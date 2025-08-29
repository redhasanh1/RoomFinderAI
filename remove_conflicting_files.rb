#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🗑️ Removing conflicting separate view files to keep comprehensive RoomFinderAIApp.swift..."

# Get the main target
target = project.targets.find { |t| t.name == "RoomFinderAI" }

# Files to remove from the build (they're included in the comprehensive RoomFinderAIApp.swift)
conflicting_files = [
  'ChatView.swift',
  'ContentView.swift', # This is also included in RoomFinderAIApp.swift
  'ListingsView.swift',
  'PropertyDetailView.swift'
]

if target&.source_build_phase
  files_to_remove = []
  
  target.source_build_phase.files.each do |build_file|
    file_ref = build_file.file_ref
    next unless file_ref
    
    filename = File.basename(file_ref.path || "")
    
    if conflicting_files.include?(filename)
      puts "  🗑️ Removing from build: #{filename}"
      files_to_remove << build_file
    end
  end
  
  # Remove from build phase
  files_to_remove.each do |build_file|
    target.source_build_phase.files.delete(build_file)
  end
  
  puts "Removed #{files_to_remove.count} conflicting files from build phase"
end

# Also remove file references from groups to avoid confusion
def remove_file_refs_from_group(group, conflicting_files)
  files_to_remove = []
  
  group.children.each do |child|
    if child.is_a?(Xcodeproj::Project::Object::PBXFileReference)
      filename = File.basename(child.path || "")
      
      if conflicting_files.include?(filename)
        puts "  🗑️ Removing file reference: #{filename}"
        files_to_remove << child
      end
    elsif child.is_a?(Xcodeproj::Project::Object::PBXGroup)
      # Recursively clean subgroups
      remove_file_refs_from_group(child, conflicting_files)
    end
  end
  
  # Remove file references
  files_to_remove.each do |file_ref|
    group.children.delete(file_ref)
  end
end

# Remove file references from all groups
remove_file_refs_from_group(project.main_group, conflicting_files)

puts "\n💾 Saving cleaned project..."
project.save

puts "✅ Conflicting files removed! The comprehensive RoomFinderAIApp.swift now has no conflicts."