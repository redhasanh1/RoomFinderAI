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

        // Check for pending listing from photo wizard (auto-fill)
        this.checkForPendingListing();

        return true;
    }

    /**
     * Check for pending listing data from photo wizard and auto-fill form
     */
    checkForPendingListing() {
        // Check URL param
        const urlParams = new URLSearchParams(window.location.search);
        const autoFill = urlParams.get('autoFill');

        // Check localStorage
        const pendingData = localStorage.getItem('pendingListing');

        if (autoFill === 'true' && pendingData) {
            try {
                const listing = JSON.parse(pendingData);
                console.log('📋 Found pending listing, auto-filling form:', listing);

                // Check if data is recent (within 5 minutes)
                if (listing.timestamp && (Date.now() - listing.timestamp) < 5 * 60 * 1000) {
                    this.autoFillFromWizard(listing);

                    // Clear the pending data and URL param
                    localStorage.removeItem('pendingListing');
                    window.history.replaceState({}, document.title, window.location.pathname);
                } else {
                    console.log('⏰ Pending listing data expired, clearing');
                    localStorage.removeItem('pendingListing');
                }
            } catch (e) {
                console.error('Failed to parse pending listing:', e);
                localStorage.removeItem('pendingListing');
            }
        }
    }

    /**
     * Auto-fill form from wizard data
     */
    async autoFillFromWizard(listing) {
        // Show the form first
        this.showForm();

        // Small delay to ensure form is visible
        await new Promise(resolve => setTimeout(resolve, 100));

        // Fill in the fields
        const fieldMap = {
            'title': listing.title,
            'houseType': listing.house_type,
            'bedrooms': listing.bedrooms,
            'price': listing.price,
            'description': listing.description
        };

        // Location fields - instant fill
        if (listing.location) {
            if (listing.location.city) {
                const cityField = document.getElementById('city');
                if (cityField) cityField.value = listing.location.city;
            }
            if (listing.location.country) {
                const countryField = document.getElementById('country');
                if (countryField) countryField.value = listing.location.country;
            }
            if (listing.location.street) {
                const streetField = document.getElementById('street');
                if (streetField) streetField.value = listing.location.street;
            }
            if (listing.location.zip) {
                const postalField = document.getElementById('postalCode');
                if (postalField) postalField.value = listing.location.zip;
            }
        }

        // Fill basic fields instantly (no typewriter animation for speed)
        for (const [fieldId, value] of Object.entries(fieldMap)) {
            if (!value) continue;

            const element = document.getElementById(fieldId);
            if (!element) continue;

            // Instant fill - no typewriter effect
            element.value = String(value);
            if (element.tagName === 'SELECT') {
                element.dispatchEvent(new Event('change'));
            }

            // Quick flash effect
            element.style.transition = 'background-color 0.2s';
            element.style.backgroundColor = '#EEF2FF';
            setTimeout(() => { element.style.backgroundColor = ''; }, 300);
        }

        // Handle image if available (full image or thumbnail)
        if (listing.imageDataUrl && this.mediaInput) {
            try {
                // Full image available - convert dataUrl back to file
                const response = await fetch(listing.imageDataUrl);
                const blob = await response.blob();
                const file = new File([blob], 'listing-photo.jpg', { type: 'image/jpeg' });

                const dt = new DataTransfer();
                dt.items.add(file);
                this.mediaInput.files = dt.files;
                this.mediaInput.dispatchEvent(new Event('change'));
            } catch (e) {
                console.error('Failed to restore image:', e);
            }
        } else if (listing.imageThumbnail) {
            // Only thumbnail available - show preview and prompt to re-upload
            this.showImageReuploadPrompt(listing.imageThumbnail);
        }

        // Show success toast
        this.showAutoFillToast(listing);
    }

    /**
     * Typewriter fill effect for inputs
     */
    async typewriterFill(element, text) {
        element.value = '';
        for (let i = 0; i < text.length; i++) {
            element.value += text[i];
            await new Promise(resolve => setTimeout(resolve, 20));
        }
    }

    /**
     * Show toast notification for auto-fill
     */
    showAutoFillToast(listing) {
        const toast = document.createElement('div');
        toast.className = 'fixed bottom-4 right-4 bg-gradient-to-r from-green-500 to-emerald-600 text-white px-6 py-4 rounded-xl shadow-2xl z-50';
        toast.innerHTML = `
            <div class="flex items-center gap-3">
                <div class="text-2xl">✨</div>
                <div>
                    <p class="font-bold">GOD MODE Auto-Fill Complete!</p>
                    <p class="text-sm opacity-90">Grade: ${listing.unitGrade || 'B'} | ${listing.targetDemo || 'General Renters'}</p>
                </div>
            </div>
        `;
        document.body.appendChild(toast);

        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transition = 'opacity 0.5s';
            setTimeout(() => toast.remove(), 500);
        }, 4000);
    }

    /**
     * Show prompt to re-upload photo when only thumbnail is available
     */
    showImageReuploadPrompt(thumbnailDataUrl) {
        // Show thumbnail preview with message
        if (this.mediaPreview) {
            this.mediaPreview.innerHTML = `
                <div class="relative">
                    <img src="${thumbnailDataUrl}" class="w-24 h-24 object-cover rounded-lg opacity-60" alt="Preview">
                    <div class="absolute inset-0 flex items-center justify-center">
                        <div class="bg-black/70 text-white text-xs px-2 py-1 rounded text-center">
                            Re-upload<br>photo
                        </div>
                    </div>
                </div>
            `;
            this.mediaPreview.classList.remove('hidden');
        }

        // Show info toast
        const toast = document.createElement('div');
        toast.className = 'fixed bottom-4 left-4 bg-yellow-500 text-white px-4 py-3 rounded-lg shadow-lg z-50';
        toast.innerHTML = `
            <div class="flex items-center gap-2">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
                <span class="text-sm">Please re-upload your photo</span>
            </div>
        `;
        document.body.appendChild(toast);

        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transition = 'opacity 0.5s';
            setTimeout(() => toast.remove(), 500);
        }, 5000);
    }

    /**
     * Setup form submission handling
     */
    setupFormSubmission() {
        console.log('✅ Setting up form submission handler');
        this.form.addEventListener('submit', async (e) => {
            console.log('📝 Form submit event triggered');
            e.preventDefault();
            console.log('✅ Default form submission prevented');
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
        console.log('📝 [SUBMIT] Starting form submission handler');

        // Check authentication - try multiple methods
        let currentUser = null;

        // Method 1: Try window.authManager (if available)
        if (window.authManager && typeof window.authManager.getCurrentUser === 'function') {
            currentUser = window.authManager.getCurrentUser();
            console.log('🔐 [SUBMIT] Auth method: window.authManager');
        }

        // Method 2: Fallback to localStorage (most reliable)
        if (!currentUser) {
            try {
                currentUser = JSON.parse(localStorage.getItem('currentUser'));
                console.log('🔐 [SUBMIT] Auth method: localStorage');
            } catch (e) {
                console.error('❌ [SUBMIT] Failed to parse currentUser from localStorage:', e);
            }
        }

        // Method 3: Try UniversalAuth (if available)
        if (!currentUser && window.UniversalAuth && typeof window.UniversalAuth.getCurrentUser === 'function') {
            currentUser = await window.UniversalAuth.getCurrentUser();
            console.log('🔐 [SUBMIT] Auth method: UniversalAuth');
        }

        if (!currentUser) {
            console.error('❌ [SUBMIT] No authenticated user found after trying all methods');
            alert('Please log in to add a listing.');
            window.location.href = '/login';
            return;
        }
        console.log('✅ [SUBMIT] User authenticated:', currentUser.email);

        // Disable submit button and show loading state
        const submitBtn = this.form.querySelector('button[type="submit"]');
        const originalBtnText = submitBtn ? submitBtn.innerHTML : '';
        if (submitBtn) {
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<span class="inline-block animate-spin mr-2">⏳</span> Adding listing...';
        }

        try {
            // Upload media files
            console.log('📤 [SUBMIT] Uploading media files...');
            const media = this.uploadedFiles.length > 0 ? await this.uploadMedia(this.uploadedFiles) : [];
            console.log('✅ [SUBMIT] Media uploaded:', media.length, 'files');

            // Collect and validate form data
            console.log('📋 [SUBMIT] Collecting form data...');
            const listingData = this.collectFormData(currentUser, media);

            console.log('🔍 [SUBMIT] Validating form data...');
            if (!this.validateFormData(listingData)) {
                console.error('❌ [SUBMIT] Form validation failed');
                return;
            }
            console.log('✅ [SUBMIT] Form data validated');

            console.log('💾 [SUBMIT] Submitting to database:', listingData);

            // Submit to database
            const result = await this.submitListing(listingData);
            console.log('✅ [SUBMIT] Database insert successful:', result);

            if (result.success) {
                console.log('🎉 [SUBMIT] Calling handleSuccessfulSubmission...');
                await this.handleSuccessfulSubmission(result.data, currentUser, media);
                console.log('✅ [SUBMIT] Complete! Listing added and displayed');
            }

        } catch (err) {
            console.error('❌ [SUBMIT] Submission failed:', err);
            console.error('❌ [SUBMIT] Error stack:', err.stack);
            alert('Failed to add listing: ' + (err.message || err));
        } finally {
            // Re-enable submit button
            if (submitBtn) {
                submitBtn.disabled = false;
                submitBtn.innerHTML = originalBtnText;
            }
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
        // Get Supabase client - try multiple sources
        let supabaseClient = null;

        // Method 1: Try window.supabaseClient (set by listings.html)
        if (window.supabaseClient && typeof window.supabaseClient.from === 'function') {
            supabaseClient = window.supabaseClient;
            console.log('💾 [SUBMIT] Supabase method: window.supabaseClient');
        }

        // Method 2: Try window.configManager
        if (!supabaseClient && window.configManager && typeof window.configManager.getSupabase === 'function') {
            supabaseClient = window.configManager.getSupabase();
            console.log('💾 [SUBMIT] Supabase method: window.configManager');
        }

        if (!supabaseClient) {
            console.error('❌ [SUBMIT] Supabase client not available');
            throw new Error('Database not ready - please refresh the page');
        }

        console.log('✅ [SUBMIT] Supabase client found, inserting listing...');

        const { data, error } = await supabaseClient
            .from('listings')
            .insert([listing])
            .select();

        if (error) {
            console.error('❌ [SUBMIT] Database insert error:', error);
            throw new Error('Failed to add listing: ' + error.message);
        }

        console.log('✅ [SUBMIT] Database insert successful:', data);
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

        console.log('✅ Updated localStorage with new listing:', newListing);

        // Show success message immediately (don't block on refresh)
        alert('Listing added successfully!');

        // Reset form
        this.resetForm();

        // Hide form
        this.hideForm();

        // Refresh listings in background (non-blocking for faster UX)
        console.log('🔄 Refreshing listings in background...');
        if (window.listingsManager) {
            window.listingsManager.refresh().then(() => {
                console.log('✅ Listings refreshed successfully');
            }).catch(refreshError => {
                console.error('❌ Error refreshing listings:', refreshError);
                // Don't fail - listing is already in database
            });
        }
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

        // Build config object from available sources
        let config = null;

        // Method 1: Try window.configManager
        if (window.configManager && typeof window.configManager.getConfig === 'function') {
            config = window.configManager.getConfig();
            if (config && config.SUPABASE_URL) {
                console.log('📤 [UPLOAD] Config method: window.configManager');
            } else {
                config = null;
            }
        }

        // Method 2: Try global variables (from listings.html)
        if (!config && window.SUPABASE_URL && window.SUPABASE_ANON_KEY) {
            config = {
                SUPABASE_URL: window.SUPABASE_URL,
                SUPABASE_ANON_KEY: window.SUPABASE_ANON_KEY
            };
            console.log('📤 [UPLOAD] Config method: global variables');
        }

        if (!config || !config.SUPABASE_URL || !config.SUPABASE_ANON_KEY) {
            console.error('❌ [UPLOAD] Config not available:', {
                hasConfig: !!config,
                hasUrl: !!(config && config.SUPABASE_URL),
                hasKey: !!(config && config.SUPABASE_ANON_KEY),
                windowUrl: !!window.SUPABASE_URL,
                windowKey: !!window.SUPABASE_ANON_KEY
            });
            throw new Error('Configuration not available - please refresh the page');
        }

        const storageApiUrl = `${config.SUPABASE_URL}/storage/v1/object/listing-media/Photos`;
        console.log('📤 [UPLOAD] Using storage API URL:', storageApiUrl);

        // Process and upload all files in parallel for speed
        const uploadPromises = files.map(async (fileObj, index) => {
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

            // Use unique timestamp + index to avoid collisions in parallel uploads
            const fileName = `${Date.now()}-${index}-${file.name.replace(/[^a-zA-Z0-9.-]/g, '_')}`;
            const filePath = fileName;

            const uploadResult = await this.uploadFileToStorage(file, filePath, contentType.startsWith('image/') ? 'image/jpeg' : contentType, storageApiUrl, config);
            return uploadResult;
        });

        // Wait for all uploads to complete in parallel
        try {
            const results = await Promise.all(uploadPromises);
            console.log(`✅ All ${results.length} files uploaded in parallel`);
            return results;
        } catch (err) {
            console.error('❌ Parallel upload failed:', err);
            throw err;
        }
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
     * Simplified: upload succeeds or throws error, no verification loop needed
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

        console.log('✅ Uploaded media:', {
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
     * Show the form
     */
    showForm() {
        console.log('📝 [FORM] showForm() called');
        const section = document.getElementById('addListingSection');
        if (section) {
            console.log('✅ [FORM] Form section found, showing form');
            section.classList.remove('hidden');
            section.scrollIntoView({ behavior: 'smooth', block: 'start' });
            this.isFormVisible = true;
            this.updateToggleButtons(true);
            console.log('✅ [FORM] Form is now visible');
        } else {
            console.error('❌ [FORM] addListingSection element not found!');
        }
    }

    /**
     * Hide the form
     */
    hideForm() {
        console.log('📝 [FORM] hideForm() called');
        const section = document.getElementById('addListingSection');
        if (section) {
            console.log('✅ [FORM] Form section found, hiding form');
            section.classList.add('hidden');
            this.isFormVisible = false;
            this.updateToggleButtons(false);
            console.log('✅ [FORM] Form is now hidden');
        } else {
            console.error('❌ [FORM] addListingSection element not found!');
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
     * Populate form fields from AI analysis
     * @param {Object} analysisData - Data from photo analysis
     * @param {Object} options - Options for population (animate, file)
     */
    async populateFromAI(analysisData, options = {}) {
        console.log('🤖 Populating form from AI analysis:', analysisData);

        if (!analysisData) {
            console.warn('No analysis data provided');
            return;
        }

        const { animate = true, file = null } = options;

        // Show the form first
        this.showForm();

        // If a file was provided, add it to the upload
        if (file) {
            const mediaInput = this.mediaInput;
            if (mediaInput) {
                const dt = new DataTransfer();
                dt.items.add(file);
                mediaInput.files = dt.files;
                this.handleFileSelection();
            }
        }

        // Field mapping from AI analysis to form fields
        const fieldMapping = [
            { formId: 'title', dataKey: 'title' },
            { formId: 'houseType', dataKey: 'house_type', isSelect: true },
            { formId: 'bedrooms', dataKey: 'bedrooms' },
            { formId: 'price', dataKey: 'suggestedPrice' },
            { formId: 'description', dataKey: 'description' }
        ];

        if (animate) {
            // Animated population with typewriter effect
            for (const mapping of fieldMapping) {
                const element = document.getElementById(mapping.formId);
                const value = analysisData[mapping.dataKey];

                if (!element || value === undefined || value === null) continue;

                await this.delay(150); // Stagger delay

                if (mapping.isSelect) {
                    element.value = value;
                    element.dispatchEvent(new Event('change'));
                    this.flashField(element);
                } else if (mapping.formId === 'description') {
                    await this.typewriterEffect(element, String(value), 15);
                } else {
                    await this.typewriterEffect(element, String(value), 30);
                }
            }
        } else {
            // Immediate population without animation
            for (const mapping of fieldMapping) {
                const element = document.getElementById(mapping.formId);
                const value = analysisData[mapping.dataKey];

                if (!element || value === undefined || value === null) continue;

                element.value = value;
                element.dispatchEvent(new Event('change'));
            }
        }

        // Show confidence indicator
        this.showConfidenceIndicator(analysisData.confidence);

        console.log('✅ Form populated from AI analysis');
    }

    /**
     * Typewriter effect for input fields
     */
    async typewriterEffect(element, text, charDelay = 20) {
        element.value = '';
        element.classList.add('ai-typing');

        for (let i = 0; i < text.length; i++) {
            element.value += text[i];
            if (element.tagName === 'TEXTAREA') {
                element.scrollTop = element.scrollHeight;
            }
            await this.delay(charDelay);
        }

        element.classList.remove('ai-typing');
        this.flashField(element);
    }

    /**
     * Flash field to indicate AI completion
     */
    flashField(element) {
        element.style.transition = 'background-color 0.3s ease, box-shadow 0.3s ease';
        element.style.backgroundColor = '#EEF2FF';
        element.style.boxShadow = '0 0 0 2px rgba(139, 92, 246, 0.3)';

        setTimeout(() => {
            element.style.backgroundColor = '';
            element.style.boxShadow = '';
        }, 500);
    }

    /**
     * Show confidence indicator for AI analysis
     */
    showConfidenceIndicator(confidence) {
        if (confidence === undefined) return;

        const confidencePercent = Math.round(confidence * 100);
        let message, bgClass, icon;

        if (confidence >= 0.8) {
            message = `AI confidence: ${confidencePercent}% - Ready to review!`;
            bgClass = 'bg-green-500';
            icon = '✅';
        } else if (confidence >= 0.5) {
            message = `AI confidence: ${confidencePercent}% - Please verify details`;
            bgClass = 'bg-yellow-500';
            icon = '⚠️';
        } else {
            message = `AI confidence: ${confidencePercent}% - Manual review recommended`;
            bgClass = 'bg-red-500';
            icon = '❗';
        }

        // Create or update confidence badge
        let badge = document.getElementById('aiConfidenceBadge');
        if (!badge) {
            badge = document.createElement('div');
            badge.id = 'aiConfidenceBadge';
            badge.className = 'fixed bottom-4 right-4 px-4 py-3 rounded-lg shadow-lg z-50 text-white flex items-center gap-2 animate-slide-up';

            // Add animation styles if not present
            if (!document.getElementById('aiFormStyles')) {
                const style = document.createElement('style');
                style.id = 'aiFormStyles';
                style.textContent = `
                    @keyframes slideUp {
                        from { opacity: 0; transform: translateY(20px); }
                        to { opacity: 1; transform: translateY(0); }
                    }
                    .animate-slide-up { animation: slideUp 0.3s ease-out; }
                    .ai-typing { border-right: 2px solid #8B5CF6; }
                `;
                document.head.appendChild(style);
            }

            document.body.appendChild(badge);
        }

        badge.className = `fixed bottom-4 right-4 px-4 py-3 rounded-lg shadow-lg z-50 text-white flex items-center gap-2 animate-slide-up ${bgClass}`;
        badge.innerHTML = `<span>${icon}</span><span>${message}</span>`;

        // Auto-hide after 6 seconds
        setTimeout(() => {
            badge.style.opacity = '0';
            badge.style.transition = 'opacity 0.3s ease';
            setTimeout(() => badge.remove(), 300);
        }, 6000);
    }

    /**
     * Utility delay function
     */
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
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

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.addListingForm.init();
    });
} else {
    window.addListingForm.init();
}

// Global functions for backward compatibility
window.toggleAddListingForm = () => {
    // Always show Photo Wizard for AI-powered listing creation
    if (window.photoListingWizard) {
        window.photoListingWizard.show();
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