#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔧 Fixing group structure correctly..."

# Remove all existing file references and groups
main_group = project.main_group

# Clear everything
main_group.children.clear

# Rebuild the proper structure
roomfinder_group = main_group.new_group('RoomFinderAI', 'RoomFinderAI')

# Create subgroups with proper relative paths within the RoomFinderAI folder
views_group = roomfinder_group.new_group('Views', 'Views')
models_group = roomfinder_group.new_group('Models', 'Models')
utils_group = roomfinder_group.new_group('Utils', 'Utils')
services_group = roomfinder_group.new_group('Services', 'Services')
resources_group = roomfinder_group.new_group('Resources', 'Resources')

# Add products group
products_group = main_group.new_group('Products')

# Get the target
target = project.targets.find { |t| t.name == "RoomFinderAI" }

# Project directory
project_dir = File.dirname(project_path)
base_dir = File.join(project_dir, 'RoomFinderAI')

# Files to add with correct structure
files_structure = {
  views_group => ['Views/ListingsView.swift', 'Views/PropertyDetailView.swift', 'Views/ChatView.swift'],
  models_group => ['Models/User.swift', 'Models/Listing.swift', 'Models/Chat.swift', 'Models/Message.swift'],
  utils_group => ['Utils/Constants.swift', 'Utils/Extensions.swift'],
  services_group => ['Services/AuthViewModel.swift', 'Services/ChatViewModel.swift', 'Services/ListingsViewModel.swift', 
                    'Services/NetworkManager.swift', 'Services/Secrets.swift', 'Services/SupabaseService.swift'],
  resources_group => ['Resources/Assets.xcassets', 'Resources/Info.plist'],
  roomfinder_group => ['RoomFinderAIApp.swift', 'ContentView.swift', 'SupabaseEnvironment.swift']
}

added_count = 0

files_structure.each do |group, file_paths|
  file_paths.each do |relative_path|
    full_path = File.join(base_dir, relative_path)
    
    if File.exist?(full_path)
      # Add file reference with relative path from group
      file_ref = group.new_reference(File.basename(relative_path))
      
      # Add to target
      if relative_path.end_with?('.swift')
        target.add_file_references([file_ref])
      elsif relative_path.end_with?('.xcassets')
        target.add_resources([file_ref]) if target.resources_build_phase
      elsif relative_path.end_with?('.plist')
        # Don't add Info.plist to resources - it should only be in build settings
      end
      
      puts "✅ Added: #{relative_path}"
      added_count += 1
    else
      puts "⚠️  File not found: #{full_path}"
    end
  end
end

# Save the project
project.save

puts "✅ Rebuilt project structure with #{added_count} files"