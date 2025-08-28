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

# Files to add with their correct relative paths
files_to_add = [
  'RoomFinderAI/Secrets.swift',
  'RoomFinderAI/SupabaseEnvironment.swift',
  'RoomFinderAI/RoomFinderAIApp.swift',
  'RoomFinderAI/ContentView.swift'
]

added_count = 0

files_to_add.each do |relative_path|
  full_path = project_dir.join(relative_path)
  
  if File.exist?(full_path)
    file_name = File.basename(relative_path)
    
    # Check if already in project
    existing = project.files.find { |f| f.path == relative_path }
    if existing
      puts "⚠️  #{file_name} already in project"
    else
      # Add file reference
      file_ref = project.new_file(relative_path)
      
      # Add to target
      target.add_file_references([file_ref])
      
      puts "✅ Added #{file_name}"
      added_count += 1
    end
  else
    puts "❌ File not found: #{relative_path}"
  end
end

# Save the project
project.save

puts "\n✅ Added #{added_count} files to project"