// Mobile App Navigation - Handle page switching and modal management

class MobileAppNavigation {
    constructor() {
        this.currentPage = 'home';
        this.pageHistory = ['home'];
        this.isModalOpen = false;
    }

    init() {
        console.log('🧭 Initializing Mobile App Navigation...');
        this.setupNavigationEvents();
        console.log('✅ Mobile App Navigation initialized');
    }

    setupNavigationEvents() {
        // Bottom navigation
        this.setupBottomNavigation();
        
        // Profile menu
        this.setupProfileMenu();
        
        // Modals
        this.setupModals();
        
        // Back button handling
        this.setupBackButtonHandling();
    }

    setupBottomNavigation() {
        const navItems = document.querySelectorAll('.nav-item');
        navItems.forEach(item => {
            item.addEventListener('click', (e) => {
                e.preventDefault();
                const page = item.dataset.page;
                if (page && page !== 'post') {
                    this.switchPage(page);
                }
            });
        });
    }

    setupProfileMenu() {
        // Profile button click
        const profileBtn = document.querySelector('.profile-btn');
        if (profileBtn) {
            profileBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                this.toggleProfileMenu();
            });
        }

        // Profile menu items
        const menuItems = document.querySelectorAll('.menu-item');
        menuItems.forEach(item => {
            item.addEventListener('click', (e) => {
                const href = item.getAttribute('href');
                if (href && href !== '#') {
                    // Allow normal navigation for external links
                    return;
                }
                
                e.preventDefault();
                const onclick = item.getAttribute('onclick');
                if (onclick) {
                    // Execute the onclick function
                    try {
                        eval(onclick);
                    } catch (error) {
                        console.warn('Error executing menu item click:', error);
                    }
                }
                
                // Close menu after click
                this.closeProfileMenu();
            });
        });
    }

    setupModals() {
        // Modal close buttons
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal-close')) {
                this.closeModal(e.target.closest('.modal'));
            }
        });

        // Modal backdrop clicks
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal')) {
                this.closeModal(e.target);
            }
        });
    }

    setupBackButtonHandling() {
        // Handle browser back button
        window.addEventListener('popstate', (e) => {
            if (this.isModalOpen) {
                this.closeAllModals();
                return;
            }
            
            if (this.pageHistory.length > 1) {
                this.pageHistory.pop(); // Remove current page
                const previousPage = this.pageHistory[this.pageHistory.length - 1];
                this.switchPage(previousPage, false); // Don't add to history
            }
        });

        // Handle Android back button (if running in Capacitor)
        if (window.Capacitor) {
            window.Capacitor.Plugins.App.addListener('backButton', (e) => {
                if (this.isModalOpen) {
                    this.closeAllModals();
                    return;
                }
                
                if (this.currentPage !== 'home') {
                    this.switchPage('home');
                } else {
                    window.Capacitor.Plugins.App.exitApp();
                }
            });
        }
    }

    // Page switching
    switchPage(page, addToHistory = true) {
        console.log(`📱 Switching to page: ${page}`);
        
        // Update navigation state
        if (addToHistory && page !== this.currentPage) {
            this.pageHistory.push(page);
        }
        this.currentPage = page;

        // Update bottom navigation
        this.updateBottomNavigation(page);

        // Handle page-specific logic
        this.handlePageSwitch(page);

        // Update URL without reload
        const newUrl = page === 'home' ? '/mobile-app.html' : `/mobile-app.html#${page}`;
        if (addToHistory) {
            history.pushState({ page }, '', newUrl);
        }

        // Track page view
        if (window.MobileAppConfig) {
            window.MobileAppConfig.trackEvent('page_view', { page });
        }
    }

    updateBottomNavigation(activePage) {
        const navItems = document.querySelectorAll('.nav-item');
        navItems.forEach(item => {
            const page = item.dataset.page;
            if (page === activePage) {
                item.classList.add('active');
            } else {
                item.classList.remove('active');
            }
        });
    }

    handlePageSwitch(page) {
        const contentContainer = document.getElementById('contentContainer');
        if (!contentContainer) return;

        // Show loading
        this.showPageLoading();

        switch (page) {
            case 'home':
                this.loadHomePage();
                break;
            case 'search':
                this.loadSearchPage();
                break;
            case 'messages':
                this.loadMessagesPage();
                break;
            case 'profile':
                this.loadProfilePage();
                break;
            default:
                this.loadHomePage();
        }
    }

    showPageLoading() {
        const contentContainer = document.getElementById('contentContainer');
        if (contentContainer) {
            contentContainer.innerHTML = `
                <div class="loading-spinner">
                    <div class="spinner"></div>
                    <p>Loading...</p>
                </div>
            `;
        }
    }

    loadHomePage() {
        // Load property listings
        if (window.MobileAppListings) {
            window.MobileAppListings.loadListings();
        } else {
            this.showPlaceholderContent('🏠 Property Listings', 'Your dream home is just a tap away!');
        }
    }

    loadSearchPage() {
        const contentContainer = document.getElementById('contentContainer');
        if (contentContainer) {
            contentContainer.innerHTML = `
                <div class="search-page">
                    <div class="search-header">
                        <h2>🔍 Advanced Search</h2>
                        <p>Find exactly what you're looking for</p>
                    </div>
                    
                    <div class="search-form">
                        <div class="search-field">
                            <label>Search Keywords</label>
                            <input type="text" placeholder="e.g. 2 bedroom apartment downtown" class="search-input">
                        </div>
                        
                        <div class="search-field">
                            <label>Location</label>
                            <input type="text" placeholder="City, neighborhood, or postal code" class="location-input">
                        </div>
                        
                        <div class="search-grid">
                            <div class="search-field">
                                <label>Min Price</label>
                                <select class="price-select">
                                    <option value="">Any</option>
                                    <option value="500">$500+</option>
                                    <option value="1000">$1,000+</option>
                                    <option value="1500">$1,500+</option>
                                    <option value="2000">$2,000+</option>
                                </select>
                            </div>
                            
                            <div class="search-field">
                                <label>Max Price</label>
                                <select class="price-select">
                                    <option value="">Any</option>
                                    <option value="1000">$1,000</option>
                                    <option value="2000">$2,000</option>
                                    <option value="3000">$3,000</option>
                                    <option value="5000">$5,000+</option>
                                </select>
                            </div>
                        </div>
                        
                        <div class="search-field">
                            <label>Property Type</label>
                            <div class="checkbox-group">
                                <label class="checkbox-item">
                                    <input type="checkbox" value="apartment"> Apartment
                                </label>
                                <label class="checkbox-item">
                                    <input type="checkbox" value="house"> House
                                </label>
                                <label class="checkbox-item">
                                    <input type="checkbox" value="condo"> Condo
                                </label>
                                <label class="checkbox-item">
                                    <input type="checkbox" value="room"> Room
                                </label>
                            </div>
                        </div>
                        
                        <button class="btn-primary search-btn" onclick="performSearch()">
                            🔍 Search Properties
                        </button>
                    </div>
                </div>
            `;
        }
    }

    loadMessagesPage() {
        this.showPlaceholderContent('💬 Messages', 'Your conversations with property owners and agents.');
    }

    loadProfilePage() {
        const isLoggedIn = window.MobileAppConfig?.user?.isLoggedIn || false;
        
        if (isLoggedIn) {
            this.showProfileDashboard();
        } else {
            this.showLoginPrompt();
        }
    }

    showProfileDashboard() {
        const contentContainer = document.getElementById('contentContainer');
        if (contentContainer) {
            contentContainer.innerHTML = `
                <div class="profile-dashboard">
                    <div class="profile-header">
                        <div class="profile-avatar-xl">👤</div>
                        <h2>${window.MobileAppConfig.user.name}</h2>
                        <p>${window.MobileAppConfig.user.email}</p>
                    </div>
                    
                    <div class="dashboard-stats">
                        <div class="stat-card">
                            <div class="stat-number">12</div>
                            <div class="stat-label">Saved Properties</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-number">3</div>
                            <div class="stat-label">Active Listings</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-number">28</div>
                            <div class="stat-label">Messages</div>
                        </div>
                    </div>
                    
                    <div class="quick-actions">
                        <h3>Quick Actions</h3>
                        <div class="action-grid">
                            <button class="action-card" onclick="showMyListings()">
                                <span class="action-icon">🏠</span>
                                <span class="action-text">My Listings</span>
                            </button>
                            <button class="action-card" onclick="showSavedProperties()">
                                <span class="action-icon">❤️</span>
                                <span class="action-text">Saved</span>
                            </button>
                            <button class="action-card" onclick="showMessages()">
                                <span class="action-icon">💬</span>
                                <span class="action-text">Messages</span>
                            </button>
                            <button class="action-card" onclick="showSettings()">
                                <span class="action-icon">⚙️</span>
                                <span class="action-text">Settings</span>
                            </button>
                        </div>
                    </div>
                </div>
            `;
        }
    }

    showLoginPrompt() {
        const contentContainer = document.getElementById('contentContainer');
        if (contentContainer) {
            contentContainer.innerHTML = `
                <div class="login-prompt">
                    <div class="login-icon">🔐</div>
                    <h2>Welcome to RoomFinderAI</h2>
                    <p>Sign in to access your personalized dashboard, save properties, and manage your listings.</p>
                    
                    <div class="login-actions">
                        <a href="login.html" class="btn-primary">Sign In</a>
                        <a href="signup.html" class="btn-secondary">Create Account</a>
                    </div>
                    
                    <div class="guest-options">
                        <button onclick="switchPage('home')" class="btn-link">Continue as Guest</button>
                    </div>
                </div>
            `;
        }
    }

    showPlaceholderContent(title, description) {
        const contentContainer = document.getElementById('contentContainer');
        if (contentContainer) {
            contentContainer.innerHTML = `
                <div class="placeholder-content">
                    <h2>${title}</h2>
                    <p>${description}</p>
                    <p class="placeholder-note">This feature is coming soon!</p>
                </div>
            `;
        }
    }

    // Profile Menu Methods
    toggleProfileMenu() {
        const dropdown = document.getElementById('profileDropdown');
        if (dropdown) {
            dropdown.classList.toggle('active');
        }
    }

    closeProfileMenu() {
        const dropdown = document.getElementById('profileDropdown');
        if (dropdown) {
            dropdown.classList.remove('active');
        }
    }

    // Modal Methods
    openModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.add('active');
            this.isModalOpen = true;
            document.body.style.overflow = 'hidden';
        }
    }

    closeModal(modal) {
        if (modal) {
            modal.classList.remove('active');
            this.isModalOpen = false;
            document.body.style.overflow = '';
        }
    }

    closeAllModals() {
        document.querySelectorAll('.modal').forEach(modal => {
            this.closeModal(modal);
        });
    }
}

// Global function bindings for onclick handlers
window.toggleProfileMenu = () => window.MobileAppNavigation?.toggleProfileMenu();
window.switchPage = (page) => window.MobileAppNavigation?.switchPage(page);
window.openLocationModal = () => window.MobileAppNavigation?.openModal('locationModal');
window.closeLocationModal = () => window.MobileAppNavigation?.closeModal(document.getElementById('locationModal'));
window.openFiltersModal = () => window.MobileAppNavigation?.openModal('filtersModal');
window.closeFiltersModal = () => window.MobileAppNavigation?.closeModal(document.getElementById('filtersModal'));
window.openPostModal = () => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('Post feature coming soon!', 'info');
    }
};

window.selectLocation = (location) => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.setLocation(location);
    }
    window.closeLocationModal();
};

window.clearFilters = () => {
    // Reset filter form
    document.querySelectorAll('#filtersModal input[type="number"]').forEach(input => {
        input.value = '';
    });
    document.querySelectorAll('#filtersModal input[type="checkbox"]').forEach(input => {
        input.checked = false;
    });
    document.querySelectorAll('.bedroom-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    document.querySelector('.bedroom-btn[data-bedrooms="any"]')?.classList.add('active');
};

window.applyFilters = () => {
    // Get filter values
    const minPrice = document.getElementById('minPrice')?.value || null;
    const maxPrice = document.getElementById('maxPrice')?.value || null;
    const bedrooms = document.querySelector('.bedroom-btn.active')?.dataset.bedrooms || 'any';
    const propertyTypes = Array.from(document.querySelectorAll('#filtersModal input[type="checkbox"]:checked')).map(cb => cb.value);

    // Update config
    if (window.MobileAppConfig) {
        window.MobileAppConfig.activeFilters = {
            ...window.MobileAppConfig.activeFilters,
            priceMin: minPrice ? parseInt(minPrice) : null,
            priceMax: maxPrice ? parseInt(maxPrice) : null,
            bedrooms,
            propertyTypes
        };
        window.MobileAppConfig.onFiltersChanged();
    }

    window.closeFiltersModal();
};

window.performSearch = () => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('Search feature coming soon!', 'info');
    }
};

// Profile menu actions
window.showMyProfile = () => window.switchPage('profile');
window.showMyListings = () => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('My Listings feature coming soon!', 'info');
    }
};
window.showSavedProperties = () => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('Saved Properties feature coming soon!', 'info');
    }
};
window.showMessages = () => window.switchPage('messages');
window.showDashboard = () => window.switchPage('profile');
window.showSettings = () => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('Settings feature coming soon!', 'info');
    }
};
window.showHelp = () => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('Help & Support feature coming soon!', 'info');
    }
};
window.showPrivacyPolicy = () => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('Privacy Policy feature coming soon!', 'info');
    }
};
window.logout = async () => {
    if (window.supabase) {
        await window.supabase.auth.signOut();
    }
    if (window.MobileAppConfig) {
        window.MobileAppConfig.user.isLoggedIn = false;
        window.MobileAppConfig.user.name = 'Guest User';
        window.MobileAppConfig.user.email = 'Not logged in';
        window.MobileAppConfig.updateUI();
        window.MobileAppConfig.showToast('Logged out successfully', 'success');
    }
    window.switchPage('home');
};

// Create global instance
window.MobileAppNavigation = new MobileAppNavigation();

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.MobileAppNavigation.init();
    });
} else {
    window.MobileAppNavigation.init();
}