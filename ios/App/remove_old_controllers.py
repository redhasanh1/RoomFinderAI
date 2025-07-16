#!/usr/bin/env python3
"""
Remove old UIKit view controllers and keep only SwiftUI views
"""
import re
import os

def main():
    project_file = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App.xcodeproj/project.pbxproj"
    
    print("🗑️  Removing old UIKit view controllers...")
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Old UIKit controllers to remove
    old_controllers = [
        'HomeViewController.swift',
        'ProfileViewController.swift',
        'MainTabBarController.swift',
        'SearchViewController.swift',
        'PropertyDetailViewController.swift',
        'ChatViewController.swift',
        'FilterViewController.swift',
        'FavoritesViewController.swift',
        'AuthViewController.swift',
        'MapViewController.swift',
        'APITestViewController.swift',
        'iOSAPITestViewController.swift',
        'AINegotiatorViewController.swift',
        'LegalHelpViewController.swift',
        'LegalArticleDetailViewController.swift',
        'MortgageToolsViewController.swift',
        'PricingPlansViewController.swift',
        'StudentHousingViewController.swift',
        'RealDataTestViewController.swift',
        'DashboardViewController.swift',
        'EnhancedSearchViewController.swift',
        'CollectionViewCells.swift',
        'PropertyTableViewCell.swift'
    ]
    
    # Remove build file entries
    for filename in old_controllers:
        content = re.sub(r'\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' in Sources \*/ = \{[^}]+\};\n', '', content)
    
    # Remove file reference entries
    for filename in old_controllers:
        content = re.sub(r'\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' \*/ = \{[^}]+\};\n', '', content)
    
    # Remove from App group children
    for filename in old_controllers:
        content = re.sub(r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' \*/,\n', '', content)
    
    # Remove from Sources build phase
    for filename in old_controllers:
        content = re.sub(r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' in Sources \*/,\n', '', content)
    
    # Remove from main group (outside App folder)
    for filename in old_controllers:
        content = re.sub(r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(filename) + r' \*/,\n', '', content)
    
    print("💾 Writing cleaned project file...")
    with open(project_file, 'w') as f:
        f.write(content)
    
    # Also delete the actual files
    base_path = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App/"
    deleted_count = 0
    
    for filename in old_controllers:
        file_path = os.path.join(base_path, filename)
        if os.path.exists(file_path):
            os.remove(file_path)
            print(f"🗑️  Deleted {filename}")
            deleted_count += 1
    
    print(f"\n✅ Cleanup complete!")
    print(f"📊 Removed {deleted_count} old controller files")
    print(f"🎯 Kept SwiftUI views only")
    print(f"🚀 Project should now build with SwiftUI interface")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()