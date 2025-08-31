/**
 * Application Initialization Module
 * Handles application startup, component setup, and DOM management
 */

// Initialization state
let isDOMReady = false;
let initializationAttempts = 0;
const MAX_INIT_ATTEMPTS = 3;

/**
 * Main initialization function
 */
async function initializeApplication() {
    console.log('🚀 Starting application initialization...');
    
    try {
        // Wait for prerequisites
        await waitForPrerequisites();
        
        // Initialize core components
        await initializeCoreComponents();
        
        // Initialize UI components
        await initializeUIComponents();
        
        // Initialize event listeners
        setupEventListeners();
        
        // Initialize real-time features
        await initializeRealTimeFeatures();
        
        console.log('✅ Application initialization completed successfully');
        return true;
        
    } catch (error) {
        console.error('❌ Application initialization failed:', error);
        handleInitializationError(error);
        return false;
    }
}

/**
 * Wait for prerequisites (DOM ready + config loaded)
 */
async function waitForPrerequisites() {
    console.log('⏳ Waiting for prerequisites...');
    
    // Wait for DOM
    await waitForDOM();
    
    // Wait for configuration
    await waitForConfiguration();
    
    console.log('✅ Prerequisites satisfied');
}

/**
 * Wait for DOM to be ready
 */
function waitForDOM() {
    return new Promise((resolve) => {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => {
                console.log('📄 DOM Content Loaded');
                isDOMReady = true;
                resolve();
            });
        } else {
            console.log('📄 DOM already ready');
            isDOMReady = true;
            resolve();
        }
    });
}

/**
 * Wait for configuration to be loaded
 */
async function waitForConfiguration() {
    const maxWait = 30000; // 30 seconds
    const checkInterval = 100; // 100ms
    let waited = 0;
    
    while (!window.ClientConfig.isConfigurationLoaded() && waited < maxWait) {
        await new Promise(resolve => setTimeout(resolve, checkInterval));
        waited += checkInterval;
    }
    
    if (!window.ClientConfig.isConfigurationLoaded()) {
        throw new Error('Configuration loading timeout');
    }
}

/**
 * Initialize core components
 */
async function initializeCoreComponents() {
    console.log('🔧 Initializing core components...');
    
    // Initialize authentication
    await window.AuthManager.initializeAuth();
    
    // Initialize spell checker
    if (window.ClientConfig.initializeTypo) {
        window.ClientConfig.initializeTypo();
    }
    
    console.log('✅ Core components initialized');
}

/**
 * Initialize UI components
 */
async function initializeUIComponents() {
    console.log('🎨 Initializing UI components...');
    
    // Initialize map
    if (typeof initMap === 'function') {
        await initMap();
    }
    
    // Initialize chat system
    if (typeof setupChat === 'function') {
        await setupChat();
    }
    
    // Initialize messaging panel
    if (typeof initializeMessagingPanel === 'function') {
        await initializeMessagingPanel();
    }
    
    // Initialize search and filters
    if (typeof initializeSearch === 'function') {
        await initializeSearch();
    }
    
    // Initialize forms
    if (typeof initializeForms === 'function') {
        await initializeForms();
    }
    
    console.log('✅ UI components initialized');
}

/**
 * Setup event listeners
 */
function setupEventListeners() {
    console.log('🔗 Setting up event listeners...');
    
    // Setup mobile menu
    setupMobileMenu();
    
    // Setup keyboard shortcuts
    setupKeyboardShortcuts();
    
    // Setup form handlers
    setupFormHandlers();
    
    // Setup modal handlers
    setupModalHandlers();
    
    // Setup dropdown handlers
    setupDropdownHandlers();
    
    console.log('✅ Event listeners set up');
}

/**
 * Setup mobile menu functionality
 */
function setupMobileMenu() {
    const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
    const mobileMenu = document.querySelector('.mobile-menu');
    const mobileMenuClose = document.querySelector('.mobile-menu-close');
    const mobileMenuOverlay = document.querySelector('.mobile-menu-overlay');
    
    if (mobileMenuBtn && mobileMenu) {
        mobileMenuBtn.addEventListener('click', () => {
            toggleMobileMenu();
        });
        
        if (mobileMenuClose) {
            mobileMenuClose.addEventListener('click', () => {
                closeMobileMenu();
            });
        }
        
        if (mobileMenuOverlay) {
            mobileMenuOverlay.addEventListener('click', () => {
                closeMobileMenu();
            });
        }
        
        // Setup mobile section toggles
        const mobileSections = document.querySelectorAll('.mobile-section-header');
        mobileSections.forEach(section => {
            section.addEventListener('click', () => {
                toggleMobileSection(section);
            });
        });
    }
}

/**
 * Toggle mobile menu
 */
function toggleMobileMenu() {
    const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
    const mobileMenu = document.querySelector('.mobile-menu');
    
    if (mobileMenuBtn && mobileMenu) {
        mobileMenuBtn.classList.toggle('active');
        mobileMenu.classList.toggle('active');
        document.body.classList.toggle('mobile-menu-open');
    }
}

/**
 * Close mobile menu
 */
function closeMobileMenu() {
    const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
    const mobileMenu = document.querySelector('.mobile-menu');
    
    if (mobileMenuBtn && mobileMenu) {
        mobileMenuBtn.classList.remove('active');
        mobileMenu.classList.remove('active');
        document.body.classList.remove('mobile-menu-open');
    }
}

/**
 * Toggle mobile section
 */
function toggleMobileSection(header) {
    const arrow = header.querySelector('.mobile-arrow');
    const content = header.nextElementSibling;
    
    if (arrow && content) {
        arrow.classList.toggle('rotated');
        content.classList.toggle('expanded');
    }
}

/**
 * Setup keyboard shortcuts
 */
function setupKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
        // ESC key - close modals
        if (e.key === 'Escape') {
            closeAllModals();
        }
        
        // Ctrl/Cmd + K - focus search
        if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
            e.preventDefault();
            focusSearch();
        }
        
        // Ctrl/Cmd + M - toggle mobile menu
        if ((e.ctrlKey || e.metaKey) && e.key === 'm') {
            e.preventDefault();
            toggleMobileMenu();
        }
    });
}

/**
 * Setup form handlers
 */
function setupFormHandlers() {
    // Add listing form
    const addListingForm = document.getElementById('add-listing-form');
    if (addListingForm) {
        addListingForm.addEventListener('submit', handleAddListingSubmit);
    }
    
    // Search form
    const searchForm = document.getElementById('search-form');
    if (searchForm) {
        searchForm.addEventListener('submit', handleSearchSubmit);
    }
    
    // Contact forms
    const contactForms = document.querySelectorAll('.contact-form');
    contactForms.forEach(form => {
        form.addEventListener('submit', handleContactSubmit);
    });
}

/**
 * Setup modal handlers
 */
function setupModalHandlers() {
    // Close buttons
    const closeButtons = document.querySelectorAll('.close-button');
    closeButtons.forEach(btn => {
        btn.addEventListener('click', (e) => {
            const modal = e.target.closest('.modal');
            if (modal) {
                closeModal(modal);
            }
        });
    });
    
    // Click outside to close
    document.addEventListener('click', (e) => {
        if (e.target.classList.contains('modal')) {
            closeModal(e.target);
        }
    });
}

/**
 * Setup dropdown handlers
 */
function setupDropdownHandlers() {
    // Close dropdowns when clicking outside
    document.addEventListener('click', (e) => {
        if (!e.target.closest('.dropdown')) {
            closeAllDropdowns();
        }
    });
}

/**
 * Initialize real-time features
 */
async function initializeRealTimeFeatures() {
    console.log('⚡ Initializing real-time features...');
    
    try {
        // Initialize real-time subscriptions
        if (typeof setupRealTimeSubscriptions === 'function') {
            await setupRealTimeSubscriptions();
        }
        
        // Initialize push notifications
        if (typeof setupPushNotifications === 'function') {
            await setupPushNotifications();
        }
        
        console.log('✅ Real-time features initialized');
        
    } catch (error) {
        console.error('❌ Real-time features initialization failed:', error);
    }
}

/**
 * Handle initialization error
 */
function handleInitializationError(error) {
    console.error('💥 Application initialization failed:', error);
    
    initializationAttempts++;
    
    if (initializationAttempts < MAX_INIT_ATTEMPTS) {
        console.log(`🔄 Retrying initialization in 2 seconds... (${MAX_INIT_ATTEMPTS - initializationAttempts} attempts remaining)`);
        
        setTimeout(() => {
            initializeApplication();
        }, 2000);
    } else {
        console.error('💥 All initialization attempts failed');
        
        // Show error to user
        window.ClientConfig.showError(
            'Application initialization failed. Some features may not work properly. Please refresh the page.'
        );
        
        // Try to initialize basic functionality
        initializeBasicFunctionality();
    }
}

/**
 * Initialize basic functionality as fallback
 */
function initializeBasicFunctionality() {
    console.log('🔧 Initializing basic functionality...');
    
    try {
        // Setup basic event listeners
        setupMobileMenu();
        setupKeyboardShortcuts();
        setupModalHandlers();
        
        console.log('✅ Basic functionality initialized');
        
    } catch (error) {
        console.error('❌ Basic functionality initialization failed:', error);
    }
}

/**
 * Utility functions
 */
function closeAllModals() {
    const modals = document.querySelectorAll('.modal.active');
    modals.forEach(modal => {
        closeModal(modal);
    });
}

function closeModal(modal) {
    if (modal) {
        modal.classList.remove('active');
    }
}

function closeAllDropdowns() {
    const dropdowns = document.querySelectorAll('.dropdown-menu');
    dropdowns.forEach(dropdown => {
        dropdown.style.opacity = '0';
        dropdown.style.visibility = 'hidden';
        dropdown.style.transform = 'translateY(-10px)';
    });
}

function focusSearch() {
    const searchInput = document.getElementById('search-input') || document.querySelector('input[type="search"]');
    if (searchInput) {
        searchInput.focus();
    }
}

/**
 * Event handlers
 */
function handleAddListingSubmit(e) {
    e.preventDefault();
    if (typeof addListing === 'function') {
        addListing();
    }
}

function handleSearchSubmit(e) {
    e.preventDefault();
    if (typeof performSearch === 'function') {
        performSearch();
    }
}

function handleContactSubmit(e) {
    e.preventDefault();
    if (typeof handleContactForm === 'function') {
        handleContactForm(e.target);
    }
}

/**
 * Attempt initialization function with retry mechanism
 */
function attemptInitialization() {
    console.log('🚀 Attempting initialization...', {
        configLoaded: window.ClientConfig.isConfigurationLoaded(),
        domReady: isDOMReady,
        attempt: initializationAttempts + 1
    });

    if (!window.ClientConfig.isConfigurationLoaded() || !isDOMReady) {
        console.log('⏳ Waiting for prerequisites...');
        return;
    }

    initializationAttempts++;
    
    try {
        console.log(`🔄 Starting initialization attempt ${initializationAttempts}/${MAX_INIT_ATTEMPTS}`);
        initializeApplication();
        console.log('✅ Initialization completed successfully');
    } catch (error) {
        console.error(`❌ Initialization attempt ${initializationAttempts} failed:`, error);
        
        if (initializationAttempts < MAX_INIT_ATTEMPTS) {
            console.log(`🔄 Retrying in 1 second... (${MAX_INIT_ATTEMPTS - initializationAttempts} attempts remaining)`);
            setTimeout(() => {
                attemptInitialization();
            }, 1000);
        } else {
            console.error('💥 All initialization attempts failed. System may not work properly.');
            window.ClientConfig.showError('Application initialization failed. Some features may not work. Please refresh the page.');
        }
    }
}

// Export functions for use in other modules
window.AppInitializer = {
    initializeApplication,
    attemptInitialization,
    waitForPrerequisites,
    waitForDOM,
    waitForConfiguration,
    initializeCoreComponents,
    initializeUIComponents,
    setupEventListeners,
    setupMobileMenu,
    toggleMobileMenu,
    closeMobileMenu,
    toggleMobileSection,
    setupKeyboardShortcuts,
    setupFormHandlers,
    setupModalHandlers,
    setupDropdownHandlers,
    initializeRealTimeFeatures,
    handleInitializationError,
    initializeBasicFunctionality,
    closeAllModals,
    closeModal,
    closeAllDropdowns,
    focusSearch
};

// Export for backward compatibility
window.initializeListingsPage = () => initializeApplication();
window.attemptInitialization = attemptInitialization;
window.isDOMReady = () => isDOMReady;
window.initializationAttempts = () => initializationAttempts;
window.MAX_INIT_ATTEMPTS = MAX_INIT_ATTEMPTS;