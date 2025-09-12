#!/usr/bin/env ruby

require 'xcodeproj'

puts "🔧 Fixing missing Supabase package dependency..."

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
main_target = project.targets.find { |t| t.name == 'RoomFinderAI' }
unless main_target
  puts "❌ Could not find RoomFinderAI target"
  exit 1
end

puts "✅ Found target: #{main_target.name}"

# Find the Supabase package reference
supabase_package = nil
project.root_object.package_references.each do |package_ref|
  if package_ref.repositoryURL && package_ref.repositoryURL.include?('supabase-swift')
    supabase_package = package_ref
    break
  end
end

unless supabase_package
  puts "❌ Supabase package reference not found"
  exit 1
end

puts "✅ Found Supabase package: #{supabase_package.repositoryURL}"

# Check if Supabase product is already in the target
existing_supabase = main_target.package_product_dependencies.find do |dep|
  dep.product_name == 'Supabase'
end

if existing_supabase
  puts "✅ Supabase product dependency already exists"
else
  # Add Supabase package product to target
  supabase_dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  supabase_dependency.package = supabase_package
  supabase_dependency.product_name = 'Supabase'
  
  # Add to target's package dependencies
  main_target.package_product_dependencies << supabase_dependency
  
  puts "✅ Added Supabase package product to target"
end

# Save the project
puts "💾 Saving project..."
project.save

puts "🎉 Supabase dependency has been restored!"
puts ""
puts "Your app should now build successfully. The missing 'Supabase' package product has been re-added to your target."