require 'xcodeproj'

project_path = './RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

puts "=== FIXING PROJECT: #{target.name} ==="

# Clear all existing source files
target.source_build_phase.files.clear
puts "✅ Cleared all source files"

# Add Swift files
swift_files = [
  'RoomFinderAI/App/RoomFinderAIApp.swift',
  'RoomFinderAI/Config/EnvironmentValues.swift',
  'RoomFinderAI/Config/Secrets.swift',
  'RoomFinderAI/Config/SupabaseEnvironment.swift',
  'RoomFinderAI/Core/Models/Listing.swift',
  'RoomFinderAI/Core/Models/Message.swift',
  'RoomFinderAI/Core/Models/User.swift',
  'RoomFinderAI/Services/OpenAI/OpenAIClient.swift',
  'RoomFinderAI/Services/Supabase/SupabaseService.swift',
  'RoomFinderAI/Features/Listings/ListingsView.swift',
  'RoomFinderAI/Features/Listings/ListingsViewModel.swift',
  'RoomFinderAI/Features/Listings/ListingCardView.swift',
  'RoomFinderAI/Features/Listings/PropertyDetailView.swift',
  'RoomFinderAI/Features/Negotiator/AINegotiatorBootstrap.swift',
  'RoomFinderAI/Features/Negotiator/AINegotiatorView.swift',
  'RoomFinderAI/Features/Negotiator/AINegotiatorViewModel.swift',
  'RoomFinderAI/Features/Negotiator/AINegotiatorService.swift',
  'RoomFinderAI/Features/Negotiator/NegotiatorConfig.swift',
  'RoomFinderAI/Features/Negotiator/DebugInfoView.swift'
]

added_count = 0
swift_files.each do |file_path|
  if File.exist?(file_path)
    file_ref = project.main_group.find_file_by_path(file_path)
    unless file_ref
      file_ref = project.main_group.new_reference(file_path)
    end
    target.add_file_references([file_ref])
    puts "✅ Added: #{file_path}"
    added_count += 1
  else
    puts "❌ Missing: #{file_path}"
  end
end

# Add assets
assets_path = 'RoomFinderAI/Resources/Assets.xcassets'
if File.exist?(assets_path)
  assets_ref = project.main_group.find_file_by_path(assets_path)
  unless assets_ref
    assets_ref = project.main_group.new_reference(assets_path)
  end
  target.add_resources([assets_ref])
  puts "✅ Added: #{assets_path}"
end

puts "\n=== SUMMARY ==="
puts "✅ Added #{added_count} Swift files"

project.save
puts "✅ PROJECT SAVED\!"
