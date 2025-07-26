#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔧 Updating project files..."

# Find the main target
main_target = project.targets.find { |t| t.name == 'RoomFinderAI' }

# Remove the old SupabaseListingsService.swift reference
project.objects.each do |uuid, obj|
  if obj.respond_to?(:display_name) && obj.display_name == 'SupabaseListingsService.swift'
    puts "Removing old SupabaseListingsService.swift reference"
    # Remove from build phase
    main_target.source_build_phase.files.each do |build_file|
      if build_file.file_ref == obj
        main_target.source_build_phase.files.delete(build_file)
        project.objects.delete(build_file.uuid)
        break
      end
    end
    # Remove file reference
    if obj.parent
      obj.parent.children.delete(obj)
    end
    project.objects.delete(uuid)
    break
  end
end

# Add RealSupabaseService.swift
services_group = nil
project.main_group.recursive_children.each do |child|
  if child.class == Xcodeproj::Project::Object::PBXGroup && child.display_name == 'Services'
    services_group = child
    break
  end
end

if services_group
  real_supabase_path = '../Source/RoomFinderAI/Services/RealSupabaseService.swift'
  if File.exist?(real_supabase_path)
    real_supabase_ref = services_group.new_reference(real_supabase_path)
    real_supabase_ref.name = 'RealSupabaseService.swift'
    
    # Add to build phases
    build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.file_ref = real_supabase_ref
    main_target.source_build_phase.files << build_file
    
    puts "✅ Added RealSupabaseService.swift"
  end
end

puts "💾 Saving project..."
project.save

puts "✅ Project updated successfully!"