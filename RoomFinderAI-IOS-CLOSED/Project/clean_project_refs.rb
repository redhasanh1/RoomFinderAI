#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🧹 Cleaning up old file references..."

# Find and remove all references to SupabaseListingsService.swift
removed_count = 0

# Remove from build files
project.objects.each do |uuid, obj|
  if obj.isa == 'PBXBuildFile' && obj.file_ref && obj.file_ref.path&.include?('SupabaseListingsService.swift')
    puts "Removing build file reference to SupabaseListingsService.swift"
    
    # Remove from target build phases
    project.targets.each do |target|
      target.build_phases.each do |phase|
        if phase.respond_to?(:files)
          phase.files.delete(obj)
        end
      end
    end
    
    project.objects.delete(uuid)
    removed_count += 1
  end
end

# Remove file references
project.objects.each do |uuid, obj|
  if obj.isa == 'PBXFileReference' && obj.path&.include?('SupabaseListingsService.swift')
    puts "Removing file reference to SupabaseListingsService.swift"
    
    # Remove from parent group
    if obj.parent
      obj.parent.children.delete(obj)
    end
    
    project.objects.delete(uuid)
    removed_count += 1
  end
end

puts "💾 Saving project..."
project.save

puts "✅ Cleaned up #{removed_count} references to SupabaseListingsService.swift"