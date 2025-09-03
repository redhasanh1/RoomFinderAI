import { initializeAuth } from './auth.js';
import { displayListings, setupListingForm, showListingModal } from './listings.js';
import { setupChat } from './chat.js';
import { initMap } from './map.js';
import { setupAutocomplete } from './autocomplete.js';
import { config } from './config.mjs';

// Initialize Supabase with config
const supabase = window.supabase.createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY, {
    db: {
        schema: 'public'
    },
    global: {
        headers: { 'Content-Type': 'application/json' }
    }
});

document.addEventListener('DOMContentLoaded', async () => {
    const isAuthenticated = await initializeAuth(supabase);
    if (!isAuthenticated) return;

    initMap();
    setupAutocomplete();
    setupListingForm(supabase);
    setupChat(supabase);
    await displayListings(supabase);

    // Real-time subscription to listings
    supabase
        .channel('public:listings')
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'listings' }, (payload) => {
            console.log('New listing added:', payload.new);
            displayListings(supabase);
        })
        .subscribe();

    // Real-time subscription to messages for notifications
    const currentUser = JSON.parse(null);
    if (currentUser) {
        supabase
            .channel('user_messages')
            .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages' }, async (payload) => {
                const newMessage = payload.new;
                
                // Check if this message is for the current user
                const { data: conversation } = await supabase
                    .from('conversations')
                    .select('receiver_email, sender_email, listing_id')
                    .eq('id', newMessage.conversation_id)
                    .single();
                
                // Show notification if user is the receiver and not the sender
                if (conversation && 
                    conversation.receiver_email === currentUser.email && 
                    newMessage.sender_email !== currentUser.email) {
                    
                    // Show browser notification
                    if (Notification.permission === 'granted') {
                        new Notification('New Message from AI Negotiator', {
                            body: `You have a new message: "${newMessage.content.substring(0, 100)}..."`,
                            icon: '/favicon.ico'
                        });
                    }
                    
                    // Show in-page notification
                    showInPageNotification(`📨 New message received! Check your profile page.`);
                }
            })
            .subscribe();
            
        // Request notification permission
        if (Notification.permission === 'default') {
            Notification.requestPermission();
        }
    }
    
    // Function to show in-page notifications
    function showInPageNotification(message) {
        const notification = document.createElement('div');
        notification.className = 'fixed top-4 right-4 bg-blue-600 text-white px-6 py-3 rounded-lg shadow-lg z-50 transition-all duration-300';
        notification.textContent = message;
        notification.style.transform = 'translateX(100%)';
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.style.transform = 'translateX(0)';
        }, 100);
        
        setTimeout(() => {
            notification.style.transform = 'translateX(100%)';
            setTimeout(() => {
                document.body.removeChild(notification);
            }, 300);
        }, 5000);
    }

    // Modal close button
    const modal = document.getElementById('listingModal');
    const closeButton = document.querySelector('.close-button');
    closeButton.addEventListener('click', () => {
        modal.style.display = 'none';
        console.log('Modal closed');
    });

    window.addEventListener('click', (event) => {
        if (event.target === modal) {
            modal.style.display = 'none';
            console.log('Modal closed by clicking outside');
        }
    });

    // Refresh listings button
    document.querySelector('button[onclick="displayListings()"]').addEventListener('click', () => displayListings(supabase));
});