/**
 * Authentication Management Module
 * Handles user authentication, session management, and emergency protection
 */

// Authentication state
let currentUser = null;
let authStateInitialized = false;
let backupInterval = null;

// Emergency protection settings
const EMERGENCY_PROTECTION_ENABLED = true;
const BACKUP_INTERVAL = 5000; // 5 seconds

/**
 * Initialize authentication system
 */
async function initializeAuth() {
    console.log('🔐 Initializing authentication system...');
    
    try {
        // Get Supabase client
        const supabase = window.ClientConfig.getSupabaseClient();
        
        // Get current session
        const { data: { session }, error } = await supabase.auth.getSession();
        
        if (error) {
            console.error('❌ Auth session error:', error);
            return false;
        }
        
        if (session) {
            currentUser = session.user;
            console.log('✅ User authenticated:', currentUser.email);
            await handleAuthenticatedUser(currentUser);
        } else {
            console.log('ℹ️ No active session found');
        }
        
        // Set up auth state listener
        supabase.auth.onAuthStateChange(async (event, session) => {
            console.log('🔄 Auth state changed:', event);
            
            if (event === 'SIGNED_IN' && session) {
                currentUser = session.user;
                await handleAuthenticatedUser(currentUser);
            } else if (event === 'SIGNED_OUT') {
                currentUser = null;
                handleSignOut();
            }
        });
        
        // Start emergency protection if enabled
        if (EMERGENCY_PROTECTION_ENABLED) {
            startEmergencyProtection();
        }
        
        authStateInitialized = true;
        return true;
        
    } catch (error) {
        console.error('❌ Auth initialization failed:', error);
        return false;
    }
}

/**
 * Handle authenticated user
 */
async function handleAuthenticatedUser(user) {
    console.log('👤 Handling authenticated user:', user.email);
    
    try {
        // Update UI elements
        updateAuthUI(user);
        
        // Create or update user profile
        await createOrUpdateUserProfile(user);
        
        // Start backup system
        startUserBackup();
        
    } catch (error) {
        console.error('❌ Error handling authenticated user:', error);
    }
}

/**
 * Handle sign out
 */
function handleSignOut() {
    console.log('👋 User signed out');
    
    // Clear current user
    currentUser = null;
    
    // Update UI
    updateAuthUI(null);
    
    // Stop backup system
    stopUserBackup();
    
    // Clear any cached data
    clearUserData();
}

/**
 * Update authentication UI elements
 */
function updateAuthUI(user) {
    const profileSection = document.getElementById('profile-section');
    const authSection = document.getElementById('auth-section');
    
    if (user) {
        // Show profile section
        if (profileSection) {
            profileSection.style.display = 'block';
            
            // Update profile image
            const profileImg = document.getElementById('profile-img');
            if (profileImg) {
                profileImg.src = getProfileImageUrl(user.email);
                profileImg.alt = user.email;
            }
            
            // Update profile name
            const profileName = document.getElementById('profile-name');
            if (profileName) {
                profileName.textContent = user.email;
            }
        }
        
        // Hide auth section
        if (authSection) {
            authSection.style.display = 'none';
        }
    } else {
        // Hide profile section
        if (profileSection) {
            profileSection.style.display = 'none';
        }
        
        // Show auth section
        if (authSection) {
            authSection.style.display = 'block';
        }
    }
}

/**
 * Create or update user profile in database
 */
async function createOrUpdateUserProfile(user) {
    try {
        const supabase = window.ClientConfig.getSupabaseClient();
        
        const profileData = {
            id: user.id,
            email: user.email,
            profile_image: getProfileImageUrl(user.email),
            last_sign_in: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };
        
        const { error } = await supabase
            .from('user_profiles')
            .upsert(profileData, { onConflict: 'id' });
        
        if (error) {
            console.error('❌ Profile upsert error:', error);
        } else {
            console.log('✅ User profile updated successfully');
        }
        
    } catch (error) {
        console.error('❌ Error creating/updating user profile:', error);
    }
}

/**
 * Get profile image URL based on email
 */
function getProfileImageUrl(email) {
    const hash = btoa(email).replace(/[^a-zA-Z0-9]/g, '').substring(0, 10);
    return `https://api.dicebear.com/6.x/initials/svg?seed=${hash}&backgroundColor=667eea,764ba2,f093fb,4f46e5,06b6d4&textColor=ffffff`;
}

/**
 * Start emergency protection system
 */
function startEmergencyProtection() {
    console.log('🛡️ Starting emergency protection system...');
    
    // Block unwanted redirects
    const originalLocation = window.location.href;
    
    // Override location changes
    let locationChangeBlocked = false;
    
    const originalPushState = history.pushState;
    const originalReplaceState = history.replaceState;
    
    history.pushState = function(...args) {
        if (locationChangeBlocked) {
            console.log('🛡️ Emergency protection: Blocked pushState');
            return;
        }
        return originalPushState.apply(this, args);
    };
    
    history.replaceState = function(...args) {
        if (locationChangeBlocked) {
            console.log('🛡️ Emergency protection: Blocked replaceState');
            return;
        }
        return originalReplaceState.apply(this, args);
    };
    
    // Block form submissions to auth endpoints
    document.addEventListener('submit', function(e) {
        const form = e.target;
        if (form.action && (form.action.includes('login') || form.action.includes('auth'))) {
            console.log('🛡️ Emergency protection: Blocked auth form submission');
            e.preventDefault();
            return false;
        }
    });
    
    // Monitor for unauthorized redirects
    window.addEventListener('beforeunload', function(e) {
        if (locationChangeBlocked) {
            e.preventDefault();
            e.returnValue = '🛡️ Emergency protection: Navigation blocked';
            return '🛡️ Emergency protection: Navigation blocked';
        }
    });
    
    console.log('🛡️ Emergency protection system activated');
}

/**
 * Start user backup system
 */
function startUserBackup() {
    if (backupInterval) {
        clearInterval(backupInterval);
    }
    
    backupInterval = setInterval(async () => {
        try {
            await backupUserData();
        } catch (error) {
            console.error('❌ User backup failed:', error);
        }
    }, BACKUP_INTERVAL);
    
    console.log('💾 User backup system started');
}

/**
 * Stop user backup system
 */
function stopUserBackup() {
    if (backupInterval) {
        clearInterval(backupInterval);
        backupInterval = null;
        console.log('💾 User backup system stopped');
    }
}

/**
 * Backup user data to localStorage
 */
async function backupUserData() {
    if (!currentUser) return;
    
    try {
        const backupData = {
            user: currentUser,
            timestamp: new Date().toISOString(),
            session: await getCurrentSession()
        };
        
        // localStorage removed - using Supabase);
        
    } catch (error) {
        console.error('❌ User backup error:', error);
    }
}

/**
 * Restore user data from localStorage
 */
async function restoreUserData() {
    try {
        const backupData = null;
        if (!backupData) return null;
        
        const parsed = JSON.parse(backupData);
        const backupAge = new Date() - new Date(parsed.timestamp);
        
        // Only restore if backup is less than 1 hour old
        if (backupAge < 3600000) {
            console.log('🔄 Restoring user data from backup');
            return parsed;
        } else {
            console.log('⏰ Backup data too old, ignoring');
            // localStorage removed
            return null;
        }
        
    } catch (error) {
        console.error('❌ User restore error:', error);
        return null;
    }
}

/**
 * Get current session
 */
async function getCurrentSession() {
    try {
        const supabase = window.ClientConfig.getSupabaseClient();
        const { data: { session } } = await supabase.auth.getSession();
        return session;
    } catch (error) {
        console.error('❌ Get session error:', error);
        return null;
    }
}

/**
 * Clear user data
 */
function clearUserData() {
    // localStorage removed
    console.log('🗑️ User data cleared');
}

/**
 * Get current user
 */
function getCurrentUser() {
    return currentUser;
}

/**
 * Check if user is authenticated
 */
function isAuthenticated() {
    return !!currentUser;
}

/**
 * Sign out user
 */
async function signOut() {
    try {
        const supabase = window.ClientConfig.getSupabaseClient();
        const { error } = await supabase.auth.signOut();
        
        if (error) {
            console.error('❌ Sign out error:', error);
            return false;
        }
        
        console.log('✅ User signed out successfully');
        return true;
        
    } catch (error) {
        console.error('❌ Sign out failed:', error);
        return false;
    }
}

// Export functions for use in other modules
window.AuthManager = {
    initializeAuth,
    handleAuthenticatedUser,
    handleSignOut,
    updateAuthUI,
    createOrUpdateUserProfile,
    getProfileImageUrl,
    startEmergencyProtection,
    startUserBackup,
    stopUserBackup,
    backupUserData,
    restoreUserData,
    getCurrentSession,
    clearUserData,
    getCurrentUser,
    isAuthenticated,
    signOut
};

// Export for backward compatibility
window.currentUser = () => currentUser;
window.authStateInitialized = () => authStateInitialized;