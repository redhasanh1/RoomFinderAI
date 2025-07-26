#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Track removed files
removed_files = []
missing_paths = []

# Check all file references in all targets
project.targets.each do |target|
  # Check source build phase
  target.source_build_phase.files_references.each do |file_ref|
    next unless file_ref
    
    # Get the full path
    full_path = file_ref.real_path.to_s rescue nil
    
    # If we can't get real_path, try to construct it
    if full_path.nil? || full_path.empty?
      if file_ref.path
        # Try to resolve the path relative to project
        test_paths = [
          File.join(File.dirname(project_path), file_ref.path),
          File.join(File.dirname(project_path), 'RoomFinderAI', file_ref.path),
          File.join(File.dirname(project_path), '..', file_ref.path)
        ]
        
        full_path = test_paths.find { |p| File.exist?(p) }
        full_path ||= test_paths.first # Use first path even if doesn't exist
      end
    end
    
    # Check if file exists
    if full_path && !File.exist?(full_path)
      puts "Missing file: #{full_path}"
      missing_paths << full_path
      
      # Find and remove the build file
      target.source_build_phase.files.each do |build_file|
        if build_file.file_ref == file_ref
          puts "  Removing from target: #{target.name}"
          build_file.remove_from_project
          removed_files << file_ref.path || file_ref.name || "Unknown"
          break
        end
      end
    end
  end
end

# Also check all file references in the project
puts "\nChecking all project file references..."
all_refs = project.files.select { |f| f.path }

all_refs.each do |file_ref|
  full_path = file_ref.real_path.to_s rescue nil
  
  if full_path.nil? || full_path.empty?
    if file_ref.path
      test_paths = [
        File.join(File.dirname(project_path), file_ref.path),
        File.join(File.dirname(project_path), 'RoomFinderAI', file_ref.path),
        File.join(File.dirname(project_path), '..', file_ref.path)
      ]
      
      full_path = test_paths.find { |p| File.exist?(p) }
      full_path ||= test_paths.first
    end
  end
  
  if full_path && !File.exist?(full_path)
    unless missing_paths.include?(full_path)
      puts "Orphaned file reference: #{file_ref.path}"
      file_ref.remove_from_project
      removed_files << (file_ref.path || file_ref.name || "Unknown")
    end
  end
end

# Save the project
project.save

puts "\n✅ Removed #{removed_files.uniq.count} missing file references from the project"
puts "\nMissing files that were removed:"
missing_paths.sort.each { |f| puts "  - #{f}" }