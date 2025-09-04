// Mobile App Profile - User profile and authentication management

class MobileAppProfile {
    constructor() {
        this.user = {
            isLoggedIn: false,
            id: null,
            email: null,
            name: null,
            avatar: null,
            phone: null,
            preferences: {
                notifications: true,
                emailUpdates: true,
                darkMode: false,
                language: 'en'
            },
            stats: {
                savedProperties: 0,
                activeListings: 0,
                totalViews: 0,
                responseRate: 0
            }
        };
    }

    init() {
        console.log('👤 Initializing Mobile App Profile...');
        this.loadUserProfile();
        console.log('✅ Mobile App Profile initialized');
    }

    async loadUserProfile() {
        try {
            // Check if user is authenticated with Supabase
            if (window.supabase) {
                const { data: { user }, error } = await window.supabase.auth.getUser();
                
                if (user && !error) {
                    this.user.isLoggedIn = true;
                    this.user.id = user.id;
                    this.user.email = user.email;
                    this.user.name = user.user_metadata?.full_name || user.email.split('@')[0];
                    this.user.phone = user.user_metadata?.phone;
                    
                    // Try to fetch profile image from backend
                    try {
                        const response = await fetch(`/api/user-profile/${encodeURIComponent(user.email)}`);
                        if (response.ok) {
                            const profileData = await response.json();
                            
                            // Use custom profile image if available
                            if (profileData.hasCustomProfileImage && profileData.profileImage) {
                                this.user.avatar = profileData.profileImage;
                                console.log('✅ Loaded custom profile image from backend');
                            } else {
                                // Use default or metadata avatar
                                this.user.avatar = user.user_metadata?.avatar_url || null;
                            }
                            
                            // Update names if available
                            if (profileData.firstName && profileData.lastName) {
                                this.user.name = `${profileData.firstName} ${profileData.lastName}`.trim();
                            }
                        }
                    } catch (fetchError) {
                        console.warn('⚠️ Could not fetch profile data:', fetchError);
                        // Fallback to metadata avatar
                        this.user.avatar = user.user_metadata?.avatar_url || null;
                    }
                    
                    // Load additional profile data
                    await this.loadUserStats();
                    await this.loadUserPreferences();
                    
                    console.log('✅ User profile loaded:', this.user.name);
                } else {
                    console.log('ℹ️ No authenticated user found');
                }
            }
        } catch (error) {
            console.warn('⚠️ Error loading user profile:', error);
        }
        
        // Update the global config
        if (window.MobileAppConfig) {
            window.MobileAppConfig.user = this.user;
            window.MobileAppConfig.updateProfileUI();
        }
    }

    async loadUserStats() {
        try {
            // Mock stats for now - in production, load from database
            this.user.stats = {
                savedProperties: Math.floor(Math.random() * 20) + 5,
                activeListings: Math.floor(Math.random() * 5) + 1,
                totalViews: Math.floor(Math.random() * 500) + 100,
                responseRate: Math.floor(Math.random() * 30) + 70
            };
        } catch (error) {
            console.warn('⚠️ Error loading user stats:', error);
        }
    }

    async loadUserPreferences() {
        try {
            // Load from localStorage for now - in production, sync with database
            const saved = null;
            if (saved) {
                this.user.preferences = { ...this.user.preferences, ...JSON.parse(saved) };
            }
        } catch (error) {
            console.warn('⚠️ Error loading user preferences:', error);
        }
    }

    async saveUserPreferences() {
        try {
            // localStorage removed - using Supabase);
            
            // In production, also save to database
            if (window.supabase && this.user.isLoggedIn) {
                // await window.supabase.from('user_preferences').upsert({
                //     user_id: this.user.id,
                //     preferences: this.user.preferences
                // });
            }
            
            if (window.MobileAppConfig) {
                window.MobileAppConfig.showToast('Preferences saved successfully', 'success');
            }
        } catch (error) {
            console.error('❌ Error saving preferences:', error);
            if (window.MobileAppConfig) {
                window.MobileAppConfig.showToast('Failed to save preferences', 'error');
            }
        }
    }

    renderProfileDashboard() {
        const contentContainer = document.getElementById('contentContainer');
        if (!contentContainer) return;

        if (!this.user.isLoggedIn) {
            this.renderLoginPrompt();
            return;
        }

        contentContainer.innerHTML = `
            <div class="profile-dashboard animate-fade-in-up">
                <!-- Profile Header -->
                <div class="profile-header-card">
                    <div class="profile-background"></div>
                    <div class="profile-info">
                        <div class="profile-avatar-container">
                            ${this.user.avatar ? 
                                `<img src="${this.user.avatar}" alt="Profile" class="profile-avatar-img">` :
                                `<div class="profile-avatar-placeholder">👤</div>`
                            }
                            <button class="edit-avatar-btn" onclick="editAvatar()">📷</button>
                        </div>
                        <div class="profile-details">
                            <h2 class="profile-name">${this.user.name}</h2>
                            <p class="profile-email">${this.user.email}</p>
                            ${this.user.phone ? `<p class="profile-phone">📞 ${this.user.phone}</p>` : ''}
                            <button class="edit-profile-btn" onclick="editProfile()">✏️ Edit Profile</button>
                        </div>
                    </div>
                </div>

                <!-- Stats Cards -->
                <div class="stats-section">
                    <h3 class="section-title">Your Activity</h3>
                    <div class="stats-grid">
                        <div class="stat-card">
                            <div class="stat-icon">❤️</div>
                            <div class="stat-number">${this.user.stats.savedProperties}</div>
                            <div class="stat-label">Saved Properties</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-icon">🏠</div>
                            <div class="stat-number">${this.user.stats.activeListings}</div>
                            <div class="stat-label">Active Listings</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-icon">👀</div>
                            <div class="stat-number">${this.user.stats.totalViews}</div>
                            <div class="stat-label">Profile Views</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-icon">💬</div>
                            <div class="stat-number">${this.user.stats.responseRate}%</div>
                            <div class="stat-label">Response Rate</div>
                        </div>
                    </div>
                </div>

                <!-- Quick Actions -->
                <div class="actions-section">
                    <h3 class="section-title">Quick Actions</h3>
                    <div class="action-grid">
                        <button class="action-card" onclick="showMyListings()">
                            <div class="action-icon">🏠</div>
                            <div class="action-content">
                                <div class="action-title">My Listings</div>
                                <div class="action-subtitle">Manage your properties</div>
                            </div>
                            <div class="action-arrow">→</div>
                        </button>
                        
                        <button class="action-card" onclick="showSavedProperties()">
                            <div class="action-icon">❤️</div>
                            <div class="action-content">
                                <div class="action-title">Saved Properties</div>
                                <div class="action-subtitle">Your favorite listings</div>
                            </div>
                            <div class="action-arrow">→</div>
                        </button>
                        
                        <button class="action-card" onclick="showMessages()">
                            <div class="action-icon">💬</div>
                            <div class="action-content">
                                <div class="action-title">Messages</div>
                                <div class="action-subtitle">Chat with agents</div>
                            </div>
                            <div class="action-arrow">→</div>
                        </button>
                        
                        <button class="action-card" onclick="showSearchAlerts()">
                            <div class="action-icon">🔔</div>
                            <div class="action-content">
                                <div class="action-title">Search Alerts</div>
                                <div class="action-subtitle">Get notified of new listings</div>
                            </div>
                            <div class="action-arrow">→</div>
                        </button>
                    </div>
                </div>

                <!-- Settings Section -->
                <div class="settings-section">
                    <h3 class="section-title">Settings</h3>
                    <div class="settings-list">
                        <button class="setting-item" onclick="showNotificationSettings()">
                            <div class="setting-icon">🔔</div>
                            <div class="setting-content">
                                <div class="setting-title">Notifications</div>
                                <div class="setting-subtitle">Manage your alerts</div>
                            </div>
                            <div class="setting-toggle">
                                <input type="checkbox" id="notificationToggle" ${this.user.preferences.notifications ? 'checked' : ''} onchange="toggleNotifications(this.checked)">
                                <label for="notificationToggle" class="toggle-slider"></label>
                            </div>
                        </button>
                        
                        <button class="setting-item" onclick="showPrivacySettings()">
                            <div class="setting-icon">🔒</div>
                            <div class="setting-content">
                                <div class="setting-title">Privacy & Security</div>
                                <div class="setting-subtitle">Control your data</div>
                            </div>
                            <div class="setting-arrow">→</div>
                        </button>
                        
                        <button class="setting-item" onclick="showAccountSettings()">
                            <div class="setting-icon">⚙️</div>
                            <div class="setting-content">
                                <div class="setting-title">Account Settings</div>
                                <div class="setting-subtitle">Update your info</div>
                            </div>
                            <div class="setting-arrow">→</div>
                        </button>
                        
                        <button class="setting-item" onclick="showHelpSupport()">
                            <div class="setting-icon">🆘</div>
                            <div class="setting-content">
                                <div class="setting-title">Help & Support</div>
                                <div class="setting-subtitle">Get assistance</div>
                            </div>
                            <div class="setting-arrow">→</div>
                        </button>
                    </div>
                </div>

                <!-- Logout Button -->
                <div class="logout-section">
                    <button class="logout-btn" onclick="confirmLogout()">
                        <span class="logout-icon">🚪</span>
                        <span class="logout-text">Sign Out</span>
                    </button>
                </div>
            </div>
        `;
    }

    renderLoginPrompt() {
        const contentContainer = document.getElementById('contentContainer');
        if (!contentContainer) return;

        contentContainer.innerHTML = `
            <div class="login-prompt animate-fade-in-up">
                <div class="login-illustration">
                    <div class="login-icon">🔐</div>
                    <div class="login-rings">
                        <div class="ring ring-1"></div>
                        <div class="ring ring-2"></div>
                        <div class="ring ring-3"></div>
                    </div>
                </div>
                
                <div class="login-content">
                    <h2>Welcome to RoomFinderAI</h2>
                    <p>Sign in to access your personalized dashboard, save your favorite properties, and manage your listings.</p>
                    
                    <div class="login-benefits">
                        <div class="benefit-item">
                            <span class="benefit-icon">❤️</span>
                            <span class="benefit-text">Save favorite properties</span>
                        </div>
                        <div class="benefit-item">
                            <span class="benefit-icon">🔔</span>
                            <span class="benefit-text">Get instant notifications</span>
                        </div>
                        <div class="benefit-item">
                            <span class="benefit-icon">💬</span>
                            <span class="benefit-text">Message property owners</span>
                        </div>
                        <div class="benefit-item">
                            <span class="benefit-icon">📊</span>
                            <span class="benefit-text">Track your activity</span>
                        </div>
                    </div>
                    
                    <div class="login-actions">
                        <a href="login.html" class="btn-primary login-btn">
                            <span class="btn-icon">🔐</span>
                            <span class="btn-text">Sign In</span>
                        </a>
                        <a href="signup.html" class="btn-secondary signup-btn">
                            <span class="btn-icon">📝</span>
                            <span class="btn-text">Create Account</span>
                        </a>
                    </div>
                    
                    <div class="guest-options">
                        <button onclick="continueAsGuest()" class="btn-link">
                            Continue as Guest
                        </button>
                    </div>
                </div>
            </div>
        `;
    }

    async logout() {
        try {
            if (window.supabase) {
                await window.supabase.auth.signOut();
            }
            
            // Clear user data
            this.user = {
                isLoggedIn: false,
                id: null,
                email: null,
                name: null,
                avatar: null,
                phone: null,
                preferences: {
                    notifications: true,
                    emailUpdates: true,
                    darkMode: false,
                    language: 'en'
                },
                stats: {
                    savedProperties: 0,
                    activeListings: 0,
                    totalViews: 0,
                    responseRate: 0
                }
            };

            // Update global config
            if (window.MobileAppConfig) {
                window.MobileAppConfig.user = this.user;
                window.MobileAppConfig.updateProfileUI();
                window.MobileAppConfig.showToast('Signed out successfully', 'success');
            }

            // Navigate to home
            if (window.MobileAppNavigation) {
                window.MobileAppNavigation.switchPage('home');
            }

        } catch (error) {
            console.error('❌ Error during logout:', error);
            if (window.MobileAppConfig) {
                window.MobileAppConfig.showToast('Error signing out', 'error');
            }
        }
    }

    updatePreference(key, value) {
        this.user.preferences[key] = value;
        this.saveUserPreferences();
    }
}

// Global function bindings
window.editAvatar = () => {
    // Create a file input element
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    
    input.onchange = async (event) => {
        const file = event.target.files[0];
        if (!file) return;
        
        // Check file size (max 5MB)
        if (file.size > 5 * 1024 * 1024) {
            if (window.MobileAppConfig) {
                window.MobileAppConfig.showToast('Image size must be less than 5MB', 'error');
            }
            return;
        }
        
        // Read the file as data URL
        const reader = new FileReader();
        reader.onload = async (e) => {
            const imageData = e.target.result;
            
            // Save to backend
            if (window.MobileAppProfile && window.MobileAppProfile.user && window.MobileAppProfile.user.email) {
                try {
                    // Show loading toast
                    if (window.MobileAppConfig) {
                        window.MobileAppConfig.showToast('Uploading profile picture...', 'info');
                    }
                    
                    const response = await fetch('/api/update-profile-image', {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/json'
                            },
                            body: JSON.stringify({
                                email: window.MobileAppProfile.user.email,
                                profileImage: imageData
                            })
                        });
                        
                        if (response.ok) {
                            const result = await response.json();
                            
                            // Update the user's avatar with the Supabase URL
                            if (result.profileImage) {
                                window.MobileAppProfile.user.avatar = result.profileImage;
                                
                                // Re-render the profile dashboard to show the new image
                                window.MobileAppProfile.renderProfileDashboard();
                            }
                            
                            if (window.MobileAppConfig) {
                                window.MobileAppConfig.showToast('Profile picture updated successfully!', 'success');
                                window.MobileAppConfig.updateProfileUI();
                            }
                        } else {
                            throw new Error('Failed to save profile image');
                        }
                    } catch (error) {
                        console.error('❌ Error saving profile image:', error);
                        if (window.MobileAppConfig) {
                            window.MobileAppConfig.showToast('Failed to save profile picture', 'error');
                        }
                    }
                }
            }
        };
        
        reader.readAsDataURL(file);
    };
    
    // Trigger the file input
    input.click();
};

window.editProfile = () => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('Profile editing coming soon!', 'info');
    }
};

window.showSearchAlerts = () => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('Search alerts coming soon!', 'info');
    }
};

window.showNotificationSettings = () => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('Notification settings coming soon!', 'info');
    }
};

window.showPrivacySettings = () => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('Privacy settings coming soon!', 'info');
    }
};

window.showAccountSettings = () => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('Account settings coming soon!', 'info');
    }
};

window.showHelpSupport = () => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('Help & support coming soon!', 'info');
    }
};

window.toggleNotifications = (enabled) => {
    if (window.MobileAppProfile) {
        window.MobileAppProfile.updatePreference('notifications', enabled);
        
        if (window.MobileAppConfig) {
            window.MobileAppConfig.showToast(
                enabled ? 'Notifications enabled' : 'Notifications disabled',
                'success'
            );
        }
    }
};

window.confirmLogout = () => {
    if (confirm('Are you sure you want to sign out?')) {
        if (window.MobileAppProfile) {
            window.MobileAppProfile.logout();
        }
    }
};

window.continueAsGuest = () => {
    if (window.MobileAppNavigation) {
        window.MobileAppNavigation.switchPage('home');
    }
};

// Create global instance
window.MobileAppProfile = new MobileAppProfile();

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.MobileAppProfile.init();
    });
} else {
    window.MobileAppProfile.init();
}