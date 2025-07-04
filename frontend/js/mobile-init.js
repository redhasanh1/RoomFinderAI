// Mobile Initialization Script for Android

document.addEventListener('DOMContentLoaded', function() {
    // Check if running on mobile
    const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
    
    if (isMobile) {
        document.body.classList.add('mobile-device');
        
        // Prevent double-tap zoom
        let lastTouchEnd = 0;
        document.addEventListener('touchend', function(event) {
            const now = (new Date()).getTime();
            if (now - lastTouchEnd <= 300) {
                event.preventDefault();
            }
            lastTouchEnd = now;
        }, false);
        
        // Add touch feedback to clickable elements
        const clickableElements = document.querySelectorAll('button, a, .clickable');
        clickableElements.forEach(element => {
            element.classList.add('touch-feedback');
        });
        
        // Handle orientation changes
        window.addEventListener('orientationchange', function() {
            setTimeout(() => {
                window.scrollTo(0, 1);
            }, 500);
        });
        
        // Improve scroll performance
        const scrollContainers = document.querySelectorAll('.scroll-container');
        scrollContainers.forEach(container => {
            container.classList.add('hardware-accelerated');
        });
    }
    
    // Add mobile navigation
    createMobileNavigation();
    
    // Handle keyboard events for better UX
    handleMobileKeyboard();
    
    // Add pull-to-refresh functionality
    if (window.Capacitor) {
        initPullToRefresh();
    }
});

// Create mobile navigation
function createMobileNavigation() {
    const mobileNav = document.createElement('div');
    mobileNav.className = 'mobile-nav';
    mobileNav.innerHTML = `
        <a href="/index.html" class="nav-item">
            <svg width="24" height="24" fill="currentColor">
                <path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/>
            </svg>
            <span>Home</span>
        </a>
        <a href="/listings.html" class="nav-item">
            <svg width="24" height="24" fill="currentColor">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
            </svg>
            <span>Listings</span>
        </a>
        <a href="/ai-negotiator.html" class="nav-item">
            <svg width="24" height="24" fill="currentColor">
                <path d="M21 11.5a8.38 8.38 0 01-.9 3.8 8.5 8.5 0 01-7.6 4.7 8.38 8.38 0 01-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 01-.9-3.8 8.5 8.5 0 014.7-7.6 8.38 8.38 0 013.8-.9h.5a8.48 8.48 0 018 8v.5z"/>
            </svg>
            <span>AI Chat</span>
        </a>
        <a href="/profile.html" class="nav-item">
            <svg width="24" height="24" fill="currentColor">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z"/>
            </svg>
            <span>Profile</span>
        </a>
    `;
    
    // Add CSS for mobile nav items
    const style = document.createElement('style');
    style.textContent = `
        .nav-item {
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: 8px;
            text-decoration: none;
            color: #666;
            font-size: 12px;
        }
        .nav-item svg {
            margin-bottom: 4px;
        }
        .nav-item:active {
            color: #667eea;
        }
    `;
    document.head.appendChild(style);
    
    // Only add mobile nav if not already present
    if (!document.querySelector('.mobile-nav')) {
        document.body.appendChild(mobileNav);
        document.body.classList.add('bottom-nav-padding');
    }
}

// Handle mobile keyboard
function handleMobileKeyboard() {
    const inputs = document.querySelectorAll('input, textarea');
    
    inputs.forEach(input => {
        input.addEventListener('focus', function() {
            // Scroll input into view when keyboard opens
            setTimeout(() => {
                this.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }, 300);
        });
        
        input.addEventListener('blur', function() {
            // Reset scroll position when keyboard closes
            window.scrollTo(0, 0);
        });
    });
}

// Initialize pull-to-refresh
function initPullToRefresh() {
    let startY = 0;
    let pullDistance = 0;
    const threshold = 100;
    
    document.addEventListener('touchstart', function(e) {
        if (window.scrollY === 0) {
            startY = e.touches[0].pageY;
        }
    });
    
    document.addEventListener('touchmove', function(e) {
        if (window.scrollY === 0 && startY > 0) {
            pullDistance = e.touches[0].pageY - startY;
            
            if (pullDistance > 0 && pullDistance < threshold * 2) {
                e.preventDefault();
                // Add visual feedback for pull-to-refresh
                if (!document.querySelector('.pull-to-refresh')) {
                    const refreshIndicator = document.createElement('div');
                    refreshIndicator.className = 'pull-to-refresh';
                    refreshIndicator.innerHTML = '↓';
                    document.body.appendChild(refreshIndicator);
                }
            }
        }
    });
    
    document.addEventListener('touchend', function() {
        const refreshIndicator = document.querySelector('.pull-to-refresh');
        if (refreshIndicator) {
            refreshIndicator.remove();
        }
        
        if (pullDistance > threshold) {
            // Trigger refresh
            window.location.reload();
        }
        
        startY = 0;
        pullDistance = 0;
    });
}

// Export functions for use in other scripts
window.mobileUtils = {
    isMobile: /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent),
    vibrate: function(duration = 50) {
        if ('vibrate' in navigator) {
            navigator.vibrate(duration);
        }
    },
    share: function(title, text, url) {
        if (navigator.share) {
            navigator.share({ title, text, url })
                .catch(err => console.log('Error sharing:', err));
        }
    }
};