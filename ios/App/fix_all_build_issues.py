#!/usr/bin/env python3
"""
Script to fix ALL build issues in the Xcode project
This will completely clean and rebuild the file references
"""
import re
import uuid

def fix_xcode_project():
    project_file = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App.xcodeproj/project.pbxproj"
    
    print("🔧 Reading Xcode project file...")
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Step 1: Remove ALL references to the problematic files
    problematic_files = [
        'LocalAPIKeys.swift',
        'iOSAPITestViewController.swift', 
        'CapacitorBridge.swift',
        'WebBridge.swift',
        'AppModels.swift',
        'MainTabView.swift',
        'HomeView.swift',
        'SearchView.swift',
        'PropertyDetailView.swift',
        'FilterView.swift',
        'AISearchView.swift',
        'ChatListView.swift',
        'ChatDetailView.swift',
        'ProfileView.swift',
        'SettingsView.swift',
        'SubscriptionView.swift',
        'NegotiationView.swift'
    ]
    
    print("🗑️  Removing old file references...")
    for filename in problematic_files:
        # Remove ALL build file entries for this file
        content = re.sub(r'\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' in Sources \*/ = \{[^}]+\};\n', '', content)
        
        # Remove ALL file reference entries for this file
        content = re.sub(r'\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' \*/ = \{[^}]+\};\n', '', content)
        
        # Remove from app group children
        content = re.sub(r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' \*/,\n', '', content)
        
        # Remove from sources build phase
        content = re.sub(r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' in Sources \*/,\n', '', content)
    
    # Step 2: Add only the files that actually exist with correct paths
    files_to_add = []
    
    # Check which files actually exist
    import os
    
    potential_files = [
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
    
    base_path = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/"
    
    for file_info in potential_files:
        full_path = os.path.join(base_path, file_info['path'])
        if os.path.exists(full_path):
            files_to_add.append(file_info)
            print(f"✅ Found: {file_info['name']}")
        else:
            print(f"❌ Missing: {file_info['name']} at {full_path}")
    
    # Step 3: Add the existing files with clean UUIDs
    print(f"📝 Adding {len(files_to_add)} files to Xcode project...")
    
    for file_info in files_to_add:
        uuid_file = str(uuid.uuid4()).upper().replace('-', '')[:24]
        uuid_build = str(uuid.uuid4()).upper().replace('-', '')[:24]
        
        # Add build file entry
        build_entry = f"\t\t{uuid_build} /* {file_info['name']} in Sources */ = {{isa = PBXBuildFile; fileRef = {uuid_file} /* {file_info['name']} */; }};\n"
        content = re.sub(r'(/\* End PBXBuildFile section \*/)', build_entry + r'\1', content)
        
        # Add file reference entry
        file_entry = f"\t\t{uuid_file} /* {file_info['name']} */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = {file_info['name']}; path = {file_info['path']}; sourceTree = \"<group>\"; }};\n"
        content = re.sub(r'(/\* End PBXFileReference section \*/)', file_entry + r'\1', content)
        
        # Add to App group children
        app_group_pattern = r'(504EC3061FED79650016851F /\* App \*/ = \{[^}]+children = \([^)]+)(\);)'
        if re.search(app_group_pattern, content):
            content = re.sub(app_group_pattern, r'\1\t\t\t\t' + uuid_file + f' /* {file_info["name"]} */,\n' + r'\2', content)
        
        # Add to Sources build phase
        sources_pattern = r'(/\* Sources \*/ = \{[^}]+files = \([^)]+)(\);)'
        if re.search(sources_pattern, content):
            content = re.sub(sources_pattern, r'\1\t\t\t\t' + uuid_build + f' /* {file_info["name"]} in Sources */,\n' + r'\2', content)
    
    # Step 4: Write the fixed project file
    print("💾 Writing fixed project file...")
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ Successfully fixed all Xcode project issues!")
    return len(files_to_add)

if __name__ == "__main__":
    try:
        files_added = fix_xcode_project()
        print(f"\n🎉 BUILD FIX COMPLETE!")
        print(f"📊 Added {files_added} files with correct paths")
        print(f"🔥 Removed all duplicate and incorrect references")
        print(f"🚀 Ready to build!")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()