/**
 * Component Loader
 * Dynamically loads shared components (header, footer) into pages
 */

/**
 * Load a component into an element
 * @param {HTMLElement} element - Element with data-component attribute
 */
async function loadComponent(element) {
    const componentName = element.dataset.component;

    if (!componentName) {
        console.warn('Component element missing data-component attribute');
        return;
    }

    try {
        const response = await fetch(`/components/${componentName}.html`);

        if (response.ok) {
            const html = await response.text();
            element.innerHTML = html;

            // Initialize component-specific functionality
            if (componentName === 'header') {
                initializeNavigation();
            }
        } else {
            console.error(`Failed to load component: ${componentName} (${response.status})`);
        }
    } catch (error) {
        console.error(`Error loading component: ${componentName}`, error);
    }
}

/**
 * Initialize navigation functionality (dropdowns, mobile menu, scroll effects)
 */
function initializeNavigation() {
    // Header scroll effect
    const header = document.querySelector('header');
    if (header) {
        const handleScroll = () => {
            if (window.scrollY > 50) {
                header.classList.add('scrolled');
            } else {
                header.classList.remove('scrolled');
            }
        };

        // Initial check
        handleScroll();

        // Add scroll listener
        window.addEventListener('scroll', handleScroll, { passive: true });
    }

    // Dropdown toggles
    const dropdownToggles = document.querySelectorAll('.dropdown-toggle');
    dropdownToggles.forEach(toggle => {
        toggle.addEventListener('click', (e) => {
            e.preventDefault();

            // Get the dropdown menu (next sibling)
            const dropdownMenu = toggle.nextElementSibling;

            if (dropdownMenu && dropdownMenu.classList.contains('dropdown-menu')) {
                // Close other dropdowns first
                document.querySelectorAll('.dropdown-menu.show').forEach(menu => {
                    if (menu !== dropdownMenu) {
                        menu.classList.remove('show');
                    }
                });

                // Toggle current dropdown
                dropdownMenu.classList.toggle('show');
            }
        });
    });

    // Close dropdowns when clicking outside
    document.addEventListener('click', (e) => {
        if (!e.target.closest('.dropdown')) {
            document.querySelectorAll('.dropdown-menu.show').forEach(menu => {
                menu.classList.remove('show');
            });
        }
    });

    // Mobile menu toggle
    const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
    const mobileMenu = document.querySelector('.mobile-menu');

    if (mobileMenuBtn && mobileMenu) {
        mobileMenuBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            mobileMenu.classList.toggle('show');

            // Toggle icon between bars and times
            const icon = mobileMenuBtn.querySelector('i');
            if (icon) {
                if (mobileMenu.classList.contains('show')) {
                    icon.className = 'fas fa-times text-2xl text-gray-700';
                } else {
                    icon.className = 'fas fa-bars text-2xl text-gray-700';
                }
            }
        });

        // Close mobile menu when clicking outside
        document.addEventListener('click', (e) => {
            if (!e.target.closest('.mobile-menu') && !e.target.closest('.mobile-menu-btn')) {
                mobileMenu.classList.remove('show');
                const icon = mobileMenuBtn.querySelector('i');
                if (icon) {
                    icon.className = 'fas fa-bars text-2xl text-gray-700';
                }
            }
        });
    }

    // Mobile menu collapsible sections
    const mobileToggleBtns = document.querySelectorAll('.mobile-section-toggle');
    mobileToggleBtns.forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.preventDefault();
            const section = btn.nextElementSibling;

            if (section && section.classList.contains('mobile-section-content')) {
                section.classList.toggle('show');

                // Toggle chevron icon
                const chevron = btn.querySelector('.fa-chevron-down');
                if (chevron) {
                    chevron.style.transform = section.classList.contains('show')
                        ? 'rotate(180deg)'
                        : 'rotate(0deg)';
                }
            }
        });
    });
}

/**
 * Initialize component loading on DOM ready
 */
document.addEventListener('DOMContentLoaded', () => {
    // Load all components
    const componentElements = document.querySelectorAll('[data-component]');
    componentElements.forEach(loadComponent);
});

/**
 * Export functions for use in other scripts if needed
 */
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        loadComponent,
        initializeNavigation
    };
}
