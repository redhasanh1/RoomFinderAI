// Authentication module
window.AuthManager = (function() {
    const defaultProfileImage = 'https://ui-avatars.com/api/?name=User&background=667eea&color=ffffff&size=128&format=svg';

    let currentUser = null;

    // Initialize current user from localStorage
    function initCurrentUser() {
        const storedUser = localStorage.getItem('currentUser');
        if (storedUser) {
            currentUser = JSON.parse(storedUser);
        }
        return currentUser;
    }

    // Check if user is authenticated
    function isAuthenticated() {
        return !!getCurrentUser();
    }

    // Get current user
    function getCurrentUser() {
        if (!currentUser) {
            initCurrentUser();
        }
        return currentUser;
    }

    // Redirect to login if not authenticated
    function requireAuth() {
        const user = getCurrentUser();
        if (!user) {
            console.log('No current user, redirecting to login');
            window.location.href = '/login';
            return false;
        }
        return true;
    }

    // Initialize user session with Supabase RLS
    async function initializeSession() {
        const user = getCurrentUser();
        if (!user) {
            console.log('No current user, redirecting to login');
            window.location.href = '/login';
            return false;
        }

        try {
            // Set current user email for RLS (Row Level Security)
            const { error } = await window.AppConfig.supabase.rpc('set_current_user_email', { 
                email: user.email 
            });
            
            console.log('RPC set_current_user_email response:', { error });
            
            if (error) {
                console.error('Error setting current user email:', error);
                alert('Failed to initialize session: ' + error.message);
                return false;
            }
            
            console.log('Current user email set for RLS:', user.email);
            return true;
        } catch (err) {
            console.error('RPC call failed:', err);
            alert('Failed to initialize session. Please check your connection.');
            return false;
        }
    }

    // Assign random profile image if missing
    function ensureProfileImage() {
        const user = getCurrentUser();
        if (!user) return;

        if (!user.profileImage) {
            user.profileImage = defaultProfileImage;
            
            // Update in localStorage
            let users = JSON.parse(localStorage.getItem('users')) || [];
            users = users.map(u => u.email === user.email ? user : u);
            localStorage.setItem('users', JSON.stringify(users));
            localStorage.setItem('currentUser', JSON.stringify(user));
            
            // Update current reference
            currentUser = user;
        }
    }

    // Update profile UI in header
    function updateProfileUI() {
        const user = getCurrentUser();
        const authSection = document.getElementById('authSection');
        
        if (!authSection) return;

        if (user) {
            ensureProfileImage();
            authSection.innerHTML = `
                <div class="flex items-center space-x-2">
                    <div class="relative">
                        <span id="profileNotificationBadge" class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-5 h-5 text-xs flex items-center justify-center hidden z-10">0</span>
                        <a href="/profile">
                            <img id="profileLogo" src="${user.profileImage}" alt="Profile" class="w-10 h-10 rounded-full profile-logo">
                        </a>
                    </div>
                </div>
            `;
        } else {
            authSection.innerHTML = `
                <a href="login.html" class="auth-link login-register-btn px-4 py-2 rounded-lg transition-colors duration-200">Login/Register</a>
            `;
        }
    }

    // Create user profile in database if missing
    async function ensureUserProfile() {
        const user = getCurrentUser();
        if (!user) return null;

        try {
            // Check if profile exists
            const { data: profile, error: profileError } = await window.AppConfig.supabase
                .from('profiles')
                .select('*')
                .eq('email', user.email)
                .single();

            if (profileError && profileError.code !== 'PGRST116') {
                console.error('Error checking user profile:', profileError);
                return null;
            }

            // Create profile if missing
            if (!profile) {
                console.log('Creating missing profile for current user...');
                const { data: newProfile, error: createError } = await window.AppConfig.supabase
                    .from('profiles')
                    .insert([{
                        email: user.email,
                        first_name: user.firstName || 'User',
                        last_name: user.lastName || '',
                        created_at: new Date().toISOString()
                    }])
                    .select()
                    .single();

                if (createError) {
                    console.error('Error creating user profile:', createError);
                    alert('Error setting up your profile. Please try refreshing the page.');
                    return null;
                }
                
                console.log('✅ Created profile for current user');
                return newProfile;
            }

            return profile;
        } catch (error) {
            console.error('Error ensuring user profile:', error);
            return null;
        }
    }

    // Check authentication for specific actions
    function checkAuthForAction(action = 'perform this action') {
        const user = getCurrentUser();
        if (!user) {
            alert(`Please log in to ${action}.`);
            window.location.href = '/login';
            return false;
        }
        return true;
    }

    // Logout function
    function logout() {
        currentUser = null;
        localStorage.removeItem('currentUser');
        window.location.href = '/login';
    }

    // Get auth status for diagnostics
    function getAuthStatus() {
        const user = getCurrentUser();
        return {
            isAuthenticated: !!user,
            userEmail: user?.email || null,
            hasProfile: !!user
        };
    }

    // Initialize auth module
    function initialize() {
        initCurrentUser();
        updateProfileUI();
    }

    // Public API
    return {
        initialize,
        isAuthenticated,
        getCurrentUser,
        requireAuth,
        initializeSession,
        ensureProfileImage,
        updateProfileUI,
        ensureUserProfile,
        checkAuthForAction,
        logout,
        getAuthStatus
    };
})();