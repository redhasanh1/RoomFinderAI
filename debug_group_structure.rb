#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔍 Debugging group structure and file paths..."

def print_group(group, level = 0)
  indent = "  " * level
  puts "#{indent}📁 Group: #{group.name || group.path || 'ROOT'}"
  
  if group.path
    puts "#{indent}   Path: #{group.path}"
  end
  
  group.children.each do |child|
    if child.is_a?(Xcodeproj::Project::Object::PBXGroup)
      print_group(child, level + 1)
    elsif child.is_a?(Xcodeproj::Project::Object::PBXFileReference)
      puts "#{indent}  📄 #{child.display_name} -> #{child.path}"
      
      if child.path&.include?('Assets.xcassets')
        puts "#{indent}     ⭐ ASSETS FILE FOUND!"
        puts "#{indent}     Real path: #{child.real_path}" if child.respond_to?(:real_path)
      end
    end
  end
end

print_group(project.main_group)

# Also specifically look for Assets.xcassets
puts "\n🔍 Specific Assets.xcassets search:"
project.files.each do |file_ref|
  if file_ref.path&.include?('Assets.xcassets')
    puts "Found Assets.xcassets:"
    puts "  Display name: #{file_ref.display_name}"
    puts "  Path: #{file_ref.path}"
    puts "  Source tree: #{file_ref.source_tree}"
    
    # Check parent groups
    current = file_ref
    parents = []
    while current.parent
      parents << current.parent.name || current.parent.path || 'unnamed'
      current = current.parent
    end
    puts "  Parent groups: #{parents.reverse.join(' > ')}"
  end
end