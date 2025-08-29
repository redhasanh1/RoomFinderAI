#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🧹 Removing all duplicate file references from Xcode project..."

# Get the main target
target = project.targets.find { |t| t.name == "RoomFinderAI" }

if target&.source_build_phase
  puts "Current source files: #{target.source_build_phase.files.count}"
  
  # Collect unique files by path, keeping only the first occurrence
  seen_files = {}
  files_to_remove = []
  
  target.source_build_phase.files.each do |build_file|
    file_ref = build_file.file_ref
    next unless file_ref
    
    # Use filename as the key for uniqueness
    filename = File.basename(file_ref.path || "unknown_#{build_file.uuid}")
    
    if seen_files[filename]
      puts "  🗑️  Duplicate: #{filename}"
      files_to_remove << build_file
    else
      seen_files[filename] = build_file
      puts "  ✅ Keep: #{filename}"
    end
  end
  
  # Remove all duplicate build files
  files_to_remove.each do |build_file|
    target.source_build_phase.files.delete(build_file)
  end
  
  puts "Removed #{files_to_remove.count} duplicate source file references"
  puts "Final source files count: #{target.source_build_phase.files.count}"
end

# Also clean resources build phase
if target&.resources_build_phase
  puts "\nCurrent resource files: #{target.resources_build_phase.files.count}"
  
  seen_files = {}
  files_to_remove = []
  
  target.resources_build_phase.files.each do |build_file|
    file_ref = build_file.file_ref
    next unless file_ref
    
    filename = File.basename(file_ref.path || "unknown")
    
    if seen_files[filename]
      puts "  🗑️  Duplicate resource: #{filename}"
      files_to_remove << build_file
    else
      seen_files[filename] = build_file
      puts "  ✅ Keep resource: #{filename}"
    end
  end
  
  files_to_remove.each do |build_file|
    target.resources_build_phase.files.delete(build_file)
  end
  
  puts "Removed #{files_to_remove.count} duplicate resource file references"
  puts "Final resource files count: #{target.resources_build_phase.files.count}"
end

# Now also remove any duplicate file references from groups (not just build phases)
puts "\n🧹 Cleaning duplicate file references from project groups..."

def clean_group_recursively(group, seen_files = {})
  files_to_remove = []
  
  group.children.each do |child|
    if child.is_a?(Xcodeproj::Project::Object::PBXFileReference)
      filename = File.basename(child.path || "unknown")
      
      if seen_files[filename]
        puts "  🗑️  Duplicate file ref: #{filename}"
        files_to_remove << child
      else
        seen_files[filename] = child
        puts "  ✅ Keep file ref: #{filename}"
      end
    elsif child.is_a?(Xcodeproj::Project::Object::PBXGroup)
      # Recursively clean subgroups
      clean_group_recursively(child, seen_files)
    end
  end
  
  # Remove duplicates
  files_to_remove.each do |file_ref|
    group.children.delete(file_ref)
  end
  
  seen_files
end

# Clean all groups starting from main group
clean_group_recursively(project.main_group)

puts "\n💾 Saving cleaned project..."
project.save

puts "✅ Project cleanup complete! All duplicates removed."