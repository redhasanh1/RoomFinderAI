#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = './App.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main app target
target = project.targets.find { |t| t.name == 'App' }

# Add new Swift files to the project
new_files = [
  'App/Services/SupabaseService.swift',
  'App/Services/DataValidationService.swift'
]

new_files.each do |file_path|
  if File.exist?(file_path)
    # Add the file to the project
    file_ref = project.main_group.find_subpath(File.dirname(file_path), true).new_reference(File.basename(file_path))
    file_ref.set_source_tree('<group>')
    
    # Add to the target's build phase
    target.add_file_references([file_ref])
    
    puts "✅ Added #{file_path} to Xcode project"
  else
    puts "❌ File not found: #{file_path}"
  end
end

# Save the project
project.save

puts "🎉 Successfully updated Xcode project with new files"