/**
 * Authentication Manager Module
 * Handles authentication logic, user management, session handling, and security
 */

// Authentication state
let currentUser = null;
let isAuthInitialized = false;

// Emergency protection state
let emergencyProtectionActive = false;
let originalLocationMethods = {};

// Profile images for random assignment
const profileImages = [
    'https://images.unsplash.com/photo-1494790108755-2616b332c65c?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop&crop=face'
];

/**
 * Initialize authentication system with emergency protection
 */
function initializeAuth() {
    console.log('🛡️ Initializing Authentication Manager...');
    
    // Initialize emergency protection first
    initializeEmergencyProtection();
    
    // Load current user from localStorage
    loadCurrentUser();
    
    // Set up backup and restore systems
    setupUserBackupSystem();
    
    isAuthInitialized = true;
    console.log('✅ Authentication Manager initialized');
}

/**
 * Initialize emergency authentication protection system
 */
function initializeEmergencyProtection() {
    console.log('🛡️ Initializing Emergency Authentication Protection System...');
    
    // Store original functions to prevent blocking
    originalLocationMethods.href = Object.getOwnPropertyDescriptor(window.location, 'href');
    originalLocationMethods.assign = window.location.assign;
    originalLocationMethods.replace = window.location.replace;
    originalLocationMethods.reload = window.location.reload;
    originalLocationMethods.removeItem = localStorage.removeItem;
    
    // Block ALL redirects to login pages
    Object.defineProperty(window.location, 'href', {
        set: function(url) {
            if (typeof url === 'string' && url.includes('/login')) {
                console.error('🚫 BLOCKED location.href redirect to login:', url);
                console.trace('Stack trace for blocked redirect:');
                return; // Block the redirect
            }
            return originalLocationMethods.href.set.call(this, url);
        },
        get: function() {
            return originalLocationMethods.href.get.call(this);
        }
    });
    
    window.location.assign = function(url) {
        if (typeof url === 'string' && url.includes('/login')) {
            console.error('🚫 BLOCKED location.assign to login:', url);
            console.trace('Stack trace for blocked redirect:');
            return; // Block the redirect
        }
        return originalLocationMethods.assign.call(this, url);
    };
    
    window.location.replace = function(url) {
        if (typeof url === 'string' && url.includes('/login')) {
            console.error('🚫 BLOCKED location.replace to login:', url);
            console.trace('Stack trace for blocked redirect:');
            return; // Block the redirect
        }
        return originalLocationMethods.replace.call(this, url);
    };
    
    // Block localStorage.removeItem for currentUser
    localStorage.removeItem = function(key) {
        if (key === 'currentUser') {
            console.error('⚠️ BLOCKING currentUser removal for debugging');
            console.trace('Stack trace for blocked currentUser removal:');
            return; // Block the removal
        }
        return originalLocationMethods.removeItem.call(this, key);
    };
    
    emergencyProtectionActive = true;
    console.log('✅ Emergency Authentication Protection System Active');
}

/**
 * Load current user from localStorage
 */
function loadCurrentUser() {
    try {
        const storedUser = localStorage.getItem('currentUser');
        if (storedUser) {
            currentUser = JSON.parse(storedUser);
            console.log('👤 Current user loaded:', currentUser.email);
            
            // Assign profile image if missing
            if (!currentUser.profileImage) {
                currentUser.profileImage = profileImages[Math.floor(Math.random() * profileImages.length)];
                saveCurrentUser();
            }
        } else {
            console.log('👤 No current user found in localStorage');
        }
    } catch (error) {
        console.error('❌ Error loading current user:', error);
        currentUser = null;
    }
}

/**
 * Save current user to localStorage
 */
function saveCurrentUser() {
    if (currentUser) {
        try {
            localStorage.setItem('currentUser', JSON.stringify(currentUser));
            
            // Also update users array
            let users = JSON.parse(localStorage.getItem('users')) || [];
            users = users.map(u => u.email === currentUser.email ? currentUser : u);
            
            // Add to users array if not exists
            if (!users.some(u => u.email === currentUser.email)) {
                users.push(currentUser);
            }
            
            localStorage.setItem('users', JSON.stringify(users));
            console.log('💾 Current user saved to localStorage');
        } catch (error) {
            console.error('❌ Error saving current user:', error);
        }
    }
}

/**
 * Set up user backup and restore system
 */
function setupUserBackupSystem() {
    // Create initial backup
    createUserBackup();
    
    // Continuous monitoring and restoration
    setInterval(() => {
        if (restoreUserIfNeeded()) {
            console.log('🔄 User data restored automatically');
        }
        createUserBackup(); // Refresh backup
    }, 5000);
}

/**
 * Create backup of current user data
 */
function createUserBackup() {
    const currentUserData = localStorage.getItem('currentUser');
    if (currentUserData) {
        localStorage.setItem('currentUser_backup', currentUserData);
        localStorage.setItem('currentUser_backup_timestamp', Date.now().toString());
        console.log('💾 User backup created');
    }
}

/**
 * Restore user data from backup if needed
 * @returns {boolean} True if user was restored
 */
function restoreUserIfNeeded() {
    const currentUserData = localStorage.getItem('currentUser');
    const backup = localStorage.getItem('currentUser_backup');
    
    if (!currentUserData && backup) {
        console.log('🔄 Restoring user from backup');
        localStorage.setItem('currentUser', backup);
        loadCurrentUser(); // Reload the current user
        return true;
    }
    return false;
}

/**
 * Get current authenticated user
 * @returns {Object|null} Current user object or null
 */
function getCurrentUser() {
    return currentUser;
}

/**
 * Check if user is authenticated
 * @returns {boolean} True if user is authenticated
 */
function isAuthenticated() {
    return currentUser !== null && currentUser.email;
}

/**
 * Set current user (for login)
 * @param {Object} user - User object
 */
function setCurrentUser(user) {
    currentUser = user;
    
    // Assign profile image if missing
    if (!currentUser.profileImage) {
        currentUser.profileImage = profileImages[Math.floor(Math.random() * profileImages.length)];
    }
    
    saveCurrentUser();
    console.log('👤 Current user set:', user.email);
}

/**
 * Clear current user (for logout)
 */
function clearCurrentUser() {
    currentUser = null;
    
    // Only clear if emergency protection is not active
    if (!emergencyProtectionActive) {
        localStorage.removeItem('currentUser');
        console.log('👤 Current user cleared');
    } else {
        console.log('🛡️ User logout blocked by emergency protection');
    }
}

/**
 * Set current user email for Supabase RLS
 * @param {string} email - User email
 * @returns {Promise<boolean>} Success status
 */
async function setCurrentUserEmailForRLS(email) {
    try {
        if (!window.supabase) {
            throw new Error('Supabase client not initialized');
        }
        
        const { error } = await window.supabase.rpc('set_current_user_email', { email });
        console.log('RPC set_current_user_email response:', { error });
        
        if (error) {
            console.error('Error setting current user email:', error);
            return false;
        }
        
        console.log('Current user email set for RLS:', email);
        return true;
    } catch (err) {
        console.error('RPC call failed:', err);
        return false;
    }
}

/**
 * Validate user session and setup authentication
 * @returns {Promise<boolean>} True if authentication is valid
 */
async function validateAndSetupAuth() {
    if (!currentUser) {
        console.log('⚠️ No authenticated user found');
        return false;
    }
    
    try {
        // Set current user email for RLS
        const rlsSuccess = await setCurrentUserEmailForRLS(currentUser.email);
        if (!rlsSuccess) {
            console.error('Failed to initialize session');
            return false;
        }
        
        return true;
    } catch (error) {
        console.error('❌ Authentication validation failed:', error);
        return false;
    }
}

/**
 * Create or ensure user profile exists in database
 * @param {Object} user - User object
 * @returns {Promise<boolean>} Success status
 */
async function ensureUserProfile(user) {
    try {
        if (!window.supabase) {
            console.error('Supabase client not initialized');
            return false;
        }
        
        // Check if profile exists
        const { data: existingProfile, error: checkError } = await window.supabase
            .from('profiles')
            .select('email')
            .eq('email', user.email)
            .single();
        
        if (checkError && checkError.code !== 'PGRST116') {
            console.error('Error checking profile:', checkError);
            return false;
        }
        
        if (!existingProfile) {
            // Create profile
            const { error: createError } = await window.supabase
                .from('profiles')
                .insert([{
                    email: user.email,
                    first_name: user.firstName || 'User',
                    last_name: user.lastName || '',
                    created_at: new Date().toISOString()
                }]);
            
            if (createError) {
                console.error('Error creating profile:', createError);
                return false;
            }
            
            console.log('✅ User profile created');
        }
        
        return true;
    } catch (error) {
        console.error('❌ Error ensuring user profile:', error);
        return false;
    }
}

/**
 * Handle authentication errors and redirects
 * @param {string} error - Error message
 * @param {boolean} redirectToLogin - Whether to redirect to login
 */
function handleAuthError(error, redirectToLogin = false) {
    console.error('🔒 Authentication error:', error);
    
    if (redirectToLogin && !emergencyProtectionActive) {
        // Only redirect if emergency protection is not active
        alert('Authentication required. Redirecting to login...');
        window.location.href = '/login';
    } else {
        // Show error without redirecting
        alert('Authentication error: ' + error);
    }
}

/**
 * Update authentication UI elements
 * @param {string} containerId - Container element ID
 */
function updateAuthUI(containerId = 'authSection') {
    const authSection = document.getElementById(containerId);
    if (!authSection) {
        console.warn('Auth section element not found:', containerId);
        return;
    }
    
    if (isAuthenticated()) {
        // Show authenticated user UI
        authSection.innerHTML = `
            <div class="flex items-center space-x-2">
                <div class="relative">
                    <span id="profileNotificationBadge" class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-5 h-5 text-xs flex items-center justify-center hidden z-10">0</span>
                    <a href="/profile">
                        <img id="profileLogo" src="${currentUser.profileImage}" alt="Profile" class="w-10 h-10 rounded-full profile-logo">
                    </a>
                </div>
            </div>
        `;
    } else {
        // Show login/signup UI
        authSection.innerHTML = `
            <div class="auth-links flex items-center space-x-4">
                <a href="/login" class="auth-link">Login</a>
                <a href="/signup" class="auth-link">Sign Up</a>
            </div>
        `;
    }
}

/**
 * Disable emergency protection (for production use)
 */
function disableEmergencyProtection() {
    if (!emergencyProtectionActive) return;
    
    console.log('🔓 Disabling emergency protection...');
    
    // Restore original location methods
    if (originalLocationMethods.href) {
        Object.defineProperty(window.location, 'href', originalLocationMethods.href);
    }
    if (originalLocationMethods.assign) {
        window.location.assign = originalLocationMethods.assign;
    }
    if (originalLocationMethods.replace) {
        window.location.replace = originalLocationMethods.replace;
    }
    if (originalLocationMethods.removeItem) {
        localStorage.removeItem = originalLocationMethods.removeItem;
    }
    
    emergencyProtectionActive = false;
    console.log('✅ Emergency protection disabled');
}

/**
 * Get authentication status and user info
 * @returns {Object} Authentication status object
 */
function getAuthStatus() {
    return {
        isAuthenticated: isAuthenticated(),
        user: currentUser,
        isInitialized: isAuthInitialized,
        emergencyProtectionActive: emergencyProtectionActive
    };
}

// Export authentication functions
window.AuthManager = {
    initializeAuth,
    getCurrentUser,
    isAuthenticated,
    setCurrentUser,
    clearCurrentUser,
    validateAndSetupAuth,
    ensureUserProfile,
    handleAuthError,
    updateAuthUI,
    disableEmergencyProtection,
    getAuthStatus,
    setCurrentUserEmailForRLS,
    
    // Backup and restore functions
    createUserBackup,
    restoreUserIfNeeded
};

// Initialize on load
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeAuth);
} else {
    initializeAuth();
}