#!/usr/bin/env ruby

# Fix file names to show just filename instead of full path

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

# Fix all file references that have "../Source/RoomFinderAI/" in the name
content.gsub!(/name = "\.\.\/Source\/RoomFinderAI\/[^"]*\/([^"\/]+)";/) do |match|
  filename = $1
  "name = \"#{filename}\";"
end

# Fix any remaining "../Source/RoomFinderAI/" references in names
content.gsub!(/name = "\.\.\/Source\/RoomFinderAI\/([^"]+)";/) do |match|
  filename = $1
  "name = \"#{filename}\";"
end

# Write the updated content back
File.write(project_file, content)

puts "Fixed all file names to show just filename!"