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

# Also check for any missing files that should exist
actual_files = [
  'RoomFinderAI/Models/User.swift',
  'RoomFinderAI/Models/Listing.swift',
  'RoomFinderAI/Views/ListingsView.swift',
  'RoomFinderAI/Views/PropertyDetailView.swift',
  'RoomFinderAI/Utils/Constants.swift',
  'RoomFinderAI/Utils/Extensions.swift'
]

actual_files.each do |relative_path|
  full_path = project_dir.join(relative_path)
  
  if File.exist?(full_path)
    # Check if this file is referenced in project
    existing = project.files.find { |f| f.path&.end_with?(File.basename(relative_path)) && f.path == relative_path }
    
    unless existing
      puts "➕ Adding missing file: #{relative_path}"
      
      # Find the appropriate group
      group_name = relative_path.split('/')[1] # Models, Views, Utils, etc.
      main_group = project.main_group
      roomfinder_group = main_group['RoomFinderAI'] || main_group.new_group('RoomFinderAI')
      target_group = roomfinder_group[group_name] || roomfinder_group.new_group(group_name)
      
      # Add file reference
      file_ref = target_group.new_reference(relative_path)
      
      # Add to target
      target = project.targets.find { |t| t.name == "RoomFinderAI" }
      target.add_file_references([file_ref]) if target
    end
  else
    puts "⚠️  File doesn't exist: #{full_path}"
  end
end

# Save the project
project.save

puts "\n✅ Fixed all duplicate path references!"