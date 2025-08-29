#!/usr/bin/env ruby

require 'xcodeproj'

project_path = './RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔧 Fixing file paths in Xcode project..."

# File path corrections - remove the duplicated group names
path_fixes = {
  'App/App/RoomFinderAIApp.swift' => 'App/RoomFinderAIApp.swift',
  'Config/Config/Secrets.swift' => 'Config/Secrets.swift',
  'Config/Config/SupabaseEnvironment.swift' => 'Config/SupabaseEnvironment.swift',
  'Core/Models/Core/Models/User.swift' => 'Core/Models/User.swift',
  'Core/Models/Core/Models/Listing.swift' => 'Core/Models/Listing.swift',
  'Core/Models/Core/Models/Chat.swift' => 'Core/Models/Chat.swift',
  'Core/Models/Core/Models/Message.swift' => 'Core/Models/Message.swift',
  'Core/Extensions/Core/Extensions/Constants.swift' => 'Core/Extensions/Constants.swift',
  'Core/Extensions/Core/Extensions/Extensions.swift' => 'Core/Extensions/Extensions.swift',
  'Services/Supabase/Services/Supabase/AuthViewModel.swift' => 'Services/Supabase/AuthViewModel.swift',
  'Services/Supabase/Services/Supabase/SupabaseService.swift' => 'Services/Supabase/SupabaseService.swift',
  'Features/Listings/Features/Listings/ListingsViewModel.swift' => 'Features/Listings/ListingsViewModel.swift',
  'Features/Chat/Features/Chat/ChatViewModel.swift' => 'Features/Chat/ChatViewModel.swift',
  'Services/Services/NetworkManager.swift' => 'Services/NetworkManager.swift'
}

# Fix all file references
project.files.each do |file_ref|
  current_path = file_ref.path
  if current_path && path_fixes[current_path]
    new_path = path_fixes[current_path]
    file_ref.path = new_path
    puts "  ✅ Fixed: #{current_path} → #{new_path}"
  end
end

puts "💾 Saving fixed project..."
project.save

puts "✅ All file paths fixed!"