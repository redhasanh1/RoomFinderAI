#!/usr/bin/env ruby

# Fix the project file paths to point to the correct location
# The project file is looking for files in Project/RoomFinderAI/Source/RoomFinderAI/
# But files are actually in Source/RoomFinderAI/

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

puts "=== Fixing Final File Paths ==="

# The build system is looking in the wrong place because the project references are incorrect
# We need to change the paths from ../Source/RoomFinderAI/ to ../../Source/RoomFinderAI/
# Since the project file is in Project/ folder, it needs to go up one more level

puts "Current working directory: #{Dir.pwd}"
puts "Project file location: #{project_file}"
puts "Files are located in: ../Source/RoomFinderAI/"
puts "But project is looking in: Project/RoomFinderAI/Source/RoomFinderAI/"

# Change all file paths to point to the correct location
content.gsub!(/path = \.\.\/Source\/RoomFinderAI\//, "path = ../../Source/RoomFinderAI/")

# Write the updated content back
File.write(project_file, content)

puts "✅ Updated all file paths to use ../../Source/RoomFinderAI/"
puts "✅ Build system should now find files at correct location"