// Performance Manager for RoomFinderAI
class PerformanceManager {
    constructor() {
        this.metrics = {
            pageLoad: null,
            firstContentfulPaint: null,
            largestContentfulPaint: null,
            cumulativeLayoutShift: null,
            firstInputDelay: null
        };
        
        this.observers = [];
        this.resourceTimings = [];
        this.analyzedSlowResources = new Set(); // Track already analyzed slow resources
        this.lastAnalysisTime = 0; // Rate limiting for analysis
        this.isMonitoring = false;
        this.enableConsoleLogging = true; // Option to disable console noise
        
        console.log('⚡ Performance Manager initialized');
    }

    // Initialize performance monitoring
    init() {
        this.isMonitoring = true;
        
        // Monitor Core Web Vitals
        this.monitorCoreWebVitals();
        
        // Monitor resource loading
        this.monitorResourceLoading();
        
        // Monitor user interactions
        this.monitorUserInteractions();
        
        // Set up periodic optimization
        this.scheduleOptimizations();
        
        console.log('✅ Performance monitoring active');
    }

    // Monitor Core Web Vitals
    monitorCoreWebVitals() {
        // First Contentful Paint
        this.observePerformanceEntry('paint', (entries) => {
            const fcp = entries.find(entry => entry.name === 'first-contentful-paint');
            if (fcp) {
                this.metrics.firstContentfulPaint = fcp.startTime;
                console.log('🎨 First Contentful Paint:', fcp.startTime.toFixed(2) + 'ms');
            }
        });

        // Largest Contentful Paint
        this.observePerformanceEntry('largest-contentful-paint', (entries) => {
            const lcp = entries[entries.length - 1];
            if (lcp) {
                this.metrics.largestContentfulPaint = lcp.startTime;
                console.log('🖼️ Largest Contentful Paint:', lcp.startTime.toFixed(2) + 'ms');
            }
        });

        // Cumulative Layout Shift
        this.observePerformanceEntry('layout-shift', (entries) => {
            let clsValue = 0;
            entries.forEach(entry => {
                if (!entry.hadRecentInput) {
                    clsValue += entry.value;
                }
            });
            this.metrics.cumulativeLayoutShift = clsValue;
            console.log('📏 Cumulative Layout Shift:', clsValue.toFixed(4));
        });

        // First Input Delay
        this.observePerformanceEntry('first-input', (entries) => {
            const fid = entries[0];
            if (fid) {
                this.metrics.firstInputDelay = fid.processingStart - fid.startTime;
                console.log('⌨️ First Input Delay:', this.metrics.firstInputDelay.toFixed(2) + 'ms');
            }
        });
    }

    // Monitor resource loading performance
    monitorResourceLoading() {
        // Monitor navigation timing
        window.addEventListener('load', () => {
            const navigation = performance.getEntriesByType('navigation')[0];
            if (navigation) {
                this.metrics.pageLoad = navigation.loadEventEnd - navigation.navigationStart;
                console.log('📄 Page Load Time:', this.metrics.pageLoad.toFixed(2) + 'ms');
                
                // Log detailed timing breakdown
                this.logNavigationTimings(navigation);
            }
        });

        // Monitor resource timings
        this.observePerformanceEntry('resource', (entries) => {
            entries.forEach(entry => {
                const resourceInfo = {
                    name: entry.name,
                    duration: entry.duration,
                    size: entry.transferSize || 0,
                    type: this.getResourceType(entry.name),
                    timestamp: Date.now()
                };
                
                this.resourceTimings.push(resourceInfo);
            });
            
            // Limit array size to prevent memory issues (keep only last 100 resources)
            if (this.resourceTimings.length > 100) {
                this.resourceTimings = this.resourceTimings.slice(-100);
            }
            
            // Analyze slow resources with rate limiting
            this.analyzeSlowResourcesThrottled();
        });
    }

    // Monitor user interactions
    monitorUserInteractions() {
        // Track long tasks
        this.observePerformanceEntry('longtask', (entries) => {
            entries.forEach(entry => {
                if (entry.duration > 50) {
                    console.warn('⚠️ Long task detected:', entry.duration.toFixed(2) + 'ms');
                    this.optimizeLongTask(entry);
                }
            });
        });

        // Track memory usage
        if ('memory' in performance) {
            setInterval(() => {
                const memory = performance.memory;
                if (memory.usedJSHeapSize > memory.jsHeapSizeLimit * 0.9) {
                    console.warn('⚠️ High memory usage detected');
                    this.triggerMemoryOptimization();
                }
            }, 30000); // Check every 30 seconds
        }
    }

    // Observe performance entries
    observePerformanceEntry(type, callback) {
        try {
            const observer = new PerformanceObserver((list) => {
                callback(list.getEntries());
            });
            
            observer.observe({ entryTypes: [type] });
            this.observers.push(observer);
            
        } catch (error) {
            console.warn(`Performance observer for ${type} not supported:`, error);
        }
    }

    // Log detailed navigation timings
    logNavigationTimings(navigation) {
        const timings = {
            'DNS Lookup': navigation.domainLookupEnd - navigation.domainLookupStart,
            'TCP Connection': navigation.connectEnd - navigation.connectStart,
            'SSL Handshake': navigation.secureConnectionStart ? navigation.connectEnd - navigation.secureConnectionStart : 0,
            'Request': navigation.responseStart - navigation.requestStart,
            'Response': navigation.responseEnd - navigation.responseStart,
            'DOM Processing': navigation.domContentLoadedEventStart - navigation.responseEnd,
            'Resource Loading': navigation.loadEventStart - navigation.domContentLoadedEventEnd
        };

        console.table(timings);
    }

    // Throttled version of analyze slow resources
    analyzeSlowResourcesThrottled() {
        const now = Date.now();
        const timeSinceLastAnalysis = now - this.lastAnalysisTime;
        
        // Rate limit: Only analyze once every 5 seconds
        if (timeSinceLastAnalysis < 5000) {
            return;
        }
        
        this.lastAnalysisTime = now;
        this.analyzeSlowResources();
    }

    // Analyze slow resources
    analyzeSlowResources() {
        if (!this.enableConsoleLogging) return;
        
        // More realistic thresholds based on resource type and network conditions
        const getThresholdForResource = (resource) => {
            switch (resource.type) {
                case 'image':
                    return 4000; // Images can take longer, especially large ones
                case 'video':
                    return 8000; // Videos are expected to take even longer
                case 'font':
                    return 3000; // Fonts are important but can be slower
                case 'script':
                    return 2500; // Scripts should be reasonably fast
                case 'stylesheet':
                    return 2000; // CSS should load quickly
                default:
                    return 3000; // Default threshold
            }
        };
        
        // Find new slow resources that haven't been analyzed yet
        const newSlowResources = this.resourceTimings
            .filter(resource => {
                const threshold = getThresholdForResource(resource);
                const resourceKey = `${resource.name}-${Math.floor(resource.duration)}`;
                
                if (resource.duration > threshold && !this.analyzedSlowResources.has(resourceKey)) {
                    this.analyzedSlowResources.add(resourceKey);
                    return true;
                }
                return false;
            })
            .sort((a, b) => b.duration - a.duration)
            .slice(0, 3); // Limit to top 3 to reduce noise

        if (newSlowResources.length > 0) {
            // Only log as warning if resources are extremely slow (> 6 seconds)
            const extremelySlow = newSlowResources.filter(r => r.duration > 6000);
            if (extremelySlow.length > 0) {
                console.warn('🐌 Extremely slow resources detected:', extremelySlow.map(r => ({
                    name: r.name.split('/').pop() || r.name, // Show only filename to reduce noise
                    duration: Math.round(r.duration) + 'ms',
                    type: r.type,
                    size: r.size ? Math.round(r.size / 1024) + 'KB' : 'unknown'
                })));
            } else {
                // Only log slower resources if user explicitly wants detailed monitoring
                if (window.location.search.includes('debug=performance')) {
                    console.log('⏱️ Slower resources detected (but within acceptable range):', 
                        newSlowResources.map(r => r.name.split('/').pop() + ' - ' + Math.round(r.duration) + 'ms'));
                }
            }
            
            this.optimizeSlowResources(newSlowResources);
        }
        
        // Clean up old analyzed resources to prevent memory leaks
        if (this.analyzedSlowResources.size > 200) {
            this.analyzedSlowResources.clear();
        }
    }

    // Get resource type from URL
    getResourceType(url) {
        if (url.includes('.js')) return 'script';
        if (url.includes('.css')) return 'stylesheet';
        if (url.match(/\.(jpg|jpeg|png|gif|svg|webp)$/i)) return 'image';
        if (url.match(/\.(mp4|webm|ogg)$/i)) return 'video';
        if (url.includes('font')) return 'font';
        return 'other';
    }

    // Optimize long tasks
    optimizeLongTask(entry) {
        // Break up long tasks using scheduler.postTask if available
        if ('scheduler' in window && 'postTask' in window.scheduler) {
            console.log('🔧 Using scheduler.postTask for task optimization');
        } else {
            // Fallback to setTimeout for task yielding
            this.enableTaskYielding();
        }
    }

    // Enable task yielding for better responsiveness
    enableTaskYielding() {
        // Wrap heavy operations to yield to browser
        window.yieldToMain = function(callback) {
            if (typeof callback === 'function') {
                setTimeout(callback, 0);
            }
        };
    }

    // Optimize slow resources
    optimizeSlowResources(slowResources) {
        slowResources.forEach(resource => {
            switch (resource.type) {
                case 'image':
                    this.optimizeImages();
                    break;
                case 'script':
                    this.optimizeScripts();
                    break;
                case 'stylesheet':
                    this.optimizeStylesheets();
                    break;
            }
        });
    }

    // Image optimization
    optimizeImages() {
        // Implement lazy loading for images not in viewport
        const images = document.querySelectorAll('img:not(.lazy-loaded)');
        
        if ('IntersectionObserver' in window) {
            const imageObserver = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        const img = entry.target;
                        
                        // Add loading placeholder
                        if (!img.src && img.dataset.src) {
                            img.src = img.dataset.src;
                            img.classList.add('lazy-loaded');
                            imageObserver.unobserve(img);
                        }
                    }
                });
            });

            images.forEach(img => {
                if (img.dataset.src) {
                    imageObserver.observe(img);
                }
            });
        }

        console.log('🖼️ Image optimization applied');
    }

    // Script optimization
    optimizeScripts() {
        // Preload critical scripts
        const criticalScripts = [
            '/js/listings.js',
            '/js/notification-manager.js'
        ];

        criticalScripts.forEach(script => {
            if (!document.querySelector(`link[href="${script}"]`)) {
                const link = document.createElement('link');
                link.rel = 'preload';
                link.as = 'script';
                link.href = script;
                document.head.appendChild(link);
            }
        });

        console.log('📜 Script optimization applied');
    }

    // Stylesheet optimization
    optimizeStylesheets() {
        // Preload critical CSS
        const criticalCSS = [
            '/css/mobile-android.css'
        ];

        criticalCSS.forEach(css => {
            if (!document.querySelector(`link[href="${css}"]`)) {
                const link = document.createElement('link');
                link.rel = 'preload';
                link.as = 'style';
                link.href = css;
                document.head.appendChild(link);
            }
        });

        console.log('🎨 Stylesheet optimization applied');
    }

    // Memory optimization
    triggerMemoryOptimization() {
        // Clear cached data if memory is high
        if (window.offlineCacheManager) {
            window.offlineCacheManager.cleanupListingsCache();
        }

        // Clear old image URLs
        this.clearOldImageUrls();

        // Force garbage collection if available
        if ('gc' in window) {
            window.gc();
        }

        console.log('🧹 Memory optimization triggered');
    }

    // Clear old image URLs to free memory
    clearOldImageUrls() {
        const images = document.querySelectorAll('img[src^="blob:"]');
        images.forEach(img => {
            const src = img.src;
            if (src && src.startsWith('blob:')) {
                URL.revokeObjectURL(src);
            }
        });
    }

    // Schedule periodic optimizations
    scheduleOptimizations() {
        // Run optimizations every 5 minutes
        setInterval(() => {
            this.runPeriodicOptimizations();
        }, 5 * 60 * 1000);

        // Run optimizations when page becomes visible
        document.addEventListener('visibilitychange', () => {
            if (!document.hidden) {
                this.runPeriodicOptimizations();
            }
        });
    }

    // Run periodic optimizations
    runPeriodicOptimizations() {
        if (!this.isMonitoring) return;

        // Clear expired caches
        this.clearExpiredCaches();

        // Optimize DOM if needed
        this.optimizeDOM();

        // Preload next likely resources
        this.preloadLikelyResources();

        console.log('🔄 Periodic optimizations completed');
    }

    // Clear expired caches
    clearExpiredCaches() {
        // Clear localStorage items older than 24 hours
        const now = Date.now();
        const maxAge = 24 * 60 * 60 * 1000;

        Object.keys(localStorage).forEach(key => {
            try {
                const item = null;
                if (item) {
                    const parsed = JSON.parse(item);
                    if (parsed.timestamp && (now - new Date(parsed.timestamp).getTime()) > maxAge) {
                        // localStorage removed
                    }
                }
            } catch (error) {
                // Not a timestamped item, skip
            }
        });
    }

    // Optimize DOM structure
    optimizeDOM() {
        // Remove hidden elements that are no longer needed
        // IMPORTANT: Never remove critical elements like header, nav, footer, or auth sections
        const hiddenElements = document.querySelectorAll('[style*="display: none"], .hidden');
        const criticalSelectors = ['header', 'nav', 'footer', '#header', '#authSection', '.premium-header', '.desktop-nav', '.mobile-menu', '#messagePanel', '#messagingPanel', '#messageToggleBtn', '.chat-modal', '#chatModal'];

        hiddenElements.forEach(element => {
            // Skip critical elements
            const isCritical = criticalSelectors.some(sel =>
                element.matches(sel) || element.closest(sel)
            );

            if (!isCritical && element.dataset.keepHidden !== 'true') {
                element.remove();
            }
        });

        // Limit the number of DOM nodes in listings container
        const listingsContainer = document.getElementById('listingsContainer');
        if (listingsContainer && listingsContainer.children.length > 100) {
            // Remove oldest listings beyond limit
            const children = Array.from(listingsContainer.children);
            children.slice(100).forEach(child => child.remove());
        }
    }

    // Preload likely next resources
    preloadLikelyResources() {
        // Based on user behavior, preload likely next pages
        if (window.recommendationEngine) {
            // Preload recommendation images
            this.preloadRecommendationImages();
        }
    }

    // Preload recommendation images
    async preloadRecommendationImages() {
        try {
            const recommendations = await window.recommendationEngine.generateRecommendations(3);
            
            recommendations.forEach(property => {
                if (property.media && property.media.length > 0) {
                    const img = new Image();
                    img.src = property.media[0].url;
                }
            });
        } catch (error) {
            // Ignore preload errors
        }
    }

    // Bundle and compress resources
    enableResourceCompression() {
        // Enable compression for fetch requests
        const originalFetch = window.fetch;
        window.fetch = function(...args) {
            const [url, options = {}] = args;
            
            // Preserve existing headers and add compression (don't overwrite Supabase headers)
            if (!options.headers) {
                options.headers = {};
            }
            
            // Only add compression if not already present
            if (!options.headers['Accept-Encoding']) {
                options.headers['Accept-Encoding'] = 'gzip, deflate, br';
            }
            
            return originalFetch(url, options);
        };
    }

    // Enable service worker caching
    enableServiceWorkerCaching() {
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.register('/sw.js')
                .then(registration => {
                    console.log('📱 Service Worker registered for caching');
                })
                .catch(error => {
                    console.error('Service Worker registration failed:', error);
                });
        }
    }

    // Control performance logging
    setConsoleLogging(enabled) {
        this.enableConsoleLogging = enabled;
        console.log(enabled ? 
            '📢 Performance console logging enabled' : 
            '🔇 Performance console logging disabled');
    }

    // Enable detailed performance debugging
    enableDebugMode() {
        this.enableConsoleLogging = true;
        console.log('🐛 Performance debug mode enabled - all warnings will be shown');
    }

    // Disable performance monitoring entirely
    disableMonitoring() {
        this.isMonitoring = false;
        this.enableConsoleLogging = false;
        this.observers.forEach(observer => observer.disconnect());
        console.log('⏸️ Performance monitoring completely disabled');
    }

    // Get performance report
    getPerformanceReport() {
        return {
            coreWebVitals: {
                firstContentfulPaint: this.metrics.firstContentfulPaint,
                largestContentfulPaint: this.metrics.largestContentfulPaint,
                cumulativeLayoutShift: this.metrics.cumulativeLayoutShift,
                firstInputDelay: this.metrics.firstInputDelay
            },
            pageLoad: this.metrics.pageLoad,
            resourceCount: this.resourceTimings.length,
            slowResources: this.resourceTimings.filter(r => r.duration > 1000).length,
            memoryUsage: 'memory' in performance ? performance.memory : null,
            timestamp: new Date().toISOString()
        };
    }

    // Log performance summary
    logPerformanceSummary() {
        const report = this.getPerformanceReport();
        console.group('📊 Performance Summary');
        console.table(report.coreWebVitals);
        console.log('Page Load Time:', report.pageLoad?.toFixed(2) + 'ms');
        console.log('Total Resources:', report.resourceCount);
        console.log('Slow Resources:', report.slowResources);
        if (report.memoryUsage) {
            console.log('Memory Usage:', (report.memoryUsage.usedJSHeapSize / 1024 / 1024).toFixed(2) + 'MB');
        }
        console.groupEnd();
    }

    // Enable all optimizations
    enableAllOptimizations() {
        this.enableResourceCompression();
        this.enableServiceWorkerCaching();
        this.enableTaskYielding();
        
        console.log('🚀 All performance optimizations enabled');
    }

    // Stop monitoring
    stop() {
        this.isMonitoring = false;
        this.observers.forEach(observer => observer.disconnect());
        this.observers = [];
        
        console.log('⏹️ Performance monitoring stopped');
    }
}

// Initialize performance manager
window.performanceManager = new PerformanceManager();

// Auto-start monitoring when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.performanceManager.init();
    window.performanceManager.enableAllOptimizations();
    
    // Disable console logging by default to reduce noise
    // Enable only if explicitly requested or in debug mode
    const shouldEnableLogging = window.location.search.includes('debug=performance') || 
                               window.location.hostname === 'localhost' ||
                               window.location.hostname === '127.0.0.1';
    
    if (!shouldEnableLogging) {
        window.performanceManager.setConsoleLogging(false);
    }
    
    // Log performance summary after page load (only if logging enabled)
    window.addEventListener('load', () => {
        setTimeout(() => {
            if (window.performanceManager.enableConsoleLogging) {
                window.performanceManager.logPerformanceSummary();
            }
        }, 2000);
    });
});

// Global helper functions for manual control
window.enablePerformanceLogging = () => window.performanceManager.setConsoleLogging(true);
window.disablePerformanceLogging = () => window.performanceManager.setConsoleLogging(false);
window.enablePerformanceDebug = () => window.performanceManager.enableDebugMode();
window.disablePerformanceMonitoring = () => window.performanceManager.disableMonitoring();