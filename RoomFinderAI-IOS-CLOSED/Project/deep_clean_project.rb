#!/usr/bin/env ruby

require 'xcodeproj'
require 'fileutils'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Deep cleaning project..."

# Function to check if a path exists in any form
def file_exists_anywhere?(file_ref, project_dir)
  return false unless file_ref
  
  # Get the path
  path = file_ref.path || file_ref.name
  return false unless path
  
  # List of possible base directories
  base_dirs = [
    project_dir,
    File.join(project_dir, 'RoomFinderAI'),
    File.join(project_dir, 'RoomFinderAI', 'Source'),
    File.join(project_dir, 'RoomFinderAI', 'Source', 'RoomFinderAI'),
    File.join(project_dir, '..', 'Source'),
    File.join(project_dir, '..', 'Source', 'RoomFinderAI'),
    File.dirname(project_dir) # parent directory
  ]
  
  # Check absolute path first
  return true if File.exist?(path)
  
  # Check relative to each base directory
  base_dirs.each do |base|
    test_path = File.join(base, path)
    return true if File.exist?(test_path)
  end
  
  # Check if it's in one of the known good locations
  filename = File.basename(path)
  base_dirs.each do |base|
    Dir.glob(File.join(base, '**', filename)).each do |found|
      return true if File.exist?(found)
    end
  end
  
  false
end

project_dir = Dir.pwd
total_removed = 0

# Clean each target
project.targets.each do |target|
  puts "\nProcessing target: #{target.name}"
  
  # Check source build phase
  if target.source_build_phase
    files_to_remove = []
    
    target.source_build_phase.files.each do |build_file|
      next unless build_file.file_ref
      
      unless file_exists_anywhere?(build_file.file_ref, project_dir)
        path = build_file.file_ref.path || build_file.file_ref.name || "Unknown"
        puts "  ❌ Removing missing file: #{path}"
        files_to_remove << build_file
      else
        path = build_file.file_ref.path || build_file.file_ref.name || "Unknown"
        puts "  ✅ Found: #{File.basename(path)}"
      end
    end
    
    files_to_remove.each do |build_file|
      build_file.remove_from_project
      total_removed += 1
    end
  end
  
  # Check resources build phase
  if target.resources_build_phase
    files_to_remove = []
    
    target.resources_build_phase.files.each do |build_file|
      next unless build_file.file_ref
      
      unless file_exists_anywhere?(build_file.file_ref, project_dir)
        path = build_file.file_ref.path || build_file.file_ref.name || "Unknown"
        puts "  ❌ Removing missing resource: #{path}"
        files_to_remove << build_file
      end
    end
    
    files_to_remove.each do |build_file|
      build_file.remove_from_project
      total_removed += 1
    end
  end
end

# Clean up file references that aren't in any target
puts "\nCleaning orphaned file references..."
orphaned = 0

project.files.select { |f| f.path }.each do |file_ref|
  # Skip if it's a group or special file
  next if file_ref.path.nil? || file_ref.path.empty?
  next if file_ref.isa == 'PBXGroup'
  
  # Check if file exists
  unless file_exists_anywhere?(file_ref, project_dir)
    puts "  ❌ Removing orphaned reference: #{file_ref.path}"
    file_ref.remove_from_project
    orphaned += 1
  end
end

# Save the project
project.save

puts "\n✅ Deep clean complete!"
puts "   Removed #{total_removed} missing build files"
puts "   Removed #{orphaned} orphaned file references"
puts "\nProject should now be clean of missing file references."