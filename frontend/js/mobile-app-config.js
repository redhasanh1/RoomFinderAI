// Mobile App Configuration - Kijiji-inspired Android Interface

class MobileAppConfig {
    constructor() {
        this.isInitialized = false;
        this.currentLocation = 'Toronto, ON';
        this.activeFilters = {
            type: 'all',
            priceMin: null,
            priceMax: null,
            bedrooms: 'any',
            propertyTypes: []
        };
        this.user = {
            isLoggedIn: false,
            name: 'Guest User',
            email: 'Not logged in',
            avatar: '👤'
        };
        this.notifications = {
            messages: 3
        };
    }

    // Initialize the mobile app
    init() {
        console.log('🚀 Initializing Mobile App Config...');
        
        // Check authentication status
        this.checkAuthStatus();
        
        // Setup event listeners
        this.setupEventListeners();
        
        // Initialize UI state
        this.updateUI();
        
        this.isInitialized = true;
        console.log('✅ Mobile App Config initialized');
    }

    // Check if user is authenticated
    async checkAuthStatus() {
        try {
            // Check with Supabase if available
            if (window.supabase) {
                const { data: { user } } = await window.supabase.auth.getUser();
                if (user) {
                    this.user.isLoggedIn = true;
                    this.user.name = user.user_metadata?.full_name || user.email;
                    this.user.email = user.email;
                    this.user.avatar = user.user_metadata?.avatar_url ? '🔵' : '👤';
                }
            }
        } catch (error) {
            console.warn('Auth check failed:', error);
        }
    }

    // Setup global event listeners
    setupEventListeners() {
        // Close dropdowns when clicking outside
        document.addEventListener('click', (e) => {
            if (!e.target.closest('.profile-menu-container')) {
                this.closeProfileMenu();
            }
            if (!e.target.closest('.modal')) {
                this.closeAllModals();
            }
        });

        // Handle escape key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.closeProfileMenu();
                this.closeAllModals();
            }
        });

        // Handle quick filter changes
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('quick-filter')) {
                this.handleQuickFilter(e.target);
            }
        });

        // Handle bedroom selector in filters
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('bedroom-btn')) {
                this.handleBedroomSelection(e.target);
            }
        });

        // Prevent default touch behavior on certain elements
        document.addEventListener('touchstart', (e) => {
            // Allow normal touch behavior for all elements
            // This fixes the Android navigation issue
        }, { passive: true });
    }

    // Update UI based on current state
    updateUI() {
        // Update location display
        const locationText = document.getElementById('currentLocation');
        if (locationText) {
            locationText.textContent = this.currentLocation;
        }

        // Update profile info
        this.updateProfileUI();
        
        // Update notification badges
        this.updateNotificationBadges();
    }

    // Update profile UI elements
    updateProfileUI() {
        const profileName = document.getElementById('profileName');
        const profileEmail = document.getElementById('profileEmail');
        const profileIcon = document.getElementById('profileIcon');
        const authSection = document.getElementById('authSection');
        const userSection = document.getElementById('userSection');
        const logoutSection = document.getElementById('logoutSection');

        if (profileName) profileName.textContent = this.user.name;
        if (profileEmail) profileEmail.textContent = this.user.email;
        if (profileIcon) {
            // Check if avatar is a URL or an emoji/text
            if (this.user.avatar && (this.user.avatar.startsWith('http') || this.user.avatar.startsWith('data:'))) {
                // It's an image URL, create an img element
                profileIcon.innerHTML = `<img src="${this.user.avatar}" alt="Profile" style="width: 100%; height: 100%; object-fit: cover; border-radius: 50%;">`;
            } else {
                // It's text/emoji
                profileIcon.textContent = this.user.avatar || '👤';
            }
        }

        // Show/hide sections based on auth status
        if (this.user.isLoggedIn) {
            if (authSection) authSection.style.display = 'none';
            if (userSection) userSection.style.display = 'block';
            if (logoutSection) logoutSection.style.display = 'block';
        } else {
            if (authSection) authSection.style.display = 'block';
            if (userSection) userSection.style.display = 'none';
            if (logoutSection) logoutSection.style.display = 'none';
        }
    }

    // Update notification badges
    updateNotificationBadges() {
        const messageBadge = document.getElementById('messageBadge');
        const navMessageBadge = document.getElementById('navMessageBadge');
        
        const messageCount = this.notifications.messages;
        const badgeText = messageCount > 0 ? messageCount.toString() : '';
        const badgeVisible = messageCount > 0;

        if (messageBadge) {
            messageBadge.textContent = badgeText;
            messageBadge.style.display = badgeVisible ? 'block' : 'none';
        }
        
        if (navMessageBadge) {
            navMessageBadge.textContent = badgeText;
            navMessageBadge.style.display = badgeVisible ? 'block' : 'none';
        }
    }

    // Handle quick filter selection
    handleQuickFilter(filterElement) {
        // Remove active class from all filters
        document.querySelectorAll('.quick-filter').forEach(filter => {
            filter.classList.remove('active');
        });

        // Add active class to selected filter
        filterElement.classList.add('active');

        // Update active filter
        const filterType = filterElement.dataset.filter;
        this.activeFilters.type = filterType;

        // Trigger filter update event
        this.onFiltersChanged();
    }

    // Handle bedroom selection in filters modal
    handleBedroomSelection(bedroomBtn) {
        // Remove active class from all bedroom buttons
        document.querySelectorAll('.bedroom-btn').forEach(btn => {
            btn.classList.remove('active');
        });

        // Add active class to selected button
        bedroomBtn.classList.add('active');

        // Update bedroom filter
        this.activeFilters.bedrooms = bedroomBtn.dataset.bedrooms;
    }

    // Close profile menu
    closeProfileMenu() {
        const dropdown = document.getElementById('profileDropdown');
        if (dropdown) {
            dropdown.classList.remove('active');
        }
    }

    // Close all modals
    closeAllModals() {
        document.querySelectorAll('.modal').forEach(modal => {
            modal.classList.remove('active');
        });
    }

    // Get current filters
    getFilters() {
        return { ...this.activeFilters };
    }

    // Update location
    setLocation(location) {
        this.currentLocation = location;
        const locationText = document.getElementById('currentLocation');
        if (locationText) {
            locationText.textContent = location;
        }
        
        // Trigger location change event
        this.onLocationChanged(location);
    }

    // Event handlers (to be overridden by other modules)
    onFiltersChanged() {
        console.log('Filters changed:', this.activeFilters);
        // This will be overridden by the listings module
        if (window.MobileAppListings) {
            window.MobileAppListings.onFiltersChanged(this.activeFilters);
        }
    }

    onLocationChanged(location) {
        console.log('Location changed:', location);
        // This will be overridden by the listings module
        if (window.MobileAppListings) {
            window.MobileAppListings.onLocationChanged(location);
        }
    }

    // Analytics tracking
    trackEvent(event, data = {}) {
        console.log('📊 Analytics Event:', event, data);
        // Add your analytics tracking here (Google Analytics, etc.)
    }

    // Utility methods
    formatPrice(price) {
        if (!price) return 'Price on request';
        return new Intl.NumberFormat('en-CA', {
            style: 'currency',
            currency: 'CAD',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(price);
    }

    formatDistance(distance) {
        if (distance < 1) {
            return `${Math.round(distance * 1000)}m`;
        }
        return `${distance.toFixed(1)}km`;
    }

    // Show toast notification
    showToast(message, type = 'info') {
        // Create toast element if it doesn't exist
        let toast = document.querySelector('.toast-container');
        if (!toast) {
            toast = document.createElement('div');
            toast.className = 'toast-container';
            toast.style.cssText = `
                position: fixed;
                top: 20px;
                right: 20px;
                z-index: 3000;
                pointer-events: none;
            `;
            document.body.appendChild(toast);
        }

        const toastElement = document.createElement('div');
        toastElement.className = `toast toast-${type}`;
        toastElement.style.cssText = `
            background: ${type === 'error' ? '#ef4444' : type === 'success' ? '#10b981' : '#3b82f6'};
            color: white;
            padding: 12px 16px;
            border-radius: 8px;
            margin-bottom: 8px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
            transform: translateX(100%);
            transition: transform 0.3s ease;
            pointer-events: auto;
            font-size: 14px;
            font-weight: 500;
        `;
        toastElement.textContent = message;

        toast.appendChild(toastElement);

        // Animate in
        setTimeout(() => {
            toastElement.style.transform = 'translateX(0)';
        }, 10);

        // Remove after 3 seconds
        setTimeout(() => {
            toastElement.style.transform = 'translateX(100%)';
            setTimeout(() => {
                toast.removeChild(toastElement);
            }, 300);
        }, 3000);
    }
}

// Create global instance
window.MobileAppConfig = new MobileAppConfig();

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.MobileAppConfig.init();
    });
} else {
    window.MobileAppConfig.init();
}