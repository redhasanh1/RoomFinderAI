#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Remove any existing references to these files first
files_to_remove = ['ErrorHandler.swift', 'StripeService.swift']
files_to_remove.each do |filename|
  project.files.each do |file|
    if file.path&.end_with?(filename)
      puts "Removing incorrect reference to: #{file.path}"
      file.remove_from_project
    end
  end
end

# Find the correct source group
source_group = project.main_group.find_subpath('RoomFinderAI/Source/RoomFinderAI', true)

# Add ErrorHandler.swift with correct path
utils_group = source_group.find_subpath('Utils', true)
error_handler_ref = utils_group.new_reference('ErrorHandler.swift')
error_handler_ref.source_tree = '<group>'
target.source_build_phase.add_file_reference(error_handler_ref)

# Add StripeService.swift with correct path
services_group = source_group.find_subpath('Services', true) 
stripe_service_ref = services_group.new_reference('StripeService.swift')
stripe_service_ref.source_tree = '<group>'
target.source_build_phase.add_file_reference(stripe_service_ref)

# Save the project
project.save

puts "Fixed file paths in Xcode project"