#!/usr/bin/env ruby

# Fix relative paths - change from ../../Source/RoomFinderAI/ to ../Source/RoomFinderAI/

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

# Replace all ../../Source/RoomFinderAI/ with ../Source/RoomFinderAI/
content.gsub!(/\.\.\/\.\.\/Source\/RoomFinderAI\//, "../Source/RoomFinderAI/")

# Write the updated content back
File.write(project_file, content)

puts "Fixed relative paths!"
puts "Changed from ../../Source/RoomFinderAI/ to ../Source/RoomFinderAI/"