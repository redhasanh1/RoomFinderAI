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
        this.maxImageSize = 20 * 1024 * 1024; // 20MB - preserve EXIF GPS data
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
                                    <p class="text-gray-400 text-xs mt-3">JPEG, PNG up to 20MB</p>
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

                        <!-- Step 3: Results/Error - GOD MODE SCORECARD -->
                        <div id="wizardStep3" class="hidden p-6">
                            <!-- Success state - GOD MODE UI -->
                            <div id="analysisSuccess" class="hidden">
                                <!-- Header with Grade -->
                                <div class="text-center mb-4">
                                    <div class="inline-flex items-center gap-2 bg-gradient-to-r from-purple-600 to-indigo-600 text-white px-4 py-2 rounded-full text-sm font-bold mb-3">
                                        <span>GOD MODE</span>
                                        <span class="bg-white/20 px-2 py-0.5 rounded">ANALYSIS COMPLETE</span>
                                    </div>
                                </div>

                                <!-- Unit Grade Card -->
                                <div class="bg-gradient-to-br from-gray-900 to-gray-800 rounded-xl p-4 mb-4 text-white">
                                    <div class="flex items-center justify-between">
                                        <div>
                                            <p class="text-gray-400 text-xs uppercase tracking-wide">Unit Grade</p>
                                            <p id="resultGrade" class="text-4xl font-black">A-</p>
                                            <p id="resultGradeDesc" class="text-sm text-gray-400">Luxury Finishes Detected</p>
                                        </div>
                                        <div class="text-right">
                                            <p class="text-gray-400 text-xs uppercase tracking-wide">Luxury Score</p>
                                            <p id="resultLuxuryScore" class="text-3xl font-bold text-purple-400">7/10</p>
                                        </div>
                                    </div>
                                </div>

                                <!-- Pricing Card -->
                                <div class="bg-green-50 border border-green-200 rounded-xl p-4 mb-4">
                                    <div class="flex items-center justify-between mb-2">
                                        <span class="text-green-800 font-semibold">Recommended Rent</span>
                                        <span id="resultPrice" class="text-2xl font-black text-green-600">$2,450</span>
                                    </div>
                                    <div id="resultPremiumRow" class="flex items-center gap-2 text-sm">
                                        <span class="bg-green-200 text-green-800 px-2 py-0.5 rounded font-medium" id="resultPremium">+$250</span>
                                        <span class="text-green-700">above area average</span>
                                    </div>
                                </div>

                                <!-- Money Features (What's Adding Value) -->
                                <div id="moneyFeaturesSection" class="mb-4">
                                    <p class="text-xs uppercase tracking-wide text-gray-500 mb-2 font-semibold">Why This Price?</p>
                                    <div id="moneyFeaturesList" class="space-y-1">
                                        <!-- Dynamically populated -->
                                    </div>
                                </div>

                                <!-- Flaws (Fix These to Charge More) -->
                                <div id="flawsSection" class="mb-4 hidden">
                                    <p class="text-xs uppercase tracking-wide text-orange-600 mb-2 font-semibold">Fix These to Charge More</p>
                                    <div id="flawsList" class="space-y-2">
                                        <!-- Dynamically populated -->
                                    </div>
                                </div>

                                <!-- Staging Alert -->
                                <div id="stagingAlert" class="mb-4 hidden">
                                    <div class="bg-yellow-50 border border-yellow-300 rounded-xl p-3">
                                        <div class="flex items-center gap-2 text-yellow-800 font-semibold text-sm mb-1">
                                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
                                            </svg>
                                            Photo Needs Staging
                                        </div>
                                        <p id="stagingIssuesList" class="text-yellow-700 text-xs">Detected: clutter, mess</p>
                                        <button id="autoStageBtn" class="mt-2 w-full bg-yellow-500 hover:bg-yellow-600 text-white text-sm py-1.5 rounded-lg font-medium transition">
                                            Auto-Clean Photo (AI)
                                        </button>
                                    </div>
                                </div>

                                <!-- Target Demo -->
                                <div class="bg-purple-50 rounded-xl p-3 mb-4">
                                    <p class="text-xs uppercase tracking-wide text-purple-600 mb-1 font-semibold">Target Audience</p>
                                    <p id="resultTargetDemo" class="font-medium text-purple-900">Tech Professionals</p>
                                    <div id="vibeKeywords" class="flex flex-wrap gap-1 mt-2">
                                        <!-- Dynamically populated -->
                                    </div>
                                </div>

                                <!-- Location (GPS or AI Estimate - ALWAYS SHOWN) -->
                                <div id="resultLocationRow" class="rounded-xl p-3 mb-4">
                                    <div class="flex items-center gap-2">
                                        <svg class="w-5 h-5" id="locationIcon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
                                        </svg>
                                        <div class="flex-1">
                                            <p class="text-xs font-semibold" id="locationSourceText">Location Detected from Photo</p>
                                            <p id="resultLocationText" class="font-medium">Seattle, WA 98101</p>
                                        </div>
                                        <span id="locationBadge" class="text-xs px-2 py-0.5 rounded font-medium">GPS</span>
                                    </div>
                                </div>

                                <!-- Quick Stats Row -->
                                <div class="grid grid-cols-3 gap-2 mb-4 text-center">
                                    <div class="bg-gray-100 rounded-lg p-2">
                                        <p class="text-lg font-bold text-gray-800" id="resultType">House</p>
                                        <p class="text-xs text-gray-500">Type</p>
                                    </div>
                                    <div class="bg-gray-100 rounded-lg p-2">
                                        <p class="text-lg font-bold text-gray-800" id="resultBedrooms">3</p>
                                        <p class="text-xs text-gray-500">Bedrooms</p>
                                    </div>
                                    <div class="bg-gray-100 rounded-lg p-2">
                                        <p class="text-lg font-bold text-green-600" id="resultConfidence">85%</p>
                                        <p class="text-xs text-gray-500">Confidence</p>
                                    </div>
                                </div>

                                <!-- FOMO Description -->
                                <div class="bg-gray-50 rounded-xl p-3 mb-4">
                                    <p class="text-xs uppercase tracking-wide text-gray-500 mb-1 font-semibold">AI-Generated Description</p>
                                    <p id="resultDescription" class="text-gray-700 text-sm"></p>
                                </div>

                                <!-- Hidden fields for form -->
                                <input type="hidden" id="resultTitle" value="">

                                <button id="applyResultsBtn" class="w-full bg-gradient-to-r from-green-500 to-emerald-600 text-white py-3 rounded-xl font-bold hover:from-green-600 hover:to-emerald-700 transition shadow-lg">
                                    AUTO-GENERATE LISTING
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
            alert('Image is too large. Please select an image under 20MB.');
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
     * Show analysis results - GOD MODE SCORECARD
     */
    showResults() {
        document.getElementById('wizardStep2')?.classList.add('hidden');
        document.getElementById('wizardStep3')?.classList.remove('hidden');
        document.getElementById('analysisSuccess')?.classList.remove('hidden');
        document.getElementById('analysisError')?.classList.add('hidden');

        const analysis = this.analysisResult;

        // ========== UNIT GRADE ==========
        const gradeEl = document.getElementById('resultGrade');
        const gradeDescEl = document.getElementById('resultGradeDesc');
        const luxuryScoreEl = document.getElementById('resultLuxuryScore');

        if (gradeEl) gradeEl.textContent = analysis.unitGrade || 'B';
        if (luxuryScoreEl) luxuryScoreEl.textContent = `${analysis.luxuryScore || 5}/10`;

        // Grade description
        const gradeDescriptions = {
            'A+': 'Exceptional Luxury Property',
            'A': 'Premium Finishes Detected',
            'A-': 'Luxury Finishes Detected',
            'B+': 'Above Average Quality',
            'B': 'Solid Mid-Range Property',
            'B-': 'Average with Potential',
            'C+': 'Basic but Functional',
            'C': 'Budget-Friendly Option',
            'C-': 'Needs Improvement'
        };
        if (gradeDescEl) gradeDescEl.textContent = gradeDescriptions[analysis.unitGrade] || 'Property Analyzed';

        // ========== PRICING ==========
        const priceEl = document.getElementById('resultPrice');
        const premiumEl = document.getElementById('resultPremium');
        const premiumRowEl = document.getElementById('resultPremiumRow');

        if (priceEl) priceEl.textContent = analysis.suggestedPrice ? `$${analysis.suggestedPrice.toLocaleString()}/mo` : 'N/A';

        if (analysis.premiumAboveAvg && analysis.premiumAboveAvg > 0) {
            if (premiumEl) premiumEl.textContent = `+$${analysis.premiumAboveAvg.toLocaleString()}`;
            premiumRowEl?.classList.remove('hidden');
        } else {
            premiumRowEl?.classList.add('hidden');
        }

        // ========== MONEY FEATURES ==========
        const moneyFeaturesSection = document.getElementById('moneyFeaturesSection');
        const moneyFeaturesList = document.getElementById('moneyFeaturesList');

        if (moneyFeaturesList && analysis.moneyFeatures && analysis.moneyFeatures.length > 0) {
            moneyFeaturesList.innerHTML = analysis.moneyFeatures.map(f => `
                <div class="flex items-center justify-between bg-green-50 rounded-lg px-3 py-2">
                    <span class="text-green-800 text-sm">${f.feature}</span>
                    <span class="text-green-600 font-semibold text-sm">+$${f.value}</span>
                </div>
            `).join('');
            moneyFeaturesSection?.classList.remove('hidden');
        } else {
            moneyFeaturesSection?.classList.add('hidden');
        }

        // ========== FLAWS ==========
        const flawsSection = document.getElementById('flawsSection');
        const flawsList = document.getElementById('flawsList');

        if (flawsList && analysis.flaws && analysis.flaws.length > 0) {
            flawsList.innerHTML = analysis.flaws.map(f => `
                <div class="bg-orange-50 rounded-lg px-3 py-2">
                    <div class="flex items-center justify-between">
                        <span class="text-orange-800 text-sm font-medium">${f.issue}</span>
                        <span class="text-orange-600 font-semibold text-xs">+$${f.potentialGain} if fixed</span>
                    </div>
                    <p class="text-orange-600 text-xs mt-1">${f.fix}</p>
                </div>
            `).join('');
            flawsSection?.classList.remove('hidden');
        } else {
            flawsSection?.classList.add('hidden');
        }

        // ========== STAGING ALERT ==========
        const stagingAlert = document.getElementById('stagingAlert');
        const stagingIssuesList = document.getElementById('stagingIssuesList');

        if (analysis.needsStaging && analysis.stagingIssues && analysis.stagingIssues.length > 0) {
            if (stagingIssuesList) stagingIssuesList.textContent = `Detected: ${analysis.stagingIssues.join(', ')}`;
            stagingAlert?.classList.remove('hidden');
        } else {
            stagingAlert?.classList.add('hidden');
        }

        // ========== TARGET DEMOGRAPHIC ==========
        const targetDemoEl = document.getElementById('resultTargetDemo');
        const vibeKeywordsEl = document.getElementById('vibeKeywords');

        if (targetDemoEl) targetDemoEl.textContent = analysis.targetDemo || 'General Renters';

        if (vibeKeywordsEl && analysis.vibeKeywords && analysis.vibeKeywords.length > 0) {
            vibeKeywordsEl.innerHTML = analysis.vibeKeywords.map(k => `
                <span class="bg-purple-200 text-purple-800 px-2 py-0.5 rounded text-xs font-medium">${k}</span>
            `).join('');
        }

        // ========== LOCATION (Always shown - GPS or AI estimate) ==========
        const locationRow = document.getElementById('resultLocationRow');
        const locationText = document.getElementById('resultLocationText');
        const locationSourceText = document.getElementById('locationSourceText');
        const locationBadge = document.getElementById('locationBadge');
        const locationIcon = document.getElementById('locationIcon');
        const location = analysis.location;

        if (location && location.city) {
            const locationStr = `${location.city}, ${location.state || ''} ${location.zip || ''} ${location.country || ''}`.trim();
            if (locationText) locationText.textContent = locationStr;

            // Style based on source (GPS vs AI estimate)
            if (location.source === 'gps') {
                locationRow.className = 'bg-green-50 border border-green-200 rounded-xl p-3 mb-4';
                if (locationSourceText) locationSourceText.textContent = 'Location from Photo GPS';
                if (locationSourceText) locationSourceText.className = 'text-xs font-semibold text-green-600';
                if (locationText) locationText.className = 'font-medium text-green-900';
                if (locationIcon) locationIcon.setAttribute('class', 'w-5 h-5 text-green-600');
                if (locationBadge) {
                    locationBadge.textContent = 'GPS';
                    locationBadge.className = 'text-xs px-2 py-0.5 rounded font-medium bg-green-200 text-green-800';
                }
            } else {
                locationRow.className = 'bg-purple-50 border border-purple-200 rounded-xl p-3 mb-4';
                if (locationSourceText) locationSourceText.textContent = 'AI Estimated Location';
                if (locationSourceText) locationSourceText.className = 'text-xs font-semibold text-purple-600';
                if (locationText) locationText.className = 'font-medium text-purple-900';
                if (locationIcon) locationIcon.setAttribute('class', 'w-5 h-5 text-purple-600');
                if (locationBadge) {
                    locationBadge.textContent = 'AI';
                    locationBadge.className = 'text-xs px-2 py-0.5 rounded font-medium bg-purple-200 text-purple-800';
                }
            }
            locationRow?.classList.remove('hidden');
        }

        // ========== BASIC INFO ==========
        const titleEl = document.getElementById('resultTitle');
        const typeEl = document.getElementById('resultType');
        const bedroomsEl = document.getElementById('resultBedrooms');

        if (titleEl) titleEl.value = analysis.title || '';
        if (typeEl) typeEl.textContent = analysis.house_type || 'N/A';
        if (bedroomsEl) bedroomsEl.textContent = analysis.bedrooms || 'N/A';

        // ========== DESCRIPTION ==========
        const descEl = document.getElementById('resultDescription');
        if (descEl && analysis.description) {
            descEl.textContent = analysis.description;
        }

        // ========== CONFIDENCE ==========
        const confidenceEl = document.getElementById('resultConfidence');
        // Calculate confidence based on what we detected
        let confidence = analysis.confidence;
        if (!confidence || confidence === 0) {
            // Fallback: calculate from features
            confidence = 0.65;
            if (analysis.moneyFeatures && analysis.moneyFeatures.length > 0) confidence += analysis.moneyFeatures.length * 0.05;
            if (analysis.luxuryScore && analysis.luxuryScore > 5) confidence += 0.1;
            confidence = Math.min(0.95, confidence);
        }
        const confidencePercent = Math.round(confidence * 100);

        if (confidenceEl) {
            confidenceEl.textContent = `${confidencePercent}%`;
            confidenceEl.className = `text-lg font-bold ${confidence >= 0.8 ? 'text-green-600' : confidence >= 0.6 ? 'text-yellow-600' : 'text-red-500'}`;
        }
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
    async applyResults() {
        if (!this.analysisResult) return;

        const analysis = this.analysisResult;

        // Save analysis to localStorage for the listings page
        const listingData = {
            title: analysis.title || '',
            house_type: analysis.house_type || 'Apartment',
            bedrooms: analysis.bedrooms || 2,
            price: analysis.suggestedPrice || 1800,
            description: analysis.description || '',
            location: analysis.location || null,
            features: analysis.features || [],
            luxuryScore: analysis.luxuryScore || 5,
            unitGrade: analysis.unitGrade || 'B',
            targetDemo: analysis.targetDemo || '',
            timestamp: Date.now()
        };

        // Save a small thumbnail instead of full image to avoid localStorage quota issues
        if (this.uploadedImage && this.uploadedImage.dataUrl) {
            try {
                const thumbnail = await this.createThumbnail(this.uploadedImage.dataUrl, 150);
                listingData.imageThumbnail = thumbnail;
            } catch (err) {
                console.warn('Could not create thumbnail:', err);
            }
        }

        try {
            localStorage.setItem('pendingListing', JSON.stringify(listingData));
            console.log('Saved pending listing to localStorage:', listingData);
        } catch (err) {
            console.warn('localStorage quota exceeded, continuing without saving:', err);
            // Clear old data and try again with minimal data
            localStorage.removeItem('pendingListing');
            try {
                delete listingData.imageThumbnail;
                localStorage.setItem('pendingListing', JSON.stringify(listingData));
            } catch (e) {
                console.error('Could not save listing data to localStorage');
            }
        }

        // Hide wizard
        this.hide();

        // Check if we're on the listings page
        const onListingsPage = window.location.pathname.includes('listings');

        if (onListingsPage && window.addListingForm) {
            // Already on listings page - show form and populate
            window.addListingForm.showForm();

            // Add the uploaded image to the form
            if (this.uploadedImage) {
                const mediaInput = document.getElementById('media');
                if (mediaInput && this.uploadedImage.file) {
                    const dt = new DataTransfer();
                    dt.items.add(this.uploadedImage.file);
                    mediaInput.files = dt.files;
                    mediaInput.dispatchEvent(new Event('change'));
                }
            }

            // Populate form fields with typewriter animation
            this.populateFormWithAnimation(analysis);
        } else {
            // Navigate to listings page - it will auto-load the form
            window.location.href = 'listings.html?autoFill=true';
        }
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

    /**
     * Create a small thumbnail from a data URL to save in localStorage
     * @param {string} dataUrl - The original image data URL
     * @param {number} maxSize - Maximum width/height in pixels
     * @returns {Promise<string>} - Compressed thumbnail data URL
     */
    createThumbnail(dataUrl, maxSize = 150) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            img.onload = () => {
                const canvas = document.createElement('canvas');
                const ctx = canvas.getContext('2d');

                let { width, height } = img;

                // Scale down to fit within maxSize
                if (width > height) {
                    if (width > maxSize) {
                        height = (height * maxSize) / width;
                        width = maxSize;
                    }
                } else {
                    if (height > maxSize) {
                        width = (width * maxSize) / height;
                        height = maxSize;
                    }
                }

                canvas.width = width;
                canvas.height = height;
                ctx.drawImage(img, 0, 0, width, height);

                // Use low quality JPEG for small file size
                resolve(canvas.toDataURL('image/jpeg', 0.5));
            };
            img.onerror = () => reject(new Error('Failed to load image for thumbnail'));
            img.src = dataUrl;
        });
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
