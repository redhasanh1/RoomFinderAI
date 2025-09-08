// Cleanup script for localStorage quota issues
// Run this in browser console if you're experiencing storage quota errors

function cleanupLocalStorage() {
    console.log('🧹 Starting localStorage cleanup...');
    
    let totalFreed = 0;
    
    // 1. Clean up old chat history
    let cleanedChats = 0;
    for (let i = localStorage.length - 1; i >= 0; i--) {
        const key = localStorage.key(i);
        if (key && key.includes('chatHistory_')) {
            const size = localStorage.getItem(key).length;
            localStorage.removeItem(key);
            totalFreed += size;
            cleanedChats++;
        }
    }
    console.log(`✅ Cleaned ${cleanedChats} chat history entries`);
    
    // 2. Clean up cached data
    let cleanedCache = 0;
    for (let i = localStorage.length - 1; i >= 0; i--) {
        const key = localStorage.key(i);
        if (key && (key.includes('cache_') || key.includes('temp_'))) {
            const size = localStorage.getItem(key).length;
            localStorage.removeItem(key);
            totalFreed += size;
            cleanedCache++;
        }
    }
    console.log(`✅ Cleaned ${cleanedCache} cached entries`);
    
    // 3. Clean up oversized users array by removing listing data (keep it in userListings_ keys)
    try {
        const users = JSON.parse(localStorage.getItem('users')) || [];
        console.log(`📊 Users array size before cleanup: ${JSON.stringify(users).length} characters`);
        
        const cleanUsers = users.map(user => ({
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            password: user.password,
            verified: user.verified,
            profileImage: user.profileImage,
            hasCustomProfileImage: user.hasCustomProfileImage
            // Remove: listings array (this is what's causing quota issues)
        }));
        
        const originalSize = JSON.stringify(users).length;
        const newSize = JSON.stringify(cleanUsers).length;
        const savedSpace = originalSize - newSize;
        
        localStorage.setItem('users', JSON.stringify(cleanUsers));
        totalFreed += savedSpace;
        
        console.log(`✅ Cleaned users array: ${originalSize} → ${newSize} characters (saved ${savedSpace})`);
    } catch (error) {
        console.log('⚠️ Could not clean users array:', error.message);
    }
    
    // 4. Report results
    const totalMB = (totalFreed / (1024 * 1024)).toFixed(2);
    console.log(`🎉 Cleanup complete! Freed approximately ${totalMB}MB of localStorage space`);
    
    // 5. Check remaining space
    try {
        const testData = new Array(1024 * 1024).join('x'); // 1MB test
        localStorage.setItem('__test__', testData);
        localStorage.removeItem('__test__');
        console.log('✅ Storage is healthy - can still write data');
    } catch (error) {
        console.warn('⚠️ Storage may still be near capacity');
    }
}

// Auto-run cleanup if quota exceeded
window.addEventListener('error', function(e) {
    if (e.error && e.error.name === 'QuotaExceededError') {
        console.log('🚨 Quota exceeded error detected, running automatic cleanup...');
        cleanupLocalStorage();
    }
});

// Export for manual use
window.cleanupLocalStorage = cleanupLocalStorage;

console.log('📋 localStorage cleanup script loaded. Run cleanupLocalStorage() to clean up storage.');