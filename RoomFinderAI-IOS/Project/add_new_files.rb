#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Find the source group
source_group = project.main_group.find_subpath('RoomFinderAI/Source/RoomFinderAI', true)

# Add ErrorHandler.swift to Utils group
utils_group = source_group.find_subpath('Utils', true)
error_handler_path = 'RoomFinderAI/Source/RoomFinderAI/Utils/ErrorHandler.swift'
error_handler_ref = utils_group.new_reference(error_handler_path)
target.source_build_phase.add_file_reference(error_handler_ref)

# Add StripeService.swift to Services group  
services_group = source_group.find_subpath('Services', true)
stripe_service_path = 'RoomFinderAI/Source/RoomFinderAI/Services/StripeService.swift'
stripe_service_ref = services_group.new_reference(stripe_service_path)
target.source_build_phase.add_file_reference(stripe_service_ref)

# Save the project
project.save

puts "Added ErrorHandler.swift and StripeService.swift to Xcode project"