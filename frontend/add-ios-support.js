/**
 * Add iOS Support to Existing HTML Files
 * 
 * This script adds the necessary iOS networking support to your existing HTML files.
 * Just include this script in your HTML files and all fetch() calls will work on iOS.
 */

// Add this to the <head> section of your existing HTML files
const iOS_SUPPORT_SCRIPT = `
<!-- iOS WebView Support -->
<script type="module">
    import { Capacitor } from '@capacitor/core';
    
    // Only load iOS support on native platforms
    if (Capacitor.isNativePlatform()) {
        console.log('🍎 Loading iOS support...');
        
        // Load network interceptor
        import('./capacitor-fetch-interceptor.js').then(() => {
            console.log('✅ iOS network interceptor loaded');
        }).catch(error => {
            console.error('❌ Failed to load iOS network interceptor:', error);
        });
        
        // Load anonymous Supabase config
        import('./supabase-anon-config.js').then(() => {
            console.log('✅ iOS Supabase config loaded');
        }).catch(error => {
            console.error('❌ Failed to load iOS Supabase config:', error);
        });
    } else {
        console.log('🌐 Running on web - iOS support not needed');
    }
</script>
`;

// Function to add iOS support to an HTML file
function addIOSSupportToHTML(htmlContent) {
    // Find the closing </head> tag and insert the iOS support script before it
    const headCloseIndex = htmlContent.indexOf('</head>');
    if (headCloseIndex !== -1) {
        return htmlContent.slice(0, headCloseIndex) + iOS_SUPPORT_SCRIPT + htmlContent.slice(headCloseIndex);
    }
    
    // If no </head> tag found, add it after <head>
    const headOpenIndex = htmlContent.indexOf('<head>');
    if (headOpenIndex !== -1) {
        const insertIndex = htmlContent.indexOf('>', headOpenIndex) + 1;
        return htmlContent.slice(0, insertIndex) + iOS_SUPPORT_SCRIPT + htmlContent.slice(insertIndex);
    }
    
    // If no <head> tag found, add it at the beginning of the body
    const bodyIndex = htmlContent.indexOf('<body>');
    if (bodyIndex !== -1) {
        return htmlContent.slice(0, bodyIndex) + iOS_SUPPORT_SCRIPT + htmlContent.slice(bodyIndex);
    }
    
    // Last resort: add it at the beginning of the document
    return iOS_SUPPORT_SCRIPT + htmlContent;
}

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { addIOSSupportToHTML, iOS_SUPPORT_SCRIPT };
}

// Browser usage
if (typeof window !== 'undefined') {
    window.addIOSSupportToHTML = addIOSSupportToHTML;
    window.iOS_SUPPORT_SCRIPT = iOS_SUPPORT_SCRIPT;
}

console.log('✅ iOS support script loaded');

// Instructions for manual integration
console.log(`
📱 To add iOS support to your existing HTML files:

1. Add this script to the <head> section of each HTML file:
${iOS_SUPPORT_SCRIPT}

2. Or copy the following files to your frontend directory:
   - capacitor-fetch-interceptor.js
   - supabase-anon-config.js

3. Update your main HTML files (index.html, login.html, etc.) to include iOS support

4. Your existing JavaScript code will work without changes!
`);