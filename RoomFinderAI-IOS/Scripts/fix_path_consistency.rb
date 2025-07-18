#!/usr/bin/env ruby

# Fix path consistency - ensure all files have the correct ../../Source/RoomFinderAI/ path

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

# Map of file patterns to their correct paths
file_mappings = {
  "RoomFinderAIApp.swift" => "../../Source/RoomFinderAI/RoomFinderAIApp.swift",
  "ContentView.swift" => "../../Source/RoomFinderAI/ContentView.swift",
  "Assets.xcassets" => "../../Source/RoomFinderAI/Resources/Assets.xcassets",
  "Info.plist" => "../../Source/RoomFinderAI/Resources/Info.plist",
  "SupabaseService.swift" => "../../Source/RoomFinderAI/Services/SupabaseService.swift",
  "AuthViewModel.swift" => "../../Source/RoomFinderAI/Services/AuthViewModel.swift",
  "ListingsViewModel.swift" => "../../Source/RoomFinderAI/Services/ListingsViewModel.swift",
  "ChatViewModel.swift" => "../../Source/RoomFinderAI/Services/ChatViewModel.swift",
  "NetworkManager.swift" => "../../Source/RoomFinderAI/Services/NetworkManager.swift",
  "LoginView.swift" => "../../Source/RoomFinderAI/Views/LoginView.swift",
  "SignUpView.swift" => "../../Source/RoomFinderAI/Views/SignUpView.swift",
  "DashboardView.swift" => "../../Source/RoomFinderAI/Views/DashboardView.swift",
  "ListingsView.swift" => "../../Source/RoomFinderAI/Views/ListingsView.swift",
  "PropertyDetailView.swift" => "../../Source/RoomFinderAI/Views/PropertyDetailView.swift",
  "ChatView.swift" => "../../Source/RoomFinderAI/Views/ChatView.swift",
  "User.swift" => "../../Source/RoomFinderAI/Models/User.swift",
  "Listing.swift" => "../../Source/RoomFinderAI/Models/Listing.swift",
  "Chat.swift" => "../../Source/RoomFinderAI/Models/Chat.swift",
  "Message.swift" => "../../Source/RoomFinderAI/Models/Message.swift",
  "Constants.swift" => "../../Source/RoomFinderAI/Utils/Constants.swift",
  "Extensions.swift" => "../../Source/RoomFinderAI/Utils/Extensions.swift"
}

# Fix each file mapping
file_mappings.each do |filename, correct_path|
  # Fix PBXFileReference entries that have just the filename as path
  content.gsub!(/(path = )#{Regexp.escape(filename)}(; sourceTree = "<group>";)/) do |match|
    "path = #{correct_path}; sourceTree = \"<group>\";"
  end
end

# Write the updated content back
File.write(project_file, content)

puts "Fixed path consistency for all core files!"
puts "All files now have the correct ../../Source/RoomFinderAI/ path"