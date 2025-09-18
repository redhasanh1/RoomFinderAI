/**
 * Authentication Manager Module
 * Handles user authentication, profile management, and session initialization
 */

class AuthManager {
    constructor() {
        this.currentUser = null;
        this.authSection = null;
        this.isInitialized = false;
        this.profileImages = [
            'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48Y2lyY2xlIGN4PSIyMCIgY3k9IjIwIiByPSIyMCIgZmlsbD0iI0ZGNkI2QiIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IndoaXRlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBkeT0iLjNlbSI+VTwvdGV4dD48L3N2Zz4=',
            'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48Y2lyY2xlIGN4PSIyMCIgY3k9IjIwIiByPSIyMCIgZmlsbD0iIzRFQ0RDNCIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IndoaXRlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBkeT0iLjNlbSI+VTwvdGV4dD48L3N2Zz4=',
            'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48Y2lyY2xlIGN4PSIyMCIgY3k9IjIwIiByPSIyMCIgZmlsbD0iI0ZGRTY2RCIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IndoaXRlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBkeT0iLjNlbSI+VTwvdGV4dD48L3N2Zz4=',
            'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48Y2lyY2xlIGN4PSIyMCIgY3k9IjIwIiByPSIyMCIgZmlsbD0iIzZCNzI4MCIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IndoaXRlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBkeT0iLjNlbSI+VTwvdGV4dD48L3N2Zz4=',
            'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48Y2lyY2xlIGN4PSIyMCIgY3k9IjIwIiByPSIyMCIgZmlsbD0iI0ZGOUYxQyIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IndoaXRlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBkeT0iLjNlbSI+VTwvdGV4dD48L3N2Zz4='
        ];
        this.onUserLoadedCallbacks = [];
    }

    /**
     * Initialize authentication manager
     */
    async init() {
        if (this.isInitialized) return;

        console.log('🔐 Initializing Authentication Manager...');

        this.authSection = document.getElementById('authSection');
        await this.loadCurrentUser();

        this.isInitialized = true;
        console.log('✅ Authentication Manager initialized');
    }

    /**
     * Load current user and setup authentication state
     */
    async loadCurrentUser() {
        // Use auth protection to get current user safely
        this.currentUser = window.authProtection ?
            window.authProtection.getCurrentUser() :
            this.getCurrentUserDirect();

        console.log('Current user:', this.currentUser);

        if (!this.currentUser) {
            console.log('No current user, showing anonymous interface');
            this.renderAnonymousInterface();
            this.executeUserLoadedCallbacks(null);
            return false;
        }

        // Setup profile image if not exists
        if (!this.currentUser.profileImage) {
            this.currentUser.profileImage = this.profileImages[
                Math.floor(Math.random() * this.profileImages.length)
            ];
            this.saveCurrentUser();
        }

        // Set current user email for RLS
        try {
            const supabase = window.configManager ? window.configManager.getSupabase() : null;
            if (supabase) {
                const { error } = await supabase.rpc('set_current_user_email', {
                    email: this.currentUser.email
                });

                console.log('RPC set_current_user_email response:', { error });

                if (error) {
                    console.error('Error setting current user email:', error);
                    alert('Failed to initialize session: ' + error.message);
                    return false;
                }

                console.log('Current user email set for RLS:', this.currentUser.email);
            }
        } catch (err) {
            console.error('RPC call failed:', err);
            alert('Failed to initialize session. Please check your connection.');
            return false;
        }

        this.renderAuthenticatedInterface();
        this.executeUserLoadedCallbacks(this.currentUser);
        return true;
    }

    /**
     * Get current user directly from localStorage
     */
    getCurrentUserDirect() {
        try {
            const userString = localStorage.getItem('currentUser');
            return userString ? JSON.parse(userString) : null;
        } catch (error) {
            console.error('Error parsing current user:', error);
            return null;
        }
    }

    /**
     * Save current user to localStorage and backup
     */
    saveCurrentUser() {
        if (!this.currentUser) return;

        const userString = JSON.stringify(this.currentUser);
        localStorage.setItem('currentUser', userString);

        // Update users array
        let users = JSON.parse(localStorage.getItem('users')) || [];
        users = users.map(u => u.email === this.currentUser.email ? this.currentUser : u);

        // Add user if not exists
        if (!users.find(u => u.email === this.currentUser.email)) {
            users.push(this.currentUser);
        }

        localStorage.setItem('users', JSON.stringify(users));

        // Create backup if auth protection is available
        if (window.authProtection) {
            window.authProtection.createUserBackup();
        }
    }

    /**
     * Render interface for anonymous users
     */
    renderAnonymousInterface() {
        if (!this.authSection) return;

        this.authSection.innerHTML = `
            <div class="flex items-center space-x-4">
                <a href="/login" class="auth-link">Login</a>
                <a href="/signup" class="auth-link">Sign Up</a>
            </div>
        `;
    }

    /**
     * Render interface for authenticated users
     */
    renderAuthenticatedInterface() {
        if (!this.authSection || !this.currentUser) return;

        this.authSection.innerHTML = `
            <div class="flex items-center space-x-2">
                <div class="relative">
                    <span id="profileNotificationBadge" class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-5 h-5 text-xs flex items-center justify-center hidden z-10">0</span>
                    <a href="/profile">
                        <img id="profileLogo" src="${this.currentUser.profileImage}" alt="Profile" class="w-10 h-10 rounded-full profile-logo">
                    </a>
                </div>
            </div>
        `;
    }

    /**
     * Register callback to be executed when user is loaded
     */
    onUserLoaded(callback) {
        this.onUserLoadedCallbacks.push(callback);

        // If user already loaded, execute immediately
        if (this.isInitialized) {
            try {
                callback(this.currentUser);
            } catch (error) {
                console.error('User loaded callback error:', error);
            }
        }
    }

    /**
     * Execute all user loaded callbacks
     */
    executeUserLoadedCallbacks(user) {
        this.onUserLoadedCallbacks.forEach(callback => {
            try {
                callback(user);
            } catch (error) {
                console.error('User loaded callback error:', error);
            }
        });
    }

    /**
     * Get current user
     */
    getCurrentUser() {
        return this.currentUser;
    }

    /**
     * Check if user is authenticated
     */
    isAuthenticated() {
        return !!this.currentUser;
    }

    /**
     * Update profile notification badge
     */
    updateNotificationBadge(count) {
        const badge = document.getElementById('profileNotificationBadge');
        if (badge) {
            if (count > 0) {
                badge.textContent = count.toString();
                badge.classList.remove('hidden');
            } else {
                badge.classList.add('hidden');
            }
        }
    }

    /**
     * Update current user data
     */
    updateUser(userData) {
        if (this.currentUser) {
            Object.assign(this.currentUser, userData);
            this.saveCurrentUser();
            this.renderAuthenticatedInterface();
        }
    }

    /**
     * Logout current user
     */
    logout() {
        this.currentUser = null;
        localStorage.removeItem('currentUser');
        this.renderAnonymousInterface();
        this.executeUserLoadedCallbacks(null);

        // Optionally redirect or reload
        // window.location.href = '/';
    }
}

// Create global instance
window.authManager = new AuthManager();

export default window.authManager;