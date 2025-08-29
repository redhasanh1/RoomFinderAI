#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

file_path = 'Source/RoomFinderAI/Views/ListingsScreen.swift'

existing_file = project.files.find { |f| f.path == file_path }
if existing_file
  puts "#{file_path} already exists in project"
else
  puts "Adding #{file_path} to project"
  file_ref = project.new_file(file_path)
  target.add_file_references([file_ref])
  project.save
  puts "Added successfully"
end