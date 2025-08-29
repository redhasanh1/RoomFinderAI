#!/usr/bin/env ruby

require 'xcodeproj'
require 'pathname'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)
project_dir = Pathname.new(File.dirname(project_path))

puts "🔧 Comprehensive Build Fix Starting..."

# Remove ALL existing file references first
puts "\n1️⃣ Removing all existing file references..."
removed_count = 0

project.files.to_a.each do |file_ref|
  next unless file_ref.path
  
  # Skip if it's a package dependency or not a Swift file
  next if file_ref.path.include?('Package') || file_ref.path.include?('.bundle')
  next unless file_ref.path.end_with?('.swift') || file_ref.path.end_with?('.xcassets') || file_ref.path.end_with?('.plist')
  
  puts "   Removing: #{file_ref.path}"
  
  # Remove from all targets
  project.targets.each do |target|
    target.source_build_phase&.remove_file_reference(file_ref)
    target.resources_build_phase&.remove_file_reference(file_ref)
  end
  
  # Remove from project
  file_ref.remove_from_project
  removed_count += 1
end

puts "   ✅ Removed #{removed_count} file references"

# Now add files correctly
puts "\n2️⃣ Adding files with correct paths..."

# Get the target
target = project.targets.find { |t| t.name == "RoomFinderAI" }

# Get the main group
main_group = project.main_group
roomfinder_group = main_group['RoomFinderAI'] || main_group.new_group('RoomFinderAI')

# Create subgroups
groups = {
  'Models' => roomfinder_group['Models'] || roomfinder_group.new_group('Models'),
  'Views' => roomfinder_group['Views'] || roomfinder_group.new_group('Views'),
  'Utils' => roomfinder_group['Utils'] || roomfinder_group.new_group('Utils'),
  'Services' => roomfinder_group['Services'] || roomfinder_group.new_group('Services'),
  'Resources' => roomfinder_group['Resources'] || roomfinder_group.new_group('Resources')
}

# Files to add with their correct paths
files_to_add = []

# Scan the actual directory structure
base_dir = project_dir.join('RoomFinderAI')

Dir.glob("#{base_dir}/**/*.swift").each do |file_path|
  relative_path = Pathname.new(file_path).relative_path_from(project_dir).to_s
  files_to_add << relative_path
end

# Add plist and assets
files_to_add << 'RoomFinderAI/Resources/Info.plist' if File.exist?(base_dir.join('Resources/Info.plist'))

# Also check for assets
Dir.glob("#{base_dir}/**/Assets.xcassets").each do |assets_path|
  relative_path = Pathname.new(assets_path).relative_path_from(project_dir).to_s  
  files_to_add << relative_path
end

puts "   Found #{files_to_add.length} files to add:"

# Add each file
added_count = 0
files_to_add.each do |relative_path|
  full_path = project_dir.join(relative_path)
  
  if File.exist?(full_path)
    # Determine the group
    path_parts = relative_path.split('/')
    
    if path_parts.length >= 3
      group_name = path_parts[1] # Models, Views, etc.
      group = groups[group_name] || roomfinder_group
    else
      group = roomfinder_group
    end
    
    # Add file reference
    file_ref = group.new_reference(relative_path)
    
    # Add to target
    if relative_path.end_with?('.swift')
      target.add_file_references([file_ref])
    elsif relative_path.end_with?('.xcassets') || relative_path.end_with?('.plist')
      target.add_resources([file_ref]) if target.resources_build_phase
    end
    
    puts "   ✅ Added: #{relative_path}"
    added_count += 1
  else
    puts "   ⚠️  File not found: #{relative_path}"
  end
end

puts "   ✅ Added #{added_count} files"

# Save the project
puts "\n3️⃣ Saving project..."
project.save

puts "\n✅ Comprehensive build fix complete!"
puts "   - Removed #{removed_count} old references"
puts "   - Added #{added_count} new references"
puts "   - Project saved successfully"