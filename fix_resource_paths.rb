#!/usr/bin/env ruby

require 'xcodeproj'
require 'pathname'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔍 Looking for resource path issues..."

# Check all file references for resource issues
project.files.each do |file_ref|
  next unless file_ref.path
  
  path = file_ref.path
  
  # Check for problematic resource paths
  if path.include?('Resources/') && (path.include?('Assets.xcassets') || path.include?('Info.plist'))
    puts "📁 Resource file: #{path}"
    
    # Check if path looks wrong (double nested)
    if path.include?('RoomFinderAI/Resources') && path.count('RoomFinderAI') > 1
      puts "   ❌ Problematic nested path detected!"
      
      # Fix the path
      new_path = path.gsub(/RoomFinderAI\/Resources\/RoomFinderAI\/Resources\//, 'RoomFinderAI/Resources/')
      file_ref.path = new_path
      
      puts "   ✅ Fixed: #{path} -> #{new_path}"
    end
  end
end

# Also check for any Info.plist duplicates specifically
info_plist_refs = project.files.select { |f| f.path&.include?('Info.plist') }

puts "\n🔍 Found #{info_plist_refs.length} Info.plist references:"
info_plist_refs.each_with_index do |ref, index|
  puts "   #{index + 1}. #{ref.path}"
end

if info_plist_refs.length > 1
  puts "\n🔧 Removing duplicate Info.plist references..."
  
  # Keep only the first one
  refs_to_remove = info_plist_refs[1..-1]
  
  refs_to_remove.each do |ref|
    puts "   🗑️  Removing: #{ref.path}"
    
    # Remove from all targets
    project.targets.each do |target|
      target.source_build_phase&.remove_file_reference(ref)
      target.resources_build_phase&.remove_file_reference(ref)
    end
    
    # Remove from project
    ref.remove_from_project
  end
  
  puts "   ✅ Kept: #{info_plist_refs.first.path}"
end

# Check Assets.xcassets too
assets_refs = project.files.select { |f| f.path&.include?('Assets.xcassets') }

puts "\n🔍 Found #{assets_refs.length} Assets.xcassets references:"
assets_refs.each_with_index do |ref, index|
  puts "   #{index + 1}. #{ref.path}"
end

if assets_refs.length > 1
  puts "\n🔧 Removing duplicate Assets.xcassets references..."
  
  # Keep only the first one
  refs_to_remove = assets_refs[1..-1]
  
  refs_to_remove.each do |ref|
    puts "   🗑️  Removing: #{ref.path}"
    
    # Remove from all targets
    project.targets.each do |target|
      target.source_build_phase&.remove_file_reference(ref)
      target.resources_build_phase&.remove_file_reference(ref)
    end
    
    # Remove from project
    ref.remove_from_project
  end
  
  puts "   ✅ Kept: #{assets_refs.first.path}"
end

# Save the project
puts "\n💾 Saving project..."
project.save

puts "✅ Fixed all resource path issues!"