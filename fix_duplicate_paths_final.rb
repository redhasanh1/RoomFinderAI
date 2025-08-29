#!/usr/bin/env ruby

require 'xcodeproj'
require 'pathname'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)
project_dir = Pathname.new(File.dirname(project_path))

puts "🔍 Looking for duplicate path issues..."

# Find all file references with duplicate paths
files_to_fix = []

project.files.each do |file_ref|
  next unless file_ref.path
  
  path = file_ref.path
  
  # Check if path has duplicate segments
  if path.include?('RoomFinderAI/Models/RoomFinderAI/Models') ||
     path.include?('RoomFinderAI/Views/RoomFinderAI/Views') ||
     path.include?('RoomFinderAI/Utils/RoomFinderAI/Utils') ||
     path.include?('RoomFinderAI/Services/RoomFinderAI/Services') ||
     path.include?('RoomFinderAI/Resources/RoomFinderAI/Resources') ||
     path.include?('RoomFinderAI/Components/RoomFinderAI/Components')
    
    files_to_fix << file_ref
    puts "❌ Found duplicate path: #{path}"
  end
end

puts "\n🔧 Fixing #{files_to_fix.length} file references..."

# Fix the paths
files_to_fix.each do |file_ref|
  old_path = file_ref.path
  
  # Remove duplicate segments
  new_path = old_path.gsub(/RoomFinderAI\/(Models|Views|Utils|Services|Resources|Components)\/RoomFinderAI\/\1\//, 'RoomFinderAI/\1/')
  
  file_ref.path = new_path
  puts "✅ Fixed: #{old_path} -> #{new_path}"
end

# Check the actual file structure and ensure files exist
puts "\n🔍 Checking actual files..."

# Look for the actual files we need
base_dir = project_dir.join('RoomFinderAI')

[
  'Models/User.swift',
  'Models/Listing.swift',
  'Views/ListingsView.swift',
  'Views/PropertyDetailView.swift',
  'Utils/Constants.swift',
  'Utils/Extensions.swift'
].each do |relative_path|
  full_path = base_dir.join(relative_path)
  
  puts "Checking: #{full_path}"
  
  if File.exist?(full_path)
    puts "✅ File exists: #{relative_path}"
    
    # Check if this file is in the project with correct path
    correct_project_path = "RoomFinderAI/#{relative_path}"
    
    existing = project.files.find { |f| f.path == correct_project_path }
    
    if existing
      puts "✅ File correctly referenced in project"
    else
      puts "➕ Need to add file to project: #{correct_project_path}"
      
      # Find the appropriate group
      parts = relative_path.split('/')
      group_name = parts[0] # Models, Views, Utils
      
      main_group = project.main_group
      roomfinder_group = main_group['RoomFinderAI'] || main_group.new_group('RoomFinderAI')
      target_group = roomfinder_group[group_name] || roomfinder_group.new_group(group_name)
      
      # Add file reference
      file_ref = target_group.new_reference(correct_project_path)
      
      # Add to target
      target = project.targets.find { |t| t.name == "RoomFinderAI" }
      if target
        target.add_file_references([file_ref])
        puts "✅ Added #{relative_path} to project and target"
      end
    end
  else
    puts "❌ File missing: #{full_path}"
  end
end

# Save the project
project.save

puts "\n✅ Fixed all duplicate path references and updated project!"