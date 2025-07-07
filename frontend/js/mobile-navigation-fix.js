// Mobile Android Navigation Fix
console.log('🔧 Loading Android mobile navigation fixes...');

// Enhanced mobile navigation handler for Android
class MobileNavigationFix {
    constructor() {
        this.isAndroid = /Android/i.test(navigator.userAgent);
        this.isMobile = /Mobi|Android/i.test(navigator.userAgent);
        this.isMenuOpen = false;
        this.touchStartTime = 0;
        this.touchEndTime = 0;
        
        console.log('📱 Device detection:', {
            isAndroid: this.isAndroid,
            isMobile: this.isMobile,
            userAgent: navigator.userAgent
        });
        
        this.init();
    }
    
    init() {
        // Wait for DOM to be fully loaded
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.setupNavigationFixes());
        } else {
            this.setupNavigationFixes();
        }
    }
    
    setupNavigationFixes() {
        console.log('🔧 Setting up mobile navigation fixes...');
        
        // Override existing mobile menu functions
        this.overrideMobileMenuFunctions();
        
        // Fix touch events on navigation elements
        this.fixNavigationTouchEvents();
        
        // Add visual feedback for touches
        this.addTouchFeedback();
        
        // Fix z-index and positioning issues
        this.fixLayoutIssues();
        
        console.log('✅ Mobile navigation fixes applied');
    }
    
    overrideMobileMenuFunctions() {
        console.log('🔧 Overriding mobile menu functions...');
        
        // Enhanced mobile menu toggle function
        window.toggleMobileMenu = () => {
            console.log('📱 Enhanced toggleMobileMenu called');
            const mobileMenu = document.getElementById('mobile-menu');
            
            if (!mobileMenu) {
                console.error('❌ Mobile menu element not found');
                return;
            }
            
            if (this.isMenuOpen || mobileMenu.classList.contains('active')) {
                this.closeMobileMenu();
            } else {
                this.openMobileMenu();
            }
        };
        
        // Enhanced mobile section toggle
        window.toggleMobileSection = (sectionId) => {
            console.log('📱 Enhanced toggleMobileSection called:', sectionId);
            const section = document.getElementById(sectionId + '-section');
            const arrow = document.getElementById(sectionId + '-arrow');
            
            if (!section) {
                console.error('❌ Section not found:', sectionId + '-section');
                return;
            }
            
            const isExpanded = section.classList.contains('expanded');
            
            // Close all sections first
            const allSections = document.querySelectorAll('.mobile-section-content');
            const allArrows = document.querySelectorAll('.mobile-arrow');
            
            allSections.forEach(s => s.classList.remove('expanded'));
            allArrows.forEach(a => a.classList.remove('rotated'));
            
            // If this section wasn't expanded, expand it
            if (!isExpanded) {
                section.classList.add('expanded');
                if (arrow) arrow.classList.add('rotated');
            }
            
            console.log('✅ Section toggled:', sectionId, 'expanded:', !isExpanded);
        };
        
        // Enhanced close function
        window.closeMobileMenu = () => {
            this.closeMobileMenu();
        };
        
        // Enhanced open function
        window.openMobileMenu = () => {
            this.openMobileMenu();
        };
    }
    
    openMobileMenu() {
        console.log('📱 Opening mobile menu...');
        const mobileMenu = document.getElementById('mobile-menu');
        const hamburgerBtn = document.querySelector('.mobile-menu-btn');
        const body = document.body;
        
        if (mobileMenu) {
            mobileMenu.classList.add('active');
            mobileMenu.style.display = 'block';
            mobileMenu.style.visibility = 'visible';
            mobileMenu.style.opacity = '1';
        }
        
        if (hamburgerBtn) {
            hamburgerBtn.classList.add('active');
        }
        
        if (body) {
            body.classList.add('mobile-menu-open');
            body.style.overflow = 'hidden';
        }
        
        this.isMenuOpen = true;
        console.log('✅ Mobile menu opened');
    }
    
    closeMobileMenu() {
        console.log('📱 Closing mobile menu...');
        const mobileMenu = document.getElementById('mobile-menu');
        const hamburgerBtn = document.querySelector('.mobile-menu-btn');
        const body = document.body;
        
        if (mobileMenu) {
            mobileMenu.classList.remove('active');
            // Use transition end to hide completely
            setTimeout(() => {
                if (!mobileMenu.classList.contains('active')) {
                    mobileMenu.style.display = '';
                    mobileMenu.style.visibility = '';
                    mobileMenu.style.opacity = '';
                }
            }, 300);
        }
        
        if (hamburgerBtn) {
            hamburgerBtn.classList.remove('active');
        }
        
        if (body) {
            body.classList.remove('mobile-menu-open');
            body.style.overflow = '';
        }
        
        // Close all expanded sections
        const allSections = document.querySelectorAll('.mobile-section-content');
        const allArrows = document.querySelectorAll('.mobile-arrow');
        allSections.forEach(s => s.classList.remove('expanded'));
        allArrows.forEach(a => a.classList.remove('rotated'));
        
        this.isMenuOpen = false;
        console.log('✅ Mobile menu closed');
    }
    
    fixNavigationTouchEvents() {
        console.log('🔧 Fixing navigation touch events...');
        
        // Fix hamburger button
        this.fixHamburgerButton();
        
        // Fix section headers
        this.fixSectionHeaders();
        
        // Fix overlay and close button
        this.fixOverlayAndCloseButton();
        
        // Fix menu item links
        this.fixMenuLinks();
    }
    
    fixHamburgerButton() {
        const hamburgerBtn = document.querySelector('.mobile-menu-btn');
        if (!hamburgerBtn) {
            console.error('❌ Hamburger button not found');
            return;
        }
        
        // Remove existing listeners
        hamburgerBtn.removeEventListener('click', window.toggleMobileMenu);
        
        // Add multiple event types for better Android compatibility
        const handleToggle = (e) => {
            e.preventDefault();
            e.stopPropagation();
            console.log('📱 Hamburger activated via:', e.type);
            
            // Add visual feedback
            hamburgerBtn.style.backgroundColor = 'rgba(102, 126, 234, 0.2)';
            setTimeout(() => {
                hamburgerBtn.style.backgroundColor = '';
            }, 200);
            
            window.toggleMobileMenu();
        };
        
        hamburgerBtn.addEventListener('click', handleToggle, { passive: false });
        hamburgerBtn.addEventListener('touchend', handleToggle, { passive: false });
        
        // Ensure proper styling
        hamburgerBtn.style.touchAction = 'manipulation';
        hamburgerBtn.style.userSelect = 'none';
        hamburgerBtn.style.webkitUserSelect = 'none';
        
        console.log('✅ Hamburger button fixed');
    }
    
    fixSectionHeaders() {
        const sectionHeaders = document.querySelectorAll('.mobile-section-header');
        console.log('🔧 Found section headers:', sectionHeaders.length);
        
        sectionHeaders.forEach((header, index) => {
            // Get section ID from onclick attribute or create one
            let sectionId = null;
            const onclickAttr = header.getAttribute('onclick');
            
            if (onclickAttr) {
                const match = onclickAttr.match(/toggleMobileSection\('([^']+)'\)/);
                if (match) {
                    sectionId = match[1];
                }
            }
            
            // Fallback: get from parent structure
            if (!sectionId) {
                const section = header.closest('.mobile-section');
                if (section) {
                    const content = section.querySelector('.mobile-section-content');
                    if (content) {
                        sectionId = content.id.replace('-section', '');
                    }
                }
            }
            
            if (sectionId) {
                console.log('🔧 Fixing section header:', sectionId);
                
                // Remove onclick attribute
                header.removeAttribute('onclick');
                
                // Add enhanced event listeners
                const handleSectionToggle = (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    console.log('📱 Section header activated:', sectionId, 'via:', e.type);
                    
                    // Add visual feedback
                    header.style.backgroundColor = 'rgba(102, 126, 234, 0.1)';
                    setTimeout(() => {
                        header.style.backgroundColor = '';
                    }, 200);
                    
                    window.toggleMobileSection(sectionId);
                };
                
                header.addEventListener('click', handleSectionToggle, { passive: false });
                header.addEventListener('touchend', handleSectionToggle, { passive: false });
                
                // Ensure proper styling
                header.style.touchAction = 'manipulation';
                header.style.userSelect = 'none';
                header.style.webkitUserSelect = 'none';
                header.style.cursor = 'pointer';
                
                console.log('✅ Section header fixed:', sectionId);
            } else {
                console.warn('⚠️ Could not determine section ID for header:', index);
            }
        });
    }
    
    fixOverlayAndCloseButton() {
        // Fix overlay
        const overlay = document.querySelector('.mobile-menu-overlay');
        if (overlay) {
            const handleOverlayClick = (e) => {
                e.preventDefault();
                e.stopPropagation();
                console.log('📱 Overlay clicked');
                this.closeMobileMenu();
            };
            
            overlay.addEventListener('click', handleOverlayClick, { passive: false });
            overlay.addEventListener('touchend', handleOverlayClick, { passive: false });
            
            overlay.style.touchAction = 'manipulation';
            console.log('✅ Overlay fixed');
        }
        
        // Fix close button
        const closeBtn = document.querySelector('.mobile-menu-close');
        if (closeBtn) {
            const handleCloseClick = (e) => {
                e.preventDefault();
                e.stopPropagation();
                console.log('📱 Close button clicked');
                
                // Add visual feedback
                closeBtn.style.backgroundColor = 'rgba(0, 0, 0, 0.1)';
                setTimeout(() => {
                    closeBtn.style.backgroundColor = '';
                }, 150);
                
                this.closeMobileMenu();
            };
            
            closeBtn.addEventListener('click', handleCloseClick, { passive: false });
            closeBtn.addEventListener('touchend', handleCloseClick, { passive: false });
            
            closeBtn.style.touchAction = 'manipulation';
            closeBtn.style.userSelect = 'none';
            closeBtn.style.webkitUserSelect = 'none';
            
            console.log('✅ Close button fixed');
        }
    }
    
    fixMenuLinks() {
        console.log('🔧 Fixing menu links...');
        
        // Fix all mobile menu links
        const allMenuLinks = document.querySelectorAll('.mobile-menu-item, .mobile-section-content a');
        console.log('📱 Found menu links:', allMenuLinks.length);
        
        allMenuLinks.forEach((link, index) => {
            if (link.tagName === 'A') {
                console.log(`🔗 Link ${index}:`, link.textContent.trim(), '→', link.href);
                
                // Remove any onclick that might interfere
                const originalOnclick = link.onclick;
                link.onclick = null;
                
                // Ensure link is properly styled
                link.style.display = 'block';
                link.style.touchAction = 'manipulation';
                link.style.webkitTapHighlightColor = 'transparent';
                link.style.cursor = 'pointer';
                link.style.textDecoration = 'none';
                
                // Add enhanced click handler
                const handleLinkClick = (e) => {
                    console.log('📱 Link clicked:', link.textContent.trim(), '→', link.href);
                    
                    // Let the browser handle the navigation
                    if (link.href && !link.href.includes('javascript:')) {
                        // Close menu first if needed
                        if (originalOnclick) {
                            try {
                                originalOnclick.call(link, e);
                            } catch (err) {
                                console.error('Error in original onclick:', err);
                            }
                        }
                        
                        // Small delay to let menu close animation start
                        setTimeout(() => {
                            console.log('📱 Navigating to:', link.href);
                            window.location.href = link.href;
                        }, 100);
                        
                        // Prevent default only if we're handling navigation
                        e.preventDefault();
                    }
                };
                
                // Remove existing listeners
                link.removeEventListener('click', handleLinkClick);
                link.removeEventListener('touchend', handleLinkClick);
                
                // Add new listeners
                link.addEventListener('click', handleLinkClick, { passive: false });
                link.addEventListener('touchend', (e) => {
                    // Prevent ghost clicks
                    e.preventDefault();
                    handleLinkClick(e);
                }, { passive: false });
                
                // Add visual feedback
                link.addEventListener('touchstart', () => {
                    link.style.backgroundColor = 'rgba(102, 126, 234, 0.1)';
                    link.style.transform = 'scale(0.98)';
                }, { passive: true });
                
                link.addEventListener('touchend', () => {
                    setTimeout(() => {
                        link.style.backgroundColor = '';
                        link.style.transform = '';
                    }, 200);
                }, { passive: true });
            }
        });
        
        // Special handling for dropdown links inside mobile-section-content
        const dropdownLinks = document.querySelectorAll('.mobile-section-content a');
        dropdownLinks.forEach(link => {
            // Ensure these links are visible and clickable
            link.style.pointerEvents = 'auto';
            link.style.position = 'relative';
            link.style.zIndex = '10';
        });
        
        console.log('✅ Menu links fixed');
    }
    
    addTouchFeedback() {
        console.log('🔧 Adding touch feedback...');
        
        // Add global touch feedback for debugging
        document.addEventListener('touchstart', (e) => {
            this.touchStartTime = Date.now();
            
            const target = e.target;
            const isNavElement = target.closest('.mobile-menu-btn') || 
                                target.closest('.mobile-section-header') ||
                                target.closest('.mobile-menu-close') ||
                                target.closest('.mobile-menu-overlay');
            
            if (isNavElement && this.isMobile) {
                console.log('📱 Touch start on nav element:', {
                    element: target.tagName,
                    className: target.className,
                    id: target.id
                });
            }
        }, { passive: true });
        
        document.addEventListener('touchend', (e) => {
            this.touchEndTime = Date.now();
            const touchDuration = this.touchEndTime - this.touchStartTime;
            
            const target = e.target;
            const isNavElement = target.closest('.mobile-menu-btn') || 
                                target.closest('.mobile-section-header') ||
                                target.closest('.mobile-menu-close') ||
                                target.closest('.mobile-menu-overlay');
            
            if (isNavElement && this.isMobile) {
                console.log('📱 Touch end on nav element:', {
                    element: target.tagName,
                    className: target.className,
                    id: target.id,
                    duration: touchDuration + 'ms'
                });
            }
        }, { passive: true });
        
        console.log('✅ Touch feedback added');
    }
    
    fixLayoutIssues() {
        console.log('🔧 Fixing layout issues...');
        
        // Ensure proper z-index hierarchy
        const mobileMenu = document.getElementById('mobile-menu');
        if (mobileMenu) {
            mobileMenu.style.zIndex = '9998';
        }
        
        const hamburgerBtn = document.querySelector('.mobile-menu-btn');
        if (hamburgerBtn) {
            hamburgerBtn.style.zIndex = '9999';
            hamburgerBtn.style.position = 'relative';
        }
        
        // Fix content positioning
        const mobileMenuContent = document.querySelector('.mobile-menu-content');
        if (mobileMenuContent) {
            mobileMenuContent.style.zIndex = '9999';
        }
        
        console.log('✅ Layout issues fixed');
    }
    
    // Debug method
    debugInfo() {
        return {
            isAndroid: this.isAndroid,
            isMobile: this.isMobile,
            isMenuOpen: this.isMenuOpen,
            userAgent: navigator.userAgent,
            menuExists: !!document.getElementById('mobile-menu'),
            hamburgerExists: !!document.querySelector('.mobile-menu-btn'),
            sectionHeaders: document.querySelectorAll('.mobile-section-header').length
        };
    }
    
    // Public method to manually apply fixes
    applyFixes() {
        this.setupNavigationFixes();
    }
}

// Initialize the mobile navigation fix
const mobileNavFix = new MobileNavigationFix();

// Make it globally available for debugging
window.mobileNavFix = mobileNavFix;

// Add keyboard event handling for accessibility
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && mobileNavFix.isMenuOpen) {
        mobileNavFix.closeMobileMenu();
    }
});

// Add resize handler to close menu on orientation change
window.addEventListener('resize', () => {
    if (window.innerWidth > 768 && mobileNavFix.isMenuOpen) {
        mobileNavFix.closeMobileMenu();
    }
});

console.log('✅ Mobile Android navigation fixes loaded successfully');