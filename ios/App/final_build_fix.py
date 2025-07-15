#!/usr/bin/env python3
"""
Final comprehensive fix for Xcode build issues
This will completely remove the problematic files and re-add them correctly
"""
import re
import uuid
import os

def main():
    project_file = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App.xcodeproj/project.pbxproj"
    
    print("🔧 Reading Xcode project file...")
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Files we need to fix
    files_to_fix = [
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
    
    print("🗑️  Removing ALL existing references to these files...")
    
    # Step 1: Remove ALL build file entries
    for filename in files_to_fix:
        # Remove all PBXBuildFile entries for this file
        content = re.sub(r'\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' in Sources \*/ = \{[^}]+\};\n', '', content)
    
    # Step 2: Remove ALL file reference entries
    for filename in files_to_fix:
        # Remove all PBXFileReference entries for this file
        content = re.sub(r'\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' \*/ = \{[^}]+\};\n', '', content)
    
    # Step 3: Remove from App group children
    for filename in files_to_fix:
        content = re.sub(r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' \*/,\n', '', content)
    
    # Step 4: Remove from Sources build phase
    for filename in files_to_fix:
        content = re.sub(r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' in Sources \*/,\n', '', content)
    
    # Step 5: Check which files actually exist and their correct paths
    base_path = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/"
    
    existing_files = []
    
    # Define the correct paths for each file
    file_paths = {
        'WebBridge.swift': 'App/WebBridge.swift',
        'AppModels.swift': 'App/Models/AppModels.swift',
        'MainTabView.swift': 'App/Views/MainTabView.swift',
        'HomeView.swift': 'App/Views/HomeView.swift',
        'SearchView.swift': 'App/Views/SearchView.swift',
        'PropertyDetailView.swift': 'App/Views/PropertyDetailView.swift',
        'FilterView.swift': 'App/Views/FilterView.swift',
        'AISearchView.swift': 'App/Views/AISearchView.swift',
        'ChatListView.swift': 'App/Views/ChatListView.swift',
        'ChatDetailView.swift': 'App/Views/ChatDetailView.swift',
        'ProfileView.swift': 'App/Views/ProfileView.swift',
        'SettingsView.swift': 'App/Views/SettingsView.swift',
        'SubscriptionView.swift': 'App/Views/SubscriptionView.swift',
        'NegotiationView.swift': 'App/Views/NegotiationView.swift'
    }
    
    for filename, path in file_paths.items():
        full_path = os.path.join(base_path, path)
        if os.path.exists(full_path):
            existing_files.append({'name': filename, 'path': path})
            print(f"✅ Found: {filename} at {path}")
        else:
            print(f"❌ Missing: {filename} at {path}")
    
    print(f"\n📝 Adding {len(existing_files)} files with correct paths...")
    
    # Step 6: Add the existing files with new clean UUIDs
    for file_info in existing_files:
        # Generate new UUIDs
        uuid_file = str(uuid.uuid4()).upper().replace('-', '')[:24]
        uuid_build = str(uuid.uuid4()).upper().replace('-', '')[:24]
        
        print(f"  Adding {file_info['name']}: file={uuid_file}, build={uuid_build}")
        
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
        sources_pattern = r'(504EC3001FED79650016851F /\* Sources \*/ = \{[^}]+files = \([^)]+)(\);)'
        if re.search(sources_pattern, content):
            content = re.sub(sources_pattern, r'\1\t\t\t\t' + uuid_build + f' /* {file_info["name"]} in Sources */,\n' + r'\2', content)
    
    # Step 7: Write the completely fixed project file
    print("\n💾 Writing completely fixed project file...")
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ FINAL BUILD FIX COMPLETE!")
    print(f"📊 Successfully fixed {len(existing_files)} files")
    print("🧹 Removed all old/duplicate references")
    print("🔧 Added files with correct paths and new UUIDs")
    print("🚀 Project should now build successfully!")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()