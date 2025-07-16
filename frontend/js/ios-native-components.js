// iOS Native Components JavaScript Framework
// Transforms web components to look and behave like native iOS elements

import { Haptics, ImpactStyle } from '@capacitor/haptics';
import { StatusBar, Style } from '@capacitor/status-bar';

class IOSNativeComponents {
    constructor() {
        this.isIOS = window.Capacitor && window.Capacitor.getPlatform() === 'ios';
        this.initializeIOSBehaviors();
    }

    initializeIOSBehaviors() {
        if (!this.isIOS) return;

        // Set status bar style
        StatusBar.setStyle({ style: Style.Default });

        // Add iOS-specific touch behaviors
        this.setupHapticFeedback();
        this.setupIOSScrollBehavior();
        this.setupIOSKeyboard();
    }

    // Haptic Feedback Integration
    setupHapticFeedback() {
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('ios-haptic-light')) {
                Haptics.impact({ style: ImpactStyle.Light });
            } else if (e.target.classList.contains('ios-haptic-medium')) {
                Haptics.impact({ style: ImpactStyle.Medium });
            } else if (e.target.classList.contains('ios-haptic-heavy')) {
                Haptics.impact({ style: ImpactStyle.Heavy });
            }
        });
    }

    // iOS Scroll Behavior
    setupIOSScrollBehavior() {
        // Enable momentum scrolling
        document.body.style.webkitOverflowScrolling = 'touch';
        
        // Disable bounce on main container
        document.addEventListener('touchmove', (e) => {
            if (e.target.classList.contains('ios-no-bounce')) {
                e.preventDefault();
            }
        }, { passive: false });
    }

    // iOS Keyboard Handling
    setupIOSKeyboard() {
        // Adjust viewport when keyboard appears
        window.addEventListener('keyboardWillShow', (e) => {
            document.body.style.height = `${window.innerHeight - e.keyboardHeight}px`;
        });

        window.addEventListener('keyboardWillHide', () => {
            document.body.style.height = '100vh';
        });
    }

    // Create iOS Navigation Bar
    createNavigationBar(options = {}) {
        const {
            title = '',
            leftButton = null,
            rightButton = null,
            backgroundColor = 'var(--ios-background)',
            large = false
        } = options;

        const navbar = document.createElement('div');
        navbar.className = `ios-navbar ${large ? 'ios-navbar-large' : ''}`;
        navbar.style.backgroundColor = backgroundColor;

        // Left button
        if (leftButton) {
            const leftBtn = document.createElement('button');
            leftBtn.className = 'ios-navbar-button ios-haptic-light';
            leftBtn.innerHTML = leftButton.text || '‹ Back';
            leftBtn.onclick = leftButton.action || (() => history.back());
            navbar.appendChild(leftBtn);
        } else {
            navbar.appendChild(document.createElement('div'));
        }

        // Title
        const titleElement = document.createElement('h1');
        titleElement.className = large ? 'ios-large-title' : 'ios-navbar-title';
        titleElement.textContent = title;
        navbar.appendChild(titleElement);

        // Right button
        if (rightButton) {
            const rightBtn = document.createElement('button');
            rightBtn.className = 'ios-navbar-button ios-haptic-light';
            rightBtn.innerHTML = rightButton.text || 'Done';
            rightBtn.onclick = rightButton.action || (() => {});
            navbar.appendChild(rightBtn);
        } else {
            navbar.appendChild(document.createElement('div'));
        }

        return navbar;
    }

    // Create iOS Button
    createButton(options = {}) {
        const {
            text = 'Button',
            type = 'primary',
            size = 'medium',
            disabled = false,
            icon = null,
            action = () => {}
        } = options;

        const button = document.createElement('button');
        button.className = `ios-button ios-button-${type} ios-button-${size} ios-haptic-medium`;
        button.disabled = disabled;
        button.onclick = action;

        if (icon) {
            const iconElement = document.createElement('span');
            iconElement.className = 'ios-button-icon';
            iconElement.innerHTML = icon;
            button.appendChild(iconElement);
        }

        const textElement = document.createElement('span');
        textElement.textContent = text;
        button.appendChild(textElement);

        return button;
    }

    // Create iOS List
    createList(items = [], options = {}) {
        const {
            showChevron = true,
            selectable = true,
            onItemSelect = () => {}
        } = options;

        const list = document.createElement('div');
        list.className = 'ios-list';

        items.forEach((item, index) => {
            const listItem = document.createElement('div');
            listItem.className = `ios-list-item ${selectable ? 'ios-haptic-light' : ''}`;
            
            if (selectable) {
                listItem.onclick = () => onItemSelect(item, index);
            }

            const content = document.createElement('div');
            content.className = 'ios-list-item-content';

            const title = document.createElement('div');
            title.className = 'ios-list-item-title';
            title.textContent = item.title || item.text || item;

            content.appendChild(title);

            if (item.subtitle) {
                const subtitle = document.createElement('div');
                subtitle.className = 'ios-list-item-subtitle';
                subtitle.textContent = item.subtitle;
                content.appendChild(subtitle);
            }

            listItem.appendChild(content);

            if (showChevron) {
                const chevron = document.createElement('div');
                chevron.className = 'ios-list-item-chevron';
                listItem.appendChild(chevron);
            }

            list.appendChild(listItem);
        });

        return list;
    }

    // Create iOS Modal
    createModal(options = {}) {
        const {
            title = 'Modal',
            content = '',
            showCloseButton = true,
            onClose = () => {}
        } = options;

        const overlay = document.createElement('div');
        overlay.className = 'ios-modal-overlay';
        overlay.onclick = (e) => {
            if (e.target === overlay) {
                this.closeModal(overlay);
                onClose();
            }
        };

        const modal = document.createElement('div');
        modal.className = 'ios-modal ios-slide-up';

        const header = document.createElement('div');
        header.className = 'ios-modal-header';

        const titleElement = document.createElement('h2');
        titleElement.className = 'ios-modal-title';
        titleElement.textContent = title;
        header.appendChild(titleElement);

        if (showCloseButton) {
            const closeButton = document.createElement('button');
            closeButton.className = 'ios-modal-close ios-haptic-light';
            closeButton.textContent = 'Done';
            closeButton.onclick = () => {
                this.closeModal(overlay);
                onClose();
            };
            header.appendChild(closeButton);
        }

        const contentElement = document.createElement('div');
        contentElement.className = 'ios-modal-content';
        contentElement.innerHTML = content;

        modal.appendChild(header);
        modal.appendChild(contentElement);
        overlay.appendChild(modal);

        return overlay;
    }

    // Show Modal
    showModal(modal) {
        document.body.appendChild(modal);
        setTimeout(() => modal.classList.add('show'), 10);
    }

    // Close Modal
    closeModal(modal) {
        modal.classList.remove('show');
        setTimeout(() => {
            if (modal.parentNode) {
                modal.parentNode.removeChild(modal);
            }
        }, 300);
    }

    // Create iOS Tab Bar
    createTabBar(tabs = [], options = {}) {
        const {
            activeTab = 0,
            onTabChange = () => {}
        } = options;

        const tabBar = document.createElement('div');
        tabBar.className = 'ios-tab-bar';

        tabs.forEach((tab, index) => {
            const tabItem = document.createElement('div');
            tabItem.className = `ios-tab-item ${index === activeTab ? 'active' : ''} ios-haptic-light`;
            
            const icon = document.createElement('div');
            icon.className = 'ios-tab-icon';
            icon.innerHTML = tab.icon || '●';
            
            const label = document.createElement('div');
            label.className = 'ios-tab-label';
            label.textContent = tab.label || tab.title;
            
            tabItem.appendChild(icon);
            tabItem.appendChild(label);
            
            tabItem.onclick = () => {
                // Update active state
                tabBar.querySelectorAll('.ios-tab-item').forEach(item => {
                    item.classList.remove('active');
                });
                tabItem.classList.add('active');
                
                onTabChange(tab, index);
            };
            
            tabBar.appendChild(tabItem);
        });

        return tabBar;
    }

    // Create iOS Form Input
    createInput(options = {}) {
        const {
            type = 'text',
            placeholder = '',
            value = '',
            label = '',
            required = false,
            validation = null
        } = options;

        const container = document.createElement('div');
        container.className = 'ios-input-container';

        if (label) {
            const labelElement = document.createElement('label');
            labelElement.className = 'ios-input-label';
            labelElement.textContent = label;
            container.appendChild(labelElement);
        }

        const input = document.createElement('input');
        input.type = type;
        input.className = 'ios-input';
        input.placeholder = placeholder;
        input.value = value;
        input.required = required;

        if (validation) {
            input.addEventListener('blur', () => {
                const isValid = validation(input.value);
                input.classList.toggle('ios-input-error', !isValid);
            });
        }

        container.appendChild(input);
        return container;
    }

    // Create iOS Switch
    createSwitch(options = {}) {
        const {
            checked = false,
            label = '',
            onChange = () => {}
        } = options;

        const container = document.createElement('div');
        container.className = 'ios-switch-container';

        if (label) {
            const labelElement = document.createElement('label');
            labelElement.className = 'ios-switch-label';
            labelElement.textContent = label;
            container.appendChild(labelElement);
        }

        const switchElement = document.createElement('label');
        switchElement.className = 'ios-switch';

        const input = document.createElement('input');
        input.type = 'checkbox';
        input.checked = checked;
        input.onchange = (e) => {
            Haptics.impact({ style: ImpactStyle.Light });
            onChange(e.target.checked);
        };

        const slider = document.createElement('span');
        slider.className = 'ios-switch-slider';

        switchElement.appendChild(input);
        switchElement.appendChild(slider);
        container.appendChild(switchElement);

        return container;
    }

    // Create iOS Segmented Control
    createSegmentedControl(options = {}) {
        const {
            segments = [],
            selectedIndex = 0,
            onChange = () => {}
        } = options;

        const container = document.createElement('div');
        container.className = 'ios-segmented-control';

        segments.forEach((segment, index) => {
            const option = document.createElement('div');
            option.className = `ios-segmented-option ${index === selectedIndex ? 'active' : ''} ios-haptic-light`;
            option.textContent = segment.title || segment;
            
            option.onclick = () => {
                container.querySelectorAll('.ios-segmented-option').forEach(opt => {
                    opt.classList.remove('active');
                });
                option.classList.add('active');
                onChange(segment, index);
            };
            
            container.appendChild(option);
        });

        return container;
    }

    // Create iOS Activity Indicator
    createActivityIndicator(options = {}) {
        const {
            size = 'medium',
            color = 'var(--ios-blue)'
        } = options;

        const spinner = document.createElement('div');
        spinner.className = `ios-spinner ios-spinner-${size}`;
        spinner.style.borderTopColor = color;

        return spinner;
    }

    // Create iOS Alert
    showAlert(options = {}) {
        const {
            title = 'Alert',
            message = '',
            buttons = [{ text: 'OK', action: () => {} }]
        } = options;

        const overlay = document.createElement('div');
        overlay.className = 'ios-alert-overlay';
        overlay.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.4);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 3000;
        `;

        const alert = document.createElement('div');
        alert.className = 'ios-alert';
        alert.style.cssText = `
            background: var(--ios-background);
            border-radius: 14px;
            width: 280px;
            text-align: center;
            overflow: hidden;
        `;

        const content = document.createElement('div');
        content.style.padding = '20px';

        const titleElement = document.createElement('h3');
        titleElement.style.cssText = `
            margin: 0 0 10px 0;
            font-size: 17px;
            font-weight: 600;
            color: var(--ios-label);
        `;
        titleElement.textContent = title;
        content.appendChild(titleElement);

        if (message) {
            const messageElement = document.createElement('p');
            messageElement.style.cssText = `
                margin: 0;
                font-size: 13px;
                color: var(--ios-label);
                line-height: 1.4;
            `;
            messageElement.textContent = message;
            content.appendChild(messageElement);
        }

        alert.appendChild(content);

        const buttonContainer = document.createElement('div');
        buttonContainer.style.cssText = `
            display: flex;
            border-top: 0.5px solid var(--ios-separator);
        `;

        buttons.forEach((button, index) => {
            const btn = document.createElement('button');
            btn.style.cssText = `
                flex: 1;
                padding: 12px;
                border: none;
                background: none;
                color: var(--ios-blue);
                font-size: 17px;
                cursor: pointer;
                ${index > 0 ? 'border-left: 0.5px solid var(--ios-separator);' : ''}
            `;
            btn.textContent = button.text;
            btn.onclick = () => {
                document.body.removeChild(overlay);
                if (button.action) button.action();
            };
            buttonContainer.appendChild(btn);
        });

        alert.appendChild(buttonContainer);
        overlay.appendChild(alert);
        document.body.appendChild(overlay);

        return overlay;
    }

    // Utility: Add safe area padding
    addSafeArea(element, areas = ['top', 'bottom']) {
        areas.forEach(area => {
            element.classList.add(`ios-safe-area-${area}`);
        });
    }

    // Utility: Enable pull to refresh
    enablePullToRefresh(container, onRefresh) {
        let startY = 0;
        let pullDistance = 0;
        let isRefreshing = false;

        container.addEventListener('touchstart', (e) => {
            startY = e.touches[0].clientY;
        });

        container.addEventListener('touchmove', (e) => {
            if (isRefreshing) return;
            
            const currentY = e.touches[0].clientY;
            pullDistance = currentY - startY;
            
            if (pullDistance > 0 && container.scrollTop === 0) {
                e.preventDefault();
                container.style.transform = `translateY(${Math.min(pullDistance * 0.5, 60)}px)`;
            }
        });

        container.addEventListener('touchend', () => {
            if (pullDistance > 60 && !isRefreshing) {
                isRefreshing = true;
                onRefresh(() => {
                    isRefreshing = false;
                    container.style.transform = 'translateY(0)';
                });
            } else {
                container.style.transform = 'translateY(0)';
            }
            pullDistance = 0;
        });
    }
}

// Initialize iOS Native Components
const iosComponents = new IOSNativeComponents();

// Global access
window.iosComponents = iosComponents;

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = IOSNativeComponents;
}

export default IOSNativeComponents;