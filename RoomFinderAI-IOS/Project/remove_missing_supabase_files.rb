#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Files to remove
files_to_remove = [
  'SupabaseClientProvider.swift',
  'SupabaseConfig.swift'
]

removed_count = 0

# Remove file references
project.files.each do |file|
  if files_to_remove.include?(file.display_name)
    puts "Removing reference: #{file.display_name} (#{file.real_path})"
    file.remove_from_project
    removed_count += 1
  end
end

# Remove from build phases
project.targets.each do |target|
  target.source_build_phase.files_references.each do |file|
    if file && files_to_remove.include?(file.display_name)
      puts "Removing from build phase: #{file.display_name}"
      target.source_build_phase.remove_file_reference(file)
    end
  end
end

# Save the project
if removed_count > 0
  project.save
  puts "\nSuccessfully removed #{removed_count} missing file references!"
else
  puts "\nNo matching files found to remove."
end