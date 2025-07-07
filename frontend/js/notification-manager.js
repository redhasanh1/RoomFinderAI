// Push Notification Manager for RoomFinderAI
class NotificationManager {
    constructor() {
        this.supported = 'Notification' in window && 'serviceWorker' in navigator;
        this.permission = this.supported ? Notification.permission : 'denied';
        this.vapidKey = null; // Will be set from server config
        this.registration = null;
        this.subscription = null;
        this.preferences = this.loadPreferences();
        
        // Notification categories
        this.categories = {
            NEW_LISTING: 'new_listing',
            PRICE_CHANGE: 'price_change',
            MESSAGE: 'message',
            VISIT_REMINDER: 'visit_reminder',
            SAVED_SEARCH: 'saved_search',
            PROPERTY_UPDATE: 'property_update'
        };
        
        console.log('🔔 Notification Manager initialized', {
            supported: this.supported,
            permission: this.permission
        });
    }

    // Initialize notification system
    async init() {
        if (!this.supported) {
            console.warn('Push notifications not supported');
            return false;
        }

        try {
            // Register service worker
            await this.registerServiceWorker();
            
            // Load VAPID key from server
            await this.loadVapidKey();
            
            // Check existing subscription
            await this.checkExistingSubscription();
            
            console.log('✅ Notification system initialized');
            return true;
        } catch (error) {
            console.error('❌ Failed to initialize notifications:', error);
            return false;
        }
    }

    // Register service worker for push notifications
    async registerServiceWorker() {
        try {
            this.registration = await navigator.serviceWorker.register('/sw.js');
            console.log('📱 Service worker registered:', this.registration);
            
            // Wait for service worker to be ready
            await navigator.serviceWorker.ready;
            
            return this.registration;
        } catch (error) {
            console.error('Failed to register service worker:', error);
            throw error;
        }
    }

    // Load VAPID key from server
    async loadVapidKey() {
        try {
            const response = await fetch('/api/vapid-key');
            const data = await response.json();
            this.vapidKey = data.vapidKey;
            console.log('🔑 VAPID key loaded');
        } catch (error) {
            console.warn('Failed to load VAPID key, using default');
            // Fallback VAPID key (in production, this should come from server)
            this.vapidKey = 'BMqFJLO3O2K9I9J8hJ9J8hJ9J8hJ9J8hJ9J8hJ9J8hJ9J8hJ9J8hJ9J8hJ9J8hJ9J8h';
        }
    }

    // Check for existing subscription
    async checkExistingSubscription() {
        if (!this.registration) return;
        
        this.subscription = await this.registration.pushManager.getSubscription();
        
        if (this.subscription) {
            console.log('📬 Existing subscription found');
            await this.updateSubscriptionOnServer(this.subscription);
        }
    }

    // Request notification permission
    async requestPermission() {
        if (!this.supported) {
            throw new Error('Notifications not supported');
        }

        if (this.permission === 'granted') {
            return true;
        }

        if (this.permission === 'denied') {
            throw new Error('Notifications denied by user');
        }

        // Show custom permission UI first
        const userWantsNotifications = await this.showPermissionDialog();
        
        if (!userWantsNotifications) {
            return false;
        }

        // Request browser permission
        const permission = await Notification.requestPermission();
        this.permission = permission;

        if (permission === 'granted') {
            console.log('✅ Notification permission granted');
            await this.subscribe();
            return true;
        } else {
            console.log('❌ Notification permission denied');
            return false;
        }
    }

    // Show custom permission dialog
    showPermissionDialog() {
        return new Promise((resolve) => {
            const dialog = document.createElement('div');
            dialog.className = 'notification-permission-dialog fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4';
            dialog.innerHTML = `
                <div class="bg-white rounded-lg p-6 max-w-sm w-full">
                    <div class="text-center">
                        <div class="mb-4">
                            <div class="mx-auto w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mb-3">
                                <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-5 5v-5zM15 17H9a2 2 0 01-2-2V9a2 2 0 012-2h6a2 2 0 012 2v6z"></path>
                                </svg>
                            </div>
                            <h3 class="text-lg font-semibold text-gray-900 mb-2">Stay Updated</h3>
                            <p class="text-gray-600 text-sm mb-4">Get instant notifications about new listings, price changes, and messages from agents.</p>
                        </div>
                        
                        <div class="space-y-2 mb-6 text-left">
                            <div class="flex items-center text-sm text-gray-700">
                                <span class="text-green-500 mr-2">✓</span>
                                New properties matching your criteria
                            </div>
                            <div class="flex items-center text-sm text-gray-700">
                                <span class="text-green-500 mr-2">✓</span>
                                Price drops on saved properties
                            </div>
                            <div class="flex items-center text-sm text-gray-700">
                                <span class="text-green-500 mr-2">✓</span>
                                Messages from landlords
                            </div>
                        </div>
                        
                        <div class="flex gap-3">
                            <button class="flex-1 px-4 py-2 text-gray-600 border border-gray-300 rounded-lg hover:bg-gray-50" onclick="this.closest('.notification-permission-dialog').dispatchEvent(new CustomEvent('deny'))">
                                Not Now
                            </button>
                            <button class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700" onclick="this.closest('.notification-permission-dialog').dispatchEvent(new CustomEvent('allow'))">
                                Enable
                            </button>
                        </div>
                    </div>
                </div>
            `;
            
            dialog.addEventListener('allow', () => {
                dialog.remove();
                resolve(true);
            });
            
            dialog.addEventListener('deny', () => {
                dialog.remove();
                resolve(false);
            });
            
            document.body.appendChild(dialog);
        });
    }

    // Subscribe to push notifications
    async subscribe() {
        if (!this.registration || !this.vapidKey) {
            throw new Error('Service worker or VAPID key not available');
        }

        try {
            this.subscription = await this.registration.pushManager.subscribe({
                userVisibleOnly: true,
                applicationServerKey: this.urlBase64ToUint8Array(this.vapidKey)
            });

            console.log('📱 Subscribed to push notifications');
            
            // Send subscription to server
            await this.updateSubscriptionOnServer(this.subscription);
            
            // Show success message
            this.showSuccessMessage('Notifications enabled! You\'ll receive updates about new listings and messages.');
            
            return this.subscription;
        } catch (error) {
            console.error('Failed to subscribe to push notifications:', error);
            throw error;
        }
    }

    // Update subscription on server
    async updateSubscriptionOnServer(subscription) {
        const currentUser = JSON.parse(localStorage.getItem('currentUser'));
        if (!currentUser) return;

        try {
            const response = await fetch('/api/push-subscription', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    subscription: subscription,
                    userEmail: currentUser.email,
                    preferences: this.preferences
                })
            });

            if (!response.ok) {
                throw new Error('Failed to update subscription on server');
            }

            console.log('✅ Subscription updated on server');
        } catch (error) {
            console.error('Failed to update subscription on server:', error);
            // Store locally for retry later
            localStorage.setItem('pendingPushSubscription', JSON.stringify(subscription));
        }
    }

    // Unsubscribe from notifications
    async unsubscribe() {
        if (!this.subscription) return;

        try {
            await this.subscription.unsubscribe();
            this.subscription = null;
            
            // Remove from server
            const currentUser = JSON.parse(localStorage.getItem('currentUser'));
            if (currentUser) {
                await fetch('/api/push-subscription', {
                    method: 'DELETE',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        userEmail: currentUser.email
                    })
                });
            }

            console.log('🔕 Unsubscribed from push notifications');
            this.showSuccessMessage('Notifications disabled');
            
        } catch (error) {
            console.error('Failed to unsubscribe:', error);
        }
    }

    // Send notification (for testing)
    sendLocalNotification(title, options = {}) {
        if (this.permission !== 'granted') return;

        const notification = new Notification(title, {
            icon: '/icons/icon-192x192.png',
            badge: '/icons/badge-72x72.png',
            ...options
        });

        // Auto-close after 5 seconds
        setTimeout(() => notification.close(), 5000);

        return notification;
    }

    // Show notification preferences
    showPreferences() {
        const modal = document.createElement('div');
        modal.className = 'notification-preferences-modal fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4';
        modal.innerHTML = `
            <div class="bg-white rounded-lg p-6 max-w-md w-full max-h-[80vh] overflow-y-auto">
                <div class="flex items-center justify-between mb-4">
                    <h3 class="text-lg font-semibold">Notification Preferences</h3>
                    <button class="close-preferences text-gray-500 hover:text-gray-700 text-2xl">×</button>
                </div>
                
                <div class="space-y-4">
                    <div class="flex items-center justify-between">
                        <div>
                            <label class="font-medium">New Listings</label>
                            <p class="text-sm text-gray-600">Properties matching your saved searches</p>
                        </div>
                        <label class="switch">
                            <input type="checkbox" id="new_listing" ${this.preferences.new_listing ? 'checked' : ''}>
                            <span class="slider"></span>
                        </label>
                    </div>
                    
                    <div class="flex items-center justify-between">
                        <div>
                            <label class="font-medium">Price Changes</label>
                            <p class="text-sm text-gray-600">Price drops on saved properties</p>
                        </div>
                        <label class="switch">
                            <input type="checkbox" id="price_change" ${this.preferences.price_change ? 'checked' : ''}>
                            <span class="slider"></span>
                        </label>
                    </div>
                    
                    <div class="flex items-center justify-between">
                        <div>
                            <label class="font-medium">Messages</label>
                            <p class="text-sm text-gray-600">New messages from agents</p>
                        </div>
                        <label class="switch">
                            <input type="checkbox" id="message" ${this.preferences.message ? 'checked' : ''}>
                            <span class="slider"></span>
                        </label>
                    </div>
                    
                    <div class="flex items-center justify-between">
                        <div>
                            <label class="font-medium">Visit Reminders</label>
                            <p class="text-sm text-gray-600">Scheduled property visit reminders</p>
                        </div>
                        <label class="switch">
                            <input type="checkbox" id="visit_reminder" ${this.preferences.visit_reminder ? 'checked' : ''}>
                            <span class="slider"></span>
                        </label>
                    </div>
                    
                    <div class="flex items-center justify-between">
                        <div>
                            <label class="font-medium">Property Updates</label>
                            <p class="text-sm text-gray-600">Updates to saved properties</p>
                        </div>
                        <label class="switch">
                            <input type="checkbox" id="property_update" ${this.preferences.property_update ? 'checked' : ''}>
                            <span class="slider"></span>
                        </label>
                    </div>
                </div>
                
                <div class="mt-6 flex gap-3">
                    <button class="flex-1 px-4 py-2 text-gray-600 border border-gray-300 rounded-lg hover:bg-gray-50 close-preferences">
                        Cancel
                    </button>
                    <button class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 save-preferences">
                        Save
                    </button>
                </div>
                
                ${this.subscription ? `
                    <div class="mt-4 pt-4 border-t border-gray-200">
                        <button class="w-full px-4 py-2 text-red-600 border border-red-300 rounded-lg hover:bg-red-50 unsubscribe-btn">
                            Disable All Notifications
                        </button>
                    </div>
                ` : ''}
            </div>
        `;
        
        document.body.appendChild(modal);
        
        // Event listeners
        modal.addEventListener('click', (e) => {
            if (e.target.classList.contains('close-preferences') || e.target === modal) {
                modal.remove();
            } else if (e.target.classList.contains('save-preferences')) {
                this.savePreferences(modal);
                modal.remove();
            } else if (e.target.classList.contains('unsubscribe-btn')) {
                this.unsubscribe();
                modal.remove();
            }
        });
    }

    // Save notification preferences
    savePreferences(modal) {
        const checkboxes = modal.querySelectorAll('input[type="checkbox"]');
        checkboxes.forEach(checkbox => {
            this.preferences[checkbox.id] = checkbox.checked;
        });
        
        localStorage.setItem('notificationPreferences', JSON.stringify(this.preferences));
        
        // Update server
        this.updateSubscriptionOnServer(this.subscription);
        
        this.showSuccessMessage('Notification preferences saved');
    }

    // Load preferences from localStorage
    loadPreferences() {
        const saved = localStorage.getItem('notificationPreferences');
        return saved ? JSON.parse(saved) : {
            new_listing: true,
            price_change: true,
            message: true,
            visit_reminder: true,
            property_update: true
        };
    }

    // Utility functions
    urlBase64ToUint8Array(base64String) {
        const padding = '='.repeat((4 - base64String.length % 4) % 4);
        const base64 = (base64String + padding)
            .replace(/-/g, '+')
            .replace(/_/g, '/');

        const rawData = window.atob(base64);
        const outputArray = new Uint8Array(rawData.length);

        for (let i = 0; i < rawData.length; ++i) {
            outputArray[i] = rawData.charCodeAt(i);
        }
        return outputArray;
    }

    showSuccessMessage(message) {
        const toast = document.createElement('div');
        toast.className = 'notification-toast fixed top-4 right-4 bg-green-600 text-white px-4 py-3 rounded-lg shadow-lg z-50 transform translate-x-full transition-transform';
        toast.innerHTML = `
            <div class="flex items-center gap-2">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                </svg>
                <span>${message}</span>
            </div>
        `;
        
        document.body.appendChild(toast);
        
        // Animate in
        setTimeout(() => {
            toast.style.transform = 'translateX(0)';
        }, 100);
        
        // Animate out and remove
        setTimeout(() => {
            toast.style.transform = 'translateX(100%)';
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }

    // Check if notifications are available and enabled
    isEnabled() {
        return this.permission === 'granted' && this.subscription;
    }

    // Get notification status
    getStatus() {
        return {
            supported: this.supported,
            permission: this.permission,
            subscribed: !!this.subscription,
            preferences: this.preferences
        };
    }
}

// Initialize notification manager
window.notificationManager = new NotificationManager();