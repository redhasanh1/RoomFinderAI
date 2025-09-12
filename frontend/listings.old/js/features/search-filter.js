/**
 * Search & Filter Module
 * Handles search functionality, filtering, and form management
 */

let searchInitialized = false;
let autocompleteCache = new Map();
let debounceTimer = null;
let currentFilters = {};

/**
 * Initialize search and filter functionality
 */
function initializeSearchFilter() {
    try {
        // Setup form handlers
        setupFormHandlers();
        
        // Setup autocomplete
        setupAutocomplete();
        
        // Setup filter handlers
        setupFilterHandlers();
        
        // Initialize URL parameters
        initializeFromURL();
        
        searchInitialized = true;
        console.log('🔍 Search & Filter initialized');
        return true;
    } catch (error) {
        console.error('❌ Failed to initialize Search & Filter:', error);
        return false;
    }
}

/**
 * Setup form handlers
 */
function setupFormHandlers() {
    // Add listing form
    const addListingForm = document.getElementById('add-listing-form');
    if (addListingForm) {
        addListingForm.addEventListener('submit', handleAddListingSubmit);
        
        // File upload handling
        const fileInput = addListingForm.querySelector('input[type="file"]');
        if (fileInput) {
            fileInput.addEventListener('change', handleFileUpload);
        }
        
        // Form validation
        setupFormValidation(addListingForm);
    }
    
    // Search form
    const searchButton = document.getElementById('search-button');
    if (searchButton) {
        searchButton.addEventListener('click', handleSearchSubmit);
    }
    
    // Search input with debouncing
    const searchInputs = document.querySelectorAll('input[type="search"], input[name="city"], input[name="country"]');
    searchInputs.forEach(input => {
        input.addEventListener('input', debounceSearch);
    });
    
    // Filter checkboxes
    const filterCheckboxes = document.querySelectorAll('input[type="checkbox"][name^="filter"]');
    filterCheckboxes.forEach(checkbox => {
        checkbox.addEventListener('change', handleFilterChange);
    });
    
    // Price range inputs
    const priceInputs = document.querySelectorAll('input[name="minPrice"], input[name="maxPrice"]');
    priceInputs.forEach(input => {
        input.addEventListener('input', debounceSearch);
    });
    
    // Clear filters button
    const clearFiltersButton = document.getElementById('clear-filters');
    if (clearFiltersButton) {
        clearFiltersButton.addEventListener('click', clearAllFilters);
    }
}

/**
 * Setup autocomplete functionality
 */
function setupAutocomplete() {
    const cityInput = document.getElementById('city');
    const countryInput = document.getElementById('country');
    
    if (cityInput) {
        setupCityAutocomplete(cityInput);
    }
    
    if (countryInput) {
        setupCountryAutocomplete(countryInput);
    }
}

/**
 * Setup city autocomplete
 */
function setupCityAutocomplete(input) {
    let autocompleteContainer = input.nextElementSibling;
    
    if (!autocompleteContainer || !autocompleteContainer.classList.contains('custom-autocomplete')) {
        autocompleteContainer = document.createElement('div');
        autocompleteContainer.className = 'custom-autocomplete';
        autocompleteContainer.style.display = 'none';
        input.parentNode.insertBefore(autocompleteContainer, input.nextSibling);
    }
    
    input.addEventListener('input', async (e) => {
        const query = e.target.value.trim();
        
        if (query.length < 2) {
            autocompleteContainer.style.display = 'none';
            return;
        }
        
        try {
            const cities = await fetchCities(query);
            displayAutocomplete(autocompleteContainer, cities, input);
        } catch (error) {
            console.error('❌ Autocomplete error:', error);
        }
    });
    
    // Hide autocomplete when clicking outside
    document.addEventListener('click', (e) => {
        if (!input.contains(e.target) && !autocompleteContainer.contains(e.target)) {
            autocompleteContainer.style.display = 'none';
        }
    });
}

/**
 * Fetch cities from external API with caching
 */
async function fetchCities(query) {
    const cacheKey = `cities_${query.toLowerCase()}`;
    
    // Check cache first
    if (autocompleteCache.has(cacheKey)) {
        return autocompleteCache.get(cacheKey);
    }
    
    try {
        const response = await fetch(`https://api.teleport.org/api/cities/?search=${encodeURIComponent(query)}&limit=5`);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        
        const data = await response.json();
        const cities = data._embedded ? data._embedded['city:search-results'].map(city => ({
            name: city.matching_full_name,
            country: city.matching_full_name.split(',').pop().trim()
        })) : [];
        
        // Cache results
        autocompleteCache.set(cacheKey, cities);
        
        // Limit cache size
        if (autocompleteCache.size > 100) {
            const firstKey = autocompleteCache.keys().next().value;
            autocompleteCache.delete(firstKey);
        }
        
        return cities;
    } catch (error) {
        console.error('❌ Failed to fetch cities:', error);
        return [];
    }
}

/**
 * Display autocomplete suggestions
 */
function displayAutocomplete(container, suggestions, input) {
    if (suggestions.length === 0) {
        container.style.display = 'none';
        return;
    }
    
    container.innerHTML = suggestions.map(suggestion => `
        <div class="autocomplete-item" data-value="${sanitizeInput(suggestion.name)}">
            ${sanitizeInput(suggestion.name)}
        </div>
    `).join('');
    
    container.style.display = 'block';
    
    // Add click handlers
    container.querySelectorAll('.autocomplete-item').forEach(item => {
        item.addEventListener('click', () => {
            input.value = item.dataset.value;
            container.style.display = 'none';
            
            // Trigger search
            handleFilterChange();
        });
    });
}

/**
 * Setup filter handlers
 */
function setupFilterHandlers() {
    // Room type filter
    const roomTypeSelect = document.getElementById('roomType');
    if (roomTypeSelect) {
        roomTypeSelect.addEventListener('change', handleFilterChange);
    }
    
    // Amenity filters
    const amenityFilters = ['wifi', 'parking', 'kitchen', 'laundry', 'furnished', 'petsAllowed'];
    amenityFilters.forEach(amenity => {
        const checkbox = document.getElementById(amenity);
        if (checkbox) {
            checkbox.addEventListener('change', handleFilterChange);
        }
    });
}

/**
 * Handle search with debouncing
 */
function debounceSearch() {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
        handleFilterChange();
    }, 300);
}

/**
 * Handle filter changes
 */
async function handleFilterChange() {
    try {
        const filters = getCurrentFilters();
        currentFilters = filters;
        
        // Update URL
        updateURL(filters);
        
        // Perform search
        await performSearch(filters);
        
        // Trigger custom event
        document.dispatchEvent(new CustomEvent('filtersChanged', { 
            detail: { filters: filters } 
        }));
        
    } catch (error) {
        console.error('❌ Error handling filter change:', error);
    }
}

/**
 * Get current filter values
 */
function getCurrentFilters() {
    const filters = {};
    
    // Text inputs
    const cityInput = document.getElementById('city');
    if (cityInput && cityInput.value.trim()) {
        filters.city = cleanAddressInput(cityInput.value);
    }
    
    const countryInput = document.getElementById('country');
    if (countryInput && countryInput.value.trim()) {
        filters.country = cleanAddressInput(countryInput.value);
    }
    
    // Room type
    const roomTypeSelect = document.getElementById('roomType');
    if (roomTypeSelect && roomTypeSelect.value) {
        filters.roomType = roomTypeSelect.value;
    }
    
    // Price range
    const minPriceInput = document.getElementById('minPrice');
    if (minPriceInput && minPriceInput.value) {
        filters.minPrice = parseFloat(minPriceInput.value);
    }
    
    const maxPriceInput = document.getElementById('maxPrice');
    if (maxPriceInput && maxPriceInput.value) {
        filters.maxPrice = parseFloat(maxPriceInput.value);
    }
    
    // Amenities
    const amenities = ['wifi', 'parking', 'kitchen', 'laundry', 'furnished', 'petsAllowed'];
    amenities.forEach(amenity => {
        const checkbox = document.getElementById(amenity);
        if (checkbox && checkbox.checked) {
            filters[amenity] = true;
        }
    });
    
    return filters;
}

/**
 * Set filter values
 */
function setFilters(filters) {
    try {
        // Text inputs
        if (filters.city) {
            const cityInput = document.getElementById('city');
            if (cityInput) cityInput.value = filters.city;
        }
        
        if (filters.country) {
            const countryInput = document.getElementById('country');
            if (countryInput) countryInput.value = filters.country;
        }
        
        // Room type
        if (filters.roomType) {
            const roomTypeSelect = document.getElementById('roomType');
            if (roomTypeSelect) roomTypeSelect.value = filters.roomType;
        }
        
        // Price range
        if (filters.minPrice) {
            const minPriceInput = document.getElementById('minPrice');
            if (minPriceInput) minPriceInput.value = filters.minPrice;
        }
        
        if (filters.maxPrice) {
            const maxPriceInput = document.getElementById('maxPrice');
            if (maxPriceInput) maxPriceInput.value = filters.maxPrice;
        }
        
        // Amenities
        const amenities = ['wifi', 'parking', 'kitchen', 'laundry', 'furnished', 'petsAllowed'];
        amenities.forEach(amenity => {
            const checkbox = document.getElementById(amenity);
            if (checkbox) {
                checkbox.checked = !!filters[amenity];
            }
        });
        
        currentFilters = filters;
        
    } catch (error) {
        console.error('❌ Error setting filters:', error);
    }
}

/**
 * Clear all filters
 */
function clearAllFilters() {
    try {
        // Clear text inputs
        const textInputs = document.querySelectorAll('#city, #country, #minPrice, #maxPrice');
        textInputs.forEach(input => {
            input.value = '';
        });
        
        // Clear select
        const roomTypeSelect = document.getElementById('roomType');
        if (roomTypeSelect) {
            roomTypeSelect.value = '';
        }
        
        // Clear checkboxes
        const checkboxes = document.querySelectorAll('input[type="checkbox"]');
        checkboxes.forEach(checkbox => {
            checkbox.checked = false;
        });
        
        // Clear current filters
        currentFilters = {};
        
        // Update URL
        updateURL({});
        
        // Perform search
        performSearch({});
        
        console.log('✅ All filters cleared');
        
    } catch (error) {
        console.error('❌ Error clearing filters:', error);
    }
}

/**
 * Perform search with filters
 */
async function performSearch(filters = {}) {
    try {
        // Show loading state
        showLoadingState();
        
        // Import ListingsAPI if using modules
        const { fetchListings } = window.ListingsAPI || await import('./listings-api.js');
        
        // Fetch filtered listings
        const listings = await fetchListings(filters);
        
        // Import ListingsUI if using modules
        const { displayListings } = window.ListingsUI || await import('./listings-ui.js');
        
        // Display listings
        displayListings(listings);
        
        console.log(`🔍 Search completed: ${listings.length} listings found`);
        
    } catch (error) {
        console.error('❌ Search error:', error);
        showErrorState('Search failed. Please try again.');
    }
}

/**
 * Handle add listing form submission
 */
async function handleAddListingSubmit(e) {
    e.preventDefault();
    
    try {
        const form = e.target;
        const formData = new FormData(form);
        
        // Validate form
        if (!validateForm(form)) {
            return;
        }
        
        // Extract listing data
        const listingData = extractListingData(formData);
        
        // Show loading state
        showSubmissionLoading(form);
        
        // Import ListingsAPI if using modules
        const { createListing, uploadMedia } = window.ListingsAPI || await import('./listings-api.js');
        
        // Create listing
        const newListing = await createListing(listingData);
        
        // Upload media if provided
        const files = formData.getAll('media');
        if (files.length > 0 && files[0].size > 0) {
            const uploadedMedia = await uploadMedia(files, newListing.id);
            
            // Update listing with media URLs
            const { updateListing } = window.ListingsAPI || await import('./listings-api.js');
            await updateListing(newListing.id, { media: uploadedMedia });
        }
        
        // Reset form
        form.reset();
        clearFilePreview();
        
        // Show success message
        showSuccessMessage('Listing created successfully!');
        
        // Refresh listings
        await performSearch(currentFilters);
        
        console.log('✅ Listing created successfully:', newListing.id);
        
    } catch (error) {
        console.error('❌ Error creating listing:', error);
        showErrorMessage('Failed to create listing. Please try again.');
    }
}

/**
 * Handle search form submission
 */
function handleSearchSubmit(e) {
    e.preventDefault();
    handleFilterChange();
}

/**
 * Extract listing data from form
 */
function extractListingData(formData) {
    return {
        title: sanitizeInput(formData.get('title')),
        description: sanitizeInput(formData.get('description')),
        city: cleanAddressInput(formData.get('city')),
        country: cleanAddressInput(formData.get('country')),
        street: cleanAddressInput(formData.get('street')),
        postal_code: sanitizeInput(formData.get('postalCode')),
        room_type: formData.get('roomType'),
        price: parseFloat(formData.get('price')),
        wifi: formData.has('wifi'),
        parking: formData.has('parking'),
        kitchen: formData.has('kitchen'),
        laundry: formData.has('laundry'),
        furnished: formData.has('furnished'),
        pets_allowed: formData.has('petsAllowed')
    };
}

/**
 * Setup form validation
 */
function setupFormValidation(form) {
    const inputs = form.querySelectorAll('input[required], textarea[required], select[required]');
    
    inputs.forEach(input => {
        input.addEventListener('blur', () => {
            validateField(input);
        });
        
        input.addEventListener('input', () => {
            clearFieldError(input);
        });
    });
}

/**
 * Validate entire form
 */
function validateForm(form) {
    const inputs = form.querySelectorAll('input[required], textarea[required], select[required]');
    let isValid = true;
    
    inputs.forEach(input => {
        if (!validateField(input)) {
            isValid = false;
        }
    });
    
    return isValid;
}

/**
 * Validate individual field
 */
function validateField(field) {
    const value = field.value.trim();
    
    // Required field validation
    if (field.hasAttribute('required') && !value) {
        showFieldError(field, 'This field is required');
        return false;
    }
    
    // Type-specific validation
    if (field.type === 'email' && value && !isValidEmail(value)) {
        showFieldError(field, 'Please enter a valid email address');
        return false;
    }
    
    if (field.type === 'number' && value && isNaN(parseFloat(value))) {
        showFieldError(field, 'Please enter a valid number');
        return false;
    }
    
    if (field.name === 'price' && value && parseFloat(value) < 0) {
        showFieldError(field, 'Price must be positive');
        return false;
    }
    
    clearFieldError(field);
    return true;
}

/**
 * Show field error
 */
function showFieldError(field, message) {
    const errorElement = field.parentNode.querySelector('.field-error');
    
    if (errorElement) {
        errorElement.textContent = message;
    } else {
        const error = document.createElement('div');
        error.className = 'field-error text-red-500 text-sm mt-1';
        error.textContent = message;
        field.parentNode.appendChild(error);
    }
    
    field.classList.add('border-red-500');
}

/**
 * Clear field error
 */
function clearFieldError(field) {
    const errorElement = field.parentNode.querySelector('.field-error');
    if (errorElement) {
        errorElement.remove();
    }
    
    field.classList.remove('border-red-500');
}

/**
 * Handle file upload with preview
 */
function handleFileUpload(e) {
    const files = Array.from(e.target.files);
    const previewContainer = document.getElementById('file-preview');
    
    if (!previewContainer) return;
    
    // Clear previous previews
    previewContainer.innerHTML = '';
    
    files.forEach((file, index) => {
        // Validate file
        if (file.size > 5 * 1024 * 1024) {
            showErrorMessage(`File ${file.name} is too large (max 5MB)`);
            return;
        }
        
        // Create preview
        const preview = document.createElement('div');
        preview.className = 'relative inline-block m-2';
        
        if (file.type.startsWith('image/')) {
            const img = document.createElement('img');
            img.src = URL.createObjectURL(file);
            img.className = 'w-20 h-20 object-cover rounded border';
            preview.appendChild(img);
        } else {
            const placeholder = document.createElement('div');
            placeholder.className = 'w-20 h-20 bg-gray-200 rounded border flex items-center justify-center text-xs';
            placeholder.textContent = file.name.substring(0, 8) + '...';
            preview.appendChild(placeholder);
        }
        
        // Add remove button
        const removeBtn = document.createElement('button');
        removeBtn.className = 'absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 text-xs';
        removeBtn.textContent = '×';
        removeBtn.onclick = () => removeFilePreview(index);
        preview.appendChild(removeBtn);
        
        previewContainer.appendChild(preview);
    });
}

/**
 * Remove file preview
 */
function removeFilePreview(index) {
    const fileInput = document.querySelector('input[type="file"]');
    if (fileInput) {
        const dt = new DataTransfer();
        const files = Array.from(fileInput.files);
        
        files.forEach((file, i) => {
            if (i !== index) {
                dt.items.add(file);
            }
        });
        
        fileInput.files = dt.files;
        handleFileUpload({ target: fileInput });
    }
}

/**
 * Clear file preview
 */
function clearFilePreview() {
    const previewContainer = document.getElementById('file-preview');
    if (previewContainer) {
        previewContainer.innerHTML = '';
    }
}

/**
 * Utility functions
 */
function sanitizeInput(input) {
    if (!input) return '';
    return input.toString().trim().replace(/<[^>]*>/g, '');
}

function cleanAddressInput(input) {
    if (!input) return '';
    
    // Apply autocorrect but preserve addresses and proper nouns
    const cleaned = sanitizeInput(input);
    
    // Don't autocorrect if it looks like an address or proper noun
    if (cleaned.match(/^\d+|street|avenue|road|blvd|drive|lane|way|court|place|st\.|ave\.|rd\.|dr\.|ln\.|ct\.|pl\./i)) {
        return cleaned;
    }
    
    return autocorrectInput(cleaned);
}

function autocorrectInput(input) {
    const typo = window.ConfigManager.getSpellChecker();
    if (!typo || !input) return input;
    
    try {
        const words = input.split(' ');
        const correctedWords = words.map(word => {
            const cleanWord = word.replace(/[^\w]/g, '');
            if (cleanWord.length < 3) return word;
            
            if (!typo.check(cleanWord)) {
                const suggestions = typo.suggest(cleanWord);
                if (suggestions.length > 0) {
                    return word.replace(cleanWord, suggestions[0]);
                }
            }
            return word;
        });
        
        return correctedWords.join(' ');
    } catch (error) {
        console.error('❌ Autocorrect error:', error);
        return input;
    }
}

function isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
}

function updateURL(filters) {
    const params = new URLSearchParams();
    
    Object.entries(filters).forEach(([key, value]) => {
        if (value !== null && value !== undefined && value !== '') {
            params.set(key, value);
        }
    });
    
    const newURL = `${window.location.pathname}${params.toString() ? '?' + params.toString() : ''}`;
    window.history.replaceState({}, '', newURL);
}

function initializeFromURL() {
    const params = new URLSearchParams(window.location.search);
    const filters = {};
    
    for (const [key, value] of params) {
        if (value) {
            filters[key] = value;
        }
    }
    
    if (Object.keys(filters).length > 0) {
        setFilters(filters);
        performSearch(filters);
    }
}

function showLoadingState() {
    const listingsContainer = document.getElementById('listingsContainer');
    if (listingsContainer) {
        listingsContainer.innerHTML = '<div class="text-center py-8">Searching...</div>';
    }
}

function showErrorState(message) {
    const listingsContainer = document.getElementById('listingsContainer');
    if (listingsContainer) {
        listingsContainer.innerHTML = `
            <div class="text-center py-8">
                <div class="text-red-500">${message}</div>
                <button onclick="window.location.reload()" class="mt-4 bg-blue-500 text-white px-4 py-2 rounded">
                    Retry
                </button>
            </div>
        `;
    }
}

function showSubmissionLoading(form) {
    const submitBtn = form.querySelector('button[type="submit"]');
    if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.textContent = 'Creating...';
    }
}

function showSuccessMessage(message) {
    // Implementation depends on your notification system
    console.log('✅', message);
    alert(message); // Replace with better notification
}

function showErrorMessage(message) {
    // Implementation depends on your notification system
    console.error('❌', message);
    alert(message); // Replace with better notification
}

// Export functions for use in other modules
export {
    initializeSearchFilter,
    setupFormHandlers,
    setupAutocomplete,
    setupFilterHandlers,
    debounceSearch,
    handleFilterChange,
    getCurrentFilters,
    setFilters,
    clearAllFilters,
    performSearch,
    handleAddListingSubmit,
    handleSearchSubmit,
    extractListingData,
    setupFormValidation,
    validateForm,
    validateField,
    handleFileUpload,
    removeFilePreview,
    clearFilePreview,
    sanitizeInput,
    cleanAddressInput,
    autocorrectInput,
    isValidEmail,
    updateURL,
    initializeFromURL
};

// Also export to window for backward compatibility
window.SearchFilter = {
    initializeSearchFilter,
    setupFormHandlers,
    setupAutocomplete,
    setupFilterHandlers,
    debounceSearch,
    handleFilterChange,
    getCurrentFilters,
    setFilters,
    clearAllFilters,
    performSearch,
    handleAddListingSubmit,
    handleSearchSubmit,
    extractListingData,
    setupFormValidation,
    validateForm,
    validateField,
    handleFileUpload,
    removeFilePreview,
    clearFilePreview,
    sanitizeInput,
    cleanAddressInput,
    autocorrectInput,
    isValidEmail,
    updateURL,
    initializeFromURL
};