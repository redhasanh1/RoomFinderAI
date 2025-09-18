/**
 * Search Controller Module
 * Handles search functionality, filtering, and text processing
 */

class SearchController {
    constructor() {
        this.isInitialized = false;
        this.currentFilters = {};
        this.searchCallbacks = [];
        this.searchInput = null;
        this.heroSearchInput = null;
    }

    /**
     * Initialize the search controller
     */
    init() {
        this.searchInput = document.getElementById('searchLocation');
        this.heroSearchInput = document.getElementById('heroSearchInput');

        if (this.heroSearchInput) {
            this.setupHeroSearch();
        }

        if (this.searchInput) {
            this.setupMainSearch();
        }

        this.isInitialized = true;
        console.log('✅ Search Controller initialized');
    }

    /**
     * Setup hero search functionality
     */
    setupHeroSearch() {
        // Hero search input event listener
        this.heroSearchInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                this.performHeroSearch();
            }
        });

        // Hero search button is handled by onclick in HTML
        window.heroQuickSearch = () => {
            this.performHeroSearch();
        };
    }

    /**
     * Setup main search functionality
     */
    setupMainSearch() {
        this.searchInput.addEventListener('input', (e) => {
            this.debounceSearch(() => {
                this.performSearch(e.target.value);
            }, 300);
        });

        this.searchInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                this.performSearch(e.target.value);
            }
        });
    }

    /**
     * Perform hero search
     */
    performHeroSearch() {
        const searchTerm = this.heroSearchInput.value.trim();

        if (searchTerm) {
            // Transfer search term to main search if available
            if (this.searchInput) {
                this.searchInput.value = searchTerm;
            }

            this.scrollToListings();
            this.performSearch(searchTerm);
        } else {
            this.scrollToListings();
        }
    }

    /**
     * Perform search with filters
     */
    performSearch(searchTerm = '') {
        console.log('Performing search:', searchTerm);

        // Update current filters
        this.currentFilters.search = searchTerm.toLowerCase().trim();

        // Apply search to listings
        this.applyFilters();

        // Notify callbacks
        this.notifySearchCallbacks(searchTerm, this.currentFilters);
    }

    /**
     * Apply current filters to listings
     */
    applyFilters() {
        if (!window.listingsManager) {
            console.warn('Listings manager not available');
            return;
        }

        const filterFunction = (listing) => {
            return this.matchesFilters(listing, this.currentFilters);
        };

        // Apply filter if any filters are active
        const hasActiveFilters = Object.values(this.currentFilters).some(filter =>
            filter !== '' && filter !== null && filter !== undefined
        );

        if (hasActiveFilters) {
            window.listingsManager.filterListings(filterFunction);
        } else {
            window.listingsManager.filterListings(null); // Clear filters
        }
    }

    /**
     * Check if a listing matches current filters
     */
    matchesFilters(listing, filters) {
        // Search term filter
        if (filters.search) {
            const searchFields = [
                listing.title,
                listing.description,
                listing.city,
                listing.street,
                listing.house_type,
                listing.utilities
            ].map(field => (field || '').toLowerCase());

            const searchTerms = filters.search.split(' ');
            const matchesSearch = searchTerms.every(term =>
                searchFields.some(field => field.includes(term))
            );

            if (!matchesSearch) return false;
        }

        // Price range filter
        if (filters.minPrice !== undefined && listing.price < filters.minPrice) {
            return false;
        }

        if (filters.maxPrice !== undefined && listing.price > filters.maxPrice) {
            return false;
        }

        // Bedrooms filter
        if (filters.bedrooms !== undefined && listing.bedrooms !== filters.bedrooms) {
            return false;
        }

        // House type filter
        if (filters.houseType && listing.house_type !== filters.houseType) {
            return false;
        }

        // Utilities filter
        if (filters.utilities && listing.utilities !== filters.utilities) {
            return false;
        }

        // City filter
        if (filters.city && !listing.city.toLowerCase().includes(filters.city.toLowerCase())) {
            return false;
        }

        return true;
    }

    /**
     * Set specific filter
     */
    setFilter(filterName, value) {
        this.currentFilters[filterName] = value;
        this.applyFilters();
    }

    /**
     * Clear specific filter
     */
    clearFilter(filterName) {
        delete this.currentFilters[filterName];
        this.applyFilters();
    }

    /**
     * Clear all filters
     */
    clearAllFilters() {
        this.currentFilters = {};

        // Clear search inputs
        if (this.searchInput) this.searchInput.value = '';
        if (this.heroSearchInput) this.heroSearchInput.value = '';

        this.applyFilters();
    }

    /**
     * Get current filters
     */
    getCurrentFilters() {
        return { ...this.currentFilters };
    }

    /**
     * Scroll to listings section
     */
    scrollToListings() {
        const listingsSection = document.getElementById('listings-display');
        if (listingsSection) {
            listingsSection.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    }

    /**
     * Debounce search input
     */
    debounceSearch(func, delay) {
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }

        this.searchTimeout = setTimeout(func, delay);
    }

    /**
     * Register search callback
     */
    onSearch(callback) {
        this.searchCallbacks.push(callback);
    }

    /**
     * Notify search callbacks
     */
    notifySearchCallbacks(searchTerm, filters) {
        this.searchCallbacks.forEach(callback => {
            try {
                callback(searchTerm, filters);
            } catch (error) {
                console.error('Error in search callback:', error);
            }
        });
    }

    /**
     * Get search suggestions (placeholder for future implementation)
     */
    getSearchSuggestions(searchTerm) {
        // This could be expanded to provide search suggestions
        // based on existing listings or popular searches
        return [];
    }

    /**
     * Highlight search terms in text
     */
    highlightSearchTerms(text, searchTerm) {
        if (!searchTerm || !text) return text;

        const terms = searchTerm.split(' ').filter(term => term.length > 0);
        let highlightedText = text;

        terms.forEach(term => {
            const regex = new RegExp(`(${term})`, 'gi');
            highlightedText = highlightedText.replace(regex, '<mark>$1</mark>');
        });

        return highlightedText;
    }

    /**
     * Advanced search with multiple criteria
     */
    advancedSearch(criteria) {
        console.log('Performing advanced search:', criteria);

        // Merge criteria into current filters
        Object.assign(this.currentFilters, criteria);

        this.applyFilters();
        this.notifySearchCallbacks('', this.currentFilters);
    }

    /**
     * Save search to history (localStorage)
     */
    saveSearchToHistory(searchTerm) {
        if (!searchTerm || searchTerm.length < 2) return;

        const searches = JSON.parse(localStorage.getItem('searchHistory') || '[]');

        // Remove existing instance if any
        const existingIndex = searches.indexOf(searchTerm);
        if (existingIndex > -1) {
            searches.splice(existingIndex, 1);
        }

        // Add to beginning
        searches.unshift(searchTerm);

        // Keep only last 10 searches
        if (searches.length > 10) {
            searches.splice(10);
        }

        localStorage.setItem('searchHistory', JSON.stringify(searches));
    }

    /**
     * Get search history
     */
    getSearchHistory() {
        return JSON.parse(localStorage.getItem('searchHistory') || '[]');
    }

    /**
     * Clear search history
     */
    clearSearchHistory() {
        localStorage.removeItem('searchHistory');
    }
}

// Create global instance
window.searchController = new SearchController();

// Setup global search functions for backward compatibility
window.heroQuickSearch = () => {
    if (window.searchController) {
        window.searchController.performHeroSearch();
    }
};

window.scrollToListings = () => {
    if (window.searchController) {
        window.searchController.scrollToListings();
    }
};

export default window.searchController;