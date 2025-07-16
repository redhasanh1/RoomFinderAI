#!/usr/bin/env python3
"""
Script to completely rebuild the file references in Xcode project
"""
import re
import uuid

# Read the current project file
project_file = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App.xcodeproj/project.pbxproj"

with open(project_file, 'r') as f:
    content = f.read()

# List of new files with correct paths
new_files = [
    {'name': 'WebBridge.swift', 'path': 'App/WebBridge.swift'},
    {'name': 'AppModels.swift', 'path': 'App/Models/AppModels.swift'},
    {'name': 'MainTabView.swift', 'path': 'App/Views/MainTabView.swift'},
    {'name': 'HomeView.swift', 'path': 'App/Views/HomeView.swift'},
    {'name': 'SearchView.swift', 'path': 'App/Views/SearchView.swift'},
    {'name': 'PropertyDetailView.swift', 'path': 'App/Views/PropertyDetailView.swift'},
    {'name': 'FilterView.swift', 'path': 'App/Views/FilterView.swift'},
    {'name': 'AISearchView.swift', 'path': 'App/Views/AISearchView.swift'},
    {'name': 'ChatListView.swift', 'path': 'App/Views/ChatListView.swift'},
    {'name': 'ChatDetailView.swift', 'path': 'App/Views/ChatDetailView.swift'},
    {'name': 'ProfileView.swift', 'path': 'App/Views/ProfileView.swift'},
    {'name': 'SettingsView.swift', 'path': 'App/Views/SettingsView.swift'},
    {'name': 'SubscriptionView.swift', 'path': 'App/Views/SubscriptionView.swift'},
    {'name': 'NegotiationView.swift', 'path': 'App/Views/NegotiationView.swift'}
]

# Remove all existing entries for these files (both correct and incorrect paths)
for file_info in new_files:
    # Remove old build file entries
    content = re.sub(r'\t\t[A-F0-9]+ /\* ' + re.escape(file_info['name']) + r' in Sources \*/ = \{isa = PBXBuildFile; fileRef = [A-F0-9]+ /\* ' + re.escape(file_info['name']) + r' \*/; \};\n', '', content)
    
    # Remove old file reference entries
    content = re.sub(r'\t\t[A-F0-9]+ /\* ' + re.escape(file_info['name']) + r' \*/ = \{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode\.swift; name = ' + re.escape(file_info['name']) + r'; path = [^;]+; sourceTree = "<group>"; \};\n', '', content)
    
    # Remove from app group children
    content = re.sub(r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(file_info['name']) + r' \*/,\n', '', content)
    
    # Remove from sources build phase
    content = re.sub(r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(file_info['name']) + r' in Sources \*/,\n', '', content)

# Generate new UUIDs and add clean entries
print("Adding files with new UUIDs:")
for file_info in new_files:
    uuid_file = str(uuid.uuid4()).upper().replace('-', '')[:24]
    uuid_build = str(uuid.uuid4()).upper().replace('-', '')[:24]
    
    print(f"  {file_info['name']}: {uuid_file} / {uuid_build}")
    
    # Add new build file entry
    build_entry = f"\t\t{uuid_build} /* {file_info['name']} in Sources */ = {{isa = PBXBuildFile; fileRef = {uuid_file} /* {file_info['name']} */; }};\n"
    
    # Find the end of PBXBuildFile section and add before it
    content = re.sub(r'(/\* End PBXBuildFile section \*/)', build_entry + r'\1', content)
    
    # Add new file reference entry
    file_entry = f"\t\t{uuid_file} /* {file_info['name']} */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = {file_info['name']}; path = {file_info['path']}; sourceTree = \"<group>\"; }};\n"
    
    # Find the end of PBXFileReference section and add before it
    content = re.sub(r'(/\* End PBXFileReference section \*/)', file_entry + r'\1', content)
    
    # Add to App group children
    app_group_pattern = r'(504EC3061FED79650016851F /\* App \*/ = \{[^}]+children = \([^)]+)(\);)'
    if re.search(app_group_pattern, content):
        content = re.sub(app_group_pattern, r'\1\t\t\t\t' + uuid_file + f' /* {file_info["name"]} */,\n' + r'\2', content)
    
    # Add to Sources build phase
    sources_pattern = r'(/\* Sources \*/ = \{[^}]+files = \([^)]+)(\);)'
    if re.search(sources_pattern, content):
        content = re.sub(sources_pattern, r'\1\t\t\t\t' + uuid_build + f' /* {file_info["name"]} in Sources */,\n' + r'\2', content)

# Write back the modified project file
with open(project_file, 'w') as f:
    f.write(content)

print("✅ Successfully rebuilt Xcode project with clean file references")
print("🔧 All files now use correct paths and new UUIDs")