#!/usr/bin/env python3
"""
Script to add missing Swift files to Xcode project
"""
import re
import uuid

# Read the current project file
project_file = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App.xcodeproj/project.pbxproj"

with open(project_file, 'r') as f:
    content = f.read()

# Files to add
files_to_add = [
    {
        'name': 'LocalAPIKeys.swift',
        'path': 'App/LocalAPIKeys.swift',
        'uuid_file': str(uuid.uuid4()).upper().replace('-', '')[:24],
        'uuid_build': str(uuid.uuid4()).upper().replace('-', '')[:24]
    },
    {
        'name': 'iOSAPITestViewController.swift', 
        'path': 'App/iOSAPITestViewController.swift',
        'uuid_file': str(uuid.uuid4()).upper().replace('-', '')[:24],
        'uuid_build': str(uuid.uuid4()).upper().replace('-', '')[:24]
    },
    {
        'name': 'CapacitorBridge.swift',
        'path': 'App/CapacitorBridge.swift', 
        'uuid_file': str(uuid.uuid4()).upper().replace('-', '')[:24],
        'uuid_build': str(uuid.uuid4()).upper().replace('-', '')[:24]
    }
]

# Add PBXBuildFile entries
build_file_section = re.search(r'(/\* Begin PBXBuildFile section \*/.*?)(/\* End PBXBuildFile section \*/)', content, re.DOTALL)
if build_file_section:
    build_entries = build_file_section.group(1)
    for file_info in files_to_add:
        new_build_entry = f"\t\t{file_info['uuid_build']} /* {file_info['name']} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_info['uuid_file']} /* {file_info['name']} */; }};\n"
        build_entries += new_build_entry
    
    content = content.replace(build_file_section.group(1), build_entries)

# Add PBXFileReference entries  
file_ref_section = re.search(r'(/\* Begin PBXFileReference section \*/.*?)(/\* End PBXFileReference section \*/)', content, re.DOTALL)
if file_ref_section:
    file_entries = file_ref_section.group(1)
    for file_info in files_to_add:
        new_file_entry = f"\t\t{file_info['uuid_file']} /* {file_info['name']} */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = {file_info['name']}; path = {file_info['path']}; sourceTree = \"<group>\"; }};\n"
        file_entries += new_file_entry
    
    content = content.replace(file_ref_section.group(1), file_entries)

# Add to App group
app_group_pattern = r'(504EC3061FED79650016851F /\* App \*/ = \{[^}]+children = \([^)]+)'
app_group_match = re.search(app_group_pattern, content, re.DOTALL)
if app_group_match:
    app_children = app_group_match.group(1)
    for file_info in files_to_add:
        app_children += f"\t\t\t\t{file_info['uuid_file']} /* {file_info['name']} */,\n"
    
    content = content.replace(app_group_match.group(1), app_children)

# Add to Sources build phase
sources_pattern = r'(504EC3011FED79650016851F /\* Frameworks \*/ = \{[^}]+files = \([^)]+)'
# Actually, let's find the Sources build phase instead
sources_pattern = r'(/\* Sources \*/ = \{[^}]+files = \([^)]+)'
sources_match = re.search(sources_pattern, content, re.DOTALL)
if sources_match:
    sources_files = sources_match.group(1)
    for file_info in files_to_add:
        sources_files += f"\t\t\t\t{file_info['uuid_build']} /* {file_info['name']} in Sources */,\n"
    
    content = content.replace(sources_match.group(1), sources_files)

# Write back the modified project file
with open(project_file, 'w') as f:
    f.write(content)

print("✅ Successfully added missing Swift files to Xcode project:")
for file_info in files_to_add:
    print(f"   - {file_info['name']}")

print("\n🔧 Now you need to:")
print("1. Open Xcode and reload the project")
print("2. Configure your API keys in LocalAPIKeys.swift")
print("3. Build and test the app")