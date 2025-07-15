#!/usr/bin/env python3
"""
Script to fix incorrect file paths in Xcode project
"""
import re

# Read the current project file
project_file = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App.xcodeproj/project.pbxproj"

with open(project_file, 'r') as f:
    content = f.read()

# Fix incorrect paths - remove the extra "App/" prefix
fixes = [
    ('App/App/Views/', 'App/Views/'),
    ('App/App/Models/', 'App/Models/'),
    ('App/App/WebBridge.swift', 'App/WebBridge.swift'),
    ('App/App/CapacitorBridge.swift', 'App/CapacitorBridge.swift'),
    ('App/App/iOSAPITestViewController.swift', 'App/iOSAPITestViewController.swift'),
    ('App/App/LocalAPIKeys.swift', 'App/LocalAPIKeys.swift')
]

for old_path, new_path in fixes:
    content = content.replace(old_path, new_path)

# Write back the modified project file
with open(project_file, 'w') as f:
    f.write(content)

print("✅ Fixed file paths in Xcode project")
print("🔧 Corrected paths:")
for old_path, new_path in fixes:
    print(f"   {old_path} → {new_path}")