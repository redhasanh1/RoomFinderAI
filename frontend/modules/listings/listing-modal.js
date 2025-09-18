/**
 * Listing Modal Module
 * Handles the display and interaction of listing detail modals
 */

class ListingModal {
    constructor() {
        this.modal = null;
        this.isInitialized = false;
        this.currentListing = null;
    }

    /**
     * Initialize the listing modal
     */
    init() {
        this.modal = document.getElementById('listingModal');
        if (!this.modal) {
            console.error('Listing modal element not found');
            return false;
        }

        this.setupEventListeners();
        this.isInitialized = true;
        console.log('✅ Listing Modal initialized');
        return true;
    }

    /**
     * Setup event listeners for modal interactions
     */
    setupEventListeners() {
        // Close button
        const closeButton = this.modal.querySelector('.close-button');
        if (closeButton) {
            closeButton.addEventListener('click', () => {
                this.hide();
            });
        }

        // Click outside modal to close
        window.addEventListener('click', (event) => {
            if (event.target === this.modal) {
                this.hide();
            }
        });

        // Escape key to close
        document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape' && this.isVisible()) {
                this.hide();
            }
        });
    }

    /**
     * Show the modal with listing details
     */
    show(listing) {
        if (!this.isInitialized || !this.modal) {
            console.error('Modal not initialized');
            return;
        }

        this.currentListing = listing;
        this.populateModal(listing);
        this.modal.classList.add('active');
        document.body.style.overflow = 'hidden'; // Prevent background scrolling
        console.log('Modal shown for listing:', listing.title);
    }

    /**
     * Hide the modal
     */
    hide() {
        if (!this.modal) return;

        this.modal.classList.remove('active');
        document.body.style.overflow = ''; // Restore scrolling
        this.currentListing = null;
        console.log('Modal closed');
    }

    /**
     * Check if modal is currently visible
     */
    isVisible() {
        return this.modal && this.modal.classList.contains('active');
    }

    /**
     * Populate modal with listing data
     */
    populateModal(listing) {
        // Basic listing information
        this.setElementText('modalTitle', listing.title);
        this.setElementText('modalPrice', `$${listing.price.toLocaleString()}/mo`);
        this.setElementText('modalLocation', `${listing.street}, ${listing.city}, ${listing.postalCode}`);

        // Listing details
        const detailsElement = document.getElementById('modalDetails');
        if (detailsElement) {
            detailsElement.innerHTML = `
                <span>${listing.bedrooms} Bed</span> •
                <span>${listing.house_type}</span> •
                <span>${listing.utilities}</span>
            `;
        }

        // Description
        this.setElementText('modalDescription', listing.description || 'No description provided');

        // Main image
        const modalImage = document.getElementById('modalImage');
        if (modalImage) {
            const primaryImage = this.getPrimaryImage(listing.media);
            modalImage.src = primaryImage;
            modalImage.alt = listing.title;
            modalImage.onerror = () => {
                modalImage.src = this.getErrorImage();
            };
        }

        // Media gallery
        this.populateMediaGallery(listing.media);

        // View details link
        const viewDetailsLink = document.getElementById('modalViewDetails');
        if (viewDetailsLink) {
            viewDetailsLink.href = `/listing_details?id=${listing.id}`;
        }

        // Contact/Chat button
        this.setupContactButton(listing);

        // Additional features
        this.populateAdditionalFeatures(listing);
    }

    /**
     * Set text content of an element by ID
     */
    setElementText(elementId, text) {
        const element = document.getElementById(elementId);
        if (element) {
            element.textContent = text;
        }
    }

    /**
     * Get primary image for listing
     */
    getPrimaryImage(media) {
        if (!media || !Array.isArray(media) || media.length === 0) {
            return this.getPlaceholderImage();
        }

        const firstImage = media.find(file =>
            file.type && file.type.startsWith('image/')
        );

        return firstImage ? firstImage.url : this.getPlaceholderImage();
    }

    /**
     * Get placeholder image
     */
    getPlaceholderImage() {
        return 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZjNmNGY2Ii8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxOCIgZmlsbD0iIzY2NzI4MCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPk5vIEltYWdlPC90ZXh0Pjwvc3ZnPg==';
    }

    /**
     * Get error image
     */
    getErrorImage() {
        return 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZmY2Njc3Ii8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxOCIgZmlsbD0iI2ZmZmZmZiIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkltYWdlIE5vdCBBdmFpbGFibGU8L3RleHQ+PC9zdmc+';
    }

    /**
     * Populate media gallery
     */
    populateMediaGallery(media) {
        const modalMedia = document.getElementById('modalMedia');
        if (!modalMedia) return;

        if (!media || !Array.isArray(media) || media.length === 0) {
            modalMedia.innerHTML = '<p class="text-gray-500">No additional media available</p>';
            return;
        }

        const mediaHtml = media.map((file, index) => {
            if (file.type && file.type.startsWith('image/')) {
                return `
                    <div class="relative cursor-pointer" onclick="listingModal.openImageViewer(${index})">
                        <img src="${file.url}" alt="${file.name}" class="w-full h-24 object-cover rounded-lg hover:opacity-75 transition-opacity">
                        <div class="absolute inset-0 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity">
                            <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                            </svg>
                        </div>
                    </div>
                `;
            } else if (file.type && file.type.startsWith('video/')) {
                return `
                    <div class="relative">
                        <video src="${file.url}" class="w-full h-24 object-cover rounded-lg" controls preload="none">
                            Your browser does not support the video tag.
                        </video>
                    </div>
                `;
            } else {
                return `
                    <div class="p-4 border border-gray-200 rounded-lg">
                        <p class="text-sm text-gray-600">${file.name}</p>
                        <a href="${file.url}" target="_blank" class="text-blue-600 hover:text-blue-800 text-sm">Download</a>
                    </div>
                `;
            }
        }).join('');

        modalMedia.innerHTML = `
            <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
                ${mediaHtml}
            </div>
        `;
    }

    /**
     * Setup contact/chat button
     */
    setupContactButton(listing) {
        const contactButton = document.getElementById('modalContactButton');
        if (!contactButton) return;

        const hasOwner = !!listing.user_email;

        if (hasOwner) {
            contactButton.className = 'bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg transition font-semibold';
            contactButton.textContent = 'Contact Owner';
            contactButton.disabled = false;
            contactButton.onclick = () => {
                if (window.chatController) {
                    window.chatController.startConversation(listing);
                    this.hide(); // Close modal when starting chat
                } else {
                    console.error('Chat controller not available');
                }
            };
        } else {
            contactButton.className = 'bg-gray-400 cursor-not-allowed text-white px-6 py-2 rounded-lg';
            contactButton.textContent = 'Owner Contact Unavailable';
            contactButton.disabled = true;
            contactButton.onclick = null;
        }
    }

    /**
     * Populate additional features section
     */
    populateAdditionalFeatures(listing) {
        const featuresElement = document.getElementById('modalFeatures');
        if (!featuresElement) return;

        const features = [];

        // Add any additional features from the listing
        if (listing.parking) features.push('Parking Available');
        if (listing.pet_friendly) features.push('Pet Friendly');
        if (listing.furnished) features.push('Furnished');
        if (listing.utilities_included) features.push('Utilities Included');
        if (listing.laundry) features.push('Laundry');
        if (listing.gym) features.push('Gym Access');

        if (features.length > 0) {
            featuresElement.innerHTML = `
                <h4 class="font-semibold text-gray-800 mb-2">Features</h4>
                <div class="flex flex-wrap gap-2">
                    ${features.map(feature => `
                        <span class="px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-sm">${feature}</span>
                    `).join('')}
                </div>
            `;
        } else {
            featuresElement.innerHTML = '';
        }
    }

    /**
     * Open image viewer for media gallery
     */
    openImageViewer(index) {
        if (!this.currentListing || !this.currentListing.media) return;

        const images = this.currentListing.media.filter(file =>
            file.type && file.type.startsWith('image/')
        );

        if (index >= 0 && index < images.length) {
            // Create or show image viewer modal
            this.showImageViewer(images, index);
        }
    }

    /**
     * Show image viewer modal
     */
    showImageViewer(images, startIndex = 0) {
        // Create image viewer overlay
        const overlay = document.createElement('div');
        overlay.className = 'fixed inset-0 bg-black bg-opacity-90 z-50 flex items-center justify-center';
        overlay.onclick = (e) => {
            if (e.target === overlay) {
                document.body.removeChild(overlay);
            }
        };

        let currentIndex = startIndex;

        const updateImage = () => {
            const img = overlay.querySelector('.viewer-image');
            if (img && images[currentIndex]) {
                img.src = images[currentIndex].url;
                img.alt = images[currentIndex].name;
            }

            const counter = overlay.querySelector('.image-counter');
            if (counter) {
                counter.textContent = `${currentIndex + 1} / ${images.length}`;
            }
        };

        overlay.innerHTML = `
            <div class="relative max-w-4xl max-h-screen p-4">
                <button class="absolute top-4 right-4 text-white text-2xl z-10" onclick="document.body.removeChild(this.closest('.fixed'))">×</button>
                ${images.length > 1 ? `
                    <button class="absolute left-4 top-1/2 transform -translate-y-1/2 text-white text-2xl z-10" onclick="listingModal.prevImage(this)">‹</button>
                    <button class="absolute right-4 top-1/2 transform -translate-y-1/2 text-white text-2xl z-10" onclick="listingModal.nextImage(this)">›</button>
                ` : ''}
                <img class="viewer-image max-w-full max-h-full object-contain" src="${images[currentIndex].url}" alt="${images[currentIndex].name}">
                ${images.length > 1 ? `<div class="image-counter absolute bottom-4 left-1/2 transform -translate-x-1/2 text-white">${currentIndex + 1} / ${images.length}</div>` : ''}
            </div>
        `;

        // Store current state for navigation
        overlay.currentIndex = currentIndex;
        overlay.images = images;
        overlay.updateImage = updateImage;

        document.body.appendChild(overlay);
    }

    /**
     * Navigate to previous image in viewer
     */
    prevImage(button) {
        const overlay = button.closest('.fixed');
        if (overlay.currentIndex > 0) {
            overlay.currentIndex--;
            overlay.updateImage();
        }
    }

    /**
     * Navigate to next image in viewer
     */
    nextImage(button) {
        const overlay = button.closest('.fixed');
        if (overlay.currentIndex < overlay.images.length - 1) {
            overlay.currentIndex++;
            overlay.updateImage();
        }
    }

    /**
     * Get current listing
     */
    getCurrentListing() {
        return this.currentListing;
    }
}

// Create global instance
window.listingModal = new ListingModal();

export default window.listingModal;