/**
 * Chat System Debug Script
 * Run this in browser console to diagnose chat issues
 */

console.log('🔍 Chat System Diagnostic Starting...');

// Check basic elements
const diagnostics = {
    chatModal: !!document.getElementById('chatModal'),
    chatInput: !!document.getElementById('chatInput'),
    chatSendBtn: !!document.getElementById('chatSendBtn'),
    chatMessages: !!document.getElementById('chatMessages'),
    chatTitle: !!document.getElementById('chatTitle'),
    chatCloseButton: !!document.querySelector('.chat-close-button'),
    
    // Check chat buttons
    chatButtons: document.querySelectorAll('.chat-btn'),
    enabledChatButtons: document.querySelectorAll('.chat-btn:not([disabled])'),
    disabledChatButtons: document.querySelectorAll('.chat-btn[disabled]'),
    
    // Check Supabase
    supabaseClient: !!window.supabaseClient,
    supabaseReady: !!window.supabaseReady,
    
    // Check user
    currentUser: !!localStorage.getItem('currentUser'),
    userEmail: JSON.parse(localStorage.getItem('currentUser') || '{}').email
};

console.log('📊 Chat System Diagnostics:', diagnostics);

// Test chat button functionality
if (diagnostics.enabledChatButtons.length > 0) {
    console.log('🔘 Testing first enabled chat button...');
    const firstChatBtn = diagnostics.enabledChatButtons[0];
    
    console.log('Chat button dataset:', firstChatBtn.dataset);
    console.log('Chat button onclick:', firstChatBtn.onclick);
    console.log('Chat button event listeners:', getEventListeners ? getEventListeners(firstChatBtn) : 'getEventListeners not available');
    
    // Try to parse the listing data
    try {
        const listing = JSON.parse(firstChatBtn.dataset.listing);
        console.log('✅ Listing data parsed successfully:', listing);
        console.log('Has user_email:', !!listing.user_email);
        console.log('Has id:', !!listing.id);
        console.log('Has title:', !!listing.title);
    } catch (error) {
        console.error('❌ Failed to parse listing data:', error);
    }
} else {
    console.warn('⚠️ No enabled chat buttons found');
}

// Test startConversation function
if (typeof startConversation === 'function') {
    console.log('✅ startConversation function is available');
} else {
    console.error('❌ startConversation function is not defined');
}

// Check for any JavaScript errors
console.log('🔍 Checking for JavaScript errors...');
if (window.addEventListener) {
    let errorCount = 0;
    window.addEventListener('error', function(e) {
        errorCount++;
        console.error('JavaScript Error #' + errorCount + ':', e.error);
    });
    console.log('✅ Error listener attached');
}

console.log('✅ Chat System Diagnostic Complete');