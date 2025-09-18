/**
 * Modal Manager Module
 * Handles all modal functionality including listing modals and chat modals
 */

class ModalManager {
    constructor() {
        this.isInitialized = false;
        this.currentModal = null;
        this.listingModal = null;
        this.chatModal = null;
    }

    /**
     * Initialize modal manager
     */
    init() {
        this.setupListingModal();
        this.setupChatModal();
        this.setupEventListeners();

        this.isInitialized = true;
        console.log('✅ Modal Manager initialized');
    }

    /**
     * Setup listing modal functionality
     */
    setupListingModal() {
        this.listingModal = document.getElementById('listingModal');
        const closeButton = document.querySelector('.close-button');

        if (!this.listingModal) {
            console.warn('Listing modal not found');
            return;
        }

        if (closeButton) {
            closeButton.addEventListener('click', () => {
                this.closeListingModal();
            });
        }

        // Click outside to close
        window.addEventListener('click', (event) => {
            if (event.target === this.listingModal) {
                this.closeListingModal();
            }
        });
    }

    /**
     * Setup chat modal functionality
     */
    setupChatModal() {
        this.chatModal = document.getElementById('chatModal');
        const chatCloseButton = document.querySelector('.chat-close-button');

        if (!this.chatModal) {
            console.warn('Chat modal not found');
            return;
        }

        if (chatCloseButton) {
            chatCloseButton.addEventListener('click', () => {
                this.closeChatModal();
            });
        }

        // Click outside to close
        window.addEventListener('click', (event) => {
            if (event.target === this.chatModal) {
                this.closeChatModal();
            }
        });
    }

    /**
     * Setup additional event listeners
     */
    setupEventListeners() {
        // Escape key to close modals
        document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape') {
                this.closeAllModals();
            }
        });
    }

    /**
     * Show listing modal with listing data
     */
    showListingModal(listing) {
        if (!this.listingModal) {
            console.error('Listing modal not available');
            return;
        }

        // Populate modal content
        document.getElementById('modalTitle').textContent = listing.title;
        document.getElementById('modalPrice').textContent = `$${listing.price.toLocaleString()}/mo`;
        document.getElementById('modalLocation').textContent = `${listing.street}, ${listing.city}, ${listing.postalCode}`;
        document.getElementById('modalDetails').innerHTML = `
            <span>${listing.bedrooms} Bed</span> • <span>${listing.house_type}</span> • <span>${listing.utilities}</span>
        `;
        document.getElementById('modalDescription').textContent = listing.description || 'No description provided';

        // Handle modal image
        const modalImage = document.getElementById('modalImage');
        modalImage.src = listing.media && listing.media.length > 0 && listing.media[0].type.startsWith('image/')
            ? listing.media[0].url
            : 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZjNmNGY2Ii8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxOCIgZmlsbD0iIzY2NzI4MCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPk5vIEltYWdlPC90ZXh0Pjwvc3ZnPg==';

        // Handle modal media
        const modalMedia = document.getElementById('modalMedia');
        modalMedia.innerHTML = listing.media && listing.media.length > 0
            ? listing.media.map(file =>
                file.type.startsWith('image/')
                    ? `<img src="${file.url}" alt="Media" class="w-24 h-24 object-cover rounded-lg cursor-pointer" onclick="openImageViewer('${file.url}')">`
                    : `<a href="${file.url}" target="_blank" class="p-2 bg-gray-100 rounded-lg text-sm text-blue-600 hover:bg-gray-200 transition">📄 ${file.name || 'Document'}</a>`
              ).join('')
            : '';

        // Set view details link
        document.getElementById('modalViewDetails').href = `/listing_details?id=${listing.id}`;

        // Show modal with animation
        this.listingModal.classList.add('active');
        this.currentModal = 'listing';
        console.log('Modal shown for listing:', listing.title);
    }

    /**
     * Close listing modal
     */
    closeListingModal() {
        if (this.listingModal) {
            this.listingModal.classList.remove('active');
            this.currentModal = null;
            console.log('Listing modal closed');
        }
    }

    /**
     * Show chat modal
     */
    showChatModal() {
        if (!this.chatModal) {
            console.error('Chat modal not available');
            return;
        }

        this.chatModal.classList.add('active');
        this.currentModal = 'chat';
        console.log('Chat modal opened');
    }

    /**
     * Close chat modal
     */
    closeChatModal() {
        if (this.chatModal) {
            this.chatModal.classList.remove('active');
            this.currentModal = null;
            console.log('Chat modal closed');
        }
    }

    /**
     * Close all modals
     */
    closeAllModals() {
        this.closeListingModal();
        this.closeChatModal();
    }

    /**
     * Check if any modal is open
     */
    isModalOpen() {
        return this.currentModal !== null;
    }

    /**
     * Get current open modal
     */
    getCurrentModal() {
        return this.currentModal;
    }

    /**
     * Create and show a simple modal with custom content
     */
    showCustomModal(title, content, buttons = []) {
        // Remove existing custom modal
        const existingModal = document.getElementById('custom-modal');
        if (existingModal) {
            existingModal.remove();
        }

        // Create modal HTML
        const modalHTML = `
            <div id="custom-modal" class="modal active">
                <div class="modal-content">
                    <div class="flex justify-between items-center mb-4">
                        <h2 class="text-xl font-bold">${title}</h2>
                        <button class="custom-modal-close text-gray-500 hover:text-gray-700 text-2xl">&times;</button>
                    </div>
                    <div class="mb-6">${content}</div>
                    <div class="flex space-x-2 justify-end">
                        ${buttons.map(btn => `
                            <button class="px-4 py-2 rounded ${btn.class || 'bg-gray-200 hover:bg-gray-300'}"
                                    onclick="${btn.onclick || ''}">${btn.text}</button>
                        `).join('')}
                    </div>
                </div>
            </div>
        `;

        // Add to page
        document.body.insertAdjacentHTML('beforeend', modalHTML);

        // Setup close functionality
        const customModal = document.getElementById('custom-modal');
        const closeBtn = customModal.querySelector('.custom-modal-close');

        closeBtn.addEventListener('click', () => {
            customModal.remove();
        });

        customModal.addEventListener('click', (e) => {
            if (e.target === customModal) {
                customModal.remove();
            }
        });

        return customModal;
    }

    /**
     * Open image viewer modal
     */
    openImageViewer(imageUrl) {
        const content = `<img src="${imageUrl}" alt="Full size image" class="max-w-full max-h-96 mx-auto rounded-lg">`;
        this.showCustomModal('Image Viewer', content, [
            { text: 'Close', class: 'bg-gray-200 hover:bg-gray-300', onclick: 'this.closest(".modal").remove()' }
        ]);
    }

    /**
     * Create confirmation modal
     */
    showConfirmModal(title, message, onConfirm, onCancel = null) {
        const content = `<p class="text-gray-600">${message}</p>`;
        const buttons = [
            {
                text: 'Cancel',
                class: 'bg-gray-200 hover:bg-gray-300',
                onclick: `(${onCancel?.toString() || function() {}})(); this.closest(".modal").remove();`
            },
            {
                text: 'Confirm',
                class: 'bg-red-600 hover:bg-red-700 text-white',
                onclick: `(${onConfirm.toString()})(); this.closest(".modal").remove();`
            }
        ];

        return this.showCustomModal(title, content, buttons);
    }

    /**
     * Destroy modal manager
     */
    destroy() {
        this.closeAllModals();
        this.isInitialized = false;
        console.log('🗑️ Modal Manager destroyed');
    }
}

// Create global instance
window.modalManager = new ModalManager();

// Global functions for backward compatibility
window.showListingModal = (listing) => {
    if (window.modalManager) {
        window.modalManager.showListingModal(listing);
    }
};

window.closeListingModal = () => {
    if (window.modalManager) {
        window.modalManager.closeListingModal();
    }
};

window.showChatModal = () => {
    if (window.modalManager) {
        window.modalManager.showChatModal();
    }
};

window.closeChatModal = () => {
    if (window.modalManager) {
        window.modalManager.closeChatModal();
    }
};

window.openImageViewer = (imageUrl) => {
    if (window.modalManager) {
        window.modalManager.openImageViewer(imageUrl);
    }
};

export default window.modalManager;