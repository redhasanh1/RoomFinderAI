#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Remove all file references for Secrets and SupabaseEnvironment
files_to_remove = ['Secrets.swift', 'SupabaseEnvironment.swift']
removed = []

project.files.each do |file_ref|
  next unless file_ref.path
  
  filename = File.basename(file_ref.path)
  if files_to_remove.include?(filename)
    puts "Removing: #{file_ref.path}"
    
    # Remove from targets
    project.targets.each do |target|
      target.source_build_phase.remove_file_reference(file_ref) if target.source_build_phase
    end
    
    # Remove from project
    file_ref.remove_from_project
    removed << filename
  end
end

# Get the RoomFinderAI group
main_group = project.main_group
roomfinder_group = main_group['RoomFinderAI']

# Get the target
target = project.targets.find { |t| t.name == "RoomFinderAI" }

# Add files with correct paths
['Secrets.swift', 'SupabaseEnvironment.swift'].each do |filename|
  file_ref = roomfinder_group.new_reference(filename)
  target.add_file_references([file_ref])
  puts "Added: #{filename} (in RoomFinderAI group)"
end

# Save
project.save

puts "\n✅ Fixed project file references!"