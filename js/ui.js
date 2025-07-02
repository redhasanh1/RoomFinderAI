// UI helpers and modal management module
window.UIManager = (function() {
    let activeModals = new Set();
    let modalHistory = [];

    // Initialize UI management
    function initialize() {
        setupGlobalEventHandlers();
        setupKeyboardHandlers();
        setupModalManagement();
        console.log('🎨 UI Manager initialized');
    }

    // Setup global event handlers
    function setupGlobalEventHandlers() {
        // Handle clicks outside modals
        document.addEventListener('click', handleGlobalClick);
        
        // Handle scroll events for animations
        window.addEventListener('scroll', handleScroll);
        
        // Handle resize events
        window.addEventListener('resize', handleResize);
        
        console.log('🎭 Global event handlers setup');
    }

    // Setup keyboard event handlers
    function setupKeyboardHandlers() {
        document.addEventListener('keydown', (e) => {
            // ESC key to close modals
            if (e.key === 'Escape') {
                closeTopModal();
            }
            
            // Enter key handling for forms
            if (e.key === 'Enter' && e.target.tagName === 'INPUT') {
                handleEnterKeyOnInput(e);
            }
        });
        
        console.log('⌨️ Keyboard handlers setup');
    }

    // Setup modal management
    function setupModalManagement() {
        // Setup all existing modals
        const modals = document.querySelectorAll('.modal, .chat-modal');
        modals.forEach(modal => {
            setupModalElement(modal);
        });
        
        // Setup close buttons
        const closeButtons = document.querySelectorAll('.close-button, .chat-close-button');
        closeButtons.forEach(btn => {
            if (!btn.hasAttribute('data-ui-setup')) {
                btn.addEventListener('click', (e) => {
                    const modal = e.target.closest('.modal, .chat-modal');
                    if (modal) {
                        closeModal(modal);
                    }
                });
                btn.setAttribute('data-ui-setup', 'true');
            }
        });
        
        console.log('🪟 Modal management setup completed');
    }

    // Setup individual modal element
    function setupModalElement(modal) {
        if (modal.hasAttribute('data-ui-setup')) return;
        
        // Click outside to close
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                closeModal(modal);
            }
        });
        
        // Prevent content clicks from closing modal
        const content = modal.querySelector('.modal-content, .chat-modal-content');
        if (content) {
            content.addEventListener('click', (e) => {
                e.stopPropagation();
            });
        }
        
        modal.setAttribute('data-ui-setup', 'true');
    }

    // Handle global clicks
    function handleGlobalClick(e) {
        // Handle dropdown closures
        const dropdowns = document.querySelectorAll('.custom-autocomplete:not(.hidden)');
        dropdowns.forEach(dropdown => {
            const input = dropdown.previousElementSibling;
            if (input && !input.contains(e.target) && !dropdown.contains(e.target)) {
                dropdown.classList.add('hidden');
            }
        });
        
        // Handle tooltip dismissals
        const tooltips = document.querySelectorAll('.tooltip.active');
        tooltips.forEach(tooltip => {
            if (!tooltip.contains(e.target)) {
                tooltip.classList.remove('active');
            }
        });
    }

    // Handle scroll events
    function handleScroll() {
        // Animate elements on scroll
        const animatedElements = document.querySelectorAll('[data-animate-on-scroll]');
        animatedElements.forEach(element => {
            if (isElementInViewport(element)) {
                element.classList.add('animate-in');
            }
        });
        
        // Update sticky elements
        updateStickyElements();
    }

    // Handle resize events
    function handleResize() {
        // Invalidate map if it exists
        if (window.MapManager?.getMapInstance()) {
            setTimeout(() => {
                window.MapManager.resizeMap();
            }, 100);
        }
        
        // Adjust modal positions
        activeModals.forEach(modal => {
            adjustModalPosition(modal);
        });
    }

    // Check if element is in viewport
    function isElementInViewport(element) {
        const rect = element.getBoundingClientRect();
        return (
            rect.top >= 0 &&
            rect.left >= 0 &&
            rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
            rect.right <= (window.innerWidth || document.documentElement.clientWidth)
        );
    }

    // Update sticky elements
    function updateStickyElements() {
        const stickyElements = document.querySelectorAll('[data-sticky]');
        stickyElements.forEach(element => {
            const offset = element.getAttribute('data-sticky-offset') || 0;
            if (window.scrollY > offset) {
                element.classList.add('sticky-active');
            } else {
                element.classList.remove('sticky-active');
            }
        });
    }

    // Open modal
    function openModal(modalId) {
        const modal = document.getElementById(modalId);
        if (!modal) {
            console.warn(`Modal ${modalId} not found`);
            return false;
        }
        
        setupModalElement(modal);
        
        modal.classList.add('active');
        activeModals.add(modal);
        modalHistory.push(modal);
        
        // Disable body scrolling
        document.body.classList.add('modal-open');
        
        // Focus first input or button
        setTimeout(() => {
            const focusable = modal.querySelector('input, textarea, button, [tabindex]');
            if (focusable) {
                focusable.focus();
            }
        }, 100);
        
        console.log(`🪟 Modal ${modalId} opened`);
        return true;
    }

    // Close modal
    function closeModal(modal) {
        if (typeof modal === 'string') {
            modal = document.getElementById(modal);
        }
        
        if (!modal) return false;
        
        modal.classList.remove('active');
        activeModals.delete(modal);
        
        // Remove from history
        const historyIndex = modalHistory.indexOf(modal);
        if (historyIndex > -1) {
            modalHistory.splice(historyIndex, 1);
        }
        
        // Re-enable body scrolling if no modals are open
        if (activeModals.size === 0) {
            document.body.classList.remove('modal-open');
        }
        
        console.log(`🪟 Modal closed`);
        return true;
    }

    // Close top modal
    function closeTopModal() {
        if (modalHistory.length > 0) {
            const topModal = modalHistory[modalHistory.length - 1];
            closeModal(topModal);
            return true;
        }
        return false;
    }

    // Close all modals
    function closeAllModals() {
        const modalsToClose = Array.from(activeModals);
        modalsToClose.forEach(modal => closeModal(modal));
    }

    // Adjust modal position
    function adjustModalPosition(modal) {
        const content = modal.querySelector('.modal-content, .chat-modal-content');
        if (!content) return;
        
        const rect = content.getBoundingClientRect();
        const viewportHeight = window.innerHeight;
        const viewportWidth = window.innerWidth;
        
        // Center modal if it's smaller than viewport
        if (rect.height < viewportHeight) {
            content.style.marginTop = '0';
            content.style.transform = 'translateY(-50%)';
            content.style.top = '50%';
        } else {
            content.style.top = '20px';
            content.style.transform = 'none';
            content.style.marginTop = '0';
        }
        
        // Adjust width for mobile
        if (viewportWidth < 768) {
            content.style.margin = '10px';
            content.style.width = 'calc(100% - 20px)';
            content.style.maxWidth = 'none';
        }
    }

    // Handle Enter key on inputs
    function handleEnterKeyOnInput(e) {
        const form = e.target.closest('form');
        if (form) {
            const submitButton = form.querySelector('button[type="submit"], input[type="submit"]');
            if (submitButton && !submitButton.disabled) {
                submitButton.click();
            }
        }
    }

    // Show loading state
    function showLoading(element, text = 'Loading...') {
        if (typeof element === 'string') {
            element = document.getElementById(element) || document.querySelector(element);
        }
        
        if (!element) return;
        
        const originalContent = element.innerHTML;
        element.setAttribute('data-original-content', originalContent);
        element.classList.add('loading');
        
        element.innerHTML = `
            <div class="flex items-center justify-center">
                <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600 mr-2"></div>
                ${text}
            </div>
        `;
        
        element.disabled = true;
    }

    // Hide loading state
    function hideLoading(element) {
        if (typeof element === 'string') {
            element = document.getElementById(element) || document.querySelector(element);
        }
        
        if (!element) return;
        
        const originalContent = element.getAttribute('data-original-content');
        if (originalContent) {
            element.innerHTML = originalContent;
            element.removeAttribute('data-original-content');
        }
        
        element.classList.remove('loading');
        element.disabled = false;
    }

    // Show tooltip
    function showTooltip(element, text, position = 'top') {
        if (typeof element === 'string') {
            element = document.getElementById(element) || document.querySelector(element);
        }
        
        if (!element) return;
        
        // Remove existing tooltip
        const existingTooltip = element.querySelector('.tooltip');
        if (existingTooltip) {
            existingTooltip.remove();
        }
        
        const tooltip = document.createElement('div');
        tooltip.className = `tooltip tooltip-${position}`;
        tooltip.textContent = text;
        
        element.style.position = 'relative';
        element.appendChild(tooltip);
        
        setTimeout(() => {
            tooltip.classList.add('active');
        }, 10);
        
        // Auto-hide after 3 seconds
        setTimeout(() => {
            hideTooltip(element);
        }, 3000);
    }

    // Hide tooltip
    function hideTooltip(element) {
        if (typeof element === 'string') {
            element = document.getElementById(element) || document.querySelector(element);
        }
        
        if (!element) return;
        
        const tooltip = element.querySelector('.tooltip');
        if (tooltip) {
            tooltip.classList.remove('active');
            setTimeout(() => {
                tooltip.remove();
            }, 200);
        }
    }

    // Animate element
    function animateElement(element, animation, duration = 300) {
        if (typeof element === 'string') {
            element = document.getElementById(element) || document.querySelector(element);
        }
        
        if (!element) return;
        
        element.style.animation = `${animation} ${duration}ms ease-in-out`;
        
        return new Promise(resolve => {
            setTimeout(() => {
                element.style.animation = '';
                resolve();
            }, duration);
        });
    }

    // Smooth scroll to element
    function scrollToElement(element, offset = 0) {
        if (typeof element === 'string') {
            element = document.getElementById(element) || document.querySelector(element);
        }
        
        if (!element) return;
        
        const targetPosition = element.offsetTop - offset;
        
        window.scrollTo({
            top: targetPosition,
            behavior: 'smooth'
        });
    }

    // Create notification
    function createNotification(message, type = 'info', duration = 5000) {
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.innerHTML = `
            <div class="notification-content">
                <span class="notification-message">${message}</span>
                <button class="notification-close">&times;</button>
            </div>
        `;
        
        // Position notification
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 1000;
            max-width: 400px;
            padding: 16px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
            transform: translateX(100%);
            transition: transform 0.3s ease;
        `;
        
        // Style based on type
        switch (type) {
            case 'success':
                notification.style.background = '#10b981';
                notification.style.color = 'white';
                break;
            case 'error':
                notification.style.background = '#ef4444';
                notification.style.color = 'white';
                break;
            case 'warning':
                notification.style.background = '#f59e0b';
                notification.style.color = 'white';
                break;
            default:
                notification.style.background = '#3b82f6';
                notification.style.color = 'white';
        }
        
        document.body.appendChild(notification);
        
        // Animate in
        setTimeout(() => {
            notification.style.transform = 'translateX(0)';
        }, 10);
        
        // Close functionality
        const closeBtn = notification.querySelector('.notification-close');
        closeBtn.addEventListener('click', () => {
            removeNotification(notification);
        });
        
        // Auto-remove
        if (duration > 0) {
            setTimeout(() => {
                removeNotification(notification);
            }, duration);
        }
        
        return notification;
    }

    // Remove notification
    function removeNotification(notification) {
        notification.style.transform = 'translateX(100%)';
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 300);
    }

    // Public functions for global access
    window.displayListings = function() {
        if (window.ListingsManager) {
            return window.ListingsManager.displayListings();
        }
    };

    window.refreshMapOnly = function() {
        if (window.MapManager) {
            window.MapManager.resizeMap();
            if (window.ListingsManager?.allListings) {
                window.MapManager.updateWithListings(window.ListingsManager.allListings);
            }
        }
    };

    window.applySearchFilters = function() {
        if (window.SearchManager) {
            window.SearchManager.filterListings();
        }
    };

    window.clearSearchFilters = function() {
        if (window.SearchManager) {
            window.SearchManager.clearSearchFilters();
        }
    };

    // Public API
    return {
        initialize,
        openModal,
        closeModal,
        closeTopModal,
        closeAllModals,
        showLoading,
        hideLoading,
        showTooltip,
        hideTooltip,
        animateElement,
        scrollToElement,
        createNotification,
        removeNotification,
        get activeModals() { return Array.from(activeModals); }
    };
})();

// Global UI functions for backward compatibility
window.showModal = function(modalId) {
    return window.UIManager?.openModal(modalId);
};

window.hideModal = function(modalId) {
    return window.UIManager?.closeModal(modalId);
};