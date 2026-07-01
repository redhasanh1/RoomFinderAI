#!/usr/bin/env ruby

require 'xcodeproj'
require 'fileutils'

project_path = 'RoomFinderAI.xcodeproj'
base_dir = 'RoomFinderAI'

puts "🧹 Starting complete project restructuring..."

# Create clean directory structure
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
  puts "📁 Created: #{dir}"
end

# Open and clean the Xcode project
project = Xcodeproj::Project.open(project_path)

# Clear all groups and files
main_group = project.main_group
main_group.children.clear

# Create new group structure
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

puts "📋 Created group structure"

# Get target
target = project.targets.find { |t| t.name == "RoomFinderAI" }

# Define file mapping for organization
file_mappings = {
  # App files
  'RoomFinderAIApp.swift' => { group: app_group, dir: 'App' },
  
  # Config files
  'Secrets.swift' => { group: config_group, dir: 'Config' },
  'SupabaseEnvironment.swift' => { group: config_group, dir: 'Config' },
  
  # Core Models
  'User.swift' => { group: models_group, dir: 'Core/Models' },
  'Listing.swift' => { group: models_group, dir: 'Core/Models' },
  'Chat.swift' => { group: models_group, dir: 'Core/Models' },
  'Message.swift' => { group: models_group, dir: 'Core/Models' },
  
  # Core Extensions
  'Extensions.swift' => { group: extensions_group, dir: 'Core/Extensions' },
  'Constants.swift' => { group: extensions_group, dir: 'Core/Extensions' },
  
  # Services - Supabase
  'SupabaseService.swift' => { group: supabase_group, dir: 'Services/Supabase' },
  'AuthViewModel.swift' => { group: supabase_group, dir: 'Services/Supabase' },
  
  # Services - OpenAI
  'OpenAIClient.swift' => { group: openai_group, dir: 'Services/OpenAI' },
  
  # Features - Listings
  'ListingsView.swift' => { group: listings_group, dir: 'Features/Listings' },
  'ListingsViewModel.swift' => { group: listings_group, dir: 'Features/Listings' },
  'PropertyDetailView.swift' => { group: listings_group, dir: 'Features/Listings' },
  
  # Features - Chat
  'ChatView.swift' => { group: chat_group, dir: 'Features/Chat' },
  'ChatViewModel.swift' => { group: chat_group, dir: 'Features/Chat' },
  
  # Features - Negotiator (main comprehensive app)
  'ContentView.swift' => { group: negotiator_group, dir: 'Features/Negotiator' },
  
  # Services - General
  'NetworkManager.swift' => { group: services_group, dir: 'Services' }
}

# Find all Swift files in the current RoomFinderAI directory and move them
Dir.glob("#{base_dir}/**/*.swift").each do |file_path|
  filename = File.basename(file_path)
  next if filename == 'RoomFinderAIApp.swift' && file_path.include?('Resources') # Skip nested duplicates
  
  mapping = file_mappings[filename]
  next unless mapping
  
  target_dir = "#{base_dir}/#{mapping[:dir]}"
  target_path = "#{target_dir}/#{filename}"
  
  # Move file to proper location
  unless File.exist?(target_path)
    FileUtils.mkdir_p(target_dir)
    if File.exist?(file_path)
      FileUtils.mv(file_path, target_path)
      puts "📦 Moved: #{filename} → #{mapping[:dir]}"
    end
  end
end

# Handle Resources
resource_files = ['Assets.xcassets', 'Info.plist']
resource_files.each do |resource|
  existing_paths = Dir.glob("#{base_dir}/**/#{resource}").reject { |path| path.include?('Resources/') && path != "#{base_dir}/Resources/#{resource}" }
  
  target_resource_path = "#{base_dir}/Resources/#{resource}"
  
  if existing_paths.any?
    source_path = existing_paths.first
    unless File.exist?(target_resource_path)
      FileUtils.mkdir_p("#{base_dir}/Resources")
      if File.directory?(source_path)
        FileUtils.cp_r(source_path, target_resource_path)
      else
        FileUtils.cp(source_path, target_resource_path)
      end
      puts "📦 Moved resource: #{resource} → Resources/"
    end
    
    # Remove duplicates
    existing_paths.each { |path| FileUtils.rm_rf(path) if path != target_resource_path }
  end
end

# Now add all files to the Xcode project with proper organization
file_mappings.each do |filename, mapping|
  file_path = "#{base_dir}/#{mapping[:dir]}/#{filename}"
  
  if File.exist?(file_path)
    # Add file reference
    file_ref = mapping[:group].new_reference(file_path)
    file_ref.last_known_file_type = 'sourcecode.swift'
    file_ref.source_tree = '<group>'
    
    # Add to build phase
    if target && filename.end_with?('.swift')
      build_file = target.source_build_phase.add_file_reference(file_ref)
      puts "✅ Added to project: #{filename}"
    end
  else
    puts "⚠️ File not found: #{file_path}"
  end
end

# Add resources
resources_group.new_reference("#{base_dir}/Resources/Assets.xcassets")
resources_group.new_reference("#{base_dir}/Resources/Info.plist")

# Add Assets.xcassets to resources build phase
if target
  assets_ref = resources_group.children.find { |child| child.path == "#{base_dir}/Resources/Assets.xcassets" }
  if assets_ref
    target.resources_build_phase.add_file_reference(assets_ref)
    puts "✅ Added Assets.xcassets to resources"
  end
end

# Add product reference
app_product_ref = products_group.new_reference("RoomFinderAI.app")
app_product_ref.explicit_file_type = 'wrapper.application'
app_product_ref.include_in_index = 0
app_product_ref.source_tree = 'BUILT_PRODUCTS_DIR'

# Save the project
project.save

puts "✅ Project restructuring complete!"
puts "📂 Directory structure:"
puts "  App/ - Main app file"
puts "  Config/ - Configuration (Secrets, Supabase setup)"
puts "  Core/ - Models and extensions"
puts "  Services/ - Service classes organized by type"
puts "  Features/ - UI organized by feature"
puts "  Resources/ - Assets and Info.plist"