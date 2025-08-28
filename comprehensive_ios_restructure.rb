#!/usr/bin/env ruby

require 'xcodeproj'
require 'fileutils'

puts "🚀 COMPREHENSIVE iOS PROJECT RESTRUCTURE - Senior iOS Engineer Pass"

project_path = './RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
base_dir = './RoomFinderAI-IOS/Project/RoomFinderAI'

# Clean existing project completely
puts "🧹 Cleaning existing project..."
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == "RoomFinderAI" }

# Clear all existing references
project.main_group.children.clear
target.source_build_phase.files.clear if target.source_build_phase
target.resources_build_phase.files.clear if target.resources_build_phase

puts "📁 Creating exact folder structure on filesystem..."

# Create the exact directory structure
directories = [
  "#{base_dir}/App",
  "#{base_dir}/Config", 
  "#{base_dir}/Core/Models",
  "#{base_dir}/Core/Extensions",
  "#{base_dir}/Services/Supabase",
  "#{base_dir}/Services/OpenAI",
  "#{base_dir}/Features/Listings",
  "#{base_dir}/Features/Negotiator", 
  "#{base_dir}/Features/Chat",
  "#{base_dir}/UI/Components",
  "#{base_dir}/UI/Theme",
  "#{base_dir}/Resources"
]

directories.each do |dir|
  FileUtils.mkdir_p(dir)
  puts "  ✅ Created: #{dir.gsub("#{base_dir}/", "")}"
end

puts "🏗️ Creating Xcode group structure..."

# Create main groups matching filesystem
main_group = project.main_group
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
negotiator_group = features_group.new_group('Negotiator', 'Features/Negotiator')
chat_group = features_group.new_group('Chat', 'Features/Chat')
ui_group = main_group.new_group('UI')
components_group = ui_group.new_group('Components', 'UI/Components')
theme_group = ui_group.new_group('Theme', 'UI/Theme')
resources_group = main_group.new_group('Resources', 'Resources')
products_group = main_group.new_group('Products')

puts "💾 Saving structured project..."
project.save

puts "📄 Project structure created. Ready for file population..."
puts ""
puts "📂 Structure created:"
puts "  ├── App/"
puts "  ├── Config/"
puts "  ├── Core/"
puts "  │   ├── Models/"
puts "  │   └── Extensions/"
puts "  ├── Services/"
puts "  │   ├── Supabase/"
puts "  │   └── OpenAI/"
puts "  ├── Features/"
puts "  │   ├── Listings/"
puts "  │   ├── Negotiator/"
puts "  │   └── Chat/"
puts "  ├── UI/"
puts "  │   ├── Components/"
puts "  │   └── Theme/"
puts "  ├── Resources/"
puts "  └── Products/"