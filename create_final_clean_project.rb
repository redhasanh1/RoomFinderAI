#!/usr/bin/env ruby

require 'xcodeproj'
require 'fileutils'

puts "🚀 Creating final clean project from scratch..."

project_path = './RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
base_dir = './RoomFinderAI-IOS/Project/RoomFinderAI'

# Create a completely new project
project = Xcodeproj::Project.new(project_path)

# Basic project settings
project.root_object.known_regions = ['en', 'Base']

# Create target
target = project.new_target(:application, 'RoomFinderAI', :ios, '16.0')
target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.roomfinderai.app'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['INFOPLIST_FILE'] = 'RoomFinderAI/Resources/Info.plist'
  config.build_settings['DEVELOPMENT_ASSET_PATHS'] = '"RoomFinderAI/Resources"'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
end

# Add Supabase package
package_ref = project.root_object.new_swift_package_reference('https://github.com/supabase/supabase-swift.git')
package_ref.requirement = {'kind' => 'upToNextMajorVersion', 'minimumVersion' => '2.0.0'}
package_product = target.add_package_product_dependency(package_ref, 'Supabase')

puts "📁 Creating group structure..."

# Create main groups
main_group = project.main_group
app_group = main_group.new_group('App', 'App')
config_group = main_group.new_group('Config', 'Config')
core_group = main_group.new_group('Core')
models_group = core_group.new_group('Models', 'Core/Models')
extensions_group = core_group.new_group('Extensions', 'Core/Extensions')
services_group = main_group.new_group('Services')
supabase_group = services_group.new_group('Supabase', 'Services/Supabase')
features_group = main_group.new_group('Features')
listings_group = features_group.new_group('Listings', 'Features/Listings')
chat_group = features_group.new_group('Chat', 'Features/Chat')
resources_group = main_group.new_group('Resources', 'Resources')
products_group = main_group.new_group('Products')

# Add product reference
app_product_ref = products_group.new_reference("RoomFinderAI.app")
app_product_ref.explicit_file_type = 'wrapper.application'
app_product_ref.source_tree = 'BUILT_PRODUCTS_DIR'

puts "📄 Adding Swift files..."

# Define all Swift files to add
swift_files = [
  { path: 'App/RoomFinderAIApp.swift', group: app_group },
  { path: 'Config/Secrets.swift', group: config_group },
  { path: 'Config/SupabaseEnvironment.swift', group: config_group },
  { path: 'Core/Models/User.swift', group: models_group },
  { path: 'Core/Models/Listing.swift', group: models_group },
  { path: 'Core/Models/Chat.swift', group: models_group },
  { path: 'Core/Models/Message.swift', group: models_group },
  { path: 'Core/Extensions/Constants.swift', group: extensions_group },
  { path: 'Core/Extensions/Extensions.swift', group: extensions_group },
  { path: 'Services/Supabase/AuthViewModel.swift', group: supabase_group },
  { path: 'Services/Supabase/SupabaseService.swift', group: supabase_group },
  { path: 'Services/NetworkManager.swift', group: services_group },
  { path: 'Features/Listings/ListingsViewModel.swift', group: listings_group },
  { path: 'Features/Chat/ChatViewModel.swift', group: chat_group },
]

swift_files.each do |file_info|
  full_path = "#{base_dir}/#{file_info[:path]}"
  
  if File.exist?(full_path)
    file_ref = file_info[:group].new_reference(file_info[:path])
    file_ref.last_known_file_type = 'sourcecode.swift'
    file_ref.source_tree = '<group>'
    
    # Add to build phase
    target.source_build_phase.add_file_reference(file_ref)
    
    puts "  ✅ Added: #{file_info[:path]}"
  else
    puts "  ⚠️  Missing: #{file_info[:path]}"
  end
end

puts "📦 Adding Assets.xcassets..."

# Add Assets.xcassets
assets_path = 'Resources/Assets.xcassets'
assets_full_path = "#{base_dir}/#{assets_path}"

if Dir.exist?(assets_full_path)
  assets_ref = resources_group.new_reference(assets_path)
  assets_ref.last_known_file_type = 'folder.assetcatalog'
  assets_ref.source_tree = '<group>'
  target.resources_build_phase.add_file_reference(assets_ref)
  puts "  ✅ Added: Assets.xcassets"
else
  puts "  ⚠️  Assets.xcassets not found"
end

puts "💾 Saving new project..."
project.save

puts "✅ Clean project created successfully!"