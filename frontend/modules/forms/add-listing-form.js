/**
 * Add Listing Form Module
 * Handles the add listing form, file uploads, and submission
 */

class AddListingForm {
    constructor() {
        this.isInitialized = false;
        this.uploadedFiles = [];
        this.isFormVisible = false;
        this.form = null;
        this.mediaInput = null;
        this.mediaPreview = null;
        this.maxFileSize = 10 * 1024 * 1024; // 10MB
    }

    /**
     * Initialize the add listing form
     */
    init() {
        this.form = document.getElementById('listingForm');
        this.mediaInput = document.getElementById('media');
        this.mediaPreview = document.getElementById('mediaPreview');

        if (!this.form) {
            console.warn('Listing form not found');
            return false;
        }

        this.setupFormSubmission();
        this.setupFileUpload();
        this.setupFormToggles();

        this.isInitialized = true;
        console.log('✅ Add Listing Form initialized');
        return true;
    }

    /**
     * Setup form submission handling
     */
    setupFormSubmission() {
        this.form.addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.handleFormSubmission(e);
        });
    }

    /**
     * Setup file upload functionality
     */
    setupFileUpload() {
        if (!this.mediaInput || !this.mediaPreview) {
            console.warn('Media input or preview elements not found');
            return;
        }

        this.mediaInput.addEventListener('change', () => {
            this.handleFileSelection();
        });
    }

    /**
     * Setup form toggle functionality
     */
    setupFormToggles() {
        // Setup show form buttons
        const showFormButtons = document.querySelectorAll('[onclick*="showAddListingForm"]');
        showFormButtons.forEach(button => {
            button.addEventListener('click', (e) => {
                e.preventDefault();
                this.showForm();
            });
        });

        // Setup hide form buttons
        const hideFormButtons = document.querySelectorAll('[onclick*="hideAddListingForm"]');
        hideFormButtons.forEach(button => {
            button.addEventListener('click', (e) => {
                e.preventDefault();
                this.hideForm();
            });
        });

        // Setup manual form button
        const manualFormButtons = document.querySelectorAll('[onclick*="showManualForm"]');
        manualFormButtons.forEach(button => {
            button.addEventListener('click', (e) => {
                e.preventDefault();
                this.showManualForm();
            });
        });
    }

    /**
     * Handle form submission
     */
    async handleFormSubmission(e) {
        console.log('📝 Handling form submission');

        // Check authentication
        const currentUser = window.authManager ? window.authManager.getCurrentUser() : null;
        if (!currentUser) {
            alert('Please log in to add a listing.');
            window.location.href = '/login';
            return;
        }

        try {
            // Upload media files
            const media = this.uploadedFiles.length > 0 ? await this.uploadMedia(this.uploadedFiles) : [];

            // Collect and validate form data
            const listingData = this.collectFormData(currentUser, media);

            if (!this.validateFormData(listingData)) {
                return;
            }

            console.log('📋 Submitting listing:', listingData);

            // Submit to database
            const result = await this.submitListing(listingData);

            if (result.success) {
                await this.handleSuccessfulSubmission(result.data, currentUser, media);
            }

        } catch (err) {
            console.error('Submission failed:', err);
            alert('Failed to add listing: ' + (err.message || err));
        }
    }

    /**
     * Collect form data
     */
    collectFormData(currentUser, media) {
        // Get text processing functions
        const autocorrectInput = window.autocorrectInput || ((input) => input);
        const sanitizeInput = window.sanitizeInput || ((input) => input.replace(/[^a-zA-Z0-9\s,.-]/g, '').trim());
        const cleanAddressInput = window.cleanAddressInput || ((input) => input.trim().replace(/\s+/g, ' ').replace(/[^\w\s\-.,#]/g, ''));

        // Log original input values for debugging
        const originalValues = {
            city: document.getElementById('city').value,
            country: document.getElementById('country').value,
            street: document.getElementById('street').value,
            postalCode: document.getElementById('postalCode').value
        };
        console.log('📝 Original address input:', originalValues);

        const listing = {
            title: autocorrectInput(sanitizeInput(document.getElementById('title').value)),
            price: parseInt(document.getElementById('price').value),
            city: cleanAddressInput(document.getElementById('city').value),
            country: sanitizeInput(document.getElementById('country').value),
            street: cleanAddressInput(document.getElementById('street').value),
            postalCode: document.getElementById('postalCode').value.trim().toUpperCase().replace(/\s+/g, ' '),
            house_type: document.getElementById('houseType').value,
            bedrooms: parseInt(document.getElementById('bedrooms').value),
            utilities: document.getElementById('utilities').value,
            description: autocorrectInput(sanitizeInput(document.getElementById('description').value)),
            media: media,
            user_email: currentUser.email,
            created_at: new Date().toISOString()
        };

        console.log('✅ Processed address values:', {
            city: listing.city,
            street: listing.street,
            postalCode: listing.postalCode
        });

        return listing;
    }

    /**
     * Validate form data
     */
    validateFormData(listing) {
        const requiredFields = ['title', 'price', 'city', 'street', 'postalCode', 'house_type', 'bedrooms'];

        for (const field of requiredFields) {
            if (!listing[field]) {
                alert(`Please fill in the ${field.replace('_', ' ')} field.`);
                return false;
            }
        }

        if (listing.price <= 0) {
            alert('Please enter a valid price.');
            return false;
        }

        if (listing.bedrooms <= 0) {
            alert('Please enter a valid number of bedrooms.');
            return false;
        }

        return true;
    }

    /**
     * Submit listing to database
     */
    async submitListing(listing) {
        const supabase = window.configManager ? window.configManager.getSupabase() : null;
        if (!supabase) {
            throw new Error('Database connection not available');
        }

        const { data, error } = await supabase
            .from('listings')
            .insert([listing])
            .select();

        if (error) {
            console.error('Error inserting listing:', error);
            throw new Error('Failed to add listing: ' + error.message);
        }

        return { success: true, data: data[0] };
    }

    /**
     * Handle successful submission
     */
    async handleSuccessfulSubmission(listingData, currentUser, media) {
        const newListing = {
            ...listingData,
            media: media
        };

        // Update user's listings in localStorage
        currentUser.listings = currentUser.listings || [];
        currentUser.listings.push(newListing);

        let users = JSON.parse(localStorage.getItem('users')) || [];
        users = users.map(u => u.email === currentUser.email ? currentUser : u);

        localStorage.setItem('users', JSON.stringify(users));
        localStorage.setItem('currentUser', JSON.stringify(currentUser));

        console.log('Updated localStorage with new listing:', newListing);

        // Reset form
        this.resetForm();

        // Show success message
        alert('Listing added successfully!');

        // Refresh listings display
        console.log('🔄 Refreshing listings and map after new listing added');
        if (window.listingsManager) {
            await window.listingsManager.refresh();
        }

        // Hide form
        this.hideForm();
    }

    /**
     * Handle file selection
     */
    handleFileSelection() {
        this.mediaPreview.innerHTML = '';
        this.uploadedFiles = [];

        const files = Array.from(this.mediaInput.files);
        let totalSize = 0;

        files.forEach(file => {
            totalSize += file.size;
            if (totalSize > this.maxFileSize) {
                alert('Total file size exceeds 10MB limit.');
                this.mediaInput.value = '';
                this.mediaPreview.innerHTML = '';
                this.uploadedFiles = [];
                return;
            }

            const reader = new FileReader();
            reader.onload = (e) => {
                const dataUrl = e.target.result;
                this.uploadedFiles.push({
                    name: file.name,
                    type: file.type,
                    data: dataUrl,
                    file: file
                });

                const previewElement = this.createPreviewElement(file, dataUrl);
                this.mediaPreview.appendChild(previewElement);
                console.log('Preview added for file:', file.name);
            };
            reader.readAsDataURL(file);
        });

        console.log('Files selected:', files.map(f => f.name));
    }

    /**
     * Create preview element for uploaded file
     */
    createPreviewElement(file, dataUrl) {
        const container = document.createElement('div');
        container.className = 'relative inline-block m-2';

        let previewContent;
        if (file.type.startsWith('image/')) {
            previewContent = `<img src="${dataUrl}" alt="${file.name}" class="w-32 h-32 object-cover rounded-lg">`;
        } else if (file.type.startsWith('video/')) {
            previewContent = `<video src="${dataUrl}" controls class="w-32 h-32 object-cover rounded-lg"></video>`;
        } else {
            previewContent = `
                <div class="w-32 h-32 bg-gray-200 rounded-lg flex items-center justify-center">
                    <span class="text-gray-600 text-sm text-center">${file.name}</span>
                </div>
            `;
        }

        container.innerHTML = `
            ${previewContent}
            <button type="button" class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center text-sm hover:bg-red-600"
                    onclick="addListingForm.removeFile('${file.name}')">×</button>
        `;

        return container;
    }

    /**
     * Remove file from selection
     */
    removeFile(fileName) {
        // Remove from uploadedFiles array
        this.uploadedFiles = this.uploadedFiles.filter(file => file.name !== fileName);

        // Update file input
        const dt = new DataTransfer();
        this.uploadedFiles.forEach(fileObj => {
            dt.items.add(fileObj.file);
        });
        this.mediaInput.files = dt.files;

        // Refresh preview
        this.refreshPreview();
    }

    /**
     * Refresh file preview
     */
    refreshPreview() {
        this.mediaPreview.innerHTML = '';
        this.uploadedFiles.forEach(fileObj => {
            const previewElement = this.createPreviewElement(fileObj.file, fileObj.data);
            this.mediaPreview.appendChild(previewElement);
        });
    }

    /**
     * Upload media files to storage
     */
    async uploadMedia(files) {
        const uploadedMedia = [];
        const config = window.configManager ? window.configManager.getConfig() : null;

        if (!config) {
            throw new Error('Configuration not available');
        }

        const storageApiUrl = `${config.SUPABASE_URL}/storage/v1/object/listing-media/Photos`;

        for (const fileObj of files) {
            let file = fileObj.file;
            const originalSize = file.size;

            // Determine content type
            const contentType = this.getContentType(file);
            console.log('Processing file:', {
                name: file.name,
                detectedType: file.type,
                assignedType: contentType
            });

            // Validate and compress image files
            if (contentType.startsWith('image/')) {
                await this.validateImageFile(file);

                // Compress image before upload to reduce egress costs
                const compressedBlob = await this.compressImage(file, 1200, 0.8);

                // Create a new File object from the compressed blob
                file = new File([compressedBlob], file.name, {
                    type: 'image/jpeg',
                    lastModified: Date.now()
                });

                console.log(`📦 Original: ${(originalSize / 1024).toFixed(1)}KB, Compressed: ${(file.size / 1024).toFixed(1)}KB`);
            }

            const fileName = `${Date.now()}-${file.name.replace(/[^a-zA-Z0-9.-]/g, '_')}`;
            const filePath = fileName;

            try {
                const uploadResult = await this.uploadFileToStorage(file, filePath, contentType.startsWith('image/') ? 'image/jpeg' : contentType, storageApiUrl, config);
                uploadedMedia.push(uploadResult);
            } catch (err) {
                console.error('Upload failed for', file.name, err);
                throw err;
            }
        }

        return uploadedMedia;
    }

    /**
     * Get content type for file
     */
    getContentType(file) {
        const extension = file.name.split('.').pop().toLowerCase();
        switch (extension) {
            case 'jpg':
            case 'jpeg':
                return 'image/jpeg';
            case 'png':
                return 'image/png';
            case 'mp4':
                return 'video/mp4';
            default:
                return 'application/octet-stream';
        }
    }

    /**
     * Validate image file
     */
    async validateImageFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = (e) => {
                const img = new Image();
                img.onload = () => resolve();
                img.onerror = () => reject(new Error('Invalid image file'));
                img.src = e.target.result;
            };
            reader.readAsDataURL(file);
        });
    }

    /**
     * Compress image before upload to reduce egress costs
     * @param {File} file - Original image file
     * @param {number} maxWidth - Maximum width (default 1200px)
     * @param {number} quality - JPEG quality 0-1 (default 0.8)
     * @returns {Promise<Blob>} Compressed image blob
     */
    async compressImage(file, maxWidth = 1200, quality = 0.8) {
        return new Promise((resolve, reject) => {
            // Skip compression for non-image files
            if (!file.type.startsWith('image/')) {
                resolve(file);
                return;
            }

            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');
            const img = new Image();

            img.onload = () => {
                let { width, height } = img;

                // Only resize if image is larger than maxWidth
                if (width > maxWidth) {
                    height = (height * maxWidth) / width;
                    width = maxWidth;
                }

                canvas.width = width;
                canvas.height = height;
                ctx.drawImage(img, 0, 0, width, height);

                // Convert to JPEG blob for better compression
                canvas.toBlob(
                    (blob) => {
                        if (blob) {
                            console.log(`📸 Image compressed: ${(file.size / 1024).toFixed(1)}KB -> ${(blob.size / 1024).toFixed(1)}KB (${((1 - blob.size / file.size) * 100).toFixed(0)}% reduction)`);
                            resolve(blob);
                        } else {
                            resolve(file); // Fallback to original
                        }
                    },
                    'image/jpeg',
                    quality
                );

                // Clean up object URL
                URL.revokeObjectURL(img.src);
            };

            img.onerror = () => {
                URL.revokeObjectURL(img.src);
                resolve(file); // Fallback to original on error
            };

            img.src = URL.createObjectURL(file);
        });
    }

    /**
     * Upload file to storage
     */
    async uploadFileToStorage(file, filePath, contentType, storageApiUrl, config) {
        const formData = new FormData();
        formData.append('file', file);
        formData.append('cacheControl', '3600');
        formData.append('upsert', 'false');

        const response = await fetch(`${storageApiUrl}/${filePath}`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${config.SUPABASE_ANON_KEY}`,
                'apikey': config.SUPABASE_ANON_KEY
            },
            body: formData
        });

        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`Upload failed: ${response.status} - ${errorText}`);
        }

        const publicUrl = `${config.SUPABASE_URL}/storage/v1/object/public/listing-media/Photos/${filePath}`;

        // Verify upload
        await this.verifyUpload(publicUrl, contentType, file, filePath, storageApiUrl, config);

        console.log('Uploaded media:', {
            name: file.name,
            type: contentType,
            url: publicUrl
        });

        return {
            name: file.name,
            type: contentType,
            url: publicUrl,
            data: null // Don't store data URL for uploaded files
        };
    }

    /**
     * Verify file upload and fix MIME type if needed
     */
    async verifyUpload(publicUrl, expectedContentType, file, filePath, storageApiUrl, config) {
        let verifyResponse = await fetch(publicUrl, { method: 'HEAD' });
        let serverContentType = verifyResponse.headers.get('Content-Type');

        console.log('Server-reported content type:', {
            name: file.name,
            serverContentType
        });

        if (serverContentType !== expectedContentType) {
            console.warn('MIME type mismatch detected. Server returned:', serverContentType, 'Expected:', expectedContentType);

            // Delete and re-upload with explicit content type
            await fetch(`${storageApiUrl}/${filePath}`, {
                method: 'DELETE',
                headers: {
                    'Authorization': `Bearer ${config.SUPABASE_ANON_KEY}`,
                    'apikey': config.SUPABASE_ANON_KEY
                }
            });

            const reUploadFormData = new FormData();
            reUploadFormData.append('file', file);
            reUploadFormData.append('cacheControl', '3600');
            reUploadFormData.append('upsert', 'false');
            reUploadFormData.append('contentType', expectedContentType);

            const reUploadResponse = await fetch(`${storageApiUrl}/${filePath}`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${config.SUPABASE_ANON_KEY}`,
                    'apikey': config.SUPABASE_ANON_KEY
                },
                body: reUploadFormData
            });

            if (!reUploadResponse.ok) {
                const errorText = await reUploadResponse.text();
                throw new Error(`Re-upload failed: ${reUploadResponse.status} - ${errorText}`);
            }

            // Verify again
            verifyResponse = await fetch(publicUrl, { method: 'HEAD' });
            serverContentType = verifyResponse.headers.get('Content-Type');

            console.log('After re-upload, server-reported content type:', {
                name: file.name,
                serverContentType
            });

            if (serverContentType !== expectedContentType) {
                throw new Error(`Failed to set correct MIME type for ${file.name}. Server returned ${serverContentType}, expected ${expectedContentType}.`);
            }
        }
    }

    /**
     * Show the form
     */
    showForm() {
        const section = document.getElementById('addListingSection');
        if (section) {
            section.classList.remove('hidden');
            section.scrollIntoView({ behavior: 'smooth', block: 'start' });
            this.isFormVisible = true;
            this.updateToggleButtons(true);
        }
    }

    /**
     * Hide the form
     */
    hideForm() {
        const section = document.getElementById('addListingSection');
        if (section) {
            section.classList.add('hidden');
            this.isFormVisible = false;
            this.updateToggleButtons(false);
        }
    }

    /**
     * Toggle form visibility
     */
    toggleForm() {
        if (this.isFormVisible) {
            this.hideForm();
        } else {
            this.showForm();
        }
    }

    /**
     * Show manual form section
     */
    showManualForm() {
        const manualSection = document.getElementById('manualFormSection');
        if (manualSection) {
            manualSection.classList.remove('hidden');
        }
    }

    /**
     * Update toggle button text and icons
     */
    updateToggleButtons(isVisible) {
        const buttons = document.querySelectorAll('#addListingToggle, #addListingToggleMain');
        buttons.forEach(btn => {
            if (isVisible) {
                btn.innerHTML = `
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                    Close Form
                `;
            } else {
                btn.innerHTML = `
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                    </svg>
                    List Your Property
                `;
            }
        });
    }

    /**
     * Reset form
     */
    resetForm() {
        if (this.form) {
            this.form.reset();
        }

        if (this.mediaPreview) {
            this.mediaPreview.innerHTML = '';
        }

        this.uploadedFiles = [];

        if (this.mediaInput) {
            this.mediaInput.value = '';
        }
    }

    /**
     * Get uploaded files
     */
    getUploadedFiles() {
        return this.uploadedFiles;
    }

    /**
     * Check if form is visible
     */
    isVisible() {
        return this.isFormVisible;
    }

    /**
     * Destroy form
     */
    destroy() {
        this.resetForm();
        this.isInitialized = false;
        console.log('🗑️ Add Listing Form destroyed');
    }
}

// Create global instance
window.addListingForm = new AddListingForm();

// Global functions for backward compatibility
window.toggleAddListingForm = () => {
    if (window.addListingForm) {
        window.addListingForm.toggleForm();
    }
};

window.showAddListingForm = () => {
    if (window.addListingForm) {
        window.addListingForm.showForm();
    }
};

window.hideAddListingForm = () => {
    if (window.addListingForm) {
        window.addListingForm.hideForm();
    }
};

window.showManualForm = () => {
    if (window.addListingForm) {
        window.addListingForm.showManualForm();
    }
};

export default window.addListingForm;