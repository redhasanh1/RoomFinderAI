#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🧹 Creating clean project structure..."

# Clear everything from the main group
main_group = project.main_group
main_group.children.clear

# Create a simple structure
roomfinder_group = main_group.new_group('RoomFinderAI', 'RoomFinderAI')
products_group = main_group.new_group('Products')

# Get the target
target = project.targets.find { |t| t.name == "RoomFinderAI" }

# Project directory
project_dir = File.dirname(project_path)
base_dir = File.join(project_dir, 'RoomFinderAI')

# Just add the essential files
essential_files = [
  'RoomFinderAIApp.swift',
  'Services/Secrets.swift'
]

added_count = 0

essential_files.each do |relative_path|
  full_path = File.join(base_dir, relative_path)
  
  if File.exist?(full_path)
    # Add file reference with just the filename (no path)
    file_ref = roomfinder_group.new_reference(File.basename(relative_path))
    
    # Add to target
    target.add_file_references([file_ref])
    
    puts "✅ Added: #{relative_path}"
    added_count += 1
  else
    puts "⚠️  File not found: #{full_path}"
  end
end

# Add SupabaseEnvironment.swift
supabase_env_path = File.join(base_dir, 'SupabaseEnvironment.swift')
if File.exist?(supabase_env_path)
  file_ref = roomfinder_group.new_reference('SupabaseEnvironment.swift')
  target.add_file_references([file_ref])
  puts "✅ Added: SupabaseEnvironment.swift"
  added_count += 1
end

# Add Resources
resources_group = roomfinder_group.new_group('Resources', 'Resources')

# Add Info.plist (but not to resources build phase)
info_plist_path = File.join(base_dir, 'Resources/Info.plist')
if File.exist?(info_plist_path)
  file_ref = resources_group.new_reference('Info.plist')
  puts "✅ Added: Info.plist (build setting only)"
  added_count += 1
end

# Add Assets.xcassets to resources build phase
assets_path = File.join(base_dir, 'Resources/Assets.xcassets')
if File.exist?(assets_path)
  file_ref = resources_group.new_reference('Assets.xcassets')
  target.add_resources([file_ref]) if target.resources_build_phase
  puts "✅ Added: Assets.xcassets"
  added_count += 1
end

# Save the project
project.save

puts "✅ Created clean project structure with #{added_count} files"