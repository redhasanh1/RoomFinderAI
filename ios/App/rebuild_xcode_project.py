#!/usr/bin/env python3
"""
Script to rebuild Xcode project file with correct paths
"""
import os
import uuid

# Read the current project file
project_file = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App.xcodeproj/project.pbxproj"

# First, let's create a backup
os.system(f"cp '{project_file}' '{project_file}.backup'")

# Read the original file
with open(project_file, 'r') as f:
    content = f.read()

# Files that exist and need proper project integration
existing_files = [
    # Main app files
    {'name': 'LocalAPIKeys.swift', 'path': 'App/LocalAPIKeys.swift', 'group': 'App'},
    {'name': 'iOSAPITestViewController.swift', 'path': 'App/iOSAPITestViewController.swift', 'group': 'App'},
    {'name': 'CapacitorBridge.swift', 'path': 'App/CapacitorBridge.swift', 'group': 'App'},
    {'name': 'QuickAPITest.swift', 'path': 'App/QuickAPITest.swift', 'group': 'App'},
    {'name': 'APITestViewController.swift', 'path': 'App/APITestViewController.swift', 'group': 'App'},
    
    # Services
    {'name': 'NetworkDiagnosticService.swift', 'path': 'App/Services/NetworkDiagnosticService.swift', 'group': 'Services'},
    {'name': 'NetworkInterceptorService.swift', 'path': 'App/Services/NetworkInterceptorService.swift', 'group': 'Services'},
    {'name': 'CentralizedAPIService.swift', 'path': 'App/Services/CentralizedAPIService.swift', 'group': 'Services'},
    {'name': 'NetworkDebugService.swift', 'path': 'App/Services/NetworkDebugService.swift', 'group': 'Services'},
    {'name': 'APIKeyManager.swift', 'path': 'App/Services/APIKeyManager.swift', 'group': 'Services'},
    {'name': 'AppInitializationService.swift', 'path': 'App/Services/AppInitializationService.swift', 'group': 'Services'},
    {'name': 'EnvironmentManager.swift', 'path': 'App/Services/EnvironmentManager.swift', 'group': 'Services'},
    {'name': 'MobileAPIService.swift', 'path': 'App/Services/MobileAPIService.swift', 'group': 'Services'},
]

# Generate new UUIDs for files
for file_info in existing_files:
    file_info['uuid_file'] = str(uuid.uuid4()).upper().replace('-', '')[:24]
    file_info['uuid_build'] = str(uuid.uuid4()).upper().replace('-', '')[:24]

# Remove any malformed entries
content = content.replace('App/CapacitorBridge.swift; sourceTree = "<group>"; };', '')
content = content.replace('App/iOSAPITestViewController.swift; sourceTree = "<group>"; };', '')
content = content.replace('App/LocalAPIKeys.swift; sourceTree = "<group>"; };', '')
content = content.replace('App/QuickAPITest.swift; sourceTree = "<group>"; };', '')
content = content.replace('App/Services/NetworkDiagnosticService.swift; sourceTree = "<group>"; };', '')
content = content.replace('App/Services/NetworkInterceptorService.swift; sourceTree = "<group>"; };', '')
content = content.replace('App/Services/CentralizedAPIService.swift; sourceTree = "<group>"; };', '')
content = content.replace('App/Services/NetworkDebugService.swift; sourceTree = "<group>"; };', '')
content = content.replace('App/Services/APIKeyManager.swift; sourceTree = "<group>"; };', '')
content = content.replace('App/Services/AppInitializationService.swift; sourceTree = "<group>"; };', '')
content = content.replace('App/Services/EnvironmentManager.swift; sourceTree = "<group>"; };', '')
content = content.replace('App/Services/MobileAPIService.swift; sourceTree = "<group>"; };', '')

# Find and update PBXBuildFile section
build_files_section = content.find('/* Begin PBXBuildFile section */')
build_files_end = content.find('/* End PBXBuildFile section */')

if build_files_section != -1 and build_files_end != -1:
    # Add new build file entries
    new_build_entries = "\n"
    for file_info in existing_files:
        new_build_entries += f"\t\t{file_info['uuid_build']} /* {file_info['name']} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_info['uuid_file']} /* {file_info['name']} */; }};\n"
    
    # Insert before the end of the section
    content = content[:build_files_end] + new_build_entries + content[build_files_end:]

# Find and update PBXFileReference section
file_ref_section = content.find('/* Begin PBXFileReference section */')
file_ref_end = content.find('/* End PBXFileReference section */')

if file_ref_section != -1 and file_ref_end != -1:
    # Add new file reference entries
    new_file_entries = "\n"
    for file_info in existing_files:
        new_file_entries += f"\t\t{file_info['uuid_file']} /* {file_info['name']} */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = {file_info['name']}; path = {file_info['path']}; sourceTree = \"<group>\"; }};\n"
    
    # Insert before the end of the section
    content = content[:file_ref_end] + new_file_entries + content[file_ref_end:]

# Find and update Services group
services_group_start = content.find('52A776F11A4F901180D6C60F /* Services */ = {')
if services_group_start != -1:
    # Find the children array
    children_start = content.find('children = (', services_group_start)
    children_end = content.find(');', children_start)
    
    if children_start != -1 and children_end != -1:
        # Add service files to the group
        new_services = "\n"
        for file_info in existing_files:
            if file_info['group'] == 'Services':
                new_services += f"\t\t\t\t{file_info['uuid_file']} /* {file_info['name']} */,\n"
        
        # Insert before the closing of children
        content = content[:children_end] + new_services + "\t\t\t" + content[children_end:]

# Find and update App group
app_group_start = content.find('504EC3061FED79650016851F /* App */ = {')
if app_group_start != -1:
    # Find the children array
    children_start = content.find('children = (', app_group_start)
    children_end = content.find(');', children_start)
    
    if children_start != -1 and children_end != -1:
        # Add app files to the group
        new_app_files = "\n"
        for file_info in existing_files:
            if file_info['group'] == 'App':
                new_app_files += f"\t\t\t\t{file_info['uuid_file']} /* {file_info['name']} */,\n"
        
        # Insert before the closing of children
        content = content[:children_end] + new_app_files + "\t\t\t" + content[children_end:]

# Find and update Sources build phase
sources_phase_start = content.find('504EC3001FED79650016851F /* Sources */ = {')
if sources_phase_start != -1:
    # Find the files array
    files_start = content.find('files = (', sources_phase_start)
    files_end = content.find(');', files_start)
    
    if files_start != -1 and files_end != -1:
        # Add source files to the build phase
        new_sources = "\n"
        for file_info in existing_files:
            new_sources += f"\t\t\t\t{file_info['uuid_build']} /* {file_info['name']} in Sources */,\n"
        
        # Insert before the closing of files
        content = content[:files_end] + new_sources + "\t\t\t" + content[files_end:]

# Write back the corrected project file
with open(project_file, 'w') as f:
    f.write(content)

print("✅ Rebuilt Xcode project with correct file paths:")
for file_info in existing_files:
    print(f"   - {file_info['name']} → {file_info['path']}")

print("\n🔧 Next steps:")
print("1. Close Xcode completely (⌘+Q)")
print("2. Open App.xcworkspace")
print("3. Clean build folder (⌘+Shift+K)")
print("4. Build project (⌘+B)")
print("5. If issues persist, restore backup and try again")
print(f"   Backup location: {project_file}.backup")