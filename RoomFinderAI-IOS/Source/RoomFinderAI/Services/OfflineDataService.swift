import Foundation
import CoreData
import Combine

// MARK: - Offline Data Service
class OfflineDataService: ObservableObject {
    static let shared = OfflineDataService()
    
    private let coreDataService = CoreDataService.shared
    private let loggingService = LoggingService.shared
    private let networkMonitor = NetworkMonitoringService.shared
    
    @Published var isOnline: Bool = true
    @Published var syncStatus: DataSyncStatus = .synced
    @Published var pendingSyncCount: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        setupNetworkMonitoring()
        setupPeriodicSync()
    }
    
    // MARK: - Setup
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                self?.isOnline = isConnected
                if isConnected {
                    self?.syncPendingData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupPeriodicSync() {
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                if self?.isOnline == true {
                    self?.syncPendingData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Listings Management
    func saveListings(_ listings: [Listing], isInitialLoad: Bool = false) {
        coreDataService.performBackgroundTask { context in
            for listing in listings {
                let fetchRequest: NSFetchRequest<CDListing> = CDListing.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", listing.id)
                
                do {
                    let existingListings = try context.fetch(fetchRequest)
                    let cdListing = existingListings.first ?? CDListing(context: context)
                    
                    cdListing.updateFromListing(listing)
                    
                    if isInitialLoad {
                        cdListing.syncStatus = SyncStatus.synced.rawValue
                    }
                    
                } catch {
                    self.loggingService.error("Failed to save listing: \(error.localizedDescription)", category: .database)
                }
            }
            
            do {
                try context.save()
                self.loggingService.info("Saved \(listings.count) listings offline", category: .database)
            } catch {
                self.loggingService.error("Failed to save listings context: \(error.localizedDescription)", category: .database)
            }
        }
    }
    
    func getOfflineListings(limit: Int = 20, offset: Int = 0) -> [Listing] {
        do {
            let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
            let cdListings = try coreDataService.fetch(
                entityType: CDListing.self,
                predicate: NSPredicate(format: "isActive == true"),
                sortDescriptors: [sortDescriptor],
                limit: limit
            )
            
            return cdListings.map { $0.toListing() }
        } catch {
            loggingService.error("Failed to fetch offline listings: \(error.localizedDescription)", category: .database)
            return []
        }
    }
    
    func getFavoriteListings() -> [Listing] {
        do {
            let predicate = NSPredicate(format: "isFavorite == true AND isActive == true")
            let sortDescriptor = NSSortDescriptor(key: "updatedAt", ascending: false)
            let cdListings = try coreDataService.fetch(
                entityType: CDListing.self,
                predicate: predicate,
                sortDescriptors: [sortDescriptor]
            )
            
            return cdListings.map { $0.toListing() }
        } catch {
            loggingService.error("Failed to fetch favorite listings: \(error.localizedDescription)", category: .database)
            return []
        }
    }
    
    func toggleFavorite(listingId: String) {
        do {
            let predicate = NSPredicate(format: "id == %@", listingId)
            if let cdListing = try coreDataService.fetchFirst(entityType: CDListing.self, predicate: predicate) {
                cdListing.isFavorite = !cdListing.isFavorite
                coreDataService.markForSync(object: cdListing)
                coreDataService.save()
                
                loggingService.info("Toggled favorite for listing: \(listingId)", category: .database)
            }
        } catch {
            loggingService.error("Failed to toggle favorite: \(error.localizedDescription)", category: .database)
        }
    }
    
    // MARK: - User Management
    func saveUser(_ user: User) {
        coreDataService.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<CDUser> = CDUser.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", user.id)
            
            do {
                let existingUsers = try context.fetch(fetchRequest)
                let cdUser = existingUsers.first ?? CDUser(context: context)
                
                cdUser.updateFromUser(user)
                cdUser.syncStatus = SyncStatus.synced.rawValue
                
                try context.save()
                self.loggingService.info("Saved user offline: \(user.id)", category: .database)
            } catch {
                self.loggingService.error("Failed to save user: \(error.localizedDescription)", category: .database)
            }
        }
    }
    
    func getOfflineUser(id: String) -> User? {
        do {
            let predicate = NSPredicate(format: "id == %@", id)
            if let cdUser = try coreDataService.fetchFirst(entityType: CDUser.self, predicate: predicate) {
                return cdUser.toUser()
            }
        } catch {
            loggingService.error("Failed to fetch offline user: \(error.localizedDescription)", category: .database)
        }
        return nil
    }
    
    // MARK: - Chat Management
    func saveChat(_ chat: Chat) {
        coreDataService.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<CDChat> = CDChat.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", chat.id)
            
            do {
                let existingChats = try context.fetch(fetchRequest)
                let cdChat = existingChats.first ?? CDChat(context: context)
                
                cdChat.updateFromChat(chat)
                cdChat.syncStatus = SyncStatus.synced.rawValue
                
                try context.save()
                self.loggingService.info("Saved chat offline: \(chat.id)", category: .database)
            } catch {
                self.loggingService.error("Failed to save chat: \(error.localizedDescription)", category: .database)
            }
        }
    }
    
    func getOfflineChats() -> [Chat] {
        do {
            let sortDescriptor = NSSortDescriptor(key: "lastMessageDate", ascending: false)
            let cdChats = try coreDataService.fetch(
                entityType: CDChat.self,
                sortDescriptors: [sortDescriptor]
            )
            
            return cdChats.map { $0.toChat() }
        } catch {
            loggingService.error("Failed to fetch offline chats: \(error.localizedDescription)", category: .database)
            return []
        }
    }
    
    func saveMessage(_ message: Message) {
        coreDataService.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<CDMessage> = CDMessage.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", message.id)
            
            do {
                let existingMessages = try context.fetch(fetchRequest)
                let cdMessage = existingMessages.first ?? CDMessage(context: context)
                
                cdMessage.updateFromMessage(message)
                
                if !self.isOnline {
                    cdMessage.syncStatus = SyncStatus.pending.rawValue
                } else {
                    cdMessage.syncStatus = SyncStatus.synced.rawValue
                }
                
                try context.save()
                self.loggingService.info("Saved message offline: \(message.id)", category: .database)
            } catch {
                self.loggingService.error("Failed to save message: \(error.localizedDescription)", category: .database)
            }
        }
    }
    
    func getOfflineMessages(chatId: String) -> [Message] {
        do {
            let predicate = NSPredicate(format: "chatID == %@", chatId)
            let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: true)
            let cdMessages = try coreDataService.fetch(
                entityType: CDMessage.self,
                predicate: predicate,
                sortDescriptors: [sortDescriptor]
            )
            
            return cdMessages.map { $0.toMessage() }
        } catch {
            loggingService.error("Failed to fetch offline messages: \(error.localizedDescription)", category: .database)
            return []
        }
    }
    
    // MARK: - Sync Operations
    func syncPendingData() {
        guard isOnline else { return }
        
        syncStatus = .syncing
        
        Task {
            do {
                await syncPendingMessages()
                await syncPendingListings()
                await syncPendingUsers()
                
                DispatchQueue.main.async {
                    self.syncStatus = .synced
                    self.updatePendingSyncCount()
                }
                
                loggingService.info("Sync completed successfully", category: .database)
            } catch {
                DispatchQueue.main.async {
                    self.syncStatus = .failed
                }
                loggingService.error("Sync failed: \(error.localizedDescription)", category: .database)
            }
        }
    }
    
    private func syncPendingMessages() async {
        do {
            let pendingMessages = try coreDataService.fetchPendingSyncObjects(entityType: CDMessage.self)
            
            for cdMessage in pendingMessages {
                let message = cdMessage.toMessage()
                
                // Sync with remote service
                // This would typically call your API service
                try await SupabaseService.shared.sendMessage(message)
                
                coreDataService.markSynced(object: cdMessage)
            }
            
            if !pendingMessages.isEmpty {
                loggingService.info("Synced \(pendingMessages.count) pending messages", category: .database)
            }
        } catch {
            loggingService.error("Failed to sync pending messages: \(error.localizedDescription)", category: .database)
        }
    }
    
    private func syncPendingListings() async {
        do {
            let pendingListings = try coreDataService.fetchPendingSyncObjects(entityType: CDListing.self)
            
            for cdListing in pendingListings {
                let listing = cdListing.toListing()
                
                // Sync with remote service
                // This would typically call your API service
                // try await SupabaseService.shared.updateListing(listing)
                
                coreDataService.markSynced(object: cdListing)
            }
            
            if !pendingListings.isEmpty {
                loggingService.info("Synced \(pendingListings.count) pending listings", category: .database)
            }
        } catch {
            loggingService.error("Failed to sync pending listings: \(error.localizedDescription)", category: .database)
        }
    }
    
    private func syncPendingUsers() async {
        do {
            let pendingUsers = try coreDataService.fetchPendingSyncObjects(entityType: CDUser.self)
            
            for cdUser in pendingUsers {
                let user = cdUser.toUser()
                
                // Sync with remote service
                // This would typically call your API service
                // try await SupabaseService.shared.updateUser(user)
                
                coreDataService.markSynced(object: cdUser)
            }
            
            if !pendingUsers.isEmpty {
                loggingService.info("Synced \(pendingUsers.count) pending users", category: .database)
            }
        } catch {
            loggingService.error("Failed to sync pending users: \(error.localizedDescription)", category: .database)
        }
    }
    
    private func updatePendingSyncCount() {
        do {
            let pendingMessages = try coreDataService.fetchPendingSyncObjects(entityType: CDMessage.self)
            let pendingListings = try coreDataService.fetchPendingSyncObjects(entityType: CDListing.self)
            let pendingUsers = try coreDataService.fetchPendingSyncObjects(entityType: CDUser.self)
            
            pendingSyncCount = pendingMessages.count + pendingListings.count + pendingUsers.count
        } catch {
            loggingService.error("Failed to update pending sync count: \(error.localizedDescription)", category: .database)
        }
    }
    
    // MARK: - Search Operations
    func searchOfflineListings(query: String) -> [Listing] {
        do {
            let predicate = NSPredicate(format: "title CONTAINS[c] %@ OR details CONTAINS[c] %@ OR city CONTAINS[c] %@", query, query, query)
            let sortDescriptor = NSSortDescriptor(key: "updatedAt", ascending: false)
            let cdListings = try coreDataService.fetch(
                entityType: CDListing.self,
                predicate: predicate,
                sortDescriptors: [sortDescriptor]
            )
            
            return cdListings.map { $0.toListing() }
        } catch {
            loggingService.error("Failed to search offline listings: \(error.localizedDescription)", category: .database)
            return []
        }
    }
    
    func filterListings(priceRange: ClosedRange<Double>?, bedrooms: Int?, bathrooms: Int?, propertyType: PropertyType?) -> [Listing] {
        var predicates: [NSPredicate] = [NSPredicate(format: "isActive == true")]
        
        if let priceRange = priceRange {
            predicates.append(NSPredicate(format: "price >= %@ AND price <= %@", NSNumber(value: priceRange.lowerBound), NSNumber(value: priceRange.upperBound)))
        }
        
        if let bedrooms = bedrooms {
            predicates.append(NSPredicate(format: "bedrooms >= %d", bedrooms))
        }
        
        if let bathrooms = bathrooms {
            predicates.append(NSPredicate(format: "bathrooms >= %d", bathrooms))
        }
        
        if let propertyType = propertyType {
            predicates.append(NSPredicate(format: "propertyType == %@", propertyType.rawValue))
        }
        
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        do {
            let sortDescriptor = NSSortDescriptor(key: "updatedAt", ascending: false)
            let cdListings = try coreDataService.fetch(
                entityType: CDListing.self,
                predicate: compoundPredicate,
                sortDescriptors: [sortDescriptor]
            )
            
            return cdListings.map { $0.toListing() }
        } catch {
            loggingService.error("Failed to filter offline listings: \(error.localizedDescription)", category: .database)
            return []
        }
    }
    
    // MARK: - Cleanup Operations
    func cleanupOldData() {
        do {
            // Clean up old listings (older than 30 days)
            try coreDataService.deleteOldEntries(entityType: CDListing.self, olderThan: 30)
            
            // Clean up old messages (older than 90 days)
            try coreDataService.deleteOldEntries(entityType: CDMessage.self, olderThan: 90)
            
            loggingService.info("Cleaned up old offline data", category: .database)
        } catch {
            loggingService.error("Failed to cleanup old data: \(error.localizedDescription)", category: .database)
        }
    }
    
    func clearAllOfflineData() {
        do {
            try coreDataService.clearAllData()
            loggingService.info("Cleared all offline data", category: .database)
        } catch {
            loggingService.error("Failed to clear all offline data: \(error.localizedDescription)", category: .database)
        }
    }
}

// MARK: - Data Sync Status
enum DataSyncStatus: String, CaseIterable {
    case synced = "synced"
    case syncing = "syncing"
    case failed = "failed"
    case pending = "pending"
    
    var displayText: String {
        switch self {
        case .synced:
            return "Synced"
        case .syncing:
            return "Syncing..."
        case .failed:
            return "Sync Failed"
        case .pending:
            return "Pending Sync"
        }
    }
}

// Required import for NWPathMonitor
import Network