/**
 * 🔄 UNIVERSAL AUTHENTICATION MANAGER
 * 
 * Provides consistent authentication state management across all pages.
 * Works with universal-auth-protection.js to maintain user sessions.
 * 
 * Usage: Include after universal-auth-protection.js and call initUniversalAuth()
 */

console.log('🔄 UNIVERSAL AUTHENTICATION MANAGER INITIALIZING...');

// Default profile image SVG
const DEFAULT_PROFILE_IMAGE = 'data:image/svg+xml;base64,' + btoa(`
    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
        <rect width="100" height="100" rx="50" fill="#E5E7EB"/>
        <path d="M50 45C56.075 45 61 40.075 61 34C61 27.925 56.075 23 50 23C43.925 23 39 27.925 39 34C39 40.075 43.925 45 50 45Z" fill="#9CA3AF"/>
        <path d="M30 77C30 77 30 66.103 30 62C30 55.373 36.268 50 44 50H56C63.732 50 70 55.373 70 62C70 66.103 70 77 70 77" fill="#9CA3AF"/>
    </svg>
`.trim());

/**
 * Check if user is authenticated
 */
function isUserAuthenticated() {
    const currentUser = localStorage.getItem('currentUser');
    return currentUser && currentUser !== 'null' && currentUser !== 'undefined';
}

/**
 * Get current user data
 */
function getCurrentUser() {
    try {
        const currentUser = localStorage.getItem('currentUser');
        return currentUser ? JSON.parse(currentUser) : null;
    } catch (error) {
        console.error('Error parsing current user:', error);
        return null;
    }
}

/**
 * Get stored profile image with fallback
 */
function getStoredProfileImage(email) {
    try {
        // Check multiple storage locations for profile image
        const profileImageKey = `profileImage_${email}`;
        const storedImage = localStorage.getItem(profileImageKey);
        
        if (storedImage && storedImage !== 'null' && storedImage !== 'undefined') {
            return storedImage;
        }
        
        // Check backup storage
        const backupKey = `profileImageBackup_${email}`;
        const backupImage = localStorage.getItem(backupKey);
        
        if (backupImage && backupImage !== 'null' && backupImage !== 'undefined') {
            return backupImage;
        }
        
        return null;
    } catch (error) {
        console.error('Error retrieving stored profile image:', error);
        return null;
    }
}

/**
 * Store profile image in multiple locations for persistence
 */
function storeProfileImage(email, imageData) {
    try {
        const profileImageKey = `profileImage_${email}`;
        const backupKey = `profileImageBackup_${email}`;
        
        // Store in primary location
        localStorage.setItem(profileImageKey, imageData);
        
        // Store backup
        localStorage.setItem(backupKey, imageData);
        
        console.log('✅ Profile image stored successfully');
    } catch (error) {
        console.error('Error storing profile image:', error);
    }
}

/**
 * Update auth section with appropriate content
 */
async function updateAuthSection() {
    const authSection = document.getElementById('authSection');
    if (!authSection) {
        console.log('No authSection found on this page');
        return;
    }

    // Check if we're on the login page and hide auth section
    const currentPath = window.location.pathname;
    const isLoginPage = currentPath.endsWith('/login.html') || currentPath.endsWith('login.html') || currentPath === '/login';
    
    if (isLoginPage) {
        authSection.style.display = 'none';
        console.log('✅ Auth section hidden on login page');
        return;
    }

    const currentUser = getCurrentUser();
    
    if (isUserAuthenticated() && currentUser) {
        // Try to fetch the latest profile image from backend first
        let profileImage = null;
        
        try {
            const response = await fetch(`/api/user-profile/${encodeURIComponent(currentUser.email)}`);
            if (response.ok) {
                const profileData = await response.json();
                
                // Update profile image if exists
                if (profileData.profileImage) {
                    profileImage = profileData.profileImage;
                    currentUser.profileImage = profileData.profileImage;
                    currentUser.hasCustomProfileImage = profileData.hasCustomProfileImage;
                    console.log('✅ Updated profile image from backend in auth section');
                }
                
                // Update names from database (prioritize database over localStorage)
                if (profileData.firstName || profileData.lastName) {
                    currentUser.firstName = profileData.firstName || '';
                    currentUser.lastName = profileData.lastName || '';
                    console.log('✅ Updated names from backend in auth section:', profileData.firstName, profileData.lastName);
                }
                
                localStorage.setItem('currentUser', JSON.stringify(currentUser));
            }
        } catch (error) {
            console.error('Error fetching profile data in auth section:', error);
        }
        
        // Fallback to stored/local profile image if backend fetch failed
        if (!profileImage) {
            profileImage = getStoredProfileImage(currentUser.email);
        }
        
        // If still no image, check current user object
        if (!profileImage) {
            profileImage = currentUser.profileImage;
        }
        
        // If user has uploaded a custom profile image, ALWAYS use it
        if (currentUser.hasCustomProfileImage && currentUser.profileImage && currentUser.profileImage.startsWith('data:image/')) {
            profileImage = currentUser.profileImage;
        } else {
            // Force update to new default profile icon if user has old placeholder images
            const oldPlaceholderPatterns = [
                'https://via.placeholder.com/',
                'https://ui-avatars.com/api/',
                'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDA',
                'PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDA'
            ];
            
            const needsUpdate = !profileImage || 
                oldPlaceholderPatterns.some(pattern => profileImage.includes(pattern));
            
            if (needsUpdate && !currentUser.hasCustomProfileImage) {
                profileImage = DEFAULT_PROFILE_IMAGE;
            }
        }
        
        // Update currentUser with the correct image
        if (currentUser.profileImage !== profileImage) {
            currentUser.profileImage = profileImage;
            localStorage.setItem('currentUser', JSON.stringify(currentUser));
            
            // Also update users array
            try {
                let users = JSON.parse(localStorage.getItem('users')) || [];
                users = users.map(u => u && u.email === currentUser.email ? { ...u, profileImage: profileImage } : u);
                localStorage.setItem('users', JSON.stringify(users));
                console.log('✅ Profile image synchronized');
            } catch (e) {
                console.error('Error updating users array:', e);
            }
            
            // Store profile image separately for persistence
            if (profileImage !== DEFAULT_PROFILE_IMAGE && !needsUpdate) {
                storeProfileImage(currentUser.email, profileImage);
            }
        }
        
        // User is logged in - show profile
        authSection.innerHTML = `
            <a href="profile.html" class="profile-link">
                <img id="profileLogo" src="${profileImage}" alt="Profile" class="w-10 h-10 rounded-full profile-logo hover:ring-2 hover:ring-blue-500 transition-all duration-200" onerror="this.src='${DEFAULT_PROFILE_IMAGE}'">
            </a>
        `;
        
        console.log('✅ Auth section updated - showing profile image');
    } else {
        // User is not logged in - show login/register
        authSection.innerHTML = `
            <a href="login.html" class="auth-link bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors duration-200">
                Login/Register
            </a>
        `;
        
        console.log('✅ Auth section updated - showing login/register');
    }
}

/**
 * Initialize authentication for Supabase-enabled pages
 */
async function initSupabaseAuth() {
    // Check for both possible Supabase client locations
    const supabaseClient = window.supabaseClient || window.supabase;
    
    if (!supabaseClient || typeof supabaseClient.from !== 'function') {
        console.log('Supabase client not available or not properly initialized, skipping Supabase auth');
        return false;
    }

    const currentUser = getCurrentUser();
    if (!currentUser) {
        return false;
    }

    try {
        // Check if user exists in profiles table
        let { data: profile, error } = await supabaseClient
            .from('profiles')
            .select('*')
            .eq('email', currentUser.email)
            .single();

        if (error || !profile) {
            // Create profile if it doesn't exist
            const newProfile = {
                email: currentUser.email,
                profile_image: DEFAULT_PROFILE_IMAGE
            };
            const { data, error: insertError } = await supabaseClient
                .from('profiles')
                .insert([newProfile])
                .select()
                .single();

            if (insertError) {
                console.error('Error creating profile:', insertError);
                return false;
            }
            profile = data;
        }

        // Update current user with profile data
        currentUser.id = profile.id;
        currentUser.profileImage = profile.profile_image || DEFAULT_PROFILE_IMAGE;
        localStorage.setItem('currentUser', JSON.stringify(currentUser));

        console.log('✅ Supabase profile synchronized');
        return true;
    } catch (error) {
        // Only log error if it's not a connection issue
        if (error && error.message && !error.message.includes('Cannot read properties')) {
            console.error('Error initializing Supabase auth:', error);
        }
        return false;
    }
}

/**
 * Main initialization function - call this on every page
 */
async function initUniversalAuth(options = {}) {
    const { 
        allowAnonymous = false, 
        redirectToLogin = true,
        requireSupabase = false 
    } = options;

    console.log('🔄 Initializing universal auth...', { allowAnonymous, redirectToLogin, requireSupabase });

    // Check authentication state
    const isAuthenticated = isUserAuthenticated();
    
    if (!isAuthenticated) {
        if (allowAnonymous) {
            console.log('✅ Anonymous access allowed');
            await updateAuthSection();
            return { authenticated: false, allowed: true };
        } else if (redirectToLogin) {
            console.log('🔄 Redirecting to login...');
            window.location.href = '/login';
            return { authenticated: false, allowed: false };
        }
    }

    // Initialize Supabase if required and available
    if (requireSupabase || window.supabase || window.supabaseClient) {
        await initSupabaseAuth();
    }

    // Update the auth section
    await updateAuthSection();

    console.log('✅ Universal auth initialized successfully');
    return { authenticated: isAuthenticated, allowed: true };
}

/**
 * Handle logout (works with universal-auth-protection.js)
 */
function handleLogout() {
    console.log('🔄 Logout requested...');
    
    // The universal-auth-protection.js will block this, but try anyway
    // This provides a consistent logout interface
    try {
        localStorage.removeItem('currentUser');
        window.location.href = '/login';
    } catch (error) {
        console.log('Logout blocked by protection system');
    }
}

/**
 * Refresh auth state (useful for dynamic updates)
 */
async function refreshAuthState() {
    await updateAuthSection();
}

// Auto-refresh auth state when localStorage changes
window.addEventListener('storage', function(event) {
    if (event.key === 'currentUser') {
        console.log('🔄 User data changed, refreshing auth state...');
        refreshAuthState();
    }
});

// Auto-refresh auth state when page becomes visible
document.addEventListener('visibilitychange', function() {
    if (!document.hidden) {
        refreshAuthState();
    }
});

// Listen for storage changes to update profile image
window.addEventListener('storage', (e) => {
    if (e.key === 'currentUser') {
        console.log('Current user updated in storage, refreshing auth section');
        refreshAuthState();
    }
});

// Also listen for custom events for same-window updates
window.addEventListener('userProfileUpdated', () => {
    console.log('User profile updated, refreshing auth section');
    refreshAuthState();
});

// Export functions for use in other scripts
window.UniversalAuth = {
    init: initUniversalAuth,
    isAuthenticated: isUserAuthenticated,
    getCurrentUser: getCurrentUser,
    refresh: refreshAuthState,
    logout: handleLogout,
    storeProfileImage: storeProfileImage,
    getStoredProfileImage: getStoredProfileImage,
    DEFAULT_PROFILE_IMAGE: DEFAULT_PROFILE_IMAGE
};

console.log('✅ UNIVERSAL AUTHENTICATION MANAGER READY');