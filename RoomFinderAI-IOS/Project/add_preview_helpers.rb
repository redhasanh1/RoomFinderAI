#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'RoomFinderAI' }

# Find the Config group
roomfinder_group = project.main_group
  .children
  .find { |g| g.name == 'RoomFinderAI' }

source_group = roomfinder_group
  &.children
  &.find { |g| g.name == 'Source' }

config_group = source_group
  &.children
  &.find { |g| g.name == 'RoomFinderAI' }
  &.children
  &.find { |g| g.name == 'Config' }

# If not found, try the top-level path
if config_group.nil?
  config_group = roomfinder_group
    &.children
    &.find { |g| g.name == 'Config' }
end

if config_group
  # Path to the file
  file_path = 'RoomFinderAI-IOS/Source/RoomFinderAI/Config/PreviewHelpers.swift'
  
  # Create file reference
  file_ref = config_group.new_file(file_path)
  
  # Add to target
  target.add_file_references([file_ref])
  
  puts "✅ Added PreviewHelpers.swift to project"
else
  puts "❌ Could not find Config group"
end

# Save the project
project.save
puts "✅ Project saved!"