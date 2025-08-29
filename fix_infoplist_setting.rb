#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔧 Fixing Info.plist build setting..."

# Get the main target
target = project.targets.find { |t| t.name == "RoomFinderAI" }

if target
  target.build_configurations.each do |config|
    current_infoplist = config.build_settings['INFOPLIST_FILE']
    puts "Config: #{config.name}"
    puts "  Current INFOPLIST_FILE: #{current_infoplist}"
    
    # Set the correct path
    config.build_settings['INFOPLIST_FILE'] = 'RoomFinderAI/Resources/Info.plist'
    
    puts "  New INFOPLIST_FILE: #{config.build_settings['INFOPLIST_FILE']}"
  end
end

# Also check if we should remove Info.plist from resources build phase
# Info.plist should NOT be in the resources build phase, it should only be referenced in build settings
puts "\n🔍 Checking if Info.plist is in resources build phase..."

if target&.resources_build_phase
  resources_files = target.resources_build_phase.files
  info_plist_resource = resources_files.find { |f| f.file_ref&.path&.include?('Info.plist') }
  
  if info_plist_resource
    puts "❌ Found Info.plist in resources build phase - removing it"
    target.resources_build_phase.remove_file_reference(info_plist_resource.file_ref)
    puts "✅ Removed Info.plist from resources build phase"
  else
    puts "✅ Info.plist is not in resources build phase (correct)"
  end
end

# Save the project
project.save

puts "\n✅ Fixed Info.plist build settings!"