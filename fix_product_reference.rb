#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔧 Fixing product reference..."

# Find the products group
products_group = project.main_group.children.find { |child| child.name == 'Products' }

if products_group && products_group.children.empty?
  # Add product reference correctly
  app_product_ref = products_group.new_reference("RoomFinderAI.app")
  app_product_ref.explicit_file_type = 'wrapper.application'
  app_product_ref.source_tree = 'BUILT_PRODUCTS_DIR'
  # Don't set includeInIndex as it causes the error
  
  puts "✅ Fixed product reference"
end

project.save
puts "💾 Saved project"