#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'RoomFinderAI' }

# Find and remove the wrong reference
project.files.each do |file|
  if file.display_name == 'PreviewHelpers.swift' && file.real_path.to_s.include?('RoomFinderAI-IOS/Source')
    puts "Removing wrong reference: #{file.real_path}"
    file.remove_from_project
  end
end

# Add the correct reference
correct_path = 'Source/RoomFinderAI/Config/PreviewHelpers.swift'

# Check if already exists
existing = project.files.find { |f| f.real_path.to_s == correct_path }
if existing.nil?
  file_ref = project.new_file(correct_path)
  target.add_file_references([file_ref])
  puts "✅ Added correct PreviewHelpers.swift reference"
else
  puts "✅ PreviewHelpers.swift already correctly referenced"
end

# Save the project
project.save
puts "✅ Project saved!"