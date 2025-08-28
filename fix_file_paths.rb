#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == "RoomFinderAI" }

# Find and fix the file references
files_to_fix = ['Secrets.swift', 'SupabaseEnvironment.swift']

project.files.each do |file_ref|
  next unless file_ref.path
  
  filename = File.basename(file_ref.path)
  
  if files_to_fix.include?(filename)
    puts "Found #{file_ref.path}"
    
    # Fix the path - should be just filename without RoomFinderAI/ prefix
    file_ref.path = filename
    
    puts "Updated to: #{file_ref.path}"
  end
end

# Save the project
project.save

puts "✅ Fixed file paths in Xcode project!"