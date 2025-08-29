#!/usr/bin/env ruby

require 'xcodeproj'
require 'fileutils'

project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
base_dir = 'RoomFinderAI-IOS/Project/RoomFinderAI'

puts "🗂️ Properly organizing ALL files into correct directory structure..."

# Open the project
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == "RoomFinderAI" }

# First, let's remove ALL existing file references and groups to start fresh
puts "🧹 Clearing all existing file references..."
main_group = project.main_group
main_group.children.clear

# Clear build phases
target.source_build_phase.files.clear if target.source_build_phase
target.resources_build_phase.files.clear if target.resources_build_phase

# Create clean group structure
puts "📁 Creating clean group structure..."
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

# Create actual directories
puts "📂 Creating actual directories on filesystem..."
dirs_to_create = [
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

dirs_to_create.each do |dir|
  FileUtils.mkdir_p(dir)
end

# Define file organization mapping
file_organization = {
  # App files
  'RoomFinderAIApp.swift' => { 
    group: app_group, 
    new_path: "#{base_dir}/App/RoomFinderAIApp.swift",
    old_paths: [
      "#{base_dir}/RoomFinderAIApp.swift",
      "#{base_dir}/RoomFinderAI/RoomFinderAIApp.swift"
    ]
  },
  
  # Config files
  'Secrets.swift' => { 
    group: config_group, 
    new_path: "#{base_dir}/Config/Secrets.swift",
    old_paths: [
      "#{base_dir}/Services/Secrets.swift",
      "#{base_dir}/Secrets.swift"
    ]
  },
  'SupabaseEnvironment.swift' => { 
    group: config_group, 
    new_path: "#{base_dir}/Config/SupabaseEnvironment.swift",
    old_paths: [
      "#{base_dir}/SupabaseEnvironment.swift",
      "#{base_dir}/Services/SupabaseEnvironment.swift"
    ]
  },
  
  # Core Models
  'User.swift' => { 
    group: models_group, 
    new_path: "#{base_dir}/Core/Models/User.swift",
    old_paths: [
      "#{base_dir}/Models/User.swift"
    ]
  },
  'Listing.swift' => { 
    group: models_group, 
    new_path: "#{base_dir}/Core/Models/Listing.swift",
    old_paths: [
      "#{base_dir}/Models/Listing.swift"
    ]
  },
  'Chat.swift' => { 
    group: models_group, 
    new_path: "#{base_dir}/Core/Models/Chat.swift",
    old_paths: [
      "#{base_dir}/Models/Chat.swift"
    ]
  },
  'Message.swift' => { 
    group: models_group, 
    new_path: "#{base_dir}/Core/Models/Message.swift",
    old_paths: [
      "#{base_dir}/Models/Message.swift"
    ]
  },
  
  # Core Extensions
  'Constants.swift' => { 
    group: extensions_group, 
    new_path: "#{base_dir}/Core/Extensions/Constants.swift",
    old_paths: [
      "#{base_dir}/Utils/Constants.swift"
    ]
  },
  'Extensions.swift' => { 
    group: extensions_group, 
    new_path: "#{base_dir}/Core/Extensions/Extensions.swift",
    old_paths: [
      "#{base_dir}/Utils/Extensions.swift"
    ]
  },
  
  # Services - Supabase
  'AuthViewModel.swift' => { 
    group: supabase_group, 
    new_path: "#{base_dir}/Services/Supabase/AuthViewModel.swift",
    old_paths: [
      "#{base_dir}/Services/AuthViewModel.swift"
    ]
  },
  'SupabaseService.swift' => { 
    group: supabase_group, 
    new_path: "#{base_dir}/Services/Supabase/SupabaseService.swift",
    old_paths: [
      "#{base_dir}/Services/SupabaseService.swift"
    ]
  },
  
  # Features - Listings (move ViewModels here since they're feature-specific)
  'ListingsViewModel.swift' => { 
    group: listings_group, 
    new_path: "#{base_dir}/Features/Listings/ListingsViewModel.swift",
    old_paths: [
      "#{base_dir}/Services/ListingsViewModel.swift"
    ]
  },
  'ListingsView.swift' => { 
    group: listings_group, 
    new_path: "#{base_dir}/Features/Listings/ListingsView.swift",
    old_paths: [
      "#{base_dir}/Views/ListingsView.swift"
    ]
  },
  'PropertyDetailView.swift' => { 
    group: listings_group, 
    new_path: "#{base_dir}/Features/Listings/PropertyDetailView.swift",
    old_paths: [
      "#{base_dir}/Views/PropertyDetailView.swift"
    ]
  },
  
  # Features - Chat
  'ChatViewModel.swift' => { 
    group: chat_group, 
    new_path: "#{base_dir}/Features/Chat/ChatViewModel.swift",
    old_paths: [
      "#{base_dir}/Services/ChatViewModel.swift"
    ]
  },
  'ChatView.swift' => { 
    group: chat_group, 
    new_path: "#{base_dir}/Features/Chat/ChatView.swift",
    old_paths: [
      "#{base_dir}/Views/ChatView.swift"
    ]
  },
  
  # Services - General
  'NetworkManager.swift' => { 
    group: services_group, 
    new_path: "#{base_dir}/Services/NetworkManager.swift",
    old_paths: [
      "#{base_dir}/Services/NetworkManager.swift"
    ]
  }
}

# Move files and add to project
puts "📦 Moving files to proper locations and adding to project..."
file_organization.each do |filename, config|
  # Find the source file
  source_file = nil
  config[:old_paths].each do |old_path|
    if File.exist?(old_path)
      source_file = old_path
      break
    end
  end
  
  if source_file
    # Move file to new location
    unless File.exist?(config[:new_path])
      FileUtils.mv(source_file, config[:new_path])
      puts "📄 Moved: #{filename} → #{config[:new_path].gsub(base_dir + '/', '')}"
    end
    
    # Add to Xcode project
    relative_path = config[:new_path].gsub("#{base_dir}/", '')
    file_ref = config[:group].new_reference(relative_path)
    file_ref.last_known_file_type = 'sourcecode.swift'
    file_ref.source_tree = '<group>'
    
    # Add to build phase (only Swift files)
    if filename.end_with?('.swift') && target
      target.source_build_phase.add_file_reference(file_ref)
    end
    
    puts "✅ Added to project: #{relative_path}"
  else
    puts "⚠️ File not found: #{filename} (checked: #{config[:old_paths].join(', ')})"
  end
end

# Handle Resources
puts "📦 Organizing resources..."
resource_mappings = {
  'Assets.xcassets' => "#{base_dir}/Resources/Assets.xcassets",
  'Info.plist' => "#{base_dir}/Resources/Info.plist"
}

resource_mappings.each do |resource_name, target_path|
  # Find existing resource
  existing_paths = Dir.glob("#{base_dir}/**/#{resource_name}").reject { |path| path.include?('DerivedData') }
  
  if existing_paths.any?
    source_path = existing_paths.first
    
    unless File.exist?(target_path)
      if File.directory?(source_path)
        FileUtils.cp_r(source_path, target_path)
      else
        FileUtils.cp(source_path, target_path)
      end
      puts "📦 Moved resource: #{resource_name} → Resources/"
    end
    
    # Add to project
    relative_path = target_path.gsub("#{base_dir}/", '')
    file_ref = resources_group.new_reference(relative_path)
    
    if resource_name == 'Assets.xcassets'
      file_ref.last_known_file_type = 'folder.assetcatalog'
      target.resources_build_phase.add_file_reference(file_ref) if target
    elsif resource_name == 'Info.plist'
      file_ref.last_known_file_type = 'text.plist.xml'
      # Info.plist should NOT be in resources build phase, only referenced
    end
    
    puts "✅ Added resource: #{relative_path}"
    
    # Clean up duplicates
    existing_paths.each { |path| FileUtils.rm_rf(path) if path != target_path }
  end
end

# Add product reference
app_product_ref = products_group.new_reference("RoomFinderAI.app")
app_product_ref.explicit_file_type = 'wrapper.application'
app_product_ref.include_in_index = 0
app_product_ref.source_tree = 'BUILT_PRODUCTS_DIR'

puts "\n💾 Saving organized project..."
project.save

puts "✅ Project properly organized!"
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
puts "  │   │   ├── ListingsViewModel.swift"
puts "  │   │   ├── ListingsView.swift"
puts "  │   │   └── PropertyDetailView.swift"
puts "  │   └── Chat/"
puts "  │       ├── ChatViewModel.swift"
puts "  │       └── ChatView.swift"
puts "  └── Resources/"
puts "      ├── Assets.xcassets"
puts "      └── Info.plist"