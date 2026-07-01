#!/usr/bin/env ruby

# Comprehensive fix for Xcode project file references and build issues

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

# Fix the PBXGroup display names - replace full paths with just filenames
content.gsub!(/([A-F0-9]+) \/\* (\.\.\/Source\/RoomFinderAI\/[^*]+) \*\//) do |match|
  id = $1
  full_path = $2
  filename = File.basename(full_path)
  "#{id} /* #{filename} */"
end

# Fix the PBXGroup references that still show full paths
content.gsub!(/(A01234567890123456789011 \/\* )\.\.\/Source\/RoomFinderAI\/RoomFinderAIApp\.swift( \*\/)/) do |match|
  "#{$1}RoomFinderAIApp.swift#{$2}"
end

content.gsub!(/(A01234567890123456789013 \/\* )\.\.\/Source\/RoomFinderAI\/ContentView\.swift( \*\/)/) do |match|
  "#{$1}ContentView.swift#{$2}"
end

# Fix all other file references in groups
[
  "A01234567890123456789027", "A01234567890123456789029", "A01234567890123456789031",
  "A01234567890123456789033", "A01234567890123456789035", "A01234567890123456789037",
  "A01234567890123456789017", "A01234567890123456789019", "A01234567890123456789021",
  "A01234567890123456789023", "A01234567890123456789025", "A01234567890123456789041",
  "A01234567890123456789043", "A01234567890123456789045", "A01234567890123456789047",
  "A01234567890123456789049", "A01234567890123456789051", "A01234567890123456789015",
  "A01234567890123456789053"
].each do |id|
  content.gsub!(/(#{id} \/\* )\.\.\/Source\/RoomFinderAI\/[^*]+\/([^*\/]+)( \*\/)/) do |match|
    "#{$1}#{$2}#{$3}"
  end
  content.gsub!(/(#{id} \/\* )\.\.\/Source\/RoomFinderAI\/([^*\/]+)( \*\/)/) do |match|
    "#{$1}#{$2}#{$3}"
  end
end

# Write the updated content back
File.write(project_file, content)

puts "Fixed all file display names in Xcode project!"
puts "Files should now show clean names without full paths in the navigator"