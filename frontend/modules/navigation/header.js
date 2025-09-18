/**
 * Header Navigation Module
 * Handles desktop dropdowns, mobile menu, and navigation interactions
 */

class HeaderNavigation {
    constructor() {
        this.isInitialized = false;
        this.isMobileMenuOpen = false;
        this.activeDropdown = null;
        this.touchStartTime = 0;
    }

    /**
     * Initialize the header navigation
     */
    init() {
        this.setupDesktopDropdowns();
        this.setupMobileMenu();
        this.setupEventListeners();
        this.setupTouchHandling();

        this.isInitialized = true;
        console.log('✅ Header Navigation initialized');
    }

    /**
     * Setup desktop dropdown functionality
     */
    setupDesktopDropdowns() {
        // Click outside to close dropdowns
        document.addEventListener('click', (event) => {
            const dropdowns = document.querySelectorAll('.dropdown');
            let clickedInsideDropdown = false;

            dropdowns.forEach(dropdown => {
                if (dropdown.contains(event.target)) {
                    clickedInsideDropdown = true;
                }
            });

            if (!clickedInsideDropdown) {
                this.closeAllDropdowns();
            }
        });

        // Escape key to close dropdowns
        document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape') {
                this.closeAllDropdowns();
                this.closeMobileMenu();
            }
        });
    }

    /**
     * Setup mobile menu functionality
     */
    setupMobileMenu() {
        const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
        if (mobileMenuBtn) {
            mobileMenuBtn.addEventListener('click', () => {
                this.toggleMobileMenu();
            });
        }

        // Close mobile menu on window resize to desktop
        window.addEventListener('resize', () => {
            if (window.innerWidth >= 768) {
                this.closeMobileMenu();
            }
        });

        // Ensure mobile menu is closed on page load
        this.closeMobileMenu();
    }

    /**
     * Setup additional event listeners
     */
    setupEventListeners() {
        // Handle mobile section toggles
        document.addEventListener('click', (event) => {
            if (event.target.matches('.mobile-section-header')) {
                const sectionId = this.extractSectionId(event.target);
                if (sectionId) {
                    this.toggleMobileSection(sectionId);
                }
            }
        });

        // Handle dropdown triggers
        document.addEventListener('click', (event) => {
            if (event.target.matches('.dropdown-trigger')) {
                event.preventDefault();
                const dropdownId = this.extractDropdownId(event.target);
                if (dropdownId) {
                    this.toggleDropdown(dropdownId);
                }
            }
        });
    }

    /**
     * Setup touch handling for better mobile experience
     */
    setupTouchHandling() {
        document.addEventListener('touchstart', (event) => {
            this.touchStartTime = Date.now();

            // Prevent zoom on double tap for buttons
            if (event.target.matches('button, .mobile-menu-item, .nav-item')) {
                event.preventDefault();
            }
        }, { passive: false });

        document.addEventListener('touchend', (event) => {
            const touchDuration = Date.now() - this.touchStartTime;

            // Handle quick taps on navigation items
            if (touchDuration < 300 && event.target.matches('.nav-item, .mobile-menu-item')) {
                // Allow normal link behavior
                return true;
            }
        });
    }

    /**
     * Toggle dropdown visibility
     */
    toggleDropdown(dropdownId) {
        const dropdown = document.getElementById(dropdownId + '-dropdown');
        if (!dropdown) {
            console.warn(`Dropdown ${dropdownId} not found`);
            return;
        }

        // Close all other dropdowns first
        this.closeAllDropdowns(dropdownId + '-dropdown');

        // Toggle current dropdown
        const isVisible = dropdown.style.opacity === '1';

        if (isVisible) {
            this.closeDropdown(dropdown);
            this.activeDropdown = null;
        } else {
            this.openDropdown(dropdown);
            this.activeDropdown = dropdownId;
        }
    }

    /**
     * Open a dropdown
     */
    openDropdown(dropdown) {
        dropdown.style.opacity = '1';
        dropdown.style.visibility = 'visible';
        dropdown.style.transform = 'translateY(0)';
        dropdown.style.pointerEvents = 'auto';
    }

    /**
     * Close a dropdown
     */
    closeDropdown(dropdown) {
        dropdown.style.opacity = '0';
        dropdown.style.visibility = 'hidden';
        dropdown.style.transform = 'translateY(-10px)';
        dropdown.style.pointerEvents = 'none';
    }

    /**
     * Close all dropdowns except the specified one
     */
    closeAllDropdowns(exceptId = null) {
        const allDropdowns = document.querySelectorAll('.dropdown-menu');

        allDropdowns.forEach(menu => {
            if (!exceptId || menu.id !== exceptId) {
                this.closeDropdown(menu);
            }
        });

        if (!exceptId) {
            this.activeDropdown = null;
        }
    }

    /**
     * Toggle mobile menu
     */
    toggleMobileMenu() {
        if (this.isMobileMenuOpen) {
            this.closeMobileMenu();
        } else {
            this.openMobileMenu();
        }
    }

    /**
     * Open mobile menu
     */
    openMobileMenu() {
        const mobileMenu = document.getElementById('mobile-menu');
        const hamburgerBtn = document.querySelector('.mobile-menu-btn');
        const body = document.body;

        if (mobileMenu) {
            mobileMenu.classList.add('active');
        }

        if (hamburgerBtn) {
            hamburgerBtn.classList.add('active');
        }

        if (body) {
            body.classList.add('mobile-menu-open');
        }

        this.isMobileMenuOpen = true;

        // Close any open desktop dropdowns
        this.closeAllDropdowns();

        console.log('📱 Mobile menu opened');
    }

    /**
     * Close mobile menu
     */
    closeMobileMenu() {
        const mobileMenu = document.getElementById('mobile-menu');
        const hamburgerBtn = document.querySelector('.mobile-menu-btn');
        const body = document.body;

        if (mobileMenu) {
            mobileMenu.classList.remove('active');
        }

        if (hamburgerBtn) {
            hamburgerBtn.classList.remove('active');
        }

        if (body) {
            body.classList.remove('mobile-menu-open');
        }

        this.isMobileMenuOpen = false;

        // Close all mobile sections
        this.closeAllMobileSections();

        console.log('📱 Mobile menu closed');
    }

    /**
     * Toggle mobile section
     */
    toggleMobileSection(sectionId) {
        const section = document.getElementById(sectionId + '-section');
        const arrow = document.getElementById(sectionId + '-arrow');

        if (!section) {
            console.warn(`Mobile section ${sectionId} not found`);
            return;
        }

        const isExpanded = section.classList.contains('expanded');

        if (isExpanded) {
            // Close this section
            section.classList.remove('expanded');
            if (arrow) {
                arrow.classList.remove('rotated');
            }
        } else {
            // Close all other sections first
            this.closeAllMobileSections();

            // Open the clicked section
            section.classList.add('expanded');
            if (arrow) {
                arrow.classList.add('rotated');
            }
        }
    }

    /**
     * Close all mobile sections
     */
    closeAllMobileSections() {
        const allSections = document.querySelectorAll('.mobile-section-content');
        const allArrows = document.querySelectorAll('.mobile-arrow');

        allSections.forEach(section => {
            section.classList.remove('expanded');
        });

        allArrows.forEach(arrow => {
            arrow.classList.remove('rotated');
        });
    }

    /**
     * Extract section ID from mobile section header
     */
    extractSectionId(element) {
        // Look for onclick attribute or data attribute
        const onclick = element.getAttribute('onclick');
        if (onclick) {
            const match = onclick.match(/toggleMobileSection\('([^']+)'\)/);
            return match ? match[1] : null;
        }

        // Fallback: check data attributes
        return element.dataset.sectionId || null;
    }

    /**
     * Extract dropdown ID from dropdown trigger
     */
    extractDropdownId(element) {
        // Look for onclick attribute or data attribute
        const onclick = element.getAttribute('onclick');
        if (onclick) {
            const match = onclick.match(/toggleDropdown\('([^']+)'\)/);
            return match ? match[1] : null;
        }

        // Fallback: check data attributes
        return element.dataset.dropdownId || null;
    }

    /**
     * Check if mobile menu is open
     */
    isMobileOpen() {
        return this.isMobileMenuOpen;
    }

    /**
     * Get active dropdown
     */
    getActiveDropdown() {
        return this.activeDropdown;
    }

    /**
     * Set header scroll behavior
     */
    setScrollBehavior(shouldHideOnScroll = false) {
        if (!shouldHideOnScroll) return;

        let lastScrollTop = 0;
        const header = document.getElementById('header');

        window.addEventListener('scroll', () => {
            const scrollTop = window.pageYOffset || document.documentElement.scrollTop;

            if (scrollTop > lastScrollTop && scrollTop > 100) {
                // Scrolling down - hide header
                if (header) {
                    header.style.transform = 'translateY(-100%)';
                }
            } else {
                // Scrolling up - show header
                if (header) {
                    header.style.transform = 'translateY(0)';
                }
            }

            lastScrollTop = scrollTop;
        });
    }

    /**
     * Update header styling based on scroll position
     */
    setupScrollStyling() {
        const header = document.getElementById('header');
        if (!header) return;

        window.addEventListener('scroll', () => {
            const scrolled = window.scrollY > 20;

            if (scrolled) {
                header.classList.add('scrolled');
            } else {
                header.classList.remove('scrolled');
            }
        });
    }

    /**
     * Add navigation item programmatically
     */
    addNavigationItem(item, position = 'end') {
        const desktopNav = document.querySelector('.desktop-nav');
        const mobileNav = document.querySelector('.mobile-menu-items');

        if (!desktopNav || !mobileNav) {
            console.warn('Navigation containers not found');
            return;
        }

        // Create desktop navigation item
        const desktopItem = this.createDesktopNavItem(item);
        const mobileItem = this.createMobileNavItem(item);

        // Add to appropriate position
        if (position === 'start') {
            desktopNav.insertBefore(desktopItem, desktopNav.firstChild);
            mobileNav.insertBefore(mobileItem, mobileNav.firstChild);
        } else {
            // Find auth section and insert before it
            const authSection = desktopNav.querySelector('.desktop-auth');
            if (authSection) {
                desktopNav.insertBefore(desktopItem, authSection);
            } else {
                desktopNav.appendChild(desktopItem);
            }
            mobileNav.appendChild(mobileItem);
        }
    }

    /**
     * Create desktop navigation item
     */
    createDesktopNavItem(item) {
        const element = document.createElement('div');

        if (item.dropdown) {
            element.className = 'dropdown';
            element.innerHTML = `
                <button class="nav-item dropdown-trigger" data-dropdown-id="${item.id}">
                    ${item.label} <span class="dropdown-arrow">▼</span>
                </button>
                <div class="dropdown-menu" id="${item.id}-dropdown">
                    ${item.dropdown.map(subItem => `
                        <a href="${subItem.href}" class="dropdown-item">${subItem.label}</a>
                    `).join('')}
                </div>
            `;
        } else {
            element.innerHTML = `<a href="${item.href}" class="nav-item">${item.label}</a>`;
        }

        return element;
    }

    /**
     * Create mobile navigation item
     */
    createMobileNavItem(item) {
        const element = document.createElement('div');

        if (item.dropdown) {
            element.className = 'mobile-section';
            element.innerHTML = `
                <button class="mobile-section-header" data-section-id="${item.id}">
                    ${item.icon || '🔗'} ${item.label} <span class="mobile-arrow" id="${item.id}-arrow">▼</span>
                </button>
                <div class="mobile-section-content" id="${item.id}-section">
                    ${item.dropdown.map(subItem => `
                        <a href="${subItem.href}" class="mobile-menu-item">${subItem.label}</a>
                    `).join('')}
                </div>
            `;
        } else {
            element.innerHTML = `
                <a href="${item.href}" class="mobile-menu-item">
                    ${item.icon || '🔗'} ${item.label}
                </a>
            `;
        }

        return element;
    }

    /**
     * Destroy navigation
     */
    destroy() {
        this.closeMobileMenu();
        this.closeAllDropdowns();
        this.isInitialized = false;
        console.log('🗑️ Header Navigation destroyed');
    }
}

// Create global instance
window.headerNavigation = new HeaderNavigation();

// Global functions for backward compatibility
window.toggleDropdown = (dropdownId) => {
    if (window.headerNavigation) {
        window.headerNavigation.toggleDropdown(dropdownId);
    }
};

window.toggleMobileMenu = () => {
    if (window.headerNavigation) {
        window.headerNavigation.toggleMobileMenu();
    }
};

window.openMobileMenu = () => {
    if (window.headerNavigation) {
        window.headerNavigation.openMobileMenu();
    }
};

window.closeMobileMenu = () => {
    if (window.headerNavigation) {
        window.headerNavigation.closeMobileMenu();
    }
};

window.toggleMobileSection = (sectionId) => {
    if (window.headerNavigation) {
        window.headerNavigation.toggleMobileSection(sectionId);
    }
};

export default window.headerNavigation;