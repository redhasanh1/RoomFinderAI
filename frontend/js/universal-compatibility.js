// Universal Compatibility Script for Web, Local, and Android
(function() {
    'use strict';
    
    // Global compatibility object
    window.UniversalApp = {
        isAndroid: !!window.Capacitor,
        isLocal: window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1',
        isProduction: !window.location.hostname.includes('localhost') && !window.location.hostname.includes('127.0.0.1'),
        
        // Initialize the app
        init: function() {
            console.log('🚀 Initializing Universal App...');
            console.log('Environment:', this.getEnvironment());
            
            this.setupErrorHandling();
            this.setupNetworkHandling();
            this.setupCompatibilityFixes();
            this.setupPerformanceOptimizations();
            
            // Environment-specific initialization
            if (this.isAndroid) {
                this.initAndroid();
            } else if (this.isLocal) {
                this.initLocal();
            } else {
                this.initProduction();
            }
            
            console.log('✅ Universal App initialized successfully');
        },
        
        getEnvironment: function() {
            if (this.isAndroid) return 'Android App';
            if (this.isLocal) return 'Local Development';
            return 'Production Web';
        },
        
        // Setup global error handling
        setupErrorHandling: function() {
            window.addEventListener('error', (e) => {
                console.error('Global Error:', e.error);
                this.showUserFriendlyError('Something went wrong. Please try again.');
            });
            
            window.addEventListener('unhandledrejection', (e) => {
                console.error('Unhandled Promise Rejection:', e.reason);
                this.showUserFriendlyError('Network error. Please check your connection.');
            });
        },
        
        // Setup network handling
        setupNetworkHandling: function() {
            // Online/offline detection
            window.addEventListener('online', () => {
                this.hideOfflineMessage();
                console.log('🌐 Back online');
            });
            
            window.addEventListener('offline', () => {
                this.showOfflineMessage();
                console.log('📵 Gone offline');
            });
            
            // Initial network check
            if (!navigator.onLine) {
                this.showOfflineMessage();
            }
        },
        
        // Setup compatibility fixes
        setupCompatibilityFixes: function() {
            // Fix viewport on mobile
            if (window.innerWidth <= 768) {
                this.fixMobileViewport();
            }
            
            // Fix touch events
            this.setupTouchEvents();
            
            // Fix form inputs
            this.fixFormInputs();
            
            // Fix image loading
            this.setupLazyLoading();
        },
        
        // Setup performance optimizations
        setupPerformanceOptimizations: function() {
            // Preload critical resources
            this.preloadCriticalResources();
            
            // Setup intersection observer for animations
            this.setupIntersectionObserver();
            
            // Debounce scroll events
            this.setupScrollOptimization();
        },
        
        // Android-specific initialization
        initAndroid: function() {
            console.log('📱 Initializing Android-specific features...');
            
            // Setup hardware back button
            document.addEventListener('backbutton', this.handleBackButton.bind(this));
            
            // Setup status bar
            if (window.Capacitor?.Plugins?.StatusBar) {
                window.Capacitor.Plugins.StatusBar.setBackgroundColor({ color: '#667eea' });
            }
            
            // Setup splash screen
            if (window.Capacitor?.Plugins?.SplashScreen) {
                setTimeout(() => {
                    window.Capacitor.Plugins.SplashScreen.hide();
                }, 1000);
            }
            
            // Add Android-specific styles
            document.body.classList.add('platform-android');
        },
        
        // Local development initialization
        initLocal: function() {
            console.log('🔧 Initializing local development features...');
            
            // Add development tools
            this.addDevelopmentTools();
            
            // Setup hot reload detection
            this.setupHotReload();
            
            document.body.classList.add('platform-local');
        },
        
        // Production initialization
        initProduction: function() {
            console.log('🌍 Initializing production features...');
            
            // Setup analytics (if needed)
            this.setupAnalytics();
            
            // Setup service worker
            this.setupServiceWorker();
            
            document.body.classList.add('platform-production');
        },
        
        // Utility functions
        fixMobileViewport: function() {
            const viewport = document.querySelector('meta[name="viewport"]');
            if (viewport) {
                viewport.setAttribute('content', 
                    'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover'
                );
            }
        },
        
        setupTouchEvents: function() {
            // Add touch feedback to buttons
            const buttons = document.querySelectorAll('button, .btn, [role="button"]');
            buttons.forEach(button => {
                button.addEventListener('touchstart', function() {
                    this.style.transform = 'scale(0.98)';
                });
                
                button.addEventListener('touchend', function() {
                    this.style.transform = 'scale(1)';
                });
            });
        },
        
        fixFormInputs: function() {
            // Prevent zoom on input focus (iOS/Android)
            const inputs = document.querySelectorAll('input, textarea, select');
            inputs.forEach(input => {
                if (input.type !== 'range') {
                    const fontSize = window.getComputedStyle(input).fontSize;
                    if (parseInt(fontSize) < 16) {
                        input.style.fontSize = '16px';
                    }
                }
            });
        },
        
        setupLazyLoading: function() {
            const images = document.querySelectorAll('img[data-src]');
            const imageObserver = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        const img = entry.target;
                        img.src = img.dataset.src;
                        img.removeAttribute('data-src');
                        imageObserver.unobserve(img);
                    }
                });
            });
            
            images.forEach(img => imageObserver.observe(img));
        },
        
        preloadCriticalResources: function() {
            const criticalCSS = [
                'css/mobile-android.css'
            ];
            
            criticalCSS.forEach(href => {
                const link = document.createElement('link');
                link.rel = 'preload';
                link.as = 'style';
                link.href = href;
                document.head.appendChild(link);
            });
        },
        
        setupIntersectionObserver: function() {
            const animatedElements = document.querySelectorAll('.animate-on-scroll');
            const animationObserver = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        entry.target.classList.add('animated');
                    }
                });
            });
            
            animatedElements.forEach(el => animationObserver.observe(el));
        },
        
        setupScrollOptimization: function() {
            let ticking = false;
            
            function updateScrollPosition() {
                // Scroll-based animations
                const scrolled = window.pageYOffset;
                const rate = scrolled * -0.5;
                
                // Update parallax elements
                const parallaxElements = document.querySelectorAll('.parallax');
                parallaxElements.forEach(el => {
                    el.style.transform = `translateY(${rate}px)`;
                });
                
                ticking = false;
            }
            
            window.addEventListener('scroll', () => {
                if (!ticking) {
                    requestAnimationFrame(updateScrollPosition);
                    ticking = true;
                }
            });
        },
        
        handleBackButton: function() {
            if (window.history.length > 1) {
                window.history.back();
            } else {
                if (window.Capacitor?.Plugins?.App) {
                    window.Capacitor.Plugins.App.exitApp();
                }
            }
        },
        
        addDevelopmentTools: function() {
            // Add environment indicator
            const indicator = document.createElement('div');
            indicator.style.cssText = `
                position: fixed;
                top: 0;
                right: 0;
                background: #ff6b6b;
                color: white;
                padding: 5px 10px;
                font-size: 12px;
                z-index: 10000;
                border-radius: 0 0 0 5px;
            `;
            indicator.textContent = 'DEV';
            document.body.appendChild(indicator);
        },
        
        setupHotReload: function() {
            // Simple hot reload detection
            let lastModified = document.lastModified;
            setInterval(() => {
                fetch(window.location.href, { cache: 'no-cache' })
                    .then(response => response.text())
                    .then(() => {
                        // Page still exists, check for changes
                        if (document.lastModified !== lastModified) {
                            console.log('🔄 Page updated, reloading...');
                            window.location.reload();
                        }
                    })
                    .catch(() => {
                        // Ignore network errors
                    });
            }, 5000);
        },
        
        setupAnalytics: function() {
            // Placeholder for analytics setup
            console.log('📊 Analytics initialized');
        },
        
        setupServiceWorker: function() {
            if ('serviceWorker' in navigator) {
                navigator.serviceWorker.register('/sw.js')
                    .then(registration => {
                        console.log('📋 Service Worker registered:', registration);
                    })
                    .catch(error => {
                        console.log('❌ Service Worker registration failed:', error);
                    });
            }
        },
        
        // User feedback functions
        showOfflineMessage: function() {
            this.showMessage('You are offline. Some features may not work.', 'warning');
        },
        
        hideOfflineMessage: function() {
            this.hideMessage();
        },
        
        showUserFriendlyError: function(message) {
            this.showMessage(message, 'error');
        },
        
        showMessage: function(text, type = 'info') {
            this.hideMessage(); // Remove existing message
            
            const message = document.createElement('div');
            message.id = 'universal-message';
            message.style.cssText = `
                position: fixed;
                top: 0;
                left: 0;
                right: 0;
                padding: 15px;
                text-align: center;
                z-index: 10001;
                font-size: 14px;
                font-weight: 500;
                ${this.getMessageStyles(type)}
            `;
            message.textContent = text;
            
            document.body.appendChild(message);
            
            // Auto-hide after 5 seconds for non-critical messages
            if (type !== 'error') {
                setTimeout(() => this.hideMessage(), 5000);
            }
        },
        
        hideMessage: function() {
            const existing = document.getElementById('universal-message');
            if (existing) {
                existing.remove();
            }
        },
        
        getMessageStyles: function(type) {
            const styles = {
                info: 'background: #e3f2fd; color: #1565c0; border-bottom: 2px solid #2196f3;',
                warning: 'background: #fff3e0; color: #ef6c00; border-bottom: 2px solid #ff9800;',
                error: 'background: #ffebee; color: #c62828; border-bottom: 2px solid #f44336;',
                success: 'background: #e8f5e8; color: #2e7d32; border-bottom: 2px solid #4caf50;'
            };
            return styles[type] || styles.info;
        }
    };
    
    // Auto-initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            window.UniversalApp.init();
        });
    } else {
        window.UniversalApp.init();
    }
    
})();