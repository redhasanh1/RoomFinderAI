#!/usr/bin/env ruby

require 'xcodeproj'
require 'pathname'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔍 Looking for duplicate files..."

# Track files by name to find duplicates
files_by_name = {}

project.files.each do |file_ref|
  next unless file_ref.path
  
  filename = File.basename(file_ref.path)
  files_by_name[filename] ||= []
  files_by_name[filename] << file_ref
end

# Find and fix duplicates
duplicates_found = 0

files_by_name.each do |filename, refs|
  if refs.length > 1
    puts "\n❌ Found #{refs.length} duplicates of: #{filename}"
    
    refs.each_with_index do |ref, index|
      puts "   #{index + 1}. #{ref.path}"
    end
    
    # Keep the first one, remove others
    refs_to_remove = refs[1..-1]
    
    refs_to_remove.each do |ref|
      puts "   🗑️  Removing: #{ref.path}"
      
      # Remove from all targets
      project.targets.each do |target|
        target.source_build_phase&.remove_file_reference(ref)
        target.resources_build_phase&.remove_file_reference(ref)
      end
      
      # Remove from project
      ref.remove_from_project
      duplicates_found += 1
    end
    
    puts "   ✅ Kept: #{refs.first.path}"
  end
end

if duplicates_found == 0
  puts "✅ No duplicates found!"
else
  puts "\n🔧 Removed #{duplicates_found} duplicate file references"
  
  # Save the project
  project.save
  puts "✅ Project saved successfully"
end