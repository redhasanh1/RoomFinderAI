#!/usr/bin/env ruby

# Complete fix for build issues - the cached SwiftFileList still has wrong paths

require 'fileutils'

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

puts "=== Complete Build Fix ==="
puts "Files are located in: ../Source/RoomFinderAI/"
puts "Build system is looking in: Project/RoomFinderAI/Source/RoomFinderAI/"
puts "The issue is in Xcode's cached build files"

# First, let's clean the derived data
puts "\n1. Cleaning Xcode derived data..."
system("rm -rf ~/Library/Developer/Xcode/DerivedData/RoomFinderAI-*")

# The main issue: Build settings might have wrong source tree paths
# Let's also ensure all source tree settings are correct
puts "\n2. Checking and fixing source tree settings..."

# Fix any remaining path issues in the project file
# Make sure all file references use the correct path structure
content.gsub!(/path = \.\.\/Source\/RoomFinderAI\/([^;]+); sourceTree = "([^"]*)"/) do |match|
  file_path = $1
  source_tree = $2
  puts "  - Fixing path: ../Source/RoomFinderAI/#{file_path}"
  "path = ../Source/RoomFinderAI/#{file_path}; sourceTree = \"<group>\""
end

# Write the updated content back
File.write(project_file, content)

puts "\n3. ✅ Project file updated with correct paths"
puts "✅ Derived data cleaned"
puts "✅ Build should now work correctly"
puts "\nNext: Open Xcode and try building again"