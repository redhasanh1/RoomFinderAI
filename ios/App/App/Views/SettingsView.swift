import SwiftUI

struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var emailNotifications = true
    @State private var pushNotifications = true
    @State private var showSavedSearches = true
    @State private var darkModeEnabled = false
    @State private var selectedCurrency = "USD"
    @State private var maxDistance = 10.0
    @Environment(\.dismiss) private var dismiss
    
    let currencies = ["USD", "EUR", "GBP", "CAD", "AUD"]
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Section
                Section("Profile") {
                    NavigationLink(destination: EditProfileView()) {
                        HStack {
                            Image(systemName: "person.circle")
                                .foregroundColor(.blue)
                            Text("Edit Profile")
                        }
                    }
                    
                    NavigationLink(destination: ChangePasswordView()) {
                        HStack {
                            Image(systemName: "key")
                                .foregroundColor(.orange)
                            Text("Change Password")
                        }
                    }
                }
                
                // Notifications
                Section("Notifications") {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack {
                            Image(systemName: "bell")
                                .foregroundColor(.red)
                            Text("Enable Notifications")
                        }
                    }
                    
                    if notificationsEnabled {
                        Toggle(isOn: $emailNotifications) {
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.blue)
                                Text("Email Notifications")
                            }
                        }
                        
                        Toggle(isOn: $pushNotifications) {
                            HStack {
                                Image(systemName: "phone")
                                    .foregroundColor(.green)
                                Text("Push Notifications")
                            }
                        }
                    }
                }
                
                // Search Preferences
                Section("Search Preferences") {
                    Toggle(isOn: $showSavedSearches) {
                        HStack {
                            Image(systemName: "bookmark")
                                .foregroundColor(.purple)
                            Text("Show Saved Searches")
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "location.circle")
                                .foregroundColor(.blue)
                            Text("Max Search Distance")
                            Spacer()
                            Text("\(Int(maxDistance)) mi")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $maxDistance, in: 1...50, step: 1)
                            .accentColor(.blue)
                    }
                    
                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // App Preferences
                Section("App Preferences") {
                    Toggle(isOn: $darkModeEnabled) {
                        HStack {
                            Image(systemName: "moon")
                                .foregroundColor(.indigo)
                            Text("Dark Mode")
                        }
                    }
                    
                    NavigationLink(destination: LanguageSettingsView()) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.green)
                            Text("Language")
                            Spacer()
                            Text("English")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Data & Privacy
                Section("Data & Privacy") {
                    NavigationLink(destination: PrivacySettingsView()) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.blue)
                            Text("Privacy Settings")
                        }
                    }
                    
                    Button(action: {
                        clearCache()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Cache")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Button(action: {
                        exportData()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("Export My Data")
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Support
                Section("Support") {
                    NavigationLink(destination: HelpCenterView()) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                            Text("Help Center")
                        }
                    }
                    
                    Button(action: {
                        contactSupport()
                    }) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.green)
                            Text("Contact Support")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.gray)
                            Text("About")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            await loadSettings()
        }
    }
    
    // MARK: - Functions
    
    @MainActor
    private func loadSettings() async {
        do {
            let result = try await WebBridge.shared.callWebFunction("iosUserAPI.getSettings")
            
            if let settings = result as? [String: Any] {
                self.notificationsEnabled = settings["notificationsEnabled"] as? Bool ?? true
                self.emailNotifications = settings["emailNotifications"] as? Bool ?? true
                self.pushNotifications = settings["pushNotifications"] as? Bool ?? true
                self.showSavedSearches = settings["showSavedSearches"] as? Bool ?? true
                self.darkModeEnabled = settings["darkModeEnabled"] as? Bool ?? false
                self.selectedCurrency = settings["currency"] as? String ?? "USD"
                self.maxDistance = settings["maxDistance"] as? Double ?? 10.0
            }
        } catch {
            print("Error loading settings: \(error)")
        }
    }
    
    private func saveSettings() {
        Task {
            do {
                let settings = [
                    "notificationsEnabled": notificationsEnabled,
                    "emailNotifications": emailNotifications,
                    "pushNotifications": pushNotifications,
                    "showSavedSearches": showSavedSearches,
                    "darkModeEnabled": darkModeEnabled,
                    "currency": selectedCurrency,
                    "maxDistance": maxDistance
                ]
                
                _ = try await WebBridge.shared.callWebFunction(
                    "iosUserAPI.updateSettings",
                    with: settings
                )
            } catch {
                print("Error saving settings: \(error)")
            }
        }
    }
    
    private func clearCache() {
        Task {
            do {
                _ = try await WebBridge.shared.callWebFunction("iosUserAPI.clearCache")
            } catch {
                print("Error clearing cache: \(error)")
            }
        }
    }
    
    private func exportData() {
        Task {
            do {
                _ = try await WebBridge.shared.callWebFunction("iosUserAPI.exportUserData")
            } catch {
                print("Error exporting data: \(error)")
            }
        }
    }
    
    private func contactSupport() {
        Task {
            do {
                _ = try await WebBridge.shared.callWebFunction("iosUserAPI.contactSupport")
            } catch {
                print("Error contacting support: \(error)")
            }
        }
    }
}

// MARK: - Placeholder Views

struct EditProfileView: View {
    var body: some View {
        Text("Edit Profile")
            .navigationTitle("Edit Profile")
    }
}

struct ChangePasswordView: View {
    var body: some View {
        Text("Change Password")
            .navigationTitle("Change Password")
    }
}

struct LanguageSettingsView: View {
    var body: some View {
        Text("Language Settings")
            .navigationTitle("Language")
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        Text("Privacy Settings")
            .navigationTitle("Privacy")
    }
}

struct HelpCenterView: View {
    var body: some View {
        Text("Help Center")
            .navigationTitle("Help")
    }
}

struct AboutView: View {
    var body: some View {
        Text("About")
            .navigationTitle("About")
    }
}

#Preview {
    SettingsView()
}