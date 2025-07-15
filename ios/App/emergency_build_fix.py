#!/usr/bin/env python3
"""
Emergency build fix - Remove all SwiftUI files temporarily to get basic build working
"""
import re
import os

def main():
    project_file = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App.xcodeproj/project.pbxproj"
    
    print("🚨 EMERGENCY BUILD FIX")
    print("🔧 Reading Xcode project file...")
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Files to temporarily remove
    swiftui_files = [
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
    
    print("🗑️  Removing ALL SwiftUI file references...")
    
    # Remove ALL build file entries
    for filename in swiftui_files:
        content = re.sub(r'\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' in Sources \*/ = \{[^}]+\};\n', '', content)
    
    # Remove ALL file reference entries
    for filename in swiftui_files:
        content = re.sub(r'\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' \*/ = \{[^}]+\};\n', '', content)
    
    # Remove from App group children
    for filename in swiftui_files:
        content = re.sub(r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' \*/,\n', '', content)
    
    # Remove from Sources build phase
    for filename in swiftui_files:
        content = re.sub(r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' in Sources \*/,\n', '', content)
    
    print("💾 Writing clean project file...")
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ Emergency fix complete!")
    print("📱 Project should now build with basic iOS functionality")
    print("⚠️  SwiftUI native views have been temporarily removed")
    print("🔄 You can re-add them later once the basic build works")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()