#!/usr/bin/env ruby

# Final fix for the correct path structure

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

puts "=== Final Path Fix ==="
puts "The build system is looking for assets in Project/Source/RoomFinderAI/"
puts "But they're actually in Source/RoomFinderAI/"
puts "So we need to use ../Source/RoomFinderAI/ (not ../../Source/RoomFinderAI/)"

# Change all paths back to ../Source/RoomFinderAI/
content.gsub!(/path = \.\.\/\.\.\/Source\/RoomFinderAI\//, "path = ../Source/RoomFinderAI/")

# Write the updated content back
File.write(project_file, content)

puts "✅ Fixed all paths to use ../Source/RoomFinderAI/"
puts "✅ Build system should now find files correctly"