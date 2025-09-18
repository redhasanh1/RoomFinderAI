/**
 * Autocomplete Module
 * Handles autocomplete functionality, text correction, and city suggestions
 */

class AutocompleteManager {
    constructor() {
        this.typo = null;
        this.cities = [];
        this.isInitialized = false;
        this.debounceTimeout = null;
        this.cityInput = null;
        this.cityDropdown = null;
    }

    /**
     * Initialize the autocomplete manager
     */
    async init() {
        await this.initializeTypo();
        await this.loadCities();
        this.setupCityAutocomplete();

        this.isInitialized = true;
        console.log('✅ Autocomplete Manager initialized');
    }

    /**
     * Initialize Typo.js for autocorrect
     */
    async initializeTypo() {
        try {
            this.typo = new Typo('en_US', false, false, {
                dictionaryPath: 'https://unpkg.com/typo-js@1.2.3/dictionaries'
            });

            // Add custom dictionary words
            const customWords = [
                'roomfinder', 'wifi', 'appartment', 'condo', 'sublease',
                'negoitator', 'loft', 'studio', 'penthouse', 'duplex'
            ];

            customWords.forEach(word => {
                this.typo.dictionary[word] = 1;
            });

            console.log('✅ Typo.js initialized with custom dictionary');
        } catch (error) {
            console.error('Failed to initialize Typo.js:', error);
        }
    }

    /**
     * Load cities data for autocomplete
     */
    async loadCities() {
        try {
            const response = await fetch('https://unpkg.com/cities.json@1.1.0/cities.json');
            this.cities = await response.json();
            console.log('Cities loaded:', this.cities.length);
        } catch (error) {
            console.error('Error loading cities:', error);
            this.showCityLoadError();
        }
    }

    /**
     * Setup city autocomplete functionality
     */
    setupCityAutocomplete() {
        this.cityInput = document.getElementById('city');
        this.cityDropdown = document.getElementById('city-autocomplete-dropdown');

        if (!this.cityInput || !this.cityDropdown) {
            console.warn('City input or dropdown not found');
            return;
        }

        // Input event listener
        this.cityInput.addEventListener('input', () => {
            clearTimeout(this.debounceTimeout);
            this.debounceTimeout = setTimeout(() => {
                const value = this.cityInput.value.trim();
                console.log('City input event:', value);
                this.showCitySuggestions(value);
            }, 300);
        });

        // Keydown event listener
        this.cityInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !this.cityDropdown.classList.contains('hidden')) {
                const firstItem = this.cityDropdown.querySelector('.autocomplete-item:not(.text-gray-500)');
                if (firstItem) {
                    this.cityInput.value = firstItem.textContent;
                    this.cityDropdown.classList.add('hidden');
                    console.log('Enter key selected city:', firstItem.textContent);
                }
                e.preventDefault();
            }
        });

        // Click outside to close
        document.addEventListener('click', (e) => {
            if (!this.cityInput.contains(e.target) && !this.cityDropdown.contains(e.target)) {
                this.cityDropdown.classList.add('hidden');
                console.log('City dropdown hidden');
            }
        });
    }

    /**
     * Show city suggestions based on input
     */
    showCitySuggestions(input) {
        this.cityDropdown.innerHTML = '';
        this.cityDropdown.classList.add('hidden');

        if (!input || this.cities.length === 0) return;

        const filtered = this.cities
            .filter(city =>
                city.name.toLowerCase().startsWith(input.toLowerCase()) ||
                city.name.toLowerCase().includes(input.toLowerCase())
            )
            .slice(0, 10)
            .map(city => ({
                display: `${city.name}${city.admin_name ? `, ${city.admin_name}` : ''}, ${city.country}`,
                value: city
            }));

        if (filtered.length === 0) {
            const item = document.createElement('div');
            item.className = 'autocomplete-item text-gray-500';
            item.textContent = 'No matching cities';
            this.cityDropdown.appendChild(item);
            this.cityDropdown.classList.remove('hidden');
            return;
        }

        filtered.forEach(loc => {
            const item = document.createElement('div');
            item.className = 'autocomplete-item';
            item.textContent = loc.display;
            item.addEventListener('click', () => {
                this.cityInput.value = loc.display;
                this.cityDropdown.classList.add('hidden');
                console.log('Selected city:', loc.display);
            });
            this.cityDropdown.appendChild(item);
        });

        this.cityDropdown.classList.remove('hidden');
        console.log('Showing city suggestions for:', input, filtered.map(f => f.display));
    }

    /**
     * Smart autocorrect - preserves addresses, numbers, and proper nouns
     */
    autocorrectInput(input) {
        if (typeof input !== 'string' || !input || !this.typo) return input;

        const words = input.split(' ');
        const correctedWords = words.map(word => {
            // Skip correction for numbers (including mixed alphanumeric like postal codes)
            if (/\d/.test(word)) {
                console.log(`Skipping autocorrect for number/code: ${word}`);
                return word;
            }

            // Skip correction for capitalized words (likely proper nouns like street names)
            if (/^[A-Z]/.test(word)) {
                console.log(`Skipping autocorrect for proper noun: ${word}`);
                return word;
            }

            // Skip common address terms
            const addressTerms = [
                'street', 'road', 'avenue', 'drive', 'lane', 'court', 'place', 'way',
                'blvd', 'ave', 'rd', 'dr', 'st', 'ln', 'ct', 'pl'
            ];
            if (addressTerms.includes(word.toLowerCase())) {
                console.log(`Skipping autocorrect for address term: ${word}`);
                return word;
            }

            // Skip words that are already correctly spelled
            if (this.typo.check(word)) {
                return word;
            }

            // Only correct if word is clearly misspelled and suggestion is confident
            const suggestions = this.typo.suggest(word);
            if (suggestions.length > 0) {
                const suggestion = suggestions[0];
                // Only auto-correct if the suggestion is significantly different
                // and the original word is clearly wrong (not just uncommon)
                if (word.length > 3 && suggestion.length > 2) {
                    console.log(`Autocorrect: ${word} -> ${suggestion}`);
                    return suggestion;
                }
            }

            console.log(`No autocorrect applied to: ${word}`);
            return word;
        });

        return correctedWords.join(' ');
    }

    /**
     * Safe autocorrect for addresses - only basic cleanup
     */
    cleanAddressInput(input) {
        if (typeof input !== 'string') return '';
        return input.trim()
            .replace(/\s+/g, ' ')  // Multiple spaces to single
            .replace(/[^\w\s\-.,#]/g, ''); // Remove special chars except basic ones
    }

    /**
     * Sanitize input by removing dangerous characters
     */
    sanitizeInput(input) {
        if (typeof input !== 'string') return '';
        return input.replace(/[^a-zA-Z0-9\s,.-]/g, '').trim();
    }

    /**
     * Get autocomplete suggestions for any input
     */
    getAutocompleteSuggestions(input, dataSource = 'cities') {
        if (!input) return [];

        switch (dataSource) {
            case 'cities':
                return this.getCitySuggestions(input);
            default:
                return [];
        }
    }

    /**
     * Get city suggestions
     */
    getCitySuggestions(input) {
        if (!input || this.cities.length === 0) return [];

        return this.cities
            .filter(city =>
                city.name.toLowerCase().startsWith(input.toLowerCase()) ||
                city.name.toLowerCase().includes(input.toLowerCase())
            )
            .slice(0, 10)
            .map(city => ({
                display: `${city.name}${city.admin_name ? `, ${city.admin_name}` : ''}, ${city.country}`,
                value: city.name,
                data: city
            }));
    }

    /**
     * Setup autocomplete for any input element
     */
    setupAutocomplete(inputElement, dataSource = 'cities', options = {}) {
        if (!inputElement) return;

        const {
            minChars = 1,
            maxSuggestions = 10,
            debounceMs = 300,
            placeholder = 'No suggestions found'
        } = options;

        let dropdown = inputElement.parentNode.querySelector('.autocomplete-dropdown');

        if (!dropdown) {
            dropdown = document.createElement('div');
            dropdown.className = 'autocomplete-dropdown custom-autocomplete hidden';
            inputElement.parentNode.appendChild(dropdown);
        }

        let debounceTimeout;

        inputElement.addEventListener('input', () => {
            clearTimeout(debounceTimeout);
            debounceTimeout = setTimeout(() => {
                const value = inputElement.value.trim();

                if (value.length < minChars) {
                    dropdown.classList.add('hidden');
                    return;
                }

                const suggestions = this.getAutocompleteSuggestions(value, dataSource)
                    .slice(0, maxSuggestions);

                this.renderSuggestions(dropdown, suggestions, inputElement, placeholder);
            }, debounceMs);
        });

        // Handle keyboard navigation
        inputElement.addEventListener('keydown', (e) => {
            const items = dropdown.querySelectorAll('.autocomplete-item:not(.text-gray-500)');

            if (e.key === 'ArrowDown') {
                e.preventDefault();
                this.selectNextItem(items, 1);
            } else if (e.key === 'ArrowUp') {
                e.preventDefault();
                this.selectNextItem(items, -1);
            } else if (e.key === 'Enter') {
                e.preventDefault();
                const selected = dropdown.querySelector('.autocomplete-item.selected');
                if (selected) {
                    inputElement.value = selected.textContent;
                    dropdown.classList.add('hidden');
                }
            } else if (e.key === 'Escape') {
                dropdown.classList.add('hidden');
            }
        });

        // Click outside to close
        document.addEventListener('click', (e) => {
            if (!inputElement.contains(e.target) && !dropdown.contains(e.target)) {
                dropdown.classList.add('hidden');
            }
        });
    }

    /**
     * Render autocomplete suggestions
     */
    renderSuggestions(dropdown, suggestions, inputElement, placeholder) {
        dropdown.innerHTML = '';

        if (suggestions.length === 0) {
            const item = document.createElement('div');
            item.className = 'autocomplete-item text-gray-500';
            item.textContent = placeholder;
            dropdown.appendChild(item);
        } else {
            suggestions.forEach((suggestion, index) => {
                const item = document.createElement('div');
                item.className = 'autocomplete-item';
                item.textContent = suggestion.display;
                item.addEventListener('click', () => {
                    inputElement.value = suggestion.display;
                    dropdown.classList.add('hidden');
                });

                if (index === 0) {
                    item.classList.add('selected');
                }

                dropdown.appendChild(item);
            });
        }

        dropdown.classList.remove('hidden');
    }

    /**
     * Handle keyboard navigation in suggestions
     */
    selectNextItem(items, direction) {
        if (items.length === 0) return;

        const currentSelected = Array.from(items).findIndex(item =>
            item.classList.contains('selected')
        );

        // Remove current selection
        items.forEach(item => item.classList.remove('selected'));

        // Calculate new index
        let newIndex = currentSelected + direction;
        if (newIndex < 0) newIndex = items.length - 1;
        if (newIndex >= items.length) newIndex = 0;

        // Select new item
        items[newIndex].classList.add('selected');
    }

    /**
     * Show error when cities fail to load
     */
    showCityLoadError() {
        if (this.cityInput) {
            this.cityInput.placeholder = 'Enter city manually (e.g., Toronto)';
        }

        // Show error notification if available
        if (window.notifications) {
            window.notifications.showError('Failed to load city data. Please enter city manually.');
        }
    }

    /**
     * Get loaded cities
     */
    getCities() {
        return this.cities;
    }

    /**
     * Clear all autocomplete dropdowns
     */
    clearAllDropdowns() {
        document.querySelectorAll('.autocomplete-dropdown').forEach(dropdown => {
            dropdown.classList.add('hidden');
        });
    }
}

// Create global instance
window.autocompleteManager = new AutocompleteManager();

// Export global functions for backward compatibility
window.autocorrectInput = (input) => {
    return window.autocompleteManager ?
        window.autocompleteManager.autocorrectInput(input) : input;
};

window.cleanAddressInput = (input) => {
    return window.autocompleteManager ?
        window.autocompleteManager.cleanAddressInput(input) : input;
};

window.sanitizeInput = (input) => {
    return window.autocompleteManager ?
        window.autocompleteManager.sanitizeInput(input) : input;
};

export default window.autocompleteManager;