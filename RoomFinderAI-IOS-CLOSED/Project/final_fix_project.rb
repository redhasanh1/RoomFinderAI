#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Remove all existing references to these files
files_to_remove = ['ErrorHandler.swift', 'StripeService.swift']
files_to_remove.each do |filename|
  # Remove from build phase
  target.source_build_phase.files.to_a.each do |build_file|
    if build_file.file_ref.path&.end_with?(filename)
      puts "Removing build file reference: #{build_file.file_ref.path}"
      build_file.remove_from_project
    end
  end
  
  # Remove file references
  project.files.each do |file|
    if file.path&.end_with?(filename)
      puts "Removing file reference: #{file.path}"
      file.remove_from_project
    end
  end
end

puts "Cleaned up all references to ErrorHandler.swift and StripeService.swift"

# Since the files exist and don't need to be added to the project,
# let's just ensure the build works
project.save