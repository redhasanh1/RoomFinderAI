#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔍 Looking for Assets.xcassets references..."

# Find the Assets.xcassets file reference
assets_ref = project.files.find { |f| f.path&.include?('Assets.xcassets') }

if assets_ref
  puts "Found Assets.xcassets reference: #{assets_ref.path}"
  
  # Check if the file actually exists at this path
  project_dir = File.dirname(project_path)
  full_path = File.join(project_dir, assets_ref.path)
  
  puts "Checking path: #{full_path}"
  
  if File.exist?(full_path)
    puts "✅ File exists at current path"
  else
    puts "❌ File does not exist at current path"
    
    # Look for the actual Assets.xcassets file
    correct_path = File.join(project_dir, 'RoomFinderAI/Resources/Assets.xcassets')
    puts "Checking correct path: #{correct_path}"
    
    if File.exist?(correct_path)
      puts "✅ Found file at correct path"
      
      # Update the reference
      assets_ref.path = 'RoomFinderAI/Resources/Assets.xcassets'
      puts "✅ Updated path to: #{assets_ref.path}"
    else
      puts "❌ File not found at expected path either"
      
      # Look for any Assets.xcassets in the RoomFinderAI directory
      Dir.glob(File.join(project_dir, '**/Assets.xcassets')).each do |found_path|
        puts "Found Assets.xcassets at: #{found_path}"
        
        relative_path = Pathname.new(found_path).relative_path_from(Pathname.new(project_dir)).to_s
        puts "Relative path would be: #{relative_path}"
        
        if relative_path.include?('RoomFinderAI/Resources/Assets.xcassets') && !relative_path.include?('RoomFinderAI/RoomFinderAI')
          puts "✅ Using this path: #{relative_path}"
          assets_ref.path = relative_path
          break
        end
      end
    end
  end
  
  # Save the project
  project.save
  puts "✅ Project saved"
else
  puts "❌ No Assets.xcassets reference found in project"
end