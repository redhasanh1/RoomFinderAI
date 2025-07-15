#!/usr/bin/env python3
"""
Script to properly fix file paths in Xcode project
"""
import re

# Read the current project file
project_file = "/Users/arsalanamirali/Downloads/RoomFinderAI/ios/App/App.xcodeproj/project.pbxproj"

with open(project_file, 'r') as f:
    content = f.read()

# Fix malformed entries from previous script
content = re.sub(r'\\1App/', 'App/', content)

# Fix specific file path issues
path_fixes = [
    # Fix LocalAPIKeys.swift
    (r'(LOCALAPIFILE1234567890AB /\* LocalAPIKeys\.swift \*/ = {[^}]+path = )[^;]+;', 
     r'\1App/LocalAPIKeys.swift;'),
    
    # Fix iOSAPITestViewController.swift  
    (r'(IOSTESTFILE1234567890ABC /\* iOSAPITestViewController\.swift \*/ = {[^}]+path = )[^;]+;',
     r'\1App/iOSAPITestViewController.swift;'),
    
    # Fix CapacitorBridge.swift
    (r'(CAPBRIDGEFILE123456789A /\* CapacitorBridge\.swift \*/ = {[^}]+path = )[^;]+;',
     r'\1App/CapacitorBridge.swift;'),
    
    # Fix QuickAPITest.swift
    (r'(1F460BEDB12044D092151B68 /\* QuickAPITest\.swift \*/ = {[^}]+path = )[^;]+;',
     r'\1App/QuickAPITest.swift;'),
    
    # Fix APITestViewController.swift
    (r'(23051621E45A4FF1BE16D856 /\* APITestViewController\.swift \*/ = {[^}]+path = )[^;]+;',
     r'\1App/APITestViewController.swift;'),
    
    # Fix Network Services
    (r'(326B01199B7D4F6FB54A1548 /\* NetworkDiagnosticService\.swift \*/ = {[^}]+path = )[^;]+;',
     r'\1App/Services/NetworkDiagnosticService.swift;'),
    
    (r'(5417EA04936449BC81CB21A5 /\* NetworkInterceptorService\.swift \*/ = {[^}]+path = )[^;]+;',
     r'\1App/Services/NetworkInterceptorService.swift;'),
    
    (r'(E3367B52B8814A8CB25AD525 /\* CentralizedAPIService\.swift \*/ = {[^}]+path = )[^;]+;',
     r'\1App/Services/CentralizedAPIService.swift;'),
    
    (r'(005E7DF755854A20A76592FF /\* NetworkDebugService\.swift \*/ = {[^}]+path = )[^;]+;',
     r'\1App/Services/NetworkDebugService.swift;'),
    
    (r'(B33CB512CBB9463D9AAC1FEA /\* APIKeyManager\.swift \*/ = {[^}]+path = )[^;]+;',
     r'\1App/Services/APIKeyManager.swift;'),
    
    (r'(2A2CE7A1D8974491BC567186 /\* AppInitializationService\.swift \*/ = {[^}]+path = )[^;]+;',
     r'\1App/Services/AppInitializationService.swift;'),
    
    (r'(4B83AF618FAA4C5C86B6FEDE /\* EnvironmentManager\.swift \*/ = {[^}]+path = )[^;]+;',
     r'\1App/Services/EnvironmentManager.swift;'),
    
    (r'(4703F6BC797648BF84106A4A /\* MobileAPIService\.swift \*/ = {[^}]+path = )[^;]+;',
     r'\1App/Services/MobileAPIService.swift;'),
]

# Apply all fixes
for pattern, replacement in path_fixes:
    content = re.sub(pattern, replacement, content)

# Fix any remaining Services/ references to App/Services/
content = re.sub(r'path = Services/', 'path = App/Services/', content)

# Write back the corrected project file
with open(project_file, 'w') as f:
    f.write(content)

print("✅ Fixed file paths in Xcode project")
print("🔧 Files should now be found correctly")
print("\n📝 Next steps:")
print("1. Close Xcode completely (⌘+Q)")
print("2. Open App.xcworkspace")
print("3. Clean build folder (⌘+Shift+K)")
print("4. Build project (⌘+B)")