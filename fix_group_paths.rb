#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔧 Fixing group path structure..."

# Find the RoomFinderAI group
main_group = project.main_group
roomfinder_group = main_group['RoomFinderAI']

if roomfinder_group
  puts "Found RoomFinderAI group with path: #{roomfinder_group.path}"
  
  # The RoomFinderAI group should have no path (or be relative)
  # The subgroups should have relative paths
  roomfinder_group.children.each do |child|
    if child.is_a?(Xcodeproj::Project::Object::PBXGroup)
      puts "  Group: #{child.name} - current path: #{child.path}"
      
      # The problem is that child groups like "Resources" have a path
      # but they're inside the RoomFinderAI group which also has a path
      # This causes path concatenation issues
      
      if child.name == 'Resources'
        puts "    Fixing Resources group path"
        # Remove the path from the Resources group
        # The files inside should keep their full paths
        child.path = nil
        puts "    Set Resources group path to: nil"
      end
    end
  end
  
  # Also check if the RoomFinderAI group itself should have no path
  puts "Setting RoomFinderAI group path to nil to fix concatenation"
  roomfinder_group.path = nil
  
  # Now update all file references to be absolute from project root
  project.files.each do |file_ref|
    if file_ref.path && file_ref.path.start_with?('RoomFinderAI/')
      # These paths are already correct, don't change them
      puts "  File path looks correct: #{file_ref.path}"
    end
  end
end

# Save the project
project.save
puts "✅ Fixed group structure and saved project"