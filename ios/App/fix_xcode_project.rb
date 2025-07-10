#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = './App.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main app target
target = project.targets.find { |t| t.name == 'App' }

# Remove duplicate file references first
puts "🧹 Cleaning up duplicate file references..."

# Find Services group or create it
app_group = project.main_group.find_subpath('App', false)
if app_group
  services_group = app_group.find_subpath('Services', false)
  if !services_group
    services_group = app_group.new_group('Services')
  end
  
  # Check if files already exist and remove duplicates
  existing_files = services_group.files.map(&:display_name)
  
  ['SupabaseService.swift', 'DataValidationService.swift'].each do |filename|
    if existing_files.include?(filename)
      puts "⚠️  File #{filename} already exists in project, removing duplicates..."
      # Remove from build phases
      target.source_build_phase.files.each do |build_file|
        if build_file.file_ref && build_file.file_ref.display_name == filename
          target.source_build_phase.files.delete(build_file)
        end
      end
      
      # Remove file reference
      services_group.files.each do |file_ref|
        if file_ref.display_name == filename
          file_ref.remove_from_project
        end
      end
    end
    
    # Add the file reference
    file_ref = services_group.new_reference(filename)
    file_ref.set_source_tree('<group>')
    
    # Add to build phase
    target.add_file_references([file_ref])
    
    puts "✅ Added #{filename} to project"
  end
else
  puts "❌ Could not find App group in project"
end

# Save the project
project.save

puts "🎉 Successfully fixed Xcode project"