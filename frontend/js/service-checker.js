/**
 * Service Availability Checker
 * Detects which backend services are available and adjusts UI accordingly
 */

class ServiceChecker {
    constructor() {
        this.status = {
            services: {},
            features: {},
            lastChecked: null
        };
        this.callbacks = [];
    }

    async checkServices() {
        try {
            const response = await fetch('/api/service-status');
            if (response.ok) {
                const data = await response.json();
                this.status = {
                    ...data,
                    lastChecked: new Date().toISOString(),
                    online: true
                };
            } else {
                this.status.online = false;
            }
        } catch (error) {
            console.error('Service check failed:', error);
            this.status.online = false;
        }
        
        this.notifyCallbacks();
        return this.status;
    }

    onStatusChange(callback) {
        this.callbacks.push(callback);
    }

    notifyCallbacks() {
        this.callbacks.forEach(cb => cb(this.status));
    }

    isFeatureAvailable(feature) {
        return this.status.features?.[feature] || false;
    }

    getServiceStatus(service) {
        return this.status.services?.[service] || false;
    }

    // Display appropriate messages based on service availability
    getFeatureMessage(feature) {
        if (!this.status.online) {
            return 'Service temporarily unavailable. Please try again later.';
        }

        const messages = {
            ai: 'AI features require configuration. Please contact support.',
            payments: 'Payment processing is currently offline.',
            database: 'Database connection unavailable. Some features may be limited.',
            email: 'Email verification is currently disabled.',
            idVerification: 'ID verification service is unavailable.'
        };

        if (!this.isFeatureAvailable(feature)) {
            return messages[feature] || 'This feature is currently unavailable.';
        }

        return null;
    }

    // Initialize service checker on page load
    async init() {
        await this.checkServices();
        
        // Re-check services every 30 seconds
        setInterval(() => this.checkServices(), 30000);
        
        // Update UI based on service availability
        this.updateUI();
    }

    updateUI() {
        // Disable/enable features based on availability
        const features = [
            { name: 'ai', selector: '.ai-negotiator-btn', message: 'AI Negotiator' },
            { name: 'payments', selector: '.payment-btn', message: 'Payment' },
            { name: 'idVerification', selector: '.verify-id-btn', message: 'ID Verification' }
        ];

        features.forEach(({ name, selector, message }) => {
            const elements = document.querySelectorAll(selector);
            elements.forEach(el => {
                if (!this.isFeatureAvailable(name)) {
                    el.disabled = true;
                    el.title = this.getFeatureMessage(name);
                    el.classList.add('opacity-50', 'cursor-not-allowed');
                    
                    // Add warning badge if not already present
                    if (!el.querySelector('.service-unavailable-badge')) {
                        const badge = document.createElement('span');
                        badge.className = 'service-unavailable-badge ml-2 text-xs text-yellow-600';
                        badge.textContent = '(Unavailable)';
                        el.appendChild(badge);
                    }
                } else {
                    el.disabled = false;
                    el.title = '';
                    el.classList.remove('opacity-50', 'cursor-not-allowed');
                    
                    // Remove warning badge if present
                    const badge = el.querySelector('.service-unavailable-badge');
                    if (badge) badge.remove();
                }
            });
        });

        // Show service status banner if any critical services are down
        this.showStatusBanner();
    }

    showStatusBanner() {
        const existingBanner = document.getElementById('service-status-banner');
        if (existingBanner) existingBanner.remove();

        const criticalServices = ['database', 'ai'];
        const unavailableServices = criticalServices.filter(s => !this.isFeatureAvailable(s));

        if (unavailableServices.length > 0 && !this.status.features?.anonymousBrowsing) {
            const banner = document.createElement('div');
            banner.id = 'service-status-banner';
            banner.className = 'fixed top-0 left-0 right-0 bg-yellow-50 border-b border-yellow-200 p-3 z-50';
            banner.innerHTML = `
                <div class="container mx-auto px-4 flex items-center justify-between">
                    <div class="flex items-center">
                        <svg class="w-5 h-5 text-yellow-600 mr-2" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
                        </svg>
                        <span class="text-sm text-yellow-800">
                            Some services are currently limited. You can still browse listings.
                        </span>
                    </div>
                    <button onclick="this.parentElement.parentElement.remove()" class="text-yellow-600 hover:text-yellow-800">
                        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/>
                        </svg>
                    </button>
                </div>
            `;
            document.body.prepend(banner);
        }
    }
}

// Create global instance
window.serviceChecker = new ServiceChecker();

// Initialize on DOM ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => window.serviceChecker.init());
} else {
    window.serviceChecker.init();
}

// Export for module usage
export default ServiceChecker;