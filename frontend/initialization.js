/**
 * Application Initialization Module
 * Handles application initialization, DOM ready handlers, main startup logic
 */

// Global initialization state tracking
let isDOMReady = false;
let isConfigLoaded = false;
let initializationAttempts = 0;
const MAX_INIT_ATTEMPTS = 3;

// Global system state
let systemInitialized = false;
let initializationPromise = null;

/**
 * Main application initialization function
 */
async function initializeApplication() {
    console.log('🚀 Starting application initialization...');
    
    if (initializationPromise) {
        return initializationPromise;
    }
    
    initializationPromise = new Promise(async (resolve, reject) => {
        try {
            // Step 1: Load configuration
            console.log('📋 Step 1: Loading configuration...');
            await window.ClientConfig.loadConfiguration();
            isConfigLoaded = true;
            console.log('✅ Configuration loaded successfully');
            
            // Step 2: Initialize authentication
            console.log('📋 Step 2: Initializing authentication...');
            window.AuthManager.initializeAuth();
            console.log('✅ Authentication initialized');
            
            // Step 3: Initialize the main listings page
            console.log('📋 Step 3: Initializing listings page...');
            await initializeListingsPage();
            console.log('✅ Listings page initialized');
            
            systemInitialized = true;
            console.log('🎉 Application initialization completed successfully');
            resolve();
            
        } catch (error) {
            console.error('❌ Application initialization failed:', error);
            reject(error);
        }
    });
    
    return initializationPromise;
}

/**
 * Safe initialization function with retry mechanism
 */
function attemptInitialization() {
    console.log('🚀 Attempting initialization...', {
        configLoaded: isConfigLoaded,
        domReady: isDOMReady,
        attempt: initializationAttempts + 1
    });

    if (!isConfigLoaded || !isDOMReady) {
        console.log('⏳ Waiting for prerequisites...');
        return;
    }

    initializationAttempts++;
    
    try {
        console.log(`🔄 Starting initialization attempt ${initializationAttempts}/${MAX_INIT_ATTEMPTS}`);
        initializeListingsPage();
        console.log('✅ Initialization completed successfully');
    } catch (error) {
        console.error(`❌ Initialization attempt ${initializationAttempts} failed:`, error);
        
        if (initializationAttempts < MAX_INIT_ATTEMPTS) {
            console.log(`🔄 Retrying in 1 second... (${MAX_INIT_ATTEMPTS - initializationAttempts} attempts remaining)`);
            setTimeout(() => {
                attemptInitialization();
            }, 1000);
        } else {
            console.error('💥 All initialization attempts failed. Chat system may not work properly.');
            showError('Application initialization failed. Some features may not work. Please refresh the page.');
        }
    }
}

/**
 * Initialize the listings page specifically
 */
async function initializeListingsPage() {
    console.log('🏠 Initializing listings page...');
    
    try {
        // Check authentication status
        const currentUser = window.AuthManager.getCurrentUser();
        console.log('👤 Current user status:', !!currentUser);
        
        // Update authentication UI
        window.AuthManager.updateAuthUI('authSection');
        
        // Validate authentication if user exists
        if (currentUser) {
            const authValid = await window.AuthManager.validateAndSetupAuth();
            if (!authValid) {
                console.error('❌ Authentication validation failed');
                window.AuthManager.handleAuthError('Session validation failed');
                return;
            }
        }
        
        // Initialize core page components
        await initializePageComponents();
        
        console.log('✅ Listings page initialization completed');
        
    } catch (error) {
        console.error('❌ Error initializing listings page:', error);
        throw error;
    }
}

/**
 * Initialize core page components
 */
async function initializePageComponents() {
    console.log('🔧 Initializing page components...');
    
    // Initialize map
    if (typeof initMap === 'function') {
        console.log('🗺️ Initializing map...');
        initMap();
    }
    
    // Setup chat system
    if (typeof setupChat === 'function') {
        console.log('💬 Setting up chat system...');
        setupChat();
    }
    
    // Setup messaging panel
    if (typeof setupMessagingPanel === 'function') {
        console.log('📱 Setting up messaging panel...');
        setupMessagingPanel();
    }
    
    // Initialize connection monitoring
    if (typeof initializeConnectionMonitoring === 'function') {
        console.log('📡 Initializing connection monitoring...');
        initializeConnectionMonitoring();
    }
    
    // Setup search filters
    setupSearchFilters();
    
    // Setup form handlers
    setupFormHandlers();
    
    // Setup keyboard shortcuts
    setupKeyboardShortcuts();
    
    // Setup mobile menu
    setupMobileMenu();
    
    // Setup real-time subscriptions
    setupRealTimeSubscriptions();
    
    // Display initial listings
    if (typeof displayListings === 'function') {
        console.log('📋 Loading and displaying listings...');
        await displayListings();
    }
    
    console.log('✅ All page components initialized');
}

/**
 * Setup search filters
 */
function setupSearchFilters() {
    console.log('🔍 Setting up search filters...');
    
    // Setup search button handler
    const searchBtn = document.getElementById('searchBtn');
    if (searchBtn && typeof applySearchFilters === 'function') {
        searchBtn.addEventListener('click', applySearchFilters);
    }
    
    // Setup filter input handlers
    const filterInputs = [
        'searchLocation',
        'searchMaxPrice',
        'searchRoomType',
        'searchBedrooms'
    ];
    
    filterInputs.forEach(inputId => {
        const input = document.getElementById(inputId);
        if (input) {
            input.addEventListener('change', debounce(() => {
                if (typeof applySearchFilters === 'function') {
                    applySearchFilters();
                }
            }, 500));
        }
    });
}

/**
 * Setup form handlers
 */
function setupFormHandlers() {
    console.log('📝 Setting up form handlers...');
    
    // Listing form handler
    const listingForm = document.getElementById('listingForm');
    if (listingForm) {
        listingForm.addEventListener('submit', handleListingFormSubmit);
    }
    
    // File upload handlers
    const mediaInput = document.getElementById('media');
    if (mediaInput) {
        mediaInput.addEventListener('change', handleMediaUpload);
    }
    
    // City autocomplete setup
    setupCityAutocomplete();
}

/**
 * Setup keyboard shortcuts
 */
function setupKeyboardShortcuts() {
    console.log('⌨️ Setting up keyboard shortcuts...');
    
    document.addEventListener('keydown', (e) => {
        // Ctrl+Shift+D for diagnostics panel
        if (e.ctrlKey && e.shiftKey && e.key === 'D') {
            e.preventDefault();
            if (document.getElementById('chat-diagnostics-panel')) {
                if (typeof toggleDiagnosticsPanel === 'function') {
                    toggleDiagnosticsPanel();
                }
            } else {
                if (typeof createChatDiagnosticsPanel === 'function') {
                    createChatDiagnosticsPanel();
                }
            }
        }
        
        // Escape key for closing modals and menus
        if (e.key === 'Escape') {
            closeAllModalsAndMenus();
        }
    });
}

/**
 * Setup mobile menu functionality
 */
function setupMobileMenu() {
    console.log('📱 Setting up mobile menu...');
    
    const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
    if (mobileMenuBtn) {
        mobileMenuBtn.addEventListener('click', () => {
            if (typeof toggleMobileMenu === 'function') {
                toggleMobileMenu();
            }
        });
    }
    
    // Close mobile menu when clicking outside
    const mobileMenuOverlay = document.querySelector('.mobile-menu-overlay');
    if (mobileMenuOverlay) {
        mobileMenuOverlay.addEventListener('click', () => {
            if (typeof closeMobileMenu === 'function') {
                closeMobileMenu();
            }
        });
    }
    
    // Handle window resize
    window.addEventListener('resize', () => {
        if (window.innerWidth >= 768) {
            if (typeof closeMobileMenu === 'function') {
                closeMobileMenu();
            }
        }
    });
}

/**
 * Setup real-time subscriptions
 */
function setupRealTimeSubscriptions() {
    console.log('📡 Setting up real-time subscriptions...');
    
    const supabase = window.ClientConfig.getSupabaseClient();
    if (!supabase) {
        console.warn('⚠️ Supabase client not available for real-time subscriptions');
        return;
    }
    
    // Subscribe to new listings
    supabase
        .channel('public:listings')
        .on('postgres_changes', { 
            event: 'INSERT', 
            schema: 'public', 
            table: 'listings' 
        }, (payload) => {
            console.log('📋 New listing added:', payload.new);
            if (typeof displayListings === 'function') {
                displayListings();
            }
        })
        .subscribe((status) => {
            console.log('📋 Listings channel status:', status);
        });
}

/**
 * Handle listing form submission
 */
async function handleListingFormSubmit(e) {
    e.preventDefault();
    
    const currentUser = window.AuthManager.getCurrentUser();
    if (!currentUser) {
        alert('Please log in to add a listing.');
        window.location.href = '/login';
        return;
    }
    
    // Handle form submission logic here
    // This would typically be moved to a separate listings module
    console.log('📝 Handling listing form submission...');
}

/**
 * Handle media upload
 */
function handleMediaUpload(e) {
    const files = Array.from(e.target.files);
    console.log('📎 Media files selected:', files.length);
    
    // Handle media upload logic here
    // This would typically be moved to a separate media module
}

/**
 * Setup city autocomplete
 */
function setupCityAutocomplete() {
    console.log('🌍 Setting up city autocomplete...');
    
    const cityInput = document.getElementById('city');
    const cityDropdown = document.getElementById('city-autocomplete-dropdown');
    
    if (!cityInput || !cityDropdown) {
        console.warn('⚠️ City autocomplete elements not found');
        return;
    }
    
    let debounceTimeout;
    
    cityInput.addEventListener('input', () => {
        clearTimeout(debounceTimeout);
        debounceTimeout = setTimeout(() => {
            const value = cityInput.value.trim();
            if (typeof showCitySuggestions === 'function') {
                showCitySuggestions(value);
            }
        }, 300);
    });
    
    cityInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !cityDropdown.classList.contains('hidden')) {
            const firstItem = cityDropdown.querySelector('.autocomplete-item:not(.text-gray-500)');
            if (firstItem) {
                cityInput.value = firstItem.textContent;
                cityDropdown.classList.add('hidden');
            }
            e.preventDefault();
        }
    });
    
    document.addEventListener('click', (e) => {
        if (!cityInput.contains(e.target) && !cityDropdown.contains(e.target)) {
            cityDropdown.classList.add('hidden');
        }
    });
}

/**
 * Close all modals and menus
 */
function closeAllModalsAndMenus() {
    // Close mobile menu
    if (typeof closeMobileMenu === 'function') {
        closeMobileMenu();
    }
    
    // Close dropdowns
    const allDropdowns = document.querySelectorAll('.dropdown-menu');
    allDropdowns.forEach(menu => {
        menu.style.opacity = '0';
        menu.style.visibility = 'hidden';
        menu.style.transform = 'translateY(-10px)';
    });
    
    // Close modals
    const modals = document.querySelectorAll('.modal.active, .modal[style*="block"]');
    modals.forEach(modal => {
        modal.classList.remove('active');
        modal.style.display = 'none';
    });
}

/**
 * Debounce function for performance
 */
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

/**
 * Show error message to user
 */
function showError(message) {
    console.error('❌ Error:', message);
    alert(message);
}

/**
 * Check if application is initialized
 */
function isApplicationInitialized() {
    return systemInitialized;
}

/**
 * Get initialization status
 */
function getInitializationStatus() {
    return {
        systemInitialized,
        isDOMReady,
        isConfigLoaded,
        initializationAttempts,
        maxAttempts: MAX_INIT_ATTEMPTS
    };
}

// DOM ready handler
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        console.log('📄 DOM Content Loaded');
        isDOMReady = true;
        attemptInitialization();
    });
} else {
    console.log('📄 DOM already ready');
    isDOMReady = true;
    attemptInitialization();
}

// Configuration loading handler
window.ClientConfig.loadConfiguration()
    .then(() => {
        console.log('🔧 Configuration loaded successfully');
        isConfigLoaded = true;
        attemptInitialization();
    })
    .catch(error => {
        console.error('❌ Failed to load configuration:', error);
        showError('Failed to load configuration. Please refresh the page.');
    });

// Export initialization functions
window.AppInitializer = {
    initializeApplication,
    initializeListingsPage,
    isApplicationInitialized,
    getInitializationStatus,
    attemptInitialization,
    closeAllModalsAndMenus,
    showError
};

// Initialize Universal Authentication Manager if available
if (typeof window.UniversalAuth !== 'undefined') {
    window.UniversalAuth.init({ 
        allowAnonymous: true, 
        requireSupabase: true 
    });
}