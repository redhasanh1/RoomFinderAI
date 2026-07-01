#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main group
main_group = project.main_group

# Find or create Services group
services_group = main_group.groups.find { |group| group.name == 'Services' }
if !services_group
  services_group = main_group.new_group('Services')
end

# Add the simplified service files
service_files = [
  '../Source/RoomFinderAI/Services/MockDataService.swift',
  '../Source/RoomFinderAI/Services/SimpleAuthViewModel.swift', 
  '../Source/RoomFinderAI/Services/SimpleListingsViewModel.swift'
]

service_files.each do |file_path|
  # Check if file already exists in project
  existing_file = project.files.find { |f| f.path&.include?(File.basename(file_path)) }
  
  if !existing_file
    puts "Adding: #{file_path}"
    file_ref = services_group.new_file(file_path)
    
    # Add to target
    target = project.targets.find { |t| t.name == 'RoomFinderAI' }
    target.add_file_references([file_ref]) if target
  else
    puts "Already exists: #{file_path}"
  end
end

# Find or create Components group and add SharedComponents
components_group = main_group.groups.find { |group| group.name == 'Components' }
if !components_group
  components_group = main_group.new_group('Components')
end

shared_components_path = '../Source/RoomFinderAI/Components/SharedComponents.swift'
existing_components = project.files.find { |f| f.path&.include?('SharedComponents.swift') }

if !existing_components
  puts "Adding: #{shared_components_path}"
  file_ref = components_group.new_file(shared_components_path)
  
  # Add to target
  target = project.targets.find { |t| t.name == 'RoomFinderAI' }
  target.add_file_references([file_ref]) if target
else
  puts "Already exists: #{shared_components_path}"
end

project.save

puts "✅ Done! Added simplified service files to Xcode project."