/**
 * Search & Filter Module
 * Handles search functionality, filtering, sorting, and form handling
 */

import { filterDisplayedListings } from './listings-ui.js';

// Global state
let cities = [];
let autocompleteCache = new Map();
let debounceTimers = new Map();

/**
 * Initialize the search and filter module
 */
export function initializeSearchFilter() {
    console.log('🔍 Search & Filter module initialized');
    
    // Load cities data
    loadCitiesData();
    
    // Setup search filters
    setupSearchFilters();
    
    // Setup autocomplete
    setupAutocomplete();
    
    // Setup form handlers
    setupFormHandlers();
}

/**
 * Load cities data for autocomplete
 */
async function loadCitiesData() {
    try {
        console.log('📍 Loading cities data...');
        const response = await fetch('https://unpkg.com/cities.json@1.1.0/cities.json');
        const data = await response.json();
        cities = data;
        console.log('✅ Cities loaded:', cities.length);
    } catch (error) {
        console.error('❌ Error loading cities:', error);
        // Fallback to empty array
        cities = [];
        
        // Update placeholder to indicate manual entry
        const cityInput = document.getElementById('city');
        if (cityInput) {
            cityInput.placeholder = 'Enter city manually (e.g., Toronto)';
        }
    }
}

/**
 * Setup search filters and URL parameter handling
 */
function setupSearchFilters() {
    console.log('🔧 Setting up search filters...');
    
    // Handle URL parameters for pre-filling search fields
    handleUrlParameters();
    
    // Set up search event listeners
    const searchInputs = [
        'searchLocation',
        'searchMaxPrice',
        'searchRoomType',
        'searchBedrooms'
    ];
    
    searchInputs.forEach(inputId => {
        const input = document.getElementById(inputId);
        if (input) {
            input.addEventListener('input', debounce(() => filterListings(), 300));
            input.addEventListener('change', filterListings);
        }
    });
    
    console.log('✅ Search filters setup complete');
}

/**
 * Handle URL parameters for pre-filling search fields
 */
function handleUrlParameters() {
    const urlParams = new URLSearchParams(window.location.search);
    const hashParams = new URLSearchParams(window.location.hash.split('?')[1] || '');
    
    // Combine URL params and hash params
    const allParams = new URLSearchParams();
    for (const [key, value] of urlParams) {
        allParams.set(key, value);
    }
    for (const [key, value] of hashParams) {
        allParams.set(key, value);
    }
    
    // Pre-fill search fields if parameters exist
    const paramMappings = {
        'location': 'searchLocation',
        'maxPrice': 'searchMaxPrice',
        'roomType': 'searchRoomType',
        'bedrooms': 'searchBedrooms'
    };
    
    Object.entries(paramMappings).forEach(([paramName, inputId]) => {
        const paramValue = allParams.get(paramName);
        const input = document.getElementById(inputId);
        if (paramValue && input) {
            input.value = paramValue;
            console.log(`🔗 Pre-filled ${inputId} with: ${paramValue}`);
        }
    });
    
    // Initial filter if parameters were provided
    if (allParams.size > 0) {
        setTimeout(() => filterListings(), 500); // Allow time for listings to load
    }
    
    // Handle messaging popup if openChat parameter exists
    if (window.location.href.includes('openChat=true')) {
        setTimeout(() => {
            const messagingBtn = document.querySelector('.messaging-toggle-btn');
            if (messagingBtn) {
                messagingBtn.click();
            }
        }, 1000);
    }
    
    // Scroll to search section if hash includes search-section
    if (window.location.hash.includes('search-section')) {
        setTimeout(() => {
            const searchSection = document.querySelector('[id*="search"], .bg-gray-50');
            if (searchSection) {
                searchSection.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        }, 500);
    }
}

/**
 * Setup autocomplete functionality
 */
function setupAutocomplete() {
    console.log('🔧 Setting up autocomplete...');
    
    // City autocomplete
    setupCityAutocomplete();
    
    // Setup other autocomplete fields if needed
    // Could add street name autocomplete, etc.
}

/**
 * Setup city autocomplete
 */
function setupCityAutocomplete() {
    const cityInput = document.getElementById('city');
    const cityDropdown = document.getElementById('city-autocomplete-dropdown');
    
    if (!cityInput || !cityDropdown) {
        console.warn('⚠️ City autocomplete elements not found');
        return;
    }
    
    // Input event listener
    cityInput.addEventListener('input', () => {
        const inputId = 'city';
        clearTimeout(debounceTimers.get(inputId));
        debounceTimers.set(inputId, setTimeout(() => {
            const value = cityInput.value.trim();
            console.log('🔍 City input event:', value);
            showCitySuggestions(value);
        }, 300));
    });
    
    // Keyboard navigation
    cityInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !cityDropdown.classList.contains('hidden')) {
            const firstItem = cityDropdown.querySelector('.autocomplete-item:not(.text-gray-500)');
            if (firstItem) {
                cityInput.value = firstItem.textContent;
                cityDropdown.classList.add('hidden');
                console.log('⌨️ Enter key selected city:', firstItem.textContent);
            }
            e.preventDefault();
        }
    });
    
    // Click outside to close
    document.addEventListener('click', (e) => {
        if (!cityInput.contains(e.target) && !cityDropdown.contains(e.target)) {
            cityDropdown.classList.add('hidden');
        }
    });
}

/**
 * Show city suggestions
 * @param {string} input - User input
 */
function showCitySuggestions(input) {
    const cityDropdown = document.getElementById('city-autocomplete-dropdown');
    if (!cityDropdown) return;
    
    cityDropdown.innerHTML = '';
    cityDropdown.classList.add('hidden');
    
    if (!input || cities.length === 0) return;
    
    // Check cache first
    const cacheKey = input.toLowerCase();
    if (autocompleteCache.has(cacheKey)) {
        displaySuggestions(autocompleteCache.get(cacheKey));
        return;
    }
    
    // Filter cities
    const filtered = cities
        .filter(city => 
            city.name.toLowerCase().startsWith(input.toLowerCase()) ||
            city.name.toLowerCase().includes(input.toLowerCase())
        )
        .slice(0, 10)
        .map(city => ({
            display: `${city.name}${city.admin_name ? `, ${city.admin_name}` : ''}, ${city.country}`,
            value: city
        }));
    
    // Cache results
    autocompleteCache.set(cacheKey, filtered);
    
    displaySuggestions(filtered);
}

/**
 * Display autocomplete suggestions
 * @param {Array} suggestions - Array of suggestion objects
 */
function displaySuggestions(suggestions) {
    const cityDropdown = document.getElementById('city-autocomplete-dropdown');
    const cityInput = document.getElementById('city');
    
    if (!cityDropdown || !cityInput) return;
    
    cityDropdown.innerHTML = '';
    
    if (suggestions.length === 0) {
        const item = document.createElement('div');
        item.className = 'autocomplete-item text-gray-500 px-4 py-2 text-sm';
        item.textContent = 'No matching cities';
        cityDropdown.appendChild(item);
        cityDropdown.classList.remove('hidden');
        return;
    }
    
    suggestions.forEach(suggestion => {
        const item = document.createElement('div');
        item.className = 'autocomplete-item px-4 py-2 text-sm hover:bg-gray-100 cursor-pointer';
        item.textContent = suggestion.display;
        item.addEventListener('click', () => {
            cityInput.value = suggestion.display;
            cityDropdown.classList.add('hidden');
            console.log('🎯 Selected city:', suggestion.display);
        });
        cityDropdown.appendChild(item);
    });
    
    cityDropdown.classList.remove('hidden');
    console.log('📋 Showing city suggestions:', suggestions.length);
}

/**
 * Filter listings based on search criteria
 */
export function filterListings() {
    console.log('🔍 Filtering listings...');
    
    // Get filter values
    const filters = {
        location: getInputValue('searchLocation'),
        maxPrice: getInputValue('searchMaxPrice', 'number'),
        roomType: getInputValue('searchRoomType'),
        bedrooms: getInputValue('searchBedrooms')
    };
    
    console.log('📋 Filter criteria:', filters);
    
    // Apply filters using the UI module
    const visibleCount = filterDisplayedListings(filters);
    
    // Update URL with current filters (optional)
    updateUrlWithFilters(filters);
    
    console.log('✅ Filtering complete:', visibleCount, 'listings visible');
    
    // Dispatch event for other modules
    document.dispatchEvent(new CustomEvent('listingsFiltered', {
        detail: { filters, visibleCount }
    }));
}

/**
 * Get input value with optional type conversion
 * @param {string} inputId - ID of the input element
 * @param {string} type - Type conversion ('number', 'string', etc.)
 * @returns {any} Input value
 */
function getInputValue(inputId, type = 'string') {
    const input = document.getElementById(inputId);
    if (!input) return type === 'number' ? null : '';
    
    const value = input.value.trim();
    if (!value) return type === 'number' ? null : '';
    
    switch (type) {
        case 'number':
            return parseInt(value) || null;
        default:
            return value;
    }
}

/**
 * Update URL with current filters (without page reload)
 * @param {Object} filters - Filter criteria
 */
function updateUrlWithFilters(filters) {
    const url = new URL(window.location);
    
    // Clear existing filter params
    url.searchParams.delete('location');
    url.searchParams.delete('maxPrice');
    url.searchParams.delete('roomType');
    url.searchParams.delete('bedrooms');
    
    // Add new filter params
    Object.entries(filters).forEach(([key, value]) => {
        if (value) {
            url.searchParams.set(key, value);
        }
    });
    
    // Update URL without reload
    window.history.replaceState({}, '', url);
}

/**
 * Setup form handlers for listing submission
 */
function setupFormHandlers() {
    console.log('🔧 Setting up form handlers...');
    
    // File upload handler
    setupFileUpload();
    
    // Form validation
    setupFormValidation();
    
    // Input sanitization
    setupInputSanitization();
}

/**
 * Setup file upload functionality
 */
function setupFileUpload() {
    const mediaInput = document.getElementById('media');
    const mediaPreview = document.getElementById('mediaPreview');
    
    if (!mediaInput || !mediaPreview) {
        console.warn('⚠️ File upload elements not found');
        return;
    }
    
    let uploadedFiles = [];
    
    mediaInput.addEventListener('change', () => {
        mediaPreview.innerHTML = '';
        uploadedFiles = [];
        
        const files = Array.from(mediaInput.files);
        let totalSize = 0;
        
        files.forEach(file => {
            totalSize += file.size;
            
            // Check file size limit (10MB total)
            if (totalSize > 10 * 1024 * 1024) {
                alert('Total file size exceeds 10MB limit.');
                mediaInput.value = '';
                mediaPreview.innerHTML = '';
                uploadedFiles = [];
                return;
            }
            
            // Create file preview
            const reader = new FileReader();
            reader.onload = (e) => {
                const dataUrl = e.target.result;
                uploadedFiles.push({ 
                    name: file.name, 
                    type: file.type, 
                    data: dataUrl, 
                    file: file 
                });
                
                const previewElement = file.type.startsWith('image/')
                    ? `<img src="${dataUrl}" alt="${file.name}" class="w-20 h-20 object-cover rounded-lg">`
                    : `<video src="${dataUrl}" controls class="w-20 h-20 object-cover rounded-lg"></video>`;
                
                const previewContainer = document.createElement('div');
                previewContainer.className = 'relative inline-block m-1';
                previewContainer.innerHTML = `
                    ${previewElement}
                    <button type="button" class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 text-xs" onclick="this.parentElement.remove()">×</button>
                `;
                
                mediaPreview.appendChild(previewContainer);
                console.log('📁 Preview added for file:', file.name);
            };
            reader.readAsDataURL(file);
        });
        
        console.log('📁 Files selected:', files.map(f => f.name));
    });
}

/**
 * Setup form validation
 */
function setupFormValidation() {
    const form = document.getElementById('listingForm');
    if (!form) return;
    
    // Add validation classes and handlers
    const requiredFields = ['title', 'price', 'city', 'street', 'postalCode', 'houseType', 'bedrooms'];
    
    requiredFields.forEach(fieldId => {
        const field = document.getElementById(fieldId);
        if (field) {
            field.addEventListener('blur', () => validateField(field));
            field.addEventListener('input', () => clearFieldError(field));
        }
    });
}

/**
 * Validate a form field
 * @param {HTMLElement} field - Form field element
 */
function validateField(field) {
    const value = field.value.trim();
    let isValid = true;
    let errorMessage = '';
    
    // Check if required field is empty
    if (field.hasAttribute('required') && !value) {
        isValid = false;
        errorMessage = 'This field is required';
    }
    
    // Specific validation rules
    switch (field.id) {
        case 'price':
            if (value && (isNaN(value) || parseFloat(value) <= 0)) {
                isValid = false;
                errorMessage = 'Please enter a valid price';
            }
            break;
        case 'bedrooms':
            if (value && (isNaN(value) || parseInt(value) < 0)) {
                isValid = false;
                errorMessage = 'Please enter a valid number of bedrooms';
            }
            break;
        case 'postalCode':
            if (value && !isValidPostalCode(value)) {
                isValid = false;
                errorMessage = 'Please enter a valid postal code';
            }
            break;
    }
    
    // Show/hide error
    if (!isValid) {
        showFieldError(field, errorMessage);
    } else {
        clearFieldError(field);
    }
    
    return isValid;
}

/**
 * Show field error
 * @param {HTMLElement} field - Form field element
 * @param {string} message - Error message
 */
function showFieldError(field, message) {
    clearFieldError(field);
    
    field.classList.add('border-red-500');
    
    const errorElement = document.createElement('div');
    errorElement.className = 'text-red-500 text-sm mt-1';
    errorElement.textContent = message;
    errorElement.id = `${field.id}-error`;
    
    field.parentNode.appendChild(errorElement);
}

/**
 * Clear field error
 * @param {HTMLElement} field - Form field element
 */
function clearFieldError(field) {
    field.classList.remove('border-red-500');
    
    const errorElement = document.getElementById(`${field.id}-error`);
    if (errorElement) {
        errorElement.remove();
    }
}

/**
 * Validate postal code (basic validation)
 * @param {string} postalCode - Postal code to validate
 * @returns {boolean} Whether postal code is valid
 */
function isValidPostalCode(postalCode) {
    // Basic validation - adjust based on requirements
    const canadianPostalCode = /^[A-Za-z]\d[A-Za-z] \d[A-Za-z]\d$/;
    const usZipCode = /^\d{5}(-\d{4})?$/;
    
    return canadianPostalCode.test(postalCode) || usZipCode.test(postalCode);
}

/**
 * Setup input sanitization
 */
function setupInputSanitization() {
    // Add sanitization for text inputs
    const textInputs = document.querySelectorAll('input[type="text"], textarea');
    
    textInputs.forEach(input => {
        input.addEventListener('input', () => {
            // Basic sanitization - remove potentially harmful characters
            const sanitized = input.value.replace(/[<>]/g, '');
            if (sanitized !== input.value) {
                input.value = sanitized;
            }
        });
    });
}

/**
 * Smart autocorrect for text inputs
 * @param {string} input - Input text
 * @returns {string} Corrected text
 */
export function autocorrectInput(input) {
    if (typeof input !== 'string' || !input) return input;
    
    // Initialize Typo.js if available
    if (typeof Typo !== 'undefined') {
        try {
            const typo = new Typo('en_US', false, false, {
                dictionaryPath: 'https://unpkg.com/typo-js@1.2.3/dictionaries'
            });
            
            // Add custom dictionary words
            typo.dictionary = typo.dictionary || {};
            typo.dictionary['roomfinder'] = 1;
            typo.dictionary['wifi'] = 1;
            typo.dictionary['apartment'] = 1;
            typo.dictionary['condo'] = 1;
            typo.dictionary['sublease'] = 1;
            
            const words = input.split(' ');
            const correctedWords = words.map(word => {
                // Skip correction for numbers, proper nouns, and address terms
                if (/\d/.test(word) || /^[A-Z]/.test(word)) {
                    return word;
                }
                
                const addressTerms = ['street', 'road', 'avenue', 'drive', 'lane', 'court', 'place', 'way'];
                if (addressTerms.includes(word.toLowerCase())) {
                    return word;
                }
                
                // Only correct if word is clearly misspelled
                if (typo.check(word)) {
                    return word;
                }
                
                const suggestions = typo.suggest(word);
                if (suggestions.length > 0 && word.length > 3) {
                    console.log(`🔧 Autocorrect: ${word} -> ${suggestions[0]}`);
                    return suggestions[0];
                }
                
                return word;
            });
            
            return correctedWords.join(' ');
        } catch (error) {
            console.warn('⚠️ Autocorrect failed:', error);
            return input;
        }
    }
    
    return input;
}

/**
 * Clean address input
 * @param {string} input - Address input
 * @returns {string} Cleaned address
 */
export function cleanAddressInput(input) {
    if (typeof input !== 'string') return '';
    return input.trim()
        .replace(/\s+/g, ' ')  // Multiple spaces to single
        .replace(/[^\w\s\-.,#]/g, ''); // Remove special chars except basic ones
}

/**
 * Sanitize general input
 * @param {string} input - Input to sanitize
 * @returns {string} Sanitized input
 */
export function sanitizeInput(input) {
    if (typeof input !== 'string') return '';
    return input.replace(/[^a-zA-Z0-9\s,.-]/g, '').trim();
}

/**
 * Debounce function
 * @param {Function} func - Function to debounce
 * @param {number} wait - Wait time in milliseconds
 * @returns {Function} Debounced function
 */
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

/**
 * Clear all filters
 */
export function clearAllFilters() {
    const searchInputs = [
        'searchLocation',
        'searchMaxPrice',
        'searchRoomType',
        'searchBedrooms'
    ];
    
    searchInputs.forEach(inputId => {
        const input = document.getElementById(inputId);
        if (input) {
            input.value = '';
        }
    });
    
    // Trigger filter update
    filterListings();
    
    console.log('🧹 All filters cleared');
}

/**
 * Get current filter values
 * @returns {Object} Current filter values
 */
export function getCurrentFilters() {
    return {
        location: getInputValue('searchLocation'),
        maxPrice: getInputValue('searchMaxPrice', 'number'),
        roomType: getInputValue('searchRoomType'),
        bedrooms: getInputValue('searchBedrooms')
    };
}

/**
 * Set filter values
 * @param {Object} filters - Filter values to set
 */
export function setFilters(filters) {
    Object.entries(filters).forEach(([key, value]) => {
        const inputId = `search${key.charAt(0).toUpperCase() + key.slice(1)}`;
        const input = document.getElementById(inputId);
        if (input && value) {
            input.value = value;
        }
    });
    
    // Trigger filter update
    filterListings();
    
    console.log('📋 Filters set:', filters);
}

// Export all functions
export default {
    initializeSearchFilter,
    filterListings,
    autocorrectInput,
    cleanAddressInput,
    sanitizeInput,
    clearAllFilters,
    getCurrentFilters,
    setFilters
};