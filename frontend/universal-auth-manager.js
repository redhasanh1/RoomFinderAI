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
 * Check if user is authenticated via Supabase
 */
async function isUserAuthenticated() {
    try {
        // First check localStorage (primary auth method)
        const currentUser = localStorage.getItem('currentUser');
        if (currentUser && currentUser !== 'null' && currentUser !== 'undefined') {
            try {
                const userData = JSON.parse(currentUser);
                if (userData && userData.email) {
                    return true;
                }
            } catch (e) {
                console.error('Error parsing currentUser:', e);
            }
        }
        
        // Fallback to Supabase if available
        if (window.supabase && window.supabase.auth) {
            const { data: { session } } = await window.supabase.auth.getSession();
            return !!session?.user;
        }
        
        return false;
    } catch (error) {
        console.error('Auth check error:', error);
        return false;
    }
}

/**
 * Get current user data from Supabase
 */
async function getCurrentUser() {
    try {
        // First check localStorage (primary auth method)
        const currentUser = localStorage.getItem('currentUser');
        console.log('🔍 localStorage currentUser:', currentUser);
        if (currentUser && currentUser !== 'null' && currentUser !== 'undefined') {
            try {
                const userData = JSON.parse(currentUser);
                if (userData && userData.email) {
                    return userData;
                }
            } catch (e) {
                console.error('Error parsing currentUser from localStorage:', e);
            }
        }
        
        // Fallback to Supabase if available
        console.log('🔍 Falling back to Supabase auth');
        if (window.supabase && window.supabase.auth) {
            const { data: { session } } = await window.supabase.auth.getSession();
            console.log('🔍 Supabase session:', session?.user?.email || 'no session');
            if (!session?.user) return null;
            
            // Get profile data from profiles table
            const { data: profile, error } = await window.supabase
                .from('profiles')
                .select('first_name, last_name, email, profile_image_url')
                .eq('email', session.user.email)
                .single();
                
            if (error) {
                console.warn('Profile fetch error:', error);
                return {
                    email: session.user.email,
                    firstName: 'User',
                    lastName: 'Name'
                };
            }
            
            return {
                id: profile.id,
                email: profile.email,
                firstName: profile.first_name || 'User',
                lastName: profile.last_name || 'Name',
                profileImage: profile.profile_image_url || profile.profile_image
            };
        }
        
        return null;
    } catch (error) {
        console.error('Error getting current user:', error);
        return null;
    }
}

/**
 * Get stored profile image from Supabase with fallback
 */
async function getStoredProfileImage(email) {
    try {
        if (!window.supabase || !email) return DEFAULT_PROFILE_IMAGE;
        
        // Get profile image from Supabase
        const { data: profile, error } = await window.supabase
            .from('profiles')
            .select('profile_image_url')
            .eq('email', email)
            .single();
            
        const storedImage = profile?.profile_image_url;
        
        if (storedImage && storedImage !== 'null' && storedImage !== 'undefined') {
            return storedImage;
        }
        
        // Check backup storage
        const backupKey = `profileImageBackup_${email}`;
        const backupImage = null;
        
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
        // localStorage removed - using Supabase
        
        // Store backup
        // localStorage removed - using Supabase
        
        console.log('✅ Profile image stored successfully');
    } catch (error) {
        console.error('Error storing profile image:', error);
    }
}

/**
 * Persist currentUser to localStorage after profile sync
 */
function syncCurrentUserToStorage(user) {
    if (!user || !user.email) return;
    try {
        localStorage.setItem('currentUser', JSON.stringify(user));
    } catch (e) {
        console.warn('Could not persist currentUser:', e);
    }
}

/**
 * Whether the user already passed the Turnstile security check this session
 */
function isSecurityCheckPassed() {
    return sessionStorage.getItem('turnstile_verified') === 'true' ||
        localStorage.getItem('security_check_passed') === 'true';
}

/**
 * Redirect after login — skip verification-modal if already verified
 */
function redirectAfterLogin(redirectUrl) {
    const target = redirectUrl || 'index.html';
    if (isSecurityCheckPassed()) {
        window.location.href = target;
    } else {
        window.location.href = 'verification-modal.html?redirect=' + encodeURIComponent(target);
    }
}

/**
 * Toggle top-level Profile nav link visibility
 */
function updateNavProfileLink(isLoggedIn) {
    const profileLink = document.getElementById('navProfileLink');
    if (profileLink) {
        profileLink.style.display = isLoggedIn ? '' : 'none';
    }
}

/**
 * Update auth section UI (profile image / login button)
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

    const currentUser = await getCurrentUser();
    console.log('🔍 getCurrentUser() returned:', currentUser);
    
    if (await isUserAuthenticated() && currentUser) {
        // Try to fetch the latest profile image from backend first
        let profileImage = null;
        
        try {
            if (!currentUser.email) {
                console.warn('⚠️ No email found for current user, skipping profile fetch');
                return;
            }
            
            const response = await fetch(`/api/user-profile/${encodeURIComponent(currentUser.email)}`);
            if (response.ok) {
                const profileData = await response.json();
                console.log('📥 Frontend received profile data:', JSON.stringify(profileData, null, 2));
                
                // Check if profile image exists in storage (backend checks storage directly)
                if (profileData.profileImage && profileData.profileImage !== 'null') {
                    profileImage = profileData.profileImage;
                    currentUser.profileImage = profileData.profileImage;
                    currentUser.hasCustomProfileImage = true;
                    
                    console.log('✅ Profile image loaded from Supabase Storage:', profileData.profileImage);
                } else {
                    // No profile image found in storage, use default
                    profileImage = DEFAULT_PROFILE_IMAGE;
                    currentUser.profileImage = DEFAULT_PROFILE_IMAGE;
                    currentUser.hasCustomProfileImage = false;
                    
                    console.log('ℹ️ No profile image found in storage, using default');
                }
                
                // Update names from database (prioritize database over localStorage)
                if (profileData.firstName || profileData.lastName) {
                    currentUser.firstName = profileData.firstName || '';
                    currentUser.lastName = profileData.lastName || '';
                    console.log('✅ Updated names from backend in auth section:', profileData.firstName, profileData.lastName);
                }

                currentUser.isPro = profileData.isPro === true || profileData.plan === 'pro';
                currentUser.plan = profileData.plan || (currentUser.isPro ? 'pro' : 'free');
            }
        } catch (error) {
            console.error('Error fetching profile data in auth section:', error);
        }
        
        // Fallback to stored/local profile image if backend fetch failed
        if (!profileImage) {
            profileImage = await getStoredProfileImage(currentUser.email);
        }
        
        // If still no image, check current user object
        if (!profileImage) {
            profileImage = currentUser.profileImage;
        }
        
        // Ensure we have a valid profile image (either from storage or default)
        if (!profileImage || profileImage === 'null' || profileImage === 'undefined') {
            profileImage = DEFAULT_PROFILE_IMAGE;
        }
        
        // Update currentUser with the correct image
        if (currentUser.profileImage !== profileImage) {
            currentUser.profileImage = profileImage;
            // localStorage removed - using Supabase);
            
            // Profile image synchronized via Supabase
            console.log('✅ Profile image synchronized');
            
            // Profile images are now stored in Supabase Storage, no local persistence needed
        }
        
        const proBadge = currentUser.isPro
            ? '<span class="absolute -bottom-1 -right-1 bg-blue-600 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full">PRO</span>'
            : '';

        // User is logged in - show profile
        authSection.innerHTML = `
            <a href="profile.html" class="profile-link relative inline-block">
                <img id="profileLogo" src="${profileImage}" alt="Profile" class="w-10 h-10 rounded-full profile-logo hover:ring-2 hover:ring-blue-500 transition-all duration-200" onerror="this.src='${DEFAULT_PROFILE_IMAGE}'">
                ${proBadge}
            </a>
        `;
        syncCurrentUserToStorage(currentUser);
        updateNavProfileLink(true);
        
        console.log('✅ Auth section updated - showing profile image');
    } else {
        // User is not logged in - show login/register
        authSection.innerHTML = `
            <a href="login.html" class="auth-link login-register-btn px-4 py-2 rounded-lg transition-colors duration-200">
                Login/Register
            </a>
        `;
        updateNavProfileLink(false);
        
        console.log('✅ Auth section updated - showing login/register');
    }

    // Mirror desktop auth into mobile nav when present
    const mobileAuth = document.getElementById('mobileAuthSection');
    if (mobileAuth && authSection) {
        if (await isUserAuthenticated() && currentUser) {
            mobileAuth.innerHTML = `
                <a href="profile.html" class="mobile-menu-item auth-item" onclick="typeof closeMobileMenu==='function'&&closeMobileMenu()">
                    <img src="${authSection.querySelector('img')?.src || DEFAULT_PROFILE_IMAGE}" alt="Profile" class="site-mobile-profile-img" onerror="this.src='${DEFAULT_PROFILE_IMAGE}'">
                    My Profile
                </a>
                <a href="#" class="mobile-menu-item auth-item" onclick="event.preventDefault(); if(window.UniversalAuth&&UniversalAuth.logout) UniversalAuth.logout();">Log out</a>
            `;
        } else {
            mobileAuth.innerHTML = `
                <a href="login.html" class="mobile-menu-item auth-item" onclick="typeof closeMobileMenu==='function'&&closeMobileMenu()">Login/Register</a>
            `;
        }
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

    const currentUser = await getCurrentUser();
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
            const newProfile = {
                email: currentUser.email,
                profile_image_url: DEFAULT_PROFILE_IMAGE
            };
            const { data, error: insertError } = await supabaseClient
                .from('profiles')
                .upsert([newProfile], { onConflict: 'email' })
                .select()
                .single();

            if (insertError) {
                console.error('Error creating profile:', insertError);
                return false;
            }
            profile = data;
        }

        currentUser.id = profile.id;
        currentUser.profileImage = profile.profile_image_url || profile.profile_image || DEFAULT_PROFILE_IMAGE;
        syncCurrentUserToStorage(currentUser);

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
    const isAuthenticated = await isUserAuthenticated();
    
    if (!isAuthenticated) {
        if (allowAnonymous) {
            console.log('✅ Anonymous access allowed');
            await updateAuthSection();
            return { authenticated: false, allowed: true };
        } else if (redirectToLogin) {
            console.log('🔄 Redirecting to login...');
            window.location.href = 'login.html';
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
        // localStorage removed
        window.location.href = 'login.html';
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
    redirectAfterLogin: redirectAfterLogin,
    isSecurityCheckPassed: isSecurityCheckPassed,
    DEFAULT_PROFILE_IMAGE: DEFAULT_PROFILE_IMAGE
};

console.log('✅ UNIVERSAL AUTHENTICATION MANAGER READY');