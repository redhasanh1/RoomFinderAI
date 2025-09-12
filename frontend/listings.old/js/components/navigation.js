/**
 * Navigation Component Module
 * Handles navigation functionality, dropdowns, and mobile menu
 */

class NavigationManager {
    constructor() {
        this.isInitialized = false;
        this.dropdownTimeouts = new Map();
        this.mobileMenuOpen = false;
        
        console.log('🧭 Navigation Manager initialized');
    }
    
    /**
     * Initialize navigation
     */
    initialize() {
        try {
            this.setupDropdowns();
            this.setupMobileMenu();
            this.setupKeyboardNavigation();
            
            this.isInitialized = true;
            console.log('✅ Navigation initialized');
            return true;
        } catch (error) {
            console.error('❌ Navigation initialization failed:', error);
            return false;
        }
    }
    
    /**
     * Setup dropdown functionality
     */
    setupDropdowns() {
        const dropdowns = document.querySelectorAll('.dropdown');
        
        dropdowns.forEach(dropdown => {
            const trigger = dropdown.querySelector('.dropdown-trigger');
            const menu = dropdown.querySelector('.dropdown-menu');
            
            if (trigger && menu) {
                // Mouse events
                dropdown.addEventListener('mouseenter', () => {
                    this.showDropdown(dropdown);
                });
                
                dropdown.addEventListener('mouseleave', () => {
                    this.hideDropdown(dropdown);
                });
                
                // Click events for mobile
                trigger.addEventListener('click', (e) => {
                    e.preventDefault();
                    this.toggleDropdown(dropdown);
                });
                
                // Close on escape
                document.addEventListener('keydown', (e) => {
                    if (e.key === 'Escape') {
                        this.hideAllDropdowns();
                    }
                });
            }
        });
        
        // Close dropdowns when clicking outside
        document.addEventListener('click', (e) => {
            if (!e.target.closest('.dropdown')) {
                this.hideAllDropdowns();
            }
        });
    }
    
    /**
     * Setup mobile menu
     */
    setupMobileMenu() {
        const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
        const mobileMenu = document.querySelector('.mobile-menu');
        const mobileMenuClose = document.querySelector('.mobile-menu-close');
        const mobileMenuOverlay = document.querySelector('.mobile-menu-overlay');
        
        if (mobileMenuBtn) {
            mobileMenuBtn.addEventListener('click', () => {
                this.toggleMobileMenu();
            });
        }
        
        if (mobileMenuClose) {
            mobileMenuClose.addEventListener('click', () => {
                this.closeMobileMenu();
            });
        }
        
        if (mobileMenuOverlay) {
            mobileMenuOverlay.addEventListener('click', () => {
                this.closeMobileMenu();
            });
        }
        
        // Setup mobile sections
        const mobileSections = document.querySelectorAll('.mobile-section-header');
        mobileSections.forEach(header => {
            header.addEventListener('click', () => {
                this.toggleMobileSection(header);
            });
        });
        
        // Close mobile menu on escape
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.mobileMenuOpen) {
                this.closeMobileMenu();
            }
        });
    }
    
    /**
     * Setup keyboard navigation
     */
    setupKeyboardNavigation() {
        // Tab navigation for dropdowns
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Tab') {
                // Close dropdowns when tabbing away
                setTimeout(() => {
                    const focusedElement = document.activeElement;
                    const isInDropdown = focusedElement.closest('.dropdown');
                    
                    if (!isInDropdown) {
                        this.hideAllDropdowns();
                    }
                }, 0);
            }
        });
    }
    
    /**
     * Show dropdown
     */
    showDropdown(dropdown) {
        const menu = dropdown.querySelector('.dropdown-menu');
        const arrow = dropdown.querySelector('.dropdown-arrow');
        
        if (menu) {
            // Clear hide timeout
            if (this.dropdownTimeouts.has(dropdown)) {
                clearTimeout(this.dropdownTimeouts.get(dropdown));
                this.dropdownTimeouts.delete(dropdown);
            }
            
            menu.style.opacity = '1';
            menu.style.visibility = 'visible';
            menu.style.transform = 'translateY(0)';
            
            if (arrow) {
                arrow.style.transform = 'rotate(180deg)';
            }
        }
    }
    
    /**
     * Hide dropdown
     */
    hideDropdown(dropdown, delay = 100) {
        const menu = dropdown.querySelector('.dropdown-menu');
        const arrow = dropdown.querySelector('.dropdown-arrow');
        
        if (menu) {
            const timeout = setTimeout(() => {
                menu.style.opacity = '0';
                menu.style.visibility = 'hidden';
                menu.style.transform = 'translateY(-10px)';
                
                if (arrow) {
                    arrow.style.transform = 'rotate(0deg)';
                }
                
                this.dropdownTimeouts.delete(dropdown);
            }, delay);
            
            this.dropdownTimeouts.set(dropdown, timeout);
        }
    }
    
    /**
     * Toggle dropdown
     */
    toggleDropdown(dropdown) {
        const menu = dropdown.querySelector('.dropdown-menu');
        
        if (menu) {
            const isVisible = menu.style.visibility === 'visible' || 
                             window.getComputedStyle(menu).visibility === 'visible';
            
            if (isVisible) {
                this.hideDropdown(dropdown, 0);
            } else {
                this.hideAllDropdowns();
                this.showDropdown(dropdown);
            }
        }
    }
    
    /**
     * Hide all dropdowns
     */
    hideAllDropdowns() {
        const dropdowns = document.querySelectorAll('.dropdown');
        dropdowns.forEach(dropdown => {
            this.hideDropdown(dropdown, 0);
        });
    }
    
    /**
     * Toggle mobile menu
     */
    toggleMobileMenu() {
        if (this.mobileMenuOpen) {
            this.closeMobileMenu();
        } else {
            this.openMobileMenu();
        }
    }
    
    /**
     * Open mobile menu
     */
    openMobileMenu() {
        const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
        const mobileMenu = document.querySelector('.mobile-menu');
        
        if (mobileMenuBtn && mobileMenu) {
            mobileMenuBtn.classList.add('active');
            mobileMenu.classList.add('active');
            document.body.classList.add('mobile-menu-open');
            this.mobileMenuOpen = true;
            
            console.log('📱 Mobile menu opened');
        }
    }
    
    /**
     * Close mobile menu
     */
    closeMobileMenu() {
        const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
        const mobileMenu = document.querySelector('.mobile-menu');
        
        if (mobileMenuBtn && mobileMenu) {
            mobileMenuBtn.classList.remove('active');
            mobileMenu.classList.remove('active');
            document.body.classList.remove('mobile-menu-open');
            this.mobileMenuOpen = false;
            
            console.log('📱 Mobile menu closed');
        }
    }
    
    /**
     * Toggle mobile section
     */
    toggleMobileSection(header) {
        const arrow = header.querySelector('.mobile-arrow');
        const content = header.nextElementSibling;
        
        if (arrow && content) {
            const isExpanded = content.classList.contains('expanded');
            
            if (isExpanded) {
                arrow.classList.remove('rotated');
                content.classList.remove('expanded');
            } else {
                arrow.classList.add('rotated');
                content.classList.add('expanded');
            }
        }
    }
    
    /**
     * Update active navigation item
     */
    updateActiveNav(currentPath) {
        const navItems = document.querySelectorAll('.nav-item, .mobile-menu-item');
        
        navItems.forEach(item => {
            const href = item.getAttribute('href');
            if (href && currentPath.includes(href)) {
                item.classList.add('active');
            } else {
                item.classList.remove('active');
            }
        });
    }
    
    /**
     * Add navigation item programmatically
     */
    addNavItem(label, href, parentSelector = '.desktop-nav') {
        const parent = document.querySelector(parentSelector);
        if (!parent) return false;
        
        const navItem = document.createElement('a');
        navItem.href = href;
        navItem.className = 'nav-item';
        navItem.textContent = label;
        
        parent.appendChild(navItem);
        
        console.log(`➕ Added nav item: ${label}`);
        return true;
    }
    
    /**
     * Remove navigation item
     */
    removeNavItem(href) {
        const navItems = document.querySelectorAll(`[href="${href}"]`);
        navItems.forEach(item => item.remove());
        
        console.log(`➖ Removed nav item: ${href}`);
    }
    
    /**
     * Get current active navigation
     */
    getActiveNav() {
        return document.querySelector('.nav-item.active, .mobile-menu-item.active');
    }
    
    /**
     * Cleanup
     */
    cleanup() {
        // Clear timeouts
        this.dropdownTimeouts.forEach(timeout => clearTimeout(timeout));
        this.dropdownTimeouts.clear();
        
        // Close mobile menu
        this.closeMobileMenu();
        
        // Hide dropdowns
        this.hideAllDropdowns();
        
        this.isInitialized = false;
        console.log('🧹 Navigation cleaned up');
    }
}

// Global navigation instance
let globalNavigationManager = null;

/**
 * Initialize navigation (backward compatibility)
 */
function initializeNavigation() {
    if (!globalNavigationManager) {
        globalNavigationManager = new NavigationManager();
    }
    
    return globalNavigationManager.initialize();
}

/**
 * Toggle mobile menu (backward compatibility)
 */
function toggleMobileMenu() {
    if (globalNavigationManager) {
        globalNavigationManager.toggleMobileMenu();
    }
}

/**
 * Close mobile menu (backward compatibility)
 */
function closeMobileMenu() {
    if (globalNavigationManager) {
        globalNavigationManager.closeMobileMenu();
    }
}

/**
 * Toggle mobile section (backward compatibility)
 */
function toggleMobileSection(header) {
    if (globalNavigationManager) {
        globalNavigationManager.toggleMobileSection(header);
    }
}

// Export for ES6 modules
export {
    NavigationManager,
    initializeNavigation,
    toggleMobileMenu,
    closeMobileMenu,
    toggleMobileSection
};

// Export to window for backward compatibility
window.NavigationManager = NavigationManager;
window.initializeNavigation = initializeNavigation;
window.toggleMobileMenu = toggleMobileMenu;
window.closeMobileMenu = closeMobileMenu;
window.toggleMobileSection = toggleMobileSection;
window.globalNavigationManager = () => globalNavigationManager;