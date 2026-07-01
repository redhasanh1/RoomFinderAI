#!/usr/bin/env ruby

# Comprehensive fix for all file path and display name issues in Xcode project

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

puts "=== Starting Comprehensive Path Fix ==="

# Phase 1: Fix all PBXGroup file references to show clean names
puts "Phase 1: Fixing PBXGroup file display names..."

# Fix all file references in PBXGroup sections that still show Source paths
content.gsub!(/([A-F0-9]+) \/\* (\.\.\/Source\/RoomFinderAI\/[^*]+) \*\//) do |match|
  id = $1
  full_path = $2
  filename = File.basename(full_path)
  puts "  - Fixed: #{full_path} -> #{filename}"
  "#{id} /* #{filename} */"
end

# Phase 2: Fix file paths to work with build system
puts "Phase 2: Fixing file paths for build system..."

# The build system expects paths relative to the project file location
# Since project file is in Project/ folder, we need to go up one level, then into Source
# Change from ../Source/RoomFinderAI/ to ../../Source/RoomFinderAI/
content.gsub!(/path = \.\.\/Source\/RoomFinderAI\//) do |match|
  puts "  - Fixed path: #{match} -> ../../Source/RoomFinderAI/"
  "path = ../../Source/RoomFinderAI/"
end

# Phase 3: Fix any remaining inconsistencies
puts "Phase 3: Fixing remaining inconsistencies..."

# Ensure all file names are clean in build file references
content.gsub!(/\/\* (\.\.\/\.\.\/Source\/RoomFinderAI\/[^*]+) in Sources \*\//) do |match|
  full_path = $1
  filename = File.basename(full_path)
  puts "  - Fixed build ref: #{full_path} -> #{filename}"
  "/* #{filename} in Sources */"
end

content.gsub!(/\/\* (\.\.\/\.\.\/Source\/RoomFinderAI\/[^*]+) in Resources \*\//) do |match|
  full_path = $1
  filename = File.basename(full_path)
  puts "  - Fixed resource ref: #{full_path} -> #{filename}"
  "/* #{filename} in Resources */"
end

# Write the updated content back
File.write(project_file, content)

puts "=== Comprehensive Path Fix Complete ==="
puts "✅ All file display names should now be clean"
puts "✅ All file paths should now work with build system"
puts "✅ Project is ready for testing"