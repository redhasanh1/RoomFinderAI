/**
 * Mobile Utilities Module
 * Mobile-specific helper functions and utilities
 */

class MobileUtils {
    constructor() {
        this.isInitialized = false;
        this.viewport = null;
        this.orientation = null;
        this.touchStartX = 0;
        this.touchStartY = 0;
        
        console.log('📱 Mobile Utils initialized');
    }
    
    /**
     * Initialize mobile utilities
     */
    initialize() {
        try {
            this.setupViewportMeta();
            this.detectDevice();
            this.setupOrientationHandling();
            this.setupTouchHandling();
            this.setupSwipeDetection();
            
            this.isInitialized = true;
            console.log('✅ Mobile utilities initialized');
            return true;
        } catch (error) {
            console.error('❌ Mobile utils initialization failed:', error);
            return false;
        }
    }
    
    /**
     * Setup viewport meta tag if not present
     */
    setupViewportMeta() {
        let viewport = document.querySelector('meta[name="viewport"]');
        
        if (!viewport) {
            viewport = document.createElement('meta');
            viewport.name = 'viewport';
            viewport.content = 'width=device-width, initial-scale=1.0, user-scalable=no';
            document.head.appendChild(viewport);
            console.log('📱 Viewport meta tag added');
        }
        
        this.viewport = viewport;
    }
    
    /**
     * Detect device capabilities
     */
    detectDevice() {
        this.device = {
            isMobile: this.isMobile(),
            isTablet: this.isTablet(),
            isDesktop: this.isDesktop(),
            isTouchDevice: this.isTouchDevice(),
            isIOS: this.isIOS(),
            isAndroid: this.isAndroid(),
            hasNotchSupport: this.hasNotchSupport(),
            supportsServiceWorker: 'serviceWorker' in navigator,
            supportsWebGL: this.supportsWebGL(),
            pixelRatio: window.devicePixelRatio || 1
        };
        
        // Add CSS classes for device detection
        document.documentElement.classList.add(
            this.device.isMobile ? 'mobile' : 'not-mobile',
            this.device.isTablet ? 'tablet' : 'not-tablet',
            this.device.isDesktop ? 'desktop' : 'not-desktop',
            this.device.isTouchDevice ? 'touch' : 'no-touch',
            this.device.isIOS ? 'ios' : 'not-ios',
            this.device.isAndroid ? 'android' : 'not-android'
        );
        
        console.log('📱 Device detected:', this.device);
    }
    
    /**
     * Setup orientation change handling
     */
    setupOrientationHandling() {
        const handleOrientationChange = () => {
            this.orientation = this.getOrientation();
            
            // Add CSS class for orientation
            document.documentElement.classList.remove('portrait', 'landscape');
            document.documentElement.classList.add(this.orientation);
            
            // Trigger custom event
            document.dispatchEvent(new CustomEvent('orientationChanged', {
                detail: { orientation: this.orientation }
            }));
            
            // Fix viewport height on mobile after orientation change
            if (this.device.isMobile) {
                setTimeout(() => {
                    this.fixViewportHeight();
                }, 100);
            }
        };
        
        // Listen for orientation changes
        window.addEventListener('orientationchange', handleOrientationChange);
        window.addEventListener('resize', handleOrientationChange);
        
        // Initial orientation
        handleOrientationChange();
    }
    
    /**
     * Setup touch handling
     */
    setupTouchHandling() {
        if (!this.device.isTouchDevice) return;
        
        // Prevent double-tap zoom on buttons
        const preventDoubleTapZoom = (e) => {
            if (e.target.matches('button, input[type="button"], input[type="submit"], .btn')) {
                e.preventDefault();
            }
        };
        
        document.addEventListener('touchend', preventDoubleTapZoom, { passive: false });
        
        // Prevent pull-to-refresh on iOS
        if (this.device.isIOS) {
            document.addEventListener('touchstart', (e) => {
                if (e.touches.length > 1) {
                    e.preventDefault();
                }
            }, { passive: false });
            
            let lastTouchEnd = 0;
            document.addEventListener('touchend', (e) => {
                const now = (new Date()).getTime();
                if (now - lastTouchEnd <= 300) {
                    e.preventDefault();
                }
                lastTouchEnd = now;
            }, { passive: false });
        }
    }
    
    /**
     * Setup swipe detection
     */
    setupSwipeDetection() {
        if (!this.device.isTouchDevice) return;
        
        document.addEventListener('touchstart', (e) => {
            this.touchStartX = e.changedTouches[0].screenX;
            this.touchStartY = e.changedTouches[0].screenY;
        }, { passive: true });
        
        document.addEventListener('touchend', (e) => {
            const touchEndX = e.changedTouches[0].screenX;
            const touchEndY = e.changedTouches[0].screenY;
            
            this.handleSwipe(
                this.touchStartX,
                this.touchStartY,
                touchEndX,
                touchEndY,
                e.target
            );
        }, { passive: true });
    }
    
    /**
     * Handle swipe gestures
     */
    handleSwipe(startX, startY, endX, endY, target) {
        const diffX = startX - endX;
        const diffY = startY - endY;
        const minSwipeDistance = 50;
        
        // Determine if it's a valid swipe
        if (Math.abs(diffX) > Math.abs(diffY)) {
            // Horizontal swipe
            if (Math.abs(diffX) > minSwipeDistance) {
                const direction = diffX > 0 ? 'left' : 'right';
                this.triggerSwipeEvent(target, direction, { diffX, diffY });
            }
        } else {
            // Vertical swipe
            if (Math.abs(diffY) > minSwipeDistance) {
                const direction = diffY > 0 ? 'up' : 'down';
                this.triggerSwipeEvent(target, direction, { diffX, diffY });
            }
        }
    }
    
    /**
     * Trigger swipe event
     */
    triggerSwipeEvent(target, direction, data) {
        const event = new CustomEvent('swipe', {
            detail: { direction, data, target }
        });
        
        target.dispatchEvent(event);
        document.dispatchEvent(event);
    }
    
    /**
     * Fix viewport height on mobile browsers
     */
    fixViewportHeight() {
        // Set CSS custom property for real viewport height
        const vh = window.innerHeight * 0.01;
        document.documentElement.style.setProperty('--vh', `${vh}px`);
        
        // Set full height custom property
        document.documentElement.style.setProperty('--full-height', `${window.innerHeight}px`);
    }
    
    /**
     * Check if device is mobile
     */
    isMobile() {
        return window.innerWidth <= 768 || /Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
    }
    
    /**
     * Check if device is tablet
     */
    isTablet() {
        return window.innerWidth > 768 && window.innerWidth <= 1024 && this.isTouchDevice();
    }
    
    /**
     * Check if device is desktop
     */
    isDesktop() {
        return window.innerWidth > 1024 && !this.isTouchDevice();
    }
    
    /**
     * Check if device supports touch
     */
    isTouchDevice() {
        return 'ontouchstart' in window || navigator.maxTouchPoints > 0 || navigator.msMaxTouchPoints > 0;
    }
    
    /**
     * Check if device is iOS
     */
    isIOS() {
        return /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;
    }
    
    /**
     * Check if device is Android
     */
    isAndroid() {
        return /Android/.test(navigator.userAgent);
    }
    
    /**
     * Check if device has notch support (iPhone X and newer)
     */
    hasNotchSupport() {
        const cssEnv = CSS.supports('padding: env(safe-area-inset-top)');
        const isIPhoneX = this.isIOS() && screen.height >= 812;
        return cssEnv || isIPhoneX;
    }
    
    /**
     * Check WebGL support
     */
    supportsWebGL() {
        try {
            const canvas = document.createElement('canvas');
            return !!(window.WebGLRenderingContext && canvas.getContext('webgl'));
        } catch (e) {
            return false;
        }
    }
    
    /**
     * Get current orientation
     */
    getOrientation() {
        return window.innerHeight > window.innerWidth ? 'portrait' : 'landscape';
    }
    
    /**
     * Get screen dimensions
     */
    getScreenDimensions() {
        return {
            width: window.innerWidth,
            height: window.innerHeight,
            availWidth: screen.availWidth,
            availHeight: screen.availHeight,
            pixelRatio: window.devicePixelRatio || 1
        };
    }
    
    /**
     * Vibrate device (if supported)
     */
    vibrate(pattern = [200]) {
        if ('vibrate' in navigator) {
            navigator.vibrate(pattern);
            return true;
        }
        return false;
    }
    
    /**
     * Share content using Web Share API
     */
    async share(data) {
        if (navigator.share) {
            try {
                await navigator.share(data);
                return true;
            } catch (error) {
                console.error('Share failed:', error);
                return false;
            }
        }
        
        // Fallback to clipboard if share not available
        if (data.url) {
            return this.copyToClipboard(data.url);
        }
        
        return false;
    }
    
    /**
     * Copy text to clipboard
     */
    async copyToClipboard(text) {
        if (navigator.clipboard) {
            try {
                await navigator.clipboard.writeText(text);
                return true;
            } catch (error) {
                console.error('Clipboard write failed:', error);
                return false;
            }
        }
        
        // Fallback for older browsers
        return this.fallbackCopyToClipboard(text);
    }
    
    /**
     * Fallback clipboard copy
     */
    fallbackCopyToClipboard(text) {
        const textArea = document.createElement('textarea');
        textArea.value = text;
        textArea.style.position = 'fixed';
        textArea.style.left = '-999999px';
        textArea.style.top = '-999999px';
        document.body.appendChild(textArea);
        
        textArea.focus();
        textArea.select();
        
        try {
            const successful = document.execCommand('copy');
            document.body.removeChild(textArea);
            return successful;
        } catch (error) {
            document.body.removeChild(textArea);
            console.error('Fallback clipboard copy failed:', error);
            return false;
        }
    }
    
    /**
     * Install PWA prompt
     */
    setupPWAInstall() {
        let deferredPrompt;
        
        window.addEventListener('beforeinstallprompt', (e) => {
            e.preventDefault();
            deferredPrompt = e;
            
            // Show install button
            document.dispatchEvent(new CustomEvent('pwaInstallAvailable', {
                detail: { prompt: deferredPrompt }
            }));
        });
        
        // Handle install button click
        document.addEventListener('pwaInstallClick', async () => {
            if (deferredPrompt) {
                deferredPrompt.prompt();
                const { outcome } = await deferredPrompt.userChoice;
                
                if (outcome === 'accepted') {
                    console.log('📱 PWA installed');
                } else {
                    console.log('📱 PWA installation declined');
                }
                
                deferredPrompt = null;
            }
        });
        
        // Track successful installation
        window.addEventListener('appinstalled', () => {
            console.log('📱 PWA installed successfully');
            document.dispatchEvent(new CustomEvent('pwaInstalled'));
        });
    }
    
    /**
     * Add touch feedback to elements
     */
    addTouchFeedback(selector) {
        const elements = document.querySelectorAll(selector);
        
        elements.forEach(element => {
            element.addEventListener('touchstart', () => {
                element.classList.add('touch-active');
            }, { passive: true });
            
            element.addEventListener('touchend', () => {
                setTimeout(() => {
                    element.classList.remove('touch-active');
                }, 150);
            }, { passive: true });
            
            element.addEventListener('touchcancel', () => {
                element.classList.remove('touch-active');
            }, { passive: true });
        });
    }
    
    /**
     * Prevent iOS bounce scroll
     */
    preventBounceScroll() {
        if (!this.device.isIOS) return;
        
        document.addEventListener('touchmove', (e) => {
            const target = e.target.closest('[data-scroll]');
            if (!target) {
                e.preventDefault();
            }
        }, { passive: false });
    }
    
    /**
     * Setup safe area insets for notched devices
     */
    setupSafeAreaInsets() {
        if (this.hasNotchSupport()) {
            document.documentElement.classList.add('has-notch');
            
            // Add CSS custom properties for safe areas
            const style = document.createElement('style');
            style.textContent = `
                :root {
                    --safe-area-inset-top: env(safe-area-inset-top, 0px);
                    --safe-area-inset-right: env(safe-area-inset-right, 0px);
                    --safe-area-inset-bottom: env(safe-area-inset-bottom, 0px);
                    --safe-area-inset-left: env(safe-area-inset-left, 0px);
                }
            `;
            document.head.appendChild(style);
        }
    }
    
    /**
     * Network information
     */
    getNetworkInfo() {
        const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
        
        if (connection) {
            return {
                effectiveType: connection.effectiveType,
                downlink: connection.downlink,
                rtt: connection.rtt,
                saveData: connection.saveData
            };
        }
        
        return null;
    }
    
    /**
     * Battery information
     */
    async getBatteryInfo() {
        if ('getBattery' in navigator) {
            try {
                const battery = await navigator.getBattery();
                return {
                    charging: battery.charging,
                    level: battery.level,
                    chargingTime: battery.chargingTime,
                    dischargingTime: battery.dischargingTime
                };
            } catch (error) {
                console.error('Battery API error:', error);
                return null;
            }
        }
        
        return null;
    }
    
    /**
     * Request device motion permission (iOS 13+)
     */
    async requestMotionPermission() {
        if (typeof DeviceMotionEvent !== 'undefined' && typeof DeviceMotionEvent.requestPermission === 'function') {
            try {
                const permission = await DeviceMotionEvent.requestPermission();
                return permission === 'granted';
            } catch (error) {
                console.error('Motion permission error:', error);
                return false;
            }
        }
        
        return true; // Assume granted for older browsers
    }
    
    /**
     * Cleanup
     */
    cleanup() {
        this.isInitialized = false;
        console.log('🧹 Mobile utils cleaned up');
    }
}

// Global mobile utils instance
let globalMobileUtils = null;

/**
 * Initialize mobile utilities (backward compatibility)
 */
function initializeMobileUtils() {
    if (!globalMobileUtils) {
        globalMobileUtils = new MobileUtils();
    }
    
    return globalMobileUtils.initialize();
}

/**
 * Get device info (backward compatibility)
 */
function getDeviceInfo() {
    return globalMobileUtils?.device || {};
}

/**
 * Check if mobile (backward compatibility)
 */
function isMobile() {
    return globalMobileUtils?.device?.isMobile || window.innerWidth <= 768;
}

/**
 * Fix viewport height (backward compatibility)
 */
function fixViewportHeight() {
    if (globalMobileUtils) {
        globalMobileUtils.fixViewportHeight();
    }
}

// Export for ES6 modules
export {
    MobileUtils,
    initializeMobileUtils,
    getDeviceInfo,
    isMobile,
    fixViewportHeight
};

// Export to window for backward compatibility
window.MobileUtils = MobileUtils;
window.initializeMobileUtils = initializeMobileUtils;
window.getDeviceInfo = getDeviceInfo;
window.isMobile = isMobile;
window.fixViewportHeight = fixViewportHeight;
window.globalMobileUtils = () => globalMobileUtils;