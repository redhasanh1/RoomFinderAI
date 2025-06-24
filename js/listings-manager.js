// Listings Manager - Handles all listing-related functionality
class ListingsManager {
    constructor(mapManager) {
        this.mapManager = mapManager;
        this.supabase = null;
        this.currentListings = [];
    }

    // Initialize with Supabase client
    initialize(supabaseClient) {
        this.supabase = supabaseClient;
        console.log('✅ ListingsManager initialized with Supabase');
    }

    // Fetch listings from Supabase with user verification status
    async fetchListings() {
        console.log('🔄 Fetching listings from Supabase');
        
        // Check if supabase is available
        if (!this.supabase) {
            console.error('❌ Supabase not initialized, cannot fetch listings');
            return [];
        }
        
        try {
            // First get listings
            const { data: listings, error: listingsError } = await this.supabase
                .from('listings')
                .select('*')
                .order('created_at', { ascending: false })
                .range(0, 19);
            
            if (listingsError) throw listingsError;
            
            // Get unique user emails from listings
            const emailSet = new Set(listings.map(listing => listing.user_email));
            const userEmails = Array.from(emailSet);
            
            // Get user verification data
            const { data: users, error: usersError } = await this.supabase
                .from('users')
                .select('email, is_verified, verification_badge_earned_at')
                .in('email', userEmails);
            
            if (usersError) throw usersError;
            
            // Merge the data
            const listingsWithUsers = listings.map(listing => {
                return Object.assign({}, listing, {
                    users: users.find(user => user.email === listing.user_email) || null
                });
            });
            
            console.log('Fetch result:', { data: listingsWithUsers });
            this.currentListings = listingsWithUsers || [];
            return this.currentListings;
        } catch (error) {
            console.error('Error fetching listings:', error);
            alert('Failed to load listings: ' + error.message);
            return [];
        }
    }

    // Get demo listings for fallback
    getDemoListings() {
        return [
            {
                id: 'demo-1',
                title: 'Modern Downtown Apartment',
                price: 1850,
                city: 'Toronto',
                street: '123 Bay Street',
                postalCode: 'M5J 2R8',
                house_type: 'Apartment',
                bedrooms: 2,
                utilities: 'Not included',
                description: 'Beautiful modern apartment in the heart of downtown Toronto. Features floor-to-ceiling windows, hardwood floors, and access to building amenities including gym and rooftop terrace.',
                media: [{ url: 'https://via.placeholder.com/400x300/667eea/ffffff?text=Modern+Apartment', type: 'image/jpeg', name: 'apartment.jpg' }],
                created_at: new Date().toISOString(),
                user_email: 'demo@roomfinder.com',
                users: { is_verified: true, verification_badge_earned_at: new Date().toISOString() }
            },
            {
                id: 'demo-2',
                title: 'Cozy Midtown Condo',
                price: 1450,
                city: 'Toronto',
                street: '789 Yonge Street',
                postalCode: 'M4Y 1X9',
                house_type: 'Condo',
                bedrooms: 1,
                utilities: 'Included',
                description: 'Charming 1-bedroom condo in vibrant midtown area. Walking distance to subway, restaurants, and shopping. Perfect for young professionals.',
                media: [{ url: 'https://via.placeholder.com/400x300/4ECDC4/ffffff?text=Midtown+Condo', type: 'image/jpeg', name: 'condo.jpg' }],
                created_at: new Date().toISOString(),
                user_email: 'demo@roomfinder.com',
                users: { is_verified: false, verification_badge_earned_at: null }
            },
            {
                id: 'demo-3',
                title: 'Spacious Family House',
                price: 2200,
                city: 'Toronto',
                street: '456 College Street',
                postalCode: 'M6G 1A5',
                house_type: 'House',
                bedrooms: 3,
                utilities: 'Not included',
                description: 'Beautiful 3-bedroom house with private backyard. Great for families. Quiet residential neighborhood with easy access to schools and parks.',
                media: [{ url: 'https://via.placeholder.com/400x300/FFE66D/333333?text=Family+House', type: 'image/jpeg', name: 'house.jpg' }],
                created_at: new Date().toISOString(),
                user_email: 'demo@roomfinder.com',
                users: { is_verified: true, verification_badge_earned_at: new Date().toISOString() }
            },
            {
                id: 'demo-4',
                title: 'Student-Friendly Studio',
                price: 950,
                city: 'Toronto',
                street: '321 Spadina Avenue',
                postalCode: 'M5T 2C2',
                house_type: 'Studio',
                bedrooms: 0,
                utilities: 'Included',
                description: 'Affordable studio apartment near University of Toronto. Perfect for students. All utilities included, furnished option available.',
                media: [{ url: 'https://via.placeholder.com/400x300/FF6B6B/ffffff?text=Student+Studio', type: 'image/jpeg', name: 'studio.jpg' }],
                created_at: new Date().toISOString(),
                user_email: 'demo@roomfinder.com',
                users: { is_verified: false, verification_badge_earned_at: null }
            },
            {
                id: 'demo-5',
                title: 'Vancouver Condo',
                price: 1800,
                city: 'Vancouver',
                street: '123 Robson Street',
                postalCode: 'V6B 2A7',
                house_type: 'Condo',
                bedrooms: 1,
                utilities: 'Not included',
                description: 'Modern Vancouver condo with ocean views. Downtown location with excellent transit access.',
                media: [{ url: 'https://via.placeholder.com/400x300/764ba2/ffffff?text=Vancouver+Condo', type: 'image/jpeg', name: 'vancouver.jpg' }],
                created_at: new Date().toISOString(),
                user_email: 'demo@roomfinder.com',
                users: { is_verified: true, verification_badge_earned_at: new Date().toISOString() }
            },
            {
                id: 'demo-6',
                title: 'Montreal House',
                price: 1500,
                city: 'Montreal',
                street: '789 Saint-Catherine Street',
                postalCode: 'H3B 1Y5',
                house_type: 'House',
                bedrooms: 3,
                utilities: 'Included',
                description: 'Charming Montreal house in historic neighborhood. Close to metro and cultural attractions.',
                media: [{ url: 'https://via.placeholder.com/400x300/FF9F1C/ffffff?text=Montreal+House', type: 'image/jpeg', name: 'montreal.jpg' }],
                created_at: new Date().toISOString(),
                user_email: 'demo@roomfinder.com',
                users: { is_verified: false, verification_badge_earned_at: null }
            }
        ];
    }

    // Create listing card HTML
    createListingCard(listing) {
        let media = listing.media || [];
        if (!Array.isArray(media)) {
            console.warn('Media is not an array, resetting to empty array:', media);
            media = [];
        }

        media = media.map(item => {
            if (item.type === 'application/json' || !item.type || item.type === 'application/octet-stream') {
                const extension = item.name.split('.').pop().toLowerCase();
                let correctedType;
                switch (extension) {
                    case 'jpg':
                    case 'jpeg':
                        correctedType = 'image/jpeg';
                        break;
                    case 'png':
                        correctedType = 'image/png';
                        break;
                    case 'mp4':
                        correctedType = 'video/mp4';
                        break;
                    default:
                        correctedType = item.type || 'application/octet-stream';
                }
                console.log('Corrected MIME type for', item.name, 'from', item.type, 'to', correctedType);
                return { ...item, type: correctedType };
            }
            return item;
        });

        const isImage = (file) => {
            const byType = file.type.startsWith('image/');
            const byExtension = file.name.match(/\.(jpg|jpeg|png)$/i);
            return byType || byExtension;
        };

        const primaryImage = media.length > 0 && isImage(media[0])
            ? media[0].url
            : 'https://via.placeholder.com/300x200?text=No+Image';

        const hasOwner = !!listing.user_email;
        const isVerified = listing.users && listing.users.is_verified;
        const verificationBadge = isVerified ? 
            `<div class="absolute top-2 right-2 bg-blue-600 rounded-full p-1 border-2 border-white shadow-lg" title="Verified Owner">
                <svg class="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"/>
                </svg>
            </div>` : '';
        
        const verificationIndicator = isVerified ? 
            `<div class="flex items-center space-x-1 text-xs text-blue-600 mt-1">
                <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"/>
                </svg>
                <span class="font-medium">Verified Owner</span>
            </div>` : '';

        const listingCard = document.createElement('div');
        listingCard.className = 'listing-card bg-white rounded-lg shadow-md overflow-hidden';

        listingCard.innerHTML = `
            <div class="relative">
                <img src="${primaryImage}" alt="${listing.title}" class="listing-image" onerror="this.src='https://via.placeholder.com/300x200?text=Image+Not+Available';">
                ${verificationBadge}
            </div>
            <div class="p-4">
                <h3 class="text-lg font-semibold text-gray-800 truncate">${listing.title}</h3>
                <p class="text-xl font-bold text-blue-600">$${listing.price.toLocaleString()}/mo</p>
                <p class="text-gray-600 text-sm">${listing.street}, ${listing.city}, ${listing.postalCode}</p>
                ${verificationIndicator}
                <div class="flex items-center space-x-2 text-sm text-gray-600 mt-2">
                    <span>${listing.bedrooms} Bed</span>
                    <span>•</span>
                    <span>${listing.house_type}</span>
                    <span>•</span>
                    <span>${listing.utilities}</span>
                </div>
                <p class="text-gray-600 text-sm mt-2 line-clamp-2">${listing.description || 'No description provided'}</p>
                <div class="flex space-x-2 mt-4">
                    <button class="view-details-btn w-1/2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition font-semibold shadow-md hover:shadow-lg" data-listing='${JSON.stringify(listing)}'>View Details</button>
                    <button class="chat-btn w-1/2 bg-green-600 text-white px-4 py-2 rounded-lg transition ${hasOwner ? 'hover:bg-green-700' : ''} font-semibold shadow-md hover:shadow-lg" data-listing='${JSON.stringify(listing)}' ${hasOwner ? '' : 'disabled title="No owner specified for this listing"'}>Chat</button>
                </div>
            </div>
        `;

        return listingCard;
    }

    // Display listings
    async displayListings() {
        console.log('🔄 Starting displayListings function');
        try {
            let listings = await this.fetchListings();
            console.log('📋 Fetched listings:', listings);
        
            const container = document.getElementById('listingsContainer');
            const noListingsMessage = document.getElementById('noListingsMessage');
            container.innerHTML = '';
            
            // Hide no listings message initially
            if (noListingsMessage) {
                noListingsMessage.classList.add('hidden');
            }

            // Always show some demo listings for better user experience
            if (listings.length === 0) {
                console.warn('⚠️ No listings from database, showing demo listings');
                listings = this.getDemoListings();
                console.log('📝 Using', listings.length, 'demo listings for demonstration');
            }

            listings.forEach(listing => {
                console.log('Processing listing:', listing.id, listing.title);
                const listingCard = this.createListingCard(listing);
                container.appendChild(listingCard);
            });

            // Add event listeners for view details buttons
            document.querySelectorAll('.view-details-btn').forEach(button => {
                button.addEventListener('click', () => {
                    const listing = JSON.parse(button.dataset.listing);
                    this.showListingModal(listing);
                });
            });

            // Show/hide no listings message based on container content
            if (container.children.length === 0) {
                console.log('No listings to display, showing no listings message');
                if (noListingsMessage) {
                    noListingsMessage.classList.remove('hidden');
                }
            } else {
                console.log('Listings displayed successfully, hiding no listings message');
                if (noListingsMessage) {
                    noListingsMessage.classList.add('hidden');
                }
            }
            
            // Update map with all listings
            console.log('📍 Updating map with', listings.length, 'listings...');
            if (this.mapManager) {
                await this.mapManager.updateMap(listings);
            }
            console.log('✅ Listings display complete:', listings.length, 'listings processed');
        } catch (error) {
            console.error('❌ Error in displayListings:', error);
            this.showError(error);
        }
    }

    // Show error message
    showError(error) {
        const container = document.getElementById('listingsContainer');
        if (container) {
            container.innerHTML = `
                <div class="text-center p-8">
                    <div class="text-red-500 text-lg font-semibold mb-2">⚠️ Error Loading Listings</div>
                    <div class="text-gray-600 mb-4">Unable to load property listings. This might be due to:</div>
                    <ul class="text-sm text-gray-500 mb-4 list-disc list-inside">
                        <li>Network connection issues</li>
                        <li>Database connection problems</li>
                        <li>Browser compatibility issues</li>
                    </ul>
                    <button onclick="location.reload()" class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition">Refresh Page</button>
                </div>
            `;
        }
        
        // Show browser-specific help for Safari
        if (window.SAFARI_MODE) {
            console.error('🍎 Safari detected - this might be a compatibility issue');
            alert('Safari Compatibility Issue Detected\\n\\nPlease try:\\n1. Update to the latest Safari version\\n2. Enable JavaScript in Safari settings\\n3. Try using Chrome or Firefox as alternative');
        }
    }

    // Show listing modal
    showListingModal(listing) {
        const modal = document.getElementById('listingModal');
        document.getElementById('modalTitle').textContent = listing.title;
        document.getElementById('modalPrice').textContent = '$' + listing.price.toLocaleString() + '/mo';
        document.getElementById('modalLocation').textContent = listing.street + ', ' + listing.city + ', ' + listing.postalCode;
        document.getElementById('modalDetails').innerHTML = 
            '<span>' + listing.bedrooms + ' Bed</span> • <span>' + listing.house_type + '</span> • <span>' + listing.utilities + '</span>';
        document.getElementById('modalDescription').textContent = listing.description || 'No description provided';
        
        const modalImage = document.getElementById('modalImage');
        modalImage.src = listing.media && listing.media.length > 0 && listing.media[0].type.startsWith('image/')
            ? listing.media[0].url
            : 'https://via.placeholder.com/300x200?text=No+Image';
        
        const modalMedia = document.getElementById('modalMedia');
        modalMedia.innerHTML = listing.media && listing.media.length > 0
            ? listing.media.map(file => {
                return file.type.startsWith('image/')
                    ? '<img src="' + file.url + '" alt="' + file.name + '">'
                    : '<video src="' + file.url + '" controls></video>';
            }).join('')
            : '';

        document.getElementById('modalViewDetails').href = '/listing_details?id=' + listing.id;
        
        modal.style.display = 'block';
        console.log('Modal shown for listing:', listing.title);
    }

    // Refresh listings
    async refreshListings() {
        console.log('🔄 Refreshing listings...');
        await this.displayListings();
    }

    // Get current listings
    getCurrentListings() {
        return this.currentListings;
    }
}

// Export for global use
window.ListingsManager = ListingsManager;