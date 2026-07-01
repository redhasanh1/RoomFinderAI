#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'RoomFinderAI' }

# Files to add
files_to_add = [
  {
    path: '../Source/RoomFinderAI/Services/SimpleAuthViewModel.swift',
    name: 'SimpleAuthViewModel.swift'
  },
  {
    path: '../Source/RoomFinderAI/Services/SimpleListingsViewModel.swift', 
    name: 'SimpleListingsViewModel.swift'
  }
]

# Get or create Services group
main_group = project.main_group
source_group = main_group.find_subpath('RoomFinderAI/Source/RoomFinderAI', true)
services_group = source_group.find_subpath('Services', true) || source_group.new_group('Services')

puts "Adding missing ViewModels to project..."

files_to_add.each do |file_info|
  # Check if file already exists in project
  existing = services_group.files.find { |f| f.path == file_info[:path] }
  
  if existing
    puts "  File reference already exists: #{file_info[:name]}"
  else
    # Add file reference
    file_ref = services_group.new_reference(file_info[:path])
    file_ref.name = file_info[:name]
    puts "  Added file reference: #{file_info[:name]}"
  end
  
  # Check if file is in target
  build_file = target.source_build_phase.files.find do |bf|
    bf.file_ref && bf.file_ref.path == file_info[:path]
  end
  
  if build_file
    puts "  File already in target: #{file_info[:name]}"
  else
    # Find the file reference we just added or already existed
    file_ref = services_group.files.find { |f| f.path == file_info[:path] }
    if file_ref
      target.add_file_references([file_ref])
      puts "  Added to target: #{file_info[:name]}"
    end
  end
end

# Save the project
project.save

puts "\n✅ ViewModels added to project successfully!"