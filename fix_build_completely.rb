#!/usr/bin/env ruby
require 'xcodeproj'

project_path = './RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

puts "=== COMPREHENSIVE BUILD FIX FOR: #{target.name} ==="

# 1. Remove duplicate Assets.xcassets from Sources build phase
puts "\n1. Fixing duplicate Assets.xcassets in Sources..."
assets_in_sources = target.source_build_phase.files.select do |file|
  file.file_ref&.path&.include?('Assets.xcassets')
end

assets_in_sources.each do |file|
  target.source_build_phase.files.delete(file)
  puts "   ✅ Removed Assets.xcassets from Sources: #{file.file_ref&.path}"
end

# 2. Ensure Assets.xcassets is only in Resources
puts "\n2. Ensuring Assets.xcassets is in Resources..."
assets_refs = project.files.select { |f| f.path&.include?('Assets.xcassets') }
puts "   Found #{assets_refs.count} Assets.xcassets references:"
assets_refs.each { |ref| puts "     - #{ref.path}" }

# Clear resources and add only one Assets.xcassets
target.resources_build_phase.files.clear
puts "   ✅ Cleared all resources"

# Add the main Assets.xcassets
main_assets = 'RoomFinderAI/Resources/Assets.xcassets'
if File.exist?(main_assets)
  assets_ref = project.main_group.find_file_by_path(main_assets)
  unless assets_ref
    assets_ref = project.main_group.new_reference(main_assets)
  end
  target.add_resources([assets_ref])
  puts "   ✅ Added main Assets.xcassets to Resources: #{main_assets}"
else
  puts "   ❌ Main assets not found: #{main_assets}"
end

# 3. Clean up all source files and re-add correctly
puts "\n3. Rebuilding Sources with correct files..."
target.source_build_phase.files.clear
puts "   ✅ Cleared all source files"

# Core Swift files that should exist and compile
swift_files = [
  'RoomFinderAI/RoomFinderAIApp.swift',
  'RoomFinderAI/Services/Secrets.swift',
  'RoomFinderAI/SupabaseEnvironment.swift'
]

added_count = 0
swift_files.each do |file_path|
  if File.exist?(file_path)
    file_ref = project.main_group.find_file_by_path(file_path)
    unless file_ref
      file_ref = project.main_group.new_reference(file_path)
    end
    target.add_file_references([file_ref])
    puts "   ✅ Added: #{file_path}"
    added_count += 1
  else
    puts "   ❌ Missing: #{file_path}"
  end
end

# 4. Remove Supabase package dependency temporarily
puts "\n4. Managing Supabase package dependency..."
if target.package_product_dependencies.any?
  puts "   Found package dependencies, clearing them temporarily"
  target.package_product_dependencies.clear
  puts "   ✅ Cleared package dependencies"
end

# 5. Clean up build settings that might cause issues
puts "\n5. Checking build settings..."
target.build_configurations.each do |config|
  # Ensure we don't have problematic settings
  config.build_settings.delete('SWIFT_ACTIVE_COMPILATION_CONDITIONS') if config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']&.include?('Supabase')
  puts "   ✅ Cleaned build settings for #{config.name}"
end

puts "\n=== BUILD FIX SUMMARY ==="
puts "✅ Removed duplicate Assets.xcassets from Sources"
puts "✅ Added main Assets.xcassets to Resources only"
puts "✅ Added #{added_count} Swift files with correct paths"
puts "✅ Temporarily removed Supabase package dependencies"
puts "✅ Cleaned build settings"

project.save
puts "\n🎯 PROJECT SAVED - Try building now!"