#!/usr/bin/env python3
"""
Clean up phantom file references left over from deleted files
"""
import re

def main():
    project_file = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App.xcodeproj/project.pbxproj"
    
    print("🧹 Cleaning up phantom file references...")
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Files that we know no longer exist (phantom references)
    phantom_files = [
        'AINEGOTIATORFILE123456',
        'LEGALFILE123456789ABCD',
        'MORTGAGEFILE123456789A',
        'PRICINGFILE1234567890AB',
        'STUDENTFILE1234567890ABC',
        'KEYCHAINFILE1234567890AB'
    ]
    
    # Remove phantom build entries
    for phantom_id in phantom_files:
        content = re.sub(r'\t\t[A-F0-9]+ /\* [^*]+ in Sources \*/ = \{isa = PBXBuildFile; fileRef = ' + phantom_id + r' /\* [^*]+ \*/; \};\n', '', content)
    
    # Remove phantom file references
    for phantom_id in phantom_files:
        content = re.sub(r'\t\t' + phantom_id + r' /\* [^*]+ \*/ = \{[^}]+\};\n', '', content)
    
    # Remove from main group
    for phantom_id in phantom_files:
        content = re.sub(r'\t\t\t\t' + phantom_id + r' /\* [^*]+ \*/,\n', '', content)
    
    # Remove phantom build file entries by UUID pattern
    phantom_uuids = [
        'AINEGOTIATOR1234567890AB',
        'LEGAL123456789ABCDEF00',
        'MORTGAGE123456789ABCDEF',
        'PRICING1234567890ABCDEF',
        'STUDENT1234567890ABCDEF0',
        'KEYCHAIN1234567890ABCDEF',
        'LOCALAPI1234567890ABCDEF',
        'IOSTEST1234567890ABCDEF0',
        'CAPBRIDGE123456789ABCDEF'
    ]
    
    # Remove these phantom entries from Sources build phase
    for phantom_uuid in phantom_uuids:
        content = re.sub(r'\t\t\t\t' + phantom_uuid + r' /\* [^*]+ \*/,\n', '', content)
    
    print("💾 Writing cleaned project file...")
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ Phantom reference cleanup complete!")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()