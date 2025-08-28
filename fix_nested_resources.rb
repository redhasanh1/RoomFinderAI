#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔍 Checking all file paths for nested issues..."

# List ALL file paths to see what's there
project.files.each do |file_ref|
  next unless file_ref.path
  
  path = file_ref.path
  puts "📄 #{path}"
  
  # Check for any nested RoomFinderAI patterns
  if path.include?('RoomFinderAI') && path.count('/RoomFinderAI/') > 1
    puts "   ❌ Multiple RoomFinderAI segments detected!"
  end
  
  # Check for specific issues from build log
  if path.include?('Resources/RoomFinderAI/Resources')
    puts "   ❌ FOUND THE PROBLEMATIC PATH!"
    
    # Fix it
    new_path = path.gsub('Resources/RoomFinderAI/Resources', 'Resources')
    file_ref.path = new_path
    puts "   ✅ Fixed: #{path} -> #{new_path}"
  end
end

# Save
project.save
puts "\n✅ Saved project"