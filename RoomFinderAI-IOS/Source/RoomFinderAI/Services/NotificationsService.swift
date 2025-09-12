import Foundation
import Supabase
import Combine
import UserNotifications

@MainActor
final class NotificationsService: ObservableObject {
    @Published var notifications: [NotificationItem] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    @Published var error: String?
    @Published var notificationSettings: UserSettings?
    
    private let client: SupabaseClient
    private let authService: AuthService
    
    init(client: SupabaseClient, authService: AuthService) {
        self.client = client
        self.authService = authService
        
        // Request notification permissions on init
        Task {
            await requestNotificationPermission()
        }
    }
    
    // MARK: - Fetch Notifications
    func fetchNotifications() async {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        error = nil
        
        do {
            let response: [NotificationItem] = try await client
                .from("notifications")
                .select("*")
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value
            
            notifications = response
            updateUnreadCount()
        } catch {
            self.error = "Failed to fetch notifications: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Mark as Read
    func markAsRead(notificationId: String) async -> Bool {
        do {
            struct NotificationUpdate: Codable {
                let is_read: Bool
                let read_at: String
            }
            
            let update = NotificationUpdate(
                is_read: true,
                read_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await client
                .from("notifications")
                .update(update)
                .eq("id", value: notificationId)
                .execute()
            
            // Update local notification
            if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
                notifications[index] = NotificationItem(
                    id: notifications[index].id,
                    userId: notifications[index].userId,
                    title: notifications[index].title,
                    body: notifications[index].body,
                    type: notifications[index].type,
                    data: notifications[index].data,
                    isRead: true,
                    createdAt: notifications[index].createdAt,
                    readAt: Date()
                )
            }
            
            updateUnreadCount()
            return true
        } catch {
            self.error = "Failed to mark notification as read: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Mark All as Read
    func markAllAsRead() async -> Bool {
        guard let userId = authService.currentUser?.id else { return false }
        
        do {
            struct NotificationUpdate: Codable {
                let is_read: Bool
                let read_at: String
            }
            
            let update = NotificationUpdate(
                is_read: true,
                read_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await client
                .from("notifications")
                .update(update)
                .eq("user_id", value: userId)
                .eq("is_read", value: false)
                .execute()
            
            // Update local notifications
            for index in notifications.indices {
                if !notifications[index].isRead {
                    notifications[index] = NotificationItem(
                        id: notifications[index].id,
                        userId: notifications[index].userId,
                        title: notifications[index].title,
                        body: notifications[index].body,
                        type: notifications[index].type,
                        data: notifications[index].data,
                        isRead: true,
                        createdAt: notifications[index].createdAt,
                        readAt: Date()
                    )
                }
            }
            
            updateUnreadCount()
            return true
        } catch {
            self.error = "Failed to mark all notifications as read: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Delete Notification
    func deleteNotification(id: String) async -> Bool {
        do {
            try await client
                .from("notifications")
                .delete()
                .eq("id", value: id)
                .execute()
            
            notifications.removeAll { $0.id == id }
            updateUnreadCount()
            return true
        } catch {
            self.error = "Failed to delete notification: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Clear All Notifications
    func clearAllNotifications() async -> Bool {
        guard let userId = authService.currentUser?.id else { return false }
        
        do {
            try await client
                .from("notifications")
                .delete()
                .eq("user_id", value: userId)
                .execute()
            
            notifications.removeAll()
            updateUnreadCount()
            return true
        } catch {
            self.error = "Failed to clear all notifications: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Send Notification (for testing/admin)
    func createNotification(
        title: String,
        body: String,
        type: NotificationType,
        data: NotificationData? = nil
    ) async -> Bool {
        guard let userId = authService.currentUser?.id else { return false }
        
        do {
            struct NotificationInsert: Codable {
                let user_id: String
                let title: String
                let body: String
                let type: String
                let data: String?
                let is_read: Bool
                let created_at: String
            }
            
            let dataString: String?
            if let data = data {
                dataString = try? String(data: JSONEncoder().encode(data), encoding: .utf8)
            } else {
                dataString = nil
            }
            
            let notification = NotificationInsert(
                user_id: userId,
                title: title,
                body: body,
                type: type.rawValue,
                data: dataString,
                is_read: false,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await client
                .from("notifications")
                .insert(notification)
                .execute()
            
            await fetchNotifications()
            await scheduleLocalNotification(title: title, body: body, type: type)
            
            return true
        } catch {
            self.error = "Failed to create notification: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Notification Settings
    func fetchNotificationSettings() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            let response: [UserSettings] = try await client
                .from("user_settings")
                .select("*")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            notificationSettings = response.first
        } catch {
            self.error = "Failed to fetch notification settings: \(error.localizedDescription)"
        }
    }
    
    func updateNotificationSettings(_ settings: UserSettings) async -> Bool {
        do {
            try await client
                .from("user_settings")
                .upsert(settings)
                .execute()
            
            notificationSettings = settings
            return true
        } catch {
            self.error = "Failed to update notification settings: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Push Notification Permission
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            self.error = "Failed to request notification permission: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Schedule Local Notification
    private func scheduleLocalNotification(
        title: String,
        body: String,
        type: NotificationType
    ) async {
        // Check if notifications are enabled in settings
        guard notificationSettings?.pushNotifications != false else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Add custom data
        content.userInfo = [
            "type": type.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Schedule immediately
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule local notification: \(error)")
        }
    }
    
    // MARK: - Filter Notifications
    func getNotifications(ofType type: NotificationType) -> [NotificationItem] {
        return notifications.filter { $0.type == type }
    }
    
    func getUnreadNotifications() -> [NotificationItem] {
        return notifications.filter { !$0.isRead }
    }
    
    // MARK: - Private Methods
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
}