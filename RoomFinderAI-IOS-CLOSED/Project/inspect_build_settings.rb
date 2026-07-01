#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Inspecting build settings and configurations..."

# Check each target
project.targets.each do |target|
  puts "\n📱 Target: #{target.name}"
  
  # Check build configurations
  target.build_configurations.each do |config|
    puts "\n  Configuration: #{config.name}"
    
    # Look for any custom build settings that might reference files
    config.build_settings.each do |key, value|
      if value.to_s.include?('KeychainManager') || 
         value.to_s.include?('CDChat') ||
         value.to_s.include?('SupabaseService') ||
         value.to_s.include?('ChatViewModel')
        puts "    Found reference in #{key}: #{value}"
      end
    end
  end
  
  # Check for any input/output file lists
  target.build_phases.each do |phase|
    if phase.respond_to?(:input_paths) && phase.input_paths.any?
      puts "\n  #{phase.class.name.split('::').last} Input Paths:"
      phase.input_paths.each { |path| puts "    - #{path}" }
    end
    
    if phase.respond_to?(:input_file_list_paths) && phase.input_file_list_paths && phase.input_file_list_paths.any?
      puts "\n  #{phase.class.name.split('::').last} Input File Lists:"
      phase.input_file_list_paths.each { |path| puts "    - #{path}" }
    end
    
    if phase.respond_to?(:output_paths) && phase.output_paths.any?
      puts "\n  #{phase.class.name.split('::').last} Output Paths:"
      phase.output_paths.each { |path| puts "    - #{path}" }
    end
  end
  
  # Check for script phases
  target.shell_script_build_phases.each do |script_phase|
    puts "\n  Script Phase: #{script_phase.name || 'Unnamed'}"
    if script_phase.input_paths.any?
      puts "    Input paths: #{script_phase.input_paths}"
    end
    if script_phase.input_file_list_paths && script_phase.input_file_list_paths.any?
      puts "    Input file lists: #{script_phase.input_file_list_paths}"
    end
  end
end

puts "\n\n🔍 Checking project-level settings..."
project.build_configurations.each do |config|
  puts "\nProject Configuration: #{config.name}"
  config.build_settings.each do |key, value|
    if value.to_s.include?('Source/RoomFinderAI') || value.to_s.include?('.swift')
      puts "  #{key}: #{value}"
    end
  end
end