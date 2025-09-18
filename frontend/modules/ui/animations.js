/**
 * Animations Manager Module
 * Handles CSS animations, transitions, and visual effects
 */

class AnimationsManager {
    constructor() {
        this.isInitialized = false;
        this.animations = new Map();
        this.observers = new Map();
    }

    /**
     * Initialize animations manager
     */
    init() {
        this.setupAnimationStyles();
        this.setupIntersectionObserver();
        this.setupScrollAnimations();

        this.isInitialized = true;
        console.log('✅ Animations Manager initialized');
    }

    /**
     * Setup animation styles
     */
    setupAnimationStyles() {
        if (document.getElementById('animation-styles')) return;

        const style = document.createElement('style');
        style.id = 'animation-styles';
        style.textContent = `
            /* Base animation classes */
            .animate-fade-in {
                animation: fadeIn 0.6s ease-out;
            }

            .animate-slide-down {
                animation: slideDown 0.4s ease-out;
            }

            .animate-slide-up {
                animation: slideUp 0.4s ease-out;
            }

            .animate-slide-left {
                animation: slideLeft 0.4s ease-out;
            }

            .animate-slide-right {
                animation: slideRight 0.4s ease-out;
            }

            .animate-scale-in {
                animation: scaleIn 0.3s ease-out;
            }

            .animate-bounce-in {
                animation: bounceIn 0.6s ease-out;
            }

            .animate-pulse {
                animation: pulse 2s infinite;
            }

            .animate-spin {
                animation: spin 1s linear infinite;
            }

            /* Hover animations */
            .hover-lift {
                transition: transform 0.3s ease, box-shadow 0.3s ease;
            }

            .hover-lift:hover {
                transform: translateY(-4px);
                box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
            }

            .hover-scale {
                transition: transform 0.2s ease;
            }

            .hover-scale:hover {
                transform: scale(1.05);
            }

            .hover-glow {
                transition: box-shadow 0.3s ease;
            }

            .hover-glow:hover {
                box-shadow: 0 0 20px rgba(102, 126, 234, 0.4);
            }

            /* Loading animations */
            .loading-shimmer {
                background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
                background-size: 200% 100%;
                animation: shimmer 1.5s infinite;
            }

            .loading-dots::after {
                content: '';
                animation: loadingDots 1.5s infinite;
            }

            .loading-spinner {
                width: 20px;
                height: 20px;
                border: 2px solid #f3f3f3;
                border-top: 2px solid #3498db;
                border-radius: 50%;
                animation: spin 1s linear infinite;
                display: inline-block;
            }

            /* Attention grabbing animations */
            .animate-shake {
                animation: shake 0.5s ease-in-out;
            }

            .animate-wiggle {
                animation: wiggle 0.6s ease-in-out;
            }

            .animate-heartbeat {
                animation: heartBeat 0.6s ease-in-out;
            }

            /* Scroll reveal animations */
            .reveal-on-scroll {
                opacity: 0;
                transform: translateY(30px);
                transition: opacity 0.6s ease, transform 0.6s ease;
            }

            .reveal-on-scroll.revealed {
                opacity: 1;
                transform: translateY(0);
            }

            /* Staggered animations */
            .stagger-item {
                opacity: 0;
                transform: translateY(20px);
                transition: opacity 0.4s ease, transform 0.4s ease;
            }

            .stagger-item.animate {
                opacity: 1;
                transform: translateY(0);
            }

            /* Keyframe definitions */
            @keyframes fadeIn {
                from { opacity: 0; transform: translateY(20px); }
                to { opacity: 1; transform: translateY(0); }
            }

            @keyframes slideDown {
                from { opacity: 0; transform: translateY(-20px); max-height: 0; }
                to { opacity: 1; transform: translateY(0); max-height: 1000px; }
            }

            @keyframes slideUp {
                from { opacity: 0; transform: translateY(20px); }
                to { opacity: 1; transform: translateY(0); }
            }

            @keyframes slideLeft {
                from { opacity: 0; transform: translateX(20px); }
                to { opacity: 1; transform: translateX(0); }
            }

            @keyframes slideRight {
                from { opacity: 0; transform: translateX(-20px); }
                to { opacity: 1; transform: translateX(0); }
            }

            @keyframes scaleIn {
                from { opacity: 0; transform: scale(0.8); }
                to { opacity: 1; transform: scale(1); }
            }

            @keyframes bounceIn {
                0% { opacity: 0; transform: scale(0.3); }
                50% { opacity: 1; transform: scale(1.05); }
                70% { transform: scale(0.9); }
                100% { opacity: 1; transform: scale(1); }
            }

            @keyframes pulse {
                0%, 100% { opacity: 1; }
                50% { opacity: 0.5; }
            }

            @keyframes spin {
                from { transform: rotate(0deg); }
                to { transform: rotate(360deg); }
            }

            @keyframes shimmer {
                0% { background-position: -200% 0; }
                100% { background-position: 200% 0; }
            }

            @keyframes loadingDots {
                0%, 20% { content: ''; }
                40% { content: '.'; }
                60% { content: '..'; }
                80%, 100% { content: '...'; }
            }

            @keyframes shake {
                0%, 100% { transform: translateX(0); }
                10%, 30%, 50%, 70%, 90% { transform: translateX(-5px); }
                20%, 40%, 60%, 80% { transform: translateX(5px); }
            }

            @keyframes wiggle {
                0%, 100% { transform: rotate(0deg); }
                25% { transform: rotate(-3deg); }
                75% { transform: rotate(3deg); }
            }

            @keyframes heartBeat {
                0% { transform: scale(1); }
                20% { transform: scale(1.25); }
                40% { transform: scale(1.1); }
                60% { transform: scale(1.25); }
                80% { transform: scale(1.1); }
                100% { transform: scale(1); }
            }

            /* Responsive animation adjustments */
            @media (prefers-reduced-motion: reduce) {
                .animate-fade-in,
                .animate-slide-down,
                .animate-slide-up,
                .animate-slide-left,
                .animate-slide-right,
                .animate-scale-in,
                .animate-bounce-in,
                .reveal-on-scroll,
                .stagger-item {
                    animation: none;
                    transition: none;
                    opacity: 1;
                    transform: none;
                }
            }

            @media (max-width: 768px) {
                .hover-lift:hover {
                    transform: none;
                }

                .hover-scale:hover {
                    transform: none;
                }
            }
        `;
        document.head.appendChild(style);
    }

    /**
     * Setup intersection observer for scroll animations
     */
    setupIntersectionObserver() {
        if (!window.IntersectionObserver) return;

        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('revealed');
                    observer.unobserve(entry.target);
                }
            });
        }, {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        });

        // Observe all elements with reveal-on-scroll class
        document.querySelectorAll('.reveal-on-scroll').forEach(el => {
            observer.observe(el);
        });

        this.observers.set('scroll-reveal', observer);
    }

    /**
     * Setup scroll animations
     */
    setupScrollAnimations() {
        // Throttled scroll handler
        let ticking = false;

        const handleScroll = () => {
            if (!ticking) {
                requestAnimationFrame(() => {
                    this.updateScrollAnimations();
                    ticking = false;
                });
                ticking = true;
            }
        };

        window.addEventListener('scroll', handleScroll, { passive: true });
    }

    /**
     * Update scroll-based animations
     */
    updateScrollAnimations() {
        const scrollTop = window.pageYOffset;
        const windowHeight = window.innerHeight;

        // Parallax effect for hero section
        const hero = document.querySelector('.hero-section');
        if (hero) {
            const heroHeight = hero.offsetHeight;
            const scrolled = scrollTop;
            const parallax = scrolled * 0.5;

            if (scrolled < heroHeight) {
                hero.style.transform = `translateY(${parallax}px)`;
            }
        }

        // Header scroll effect
        const header = document.getElementById('header');
        if (header) {
            if (scrollTop > 100) {
                header.classList.add('scrolled');
            } else {
                header.classList.remove('scrolled');
            }
        }
    }

    /**
     * Animate element with specified animation
     */
    animate(element, animationClass, options = {}) {
        if (typeof element === 'string') {
            element = document.querySelector(element);
        }

        if (!element) return Promise.resolve();

        const {
            duration = null,
            delay = 0,
            onComplete = null,
            removeOnComplete = true
        } = options;

        return new Promise((resolve) => {
            const cleanup = () => {
                if (removeOnComplete) {
                    element.classList.remove(animationClass);
                }
                element.removeEventListener('animationend', cleanup);
                if (onComplete) onComplete();
                resolve();
            };

            if (delay > 0) {
                setTimeout(() => {
                    element.classList.add(animationClass);
                    element.addEventListener('animationend', cleanup, { once: true });
                }, delay);
            } else {
                element.classList.add(animationClass);
                element.addEventListener('animationend', cleanup, { once: true });
            }

            if (duration) {
                element.style.animationDuration = duration;
            }
        });
    }

    /**
     * Fade in element
     */
    fadeIn(element, options = {}) {
        return this.animate(element, 'animate-fade-in', options);
    }

    /**
     * Slide down element
     */
    slideDown(element, options = {}) {
        return this.animate(element, 'animate-slide-down', options);
    }

    /**
     * Slide up element
     */
    slideUp(element, options = {}) {
        return this.animate(element, 'animate-slide-up', options);
    }

    /**
     * Scale in element
     */
    scaleIn(element, options = {}) {
        return this.animate(element, 'animate-scale-in', options);
    }

    /**
     * Bounce in element
     */
    bounceIn(element, options = {}) {
        return this.animate(element, 'animate-bounce-in', options);
    }

    /**
     * Shake element (attention grabbing)
     */
    shake(element, options = {}) {
        return this.animate(element, 'animate-shake', options);
    }

    /**
     * Heartbeat animation (for favorites)
     */
    heartbeat(element, options = {}) {
        return this.animate(element, 'animate-heartbeat', options);
    }

    /**
     * Staggered animation for multiple elements
     */
    staggerElements(elements, animationClass = 'animate-fade-in', delay = 100) {
        if (typeof elements === 'string') {
            elements = document.querySelectorAll(elements);
        }

        const promises = [];
        elements.forEach((element, index) => {
            const promise = this.animate(element, animationClass, {
                delay: index * delay
            });
            promises.push(promise);
        });

        return Promise.all(promises);
    }

    /**
     * Create loading animation
     */
    showLoading(element, type = 'spinner') {
        if (typeof element === 'string') {
            element = document.querySelector(element);
        }

        if (!element) return;

        const originalContent = element.innerHTML;
        this.animations.set(element, { originalContent, type: 'loading' });

        switch (type) {
            case 'spinner':
                element.innerHTML = '<div class="loading-spinner"></div>';
                break;
            case 'dots':
                element.innerHTML = '<span class="loading-dots">Loading</span>';
                break;
            case 'shimmer':
                element.classList.add('loading-shimmer');
                break;
            default:
                element.innerHTML = 'Loading...';
        }
    }

    /**
     * Hide loading animation
     */
    hideLoading(element) {
        if (typeof element === 'string') {
            element = document.querySelector(element);
        }

        if (!element) return;

        const animation = this.animations.get(element);
        if (animation && animation.type === 'loading') {
            element.innerHTML = animation.originalContent;
            element.classList.remove('loading-shimmer');
            this.animations.delete(element);
        }
    }

    /**
     * Animate favorite button
     */
    animateFavorite(button) {
        if (typeof button === 'string') {
            button = document.querySelector(button);
        }

        if (!button) return;

        button.classList.add('favoriting');
        setTimeout(() => {
            button.classList.remove('favoriting');
        }, 600);
    }

    /**
     * Smooth scroll to element
     */
    scrollTo(element, options = {}) {
        if (typeof element === 'string') {
            element = document.querySelector(element);
        }

        if (!element) return;

        const {
            offset = 0,
            duration = 500,
            easing = 'ease-in-out'
        } = options;

        const targetPosition = element.offsetTop - offset;
        const startPosition = window.pageYOffset;
        const distance = targetPosition - startPosition;
        let startTime = null;

        const animation = (currentTime) => {
            if (startTime === null) startTime = currentTime;
            const timeElapsed = currentTime - startTime;
            const progress = Math.min(timeElapsed / duration, 1);

            const ease = this.easingFunctions[easing] || this.easingFunctions['ease-in-out'];
            const currentPosition = startPosition + (distance * ease(progress));

            window.scrollTo(0, currentPosition);

            if (progress < 1) {
                requestAnimationFrame(animation);
            }
        };

        requestAnimationFrame(animation);
    }

    /**
     * Easing functions
     */
    easingFunctions = {
        'linear': t => t,
        'ease-in': t => t * t,
        'ease-out': t => t * (2 - t),
        'ease-in-out': t => t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t,
        'bounce': t => {
            const n1 = 7.5625;
            const d1 = 2.75;
            if (t < 1 / d1) {
                return n1 * t * t;
            } else if (t < 2 / d1) {
                return n1 * (t -= 1.5 / d1) * t + 0.75;
            } else if (t < 2.5 / d1) {
                return n1 * (t -= 2.25 / d1) * t + 0.9375;
            } else {
                return n1 * (t -= 2.625 / d1) * t + 0.984375;
            }
        }
    };

    /**
     * Add hover effect to element
     */
    addHoverEffect(element, effect = 'lift') {
        if (typeof element === 'string') {
            element = document.querySelector(element);
        }

        if (!element) return;

        switch (effect) {
            case 'lift':
                element.classList.add('hover-lift');
                break;
            case 'scale':
                element.classList.add('hover-scale');
                break;
            case 'glow':
                element.classList.add('hover-glow');
                break;
        }
    }

    /**
     * Remove hover effect from element
     */
    removeHoverEffect(element, effect = 'lift') {
        if (typeof element === 'string') {
            element = document.querySelector(element);
        }

        if (!element) return;

        switch (effect) {
            case 'lift':
                element.classList.remove('hover-lift');
                break;
            case 'scale':
                element.classList.remove('hover-scale');
                break;
            case 'glow':
                element.classList.remove('hover-glow');
                break;
        }
    }

    /**
     * Check if user prefers reduced motion
     */
    prefersReducedMotion() {
        return window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    }

    /**
     * Destroy animations manager
     */
    destroy() {
        // Clean up observers
        this.observers.forEach(observer => {
            observer.disconnect();
        });
        this.observers.clear();

        // Clean up animations
        this.animations.clear();

        this.isInitialized = false;
        console.log('🗑️ Animations Manager destroyed');
    }
}

// Create global instance
window.animationsManager = new AnimationsManager();

// Global functions for backward compatibility
window.fadeIn = (element, options = {}) => {
    return window.animationsManager ?
        window.animationsManager.fadeIn(element, options) :
        Promise.resolve();
};

window.slideDown = (element, options = {}) => {
    return window.animationsManager ?
        window.animationsManager.slideDown(element, options) :
        Promise.resolve();
};

window.scrollTo = (element, options = {}) => {
    if (window.animationsManager) {
        window.animationsManager.scrollTo(element, options);
    }
};

window.scrollToListings = () => {
    const listingsSection = document.getElementById('listings-section');
    if (listingsSection) {
        window.animationsManager?.scrollTo(listingsSection, { offset: 100 });
    }
};

window.toggleFavorite = (listingId, button) => {
    // Animate the favorite button
    if (window.animationsManager) {
        window.animationsManager.animateFavorite(button);
    }

    // Toggle favorite styling
    const icon = button.querySelector('svg');
    if (icon) {
        const currentColor = icon.style.fill;
        if (currentColor === 'red' || currentColor === '#ef4444') {
            icon.style.fill = 'none';
            icon.style.stroke = 'currentColor';
        } else {
            icon.style.fill = '#ef4444';
            icon.style.stroke = '#ef4444';
        }
    }

    console.log('Toggled favorite for listing:', listingId);
};

export default window.animationsManager;