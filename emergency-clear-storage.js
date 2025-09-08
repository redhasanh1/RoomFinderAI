// Emergency localStorage clear script
// Run this in browser console to completely clear storage

function emergencyClearStorage() {
    console.log('🚨 EMERGENCY: Clearing ALL localStorage data...');
    
    // Save only essential user data
    const currentUser = localStorage.getItem('currentUser');
    const authToken = localStorage.getItem('authToken');
    
    // Clear everything
    localStorage.clear();
    
    // Restore only essential data
    if (currentUser) {
        try {
            localStorage.setItem('currentUser', currentUser);
            console.log('✅ Restored currentUser');
        } catch (e) {
            console.warn('❌ Could not restore currentUser - storage still full');
        }
    }
    
    if (authToken) {
        try {
            localStorage.setItem('authToken', authToken);
            console.log('✅ Restored authToken');
        } catch (e) {
            console.warn('❌ Could not restore authToken - storage still full');
        }
    }
    
    console.log('🎉 Emergency clear complete! Refresh the page.');
}

// Run immediately
emergencyClearStorage();