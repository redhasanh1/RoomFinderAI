// App Controller - Main application orchestrator
class AppController {
    constructor() {
        this.mapManager = null;
        this.listingsManager = null;
        this.formManager = null;
        this.messagingManager = null;
        this.supabase = null;
        this.isInitialized = false;
    }

    // Initialize the application
    async initialize() {
        console.log('🚀 Initializing RoomFinderAI Application...');
        
        try {
            // Wait for DOM to be ready
            if (document.readyState === 'loading') {
                await new Promise(resolve => {
                    document.addEventListener('DOMContentLoaded', resolve);
                });
            }

            // Initialize Supabase
            await this.initializeSupabase();
            
            // Create managers
            this.createManagers();
            
            // Initialize all managers
            await this.initializeManagers();
            
            // Setup authentication
            await this.setupAuthentication();
            
            // Setup modal handlers
            this.setupModalHandlers();
            
            // Setup global event listeners
            this.setupGlobalEventListeners();
            
            // Initialize map fallback
            this.setupMapFallback();
            
            // Setup real-time subscriptions
            this.setupRealtimeSubscriptions();
            
            // Load initial data
            await this.loadInitialData();
            
            this.isInitialized = true;
            console.log('✅ Application initialization complete!');
            
        } catch (error) {
            console.error('❌ Application initialization failed:', error);
            this.showInitializationError(error);
        }
    }

    // Initialize Supabase
    async initializeSupabase() {
        console.log('Initializing Supabase...');
        
        // Get configuration
        const SUPABASE_URL = (window.config && window.config.SUPABASE_URL) || window.SUPABASE_URL;
        const SUPABASE_ANON_KEY = (window.config && window.config.SUPABASE_ANON_KEY) || window.SUPABASE_ANON_KEY;
        
        if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
            throw new Error('Missing Supabase configuration');
        }

        // Initialize Supabase client
        if (typeof window.supabase !== 'undefined') {
            this.supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
                db: { schema: 'public' },
                global: { headers: { 'Content-Type': 'application/json' } }
            });
            
            window.supabaseClient = this.supabase; // Make globally available
            console.log('✅ Supabase initialized successfully');
        } else {
            throw new Error('Supabase library not loaded');
        }
    }

    // Create manager instances
    createManagers() {
        console.log('Creating managers...');
        this.mapManager = new MapManager();
        this.listingsManager = new ListingsManager(this.mapManager);
        this.formManager = new FormManager(this.listingsManager);
        this.messagingManager = new MessagingManager();
        console.log('✅ Managers created');
    }

    // Initialize all managers
    async initializeManagers() {
        console.log('Initializing managers...');
        
        // Initialize managers with dependencies
        this.listingsManager.initialize(this.supabase);
        this.formManager.initialize(this.supabase, window.config);
        this.messagingManager.initialize(this.supabase);
        
        console.log('✅ Managers initialized');
    }

    // Setup authentication
    async setupAuthentication() {
        console.log('Setting up authentication...');
        
        const currentUser = JSON.parse(localStorage.getItem('currentUser'));
        console.log('Current user:', currentUser);
        
        if (!currentUser) {
            console.log('No current user, redirecting to login');
            window.location.href = '/login';
            return;
        }

        // Set current user email for RLS
        try {
            const { error } = await this.supabase.rpc('set_current_user_email', { email: currentUser.email });
            console.log('RPC set_current_user_email response:', { error });
            if (error) {
                console.error('Error setting current user email:', error);
                alert('Failed to initialize session: ' + error.message);
                return;
            }
            console.log('Current user email set for RLS:', currentUser.email);
        } catch (err) {
            console.error('RPC call failed:', err);
            alert('Failed to initialize session. Please check your connection.');
            return;
        }

        // Update user profile if needed
        this.updateUserProfile(currentUser);
        
        console.log('✅ Authentication setup complete');
    }

    // Update user profile
    updateUserProfile(currentUser) {
        const profileImages = [
            'https://via.placeholder.com/40/FF6B6B',
            'https://via.placeholder.com/40/4ECDC4',
            'https://via.placeholder.com/40/FFE66D',
            'https://via.placeholder.com/40/6B7280',
            'https://via.placeholder.com/40/FF9F1C'
        ];

        if (!currentUser.profileImage) {
            currentUser.profileImage = profileImages[Math.floor(Math.random() * profileImages.length)];
            let users = JSON.parse(localStorage.getItem('users')) || [];
            users = users.map(u => u.email === currentUser.email ? currentUser : u);
            localStorage.setItem('users', JSON.stringify(users));
            localStorage.setItem('currentUser', JSON.stringify(currentUser));
        }

        // Update auth section
        const authSection = document.getElementById('authSection');
        if (authSection) {
            authSection.innerHTML = `
                <div class="flex items-center space-x-4">
                    <a href="/profile" class="profile-logo">
                        <img src="${currentUser.profileImage}" alt="Profile" class="w-10 h-10 rounded-full border-2 border-white shadow-md">
                    </a>
                    <div class="text-sm">
                        <div class="text-gray-800 font-medium">Welcome, ${currentUser.name || currentUser.email}</div>
                        <a href="/logout" class="text-gray-600 hover:text-gray-800 transition">Logout</a>
                    </div>
                </div>
            `;
        }
    }

    // Setup modal handlers
    setupModalHandlers() {
        console.log('Setting up modal handlers...');
        
        // Listing modal
        const modal = document.getElementById('listingModal');
        const closeButton = document.querySelector('.close-button');

        if (closeButton) {
            closeButton.addEventListener('click', () => {
                if (modal) modal.style.display = 'none';
                console.log('Modal closed');
            });
        }

        window.addEventListener('click', (event) => {
            if (event.target === modal) {
                if (modal) modal.style.display = 'none';
                console.log('Modal closed by clicking outside');
            }
        });
        
        console.log('✅ Modal handlers setup complete');
    }

    // Setup global event listeners
    setupGlobalEventListeners() {
        console.log('Setting up global event listeners...');
        
        // Global button handlers
        window.displayListings = () => this.listingsManager.displayListings();
        window.refreshMapOnly = () => this.mapManager.refreshMapOnly(this.listingsManager.getCurrentListings());
        window.centerMapOnUser = () => this.mapManager.centerMapOnUser();
        
        // Expose managers globally for debugging
        window.appController = this;
        window.mapManager = this.mapManager;
        window.listingsManager = this.listingsManager;
        window.messagingManager = this.messagingManager;
        
        console.log('✅ Global event listeners setup complete');
    }

    // Setup map fallback
    setupMapFallback() {
        console.log('Setting up map fallback...');
        
        // Initialize map when window loads (fallback)
        window.addEventListener('load', () => {
            console.log('🗺️ Window load event - ensuring map is initialized');
            if (!this.mapManager.isInitialized) {
                console.log('Map not initialized, initializing...');
                this.mapManager.initMap();
            }
        });
        
        console.log('✅ Map fallback setup complete');
    }

    // Setup real-time subscriptions
    setupRealtimeSubscriptions() {
        console.log('Setting up real-time subscriptions...');
        
        if (this.supabase) {
            // Listen for new listings
            this.supabase
                .channel('public:listings')
                .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'listings' }, (payload) => {
                    console.log('New listing added:', payload.new);
                    this.listingsManager.displayListings();
                })
                .subscribe((status) => {
                    console.log('Listings channel status:', status);
                });
                
            console.log('✅ Real-time subscriptions setup complete');
        }
    }

    // Load initial data
    async loadInitialData() {
        console.log('Loading initial data...');
        
        // Ensure Supabase is ready
        if (!this.supabase) {
            console.log('⏳ Waiting for Supabase initialization...');
            await new Promise(resolve => {
                const checkSupabase = () => {
                    if (this.supabase || (window.getSupabase && window.getSupabase())) {
                        this.supabase = this.supabase || window.getSupabase();
                        console.log('✅ Supabase ready, loading data');
                        resolve();
                    } else {
                        setTimeout(checkSupabase, 100);
                    }
                };
                checkSupabase();
            });
        }
        
        // Load listings and initialize map
        await this.listingsManager.displayListings();
        
        console.log('✅ Initial data loaded');
    }

    // Show initialization error
    showInitializationError(error) {
        console.error('Showing initialization error:', error);
        
        const container = document.getElementById('listingsContainer');
        if (container) {
            container.innerHTML = `
                <div class="text-center p-8">
                    <div class="text-red-500 text-lg font-semibold mb-2">⚠️ Application Failed to Initialize</div>
                    <div class="text-gray-600 mb-4">There was an error starting the application:</div>
                    <div class="bg-red-50 border border-red-200 rounded p-4 mb-4">
                        <code class="text-sm">${error.message}</code>
                    </div>
                    <div class="text-sm text-gray-500 mb-4">
                        This might be due to:
                        <ul class="list-disc list-inside mt-2">
                            <li>Network connection issues</li>
                            <li>Database configuration problems</li>
                            <li>Browser compatibility issues</li>
                            <li>Missing dependencies</li>
                        </ul>
                    </div>
                    <button onclick="location.reload()" class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition">Refresh Page</button>
                </div>
            `;
        }
        
        // Show browser-specific help for Safari
        if (window.SAFARI_MODE) {
            console.error('🍎 Safari detected - this might be a compatibility issue');
            alert('Safari Compatibility Issue Detected\\n\\nPlease try:\\n1. Update to the latest Safari version\\n2. Enable JavaScript in Safari settings\\n3. Try using Chrome or Firefox as alternative');
        }
    }

    // Get application status
    getStatus() {
        return {
            initialized: this.isInitialized,
            supabaseReady: !!this.supabase,
            managersReady: !!(this.mapManager && this.listingsManager && this.formManager && this.messagingManager),
            currentUser: JSON.parse(localStorage.getItem('currentUser'))
        };
    }
}

// Auto-initialize when script loads
document.addEventListener('DOMContentLoaded', async () => {
    console.log('DOM loaded, creating app controller...');
    window.appController = new AppController();
    await window.appController.initialize();
});

// Export for manual initialization if needed
window.AppController = AppController;