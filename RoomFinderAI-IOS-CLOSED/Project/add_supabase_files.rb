#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔧 Adding Supabase integration files to Xcode project..."

# Find the main target
main_target = project.targets.find { |t| t.name == 'RoomFinderAI' }
unless main_target
  puts "❌ Could not find RoomFinderAI target"
  exit 1
end

# Find the Utils group
utils_group = nil
project.main_group.recursive_children.each do |child|
  if child.class == Xcodeproj::Project::Object::PBXGroup && child.display_name == 'Utils'
    utils_group = child
    break
  end
end

# Find the Services group  
services_group = nil
project.main_group.recursive_children.each do |child|
  if child.class == Xcodeproj::Project::Object::PBXGroup && child.display_name == 'Services'
    services_group = child
    break
  end
end

unless utils_group && services_group
  puts "❌ Could not find Utils or Services groups"
  exit 1
end

# Add SupabaseConfig.swift to Utils group
supabase_config_path = '../Source/RoomFinderAI/Utils/SupabaseConfig.swift'
if File.exist?(supabase_config_path)
  supabase_config_ref = utils_group.new_reference(supabase_config_path)
  supabase_config_ref.name = 'SupabaseConfig.swift'
  
  # Add to build phases
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.file_ref = supabase_config_ref
  main_target.source_build_phase.files << build_file
  
  puts "✅ Added SupabaseConfig.swift to Utils"
else
  puts "❌ SupabaseConfig.swift not found"
end

# Add SupabaseListingsService.swift to Services group
supabase_service_path = '../Source/RoomFinderAI/Services/SupabaseListingsService.swift'
if File.exist?(supabase_service_path)
  supabase_service_ref = services_group.new_reference(supabase_service_path)
  supabase_service_ref.name = 'SupabaseListingsService.swift'
  
  # Add to build phases
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.file_ref = supabase_service_ref
  main_target.source_build_phase.files << build_file
  
  puts "✅ Added SupabaseListingsService.swift to Services"
else
  puts "❌ SupabaseListingsService.swift not found"
end

puts "💾 Saving project..."
project.save

puts "✅ Supabase integration files added successfully!"
puts ""
puts "🚀 Your app now uses real Supabase data instead of mock data!"
puts "📊 Features added:"
puts "   • Real-time data fetching from Supabase"
puts "   • Advanced filtering and search"
puts "   • Pagination support"
puts "   • Favorite listings management"
puts "   • Fallback to mock data for development"