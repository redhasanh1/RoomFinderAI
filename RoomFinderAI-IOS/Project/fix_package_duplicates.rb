#!/usr/bin/env ruby

require 'xcodeproj'
require 'set'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Track seen GUIDs
seen_guids = Set.new
duplicates = []

# Function to check for duplicate GUIDs recursively
def check_duplicates(object, path, seen_guids, duplicates)
  return unless object.respond_to?(:uuid)
  
  guid = object.uuid
  if seen_guids.include?(guid)
    duplicates << { guid: guid, path: path, object: object }
  else
    seen_guids.add(guid)
  end
  
  # Check children
  if object.respond_to?(:children)
    object.children.each do |child|
      check_duplicates(child, "#{path} > #{child.display_name}", seen_guids, duplicates)
    end
  end
end

# Check all objects in the project
project.objects.each do |uuid, object|
  if object.respond_to?(:display_name)
    check_duplicates(object, object.display_name || uuid, seen_guids, duplicates)
  end
end

# Print duplicates found
if duplicates.any?
  puts "Found #{duplicates.length} duplicate GUIDs:"
  duplicates.each do |dup|
    puts "  GUID: #{dup[:guid]}"
    puts "  Path: #{dup[:path]}"
    puts "  Type: #{dup[:object].class}"
    puts "  ---"
  end
  
  # Generate new UUIDs for duplicates
  duplicates.each do |dup|
    old_uuid = dup[:object].uuid
    new_uuid = Xcodeproj::Project.generate_uuid
    dup[:object].instance_variable_set(:@uuid, new_uuid)
    puts "  Replaced #{old_uuid} with #{new_uuid}"
  end
  
  project.save
  puts "\nProject saved with fixed GUIDs"
else
  puts "No duplicate GUIDs found"
end

# Clean up package references
package_refs = project.root_object.package_references
if package_refs && package_refs.any?
  puts "\nFound #{package_refs.count} package references:"
  package_refs.each do |ref|
    puts "  - #{ref.requirement}"
  end
end