#!/usr/bin/env ruby

# Fix file names in Xcode to show just the filename without path

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

# Fix PBXFileReference entries that have full paths in the name
content.gsub!(/([A-F0-9]+) \/\* (\.\.\/\.\.\/Source\/RoomFinderAI\/[^*]+) \*\/ = \{isa = PBXFileReference[^}]+path = [^;]+;/) do |match|
  id = $1
  full_path = $2
  filename = File.basename(full_path)
  
  # Keep the original match but replace the comment with just the filename
  match.gsub(full_path, filename)
end

# Fix PBXBuildFile entries that have full paths in the name
content.gsub!(/([A-F0-9]+) \/\* (\.\.\/\.\.\/Source\/RoomFinderAI\/[^*]+) in Sources \*\/ = \{isa = PBXBuildFile[^}]+\};/) do |match|
  id = $1
  full_path = $2
  filename = File.basename(full_path)
  
  # Keep the original match but replace the comment with just the filename
  match.gsub(full_path, filename)
end

# Fix PBXBuildFile entries for Resources
content.gsub!(/([A-F0-9]+) \/\* (\.\.\/\.\.\/Source\/RoomFinderAI\/[^*]+) in Resources \*\/ = \{isa = PBXBuildFile[^}]+\};/) do |match|
  id = $1
  full_path = $2
  filename = File.basename(full_path)
  
  # Keep the original match but replace the comment with just the filename
  match.gsub(full_path, filename)
end

# Write the updated content back
File.write(project_file, content)

puts "Fixed all file names to show just filenames!"
puts "Files should now show clean names like 'ProfileView.swift' instead of full paths"