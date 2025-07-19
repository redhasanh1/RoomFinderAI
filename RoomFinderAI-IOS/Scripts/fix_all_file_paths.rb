#!/usr/bin/env ruby

# Fix all file paths in the Xcode project to point to the correct locations

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

# Replace all "../Source/RoomFinderAI/" with "../../Source/RoomFinderAI/"
# This accounts for the Project folder being one level deeper
content.gsub!(/\.\.\/Source\/RoomFinderAI\//, "../../Source/RoomFinderAI/")

# Also fix any file names that still show the Source path
content.gsub!(/name = "\.\.\/\.\.\/Source\/RoomFinderAI\/[^"]*\/([^"\/]+)";/) do |match|
  filename = $1
  "name = \"#{filename}\";"
end

# Fix any remaining Source references in names
content.gsub!(/name = "\.\.\/\.\.\/Source\/RoomFinderAI\/([^"]+)";/) do |match|
  filename = $1.split('/').last
  "name = \"#{filename}\";"
end

# Write the updated content back
File.write(project_file, content)

puts "Fixed all file paths in the Xcode project!"
puts "Files should now point to ../../Source/RoomFinderAI/ instead of ../Source/RoomFinderAI/"