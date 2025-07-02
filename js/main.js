// Main application initialization and orchestration
window.App = (function() {
    
    // Main initialization function (equivalent to initializeListingsPage)
    async function initializeListingsPage() {
        console.log('🚀 Starting main application initialization');

        // Check authentication first
        if (!window.AuthManager.requireAuth()) {
            return;
        }

        // Initialize user session with RLS
        const sessionInitialized = await window.AuthManager.initializeSession();
        if (!sessionInitialized) {
            return;
        }

        // Update profile UI
        window.AuthManager.updateProfileUI();

        // Initialize all modules
        console.log('📱 Initializing application modules...');
        
        // Initialize map
        window.MapManager.initialize();
        
        // Initialize search functionality
        window.SearchManager.initialize();
        
        // Initialize listings
        window.ListingsManager.initialize();
        
        // Setup UI event handlers
        setupUIEventHandlers();
        
        // Setup real-time subscriptions if chat is available
        if (window.ChatManager) {
            window.ChatManager.initialize();
        }
        
        console.log('✅ Main application initialization completed');
    }

    // Setup UI event handlers
    function setupUIEventHandlers() {
        // Refresh buttons
        const refreshListingsBtn = document.getElementById('refreshListingsBtn');
        if (refreshListingsBtn) {
            refreshListingsBtn.addEventListener('click', () => {
                console.log('🔄 Manual refresh triggered');
                window.ListingsManager.displayListings();
            });
        }

        const refreshMapBtn = document.getElementById('refreshMapBtn');
        if (refreshMapBtn) {
            refreshMapBtn.addEventListener('click', () => {
                console.log('🗺️ Manual map refresh triggered');
                window.MapManager.resizeMap();
                if (window.ListingsManager.allListings) {
                    window.MapManager.updateWithListings(window.ListingsManager.allListings);
                }
            });
        }

        // Clear filters button
        const clearFiltersBtn = document.getElementById('clearFiltersBtn');
        if (clearFiltersBtn) {
            clearFiltersBtn.addEventListener('click', window.SearchManager.clearSearchFilters);
        }

        // Modal close handlers
        setupModalHandlers();
        
        console.log('🎛️ UI event handlers setup completed');
    }

    // Setup modal handlers
    function setupModalHandlers() {
        // Setup listing modal
        const listingModal = document.getElementById('listingModal');
        if (listingModal) {
            listingModal.addEventListener('click', (e) => {
                if (e.target === listingModal) {
                    listingModal.classList.remove('active');
                }
            });
        }

        // Setup chat modal if it exists
        const chatModal = document.getElementById('chatModal');
        if (chatModal) {
            chatModal.addEventListener('click', (e) => {
                if (e.target === chatModal) {
                    chatModal.classList.remove('active');
                }
            });
        }
    }

    // Setup real-time database subscriptions
    function setupRealtimeSubscriptions() {
        if (!window.AppConfig.supabase) {
            console.error('Supabase not initialized');
            return;
        }

        // Subscribe to listings changes
        const listingsSubscription = window.AppConfig.supabase
            .channel('listings_changes')
            .on('postgres_changes', 
                { 
                    event: 'INSERT', 
                    schema: 'public', 
                    table: 'listings' 
                }, 
                (payload) => {
                    console.log('📝 New listing added:', payload.new);
                    // Refresh listings display
                    window.ListingsManager.displayListings();
                }
            )
            .subscribe();

        console.log('📡 Real-time subscriptions setup completed');
        return listingsSubscription;
    }

    // Show error message to user
    function showError(message) {
        console.error('Application Error:', message);
        if (window.Utils) {
            window.Utils.showError(message);
        } else {
            alert(message);
        }
    }

    // Global error handler
    function setupGlobalErrorHandler() {
        window.addEventListener('error', (event) => {
            console.error('Global error:', event.error);
            showError('An unexpected error occurred. Please refresh the page.');
        });

        window.addEventListener('unhandledrejection', (event) => {
            console.error('Unhandled promise rejection:', event.reason);
            showError('A network or processing error occurred.');
        });
    }

    // Public functions for global access
    window.showListingModal = function(listing) {
        if (window.ListingsManager) {
            window.ListingsManager.showListingModal(listing);
        }
    };

    window.startConversation = function(userEmail, listingTitle) {
        if (window.ChatManager) {
            window.ChatManager.startConversation(userEmail, listingTitle);
        } else {
            console.warn('Chat functionality not available');
            showError('Chat functionality is not available');
        }
    };

    window.startConversationFromMap = function(listingJson) {
        if (window.MapManager) {
            window.MapManager.startConversationFromMap(listingJson);
        }
    };

    // Initialize the application
    function initialize() {
        console.log('🚀 Application starting...');
        
        // Setup global error handling
        setupGlobalErrorHandler();
        
        // Initialize configuration and start app
        window.AppConfig.initialize(() => {
            // This callback runs after config is loaded and DOM is ready
            initializeListingsPage()
                .then(() => {
                    // Setup real-time subscriptions after everything is initialized
                    setupRealtimeSubscriptions();
                })
                .catch(error => {
                    console.error('Failed to initialize application:', error);
                    showError('Failed to initialize application. Please refresh the page.');
                });
        });
    }

    // Public API
    return {
        initialize,
        initializeListingsPage,
        setupUIEventHandlers,
        setupRealtimeSubscriptions,
        showError
    };
})();

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', window.App.initialize);
} else {
    window.App.initialize();
}