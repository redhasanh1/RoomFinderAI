#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "All file references in project:"
project.files.each do |file|
  if file.path&.include?('ErrorHandler') || file.path&.include?('StripeService')
    puts "File: #{file.path}, Source tree: #{file.source_tree}, Real path: #{file.real_path}"
  end
end

puts "\nTarget source files:"
target = project.targets.first
target.source_build_phase.files.each do |build_file|
  file_ref = build_file.file_ref
  if file_ref.path&.include?('ErrorHandler') || file_ref.path&.include?('StripeService')
    puts "Build file: #{file_ref.path}, Source tree: #{file_ref.source_tree}"
  end
end