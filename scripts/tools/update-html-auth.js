const fs = require('fs');
const path = require('path');
const glob = require('glob');

// Find all HTML files
const htmlFiles = glob.sync('/app/frontend/**/*.html');

function updateHTMLFile(filePath) {
    try {
        let content = fs.readFileSync(filePath, 'utf8');
        const originalLength = content.length;
        
        // Replace old auth scripts with new Supabase-only auth
        const replacements = [
            // Replace universal-auth-protection.js with supabase-auth-only.js
            [/<script src="[^"]*universal-auth-protection\.js"><\/script>/g, 
             '<script src="/supabase-auth-only.js"></script>'],
            
            // Replace universal-auth-manager.js with supabase-auth-only.js
            [/<script src="[^"]*universal-auth-manager\.js"><\/script>/g, 
             '<!-- Auth handled by supabase-auth-only.js -->'],
            
            // Clean up duplicate script tags
            [/(<script src="\/supabase-auth-only\.js"><\/script>\s*)+/g, 
             '<script src="/supabase-auth-only.js"></script>']
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
            console.log(`⏭️  No changes needed: ${path.basename(filePath)}`);
            return false;
        }
    } catch (error) {
        console.error(`❌ Error processing ${filePath}:`, error.message);
        return false;
    }
}

console.log('🔄 Updating HTML files to use Supabase-only auth...\n');

let updatedCount = 0;
htmlFiles.forEach(file => {
    if (updateHTMLFile(file)) {
        updatedCount++;
    }
});

console.log(`\n✅ Complete! Updated ${updatedCount} HTML files.`);
console.log('📝 All auth now uses Supabase directly.');