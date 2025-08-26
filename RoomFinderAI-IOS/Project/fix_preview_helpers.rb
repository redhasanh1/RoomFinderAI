#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'RoomFinderAI' }

# Just add the file directly to the target
file_path = 'RoomFinderAI-IOS/Source/RoomFinderAI/Config/PreviewHelpers.swift'

# Create file reference
file_ref = project.new_file(file_path)

# Add to target
target.add_file_references([file_ref])

puts "✅ Added PreviewHelpers.swift to project"

# Save the project
project.save
puts "✅ Project saved!"