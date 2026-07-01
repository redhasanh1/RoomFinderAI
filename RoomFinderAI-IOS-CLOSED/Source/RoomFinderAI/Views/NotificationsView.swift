import SwiftUI
import Supabase

struct NotificationsView: View {
    @StateObject private var notificationsService: NotificationsService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFilter: NotificationFilter = .all
    @State private var showingDeleteAlert = false
    @State private var notificationToDelete: NotificationItem?
    @State private var showingClearAllAlert = false
    @State private var showingSettings = false
    
    init(authService: AuthService, supabaseClient: SupabaseClient) {
        self._notificationsService = StateObject(wrappedValue: NotificationsService(client: supabaseClient, authService: authService))
    }
    
    var filteredNotifications: [NotificationItem] {
        switch selectedFilter {
        case .all:
            return notificationsService.notifications
        case .unread:
            return notificationsService.notifications.filter { !$0.isRead }
        case .read:
            return notificationsService.notifications.filter { $0.isRead }
        case .messages:
            return notificationsService.notifications.filter { $0.type == .newMessage }
        case .listings:
            return notificationsService.notifications.filter { $0.type == .newListing || $0.type == .priceUpdate }
        case .system:
            return notificationsService.notifications.filter { $0.type == .general }
        }
    }
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
                .ignoresSafeArea()
            
            NavigationView {
                ZStack {
                    if notificationsService.isLoading {
                        LoadingView(message: "Loading notifications...")
                    } else if filteredNotifications.isEmpty {
                        EmptyNotificationsView(
                            filter: selectedFilter,
                            onRefresh: {
                                Task {
                                    await notificationsService.fetchNotifications()
                                }
                            }
                        )
                    } else {
                        VStack(spacing: 0) {
                            // Filter bar
                            NotificationFilterBar(
                                selectedFilter: $selectedFilter,
                                unreadCount: notificationsService.unreadCount
                            )
                            
                            // Notifications list
                            NotificationsContentView(
                                notifications: filteredNotifications,
                                onMarkRead: { notification in
                                    Task {
                                        await notificationsService.markAsRead(notificationId: notification.id)
                                    }
                                },
                                onDelete: { notification in
                                    notificationToDelete = notification
                                    showingDeleteAlert = true
                                }
                            )
                        }
                    }
                }
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Mark All as Read") {
                                Task {
                                    await notificationsService.markAllAsRead()
                                }
                            }
                            .disabled(notificationsService.unreadCount == 0)
                            
                            Button("Refresh") {
                                Task {
                                    await notificationsService.fetchNotifications()
                                }
                            }
                            
                            Divider()
                            
                            Button("Notification Settings") {
                                showingSettings = true
                            }
                            
                            if !notificationsService.notifications.isEmpty {
                                Button("Clear All", role: .destructive) {
                                    showingClearAllAlert = true
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.white)
                        }
                    }
                }
                .refreshable {
                    await notificationsService.fetchNotifications()
                }
            }
        }
        .alert("Delete Notification", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let notification = notificationToDelete {
                    Task {
                        _ = await notificationsService.deleteNotification(id: notification.id)
                    }
                }
                notificationToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this notification?")
        }
        .alert("Clear All Notifications", isPresented: $showingClearAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                Task {
                    _ = await notificationsService.clearAllNotifications()
                }
            }
        } message: {
            Text("Are you sure you want to clear all notifications? This action cannot be undone.")
        }
        .sheet(isPresented: $showingSettings) {
            NotificationSettingsView(notificationsService: notificationsService)
        }
        .task {
            await notificationsService.fetchNotifications()
            await notificationsService.fetchNotificationSettings()
        }
    }
}

enum NotificationFilter: String, CaseIterable {
    case all = "All"
    case unread = "Unread"
    case read = "Read"
    case messages = "Messages"
    case listings = "Listings"
    case system = "System"
    
    var icon: String {
        switch self {
        case .all: return "bell"
        case .unread: return "bell.badge"
        case .read: return "bell.slash"
        case .messages: return "message"
        case .listings: return "house"
        case .system: return "gear"
        }
    }
}

struct NotificationFilterBar: View {
    @Binding var selectedFilter: NotificationFilter
    let unreadCount: Int
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(NotificationFilter.allCases, id: \.self) { filter in
                    NotificationFilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        count: filter == .unread ? unreadCount : nil
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

struct NotificationFilterChip: View {
    let filter: NotificationFilter
    let isSelected: Bool
    let count: Int?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption)
                
                Text(filter.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .white : .blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.3) : Color.blue.opacity(0.2))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white.opacity(0.2) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .cornerRadius(20)
        }
    }
}

struct NotificationsContentView: View {
    let notifications: [NotificationItem]
    let onMarkRead: (NotificationItem) -> Void
    let onDelete: (NotificationItem) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(notifications) { notification in
                    NotificationCard(
                        notification: notification,
                        onMarkRead: {
                            onMarkRead(notification)
                        },
                        onDelete: {
                            onDelete(notification)
                        }
                    )
                }
            }
            .padding()
        }
    }
}

struct NotificationCard: View {
    let notification: NotificationItem
    let onMarkRead: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        GlassmorphismCard {
            HStack(spacing: 12) {
                // Notification type icon
                VStack {
                    Image(systemName: notification.type.notificationIcon)
                        .foregroundColor(notification.type.color)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(notification.type.color.opacity(0.15))
                        )
                    
                    if !notification.isRead {
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(.clear)
                            .frame(width: 8, height: 8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(notification.title)
                        .font(.headline)
                        .fontWeight(notification.isRead ? .medium : .semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(notification.body)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(3)
                    
                    HStack(spacing: 12) {
                        Text(notification.createdAt, style: .relative) + Text(" ago")
                        
                        if notification.isRead, let readAt = notification.readAt {
                            Text("• Read ") + Text(readAt, style: .relative) + Text(" ago")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    if !notification.isRead {
                        Button(action: onMarkRead) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                            .font(.title3)
                    }
                }
            }
            .padding()
        }
        .opacity(notification.isRead ? 0.8 : 1.0)
    }
}

struct EmptyNotificationsView: View {
    let filter: NotificationFilter
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 12) {
                Text(emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: onRefresh) {
                Text("Refresh")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
            }
        }
        .padding()
    }
    
    private var emptyStateIcon: String {
        switch filter {
        case .all: return "bell.slash"
        case .unread: return "bell.badge"
        case .read: return "checkmark.circle"
        case .messages: return "message.badge"
        case .listings: return "house.badge"
        case .system: return "gear.badge"
        }
    }
    
    private var emptyStateTitle: String {
        switch filter {
        case .all: return "No Notifications"
        case .unread: return "No Unread Notifications"
        case .read: return "No Read Notifications"
        case .messages: return "No Message Notifications"
        case .listings: return "No Listing Notifications"
        case .system: return "No System Notifications"
        }
    }
    
    private var emptyStateMessage: String {
        switch filter {
        case .all:
            return "You don't have any notifications yet. We'll notify you about new messages, listing updates, and other important activities."
        case .unread:
            return "Great! You're all caught up. All your notifications have been read."
        case .read:
            return "You haven't read any notifications yet."
        case .messages:
            return "No message notifications yet. You'll be notified when you receive new messages."
        case .listings:
            return "No listing notifications yet. You'll be notified about new listings that match your interests."
        case .system:
            return "No system notifications yet. We'll notify you about important app updates and announcements."
        }
    }
}

struct NotificationSettingsView: View {
    @ObservedObject var notificationsService: NotificationsService
    @Environment(\.dismiss) private var dismiss
    
    @State private var pushNotifications = true
    @State private var messageNotifications = true
    @State private var listingNotifications = true
    @State private var systemNotifications = true
    @State private var emailNotifications = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedGradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Push Notifications Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Push Notifications")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            SettingsToggleRow(
                                icon: "bell",
                                title: "Enable Push Notifications",
                                subtitle: "Receive notifications on this device",
                                isOn: $pushNotifications
                            )
                            
                            if pushNotifications {
                                VStack(spacing: 12) {
                                    SettingsToggleRow(
                                        icon: "message",
                                        title: "Message Notifications",
                                        subtitle: "New messages and replies",
                                        isOn: $messageNotifications
                                    )
                                    
                                    SettingsToggleRow(
                                        icon: "house",
                                        title: "Listing Notifications",
                                        subtitle: "New listings and updates",
                                        isOn: $listingNotifications
                                    )
                                    
                                    SettingsToggleRow(
                                        icon: "gear",
                                        title: "System Notifications",
                                        subtitle: "App updates and announcements",
                                        isOn: $systemNotifications
                                    )
                                }
                                .padding(.leading, 20)
                            }
                        }
                        
                        Divider()
                            .background(.white.opacity(0.3))
                        
                        // Email Notifications Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Email Notifications")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            SettingsToggleRow(
                                icon: "envelope",
                                title: "Email Notifications",
                                subtitle: "Receive important updates via email",
                                isOn: $emailNotifications
                            )
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveSettings()
                        }
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        if let settings = notificationsService.notificationSettings {
            pushNotifications = settings.pushNotifications
            messageNotifications = settings.messageAlerts
            listingNotifications = settings.newListingAlerts
            systemNotifications = settings.pushNotifications
            emailNotifications = settings.emailNotifications
        }
    }
    
    private func saveSettings() async {
        let settings = UserSettings(
            userId: "",
            pushNotifications: pushNotifications,
            emailNotifications: emailNotifications,
            newListingAlerts: listingNotifications,
            priceUpdateAlerts: false,
            messageAlerts: messageNotifications,
            marketingEmails: false,
            theme: .light,
            language: "en",
            privacyLevel: .friends,
            updatedAt: Date()
        )
        
        let success = await notificationsService.updateNotificationSettings(settings)
        if success {
            dismiss()
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        GlassmorphismCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.8))
                    .font(.title3)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .toggleStyle(SwitchToggleStyle())
            }
            .padding()
        }
    }
}

// Extension to add icon and color properties to NotificationType
extension NotificationType {
    var icon: String {
        switch self {
        case .newMessage: return "message.fill"
        case .newListing: return "house.fill"
        case .priceUpdate: return "house.badge.plus"
        case .favoriteUpdate: return "heart.badge.plus"
        case .general: return "gear.badge"
        }
    }
    
    var color: Color {
        switch self {
        case .newMessage: return .blue
        case .newListing: return .green
        case .priceUpdate: return .orange
        case .favoriteUpdate: return .pink
        case .general: return .purple
        }
    }
}

#Preview {
    NotificationsView(
        authService: AuthService(supabaseClient: SupabaseClient(supabaseURL: URL(string: "https://example.supabase.co")!, supabaseKey: "key")),
        supabaseClient: SupabaseClient(supabaseURL: URL(string: "https://example.supabase.co")!, supabaseKey: "key")
    )
}