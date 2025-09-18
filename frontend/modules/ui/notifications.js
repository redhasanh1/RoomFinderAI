/**
 * Notifications Manager Module
 * Handles error messages, success notifications, warnings, and connection status
 */

class NotificationsManager {
    constructor() {
        this.isInitialized = false;
        this.notifications = new Map();
        this.notificationCounter = 0;
        this.defaultOptions = {
            duration: 5000,
            position: 'top-right',
            showCloseButton: true,
            autoRemove: true
        };
    }

    /**
     * Initialize notifications manager
     */
    init() {
        this.setupStyles();
        this.setupContainer();

        this.isInitialized = true;
        console.log('✅ Notifications Manager initialized');
    }

    /**
     * Setup notification styles
     */
    setupStyles() {
        if (document.getElementById('notification-styles')) return;

        const style = document.createElement('style');
        style.id = 'notification-styles';
        style.textContent = `
            .notification-container {
                position: fixed;
                z-index: 9999;
                pointer-events: none;
                max-width: 400px;
                width: 100%;
            }

            .notification-container.top-right {
                top: 20px;
                right: 20px;
            }

            .notification-container.top-left {
                top: 20px;
                left: 20px;
            }

            .notification-container.bottom-right {
                bottom: 20px;
                right: 20px;
            }

            .notification-container.bottom-left {
                bottom: 20px;
                left: 20px;
            }

            .notification {
                pointer-events: auto;
                margin-bottom: 12px;
                padding: 16px 20px;
                border-radius: 8px;
                box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
                backdrop-filter: blur(10px);
                border: 1px solid rgba(255, 255, 255, 0.2);
                opacity: 0;
                transform: translateX(100%);
                transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
                max-width: 100%;
                word-wrap: break-word;
            }

            .notification.show {
                opacity: 1;
                transform: translateX(0);
            }

            .notification.success {
                background: linear-gradient(135deg, rgba(16, 185, 129, 0.9) 0%, rgba(5, 150, 105, 0.9) 100%);
                color: white;
                border-color: rgba(16, 185, 129, 0.3);
            }

            .notification.error {
                background: linear-gradient(135deg, rgba(239, 68, 68, 0.9) 0%, rgba(220, 38, 38, 0.9) 100%);
                color: white;
                border-color: rgba(239, 68, 68, 0.3);
            }

            .notification.warning {
                background: linear-gradient(135deg, rgba(245, 158, 11, 0.9) 0%, rgba(217, 119, 6, 0.9) 100%);
                color: white;
                border-color: rgba(245, 158, 11, 0.3);
            }

            .notification.info {
                background: linear-gradient(135deg, rgba(59, 130, 246, 0.9) 0%, rgba(37, 99, 235, 0.9) 100%);
                color: white;
                border-color: rgba(59, 130, 246, 0.3);
            }

            .notification-content {
                display: flex;
                align-items: flex-start;
                justify-content: space-between;
                gap: 12px;
            }

            .notification-text {
                flex: 1;
                font-size: 14px;
                line-height: 1.4;
            }

            .notification-title {
                font-weight: 600;
                margin-bottom: 4px;
            }

            .notification-message {
                opacity: 0.9;
            }

            .notification-close {
                background: none;
                border: none;
                color: inherit;
                cursor: pointer;
                font-size: 18px;
                font-weight: bold;
                opacity: 0.7;
                padding: 0;
                line-height: 1;
                transition: opacity 0.2s ease;
                flex-shrink: 0;
            }

            .notification-close:hover {
                opacity: 1;
            }

            .notification-icon {
                font-size: 16px;
                margin-right: 8px;
                flex-shrink: 0;
            }

            @keyframes slideInFromRight {
                from {
                    opacity: 0;
                    transform: translateX(100%);
                }
                to {
                    opacity: 1;
                    transform: translateX(0);
                }
            }

            @keyframes slideOutToRight {
                from {
                    opacity: 1;
                    transform: translateX(0);
                }
                to {
                    opacity: 0;
                    transform: translateX(100%);
                }
            }

            .notification.entering {
                animation: slideInFromRight 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            }

            .notification.exiting {
                animation: slideOutToRight 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            }
        `;
        document.head.appendChild(style);
    }

    /**
     * Setup notification container
     */
    setupContainer() {
        let container = document.getElementById('notification-container');
        if (!container) {
            container = document.createElement('div');
            container.id = 'notification-container';
            container.className = `notification-container ${this.defaultOptions.position}`;
            document.body.appendChild(container);
        }
    }

    /**
     * Show a notification
     */
    show(message, type = 'info', options = {}) {
        const config = { ...this.defaultOptions, ...options };
        const id = `notification-${++this.notificationCounter}`;

        const icons = {
            success: '✅',
            error: '❌',
            warning: '⚠️',
            info: 'ℹ️'
        };

        const container = document.getElementById('notification-container');
        if (!container) {
            this.setupContainer();
        }

        const notification = document.createElement('div');
        notification.id = id;
        notification.className = `notification ${type}`;

        const title = config.title ? `<div class="notification-title">${config.title}</div>` : '';
        const closeButton = config.showCloseButton ?
            `<button class="notification-close" onclick="window.notificationsManager.remove('${id}')">&times;</button>` : '';

        notification.innerHTML = `
            <div class="notification-content">
                <div class="notification-text">
                    ${icons[type] ? `<span class="notification-icon">${icons[type]}</span>` : ''}
                    ${title}
                    <div class="notification-message">${message}</div>
                </div>
                ${closeButton}
            </div>
        `;

        container.appendChild(notification);
        this.notifications.set(id, notification);

        // Trigger animation
        requestAnimationFrame(() => {
            notification.classList.add('show', 'entering');
        });

        // Auto-remove if enabled
        if (config.autoRemove && config.duration > 0) {
            setTimeout(() => {
                this.remove(id);
            }, config.duration);
        }

        console.log(`📢 ${type.toUpperCase()} notification:`, message);
        return id;
    }

    /**
     * Show success notification
     */
    showSuccess(message, options = {}) {
        return this.show(message, 'success', { title: 'Success', ...options });
    }

    /**
     * Show error notification
     */
    showError(message, options = {}) {
        return this.show(message, 'error', {
            title: 'Error',
            duration: 8000, // Longer duration for errors
            ...options
        });
    }

    /**
     * Show warning notification
     */
    showWarning(message, options = {}) {
        return this.show(message, 'warning', { title: 'Warning', ...options });
    }

    /**
     * Show info notification
     */
    showInfo(message, options = {}) {
        return this.show(message, 'info', { title: 'Info', ...options });
    }

    /**
     * Remove a notification
     */
    remove(id) {
        const notification = this.notifications.get(id);
        if (!notification) return;

        notification.classList.add('exiting');
        notification.classList.remove('entering');

        setTimeout(() => {
            if (notification.parentElement) {
                notification.parentElement.removeChild(notification);
            }
            this.notifications.delete(id);
        }, 300);
    }

    /**
     * Clear all notifications
     */
    clearAll() {
        this.notifications.forEach((notification, id) => {
            this.remove(id);
        });
    }

    /**
     * Show connection notification (for chat system)
     */
    showConnectionNotification(message, type = 'info') {
        // Remove existing connection notification
        const existing = document.getElementById('connection-notification');
        if (existing) {
            existing.remove();
        }

        const colors = {
            success: { bg: '#d1fae5', border: '#10b981', text: '#065f46' },
            warning: { bg: '#fef3c7', border: '#f59e0b', text: '#92400e' },
            error: { bg: '#fee2e2', border: '#ef4444', text: '#991b1b' },
            info: { bg: '#dbeafe', border: '#3b82f6', text: '#1e40af' }
        };

        const color = colors[type] || colors.info;

        const notification = document.createElement('div');
        notification.id = 'connection-notification';
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            left: 50%;
            transform: translateX(-50%);
            background-color: ${color.bg};
            border: 2px solid ${color.border};
            color: ${color.text};
            padding: 12px 24px;
            border-radius: 8px;
            font-weight: 500;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
            z-index: 10000;
            max-width: 400px;
            text-align: center;
            font-size: 14px;
        `;

        notification.innerHTML = `
            <div style="display: flex; align-items: center; justify-content: space-between;">
                <span>${message}</span>
                <button onclick="this.parentElement.parentElement.remove()"
                        style="background: none; border: none; color: inherit; font-size: 18px;
                               font-weight: bold; cursor: pointer; margin-left: 12px; opacity: 0.7;">
                    &times;
                </button>
            </div>
        `;

        document.body.appendChild(notification);

        // Auto-remove after delay
        const autoRemoveDelay = (type === 'success' || type === 'info') ? 5000 : 10000;
        setTimeout(() => {
            if (notification.parentElement) {
                notification.remove();
            }
        }, autoRemoveDelay);

        console.log(`🔗 Connection notification (${type}):`, message);
    }

    /**
     * Show chat system error
     */
    showChatSystemError() {
        const errorContainer = document.getElementById('chatMessages') || document.body;

        // Remove existing error
        const existingError = document.getElementById('chat-system-error');
        if (existingError) {
            existingError.remove();
        }

        const errorDiv = document.createElement('div');
        errorDiv.id = 'chat-system-error';
        errorDiv.style.cssText = `
            background: #fee2e2;
            border: 2px solid #ef4444;
            color: #991b1b;
            padding: 16px;
            margin: 12px;
            border-radius: 8px;
            font-weight: 500;
        `;

        errorDiv.innerHTML = `
            <strong>⚠️ Chat System Error</strong><br>
            The chat system is currently experiencing issues. Features may not work properly.<br><br>
            <div style="margin-top: 8px;">
                <button onclick="window.retryChatSetup()"
                        style="background: #dc2626; color: white; padding: 6px 12px; border: none;
                               border-radius: 4px; cursor: pointer; margin-right: 8px;">
                    🔄 Retry Setup
                </button>
                <button onclick="window.runChatDiagnostics()"
                        style="background: #6b7280; color: white; padding: 6px 12px; border: none;
                               border-radius: 4px; cursor: pointer;">
                    🔍 Run Diagnostics
                </button>
            </div>
        `;

        errorContainer.appendChild(errorDiv);
        console.log('🚨 Chat system error displayed to user');
    }

    /**
     * Show map error
     */
    showMapError(message = 'Failed to load map. Please check your connection or try again later.') {
        const mapError = document.getElementById('map-error');
        if (mapError) {
            mapError.textContent = message;
            mapError.style.display = 'block';
            mapError.classList.remove('hidden');
        } else {
            this.showError(message, { title: 'Map Error' });
        }
    }

    /**
     * Hide map error
     */
    hideMapError() {
        const mapError = document.getElementById('map-error');
        if (mapError) {
            mapError.style.display = 'none';
            mapError.classList.add('hidden');
        }
    }

    /**
     * Show loading notification
     */
    showLoading(message = 'Loading...', options = {}) {
        const loadingIcon = '⏳';
        return this.show(`${loadingIcon} ${message}`, 'info', {
            autoRemove: false,
            showCloseButton: false,
            ...options
        });
    }

    /**
     * Update notification content
     */
    update(id, message, type = null) {
        const notification = this.notifications.get(id);
        if (!notification) return;

        const messageElement = notification.querySelector('.notification-message');
        if (messageElement) {
            messageElement.textContent = message;
        }

        if (type) {
            notification.className = `notification ${type} show`;
        }
    }

    /**
     * Get notification count by type
     */
    getCount(type = null) {
        if (!type) {
            return this.notifications.size;
        }

        let count = 0;
        this.notifications.forEach(notification => {
            if (notification.classList.contains(type)) {
                count++;
            }
        });
        return count;
    }

    /**
     * Destroy notifications manager
     */
    destroy() {
        this.clearAll();
        const container = document.getElementById('notification-container');
        if (container) {
            container.remove();
        }
        this.isInitialized = false;
        console.log('🗑️ Notifications Manager destroyed');
    }
}

// Create global instance
window.notificationsManager = new NotificationsManager();

// Global functions for backward compatibility
window.showError = (message, options = {}) => {
    return window.notificationsManager ?
        window.notificationsManager.showError(message, options) :
        console.error(message);
};

window.showSuccess = (message, options = {}) => {
    return window.notificationsManager ?
        window.notificationsManager.showSuccess(message, options) :
        console.log(message);
};

window.showWarning = (message, options = {}) => {
    return window.notificationsManager ?
        window.notificationsManager.showWarning(message, options) :
        console.warn(message);
};

window.showInfo = (message, options = {}) => {
    return window.notificationsManager ?
        window.notificationsManager.showInfo(message, options) :
        console.info(message);
};

window.showConnectionNotification = (message, type = 'info') => {
    if (window.notificationsManager) {
        window.notificationsManager.showConnectionNotification(message, type);
    }
};

window.showMapError = (message) => {
    if (window.notificationsManager) {
        window.notificationsManager.showMapError(message);
    }
};

window.hideMapError = () => {
    if (window.notificationsManager) {
        window.notificationsManager.hideMapError();
    }
};

// Legacy alert replacement
const originalAlert = window.alert;
window.alert = function(message) {
    if (window.notificationsManager && window.notificationsManager.isInitialized) {
        // For error-like messages, show as error notification
        if (message.toLowerCase().includes('error') || message.toLowerCase().includes('failed')) {
            window.notificationsManager.showError(message);
        } else {
            window.notificationsManager.showInfo(message);
        }
    } else {
        originalAlert(message);
    }
};

export default window.notificationsManager;