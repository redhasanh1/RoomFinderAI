#!/usr/bin/env ruby

require 'xcodeproj'

# Path to project  
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first
puts "Working with target: #{target.name}"

# Clear existing file references and groups to start clean
project.main_group.clear
target.source_build_phase.clear

# Recreate clean group structure
main_group = project.main_group

# Create groups to match directory structure
app_group = main_group.new_group('App')
config_group = main_group.new_group('Config') 
core_group = main_group.new_group('Core')
models_group = core_group.new_group('Models')
services_group = main_group.new_group('Services')
openai_group = services_group.new_group('OpenAI')
supabase_group = services_group.new_group('Supabase')
features_group = main_group.new_group('Features')
listings_group = features_group.new_group('Listings')
negotiator_group = features_group.new_group('Negotiator')
ui_group = main_group.new_group('UI')
components_group = ui_group.new_group('Components')

# Add files to appropriate groups and build phases
base_path = 'RoomFinderAI-IOS/Project/RoomFinderAI'

# App files
app_files = [
  'App/RoomFinderAIApp.swift'
]

app_files.each do |file_path|
  full_path = "#{base_path}/#{file_path}"
  if File.exist?(full_path)
    file_ref = app_group.new_reference(full_path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "✅ Added: #{file_path}"
  else
    puts "❌ Missing: #{file_path}"
  end
end

# Config files
config_files = [
  'Config/Secrets.swift',
  'Config/EnvironmentValues.swift'
]

config_files.each do |file_path|
  full_path = "#{base_path}/#{file_path}"
  if File.exist?(full_path)
    file_ref = config_group.new_reference(full_path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "✅ Added: #{file_path}"
  else
    puts "❌ Missing: #{file_path}"
  end
end

# Core/Models files
model_files = [
  'Core/Models/Listing.swift',
  'Core/Models/Message.swift',
  'Core/Models/User.swift'
]

model_files.each do |file_path|
  full_path = "#{base_path}/#{file_path}"
  if File.exist?(full_path)
    file_ref = models_group.new_reference(full_path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "✅ Added: #{file_path}"
  else
    puts "❌ Missing: #{file_path}"
  end
end

# Services/OpenAI files
openai_files = [
  'Services/OpenAI/OpenAIClient.swift'
]

openai_files.each do |file_path|
  full_path = "#{base_path}/#{file_path}"
  if File.exist?(full_path)
    file_ref = openai_group.new_reference(full_path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "✅ Added: #{file_path}"
  else
    puts "❌ Missing: #{file_path}"
  end
end

# Services/Supabase files
supabase_files = [
  'Services/Supabase/SupabaseService.swift'
]

supabase_files.each do |file_path|
  full_path = "#{base_path}/#{file_path}"
  if File.exist?(full_path)
    file_ref = supabase_group.new_reference(full_path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "✅ Added: #{file_path}"
  else
    puts "❌ Missing: #{file_path}"
  end
end

# Features/Listings files
listings_files = [
  'Features/Listings/ListingsView.swift',
  'Features/Listings/ListingsViewModel.swift'
]

listings_files.each do |file_path|
  full_path = "#{base_path}/#{file_path}"
  if File.exist?(full_path)
    file_ref = listings_group.new_reference(full_path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "✅ Added: #{file_path}"
  else
    puts "❌ Missing: #{file_path}"
  end
end

# Features/Negotiator files
negotiator_files = [
  'Features/Negotiator/AINegotiatorView.swift',
  'Features/Negotiator/AINegotiatorViewModel.swift',
  'Features/Negotiator/AINegotiatorService.swift',
  'Features/Negotiator/AINegotiatorBootstrap.swift',
  'Features/Negotiator/DebugInfoView.swift'
]

negotiator_files.each do |file_path|
  full_path = "#{base_path}/#{file_path}"
  if File.exist?(full_path)
    file_ref = negotiator_group.new_reference(full_path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "✅ Added: #{file_path}"
  else
    puts "❌ Missing: #{file_path}"
  end
end

# Save project
project.save

puts "\n🎉 Project restructured successfully!"
puts "Groups created with proper file references"
puts "All duplicates removed from build phases"