#!/usr/bin/env python3
"""
Final fix for Xcode project paths - correct the App/App/App issue
"""
import re

# Read the current project file
project_file = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App.xcodeproj/project.pbxproj"

# Create backup
import shutil
shutil.copy(project_file, project_file + ".backup")

with open(project_file, 'r') as f:
    content = f.read()

# The actual file structure is:
# /Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App/LocalAPIKeys.swift
# /Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App/Services/KeychainService.swift

# But the project is looking for:
# /Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App/App/LocalAPIKeys.swift
# /Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App/App/Services/KeychainService.swift

# So we need to change the paths from "App/..." to just the filename or relative path

# Define the corrections needed
path_corrections = {
    # Files in App/ directory
    'App/LocalAPIKeys.swift': 'LocalAPIKeys.swift',
    'App/iOSAPITestViewController.swift': 'iOSAPITestViewController.swift', 
    'App/CapacitorBridge.swift': 'CapacitorBridge.swift',
    'App/QuickAPITest.swift': 'QuickAPITest.swift',
    'App/APITestViewController.swift': 'APITestViewController.swift',
    
    # Files in App/Services/ directory
    'App/Services/KeychainService.swift': 'Services/KeychainService.swift',
    'App/Services/NetworkDiagnosticService.swift': 'Services/NetworkDiagnosticService.swift',
    'App/Services/NetworkInterceptorService.swift': 'Services/NetworkInterceptorService.swift',
    'App/Services/CentralizedAPIService.swift': 'Services/CentralizedAPIService.swift',
    'App/Services/NetworkDebugService.swift': 'Services/NetworkDebugService.swift',
    'App/Services/APIKeyManager.swift': 'Services/APIKeyManager.swift',
    'App/Services/AppInitializationService.swift': 'Services/AppInitializationService.swift',
    'App/Services/EnvironmentManager.swift': 'Services/EnvironmentManager.swift',
    'App/Services/MobileAPIService.swift': 'Services/MobileAPIService.swift',
}

# Apply corrections
for old_path, new_path in path_corrections.items():
    # Fix in PBXFileReference entries
    content = re.sub(
        rf'(path = ){re.escape(old_path)};',
        rf'\1{new_path};',
        content
    )

# Write the corrected file
with open(project_file, 'w') as f:
    f.write(content)

print("✅ Fixed project file paths:")
for old_path, new_path in path_corrections.items():
    print(f"   {old_path} → {new_path}")

print("\n🔧 The project should now build correctly!")
print("💡 Backup created at: " + project_file + ".backup")