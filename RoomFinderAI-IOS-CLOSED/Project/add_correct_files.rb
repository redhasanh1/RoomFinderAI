require 'xcodeproj'

project_path = './RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first

# Files to add with correct paths
files_to_add = [
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

files_to_add.each do |file_path|
  if File.exist?(file_path)
    file_ref = project.main_group.find_file_by_path(file_path)
    unless file_ref
      file_ref = project.main_group.new_reference(file_path)
      target.add_file_references([file_ref])
      puts "Added: #{file_path}"
    end
  else
    puts "Missing: #{file_path}"
  end
end

project.save
puts "Project updated\!"
