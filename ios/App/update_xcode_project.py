#!/usr/bin/env python3
"""
Script to add all new network services to Xcode project
"""
import re
import uuid

# Read the current project file
project_file = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App.xcodeproj/project.pbxproj"

with open(project_file, 'r') as f:
    content = f.read()

# New network service files to add
new_network_files = [
    {
        'name': 'NetworkDiagnosticService.swift',
        'path': 'Services/NetworkDiagnosticService.swift',
        'uuid_file': str(uuid.uuid4()).upper().replace('-', '')[:24],
        'uuid_build': str(uuid.uuid4()).upper().replace('-', '')[:24]
    },
    {
        'name': 'NetworkInterceptorService.swift',
        'path': 'Services/NetworkInterceptorService.swift',
        'uuid_file': str(uuid.uuid4()).upper().replace('-', '')[:24],
        'uuid_build': str(uuid.uuid4()).upper().replace('-', '')[:24]
    },
    {
        'name': 'CentralizedAPIService.swift',
        'path': 'Services/CentralizedAPIService.swift',
        'uuid_file': str(uuid.uuid4()).upper().replace('-', '')[:24],
        'uuid_build': str(uuid.uuid4()).upper().replace('-', '')[:24]
    },
    {
        'name': 'NetworkDebugService.swift',
        'path': 'Services/NetworkDebugService.swift',
        'uuid_file': str(uuid.uuid4()).upper().replace('-', '')[:24],
        'uuid_build': str(uuid.uuid4()).upper().replace('-', '')[:24]
    },
    {
        'name': 'APIKeyManager.swift',
        'path': 'Services/APIKeyManager.swift',
        'uuid_file': str(uuid.uuid4()).upper().replace('-', '')[:24],
        'uuid_build': str(uuid.uuid4()).upper().replace('-', '')[:24]
    },
    {
        'name': 'AppInitializationService.swift',
        'path': 'Services/AppInitializationService.swift',
        'uuid_file': str(uuid.uuid4()).upper().replace('-', '')[:24],
        'uuid_build': str(uuid.uuid4()).upper().replace('-', '')[:24]
    },
    {
        'name': 'EnvironmentManager.swift',
        'path': 'Services/EnvironmentManager.swift',
        'uuid_file': str(uuid.uuid4()).upper().replace('-', '')[:24],
        'uuid_build': str(uuid.uuid4()).upper().replace('-', '')[:24]
    },
    {
        'name': 'MobileAPIService.swift',
        'path': 'Services/MobileAPIService.swift',
        'uuid_file': str(uuid.uuid4()).upper().replace('-', '')[:24],
        'uuid_build': str(uuid.uuid4()).upper().replace('-', '')[:24]
    },
    {
        'name': 'QuickAPITest.swift',
        'path': 'App/QuickAPITest.swift',
        'uuid_file': str(uuid.uuid4()).upper().replace('-', '')[:24],
        'uuid_build': str(uuid.uuid4()).upper().replace('-', '')[:24]
    },
    {
        'name': 'APITestViewController.swift',
        'path': 'App/APITestViewController.swift',
        'uuid_file': str(uuid.uuid4()).upper().replace('-', '')[:24],
        'uuid_build': str(uuid.uuid4()).upper().replace('-', '')[:24]
    }
]

# Add PBXBuildFile entries
build_file_section = re.search(r'(/\* Begin PBXBuildFile section \*/.*?)(/\* End PBXBuildFile section \*/)', content, re.DOTALL)
if build_file_section:
    build_entries = build_file_section.group(1)
    for file_info in new_network_files:
        # Check if the file is already in the build section
        if file_info['name'] not in build_entries:
            new_build_entry = f"\t\t{file_info['uuid_build']} /* {file_info['name']} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_info['uuid_file']} /* {file_info['name']} */; }};\n"
            build_entries += new_build_entry
    
    content = content.replace(build_file_section.group(1), build_entries)

# Add PBXFileReference entries  
file_ref_section = re.search(r'(/\* Begin PBXFileReference section \*/.*?)(/\* End PBXFileReference section \*/)', content, re.DOTALL)
if file_ref_section:
    file_entries = file_ref_section.group(1)
    for file_info in new_network_files:
        # Check if the file is already in the file reference section
        if file_info['name'] not in file_entries:
            new_file_entry = f"\t\t{file_info['uuid_file']} /* {file_info['name']} */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = {file_info['name']}; path = {file_info['path']}; sourceTree = \"<group>\"; }};\n"
            file_entries += new_file_entry
    
    content = content.replace(file_ref_section.group(1), file_entries)

# Add to Services group
services_group_pattern = r'(52A776F11A4F901180D6C60F /\* Services \*/ = \{[^}]+children = \([^)]+)'
services_group_match = re.search(services_group_pattern, content, re.DOTALL)
if services_group_match:
    services_children = services_group_match.group(1)
    for file_info in new_network_files:
        if 'Services/' in file_info['path']:
            # Check if already added
            if file_info['uuid_file'] not in services_children:
                services_children += f"\t\t\t\t{file_info['uuid_file']} /* {file_info['name']} */,\n"
    
    content = content.replace(services_group_match.group(1), services_children)

# Add to App group (for non-Services files)
app_group_pattern = r'(504EC3061FED79650016851F /\* App \*/ = \{[^}]+children = \([^)]+)'
app_group_match = re.search(app_group_pattern, content, re.DOTALL)
if app_group_match:
    app_children = app_group_match.group(1)
    for file_info in new_network_files:
        if 'App/' in file_info['path']:
            # Check if already added
            if file_info['uuid_file'] not in app_children:
                app_children += f"\t\t\t\t{file_info['uuid_file']} /* {file_info['name']} */,\n"
    
    content = content.replace(app_group_match.group(1), app_children)

# Add to Sources build phase
sources_pattern = r'(504EC3001FED79650016851F /\* Sources \*/ = \{[^}]+files = \([^)]+)'
sources_match = re.search(sources_pattern, content, re.DOTALL)
if sources_match:
    sources_files = sources_match.group(1)
    for file_info in new_network_files:
        # Check if already added
        if file_info['uuid_build'] not in sources_files:
            sources_files += f"\t\t\t\t{file_info['uuid_build']} /* {file_info['name']} in Sources */,\n"
    
    content = content.replace(sources_match.group(1), sources_files)

# Write back the modified project file
with open(project_file, 'w') as f:
    f.write(content)

print("✅ Successfully added network service files to Xcode project:")
for file_info in new_network_files:
    print(f"   - {file_info['name']}")

print("\n🔧 Next steps:")
print("1. Close Xcode if it's open")
print("2. Open Xcode and reload the project")
print("3. Check that all files are properly added")
print("4. Build and test the app")
print("5. Configure API keys in the Services files")