// Environment Configuration for Web and Mobile
window.AppConfig = {
    // Detect if running in Capacitor (mobile app)
    isMobile: !!window.Capacitor,
    
    // Detect if running as PWA
    isPWA: window.matchMedia('(display-mode: standalone)').matches,
    
    // Get the current environment
    getEnvironment: function() {
        if (this.isMobile) return 'mobile';
        if (this.isPWA) return 'pwa';
        return 'web';
    },
    
    // Get base URL based on environment
    getBaseUrl: function() {
        if (this.isMobile) {
            // For mobile app, use relative paths
            return './';
        }
        
        // For web, use current domain or your production URL
        return window.location.origin + '/';
    },
    
    // Get API URL based on environment
    getApiUrl: function() {
        if (this.isMobile) {
            // For mobile app, use your production API
            return 'https://roomfinderai-production.up.railway.app/api/';
        }
        
        // For web, use relative or full API URL
        return '/api/';
    },
    
    // Initialize app based on environment
    initialize: function() {
        console.log('App Environment:', this.getEnvironment());
        console.log('Base URL:', this.getBaseUrl());
        console.log('API URL:', this.getApiUrl());
        
        // Add environment class to body
        document.body.classList.add('env-' + this.getEnvironment());
        
        // Mobile-specific initialization
        if (this.isMobile) {
            this.initializeMobile();
        }
        
        // Web-specific initialization
        if (!this.isMobile) {
            this.initializeWeb();
        }
    },
    
    // Mobile-specific initialization
    initializeMobile: function() {
        console.log('Initializing mobile app...');
        
        // Hide elements that shouldn't be shown in mobile
        const webOnlyElements = document.querySelectorAll('.web-only');
        webOnlyElements.forEach(el => el.style.display = 'none');
        
        // Show mobile-specific elements
        const mobileOnlyElements = document.querySelectorAll('.mobile-only');
        mobileOnlyElements.forEach(el => el.style.display = 'block');
        
        // Add mobile-specific event listeners
        this.addMobileEventListeners();
    },
    
    // Web-specific initialization
    initializeWeb: function() {
        console.log('Initializing web app...');
        
        // Hide mobile-specific elements
        const mobileOnlyElements = document.querySelectorAll('.mobile-only');
        mobileOnlyElements.forEach(el => el.style.display = 'none');
        
        // Show web-only elements
        const webOnlyElements = document.querySelectorAll('.web-only');
        webOnlyElements.forEach(el => el.style.display = 'block');
    },
    
    // Add mobile-specific event listeners
    addMobileEventListeners: function() {
        // Handle back button
        document.addEventListener('backbutton', function() {
            if (window.history.length > 1) {
                window.history.back();
            } else {
                // Close app or go to home
                if (window.Capacitor && window.Capacitor.Plugins.App) {
                    window.Capacitor.Plugins.App.exitApp();
                }
            }
        });
        
        // Handle network status
        if (window.Capacitor && window.Capacitor.Plugins.Network) {
            window.Capacitor.Plugins.Network.addListener('networkStatusChange', (status) => {
                console.log('Network status changed:', status);
                if (!status.connected) {
                    this.showOfflineMessage();
                } else {
                    this.hideOfflineMessage();
                }
            });
        }
    },
    
    // Show offline message
    showOfflineMessage: function() {
        let offlineDiv = document.getElementById('offline-message');
        if (!offlineDiv) {
            offlineDiv = document.createElement('div');
            offlineDiv.id = 'offline-message';
            offlineDiv.style.cssText = `
                position: fixed;
                top: 0;
                left: 0;
                right: 0;
                background: #f44336;
                color: white;
                padding: 10px;
                text-align: center;
                z-index: 10000;
                font-size: 14px;
            `;
            offlineDiv.textContent = 'You are offline. Some features may not work.';
            document.body.appendChild(offlineDiv);
        }
        offlineDiv.style.display = 'block';
    },
    
    // Hide offline message
    hideOfflineMessage: function() {
        const offlineDiv = document.getElementById('offline-message');
        if (offlineDiv) {
            offlineDiv.style.display = 'none';
        }
    },
    
    // Safe navigation function
    navigate: function(url) {
        if (this.isMobile) {
            // For mobile, use Capacitor's navigation
            window.location.href = url;
        } else {
            // For web, use standard navigation
            if (url.startsWith('http')) {
                window.location.href = url;
            } else {
                window.location.href = this.getBaseUrl() + url;
            }
        }
    },
    
    // Show loading indicator
    showLoading: function() {
        let loadingDiv = document.getElementById('global-loading');
        if (!loadingDiv) {
            loadingDiv = document.createElement('div');
            loadingDiv.id = 'global-loading';
            loadingDiv.innerHTML = `
                <div style="position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 9999; display: flex; align-items: center; justify-content: center;">
                    <div style="background: white; padding: 20px; border-radius: 10px; text-align: center;">
                        <div style="width: 40px; height: 40px; border: 4px solid #f3f3f3; border-top: 4px solid #667eea; border-radius: 50%; animation: spin 1s linear infinite; margin: 0 auto 10px;"></div>
                        <p>Loading...</p>
                    </div>
                </div>
            `;
            document.body.appendChild(loadingDiv);
        }
        loadingDiv.style.display = 'block';
    },
    
    // Hide loading indicator
    hideLoading: function() {
        const loadingDiv = document.getElementById('global-loading');
        if (loadingDiv) {
            loadingDiv.style.display = 'none';
        }
    }
};

// Auto-initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    window.AppConfig.initialize();
});

// Add spin animation CSS
const style = document.createElement('style');
style.textContent = `
    @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
    }
`;
document.head.appendChild(style);