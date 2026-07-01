#!/usr/bin/env ruby

# Fix all file paths in the Xcode project

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

# Fix all variations of incorrect paths
replacements = [
  # Fix the main issue - files with Project/ prefix
  ['/Project/RoomFinderAI/Source/RoomFinderAI/', '../Source/RoomFinderAI/'],
  ['/Project/Source/RoomFinderAI/', '../Source/RoomFinderAI/'],
  ['Project/RoomFinderAI/Source/RoomFinderAI/', '../Source/RoomFinderAI/'],
  ['Project/Source/RoomFinderAI/', '../Source/RoomFinderAI/'],
  
  # Fix any remaining absolute paths
  ['/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/', '../Source/RoomFinderAI/'],
  ['/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/Source/RoomFinderAI/', '../Source/RoomFinderAI/'],
  
  # Fix assets path
  ['/Project/RoomFinderAI/Source/RoomFinderAI/Resources/Assets.xcassets', '../Source/RoomFinderAI/Resources/Assets.xcassets'],
  ['Project/RoomFinderAI/Source/RoomFinderAI/Resources/Assets.xcassets', '../Source/RoomFinderAI/Resources/Assets.xcassets'],
]

replacements.each do |old_path, new_path|
  content.gsub!(old_path, new_path)
end

# Write the updated content back
File.write(project_file, content)

puts "Fixed all file paths in project file!"
puts "Replacements made: #{replacements.count}"