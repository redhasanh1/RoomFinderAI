// Mobile App Listings - Property card display and management

class MobileAppListings {
    constructor() {
        this.listings = [];
        this.currentPage = 1;
        this.itemsPerPage = 10;
        this.isLoading = false;
        this.hasMore = true;
        this.filters = {};
        this.location = 'Toronto, ON';
    }

    init() {
        console.log('🏠 Initializing Mobile App Listings...');
        this.setupInfiniteScroll();
        console.log('✅ Mobile App Listings initialized');
    }

    setupInfiniteScroll() {
        // Intersection Observer for infinite scroll
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting && this.hasMore && !this.isLoading) {
                    this.loadMoreListings();
                }
            });
        }, {
            threshold: 0.1,
            rootMargin: '100px'
        });

        // Observe the loading spinner
        const loadingSpinner = document.getElementById('loadingSpinner');
        if (loadingSpinner) {
            observer.observe(loadingSpinner);
        }
    }

    async loadListings() {
        console.log('📊 Loading property listings...');
        this.currentPage = 1;
        this.listings = [];
        this.hasMore = true;
        
        await this.loadMoreListings();
    }

    async loadMoreListings() {
        if (this.isLoading || !this.hasMore) return;

        this.isLoading = true;
        this.showLoadingState();

        try {
            // Simulate API call with mock data
            const newListings = await this.fetchMockListings();
            
            if (newListings.length === 0) {
                this.hasMore = false;
                this.hideLoadingState();
                return;
            }

            this.listings.push(...newListings);
            this.renderListings();
            this.currentPage++;
            
        } catch (error) {
            console.error('❌ Error loading listings:', error);
            this.showErrorState();
        } finally {
            this.isLoading = false;
            this.hideLoadingState();
        }
    }

    async fetchMockListings() {
        // Simulate network delay
        await new Promise(resolve => setTimeout(resolve, 800));

        // Generate mock property data
        const mockProperties = [
            {
                id: `prop_${Date.now()}_1`,
                title: "Modern 2BR Apartment Downtown",
                price: 2800,
                location: "Entertainment District, Toronto",
                bedrooms: 2,
                bathrooms: 2,
                sqft: 950,
                type: "apartment",
                image: "https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=400&h=300&fit=crop",
                features: ["Gym", "Rooftop", "Parking", "Pet-friendly"],
                distance: 0.8,
                isNew: true,
                rating: 4.8
            },
            {
                id: `prop_${Date.now()}_2`,
                title: "Cozy Studio Near University",
                price: 1600,
                location: "Annex, Toronto",
                bedrooms: 0,
                bathrooms: 1,
                sqft: 450,
                type: "studio",
                image: "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=400&h=300&fit=crop",
                features: ["Furnished", "Utilities included", "Laundry"],
                distance: 2.1,
                isNew: false,
                rating: 4.3
            },
            {
                id: `prop_${Date.now()}_3`,
                title: "Luxury 3BR Condo Waterfront",
                price: 4200,
                location: "Harbourfront, Toronto",
                bedrooms: 3,
                bathrooms: 2.5,
                sqft: 1400,
                type: "condo",
                image: "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400&h=300&fit=crop",
                features: ["Lake view", "Concierge", "Pool", "Balcony"],
                distance: 1.5,
                isNew: true,
                rating: 4.9
            },
            {
                id: `prop_${Date.now()}_4`,
                title: "Spacious Room in Shared House",
                price: 950,
                location: "Kensington Market, Toronto",
                bedrooms: 1,
                bathrooms: 1,
                sqft: 200,
                type: "room",
                image: "https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400&h=300&fit=crop",
                features: ["Shared kitchen", "Garden", "WiFi included"],
                distance: 3.2,
                isNew: false,
                rating: 4.1
            },
            {
                id: `prop_${Date.now()}_5`,
                title: "Family House with Backyard",
                price: 3500,
                location: "Leslieville, Toronto",
                bedrooms: 4,
                bathrooms: 3,
                sqft: 1800,
                type: "house",
                image: "https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=400&h=300&fit=crop",
                features: ["Backyard", "Garage", "Fireplace", "Updated"],
                distance: 5.8,
                isNew: false,
                rating: 4.6
            }
        ];

        // Filter based on current filters
        let filteredProperties = mockProperties;
        
        if (this.filters.type && this.filters.type !== 'all') {
            filteredProperties = filteredProperties.filter(prop => prop.type === this.filters.type);
        }
        
        if (this.filters.priceMin) {
            filteredProperties = filteredProperties.filter(prop => prop.price >= this.filters.priceMin);
        }
        
        if (this.filters.priceMax) {
            filteredProperties = filteredProperties.filter(prop => prop.price <= this.filters.priceMax);
        }
        
        if (this.filters.bedrooms && this.filters.bedrooms !== 'any') {
            const minBedrooms = parseInt(this.filters.bedrooms);
            filteredProperties = filteredProperties.filter(prop => prop.bedrooms >= minBedrooms);
        }

        // Simulate pagination
        if (this.currentPage > 2) {
            return []; // No more results
        }

        return filteredProperties;
    }

    renderListings() {
        const contentContainer = document.getElementById('contentContainer');
        if (!contentContainer) return;

        if (this.listings.length === 0) {
            this.showEmptyState();
            return;
        }

        const listingsHTML = this.listings.map(listing => this.createListingCard(listing)).join('');
        
        contentContainer.innerHTML = `
            <div class="listings-grid">
                ${listingsHTML}
            </div>
            <div class="loading-spinner" id="loadingSpinner" style="display: none;">
                <div class="spinner"></div>
                <p>Loading more properties...</p>
            </div>
        `;

        // Re-setup infinite scroll observer
        this.setupInfiniteScroll();
    }

    createListingCard(listing) {
        const formattedPrice = window.MobileAppConfig?.formatPrice(listing.price) || `$${listing.price}/month`;
        const formattedDistance = window.MobileAppConfig?.formatDistance(listing.distance) || `${listing.distance}km`;
        
        return `
            <div class="property-card" data-property-id="${listing.id}" onclick="openPropertyDetails('${listing.id}')">
                <div class="property-image-container">
                    <img src="${listing.image}" alt="${listing.title}" class="property-image" loading="lazy">
                    ${listing.isNew ? '<div class="property-badge new">New</div>' : ''}
                    <div class="property-badge distance">${formattedDistance}</div>
                    <button class="favorite-btn" onclick="toggleFavorite(event, '${listing.id}')">
                        <span class="favorite-icon">🤍</span>
                    </button>
                </div>
                
                <div class="property-content">
                    <div class="property-header">
                        <h3 class="property-title">${listing.title}</h3>
                        <div class="property-rating">
                            <span class="rating-star">⭐</span>
                            <span class="rating-value">${listing.rating}</span>
                        </div>
                    </div>
                    
                    <div class="property-location">
                        <span class="location-icon">📍</span>
                        <span class="location-text">${listing.location}</span>
                    </div>
                    
                    <div class="property-details">
                        <div class="detail-item">
                            <span class="detail-icon">🛏️</span>
                            <span class="detail-text">${listing.bedrooms === 0 ? 'Studio' : listing.bedrooms + ' bed'}</span>
                        </div>
                        <div class="detail-item">
                            <span class="detail-icon">🚿</span>
                            <span class="detail-text">${listing.bathrooms} bath</span>
                        </div>
                        <div class="detail-item">
                            <span class="detail-icon">📐</span>
                            <span class="detail-text">${listing.sqft} sqft</span>
                        </div>
                    </div>
                    
                    <div class="property-features">
                        ${listing.features.slice(0, 3).map(feature => `
                            <span class="feature-tag">${feature}</span>
                        `).join('')}
                        ${listing.features.length > 3 ? `<span class="feature-more">+${listing.features.length - 3}</span>` : ''}
                    </div>
                    
                    <div class="property-footer">
                        <div class="property-price">
                            <span class="price-amount">${formattedPrice}</span>
                            <span class="price-period">/month</span>
                        </div>
                        <button class="contact-btn" onclick="contactOwner(event, '${listing.id}')">
                            Contact
                        </button>
                    </div>
                </div>
            </div>
        `;
    }

    showLoadingState() {
        const loadingSpinner = document.getElementById('loadingSpinner');
        if (loadingSpinner) {
            loadingSpinner.style.display = 'flex';
        }
    }

    hideLoadingState() {
        const loadingSpinner = document.getElementById('loadingSpinner');
        if (loadingSpinner) {
            loadingSpinner.style.display = 'none';
        }
    }

    showEmptyState() {
        const contentContainer = document.getElementById('contentContainer');
        if (contentContainer) {
            contentContainer.innerHTML = `
                <div class="empty-state">
                    <div class="empty-icon">🔍</div>
                    <h3>No properties found</h3>
                    <p>Try adjusting your filters or search in a different area.</p>
                    <button class="btn-primary" onclick="clearAllFilters()">Clear Filters</button>
                </div>
            `;
        }
    }

    showErrorState() {
        const contentContainer = document.getElementById('contentContainer');
        if (contentContainer) {
            contentContainer.innerHTML = `
                <div class="error-state">
                    <div class="error-icon">❌</div>
                    <h3>Something went wrong</h3>
                    <p>We couldn't load the properties. Please try again.</p>
                    <button class="btn-primary" onclick="retryLoadListings()">Try Again</button>
                </div>
            `;
        }
    }

    // Event handlers
    onFiltersChanged(filters) {
        console.log('🔍 Filters changed:', filters);
        this.filters = filters;
        this.loadListings();
    }

    onLocationChanged(location) {
        console.log('📍 Location changed:', location);
        this.location = location;
        this.loadListings();
    }
}

// Global function bindings
window.openPropertyDetails = (propertyId) => {
    console.log('🏠 Opening property details:', propertyId);
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('Property details coming soon!', 'info');
        window.MobileAppConfig.trackEvent('property_view', { propertyId });
    }
};

window.toggleFavorite = (event, propertyId) => {
    event.stopPropagation();
    console.log('❤️ Toggling favorite:', propertyId);
    
    const favoriteIcon = event.target.closest('.favorite-btn').querySelector('.favorite-icon');
    const isFavorited = favoriteIcon.textContent === '❤️';
    
    favoriteIcon.textContent = isFavorited ? '🤍' : '❤️';
    
    if (window.MobileAppConfig) {
        const action = isFavorited ? 'removed_favorite' : 'added_favorite';
        window.MobileAppConfig.trackEvent(action, { propertyId });
        window.MobileAppConfig.showToast(
            isFavorited ? 'Removed from favorites' : 'Added to favorites',
            'success'
        );
    }
};

window.contactOwner = (event, propertyId) => {
    event.stopPropagation();
    console.log('📞 Contacting owner:', propertyId);
    
    if (window.MobileAppConfig) {
        window.MobileAppConfig.showToast('Contact feature coming soon!', 'info');
        window.MobileAppConfig.trackEvent('contact_owner', { propertyId });
    }
};

window.clearAllFilters = () => {
    if (window.MobileAppConfig) {
        window.MobileAppConfig.activeFilters = {
            type: 'all',
            priceMin: null,
            priceMax: null,
            bedrooms: 'any',
            propertyTypes: []
        };
        
        // Reset quick filters UI
        document.querySelectorAll('.quick-filter').forEach(filter => {
            filter.classList.remove('active');
        });
        document.querySelector('.quick-filter[data-filter="all"]')?.classList.add('active');
        
        window.MobileAppConfig.onFiltersChanged();
    }
};

window.retryLoadListings = () => {
    if (window.MobileAppListings) {
        window.MobileAppListings.loadListings();
    }
};

// Create global instance
window.MobileAppListings = new MobileAppListings();

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.MobileAppListings.init();
    });
} else {
    window.MobileAppListings.init();
}