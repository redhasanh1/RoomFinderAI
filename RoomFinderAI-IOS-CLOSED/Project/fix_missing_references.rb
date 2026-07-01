#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Files to remove (missing files causing compilation errors)
files_to_remove = [
  'ErrorHandler.swift',
  'StripeService.swift'
]

files_to_remove.each do |filename|
  # Find and remove file references
  project.files.each do |file|
    if file.path&.end_with?(filename)
      puts "Removing reference to missing file: #{file.path}"
      file.remove_from_project
    end
  end
end

# Save the project
project.save

puts "Cleaned up missing file references from Xcode project"