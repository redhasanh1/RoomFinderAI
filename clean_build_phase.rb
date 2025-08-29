#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🧹 Cleaning build phase duplicates..."

# Get the main target
target = project.targets.find { |t| t.name == "RoomFinderAI" }

if target&.source_build_phase
  puts "Current source files: #{target.source_build_phase.files.count}"
  
  # Get unique file references by path
  seen_paths = Set.new
  files_to_remove = []
  
  target.source_build_phase.files.each do |build_file|
    file_path = build_file.file_ref&.path
    
    if file_path
      if seen_paths.include?(file_path)
        puts "  Duplicate: #{file_path}"
        files_to_remove << build_file
      else
        seen_paths.add(file_path)
        puts "  Keep: #{file_path}"
      end
    end
  end
  
  # Remove duplicates
  files_to_remove.each do |build_file|
    target.source_build_phase.files.delete(build_file)
  end
  
  puts "Removed #{files_to_remove.count} duplicate source file references"
  puts "Final source files count: #{target.source_build_phase.files.count}"
end

if target&.resources_build_phase
  puts "\nCurrent resource files: #{target.resources_build_phase.files.count}"
  
  # Get unique file references by path
  seen_paths = Set.new
  files_to_remove = []
  
  target.resources_build_phase.files.each do |build_file|
    file_path = build_file.file_ref&.path
    
    if file_path
      if seen_paths.include?(file_path)
        puts "  Duplicate: #{file_path}"
        files_to_remove << build_file
      else
        seen_paths.add(file_path)
        puts "  Keep: #{file_path}"
      end
    end
  end
  
  # Remove duplicates
  files_to_remove.each do |build_file|
    target.resources_build_phase.files.delete(build_file)
  end
  
  puts "Removed #{files_to_remove.count} duplicate resource file references"
  puts "Final resource files count: #{target.resources_build_phase.files.count}"
end

# Save the project
project.save

puts "✅ Cleaned build phases!"