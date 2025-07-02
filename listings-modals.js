// Modal functionality for listings

// Show listing details in modal
function openListingModal(listingId) {
    console.log('🔍 Opening modal for listing:', listingId);
    
    const listing = allListings.find(l => l.id === listingId);
    if (!listing) {
        console.error('Listing not found:', listingId);
        return;
    }

    const modal = document.getElementById('listingModal');
    if (!modal) return;

    // Populate modal content
    document.getElementById('modalTitle').textContent = listing.title;
    document.getElementById('modalPrice').textContent = `$${listing.price.toLocaleString()}/mo`;
    document.getElementById('modalLocation').textContent = `${listing.street}, ${listing.city}, ${listing.postal_code}`;
    document.getElementById('modalDetails').innerHTML = `
        <span>${listing.bedrooms} Bed</span> • 
        <span>${listing.house_type}</span> • 
        <span>${listing.utilities}</span>
    `;
    document.getElementById('modalDescription').textContent = listing.description || 'No description provided';

    // Handle media
    let media = listing.media || [];
    if (!Array.isArray(media)) {
        try {
            media = JSON.parse(media);
        } catch (e) {
            media = [];
        }
    }

    // Set primary image
    const imageMedia = media.find(item => item.type && item.type.startsWith('image/'));
    const primaryImageUrl = imageMedia ? imageMedia.url : 'https://via.placeholder.com/400x300?text=No+Image';
    
    const modalImage = document.getElementById('modalImage');
    modalImage.src = primaryImageUrl;
    modalImage.onerror = () => {
        modalImage.src = 'https://via.placeholder.com/400x300?text=Image+Failed+to+Load';
    };

    // Set media gallery
    const modalMedia = document.getElementById('modalMedia');
    if (media.length > 0) {
        modalMedia.innerHTML = media.map(file => {
            if (!file.type || !file.url) return '';
            
            return file.type.startsWith('image/')
                ? `<img src="${file.url}" alt="${file.name || 'Media'}" onerror="this.src='https://via.placeholder.com/150x150?text=Image+Failed'">`
                : `<video src="${file.url}" controls></video>`;
        }).join('');
    } else {
        modalMedia.innerHTML = '<p class="text-gray-600">No additional media available.</p>';
    }

    // Set view details link
    document.getElementById('modalViewDetails').href = `/listing_details?id=${listing.id}`;

    // Show modal
    modal.classList.add('active');
}

// Setup modal event handlers
function setupModals() {
    console.log('🔧 Setting up modal functionality...');

    const listingModal = document.getElementById('listingModal');
    const chatModal = document.getElementById('chatModal');

    if (listingModal) {
        // Close button for listing modal
        const closeButton = listingModal.querySelector('.close-button');
        if (closeButton) {
            closeButton.addEventListener('click', () => {
                listingModal.classList.remove('active');
            });
        }

        // Close on outside click
        listingModal.addEventListener('click', (e) => {
            if (e.target === listingModal) {
                listingModal.classList.remove('active');
            }
        });
    }

    if (chatModal) {
        // Close buttons for chat modal
        const chatCloseButtons = chatModal.querySelectorAll('.close-button, .chat-close-button');
        chatCloseButtons.forEach(button => {
            button.addEventListener('click', () => {
                chatModal.classList.remove('active');
                currentConversationId = null;
            });
        });

        // Close on outside click
        chatModal.addEventListener('click', (e) => {
            if (e.target === chatModal) {
                chatModal.classList.remove('active');
                currentConversationId = null;
            }
        });
    }

    // Global escape key handler
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            // Close any open modals
            document.querySelectorAll('.modal.active, .chat-modal.active').forEach(modal => {
                modal.classList.remove('active');
            });
            currentConversationId = null;
        }
    });

    console.log('✅ Modal setup complete');
}

// Global function to make it available for onclick handlers
window.openListingModal = openListingModal;
window.startConversation = startConversation;