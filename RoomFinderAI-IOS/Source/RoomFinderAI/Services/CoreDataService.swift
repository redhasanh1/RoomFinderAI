import CoreData
import Foundation
import Combine

// MARK: - Core Data Service
class CoreDataService: ObservableObject {
    static let shared = CoreDataService()
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "RoomFinderAI")
        
        // Configure for CloudKit
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Could not retrieve a persistent store description.")
        }
        
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // CloudKit configuration
        if let cloudKitOptions = description.cloudKitContainerOptions {
            cloudKitOptions.containerIdentifier = "iCloud.com.roomfinder.app"
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                LoggingService.shared.error("Core Data failed to load: \(error.localizedDescription)", category: .database)
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        setupNotifications()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] _ in
                self?.handleRemoteChange()
            }
            .store(in: &cancellables)
    }
    
    private func handleRemoteChange() {
        LoggingService.shared.info("Remote Core Data change detected", category: .database)
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Save Context
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                LoggingService.shared.info("Core Data context saved successfully", category: .database)
            } catch {
                LoggingService.shared.error("Failed to save Core Data context: \(error.localizedDescription)", category: .database)
                ErrorHandler.shared.handle(error, context: ErrorContext(additionalInfo: ["operation": "save_context"]))
            }
        }
    }
    
    // MARK: - Background Context
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
    
    // MARK: - Batch Operations
    func batchInsert<T: NSManagedObject>(entityName: String, objects: [[String: Any]]) throws {
        let batchInsert = NSBatchInsertRequest(entityName: entityName, objects: objects)
        batchInsert.resultType = .statusOnly
        
        let result = try persistentContainer.viewContext.execute(batchInsert)
        
        if let batchResult = result as? NSBatchInsertResult,
           let success = batchResult.result as? Bool, success {
            LoggingService.shared.info("Batch insert completed successfully for \(entityName)", category: .database)
        } else {
            throw CoreDataError.batchInsertFailed
        }
    }
    
    func batchDelete<T: NSManagedObject>(entityType: T.Type, predicate: NSPredicate? = nil) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entityType))
        fetchRequest.predicate = predicate
        
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDelete.resultType = .resultTypeObjectIDs
        
        let result = try persistentContainer.viewContext.execute(batchDelete)
        
        if let batchResult = result as? NSBatchDeleteResult,
           let objectIDs = batchResult.result as? [NSManagedObjectID] {
            
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [persistentContainer.viewContext])
            
            LoggingService.shared.info("Batch delete completed for \(objectIDs.count) objects", category: .database)
        }
    }
    
    // MARK: - Fetch Operations
    func fetch<T: NSManagedObject>(entityType: T.Type, predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil, limit: Int? = nil) throws -> [T] {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: entityType))
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors
        
        if let limit = limit {
            fetchRequest.fetchLimit = limit
        }
        
        return try persistentContainer.viewContext.fetch(fetchRequest)
    }
    
    func fetchFirst<T: NSManagedObject>(entityType: T.Type, predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) throws -> T? {
        let results = try fetch(entityType: entityType, predicate: predicate, sortDescriptors: sortDescriptors, limit: 1)
        return results.first
    }
    
    func count<T: NSManagedObject>(entityType: T.Type, predicate: NSPredicate? = nil) throws -> Int {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: entityType))
        fetchRequest.predicate = predicate
        
        return try persistentContainer.viewContext.count(for: fetchRequest)
    }
    
    // MARK: - Sync Status Management
    func markForSync<T: NSManagedObject>(object: T) where T: SyncableEntity {
        object.syncStatus = SyncStatus.pending.rawValue
        save()
    }
    
    func markSynced<T: NSManagedObject>(object: T) where T: SyncableEntity {
        object.syncStatus = SyncStatus.synced.rawValue
        save()
    }
    
    func fetchPendingSyncObjects<T: NSManagedObject>(entityType: T.Type) throws -> [T] where T: SyncableEntity {
        let predicate = NSPredicate(format: "syncStatus == %@", SyncStatus.pending.rawValue)
        return try fetch(entityType: entityType, predicate: predicate)
    }
    
    // MARK: - Cleanup
    func deleteOldEntries<T: NSManagedObject>(entityType: T.Type, olderThan days: Int) throws {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let predicate = NSPredicate(format: "createdAt < %@", cutoffDate as NSDate)
        try batchDelete(entityType: entityType, predicate: predicate)
    }
    
    func clearAllData() throws {
        let entityNames = ["CDListing", "CDUser", "CDChat", "CDMessage"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try persistentContainer.viewContext.execute(batchDelete)
        }
        
        save()
        LoggingService.shared.info("All Core Data cleared", category: .database)
    }
}

// MARK: - Core Data Error
enum CoreDataError: Error, LocalizedError {
    case batchInsertFailed
    case entityNotFound
    case invalidData
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .batchInsertFailed:
            return "Batch insert operation failed"
        case .entityNotFound:
            return "Entity not found"
        case .invalidData:
            return "Invalid data provided"
        case .syncFailed:
            return "Sync operation failed"
        }
    }
}

// MARK: - Sync Status
enum SyncStatus: String, CaseIterable {
    case synced = "synced"
    case pending = "pending"
    case failed = "failed"
    case conflict = "conflict"
}

// MARK: - Syncable Entity Protocol
protocol SyncableEntity {
    var syncStatus: String? { get set }
    var updatedAt: Date? { get set }
}

// MARK: - Extensions for Core Data Entities
extension CDListing: SyncableEntity {}
extension CDUser: SyncableEntity {}
extension CDMessage: SyncableEntity {}

// MARK: - Data Mapping Extensions
extension CDListing {
    func toListing() -> Listing {
        return Listing(
            id: self.id ?? "",
            title: self.title ?? "",
            price: self.price,
            bedrooms: Int(self.bedrooms),
            bathrooms: Int(self.bathrooms),
            propertyType: PropertyType(rawValue: self.propertyType ?? "") ?? .apartment,
            location: [
                "address": self.address ?? "",
                "city": self.city ?? "",
                "state": self.state ?? "",
                "zipCode": self.zipCode ?? "",
                "latitude": self.latitude,
                "longitude": self.longitude
            ],
            description: self.details ?? "",
            imageURLs: self.imageURLs ?? [],
            isActive: self.isActive,
            availableDate: self.availableDate ?? Date(),
            createdAt: self.createdAt ?? Date(),
            updatedAt: self.updatedAt ?? Date()
        )
    }
    
    func updateFromListing(_ listing: Listing) {
        self.id = listing.id
        self.title = listing.title
        self.price = listing.price
        self.bedrooms = Int32(listing.bedrooms)
        self.bathrooms = Int32(listing.bathrooms)
        self.propertyType = listing.propertyType.rawValue
        
        if let location = listing.location {
            self.address = location["address"] as? String ?? ""
            self.city = location["city"] as? String ?? ""
            self.state = location["state"] as? String ?? ""
            self.zipCode = location["zipCode"] as? String ?? ""
            self.latitude = location["latitude"] as? Double ?? 0.0
            self.longitude = location["longitude"] as? Double ?? 0.0
        }
        
        self.details = listing.description
        self.imageURLs = listing.imageURLs
        self.isActive = listing.isActive
        self.availableDate = listing.availableDate
        self.createdAt = listing.createdAt
        self.updatedAt = listing.updatedAt
    }
}

extension CDUser {
    func toUser() -> User {
        return User(
            id: self.id ?? "",
            email: self.email ?? "",
            firstName: self.firstName ?? "",
            lastName: self.lastName ?? "",
            phoneNumber: self.phoneNumber,
            profileImageURL: self.profileImageURL,
            isActive: self.isActive,
            createdAt: self.createdAt ?? Date(),
            updatedAt: self.updatedAt ?? Date()
        )
    }
    
    func updateFromUser(_ user: User) {
        self.id = user.id
        self.email = user.email
        self.firstName = user.firstName
        self.lastName = user.lastName
        self.phoneNumber = user.phoneNumber
        self.profileImageURL = user.profileImageURL
        self.isActive = user.isActive
        self.createdAt = user.createdAt
        self.updatedAt = user.updatedAt
    }
}

extension CDMessage {
    func toMessage() -> Message {
        return Message(
            id: self.id ?? "",
            chatID: self.chatID ?? "",
            senderID: self.senderID ?? "",
            content: self.content ?? "",
            messageType: MessageType(rawValue: self.messageType ?? "") ?? .text,
            isRead: self.isRead,
            createdAt: self.createdAt ?? Date(),
            updatedAt: self.updatedAt ?? Date()
        )
    }
    
    func updateFromMessage(_ message: Message) {
        self.id = message.id
        self.chatID = message.chatID
        self.senderID = message.senderID
        self.content = message.content
        self.messageType = message.messageType.rawValue
        self.isRead = message.isRead
        self.createdAt = message.createdAt
        self.updatedAt = message.updatedAt
    }
}

extension CDChat {
    func toChat() -> Chat {
        let participantsArray: [String]
        if let data = self.participantsData {
            participantsArray = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        } else {
            participantsArray = []
        }
        
        return Chat(
            id: self.id ?? "",
            propertyID: self.propertyID,
            participants: participantsArray,
            type: ChatType(rawValue: self.type ?? "") ?? .direct,
            lastMessage: self.lastMessage,
            lastMessageDate: self.lastMessageDate,
            createdAt: self.createdAt ?? Date(),
            updatedAt: self.updatedAt ?? Date()
        )
    }
    
    func updateFromChat(_ chat: Chat) {
        self.id = chat.id
        self.propertyID = chat.propertyID
        
        if let data = try? JSONEncoder().encode(chat.participants) {
            self.participantsData = data
        }
        
        self.type = chat.type.rawValue
        self.lastMessage = chat.lastMessage
        self.lastMessageDate = chat.lastMessageDate
        self.createdAt = chat.createdAt
        self.updatedAt = chat.updatedAt
    }
}