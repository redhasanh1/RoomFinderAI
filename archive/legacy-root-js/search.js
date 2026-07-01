// Search and filter functionality module
window.SearchManager = (function() {
    let cities = [];
    let debounceTimeout;
    let filteredListings = [];

    // Load cities data for autocomplete
    function loadCitiesData() {
        return fetch('https://unpkg.com/cities.json@1.1.0/cities.json')
            .then(response => response.json())
            .then(data => {
                cities = data;
                console.log('Cities loaded:', cities.length);
                return cities;
            })
            .catch(error => {
                console.error('Error loading cities:', error);
                window.Utils?.showError('Failed to load city data. Please enter city manually.');
                
                const cityInput = document.getElementById('city');
                if (cityInput) {
                    cityInput.placeholder = 'Enter city manually (e.g., Toronto)';
                }
                return [];
            });
    }

    // Show city autocomplete suggestions
    function showCitySuggestions(input) {
        const cityDropdown = document.getElementById('city-autocomplete-dropdown');
        if (!cityDropdown) return;

        cityDropdown.innerHTML = '';
        cityDropdown.classList.add('hidden');
        
        if (!input || cities.length === 0) return;

        const filtered = cities
            .filter(city => 
                city.name.toLowerCase().startsWith(input.toLowerCase()) ||
                city.name.toLowerCase().includes(input.toLowerCase())
            )
            .slice(0, 10)
            .map(city => ({
                display: `${city.name}${city.admin_name ? `, ${city.admin_name}` : ''}, ${city.country}`,
                name: city.name,
                country: city.country,
                admin_name: city.admin_name
            }));

        if (filtered.length > 0) {
            filtered.forEach(city => {
                const item = document.createElement('div');
                item.className = 'autocomplete-item';
                item.textContent = city.display;
                item.addEventListener('click', () => {
                    const cityInput = document.getElementById('city');
                    if (cityInput) {
                        cityInput.value = city.name;
                    }
                    cityDropdown.classList.add('hidden');
                });
                cityDropdown.appendChild(item);
            });

            cityDropdown.classList.remove('hidden');
        } else {
            const noResults = document.createElement('div');
            noResults.className = 'autocomplete-item';
            noResults.textContent = 'No matching cities found';
            noResults.style.color = '#9ca3af';
            cityDropdown.appendChild(noResults);
            cityDropdown.classList.remove('hidden');
        }
    }

    // Setup city autocomplete functionality
    function setupCityAutocomplete() {
        const cityInput = document.getElementById('city');
        const cityDropdown = document.getElementById('city-autocomplete-dropdown');
        
        if (!cityInput || !cityDropdown) return;

        // Input event with debouncing
        cityInput.addEventListener('input', () => {
            clearTimeout(debounceTimeout);
            debounceTimeout = setTimeout(() => {
                const value = cityInput.value.trim();
                showCitySuggestions(value);
            }, 300);
        });

        // Keyboard navigation
        cityInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                cityDropdown.classList.add('hidden');
            }
        });

        // Click outside to close dropdown
        document.addEventListener('click', (e) => {
            if (!cityInput.contains(e.target) && !cityDropdown.contains(e.target)) {
                cityDropdown.classList.add('hidden');
            }
        });
    }

    // Setup search filters from URL parameters
    function setupSearchFilters() {
        // Handle URL parameters for pre-filling search fields
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
        const searchLocation = document.getElementById('searchLocation');
        const searchMaxPrice = document.getElementById('searchMaxPrice');
        const searchRoomType = document.getElementById('searchRoomType');
        const searchBedrooms = document.getElementById('searchBedrooms');

        if (allParams.get('location') && searchLocation) {
            searchLocation.value = allParams.get('location');
        }
        if (allParams.get('maxPrice') && searchMaxPrice) {
            searchMaxPrice.value = allParams.get('maxPrice');
        }
        if (allParams.get('roomType') && searchRoomType) {
            searchRoomType.value = allParams.get('roomType');
        }
        if (allParams.get('bedrooms') && searchBedrooms) {
            searchBedrooms.value = allParams.get('bedrooms');
        }
        
        // Set up search event listeners
        const searchInputs = [searchLocation, searchMaxPrice, searchRoomType, searchBedrooms];
        
        searchInputs.forEach(input => {
            if (input) {
                input.addEventListener('input', filterListings);
                input.addEventListener('change', filterListings);
            }
        });
        
        // Initial filter if parameters were provided
        if (allParams.size > 0) {
            setTimeout(filterListings, 500); // Allow time for listings to load
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

    // Filter listings based on search criteria
    function filterListings() {
        const searchLocation = document.getElementById('searchLocation')?.value.toLowerCase().trim() || '';
        const searchMaxPrice = document.getElementById('searchMaxPrice')?.value || '';
        const searchRoomType = document.getElementById('searchRoomType')?.value || '';
        const searchBedrooms = document.getElementById('searchBedrooms')?.value || '';

        console.log('Filtering with criteria:', {
            location: searchLocation,
            maxPrice: searchMaxPrice,
            roomType: searchRoomType,
            bedrooms: searchBedrooms
        });

        // Get all listing cards
        const listingCards = document.querySelectorAll('.listing-card-perspective-container');
        let visibleCount = 0;

        listingCards.forEach(card => {
            let shouldShow = true;

            // Location filter
            if (searchLocation) {
                const locationText = card.textContent.toLowerCase();
                if (!locationText.includes(searchLocation)) {
                    shouldShow = false;
                }
            }

            // Price filter
            if (searchMaxPrice && shouldShow) {
                const priceMatch = card.textContent.match(/\$(\d+(?:,\d{3})*)/);
                if (priceMatch) {
                    const price = parseInt(priceMatch[1].replace(/,/g, ''));
                    const maxPrice = parseInt(searchMaxPrice);
                    if (price > maxPrice) {
                        shouldShow = false;
                    }
                }
            }

            // Room type filter
            if (searchRoomType && shouldShow) {
                const cardText = card.textContent.toLowerCase();
                if (!cardText.includes(searchRoomType.toLowerCase())) {
                    shouldShow = false;
                }
            }

            // Bedrooms filter
            if (searchBedrooms && shouldShow) {
                const cardText = card.textContent.toLowerCase();
                const bedroomText = `${searchBedrooms} bed`;
                if (!cardText.includes(bedroomText)) {
                    shouldShow = false;
                }
            }

            // Show/hide card
            if (shouldShow) {
                card.style.display = '';
                visibleCount++;
            } else {
                card.style.display = 'none';
            }
        });

        // Update results count
        updateSearchResultsCount(visibleCount);

        // Filter listings array for map update
        if (window.ListingsManager && window.ListingsManager.allListings) {
            filteredListings = window.ListingsManager.allListings.filter(listing => {
                let matches = true;

                if (searchLocation) {
                    const location = `${listing.street || ''} ${listing.city || ''}`.toLowerCase();
                    if (!location.includes(searchLocation)) {
                        matches = false;
                    }
                }

                if (searchMaxPrice && matches) {
                    const maxPrice = parseInt(searchMaxPrice);
                    if (listing.price > maxPrice) {
                        matches = false;
                    }
                }

                if (searchRoomType && matches) {
                    if (listing.house_type !== searchRoomType) {
                        matches = false;
                    }
                }

                if (searchBedrooms && matches) {
                    const bedrooms = parseInt(searchBedrooms);
                    if (listing.bedrooms < bedrooms) {
                        matches = false;
                    }
                }

                return matches;
            });

            // Update map with filtered listings
            if (window.MapManager) {
                window.MapManager.updateWithListings(filteredListings);
            }
        }

        console.log(`Filter results: ${visibleCount} listings visible`);
    }

    // Update search results count display
    function updateSearchResultsCount(count) {
        let resultsElement = document.getElementById('searchResultsCount');
        
        if (!resultsElement) {
            // Create results count element if it doesn't exist
            resultsElement = document.createElement('div');
            resultsElement.id = 'searchResultsCount';
            resultsElement.className = 'text-sm text-gray-600 mb-4';
            
            const listingsContainer = document.getElementById('listingsContainer');
            if (listingsContainer && listingsContainer.parentNode) {
                listingsContainer.parentNode.insertBefore(resultsElement, listingsContainer);
            }
        }

        resultsElement.textContent = `Showing ${count} result${count !== 1 ? 's' : ''}`;
    }

    // Clear all search filters
    function clearSearchFilters() {
        const searchLocation = document.getElementById('searchLocation');
        const searchMaxPrice = document.getElementById('searchMaxPrice');
        const searchRoomType = document.getElementById('searchRoomType');
        const searchBedrooms = document.getElementById('searchBedrooms');

        if (searchLocation) searchLocation.value = '';
        if (searchMaxPrice) searchMaxPrice.value = '';
        if (searchRoomType) searchRoomType.value = '';
        if (searchBedrooms) searchBedrooms.value = '';

        filteredListings = [];
        
        // Show all listings
        if (window.ListingsManager) {
            window.ListingsManager.displayListings();
        }

        console.log('Search filters cleared');
    }

    // Apply search filters programmatically
    function applySearchFilters(filters = {}) {
        const { location, maxPrice, roomType, bedrooms } = filters;

        const searchLocation = document.getElementById('searchLocation');
        const searchMaxPrice = document.getElementById('searchMaxPrice');
        const searchRoomType = document.getElementById('searchRoomType');
        const searchBedrooms = document.getElementById('searchBedrooms');

        if (location && searchLocation) searchLocation.value = location;
        if (maxPrice && searchMaxPrice) searchMaxPrice.value = maxPrice;
        if (roomType && searchRoomType) searchRoomType.value = roomType;
        if (bedrooms && searchBedrooms) searchBedrooms.value = bedrooms;

        filterListings();
    }

    // Get current search criteria
    function getCurrentSearchCriteria() {
        return {
            location: document.getElementById('searchLocation')?.value || '',
            maxPrice: document.getElementById('searchMaxPrice')?.value || '',
            roomType: document.getElementById('searchRoomType')?.value || '',
            bedrooms: document.getElementById('searchBedrooms')?.value || ''
        };
    }

    // Initialize search functionality
    function initialize() {
        // Load cities data first
        loadCitiesData().then(() => {
            setupCityAutocomplete();
        });

        // Setup search filters
        setupSearchFilters();

        // Setup clear filters button if it exists
        const clearFiltersBtn = document.getElementById('clearFiltersBtn');
        if (clearFiltersBtn) {
            clearFiltersBtn.addEventListener('click', clearSearchFilters);
        }
    }

    // Public API
    return {
        initialize,
        loadCitiesData,
        showCitySuggestions,
        setupCityAutocomplete,
        setupSearchFilters,
        filterListings,
        clearSearchFilters,
        applySearchFilters,
        getCurrentSearchCriteria,
        updateSearchResultsCount,
        get filteredListings() { return filteredListings; },
        get cities() { return cities; }
    };
})();