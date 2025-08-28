#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Get the Services group
services_group = project.main_group.find_subpath('RoomFinderAI/Services')

if services_group
  # Add Secrets.swift to the project
  secrets_file = services_group.new_reference('Secrets.swift')
  secrets_file.last_known_file_type = 'sourcecode.swift'
  target.source_build_phase.add_file_reference(secrets_file)

  # Add OpenAIClient.swift to the project
  openai_file = services_group.new_reference('OpenAIClient.swift')
  openai_file.last_known_file_type = 'sourcecode.swift'
  target.source_build_phase.add_file_reference(openai_file)

  # Save the project
  project.save

  puts "✅ Successfully added Secrets.swift and OpenAIClient.swift to the project"
else
  puts "❌ Could not find Services group in project"
end