#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Analyzing project structure..."

# List all build files in all targets
project.targets.each do |target|
  puts "\nTarget: #{target.name}"
  puts "Build files count: #{target.source_build_phase.files.count}"
  
  missing_files = []
  
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref
      file_path = build_file.file_ref.path || build_file.file_ref.name || "Unknown"
      
      # Try multiple ways to check if file exists
      exists = false
      
      begin
        # Method 1: real_path
        real_path = build_file.file_ref.real_path
        exists = File.exist?(real_path.to_s) if real_path
      rescue
        # Method 2: construct path manually
        if build_file.file_ref.path
          # Check various possible locations
          possible_paths = [
            File.join(Dir.pwd, build_file.file_ref.path),
            File.join(Dir.pwd, 'RoomFinderAI', build_file.file_ref.path),
            File.join(Dir.pwd, 'RoomFinderAI', 'Source', build_file.file_ref.path),
            File.join(Dir.pwd, '..', 'Source', build_file.file_ref.path),
            build_file.file_ref.path # absolute path
          ]
          
          exists = possible_paths.any? { |p| File.exist?(p) }
        end
      end
      
      unless exists
        missing_files << build_file
        puts "  ❌ Missing: #{file_path}"
      end
    end
  end
  
  if missing_files.any?
    puts "\nRemoving #{missing_files.count} missing files from target..."
    missing_files.each do |build_file|
      build_file.remove_from_project
    end
  end
end

# Save the project
project.save

puts "\n✅ Project file cleaned"