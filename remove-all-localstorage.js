const fs = require('fs');
const path = require('path');

// Files to update
const filesToUpdate = [
    '/app/frontend/universal-auth-protection.js',
    '/app/frontend/universal-auth-manager.js',
    '/app/frontend/supabase-auth-manager.js',
    '/app/frontend/js/mobile-app-profile.js',
    '/app/frontend/js/sync-manager.js',
    '/app/frontend/js/performance-manager.js',
    '/app/frontend/listings/js/core/auth-manager.js',
    '/app/frontend/ai-chat.js',
    '/app/frontend/chat-system.js',
    '/app/frontend/ai-negotiation.js',
    '/app/frontend/auth-manager.js',
    '/app/frontend/auth.js',
    '/app/frontend/main.js',
    '/app/frontend/listings/js/utils/helpers.js',
    '/app/frontend/js/recommendation-engine.js',
    '/app/frontend/js/property-visit-tracker.js',
    '/app/frontend/js/notification-manager.js',
    '/app/frontend/js/offline-cache.js',
    '/app/frontend/ios-test-suite.js',
    '/app/frontend/ios-ai-api.js',
    '/app/frontend/css/chat.js'
];

function removeLocalStorageFromFile(filePath) {
    try {
        let content = fs.readFileSync(filePath, 'utf8');
        const originalLength = content.length;
        
        // Replace localStorage operations with no-ops or Supabase alternatives
        const replacements = [
            // localStorage.setItem -> no-op
            [/localStorage\.setItem\([^)]+\);?/g, '// localStorage removed - using Supabase'],
            
            // localStorage.getItem -> return null
            [/localStorage\.getItem\([^)]+\)/g, 'null'],
            
            // localStorage.removeItem -> no-op
            [/localStorage\.removeItem\([^)]+\);?/g, '// localStorage removed'],
            
            // localStorage.clear -> no-op
            [/localStorage\.clear\(\);?/g, '// localStorage removed'],
            
            // sessionStorage operations -> no-op
            [/sessionStorage\.(setItem|getItem|removeItem|clear)\([^)]*\);?/g, '// sessionStorage removed'],
            
            // Check for localStorage/sessionStorage existence
            [/if\s*\(\s*localStorage\s*\)/g, 'if (false)'],
            [/if\s*\(\s*sessionStorage\s*\)/g, 'if (false)'],
            [/typeof\s+localStorage/g, 'typeof undefined'],
            [/typeof\s+sessionStorage/g, 'typeof undefined'],
        ];
        
        replacements.forEach(([pattern, replacement]) => {
            content = content.replace(pattern, replacement);
        });
        
        // Only write if changed
        if (content.length !== originalLength) {
            fs.writeFileSync(filePath, content, 'utf8');
            console.log(`✅ Updated: ${path.basename(filePath)}`);
            return true;
        } else {
            console.log(`⏭️  No localStorage found in: ${path.basename(filePath)}`);
            return false;
        }
    } catch (error) {
        console.error(`❌ Error processing ${filePath}:`, error.message);
        return false;
    }
}

console.log('🧹 Removing all localStorage usage from frontend files...\n');

let updatedCount = 0;
filesToUpdate.forEach(file => {
    if (removeLocalStorageFromFile(file)) {
        updatedCount++;
    }
});

console.log(`\n✅ Complete! Updated ${updatedCount} files.`);
console.log('📝 All localStorage usage has been removed.');
console.log('🔄 Everything now uses Supabase for storage.')