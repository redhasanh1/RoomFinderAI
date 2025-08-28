#!/usr/bin/env ruby

require 'xcodeproj'
require 'pathname'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the project directory
project_dir = Pathname.new(File.dirname(project_path))

# Track what we remove
removed_count = 0

# Find all file references
project.files.each do |file_ref|
  next unless file_ref.path
  
  # Construct the full path
  if file_ref.path.start_with?('/')
    full_path = file_ref.path
  else
    full_path = project_dir.join(file_ref.path).to_s
  end
  
  # Check if file exists
  unless File.exist?(full_path)
    puts "❌ Removing missing file: #{file_ref.path}"
    
    # Remove from all targets
    project.targets.each do |target|
      target.source_build_phase.remove_file_reference(file_ref) if target.source_build_phase
      target.resources_build_phase.remove_file_reference(file_ref) if target.resources_build_phase
    end
    
    # Remove from project
    file_ref.remove_from_project
    removed_count += 1
  end
end

# Save the project
project.save

puts "\n✅ Removed #{removed_count} missing file references from project"