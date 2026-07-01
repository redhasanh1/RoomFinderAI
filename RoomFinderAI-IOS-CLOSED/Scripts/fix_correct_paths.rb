#!/usr/bin/env ruby

# Fix paths to use correct relative path from Project directory

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

puts "=== Fixing Correct Relative Paths ==="
puts "Build is looking in: /Project/Source/RoomFinderAI/"
puts "Files are actually in: /Source/RoomFinderAI/"
puts "From Project/ directory, we need: ../Source/RoomFinderAI/"

# Change paths from ../../Source/RoomFinderAI/ back to ../Source/RoomFinderAI/
content.gsub!(/path = \.\.\/\.\.\/Source\/RoomFinderAI\//, "path = ../Source/RoomFinderAI/")

# Write the updated content back
File.write(project_file, content)

puts "✅ Updated all paths to use ../Source/RoomFinderAI/"
puts "✅ This should match the actual file locations"