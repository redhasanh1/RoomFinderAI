#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find Assets.xcassets reference
project.files.each do |file_ref|
  next unless file_ref.path&.include?('Assets.xcassets')
  
  puts "Found: #{file_ref.path}"
  
  # Fix the path
  file_ref.path = 'Resources/Assets.xcassets'
  
  puts "Updated to: #{file_ref.path}"
end

# Save
project.save

puts "✅ Fixed assets path!"