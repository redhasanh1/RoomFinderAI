#!/usr/bin/env ruby

# Debug and fix the assets path issue

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

puts "=== Debug Assets Path Issue ==="
puts "Current working directory: #{Dir.pwd}"
puts "Project file: #{project_file}"

# Check current assets path in project file
assets_match = content.match(/path = ([^;]+Assets\.xcassets)/)
if assets_match
  puts "Current assets path in project: #{assets_match[1]}"
end

# The issue might be that the build system is incorrectly resolving the path
# Let's check if there's an absolute path issue
puts "\nChecking if ../Source/RoomFinderAI/Resources/Assets.xcassets exists from Project dir:"
puts File.exist?("Project/../Source/RoomFinderAI/Resources/Assets.xcassets")

puts "\nChecking if Source/RoomFinderAI/Resources/Assets.xcassets exists from current dir:"
puts File.exist?("Source/RoomFinderAI/Resources/Assets.xcassets")

# The issue could be that Xcode is interpreting the sourceTree incorrectly
# Let's try changing the sourceTree from "<group>" to "SOURCE_ROOT"
puts "\n=== Fixing Assets Path ==="

# Change the assets reference to use SOURCE_ROOT instead of <group>
content.gsub!(/path = \.\.\/Source\/RoomFinderAI\/Resources\/Assets\.xcassets; sourceTree = "<group>";/) do |match|
  puts "  - Changing sourceTree from <group> to SOURCE_ROOT for assets"
  'path = Source/RoomFinderAI/Resources/Assets.xcassets; sourceTree = SOURCE_ROOT;'
end

# Write the updated content back
File.write(project_file, content)

puts "✅ Updated assets path to use SOURCE_ROOT"
puts "✅ This should resolve the path correctly"