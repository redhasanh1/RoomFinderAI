/**
 * UI Helper Functions Module
 * Handles UI-specific utilities, form helpers, and display functions
 */

class UIHelpers {
    constructor() {
        this.isInitialized = false;
        this.currentFilters = {};
        this.searchTimeout = null;
    }

    /**
     * Initialize UI helpers
     */
    init() {
        this.setupGlobalUIFunctions();
        this.setupEventHandlers();

        this.isInitialized = true;
        console.log('✅ UI Helpers initialized');
    }

    /**
     * Setup global UI functions for backward compatibility
     */
    setupGlobalUIFunctions() {
        window.heroQuickSearch = this.heroQuickSearch.bind(this);
        window.scrollToListings = this.scrollToListings.bind(this);
        window.showAddListingForm = this.showAddListingForm.bind(this);
        window.hideAddListingForm = this.hideAddListingForm.bind(this);
        window.showManualForm = this.showManualForm.bind(this);
        window.toggleAdvancedFilters = this.toggleAdvancedFilters.bind(this);
        window.applyQuickFilter = this.applyQuickFilter.bind(this);
        window.applySearchFilters = this.applySearchFilters.bind(this);
        window.liveSearch = this.liveSearch.bind(this);
        window.clearFilters = this.clearFilters.bind(this);
        window.toggleFavorite = this.toggleFavorite.bind(this);
    }

    /**
     * Setup event handlers
     */
    setupEventHandlers() {
        // Hero search input enter key
        const heroInput = document.getElementById('heroSearchInput');
        if (heroInput) {
            heroInput.addEventListener('keypress', (e) => {
                if (e.key === 'Enter') {
                    this.heroQuickSearch();
                }
            });
        }

        // Main search input
        const searchInput = document.getElementById('searchLocation');
        if (searchInput) {
            searchInput.addEventListener('keypress', (e) => {
                if (e.key === 'Enter') {
                    this.applySearchFilters();
                }
            });
        }
    }

    // ==================== NAVIGATION HELPERS ====================

    /**
     * Hero quick search functionality
     */
    heroQuickSearch() {
        const searchInput = document.getElementById('heroSearchInput');
        const searchTerm = searchInput?.value.trim();

        if (searchTerm) {
            const mainSearchInput = document.getElementById('searchLocation');
            if (mainSearchInput) {
                mainSearchInput.value = searchTerm;
            }
            this.scrollToListings();
            this.applySearchFilters();
        } else {
            this.scrollToListings();
        }
    }

    /**
     * Smooth scroll to listings section
     */
    scrollToListings() {
        const listingsDisplay = document.getElementById('listings-display');
        if (listingsDisplay) {
            listingsDisplay.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    }

    // ==================== FORM DISPLAY HELPERS ====================

    /**
     * Show add listing form
     */
    showAddListingForm() {
        const section = document.getElementById('addListingSection');
        if (section) {
            section.classList.remove('hidden');
            section.scrollIntoView({ behavior: 'smooth', block: 'start' });

            // Add animation class if available
            setTimeout(() => {
                section.classList.add('animate-fade-in');
            }, 100);

            // Focus on first input
            setTimeout(() => {
                const firstInput = section.querySelector('input, select, textarea');
                if (firstInput) {
                    firstInput.focus();
                }
            }, 500);
        }
    }

    /**
     * Hide add listing form
     */
    hideAddListingForm() {
        const section = document.getElementById('addListingSection');
        if (section) {
            section.classList.add('hidden');

            // Clear form if needed
            const form = section.querySelector('form');
            if (form) {
                // Don't auto-clear, let user decide
                // form.reset();
            }

            // Scroll back to hero
            const hero = document.querySelector('.hero-section');
            if (hero) {
                hero.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }
    }

    /**
     * Show manual form section
     */
    showManualForm() {
        const manualSection = document.getElementById('manualFormSection');
        if (manualSection) {
            manualSection.classList.remove('hidden');

            // Focus on first input
            setTimeout(() => {
                const firstInput = manualSection.querySelector('input');
                if (firstInput) {
                    firstInput.focus();
                }
            }, 100);
        }
    }

    /**
     * Toggle advanced filters visibility
     */
    toggleAdvancedFilters() {
        const advancedFilters = document.getElementById('advancedFilters');
        if (!advancedFilters) return;

        const isHidden = advancedFilters.classList.contains('hidden');

        if (isHidden) {
            advancedFilters.classList.remove('hidden');
            advancedFilters.classList.add('animate-slide-down');
        } else {
            advancedFilters.classList.add('hidden');
            advancedFilters.classList.remove('animate-slide-down');
        }

        // Update button text
        const button = document.querySelector('[onclick="toggleAdvancedFilters()"]');
        if (button) {
            const text = button.querySelector('span');
            if (text) {
                text.textContent = isHidden ? 'Hide Filters' : 'More Filters';
            }
        }
    }

    // ==================== FILTER HELPERS ====================

    /**
     * Apply quick filter
     */
    applyQuickFilter(type, value) {
        // Update the visual state of filter chips
        const allChips = document.querySelectorAll('.flex.flex-wrap.gap-2 button');
        allChips.forEach(chip => chip.classList.remove('filter-chip-active'));

        // Store the filter
        this.currentFilters[type] = value;

        // Update relevant form fields
        switch (type) {
            case 'price':
                const priceMax = document.getElementById('priceMax');
                if (priceMax) priceMax.value = value;
                break;
            case 'bedrooms':
                const bedroomsMin = document.getElementById('bedroomsMin');
                if (bedroomsMin) bedroomsMin.value = value;
                break;
            case 'type':
                const houseTypeFilter = document.getElementById('houseTypeFilter');
                if (houseTypeFilter) houseTypeFilter.value = value;
                break;
            case 'utilities':
                const utilitiesFilter = document.getElementById('utilitiesFilter');
                if (utilitiesFilter) utilitiesFilter.value = value;
                break;
        }

        // Apply filters immediately
        this.applySearchFilters();

        // Mark the clicked chip as active
        event?.target?.classList.add('filter-chip-active');
    }

    /**
     * Apply search filters to listings
     */
    async applySearchFilters() {
        console.log('🔍 Applying search filters...');

        const location = document.getElementById('searchLocation')?.value.toLowerCase().trim() || '';
        const priceMin = parseInt(document.getElementById('priceMin')?.value) || 0;
        const priceMax = parseInt(document.getElementById('priceMax')?.value) || Infinity;
        const bedroomsMin = parseInt(document.getElementById('bedroomsMin')?.value) || 0;
        const bedroomsMax = parseInt(document.getElementById('bedroomsMax')?.value) || Infinity;
        const houseType = document.getElementById('houseTypeFilter')?.value || '';
        const utilities = document.getElementById('utilitiesFilter')?.value || '';

        // Get current listings from the listings manager
        const listingsManager = window.listingsManager;
        if (!listingsManager || !listingsManager.listings) {
            console.warn('Listings manager not available or no listings loaded');
            return;
        }

        const originalListings = listingsManager.listings;

        // Apply filters
        const filtered = originalListings.filter(listing => {
            // Location filter
            if (location) {
                const matchesLocation = [
                    listing.city,
                    listing.street,
                    listing.postalCode,
                    listing.country
                ].some(field =>
                    field && field.toLowerCase().includes(location)
                );

                if (!matchesLocation) return false;
            }

            // Price filter
            if (listing.price < priceMin || listing.price > priceMax) {
                return false;
            }

            // Bedrooms filter
            if (listing.bedrooms < bedroomsMin || listing.bedrooms > bedroomsMax) {
                return false;
            }

            // House type filter
            if (houseType && listing.house_type !== houseType) {
                return false;
            }

            // Utilities filter
            if (utilities && listing.utilities !== utilities) {
                return false;
            }

            return true;
        });

        console.log(`🎯 Filtered ${filtered.length} listings from ${originalListings.length} total`);

        // Display filtered results
        if (listingsManager.displayListings) {
            await listingsManager.displayListings(filtered);
        }

        // Update map if available
        if (window.mapController && window.mapController.updateMap) {
            window.mapController.updateMap(filtered);
        }

        // Show results count
        this.updateResultsCount(filtered.length, originalListings.length);
    }

    /**
     * Live search with debouncing
     */
    liveSearch(event) {
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            if (event.key === 'Enter') {
                this.applySearchFilters();
            }
        }, 300);
    }

    /**
     * Clear all filters
     */
    clearFilters() {
        // Clear form inputs
        const filterInputs = [
            'searchLocation', 'priceMin', 'priceMax',
            'bedroomsMin', 'bedroomsMax', 'houseTypeFilter', 'utilitiesFilter'
        ];

        filterInputs.forEach(id => {
            const element = document.getElementById(id);
            if (element) {
                element.value = '';
            }
        });

        // Clear current filters
        this.currentFilters = {};

        // Remove active filter chips
        document.querySelectorAll('.filter-chip-active').forEach(chip => {
            chip.classList.remove('filter-chip-active');
        });

        // Reapply filters (which will now show all listings)
        this.applySearchFilters();

        console.log('🧹 All filters cleared');
    }

    /**
     * Update results count display
     */
    updateResultsCount(filtered, total) {
        let countElement = document.getElementById('results-count');

        if (!countElement) {
            // Create results count element if it doesn't exist
            countElement = document.createElement('div');
            countElement.id = 'results-count';
            countElement.className = 'text-sm text-gray-600 mb-4 px-4';

            const listingsContainer = document.getElementById('listings-display');
            if (listingsContainer) {
                listingsContainer.insertBefore(countElement, listingsContainer.firstChild);
            }
        }

        const message = filtered === total
            ? `Showing all ${total} listings`
            : `Showing ${filtered} of ${total} listings`;

        countElement.textContent = message;
    }

    // ==================== FAVORITE HELPERS ====================

    /**
     * Toggle favorite status for a listing
     */
    toggleFavorite(listingId, button) {
        // Animate the favorite button if animations manager is available
        if (window.animationsManager) {
            window.animationsManager.animateFavorite(button);
        }

        // Toggle favorite styling
        const icon = button.querySelector('svg');
        if (icon) {
            const currentFill = icon.style.fill;
            const isFavorited = currentFill === 'red' || currentFill === '#ef4444';

            if (isFavorited) {
                // Unfavorite
                icon.style.fill = 'none';
                icon.style.stroke = 'currentColor';
                button.setAttribute('data-favorited', 'false');
            } else {
                // Favorite
                icon.style.fill = '#ef4444';
                icon.style.stroke = '#ef4444';
                button.setAttribute('data-favorited', 'true');
            }
        }

        // Store in localStorage
        this.updateFavoriteStorage(listingId, !this.isFavorited(listingId));

        // Show notification if available
        if (window.notificationsManager) {
            const message = this.isFavorited(listingId)
                ? 'Added to favorites'
                : 'Removed from favorites';
            window.notificationsManager.showInfo(message, { duration: 2000 });
        }

        console.log('Toggled favorite for listing:', listingId);
    }

    /**
     * Check if listing is favorited
     */
    isFavorited(listingId) {
        const favorites = this.getFavorites();
        return favorites.includes(listingId);
    }

    /**
     * Get user's favorites from localStorage
     */
    getFavorites() {
        try {
            const favorites = localStorage.getItem('user-favorites');
            return favorites ? JSON.parse(favorites) : [];
        } catch (error) {
            console.error('Error reading favorites:', error);
            return [];
        }
    }

    /**
     * Update favorite in localStorage
     */
    updateFavoriteStorage(listingId, isFavorited) {
        try {
            let favorites = this.getFavorites();

            if (isFavorited) {
                if (!favorites.includes(listingId)) {
                    favorites.push(listingId);
                }
            } else {
                favorites = favorites.filter(id => id !== listingId);
            }

            localStorage.setItem('user-favorites', JSON.stringify(favorites));
        } catch (error) {
            console.error('Error saving favorites:', error);
        }
    }

    /**
     * Initialize favorite buttons on page load
     */
    initializeFavoriteButtons() {
        const favorites = this.getFavorites();
        document.querySelectorAll('.favorite-btn').forEach(button => {
            const listingId = button.getAttribute('data-listing-id');
            if (favorites.includes(listingId)) {
                const icon = button.querySelector('svg');
                if (icon) {
                    icon.style.fill = '#ef4444';
                    icon.style.stroke = '#ef4444';
                    button.setAttribute('data-favorited', 'true');
                }
            }
        });
    }

    // ==================== FORM HELPERS ====================

    /**
     * Validate form fields
     */
    validateForm(formElement) {
        const errors = [];
        const requiredFields = formElement.querySelectorAll('[required]');

        requiredFields.forEach(field => {
            const value = field.value.trim();
            if (!value) {
                errors.push(`${field.name || field.id} is required`);
                field.classList.add('border-red-500');
            } else {
                field.classList.remove('border-red-500');
            }

            // Specific validations
            if (field.type === 'email' && value && !window.utilityHelpers?.validateEmail(value)) {
                errors.push('Please enter a valid email address');
                field.classList.add('border-red-500');
            }

            if (field.type === 'number' && value && isNaN(value)) {
                errors.push(`${field.name || field.id} must be a number`);
                field.classList.add('border-red-500');
            }
        });

        return errors;
    }

    /**
     * Show form validation errors
     */
    showFormErrors(errors, formElement) {
        // Remove existing error display
        const existingError = formElement.querySelector('.form-errors');
        if (existingError) {
            existingError.remove();
        }

        if (errors.length === 0) return;

        // Create error display
        const errorDiv = document.createElement('div');
        errorDiv.className = 'form-errors bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-4';
        errorDiv.innerHTML = `
            <h4 class="font-semibold mb-2">Please correct the following errors:</h4>
            <ul class="list-disc list-inside">
                ${errors.map(error => `<li>${error}</li>`).join('')}
            </ul>
        `;

        formElement.insertBefore(errorDiv, formElement.firstChild);
    }

    // ==================== UTILITY FUNCTIONS ====================

    /**
     * Get active filters
     */
    getActiveFilters() {
        return { ...this.currentFilters };
    }

    /**
     * Reset filters to default
     */
    resetFilters() {
        this.currentFilters = {};
        this.clearFilters();
    }

    /**
     * Export current filter state
     */
    exportFilters() {
        return {
            location: document.getElementById('searchLocation')?.value || '',
            priceMin: document.getElementById('priceMin')?.value || '',
            priceMax: document.getElementById('priceMax')?.value || '',
            bedroomsMin: document.getElementById('bedroomsMin')?.value || '',
            bedroomsMax: document.getElementById('bedroomsMax')?.value || '',
            houseType: document.getElementById('houseTypeFilter')?.value || '',
            utilities: document.getElementById('utilitiesFilter')?.value || ''
        };
    }

    /**
     * Import filter state
     */
    importFilters(filters) {
        Object.entries(filters).forEach(([key, value]) => {
            const element = document.getElementById(key === 'location' ? 'searchLocation' : key);
            if (element && value) {
                element.value = value;
            }
        });

        this.applySearchFilters();
    }

    /**
     * Destroy UI helpers
     */
    destroy() {
        clearTimeout(this.searchTimeout);
        this.currentFilters = {};
        this.isInitialized = false;
        console.log('🗑️ UI Helpers destroyed');
    }
}

// Create global instance
window.uiHelpers = new UIHelpers();

export default window.uiHelpers;