require 'xcodeproj'

project_path = './RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first
puts "Target: #{target.name}"

# Get all file references in build phase
build_files = target.source_build_phase.files
puts "Total build files: #{build_files.count}"

# Track duplicates by filename
file_counts = {}
duplicates_to_remove = []

build_files.each do |build_file|
  next unless build_file.file_ref
  
  filename = build_file.file_ref.name || File.basename(build_file.file_ref.path || "")
  next if filename.empty?
  
  if file_counts[filename]
    puts "Found duplicate: #{filename}"
    duplicates_to_remove << build_file
  else
    file_counts[filename] = build_file
  end
end

# Remove duplicates
duplicates_to_remove.each do |duplicate|
  filename = duplicate.file_ref.name || File.basename(duplicate.file_ref.path || "")
  puts "Removing duplicate: #{filename}"
  target.source_build_phase.files.delete(duplicate)
end

puts "Removed #{duplicates_to_remove.count} duplicate file references"

project.save
puts "✅ Project cleaned\!"
