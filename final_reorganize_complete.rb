#!/usr/bin/env ruby

require 'xcodeproj'
require 'fileutils'

puts "🔧 FINAL COMPLETE REORGANIZATION - Creating clean project structure"

project_path = './RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
base_dir = './RoomFinderAI-IOS/Project/RoomFinderAI'

# Open project
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == "RoomFinderAI" }

# Step 1: Clear everything and start fresh
puts "🧹 Clearing all existing references..."
project.main_group.children.clear
target.source_build_phase.files.clear if target.source_build_phase
target.resources_build_phase.files.clear if target.resources_build_phase

# Step 2: Create the expected directory structure on filesystem
puts "📁 Creating directory structure..."
directories = [
  "#{base_dir}/App",
  "#{base_dir}/Config", 
  "#{base_dir}/Core/Models",
  "#{base_dir}/Core/Extensions",
  "#{base_dir}/Services/Supabase",
  "#{base_dir}/Services/OpenAI", 
  "#{base_dir}/Features/Listings",
  "#{base_dir}/Features/Chat",
  "#{base_dir}/Features/Negotiator",
  "#{base_dir}/UI/Components",
  "#{base_dir}/Resources"
]

directories.each do |dir|
  FileUtils.mkdir_p(dir)
  puts "  📂 Created: #{dir.gsub("#{base_dir}/", "")}"
end

# Step 3: Move the main app file to App directory
puts "📦 Moving RoomFinderAIApp.swift to App directory..."
main_app_file = "#{base_dir}/RoomFinderAIApp.swift"
target_app_file = "#{base_dir}/App/RoomFinderAIApp.swift"

if File.exist?(main_app_file)
  FileUtils.mv(main_app_file, target_app_file)
  puts "  ✅ Moved RoomFinderAIApp.swift → App/"
else
  puts "  ⚠️  RoomFinderAIApp.swift not found at expected location"
end

# Step 4: Create placeholder files for the organized structure
puts "📝 Creating placeholder files for proper structure..."

placeholder_files = {
  "#{base_dir}/Config/Secrets.swift" => <<~SWIFT,
    import Foundation

    struct Secrets {
        static let supabaseURL = "https://your-project.supabase.co"
        static let supabaseAnonKey = "your-anon-key"
        static let openAIKey = "sk-proj-your-key"
        static let openAIOrgID: String? = nil
        static let openAIModel = "gpt-3.5-turbo"
        
        static func assertValid() {
            assert(!supabaseURL.contains("your-project"), "Update Secrets.swift with real Supabase URL")
            assert(!supabaseAnonKey.contains("your-anon"), "Update Secrets.swift with real Supabase key")
            assert(!openAIKey.contains("your-key"), "Update Secrets.swift with real OpenAI key")
        }
    }
    SWIFT
    
  "#{base_dir}/Config/SupabaseEnvironment.swift" => <<~SWIFT,
    import Foundation

    struct SupabaseEnvironment {
        // Configuration for Supabase environment
    }
    SWIFT

  "#{base_dir}/Core/Models/User.swift" => <<~SWIFT,
    import Foundation

    struct User: Identifiable, Codable {
        let id: UUID
        let email: String
        let name: String?
    }
    SWIFT

  "#{base_dir}/Core/Models/Listing.swift" => <<~SWIFT,
    import Foundation

    struct Listing: Identifiable, Codable {
        let id: UUID
        let title: String
        let description: String
        let price: Double
    }
    SWIFT

  "#{base_dir}/Core/Models/Chat.swift" => <<~SWIFT,
    import Foundation

    struct Chat: Identifiable, Codable {
        let id: UUID
        let title: String
        let messages: [Message]
    }
    SWIFT

  "#{base_dir}/Core/Models/Message.swift" => <<~SWIFT,
    import Foundation

    struct Message: Identifiable, Codable {
        let id: UUID
        let content: String
        let timestamp: Date
        let isFromUser: Bool
    }
    SWIFT

  "#{base_dir}/Core/Extensions/Constants.swift" => <<~SWIFT,
    import Foundation

    struct Constants {
        // App constants
    }
    SWIFT

  "#{base_dir}/Core/Extensions/Extensions.swift" => <<~SWIFT,
    import SwiftUI

    // Supabase environment key
    private struct SupabaseKey: EnvironmentKey {
        static let defaultValue: SupabaseClient? = nil
    }

    extension EnvironmentValues {
        var supabase: SupabaseClient? {
            get { self[SupabaseKey.self] }
            set { self[SupabaseKey.self] = newValue }
        }
    }
    SWIFT

  "#{base_dir}/Services/Supabase/AuthViewModel.swift" => <<~SWIFT,
    import Foundation
    import Supabase

    @MainActor
    class AuthViewModel: ObservableObject {
        @Published var isAuthenticated = false
        
        private let supabase: SupabaseClient
        
        init(supabase: SupabaseClient) {
            self.supabase = supabase
        }
    }
    SWIFT

  "#{base_dir}/Services/Supabase/SupabaseService.swift" => <<~SWIFT,
    import Foundation
    import Supabase

    class SupabaseService: ObservableObject {
        let client: SupabaseClient
        
        init() {
            let url = URL(string: Secrets.supabaseURL)!
            self.client = SupabaseClient(supabaseURL: url, supabaseKey: Secrets.supabaseAnonKey)
        }
    }
    SWIFT

  "#{base_dir}/Features/Listings/ListingsViewModel.swift" => <<~SWIFT,
    import Foundation

    @MainActor
    class ListingsViewModel: ObservableObject {
        @Published var listings: [Listing] = []
    }
    SWIFT

  "#{base_dir}/Features/Chat/ChatViewModel.swift" => <<~SWIFT,
    import Foundation

    @MainActor 
    class ChatViewModel: ObservableObject {
        @Published var messages: [Message] = []
    }
    SWIFT

  "#{base_dir}/Services/NetworkManager.swift" => <<~SWIFT,
    import Foundation

    class NetworkManager {
        static let shared = NetworkManager()
        private init() {}
    }
    SWIFT
}

# Only create files that don't exist
placeholder_files.each do |path, content|
  unless File.exist?(path)
    File.write(path, content)
    puts "  ✅ Created: #{path.gsub("#{base_dir}/", "")}"
  end
end

# Step 5: Rebuild Xcode project structure with clean groups
puts "🏗️ Building clean Xcode project structure..."

main_group = project.main_group

# Create group hierarchy
app_group = main_group.new_group('App', 'App')
config_group = main_group.new_group('Config', 'Config') 
core_group = main_group.new_group('Core')
models_group = core_group.new_group('Models', 'Core/Models')
extensions_group = core_group.new_group('Extensions', 'Core/Extensions')
services_group = main_group.new_group('Services')
supabase_group = services_group.new_group('Supabase', 'Services/Supabase')
openai_group = services_group.new_group('OpenAI', 'Services/OpenAI')
features_group = main_group.new_group('Features')
listings_group = features_group.new_group('Listings', 'Features/Listings')
chat_group = features_group.new_group('Chat', 'Features/Chat')  
negotiator_group = features_group.new_group('Negotiator', 'Features/Negotiator')
ui_group = main_group.new_group('UI')
components_group = ui_group.new_group('Components', 'UI/Components')
resources_group = main_group.new_group('Resources', 'Resources')
products_group = main_group.new_group('Products')

# File mapping with groups and paths
file_mappings = {
  'App/RoomFinderAIApp.swift' => app_group,
  'Config/Secrets.swift' => config_group,
  'Config/SupabaseEnvironment.swift' => config_group,
  'Core/Models/User.swift' => models_group,
  'Core/Models/Listing.swift' => models_group,
  'Core/Models/Chat.swift' => models_group,
  'Core/Models/Message.swift' => models_group,
  'Core/Extensions/Constants.swift' => extensions_group,
  'Core/Extensions/Extensions.swift' => extensions_group,
  'Services/Supabase/AuthViewModel.swift' => supabase_group,
  'Services/Supabase/SupabaseService.swift' => supabase_group,
  'Features/Listings/ListingsViewModel.swift' => listings_group,
  'Features/Chat/ChatViewModel.swift' => chat_group,
  'Services/NetworkManager.swift' => services_group
}

# Add all Swift files to project
puts "📎 Adding Swift files to project..."
file_mappings.each do |relative_path, group|
  full_path = "#{base_dir}/#{relative_path}"
  
  if File.exist?(full_path)
    file_ref = group.new_reference(relative_path)
    file_ref.last_known_file_type = 'sourcecode.swift'
    file_ref.source_tree = '<group>'
    
    # Add to build phase
    target.source_build_phase.add_file_reference(file_ref)
    
    puts "  ✅ Added: #{relative_path}"
  else
    puts "  ⚠️  Missing: #{relative_path}"
  end
end

# Handle resources
puts "📦 Adding resources..."

# Assets
assets_path = "#{base_dir}/Resources/Assets.xcassets"
if Dir.exist?(assets_path)
  assets_ref = resources_group.new_reference('Resources/Assets.xcassets')
  assets_ref.last_known_file_type = 'folder.assetcatalog'
  assets_ref.source_tree = '<group>'
  target.resources_build_phase.add_file_reference(assets_ref)
  puts "  ✅ Added: Assets.xcassets"
else
  # Create basic Assets.xcassets structure
  FileUtils.mkdir_p("#{assets_path}/AppIcon.appiconset")
  FileUtils.mkdir_p("#{assets_path}/AccentColor.colorset")
  
  # Create Contents.json files
  File.write("#{assets_path}/Contents.json", '{"info":{"version":1,"author":"xcode"}}')
  File.write("#{assets_path}/AppIcon.appiconset/Contents.json", '{"images":[],"info":{"version":1,"author":"xcode"}}')
  File.write("#{assets_path}/AccentColor.colorset/Contents.json", '{"info":{"version":1,"author":"xcode"},"colors":[{"idiom":"universal"}]}')
  
  assets_ref = resources_group.new_reference('Resources/Assets.xcassets')
  assets_ref.last_known_file_type = 'folder.assetcatalog'
  assets_ref.source_tree = '<group>'
  target.resources_build_phase.add_file_reference(assets_ref)
  puts "  ✅ Created and added: Assets.xcassets"
end

# Add product reference
app_product_ref = products_group.new_reference("RoomFinderAI.app")
app_product_ref.explicit_file_type = 'wrapper.application'
app_product_ref.source_tree = 'BUILT_PRODUCTS_DIR'

puts "💾 Saving project..."
project.save

puts "✅ COMPLETE! Project reorganized with clean structure."
puts ""
puts "📂 Final structure:"
puts "  ├── App/"
puts "  │   └── RoomFinderAIApp.swift"
puts "  ├── Config/"
puts "  │   ├── Secrets.swift"
puts "  │   └── SupabaseEnvironment.swift" 
puts "  ├── Core/"
puts "  │   ├── Models/"
puts "  │   │   ├── User.swift"
puts "  │   │   ├── Listing.swift"
puts "  │   │   ├── Chat.swift"
puts "  │   │   └── Message.swift"
puts "  │   └── Extensions/"
puts "  │       ├── Constants.swift"
puts "  │       └── Extensions.swift"
puts "  ├── Services/"
puts "  │   ├── Supabase/"
puts "  │   │   ├── AuthViewModel.swift"
puts "  │   │   └── SupabaseService.swift"
puts "  │   └── NetworkManager.swift"
puts "  ├── Features/"
puts "  │   ├── Listings/"
puts "  │   │   └── ListingsViewModel.swift"
puts "  │   └── Chat/"
puts "  │       └── ChatViewModel.swift"
puts "  └── Resources/"
puts "      └── Assets.xcassets"