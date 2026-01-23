/**
 * Photo Listing Wizard Module
 * "Magic Moment" - Upload a photo, AI fills the listing form
 * Uses Cloudflare Workers AI (LLaVA) - FREE tier
 */

class PhotoListingWizard {
    constructor() {
        this.modal = null;
        this.isAnalyzing = false;
        this.analysisResult = null;
        this.uploadedImage = null;
        this.maxImageSize = 4 * 1024 * 1024; // 4MB for AI analysis
        this.locationData = null; // GPS-extracted location
        this.exifData = null; // Full EXIF data
    }

    /**
     * Initialize the wizard
     */
    init() {
        this.createModal();
        this.setupEventListeners();
        console.log('Photo Listing Wizard initialized');
    }

    /**
     * Create the wizard modal HTML
     */
    createModal() {
        // Check if modal already exists
        if (document.getElementById('photoWizardModal')) {
            this.modal = document.getElementById('photoWizardModal');
            return;
        }

        const modalHTML = `
            <div id="photoWizardModal" class="fixed inset-0 z-50 hidden overflow-y-auto">
                <!-- Backdrop -->
                <div class="photo-wizard-backdrop fixed inset-0 bg-black/60 backdrop-blur-sm transition-opacity"></div>

                <!-- Modal Content -->
                <div class="flex items-center justify-center min-h-screen p-4">
                    <div class="photo-wizard-content relative bg-white rounded-2xl shadow-2xl w-full max-w-lg transform transition-all">
                        <!-- Close button -->
                        <button id="photoWizardClose" class="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition z-10">
                            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                            </svg>
                        </button>

                        <!-- Step 1: Upload -->
                        <div id="wizardStep1" class="p-8">
                            <div class="text-center mb-6">
                                <div class="inline-flex items-center justify-center w-16 h-16 bg-gradient-to-br from-purple-500 to-indigo-600 rounded-2xl mb-4">
                                    <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"/>
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"/>
                                    </svg>
                                </div>
                                <h2 class="text-2xl font-bold text-gray-800">Quick List with Photo</h2>
                                <p class="text-gray-500 mt-2">Upload a photo, we'll do the rest</p>
                            </div>

                            <!-- Drop Zone -->
                            <div id="photoDropZone" class="relative border-2 border-dashed border-gray-300 rounded-xl p-8 text-center hover:border-purple-500 hover:bg-purple-50/50 transition-all cursor-pointer group">
                                <input type="file" id="wizardPhotoInput" accept="image/*" class="absolute inset-0 w-full h-full opacity-0 cursor-pointer">

                                <div id="dropZoneContent">
                                    <div class="inline-flex items-center justify-center w-12 h-12 bg-gray-100 rounded-xl mb-4 group-hover:bg-purple-100 transition">
                                        <svg class="w-6 h-6 text-gray-400 group-hover:text-purple-500 transition" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                                        </svg>
                                    </div>
                                    <p class="text-gray-600 font-medium">Drop your photo here</p>
                                    <p class="text-gray-400 text-sm mt-1">or click to browse</p>
                                    <p class="text-gray-400 text-xs mt-3">JPEG, PNG up to 4MB</p>
                                </div>

                                <!-- Preview (hidden initially) -->
                                <div id="photoPreviewContainer" class="hidden">
                                    <img id="photoPreview" class="max-h-48 mx-auto rounded-lg shadow-md" alt="Property preview">
                                    <p id="photoFileName" class="text-sm text-gray-500 mt-2"></p>
                                </div>
                            </div>

                            <!-- Skip link -->
                            <div class="text-center mt-4">
                                <button id="skipToManualBtn" class="text-sm text-gray-500 hover:text-purple-600 transition">
                                    Skip and fill manually
                                </button>
                            </div>
                        </div>

                        <!-- Step 2: Analyzing -->
                        <div id="wizardStep2" class="hidden p-8">
                            <div class="text-center">
                                <!-- Photo thumbnail with shimmer -->
                                <div class="relative inline-block mb-6">
                                    <img id="analyzingThumbnail" class="w-32 h-32 object-cover rounded-xl" alt="Analyzing">
                                    <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/30 to-transparent shimmer-animation rounded-xl"></div>
                                </div>

                                <!-- Animated icons -->
                                <div class="flex justify-center items-center gap-4 mb-6">
                                    <div class="analysis-icon" data-step="1">
                                        <div class="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center">
                                            <span class="text-xl">🏠</span>
                                        </div>
                                        <p class="text-xs text-gray-400 mt-1">Type</p>
                                    </div>
                                    <div class="w-8 h-0.5 bg-gray-200 analysis-connector"></div>
                                    <div class="analysis-icon" data-step="2">
                                        <div class="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center">
                                            <span class="text-xl">🛏️</span>
                                        </div>
                                        <p class="text-xs text-gray-400 mt-1">Rooms</p>
                                    </div>
                                    <div class="w-8 h-0.5 bg-gray-200 analysis-connector"></div>
                                    <div class="analysis-icon" data-step="3">
                                        <div class="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center">
                                            <span class="text-xl">💰</span>
                                        </div>
                                        <p class="text-xs text-gray-400 mt-1">Price</p>
                                    </div>
                                    <div class="w-8 h-0.5 bg-gray-200 analysis-connector"></div>
                                    <div class="analysis-icon" data-step="4">
                                        <div class="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center">
                                            <span class="text-xl">✍️</span>
                                        </div>
                                        <p class="text-xs text-gray-400 mt-1">Details</p>
                                    </div>
                                </div>

                                <p class="text-gray-600 font-medium">Analyzing your property...</p>
                                <p class="text-gray-400 text-sm mt-1">This takes a few seconds</p>

                                <!-- Progress bar -->
                                <div class="mt-6 w-full bg-gray-200 rounded-full h-1.5">
                                    <div id="analysisProgress" class="bg-gradient-to-r from-purple-500 to-indigo-600 h-1.5 rounded-full transition-all duration-300" style="width: 0%"></div>
                                </div>
                            </div>
                        </div>

                        <!-- Step 3: Results/Error -->
                        <div id="wizardStep3" class="hidden p-8">
                            <!-- Success state -->
                            <div id="analysisSuccess" class="hidden">
                                <div class="text-center mb-6">
                                    <div class="inline-flex items-center justify-center w-12 h-12 bg-green-100 rounded-full mb-3">
                                        <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                                        </svg>
                                    </div>
                                    <h3 class="text-xl font-bold text-gray-800">Analysis Complete!</h3>
                                    <p class="text-gray-500 text-sm mt-1">Review the auto-filled details below</p>
                                </div>

                                <!-- Results preview -->
                                <div class="bg-gray-50 rounded-xl p-4 space-y-3 mb-6">
                                    <div class="flex items-center justify-between">
                                        <span class="text-gray-500 text-sm">Title</span>
                                        <span id="resultTitle" class="font-medium text-gray-800 text-right max-w-[200px] truncate"></span>
                                    </div>
                                    <div class="flex items-center justify-between">
                                        <span class="text-gray-500 text-sm">Type</span>
                                        <span id="resultType" class="font-medium text-gray-800"></span>
                                    </div>
                                    <div class="flex items-center justify-between">
                                        <span class="text-gray-500 text-sm">Bedrooms</span>
                                        <span id="resultBedrooms" class="font-medium text-gray-800"></span>
                                    </div>
                                    <div id="resultLocationRow" class="flex items-center justify-between hidden">
                                        <span class="text-gray-500 text-sm">Location</span>
                                        <span id="resultLocation" class="font-medium text-green-600 flex items-center gap-1">
                                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
                                            </svg>
                                            <span id="resultLocationText"></span>
                                        </span>
                                    </div>
                                    <div class="flex items-center justify-between">
                                        <span class="text-gray-500 text-sm">Suggested Price</span>
                                        <span id="resultPrice" class="font-medium text-gray-800"></span>
                                    </div>
                                    <div class="flex items-center justify-between">
                                        <span class="text-gray-500 text-sm">Confidence</span>
                                        <span id="resultConfidence" class="font-medium"></span>
                                    </div>
                                </div>

                                <button id="applyResultsBtn" class="w-full bg-gradient-to-r from-purple-600 to-indigo-600 text-white py-3 rounded-xl font-semibold hover:from-purple-700 hover:to-indigo-700 transition">
                                    Apply to Listing Form
                                </button>
                            </div>

                            <!-- Error state -->
                            <div id="analysisError" class="hidden text-center">
                                <div class="inline-flex items-center justify-center w-12 h-12 bg-red-100 rounded-full mb-3">
                                    <svg class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
                                    </svg>
                                </div>
                                <h3 class="text-xl font-bold text-gray-800">Analysis Failed</h3>
                                <p id="errorMessage" class="text-gray-500 text-sm mt-1 mb-6">Something went wrong. Please try again or fill manually.</p>

                                <div class="flex gap-3">
                                    <button id="retryAnalysisBtn" class="flex-1 bg-gray-100 text-gray-700 py-3 rounded-xl font-semibold hover:bg-gray-200 transition">
                                        Try Again
                                    </button>
                                    <button id="fillManuallyBtn" class="flex-1 bg-purple-600 text-white py-3 rounded-xl font-semibold hover:bg-purple-700 transition">
                                        Fill Manually
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        `;

        document.body.insertAdjacentHTML('beforeend', modalHTML);
        this.modal = document.getElementById('photoWizardModal');

        // Add styles
        this.addStyles();
    }

    /**
     * Add required CSS styles
     */
    addStyles() {
        if (document.getElementById('photoWizardStyles')) return;

        const styles = `
            <style id="photoWizardStyles">
                .photo-wizard-backdrop {
                    animation: fadeIn 0.2s ease-out;
                }

                .photo-wizard-content {
                    animation: slideUp 0.3s ease-out;
                }

                @keyframes fadeIn {
                    from { opacity: 0; }
                    to { opacity: 1; }
                }

                @keyframes slideUp {
                    from {
                        opacity: 0;
                        transform: translateY(20px) scale(0.95);
                    }
                    to {
                        opacity: 1;
                        transform: translateY(0) scale(1);
                    }
                }

                @keyframes shimmer {
                    0% { transform: translateX(-100%); }
                    100% { transform: translateX(100%); }
                }

                .shimmer-animation {
                    animation: shimmer 1.5s infinite;
                }

                .analysis-icon {
                    opacity: 0.4;
                    transform: scale(0.9);
                    transition: all 0.3s ease;
                }

                .analysis-icon.active {
                    opacity: 1;
                    transform: scale(1);
                }

                .analysis-icon.active .w-10 {
                    background: linear-gradient(135deg, #8B5CF6 0%, #6366F1 100%);
                }

                .analysis-icon.complete {
                    opacity: 1;
                }

                .analysis-icon.complete .w-10 {
                    background: #10B981;
                }

                .analysis-connector {
                    transition: background-color 0.3s ease;
                }

                .analysis-connector.active {
                    background: linear-gradient(90deg, #8B5CF6, #6366F1);
                }

                .typewriter {
                    overflow: hidden;
                    border-right: 2px solid #8B5CF6;
                    animation: blink 0.7s step-end infinite;
                }

                @keyframes blink {
                    from, to { border-color: transparent; }
                    50% { border-color: #8B5CF6; }
                }

                .confidence-high { color: #10B981; }
                .confidence-medium { color: #F59E0B; }
                .confidence-low { color: #EF4444; }

                #photoDropZone.drag-over {
                    border-color: #8B5CF6;
                    background-color: rgba(139, 92, 246, 0.1);
                }
            </style>
        `;

        document.head.insertAdjacentHTML('beforeend', styles);
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // File input change
        const fileInput = document.getElementById('wizardPhotoInput');
        if (fileInput) {
            fileInput.addEventListener('change', (e) => this.handleFileSelect(e));
        }

        // Drop zone drag events
        const dropZone = document.getElementById('photoDropZone');
        if (dropZone) {
            ['dragenter', 'dragover'].forEach(eventName => {
                dropZone.addEventListener(eventName, (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    dropZone.classList.add('drag-over');
                });
            });

            ['dragleave', 'drop'].forEach(eventName => {
                dropZone.addEventListener(eventName, (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    dropZone.classList.remove('drag-over');
                });
            });

            dropZone.addEventListener('drop', (e) => {
                const files = e.dataTransfer.files;
                if (files.length > 0) {
                    this.processFile(files[0]);
                }
            });
        }

        // Close button
        const closeBtn = document.getElementById('photoWizardClose');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => this.hide());
        }

        // Skip to manual
        const skipBtn = document.getElementById('skipToManualBtn');
        if (skipBtn) {
            skipBtn.addEventListener('click', () => this.skipToManual());
        }

        // Apply results
        const applyBtn = document.getElementById('applyResultsBtn');
        if (applyBtn) {
            applyBtn.addEventListener('click', () => this.applyResults());
        }

        // Retry
        const retryBtn = document.getElementById('retryAnalysisBtn');
        if (retryBtn) {
            retryBtn.addEventListener('click', () => this.resetToStep1());
        }

        // Fill manually from error
        const fillManuallyBtn = document.getElementById('fillManuallyBtn');
        if (fillManuallyBtn) {
            fillManuallyBtn.addEventListener('click', () => this.skipToManual());
        }

        // Backdrop click to close
        const backdrop = this.modal?.querySelector('.photo-wizard-backdrop');
        if (backdrop) {
            backdrop.addEventListener('click', () => this.hide());
        }

        // Escape key to close
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.modal && !this.modal.classList.contains('hidden')) {
                this.hide();
            }
        });
    }

    /**
     * Show the wizard modal
     */
    show() {
        if (!this.modal) this.createModal();

        this.resetToStep1();
        this.modal.classList.remove('hidden');
        document.body.style.overflow = 'hidden';
    }

    /**
     * Hide the wizard modal
     */
    hide() {
        if (this.modal) {
            this.modal.classList.add('hidden');
            document.body.style.overflow = '';
        }
    }

    /**
     * Reset to step 1
     */
    resetToStep1() {
        document.getElementById('wizardStep1')?.classList.remove('hidden');
        document.getElementById('wizardStep2')?.classList.add('hidden');
        document.getElementById('wizardStep3')?.classList.add('hidden');

        // Reset preview
        document.getElementById('dropZoneContent')?.classList.remove('hidden');
        document.getElementById('photoPreviewContainer')?.classList.add('hidden');

        // Reset file input
        const fileInput = document.getElementById('wizardPhotoInput');
        if (fileInput) fileInput.value = '';

        this.uploadedImage = null;
        this.analysisResult = null;
        this.locationData = null;
        this.exifData = null;
    }

    /**
     * Handle file selection
     */
    handleFileSelect(event) {
        const file = event.target.files?.[0];
        if (file) {
            this.processFile(file);
        }
    }

    /**
     * Process selected file
     */
    async processFile(file) {
        // Validate file type
        if (!file.type.startsWith('image/')) {
            alert('Please select an image file (JPEG, PNG)');
            return;
        }

        // Validate file size
        if (file.size > this.maxImageSize) {
            alert('Image is too large. Please select an image under 4MB.');
            return;
        }

        // Show preview
        const reader = new FileReader();
        reader.onload = async (e) => {
            const dataUrl = e.target.result;

            // Show preview in drop zone
            const previewContainer = document.getElementById('photoPreviewContainer');
            const previewImg = document.getElementById('photoPreview');
            const fileName = document.getElementById('photoFileName');
            const dropZoneContent = document.getElementById('dropZoneContent');

            if (previewContainer && previewImg && dropZoneContent) {
                previewImg.src = dataUrl;
                fileName.textContent = file.name;
                dropZoneContent.classList.add('hidden');
                previewContainer.classList.remove('hidden');
            }

            // Store the image data
            this.uploadedImage = {
                file: file,
                dataUrl: dataUrl
            };

            // Auto-start analysis after a brief delay
            setTimeout(() => this.startAnalysis(), 500);
        };

        reader.readAsDataURL(file);
    }

    /**
     * Start the AI analysis
     */
    async startAnalysis() {
        if (!this.uploadedImage || this.isAnalyzing) return;

        this.isAnalyzing = true;
        this.locationData = null;

        // Show step 2
        document.getElementById('wizardStep1')?.classList.add('hidden');
        document.getElementById('wizardStep2')?.classList.remove('hidden');

        // Set thumbnail
        const thumbnail = document.getElementById('analyzingThumbnail');
        if (thumbnail) {
            thumbnail.src = this.uploadedImage.dataUrl;
        }

        // Animate progress
        this.animateAnalysisIcons();

        try {
            // Step 1: Extract EXIF GPS data (runs in parallel with image compression)
            const [compressedImage, gpsData] = await Promise.all([
                this.compressImageForAPI(this.uploadedImage.file),
                this.extractEXIF(this.uploadedImage.file)
            ]);

            console.log('GPS data extracted:', gpsData);

            // Step 2: Reverse geocode if GPS found
            let locationData = null;
            if (gpsData && gpsData.lat && gpsData.lng) {
                console.log(`Found GPS: ${gpsData.lat}, ${gpsData.lng}`);
                locationData = await this.reverseGeocode(gpsData.lat, gpsData.lng);
                console.log('Location resolved:', locationData);
                this.locationData = locationData;
            }

            // Convert to byte array
            const base64Data = compressedImage.split(',')[1];
            const byteArray = Array.from(atob(base64Data), c => c.charCodeAt(0));

            // Step 3: Call the backend API with image and location
            const requestBody = { image: byteArray };
            if (locationData) {
                requestBody.location = locationData;
            }

            const response = await fetch('/api/analyze-property-photo', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(requestBody)
            });

            const result = await response.json();

            if (result.success && result.analysis) {
                this.analysisResult = result.analysis;
                // Store location in analysis result if not already there
                if (locationData && !this.analysisResult.location) {
                    this.analysisResult.location = locationData;
                }
                this.showResults();
            } else {
                throw new Error(result.error || 'Analysis failed');
            }

        } catch (error) {
            console.error('Analysis error:', error);
            this.showError(error.message);
        } finally {
            this.isAnalyzing = false;
        }
    }

    /**
     * Compress image for API submission
     */
    async compressImageForAPI(file) {
        return new Promise((resolve, reject) => {
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');
            const img = new Image();

            img.onload = () => {
                // Target: max 800px width for faster API processing
                const maxWidth = 800;
                let { width, height } = img;

                if (width > maxWidth) {
                    height = (height * maxWidth) / width;
                    width = maxWidth;
                }

                canvas.width = width;
                canvas.height = height;
                ctx.drawImage(img, 0, 0, width, height);

                // Convert to JPEG with 70% quality
                resolve(canvas.toDataURL('image/jpeg', 0.7));
                URL.revokeObjectURL(img.src);
            };

            img.onerror = () => {
                URL.revokeObjectURL(img.src);
                reject(new Error('Failed to process image'));
            };

            img.src = URL.createObjectURL(file);
        });
    }

    /**
     * Extract EXIF GPS data from image file
     * Returns { lat, lng } or null if no GPS data found
     */
    async extractEXIF(file) {
        return new Promise((resolve) => {
            const reader = new FileReader();

            reader.onload = (e) => {
                try {
                    const view = new DataView(e.target.result);

                    // Check for JPEG
                    if (view.getUint16(0, false) !== 0xFFD8) {
                        resolve(null);
                        return;
                    }

                    const length = view.byteLength;
                    let offset = 2;

                    while (offset < length) {
                        if (view.getUint16(offset, false) === 0xFFE1) {
                            // Found EXIF marker
                            const exifData = this.parseEXIF(view, offset + 4);
                            resolve(exifData);
                            return;
                        }
                        offset += 2 + view.getUint16(offset + 2, false);
                    }

                    resolve(null);
                } catch (err) {
                    console.log('EXIF extraction error:', err);
                    resolve(null);
                }
            };

            reader.onerror = () => resolve(null);

            // Only read first 128KB (EXIF is always near the beginning)
            reader.readAsArrayBuffer(file.slice(0, 128 * 1024));
        });
    }

    /**
     * Parse EXIF data from DataView
     */
    parseEXIF(view, start) {
        try {
            // Check for "Exif" string
            if (String.fromCharCode(view.getUint8(start), view.getUint8(start + 1),
                view.getUint8(start + 2), view.getUint8(start + 3)) !== 'Exif') {
                return null;
            }

            const tiffOffset = start + 6;
            const littleEndian = view.getUint16(tiffOffset, false) === 0x4949;

            const ifdOffset = view.getUint32(tiffOffset + 4, littleEndian);
            const numEntries = view.getUint16(tiffOffset + ifdOffset, littleEndian);

            let gpsOffset = null;

            // Find GPS IFD pointer (tag 0x8825)
            for (let i = 0; i < numEntries; i++) {
                const entryOffset = tiffOffset + ifdOffset + 2 + (i * 12);
                const tag = view.getUint16(entryOffset, littleEndian);

                if (tag === 0x8825) {
                    gpsOffset = view.getUint32(entryOffset + 8, littleEndian);
                    break;
                }
            }

            if (!gpsOffset) return null;

            // Parse GPS IFD
            const gpsIfdOffset = tiffOffset + gpsOffset;
            const gpsEntries = view.getUint16(gpsIfdOffset, littleEndian);

            let latRef = null, lat = null, lngRef = null, lng = null;

            for (let i = 0; i < gpsEntries; i++) {
                const entryOffset = gpsIfdOffset + 2 + (i * 12);
                const tag = view.getUint16(entryOffset, littleEndian);
                const valueOffset = tiffOffset + view.getUint32(entryOffset + 8, littleEndian);

                switch (tag) {
                    case 1: // GPSLatitudeRef
                        latRef = String.fromCharCode(view.getUint8(entryOffset + 8));
                        break;
                    case 2: // GPSLatitude
                        lat = this.parseGPSCoordinate(view, valueOffset, littleEndian);
                        break;
                    case 3: // GPSLongitudeRef
                        lngRef = String.fromCharCode(view.getUint8(entryOffset + 8));
                        break;
                    case 4: // GPSLongitude
                        lng = this.parseGPSCoordinate(view, valueOffset, littleEndian);
                        break;
                }
            }

            if (lat !== null && lng !== null) {
                // Apply reference (N/S, E/W)
                if (latRef === 'S') lat = -lat;
                if (lngRef === 'W') lng = -lng;

                return { lat, lng };
            }

            return null;
        } catch (err) {
            console.log('EXIF parse error:', err);
            return null;
        }
    }

    /**
     * Parse GPS coordinate from EXIF rational values (degrees, minutes, seconds)
     */
    parseGPSCoordinate(view, offset, littleEndian) {
        try {
            const degrees = view.getUint32(offset, littleEndian) / view.getUint32(offset + 4, littleEndian);
            const minutes = view.getUint32(offset + 8, littleEndian) / view.getUint32(offset + 12, littleEndian);
            const seconds = view.getUint32(offset + 16, littleEndian) / view.getUint32(offset + 20, littleEndian);

            return degrees + (minutes / 60) + (seconds / 3600);
        } catch (err) {
            return null;
        }
    }

    /**
     * Reverse geocode GPS coordinates to address via backend API
     */
    async reverseGeocode(lat, lng) {
        try {
            const response = await fetch('/api/reverse-geocode', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ lat, lng })
            });

            if (!response.ok) {
                console.log('Reverse geocode failed:', response.status);
                return null;
            }

            const data = await response.json();
            return data;
        } catch (err) {
            console.log('Reverse geocode error:', err);
            return null;
        }
    }

    /**
     * Animate analysis icons
     */
    animateAnalysisIcons() {
        const icons = document.querySelectorAll('.analysis-icon');
        const connectors = document.querySelectorAll('.analysis-connector');
        const progressBar = document.getElementById('analysisProgress');

        let step = 0;
        const totalSteps = icons.length;

        const animate = () => {
            if (step < totalSteps) {
                // Activate current icon
                icons[step].classList.add('active');

                // Activate connector before current icon
                if (step > 0 && connectors[step - 1]) {
                    connectors[step - 1].classList.add('active');
                }

                // Update progress bar
                const progress = ((step + 1) / totalSteps) * 100;
                if (progressBar) {
                    progressBar.style.width = `${progress}%`;
                }

                // Mark previous icon as complete
                if (step > 0) {
                    icons[step - 1].classList.remove('active');
                    icons[step - 1].classList.add('complete');
                }

                step++;
                setTimeout(animate, 800);
            } else {
                // Complete the last icon
                icons[totalSteps - 1].classList.remove('active');
                icons[totalSteps - 1].classList.add('complete');
                if (connectors[totalSteps - 2]) {
                    connectors[totalSteps - 2].classList.add('active');
                }
            }
        };

        animate();
    }

    /**
     * Show analysis results
     */
    showResults() {
        document.getElementById('wizardStep2')?.classList.add('hidden');
        document.getElementById('wizardStep3')?.classList.remove('hidden');
        document.getElementById('analysisSuccess')?.classList.remove('hidden');
        document.getElementById('analysisError')?.classList.add('hidden');

        const analysis = this.analysisResult;

        // Populate results
        document.getElementById('resultTitle').textContent = analysis.title || 'N/A';
        document.getElementById('resultType').textContent = analysis.house_type || 'N/A';
        document.getElementById('resultBedrooms').textContent = analysis.bedrooms || 'N/A';
        document.getElementById('resultPrice').textContent = analysis.suggestedPrice
            ? `$${analysis.suggestedPrice.toLocaleString()}/mo`
            : 'N/A';

        // Show location if detected from EXIF
        const locationRow = document.getElementById('resultLocationRow');
        const locationText = document.getElementById('resultLocationText');
        const location = analysis.location || this.locationData;

        if (location && location.city) {
            const locationStr = location.state
                ? `${location.city}, ${location.state}${location.zip ? ' ' + location.zip : ''}`
                : location.city;
            locationText.textContent = locationStr;
            locationRow?.classList.remove('hidden');
        } else {
            locationRow?.classList.add('hidden');
        }

        // Confidence indicator
        const confidenceEl = document.getElementById('resultConfidence');
        const confidence = analysis.confidence || 0;
        const confidencePercent = Math.round(confidence * 100);

        let confidenceClass = 'confidence-low';
        let confidenceText = 'Low';

        if (confidence >= 0.8) {
            confidenceClass = 'confidence-high';
            confidenceText = 'High';
        } else if (confidence >= 0.5) {
            confidenceClass = 'confidence-medium';
            confidenceText = 'Medium';
        }

        confidenceEl.textContent = `${confidencePercent}% (${confidenceText})`;
        confidenceEl.className = `font-medium ${confidenceClass}`;
    }

    /**
     * Show error state
     */
    showError(message) {
        document.getElementById('wizardStep2')?.classList.add('hidden');
        document.getElementById('wizardStep3')?.classList.remove('hidden');
        document.getElementById('analysisSuccess')?.classList.add('hidden');
        document.getElementById('analysisError')?.classList.remove('hidden');

        const errorEl = document.getElementById('errorMessage');
        if (errorEl) {
            errorEl.textContent = message || 'Something went wrong. Please try again.';
        } else {
            console.error('Photo analysis error:', message);
            alert('Analysis failed: ' + (message || 'Unknown error'));
        }
    }

    /**
     * Apply results to the listing form
     */
    applyResults() {
        if (!this.analysisResult) return;

        const analysis = this.analysisResult;

        // Hide wizard
        this.hide();

        // Show the add listing form
        if (window.addListingForm) {
            window.addListingForm.showForm();
        }

        // Add the uploaded image to the form
        if (this.uploadedImage && window.addListingForm) {
            // Transfer the uploaded file to the form's file input
            const mediaInput = document.getElementById('media');
            if (mediaInput && this.uploadedImage.file) {
                const dt = new DataTransfer();
                dt.items.add(this.uploadedImage.file);
                mediaInput.files = dt.files;

                // Trigger change event to update preview
                mediaInput.dispatchEvent(new Event('change'));
            }
        }

        // Populate form fields with typewriter animation
        this.populateFormWithAnimation(analysis);
    }

    /**
     * Populate form fields with typewriter animation
     */
    async populateFormWithAnimation(analysis) {
        // Build location string if available
        const location = analysis.location || this.locationData;
        let locationStr = '';
        if (location && location.city) {
            locationStr = location.state
                ? `${location.city}, ${location.state}`
                : location.city;
        }

        const fields = [
            { id: 'title', value: analysis.title, delay: 0 },
            { id: 'houseType', value: analysis.house_type, isSelect: true, delay: 200 },
            { id: 'bedrooms', value: analysis.bedrooms, delay: 400 },
            { id: 'location', value: locationStr, delay: 500 }, // Add location if field exists
            { id: 'city', value: location?.city || '', delay: 500 }, // Some forms use city field
            { id: 'state', value: location?.state || '', isSelect: true, delay: 550 },
            { id: 'zipCode', value: location?.zip || '', delay: 600 },
            { id: 'price', value: analysis.suggestedPrice, delay: 700 },
            { id: 'description', value: analysis.description, delay: 900 }
        ];

        for (const field of fields) {
            await this.delay(field.delay);

            const element = document.getElementById(field.id);
            if (!element || !field.value) continue;

            if (field.isSelect) {
                // For select elements
                element.value = field.value;
                element.dispatchEvent(new Event('change'));
                this.flashField(element);
            } else if (field.id === 'description') {
                // Typewriter effect for description
                await this.typewriterEffect(element, String(field.value));
            } else {
                // Quick typewriter for short fields
                await this.typewriterEffect(element, String(field.value), 30);
            }
        }

        // Show confidence badge/toast
        this.showConfidenceToast(analysis.confidence);
    }

    /**
     * Typewriter effect for input fields
     */
    async typewriterEffect(element, text, charDelay = 20) {
        element.value = '';
        element.classList.add('typewriter');

        for (let i = 0; i < text.length; i++) {
            element.value += text[i];
            element.scrollLeft = element.scrollWidth;
            await this.delay(charDelay);
        }

        element.classList.remove('typewriter');
        this.flashField(element);
    }

    /**
     * Flash field to indicate completion
     */
    flashField(element) {
        element.style.transition = 'background-color 0.3s ease';
        element.style.backgroundColor = '#EEF2FF';

        setTimeout(() => {
            element.style.backgroundColor = '';
        }, 500);
    }

    /**
     * Show confidence toast
     */
    showConfidenceToast(confidence) {
        const confidencePercent = Math.round((confidence || 0) * 100);
        let message, bgClass;

        if (confidence >= 0.8) {
            message = `AI is ${confidencePercent}% confident. Review and submit!`;
            bgClass = 'bg-green-500';
        } else if (confidence >= 0.5) {
            message = `AI is ${confidencePercent}% confident. Please review the details.`;
            bgClass = 'bg-yellow-500';
        } else {
            message = `AI confidence is low (${confidencePercent}%). Please verify all fields.`;
            bgClass = 'bg-red-500';
        }

        // Create toast
        const toast = document.createElement('div');
        toast.className = `fixed bottom-4 right-4 ${bgClass} text-white px-6 py-3 rounded-lg shadow-lg z-50 animate-slide-up`;
        toast.innerHTML = `
            <div class="flex items-center gap-2">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                <span>${message}</span>
            </div>
        `;

        document.body.appendChild(toast);

        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transition = 'opacity 0.3s ease';
            setTimeout(() => toast.remove(), 300);
        }, 5000);
    }

    /**
     * Skip to manual form
     */
    skipToManual() {
        this.hide();

        if (window.addListingForm) {
            window.addListingForm.showForm();
        }
    }

    /**
     * Utility delay function
     */
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

// Create global instance
window.photoListingWizard = new PhotoListingWizard();

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.photoListingWizard.init();
    });
} else {
    window.photoListingWizard.init();
}

// Global function for easy access
window.showPhotoWizard = () => {
    if (window.photoListingWizard) {
        window.photoListingWizard.show();
    }
};
