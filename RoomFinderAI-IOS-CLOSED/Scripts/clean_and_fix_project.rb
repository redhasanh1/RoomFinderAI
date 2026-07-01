#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'RoomFinderAI' }
main_group = project.main_group['RoomFinderAI']

puts "Removing all incorrectly added files from project..."

# Remove all files with double paths from the project
files_to_remove = []
project.files.each do |file_ref|
  if file_ref.path && file_ref.path.include?('RoomFinderAI/RoomFinderAI/')
    files_to_remove << file_ref
    puts "Removing: #{file_ref.path}"
  end
end

files_to_remove.each { |file| file.remove_from_project }

puts "Removed #{files_to_remove.count} files with incorrect paths"

# Clean the project
project.save

puts "Project cleaned successfully!"