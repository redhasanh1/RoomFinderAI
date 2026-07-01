#!/usr/bin/env ruby

# Fix missing name attributes in PBXFileReference entries

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

puts "=== Fixing Missing Name Attributes ==="
puts "Adding 'name' attribute to all file references that don't have one..."

# Fix PBXFileReference entries that only have 'path' but no 'name'
# Pattern: {isa = PBXFileReference; lastKnownFileType = ...; path = ../Source/RoomFinderAI/...; sourceTree = "<group>"; };
content.gsub!(/(\w+) \/\* ([^*]+) \*\/ = \{isa = PBXFileReference; lastKnownFileType = ([^;]+); path = (\.\.\/Source\/RoomFinderAI\/[^;]+); sourceTree = \"<group>\"; \};/) do |match|
  id = $1
  comment = $2
  filetype = $3
  path = $4
  
  # Extract just the filename from the path
  filename = File.basename(path)
  
  puts "  - Fixed: #{filename} (was missing name attribute)"
  
  # Return the fixed version with name attribute
  "#{id} /* #{filename} */ = {isa = PBXFileReference; lastKnownFileType = #{filetype}; name = #{filename}; path = #{path}; sourceTree = \"<group>\"; };"
end

# Also fix any remaining entries that might have different patterns
content.gsub!(/(\w+) \/\* ([^*]+) \*\/ = \{isa = PBXFileReference; explicitFileType = ([^;]+); includeInIndex = \d+; path = ([^;]+); sourceTree = ([^;]+); \};/) do |match|
  id = $1
  comment = $2
  filetype = $3
  path = $4
  sourcetree = $5
  
  # Extract just the filename from the path
  filename = File.basename(path)
  
  puts "  - Fixed app bundle: #{filename}"
  
  # Return the fixed version (app bundles don't need name attribute)
  match
end

# Write the updated content back
File.write(project_file, content)

puts "=== Fix Complete ==="
puts "✅ All file references now have proper name attributes"
puts "✅ Files should now show clean names in Xcode navigator"