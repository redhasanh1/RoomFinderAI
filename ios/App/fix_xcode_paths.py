#!/usr/bin/env python3
"""
Script to fix incorrect file paths in Xcode project
"""
import re

# Read the current project file
project_file = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App.xcodeproj/project.pbxproj"

with open(project_file, 'r') as f:
    content = f.read()

# Files that need path corrections
files_to_fix = {
    'LocalAPIKeys.swift': 'App/LocalAPIKeys.swift',
    'iOSAPITestViewController.swift': 'App/iOSAPITestViewController.swift',
    'CapacitorBridge.swift': 'App/CapacitorBridge.swift',
    'QuickAPITest.swift': 'App/QuickAPITest.swift',
    'APITestViewController.swift': 'App/APITestViewController.swift',
    'NetworkDiagnosticService.swift': 'App/Services/NetworkDiagnosticService.swift',
    'NetworkInterceptorService.swift': 'App/Services/NetworkInterceptorService.swift',
    'CentralizedAPIService.swift': 'App/Services/CentralizedAPIService.swift',
    'NetworkDebugService.swift': 'App/Services/NetworkDebugService.swift',
    'APIKeyManager.swift': 'App/Services/APIKeyManager.swift',
    'AppInitializationService.swift': 'App/Services/AppInitializationService.swift',
    'EnvironmentManager.swift': 'App/Services/EnvironmentManager.swift',
    'MobileAPIService.swift': 'App/Services/MobileAPIService.swift'
}

# Fix file paths in PBXFileReference sections
for filename, correct_path in files_to_fix.items():
    # Pattern to match PBXFileReference entries
    pattern = rf'(.*{filename}.*path = )[^;]+;'
    replacement = rf'\\1{correct_path};'
    content = re.sub(pattern, replacement, content)

# Also fix any references to Services/ path
content = re.sub(r'path = Services/', 'path = App/Services/', content)

# Write back the corrected project file
with open(project_file, 'w') as f:
    f.write(content)

print("✅ Fixed file paths in Xcode project:")
for filename, path in files_to_fix.items():
    print(f"   - {filename} → {path}")

print("\n🔧 Next steps:")
print("1. Close Xcode completely")
print("2. Open App.xcworkspace again")
print("3. Clean build folder (⌘+Shift+K)")
print("4. Build project (⌘+B)")