#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == "RoomFinderAI" }

# Get the RoomFinderAI group
main_group = project.main_group
roomfinder_group = main_group['RoomFinderAI'] || main_group.new_group('RoomFinderAI')

# Files to add
files_to_add = [
  'RoomFinderAI/Secrets.swift',
  'RoomFinderAI/SupabaseEnvironment.swift'
]

files_to_add.each do |file_path|
  file_name = File.basename(file_path)
  
  # Check if file already exists in project
  existing_file = project.files.find { |f| f.path&.end_with?(file_name) }
  if existing_file
    puts "⚠️  #{file_name} already exists in project"
  else
    puts "Adding #{file_path}"
    
    # Add file reference to project
    file_ref = roomfinder_group.new_reference(file_path)
    
    # Add file to target
    target.add_file_references([file_ref])
    
    puts "✅ Added #{file_name} to Xcode project"
  end
end

# Save the project
project.save

puts "✅ Project saved successfully!"