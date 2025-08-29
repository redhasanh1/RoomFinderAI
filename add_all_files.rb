#!/usr/bin/env ruby

require 'xcodeproj'
require 'pathname'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)
project_dir = Pathname.new(File.dirname(project_path))

# Get the main target
target = project.targets.find { |t| t.name == "RoomFinderAI" }

# Get the RoomFinderAI group
main_group = project.main_group
roomfinder_group = main_group['RoomFinderAI'] || main_group.new_group('RoomFinderAI')

# Create subgroups
models_group = roomfinder_group['Models'] || roomfinder_group.new_group('Models')
views_group = roomfinder_group['Views'] || roomfinder_group.new_group('Views')  
utils_group = roomfinder_group['Utils'] || roomfinder_group.new_group('Utils')
resources_group = roomfinder_group['Resources'] || roomfinder_group.new_group('Resources')

# Files to add
files = {
  roomfinder_group => [
    'RoomFinderAI/RoomFinderAIApp.swift',
    'RoomFinderAI/ContentView.swift',
    'RoomFinderAI/Secrets.swift',
    'RoomFinderAI/SupabaseEnvironment.swift'
  ],
  models_group => [
    'RoomFinderAI/Models/User.swift',
    'RoomFinderAI/Models/Listing.swift'
  ],
  views_group => [
    'RoomFinderAI/Views/ListingsView.swift',
    'RoomFinderAI/Views/PropertyDetailView.swift'
  ],
  utils_group => [
    'RoomFinderAI/Utils/Constants.swift',
    'RoomFinderAI/Utils/Extensions.swift'
  ],
  resources_group => [
    'RoomFinderAI/Resources/Assets.xcassets'
  ]
}

added_count = 0

files.each do |group, file_paths|
  file_paths.each do |relative_path|
    full_path = project_dir.join(relative_path)
    
    if File.exist?(full_path)
      file_name = File.basename(relative_path)
      
      # Check if already in project
      existing = project.files.find { |f| f.path&.end_with?(file_name) }
      if existing
        puts "⚠️  #{file_name} already in project"
      else
        # Add file reference
        file_ref = group.new_reference(relative_path)
        
        # Add to target (except assets)
        unless file_name.end_with?('.xcassets')
          target.add_file_references([file_ref])
        else
          target.add_resources([file_ref])
        end
        
        puts "✅ Added #{file_name}"
        added_count += 1
      end
    else
      puts "⏭️  Skipping missing: #{relative_path}"
    end
  end
end

# Save the project
project.save

puts "\n✅ Added #{added_count} files to project"