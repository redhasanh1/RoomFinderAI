/**
 * Modal Component Module
 * Handles modal dialogs, popups, and overlays
 */

class ModalManager {
    constructor() {
        this.activeModals = new Set();
        this.isInitialized = false;
        this.modalStack = [];
        
        console.log('🪟 Modal Manager initialized');
    }
    
    /**
     * Initialize modal system
     */
    initialize() {
        try {
            this.setupEventListeners();
            this.setupKeyboardControls();
            this.findExistingModals();
            
            this.isInitialized = true;
            console.log('✅ Modal system initialized');
            return true;
        } catch (error) {
            console.error('❌ Modal initialization failed:', error);
            return false;
        }
    }
    
    /**
     * Setup global event listeners
     */
    setupEventListeners() {
        // Close modal when clicking outside
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal')) {
                this.closeModal(e.target);
            }
        });
        
        // Close button handlers
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('close-button') || 
                e.target.classList.contains('modal-close')) {
                const modal = e.target.closest('.modal');
                if (modal) {
                    this.closeModal(modal);
                }
            }
        });
        
        // Cancel button handlers
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal-cancel')) {
                const modal = e.target.closest('.modal');
                if (modal) {
                    this.closeModal(modal);
                }
            }
        });
    }
    
    /**
     * Setup keyboard controls
     */
    setupKeyboardControls() {
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.closeTopModal();
            }
            
            // Tab trapping for modals
            if (e.key === 'Tab' && this.activeModals.size > 0) {
                this.handleTabTrapping(e);
            }
        });
    }
    
    /**
     * Find and register existing modals
     */
    findExistingModals() {
        const modals = document.querySelectorAll('.modal');
        modals.forEach(modal => {
            this.registerModal(modal);
        });
    }
    
    /**
     * Register a modal for management
     */
    registerModal(modalElement) {
        if (!modalElement.id) {
            modalElement.id = `modal-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
        }
        
        // Add data attributes for tracking
        modalElement.dataset.modalRegistered = 'true';
        
        console.log('📝 Modal registered:', modalElement.id);
    }
    
    /**
     * Create a new modal
     */
    createModal(options = {}) {
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.id = options.id || `modal-${Date.now()}`;
        
        const modalContent = document.createElement('div');
        modalContent.className = 'modal-content';
        
        // Add header if title provided
        if (options.title) {
            const header = this.createModalHeader(options.title, options.showCloseButton !== false);
            modalContent.appendChild(header);
        }
        
        // Add body
        const body = document.createElement('div');
        body.className = 'modal-body';
        if (options.content) {
            if (typeof options.content === 'string') {
                body.innerHTML = options.content;
            } else {
                body.appendChild(options.content);
            }
        }
        modalContent.appendChild(body);
        
        // Add footer if buttons provided
        if (options.buttons && options.buttons.length > 0) {
            const footer = this.createModalFooter(options.buttons);
            modalContent.appendChild(footer);
        }
        
        modal.appendChild(modalContent);
        document.body.appendChild(modal);
        
        this.registerModal(modal);
        
        console.log('✨ Modal created:', modal.id);
        return modal;
    }
    
    /**
     * Create modal header
     */
    createModalHeader(title, showCloseButton = true) {
        const header = document.createElement('div');
        header.className = 'modal-header';
        
        const titleElement = document.createElement('h2');
        titleElement.className = 'modal-title';
        titleElement.textContent = title;
        header.appendChild(titleElement);
        
        if (showCloseButton) {
            const closeButton = document.createElement('button');
            closeButton.className = 'close-button';
            closeButton.innerHTML = '×';
            closeButton.setAttribute('aria-label', 'Close modal');
            header.appendChild(closeButton);
        }
        
        return header;
    }
    
    /**
     * Create modal footer
     */
    createModalFooter(buttons) {
        const footer = document.createElement('div');
        footer.className = 'modal-footer';
        
        buttons.forEach(buttonConfig => {
            const button = document.createElement('button');
            button.className = buttonConfig.className || 'modal-btn';
            button.textContent = buttonConfig.text || buttonConfig.label;
            
            if (buttonConfig.click) {
                button.addEventListener('click', buttonConfig.click);
            }
            
            if (buttonConfig.type === 'primary') {
                button.classList.add('primary');
            }
            
            footer.appendChild(button);
        });
        
        return footer;
    }
    
    /**
     * Show a modal
     */
    showModal(modalElement, options = {}) {
        if (typeof modalElement === 'string') {
            modalElement = document.getElementById(modalElement);
        }
        
        if (!modalElement) {
            console.error('❌ Modal element not found');
            return false;
        }
        
        // Register if not already registered
        if (!modalElement.dataset.modalRegistered) {
            this.registerModal(modalElement);
        }
        
        // Add to active modals
        this.activeModals.add(modalElement);
        this.modalStack.push(modalElement);
        
        // Set z-index for stacking
        const zIndex = 1000 + this.modalStack.length;
        modalElement.style.zIndex = zIndex;
        
        // Show modal
        modalElement.classList.add('active');
        
        // Prevent body scroll
        if (this.activeModals.size === 1) {
            document.body.style.overflow = 'hidden';
        }
        
        // Focus management
        this.focusModal(modalElement);
        
        // Auto-close timer
        if (options.autoClose) {
            setTimeout(() => {
                this.closeModal(modalElement);
            }, options.autoClose);
        }
        
        // Trigger event
        modalElement.dispatchEvent(new CustomEvent('modalShown'));
        
        console.log('🔓 Modal shown:', modalElement.id);
        return true;
    }
    
    /**
     * Close a modal
     */
    closeModal(modalElement) {
        if (typeof modalElement === 'string') {
            modalElement = document.getElementById(modalElement);
        }
        
        if (!modalElement || !this.activeModals.has(modalElement)) {
            return false;
        }
        
        // Remove from active modals
        this.activeModals.delete(modalElement);
        const stackIndex = this.modalStack.indexOf(modalElement);
        if (stackIndex > -1) {
            this.modalStack.splice(stackIndex, 1);
        }
        
        // Hide modal
        modalElement.classList.remove('active');
        
        // Restore body scroll if no more modals
        if (this.activeModals.size === 0) {
            document.body.style.overflow = '';
        }
        
        // Focus management
        this.restoreFocus();
        
        // Trigger event
        modalElement.dispatchEvent(new CustomEvent('modalClosed'));
        
        console.log('🔒 Modal closed:', modalElement.id);
        return true;
    }
    
    /**
     * Close the topmost modal
     */
    closeTopModal() {
        if (this.modalStack.length > 0) {
            const topModal = this.modalStack[this.modalStack.length - 1];
            this.closeModal(topModal);
        }
    }
    
    /**
     * Close all modals
     */
    closeAllModals() {
        const modalsToClose = [...this.activeModals];
        modalsToClose.forEach(modal => {
            this.closeModal(modal);
        });
    }
    
    /**
     * Focus management for modals
     */
    focusModal(modalElement) {
        // Find first focusable element
        const focusableElements = modalElement.querySelectorAll(
            'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
        );
        
        if (focusableElements.length > 0) {
            focusableElements[0].focus();
        }
    }
    
    /**
     * Restore focus after closing modal
     */
    restoreFocus() {
        if (this.modalStack.length > 0) {
            // Focus the next modal in stack
            this.focusModal(this.modalStack[this.modalStack.length - 1]);
        } else {
            // Focus the previously focused element or document body
            document.body.focus();
        }
    }
    
    /**
     * Handle tab trapping within modals
     */
    handleTabTrapping(e) {
        if (this.modalStack.length === 0) return;
        
        const modal = this.modalStack[this.modalStack.length - 1];
        const focusableElements = modal.querySelectorAll(
            'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
        );
        
        if (focusableElements.length === 0) return;
        
        const firstElement = focusableElements[0];
        const lastElement = focusableElements[focusableElements.length - 1];
        
        if (e.shiftKey && document.activeElement === firstElement) {
            e.preventDefault();
            lastElement.focus();
        } else if (!e.shiftKey && document.activeElement === lastElement) {
            e.preventDefault();
            firstElement.focus();
        }
    }
    
    /**
     * Show confirmation dialog
     */
    showConfirmation(message, title = 'Confirm', options = {}) {
        return new Promise((resolve) => {
            const modal = this.createModal({
                id: 'confirmation-modal',
                title: title,
                content: `<p>${this.escapeHtml(message)}</p>`,
                buttons: [
                    {
                        text: options.cancelText || 'Cancel',
                        className: 'modal-btn secondary',
                        click: () => {
                            this.closeModal(modal);
                            resolve(false);
                        }
                    },
                    {
                        text: options.confirmText || 'Confirm',
                        className: 'modal-btn primary',
                        click: () => {
                            this.closeModal(modal);
                            resolve(true);
                        }
                    }
                ]
            });
            
            this.showModal(modal);
            
            // Auto-resolve on modal close
            modal.addEventListener('modalClosed', () => {
                resolve(false);
                document.body.removeChild(modal);
            });
        });
    }
    
    /**
     * Show alert dialog
     */
    showAlert(message, title = 'Alert', options = {}) {
        return new Promise((resolve) => {
            const modal = this.createModal({
                id: 'alert-modal',
                title: title,
                content: `<p>${this.escapeHtml(message)}</p>`,
                buttons: [
                    {
                        text: options.buttonText || 'OK',
                        className: 'modal-btn primary',
                        click: () => {
                            this.closeModal(modal);
                            resolve();
                        }
                    }
                ]
            });
            
            this.showModal(modal);
            
            // Auto-resolve on modal close
            modal.addEventListener('modalClosed', () => {
                resolve();
                document.body.removeChild(modal);
            });
        });
    }
    
    /**
     * Show loading modal
     */
    showLoading(message = 'Loading...', options = {}) {
        const modal = this.createModal({
            id: 'loading-modal',
            content: `
                <div class="loading-content">
                    <div class="loading-spinner"></div>
                    <p>${this.escapeHtml(message)}</p>
                </div>
            `,
            showCloseButton: false
        });
        
        modal.classList.add('loading-modal');
        this.showModal(modal);
        
        return modal;
    }
    
    /**
     * Hide loading modal
     */
    hideLoading() {
        const loadingModal = document.getElementById('loading-modal');
        if (loadingModal) {
            this.closeModal(loadingModal);
            document.body.removeChild(loadingModal);
        }
    }
    
    /**
     * Check if any modal is active
     */
    hasActiveModal() {
        return this.activeModals.size > 0;
    }
    
    /**
     * Get active modals
     */
    getActiveModals() {
        return [...this.activeModals];
    }
    
    /**
     * Utility function to escape HTML
     */
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
    
    /**
     * Cleanup
     */
    cleanup() {
        this.closeAllModals();
        this.activeModals.clear();
        this.modalStack = [];
        this.isInitialized = false;
        
        console.log('🧹 Modal system cleaned up');
    }
}

// Global modal manager instance
let globalModalManager = null;

/**
 * Initialize modal system (backward compatibility)
 */
function initializeModals() {
    if (!globalModalManager) {
        globalModalManager = new ModalManager();
    }
    
    return globalModalManager.initialize();
}

/**
 * Show modal (backward compatibility)
 */
function showModal(modalElement, options = {}) {
    if (globalModalManager) {
        return globalModalManager.showModal(modalElement, options);
    }
    return false;
}

/**
 * Close modal (backward compatibility)
 */
function closeModal(modalElement) {
    if (globalModalManager) {
        return globalModalManager.closeModal(modalElement);
    }
    return false;
}

/**
 * Show confirmation (backward compatibility)
 */
function showConfirmation(message, title, options) {
    if (globalModalManager) {
        return globalModalManager.showConfirmation(message, title, options);
    }
    return Promise.resolve(false);
}

/**
 * Show alert (backward compatibility)
 */
function showAlert(message, title, options) {
    if (globalModalManager) {
        return globalModalManager.showAlert(message, title, options);
    }
    return Promise.resolve();
}

// Export for ES6 modules
export {
    ModalManager,
    initializeModals,
    showModal,
    closeModal,
    showConfirmation,
    showAlert
};

// Export to window for backward compatibility
window.ModalManager = ModalManager;
window.initializeModals = initializeModals;
window.showModal = showModal;
window.closeModal = closeModal;
window.showConfirmation = showConfirmation;
window.showAlert = showAlert;
window.globalModalManager = () => globalModalManager;