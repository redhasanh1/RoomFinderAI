/**
 * Mobile Authentication Fix for Android
 * Fixes form submission and API URL issues in Capacitor
 */

(function() {
    console.log('🔧 Mobile Auth Fix Loading...');
    
    // Get the actual API URL for your backend
    function getApiUrl() {
        // Check if we're in Capacitor/mobile environment
        if (window.Capacitor || window.webkit?.messageHandlers) {
            // Use your production backend URL here
            // This should point to your deployed backend (Railway, Heroku, etc.)
            return 'https://roomfinderai-production.up.railway.app';
        }
        // For web, use relative URL
        return '';
    }
    
    // Fix all fetch requests to use absolute URLs on mobile
    function fixFetchUrl(url) {
        if (!url.startsWith('http') && (window.Capacitor || window.webkit?.messageHandlers)) {
            return getApiUrl() + url;
        }
        return url;
    }
    
    // Override the native fetch to automatically fix URLs
    const originalFetch = window.fetch;
    window.fetch = function(url, options) {
        const fixedUrl = fixFetchUrl(url);
        console.log('📡 Fetch request:', url, '→', fixedUrl);
        return originalFetch(fixedUrl, options);
    };
    
    // Wait for DOM to be ready
    document.addEventListener('DOMContentLoaded', function() {
        console.log('🔧 Applying mobile auth fixes...');
        
        // Fix form submissions
        const forms = document.querySelectorAll('form');
        forms.forEach(form => {
            // Remove any existing listeners to prevent duplicates
            const newForm = form.cloneNode(true);
            form.parentNode.replaceChild(newForm, form);
            
            // Add our fixed listener
            newForm.addEventListener('submit', function(e) {
                console.log('📝 Form submission intercepted');
                // Let the original handler run, but our fetch override will fix the URL
            });
        });
        
        // Fix any buttons that might use onclick
        const buttons = document.querySelectorAll('button[type="submit"], button[onclick]');
        buttons.forEach(button => {
            console.log('🔘 Found button:', button.textContent);
            
            // Ensure buttons are clickable on mobile
            button.style.cursor = 'pointer';
            button.style.webkitTapHighlightColor = 'rgba(0,0,0,0.1)';
            
            // Add touch feedback
            button.addEventListener('touchstart', function() {
                this.style.opacity = '0.7';
            });
            
            button.addEventListener('touchend', function() {
                this.style.opacity = '1';
            });
        });
        
        // Fix environment config
        if (window.AppConfig) {
            const originalGetApiUrl = window.AppConfig.getApiUrl;
            window.AppConfig.getApiUrl = function() {
                if (this.isMobile) {
                    return getApiUrl() + '/api/';
                }
                return originalGetApiUrl.call(this);
            };
            console.log('✅ AppConfig API URL fixed:', window.AppConfig.getApiUrl());
        }
        
        // Add visual feedback for mobile taps
        document.addEventListener('touchstart', function(e) {
            if (e.target.tagName === 'BUTTON' || e.target.tagName === 'A') {
                e.target.style.transform = 'scale(0.95)';
            }
        });
        
        document.addEventListener('touchend', function(e) {
            if (e.target.tagName === 'BUTTON' || e.target.tagName === 'A') {
                setTimeout(() => {
                    e.target.style.transform = 'scale(1)';
                }, 100);
            }
        });
        
        console.log('✅ Mobile auth fixes applied');
    });
    
    // Also apply fixes when Capacitor is ready
    if (window.Capacitor) {
        document.addEventListener('deviceready', function() {
            console.log('📱 Device ready - reapplying fixes');
            // Re-run initialization in case DOM changed
            document.dispatchEvent(new Event('DOMContentLoaded'));
        });
    }
})();