#!/usr/bin/env ruby

require 'xcodeproj'
require 'fileutils'

project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
base_dir = 'RoomFinderAI-IOS/Project/RoomFinderAI'

puts "📦 Organizing files into proper structure..."

# Read the comprehensive app from the correct location
comprehensive_app_content = nil
comprehensive_app_sources = [
  "#{base_dir}/RoomFinderAIApp.swift",
  "RoomFinderAI-IOS/Project/RoomFinderAI/RoomFinderAIApp.swift",
  "Source/RoomFinderAI/RoomFinderAIApp.swift"
]

comprehensive_app_sources.each do |path|
  if File.exist?(path)
    comprehensive_app_content = File.read(path)
    puts "📖 Found comprehensive app at: #{path}"
    break
  end
end

# Define file contents to create for proper organization
file_contents = {}

# App/RoomFinderAIApp.swift - Use comprehensive version or simple fallback
if comprehensive_app_content && comprehensive_app_content.include?("struct ContentView")
  file_contents["#{base_dir}/App/RoomFinderAIApp.swift"] = comprehensive_app_content
else
  file_contents["#{base_dir}/App/RoomFinderAIApp.swift"] = <<~SWIFT
    import SwiftUI

    @main
    struct RoomFinderAIApp: App {
        @StateObject private var authViewModel = AuthViewModel()
        @StateObject private var listingsViewModel = ListingsViewModel()
        @StateObject private var chatViewModel = ChatViewModel()
        
        init() {
            print("🔐 OpenAI key loaded: \\(Secrets.openAIKey.hasPrefix("sk-proj-") ? "project key" : "classic key") (\\(Secrets.openAIModel))")
            Secrets.assertValid()
        }
        
        var body: some Scene {
            WindowGroup {
                ContentView()
                    .environmentObject(authViewModel)
                    .environmentObject(listingsViewModel)
                    .environmentObject(chatViewModel)
                    .onAppear {
                        authViewModel.checkAuthStatus()
                    }
            }
        }
    }
  SWIFT
end

# Read existing Secrets.swift
secrets_content = nil
secrets_sources = [
  "#{base_dir}/Services/Secrets.swift",
  "#{base_dir}/Secrets.swift",
  "Source/RoomFinderAI/Config/Secrets.swift"
]

secrets_sources.each do |path|
  if File.exist?(path)
    secrets_content = File.read(path)
    puts "📖 Found Secrets.swift at: #{path}"
    break
  end
end

# Config/Secrets.swift - Use existing or create
if secrets_content
  file_contents["#{base_dir}/Config/Secrets.swift"] = secrets_content
else
  file_contents["#{base_dir}/Config/Secrets.swift"] = <<~SWIFT
    enum Secrets {
      static let supabaseURL = "https://fkktwhjybuflxqzopaex.supabase.co"
      static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjIxNzU0NzMsImV4cCI6MjAzNzc1MTQ3M30.d9rHtKJCLAKOIzlzxQZk3P7QaMOW8fTBBMr9u_3D-OE"
      private static let _rawKey = "sk-proj-zFRDbomQxBfV4CCY6Zinr5pf0EW4q-hMlWaihWMhOqtSEdHhHhJ_QmWZXDTYBFGXew-K2J3yAsWT3BlbkFJiB-CxD6QNVoq90ds6e-n826FS8-PUSAZ3OQqy110UdLXDsfhB-DXp6i84lKMxr7OB2FaEei1AA"
      static var openAIKey: String { _rawKey.trimmingCharacters(in: .whitespacesAndNewlines) }
      static let openAIOrgID: String? = nil
      static let openAIModel = "gpt-3.5-turbo"
      
      static func assertValid() {
        precondition(!openAIKey.isEmpty, "OpenAI key is required")
        precondition(openAIKey.hasPrefix("sk-"), "Invalid OpenAI key format")
      }
    }
  SWIFT
end

# Read existing SupabaseEnvironment.swift
supabase_env_content = nil
supabase_env_sources = [
  "#{base_dir}/SupabaseEnvironment.swift",
  "#{base_dir}/Services/SupabaseEnvironment.swift",
  "Source/RoomFinderAI/Config/SupabaseEnvironment.swift"
]

supabase_env_sources.each do |path|
  if File.exist?(path)
    supabase_env_content = File.read(path)
    puts "📖 Found SupabaseEnvironment.swift at: #{path}"
    break
  end
end

# Config/SupabaseEnvironment.swift - Use existing or create
if supabase_env_content
  file_contents["#{base_dir}/Config/SupabaseEnvironment.swift"] = supabase_env_content
else
  file_contents["#{base_dir}/Config/SupabaseEnvironment.swift"] = <<~SWIFT
    import SwiftUI
    import Supabase

    private struct SupabaseClientKey: EnvironmentKey {
        static let defaultValue: SupabaseClient = {
            let url = URL(string: "https://invalid.local")!
            return SupabaseClient(supabaseURL: url, supabaseKey: "invalid")
        }()
    }

    extension EnvironmentValues {
        var supabase: SupabaseClient {
            get { self[SupabaseClientKey.self] }
            set { self[SupabaseClientKey.self] = newValue }
        }
    }
  SWIFT
end

# Create stub files for organization
file_contents.merge!({
  # Features/Negotiator/ContentView.swift (main comprehensive view)
  "#{base_dir}/Features/Negotiator/ContentView.swift" => <<~SWIFT
    import SwiftUI
    import Supabase

    struct ContentView: View {
        @EnvironmentObject var authViewModel: AuthViewModel
        @EnvironmentObject var listingsViewModel: ListingsViewModel
        @EnvironmentObject var chatViewModel: ChatViewModel
        @State private var selectedTab = 0
        
        private let supabase = SupabaseClient(
            supabaseURL: URL(string: Secrets.supabaseURL)!,
            supabaseKey: Secrets.supabaseAnonKey
        )
        
        var body: some View {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag(0)
                
                ListingsView()
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Listings")
                    }
                    .tag(1)
                
                AINegotiatorHub()
                    .tabItem {
                        Image(systemName: "brain.head.profile")
                        Text("AI Negotiator")
                    }
                    .tag(2)
            }
            .environment(\\.supabase, supabase)
        }
    }
    
    struct HomeView: View {
        var body: some View {
            NavigationView {
                VStack {
                    Text("Welcome to RoomFinderAI")
                        .font(.largeTitle)
                        .padding()
                    
                    Text("Find your perfect room with AI assistance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .navigationTitle("Home")
            }
        }
    }
    
    struct AINegotiatorHub: View {
        @State private var messages: [AIMessage] = []
        @State private var inputText = ""
        
        var body: some View {
            NavigationView {
                VStack {
                    ScrollView {
                        LazyVStack {
                            ForEach(messages, id: \\.id) { message in
                                MessageRow(message: message)
                            }
                        }
                        .padding()
                    }
                    
                    HStack {
                        TextField("Ask AI about room negotiations...", text: $inputText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Send") {
                            sendMessage()
                        }
                        .disabled(inputText.isEmpty)
                    }
                    .padding()
                }
                .navigationTitle("AI Negotiator")
            }
        }
        
        private func sendMessage() {
            let userMessage = AIMessage(text: inputText, isFromUser: true)
            messages.append(userMessage)
            inputText = ""
            
            // Simulate AI response
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let aiResponse = AIMessage(text: "I can help you negotiate better room deals! What specific aspect would you like assistance with?", isFromUser: false)
                messages.append(aiResponse)
            }
        }
    }
    
    struct MessageRow: View {
        let message: AIMessage
        
        var body: some View {
            HStack {
                if message.isFromUser {
                    Spacer()
                    Text(message.text)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                } else {
                    Text(message.text)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    Spacer()
                }
            }
        }
    }
    
    struct AIMessage {
        let id = UUID()
        let text: String
        let isFromUser: Bool
    }
  SWIFT,
  
  # Core/Models
  "#{base_dir}/Core/Models/User.swift" => <<~SWIFT
    import Foundation

    struct User: Codable, Identifiable {
        let id: UUID
        let email: String
        let createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case email
            case createdAt = "created_at"
        }
    }
  SWIFT,
  
  "#{base_dir}/Core/Models/Listing.swift" => <<~SWIFT
    import Foundation

    struct Listing: Codable, Identifiable {
        let id: UUID
        let title: String
        let price: Double
        let location: String
        let description: String
        let imageURL: String?
        let createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case title
            case price
            case location
            case description
            case imageURL = "image_url"
            case createdAt = "created_at"
        }
    }
  SWIFT,
  
  "#{base_dir}/Services/Supabase/AuthViewModel.swift" => <<~SWIFT
    import Foundation
    import Supabase

    @MainActor
    class AuthViewModel: ObservableObject {
        @Published var user: User?
        @Published var isAuthenticated = false
        
        private let supabase = SupabaseClient(
            supabaseURL: URL(string: Secrets.supabaseURL)!,
            supabaseKey: Secrets.supabaseAnonKey
        )
        
        func checkAuthStatus() {
            // Check authentication status
        }
        
        func signOut() async {
            do {
                try await supabase.auth.signOut()
                self.user = nil
                self.isAuthenticated = false
            } catch {
                print("Error signing out: \\(error)")
            }
        }
    }
  SWIFT,
  
  "#{base_dir}/Features/Listings/ListingsView.swift" => <<~SWIFT
    import SwiftUI

    struct ListingsView: View {
        @EnvironmentObject var listingsViewModel: ListingsViewModel
        @State private var searchText = ""
        
        var body: some View {
            NavigationView {
                List {
                    ForEach(listingsViewModel.listings) { listing in
                        ListingRow(listing: listing)
                    }
                }
                .searchable(text: $searchText)
                .navigationTitle("Listings")
                .onAppear {
                    listingsViewModel.fetchListings()
                }
            }
        }
    }
    
    struct ListingRow: View {
        let listing: Listing
        
        var body: some View {
            VStack(alignment: .leading) {
                Text(listing.title)
                    .font(.headline)
                Text("$\\(listing.price, specifier: "%.0f")/month")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(listing.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
  SWIFT,
  
  "#{base_dir}/Features/Listings/ListingsViewModel.swift" => <<~SWIFT
    import Foundation
    import Supabase

    @MainActor
    class ListingsViewModel: ObservableObject {
        @Published var listings: [Listing] = []
        @Published var isLoading = false
        
        private let supabase = SupabaseClient(
            supabaseURL: URL(string: Secrets.supabaseURL)!,
            supabaseKey: Secrets.supabaseAnonKey
        )
        
        func fetchListings() {
            isLoading = true
            // Fetch listings from Supabase
            
            // Mock data for now
            listings = [
                Listing(id: UUID(), title: "Cozy Studio", price: 1200, location: "Downtown", description: "Nice studio apartment", imageURL: nil, createdAt: Date()),
                Listing(id: UUID(), title: "Spacious 1BR", price: 1800, location: "Midtown", description: "Large one bedroom", imageURL: nil, createdAt: Date())
            ]
            isLoading = false
        }
    }
  SWIFT,
  
  "#{base_dir}/Features/Chat/ChatViewModel.swift" => <<~SWIFT
    import Foundation

    @MainActor
    class ChatViewModel: ObservableObject {
        @Published var messages: [ChatMessage] = []
        @Published var isLoading = false
        
        func sendMessage(_ text: String) {
            let message = ChatMessage(text: text, isFromUser: true, timestamp: Date())
            messages.append(message)
            
            // Simulate response
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let response = ChatMessage(text: "Thanks for your message!", isFromUser: false, timestamp: Date())
                self.messages.append(response)
            }
        }
    }
    
    struct ChatMessage: Identifiable {
        let id = UUID()
        let text: String
        let isFromUser: Bool
        let timestamp: Date
    }
  SWIFT
})

# Write all files
file_contents.each do |path, content|
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content)
  puts "✅ Created: #{path.gsub(base_dir + '/', '')}"
end

puts "🔧 Adding files to Xcode project..."

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == "RoomFinderAI" }

# Get group references
main_group = project.main_group
app_group = main_group.children.find { |child| child.name == 'App' }
config_group = main_group.children.find { |child| child.name == 'Config' }
core_group = main_group.children.find { |child| child.name == 'Core' }
models_group = core_group.children.find { |child| child.name == 'Models' }
services_group = main_group.children.find { |child| child.name == 'Services' }
supabase_group = services_group.children.find { |child| child.name == 'Supabase' }
features_group = main_group.children.find { |child| child.name == 'Features' }
negotiator_group = features_group.children.find { |child| child.name == 'Negotiator' }
listings_group = features_group.children.find { |child| child.name == 'Listings' }
chat_group = features_group.children.find { |child| child.name == 'Chat' }
resources_group = main_group.children.find { |child| child.name == 'Resources' }

# Add files to appropriate groups
files_to_add = {
  "App/RoomFinderAIApp.swift" => app_group,
  "Config/Secrets.swift" => config_group,
  "Config/SupabaseEnvironment.swift" => config_group,
  "Core/Models/User.swift" => models_group,
  "Core/Models/Listing.swift" => models_group,
  "Features/Negotiator/ContentView.swift" => negotiator_group,
  "Features/Listings/ListingsView.swift" => listings_group,
  "Features/Listings/ListingsViewModel.swift" => listings_group,
  "Features/Chat/ChatViewModel.swift" => chat_group,
  "Services/Supabase/AuthViewModel.swift" => supabase_group
}

files_to_add.each do |relative_path, group|
  full_path = "#{base_dir}/#{relative_path}"
  
  if File.exist?(full_path)
    # Add file reference to group
    file_ref = group.new_reference(relative_path)
    file_ref.last_known_file_type = 'sourcecode.swift'
    file_ref.source_tree = '<group>'
    
    # Add to build phase
    if target
      target.source_build_phase.add_file_reference(file_ref)
    end
    
    puts "📋 Added to project: #{relative_path}"
  end
end

# Handle resources - copy existing Assets.xcassets and Info.plist
resource_sources = Dir.glob("#{base_dir.gsub('/Project/RoomFinderAI', '')}/**/Assets.xcassets").first
if resource_sources && !File.exist?("#{base_dir}/Resources/Assets.xcassets")
  FileUtils.cp_r(resource_sources, "#{base_dir}/Resources/Assets.xcassets")
  puts "📦 Copied Assets.xcassets to Resources/"
end

info_plist_sources = Dir.glob("#{base_dir.gsub('/Project/RoomFinderAI', '')}/**/Info.plist").first
if info_plist_sources && !File.exist?("#{base_dir}/Resources/Info.plist")
  FileUtils.cp(info_plist_sources, "#{base_dir}/Resources/Info.plist")
  puts "📦 Copied Info.plist to Resources/"
end

# Add resources to project
if File.exist?("#{base_dir}/Resources/Assets.xcassets")
  assets_ref = resources_group.new_reference("Resources/Assets.xcassets")
  assets_ref.last_known_file_type = 'folder.assetcatalog'
  if target
    target.resources_build_phase.add_file_reference(assets_ref)
  end
  puts "📋 Added Assets.xcassets to resources"
end

# Add product reference
products_group = main_group.children.find { |child| child.name == 'Products' }
if products_group && products_group.children.empty?
  app_product_ref = products_group.new_reference("RoomFinderAI.app")
  app_product_ref.explicit_file_type = 'wrapper.application'
  app_product_ref.include_in_index = 0
  app_product_ref.source_tree = 'BUILT_PRODUCTS_DIR'
end

# Save the project
project.save

puts "✅ Project organization complete!"
puts ""
puts "📂 Final structure:"
puts "  App/ - Main app entry point"
puts "  Config/ - Secrets and environment configuration"  
puts "  Core/Models/ - Data models"
puts "  Services/Supabase/ - Authentication and database services"
puts "  Features/ - UI organized by feature (Listings, Chat, Negotiator)"
puts "  Resources/ - Assets and configuration files"