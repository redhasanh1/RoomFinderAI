#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔍 All file paths in project:"

# List all file paths to see what's wrong
project.files.each do |file_ref|
  next unless file_ref.path
  
  path = file_ref.path
  
  # Look for problematic paths
  if path.include?('User.swift') || path.include?('Listing.swift') || 
     path.include?('ListingsView.swift') || path.include?('PropertyDetailView.swift') ||
     path.include?('Constants.swift') || path.include?('Extensions.swift')
    
    puts "📁 #{path}"
    
    # Check if this is a duplicate path
    if path.count('/') > 2 && path.include?('RoomFinderAI/')
      puts "   ⚠️  Potential duplicate path detected!"
    end
  end
end

puts "\n🔍 Checking for specific problematic paths from build error:"
problematic_paths = [
  '/Models/RoomFinderAI/Models/User.swift',
  '/Models/RoomFinderAI/Models/Listing.swift',
  '/Views/RoomFinderAI/Views/ListingsView.swift',
  '/Views/RoomFinderAI/Views/PropertyDetailView.swift',
  '/Utils/RoomFinderAI/Utils/Constants.swift',
  '/Utils/RoomFinderAI/Utils/Extensions.swift'
]

problematic_paths.each do |bad_path|
  bad_refs = project.files.select { |f| f.path&.include?(bad_path) }
  bad_refs.each do |ref|
    puts "❌ FOUND PROBLEMATIC: #{ref.path}"
  end
end