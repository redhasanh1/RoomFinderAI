#!/usr/bin/env ruby

require 'xcodeproj'
require 'fileutils'

project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
base_dir = 'RoomFinderAI-IOS/Project/RoomFinderAI'

puts "🧹 Restructuring Xcode project completely..."

# Create clean directory structure
dirs_to_create = [
  "#{base_dir}/App",
  "#{base_dir}/Config", 
  "#{base_dir}/Core/Models",
  "#{base_dir}/Core/Extensions",
  "#{base_dir}/Services/Supabase",
  "#{base_dir}/Services/OpenAI",
  "#{base_dir}/Features/Listings",
  "#{base_dir}/Features/Chat",
  "#{base_dir}/Features/Negotiator",
  "#{base_dir}/UI/Components"
]

dirs_to_create.each do |dir|
  FileUtils.mkdir_p(dir)
  puts "📁 Created: #{dir}"
end

# Open and clean the Xcode project
project = Xcodeproj::Project.open(project_path)

# Clear all groups and files
main_group = project.main_group
main_group.children.clear

# Create new group structure
app_group = main_group.new_group('App', 'App')
config_group = main_group.new_group('Config', 'Config')
core_group = main_group.new_group('Core')
models_group = core_group.new_group('Models', 'Core/Models')
extensions_group = core_group.new_group('Extensions', 'Core/Extensions')
services_group = main_group.new_group('Services')
supabase_group = services_group.new_group('Supabase', 'Services/Supabase')
openai_group = services_group.new_group('OpenAI', 'Services/OpenAI')
features_group = main_group.new_group('Features')
listings_group = features_group.new_group('Listings', 'Features/Listings')
chat_group = features_group.new_group('Chat', 'Features/Chat')
negotiator_group = features_group.new_group('Negotiator', 'Features/Negotiator')
ui_group = main_group.new_group('UI')
components_group = ui_group.new_group('Components', 'UI/Components')
resources_group = main_group.new_group('Resources', 'Resources')
products_group = main_group.new_group('Products')

puts "📋 Created group structure"

# Get target
target = project.targets.find { |t| t.name == "RoomFinderAI" }

# Save the cleaned project
project.save

puts "✅ Project structure cleaned and ready for files"