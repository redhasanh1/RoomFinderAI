#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find all file references and fix paths
project.files.each do |file_ref|
  if file_ref.path && file_ref.path.include?('RoomFinderAI/Services/RoomFinderAI/Services/')
    # Fix double path issue
    file_ref.path = file_ref.path.gsub('RoomFinderAI/Services/RoomFinderAI/Services/', 'RoomFinderAI/Services/')
    puts "Fixed path: #{file_ref.path}"
  elsif file_ref.path && file_ref.path.include?('RoomFinderAI/Utils/RoomFinderAI/Utils/')
    # Fix double path issue
    file_ref.path = file_ref.path.gsub('RoomFinderAI/Utils/RoomFinderAI/Utils/', 'RoomFinderAI/Utils/')
    puts "Fixed path: #{file_ref.path}"
  elsif file_ref.path && file_ref.path.include?('RoomFinderAI/Views/RoomFinderAI/Views/')
    # Fix double path issue
    file_ref.path = file_ref.path.gsub('RoomFinderAI/Views/RoomFinderAI/Views/', 'RoomFinderAI/Views/')
    puts "Fixed path: #{file_ref.path}"
  end
end

# Save the project
project.save

puts "\nFile paths fixed successfully!"