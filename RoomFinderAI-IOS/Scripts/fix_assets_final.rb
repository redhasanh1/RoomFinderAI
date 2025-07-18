#!/usr/bin/env ruby

# Final fix for assets path - use the correct relative path

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

puts "=== Final Assets Path Fix ==="
puts "Working directory during build: /RoomFinderAI-IOS/Project/"
puts "Assets are at: /RoomFinderAI-IOS/Source/RoomFinderAI/Resources/Assets.xcassets"
puts "So relative path should be: ../Source/RoomFinderAI/Resources/Assets.xcassets"

# Change back to using relative path with <group> source tree
content.gsub!(/path = Source\/RoomFinderAI\/Resources\/Assets\.xcassets; sourceTree = SOURCE_ROOT;/) do |match|
  puts "  - Changing back to relative path with <group> sourceTree"
  'path = ../Source/RoomFinderAI/Resources/Assets.xcassets; sourceTree = "<group>";'
end

# Write the updated content back
File.write(project_file, content)

puts "✅ Updated assets to use correct relative path"
puts "✅ Path: ../Source/RoomFinderAI/Resources/Assets.xcassets"

# Let's also verify the path exists
assets_path = "Source/RoomFinderAI/Resources/Assets.xcassets"
if File.directory?(assets_path)
  puts "✅ Verified: Assets.xcassets directory exists"
  
  # Check if AppIcon exists
  appicon_path = File.join(assets_path, "AppIcon.appiconset")
  if File.directory?(appicon_path)
    puts "✅ Verified: AppIcon.appiconset exists"
  else
    puts "❌ Warning: AppIcon.appiconset missing"
  end
  
  # Check if AccentColor exists
  accent_path = File.join(assets_path, "AccentColor.colorset")
  if File.directory?(accent_path)
    puts "✅ Verified: AccentColor.colorset exists"
  else
    puts "❌ Warning: AccentColor.colorset missing"
  end
else
  puts "❌ Error: Assets.xcassets directory not found at #{assets_path}"
end