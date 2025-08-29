#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔍 Checking build settings for asset paths..."

# Get the main target
target = project.targets.find { |t| t.name == "RoomFinderAI" }

if target
  target.build_configurations.each do |config|
    puts "\nConfig: #{config.name}"
    
    # Check DEVELOPMENT_ASSET_PATHS
    dev_asset_paths = config.build_settings['DEVELOPMENT_ASSET_PATHS']
    puts "  Current DEVELOPMENT_ASSET_PATHS: #{dev_asset_paths}"
    
    if dev_asset_paths && dev_asset_paths.include?('Resources')
      # Fix the path - remove any doubled RoomFinderAI references
      new_path = 'RoomFinderAI/Resources'
      config.build_settings['DEVELOPMENT_ASSET_PATHS'] = "\"#{new_path}\""
      puts "  Fixed DEVELOPMENT_ASSET_PATHS to: #{config.build_settings['DEVELOPMENT_ASSET_PATHS']}"
    end
    
    # Also check any other asset-related settings
    config.build_settings.each do |key, value|
      if key.to_s.include?('ASSET') || key.to_s.include?('Resource')
        puts "  #{key}: #{value}"
      end
    end
  end
  
  # Save the project
  project.save
  puts "\n✅ Updated build settings and saved project"
else
  puts "❌ Could not find RoomFinderAI target"
end