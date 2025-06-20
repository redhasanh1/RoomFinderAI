// User Verification System for RoomFinderAI
class VerificationSystem {
    constructor(supabaseClient) {
        this.supabase = supabaseClient;
        this.initialized = false;
        this.faceDetector = null;
    }

    // Initialize face detection API
    async initializeFaceDetection() {
        try {
            // Check if MediaDevices is available
            if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
                throw new Error('Camera access not supported');
            }

            // Load face-api.js for face detection
            if (typeof faceapi === 'undefined') {
                await this.loadFaceAPILibrary();
            }

            this.initialized = true;
            return true;
        } catch (error) {
            console.error('Failed to initialize face detection:', error);
            return false;
        }
    }

    // Load face-api.js library
    async loadFaceAPILibrary() {
        return new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = 'https://cdn.jsdelivr.net/npm/face-api.js@0.22.2/dist/face-api.min.js';
            script.onload = resolve;
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }

    // Upload ID document to Supabase Storage
    async uploadIDDocument(file, userEmail) {
        try {
            // Validate file
            if (!this.isValidIDDocument(file)) {
                throw new Error('Invalid ID document format');
            }

            // Create unique filename
            const fileExt = file.name.split('.').pop();
            const fileName = `${userEmail}-${Date.now()}.${fileExt}`;
            const filePath = `id-documents/${fileName}`;

            // Upload to Supabase Storage
            const { data, error } = await this.supabase.storage
                .from('verification-documents')
                .upload(filePath, file);

            if (error) {
                throw new Error(`Upload failed: ${error.message}`);
            }

            // Get public URL
            const { data: urlData } = this.supabase.storage
                .from('verification-documents')
                .getPublicUrl(filePath);

            return {
                url: urlData.publicUrl,
                path: filePath,
                filename: fileName
            };
        } catch (error) {
            console.error('ID upload error:', error);
            throw error;
        }
    }

    // Validate ID document
    isValidIDDocument(file) {
        const validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'application/pdf'];
        const maxSize = 10 * 1024 * 1024; // 10MB

        if (!validTypes.includes(file.type)) {
            alert('Please upload a JPEG, PNG, or PDF file');
            return false;
        }

        if (file.size > maxSize) {
            alert('File size must be less than 10MB');
            return false;
        }

        return true;
    }

    // Start face scanning process
    async startFaceScanning() {
        try {
            if (!this.initialized) {
                await this.initializeFaceDetection();
            }

            // Get camera stream
            const stream = await navigator.mediaDevices.getUserMedia({ 
                video: { 
                    width: 640, 
                    height: 480,
                    facingMode: 'user'
                } 
            });

            return stream;
        } catch (error) {
            console.error('Face scanning error:', error);
            throw new Error('Unable to access camera for face scanning');
        }
    }

    // Capture and analyze face
    async captureFace(videoElement) {
        try {
            // Create canvas for face capture
            const canvas = document.createElement('canvas');
            const context = canvas.getContext('2d');
            
            canvas.width = videoElement.videoWidth;
            canvas.height = videoElement.videoHeight;
            
            // Draw current video frame to canvas
            context.drawImage(videoElement, 0, 0, canvas.width, canvas.height);
            
            // Convert to blob
            return new Promise((resolve) => {
                canvas.toBlob((blob) => {
                    resolve({
                        blob: blob,
                        dataUrl: canvas.toDataURL('image/jpeg', 0.8)
                    });
                }, 'image/jpeg', 0.8);
            });
        } catch (error) {
            console.error('Face capture error:', error);
            throw error;
        }
    }

    // Basic face detection (placeholder - in production use proper face recognition)
    async detectFace(imageDataUrl) {
        try {
            // This is a simplified implementation
            // In production, you would use a proper face recognition service
            
            // Create image element
            const img = new Image();
            img.src = imageDataUrl;
            
            return new Promise((resolve) => {
                img.onload = () => {
                    // Basic face detection simulation
                    // In reality, this would use face-api.js or a cloud service
                    const confidence = Math.random() * 0.3 + 0.7; // 70-100% confidence
                    resolve({
                        faceDetected: true,
                        confidence: confidence,
                        landmarks: [] // Would contain actual face landmarks
                    });
                };
            });
        } catch (error) {
            console.error('Face detection error:', error);
            return {
                faceDetected: false,
                confidence: 0,
                error: error.message
            };
        }
    }

    // Submit verification request
    async submitVerificationRequest(userEmail, idDocumentData, faceData) {
        try {
            // Handle both old single-capture format and new multi-pose format
            let faceVerificationData;
            let faceVerificationScore;
            
            if (faceData.poses && Array.isArray(faceData.poses)) {
                // New multi-pose format
                faceVerificationData = {
                    poses: faceData.poses.map(pose => ({
                        pose_type: pose.pose,
                        image_url: pose.data.dataUrl,
                        confidence: pose.confidence,
                        captured_at: pose.timestamp
                    })),
                    average_confidence: faceData.confidence,
                    total_poses: faceData.poses.length,
                    verification_type: 'multi_pose',
                    completed_at: faceData.completedAt
                };
                faceVerificationScore = faceData.confidence;
            } else {
                // Legacy single-capture format (fallback)
                faceVerificationData = {
                    image_url: faceData.dataUrl || faceData.image_url,
                    confidence: faceData.confidence || 0.85,
                    verification_type: 'single_capture',
                    captured_at: new Date().toISOString()
                };
                faceVerificationScore = faceData.confidence || 0.85;
            }

            const verificationData = {
                user_email: userEmail,
                id_document_url: idDocumentData.url,
                id_document_type: this.detectIDType(idDocumentData.filename),
                face_scan_data: faceVerificationData,
                face_verification_score: faceVerificationScore,
                ip_address: await this.getUserIP(),
                user_agent: navigator.userAgent,
                verification_method: 'enhanced_guided_scanning'
            };

            const response = await fetch('http://localhost:3000/api/verification/submit', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(verificationData)
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || 'Verification submission failed');
            }

            const result = await response.json();
            return result.verification;
        } catch (error) {
            console.error('Verification submission error:', error);
            throw error;
        }
    }

    // Detect ID document type from filename
    detectIDType(filename) {
        const lower = filename.toLowerCase();
        if (lower.includes('passport')) return 'passport';
        if (lower.includes('license') || lower.includes('driver')) return 'drivers_license';
        if (lower.includes('national') || lower.includes('id')) return 'national_id';
        return 'other';
    }

    // Get user's IP address
    async getUserIP() {
        try {
            const response = await fetch('https://api.ipify.org?format=json');
            const data = await response.json();
            return data.ip;
        } catch (error) {
            console.error('IP detection error:', error);
            return null;
        }
    }

    // Check verification status
    async getVerificationStatus(userEmail) {
        try {
            const response = await fetch(`http://localhost:3000/api/verification/status/${encodeURIComponent(userEmail)}`);
            
            if (!response.ok) {
                if (response.status === 404) {
                    return null;
                }
                const errorData = await response.json();
                throw new Error(errorData.error || 'Failed to check verification status');
            }

            const result = await response.json();
            return result.latestVerification;
        } catch (error) {
            console.error('Verification status error:', error);
            throw error;
        }
    }

    // Check if user is verified
    async isUserVerified(userEmail) {
        try {
            const response = await fetch(`http://localhost:3000/api/verification/status/${encodeURIComponent(userEmail)}`);
            
            if (!response.ok) {
                return false;
            }

            const result = await response.json();
            return result.isVerified || false;
        } catch (error) {
            console.error('User verification error:', error);
            return false;
        }
    }
}

// Verification UI Components
class VerificationUI {
    constructor(verificationSystem) {
        this.verification = verificationSystem;
        this.currentStep = 'start';
        this.uploadedIDData = null;
        this.capturedFaceData = null;
    }

    // Create verification modal
    createVerificationModal() {
        const modal = document.createElement('div');
        modal.id = 'verificationModal';
        modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
        modal.style.display = 'none';

        modal.innerHTML = `
            <div class="bg-white rounded-2xl p-8 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
                <div class="flex justify-between items-center mb-6">
                    <h2 class="text-2xl font-bold text-gray-800">Get Verified</h2>
                    <button id="closeVerificationModal" class="text-gray-500 hover:text-gray-700">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                        </svg>
                    </button>
                </div>
                
                <div id="verificationContent">
                    <!-- Dynamic content will be inserted here -->
                </div>
            </div>
        `;

        return modal;
    }

    // Show verification start screen
    showStartScreen() {
        const content = document.getElementById('verificationContent');
        content.innerHTML = `
            <div class="text-center">
                <div class="mb-6">
                    <div class="bg-blue-100 rounded-full p-4 w-16 h-16 mx-auto mb-4">
                        <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.5-2a8.5 8.5 0 11-17 0 8.5 8.5 0 0117 0z"></path>
                        </svg>
                    </div>
                    <h3 class="text-xl font-semibold text-gray-800 mb-2">Verify Your Identity</h3>
                    <p class="text-gray-600">Get verified to build trust with potential renters and stand out from the crowd.</p>
                </div>
                
                <div class="space-y-4 mb-8">
                    <div class="flex items-center text-left">
                        <div class="bg-green-100 rounded-full p-2 mr-4">
                            <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                            </svg>
                        </div>
                        <span class="text-gray-700">Upload a government-issued ID</span>
                    </div>
                    <div class="flex items-center text-left">
                        <div class="bg-green-100 rounded-full p-2 mr-4">
                            <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                            </svg>
                        </div>
                        <span class="text-gray-700">Complete face verification scan</span>
                    </div>
                    <div class="flex items-center text-left">
                        <div class="bg-green-100 rounded-full p-2 mr-4">
                            <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                            </svg>
                        </div>
                        <span class="text-gray-700">Get your verified badge</span>
                    </div>
                </div>
                
                <button id="startVerificationBtn" class="modern-button w-full">
                    Start Verification Process
                </button>
            </div>
        `;

        document.getElementById('startVerificationBtn').addEventListener('click', () => {
            this.showIDUploadScreen();
        });
    }

    // Show ID upload screen
    showIDUploadScreen() {
        const content = document.getElementById('verificationContent');
        content.innerHTML = `
            <div>
                <div class="mb-6">
                    <h3 class="text-xl font-semibold text-gray-800 mb-2">Upload Government-Issued ID</h3>
                    <p class="text-gray-600">Please upload a clear photo of your government-issued identification document.</p>
                </div>
                
                <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center mb-6">
                    <div id="idUploadArea">
                        <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
                        </svg>
                        <p class="text-gray-600 mb-4">Click to upload or drag and drop</p>
                        <p class="text-sm text-gray-500">Supports: JPEG, PNG, PDF (Max 10MB)</p>
                        <input type="file" id="idDocumentInput" class="hidden" accept="image/jpeg,image/jpg,image/png,application/pdf">
                        <button id="selectIDBtn" class="mt-4 bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition">
                            Select File
                        </button>
                    </div>
                    <div id="idPreview" class="hidden">
                        <!-- Preview will be shown here -->
                    </div>
                </div>
                
                <div class="flex space-x-4">
                    <button id="backToStartBtn" class="flex-1 bg-gray-300 text-gray-700 py-3 rounded-lg hover:bg-gray-400 transition">
                        Back
                    </button>
                    <button id="continueToFaceScanBtn" class="flex-1 modern-button" disabled>
                        Continue to Face Scan
                    </button>
                </div>
            </div>
        `;

        // Setup event listeners
        document.getElementById('selectIDBtn').addEventListener('click', () => {
            document.getElementById('idDocumentInput').click();
        });

        document.getElementById('idDocumentInput').addEventListener('change', (e) => {
            this.handleIDUpload(e.target.files[0]);
        });

        document.getElementById('backToStartBtn').addEventListener('click', () => {
            this.showStartScreen();
        });

        document.getElementById('continueToFaceScanBtn').addEventListener('click', () => {
            this.showFaceScanScreen();
        });
    }

    // Handle ID document upload
    async handleIDUpload(file) {
        if (!file || !this.verification.isValidIDDocument(file)) {
            return;
        }

        try {
            // Show loading
            document.getElementById('idUploadArea').innerHTML = '<p class="text-blue-600">Uploading...</p>';

            // Get current user
            const currentUser = JSON.parse(localStorage.getItem('currentUser'));
            
            // Upload file
            this.uploadedIDData = await this.verification.uploadIDDocument(file, currentUser.email);

            // Show preview
            this.showIDPreview(file, this.uploadedIDData);

            // Enable continue button
            document.getElementById('continueToFaceScanBtn').disabled = false;

        } catch (error) {
            console.error('ID upload error:', error);
            alert('Failed to upload ID document. Please try again.');
            this.showIDUploadScreen();
        }
    }

    // Show ID preview
    showIDPreview(file, uploadData) {
        const previewArea = document.getElementById('idPreview');
        const uploadArea = document.getElementById('idUploadArea');
        
        uploadArea.classList.add('hidden');
        previewArea.classList.remove('hidden');

        if (file.type === 'application/pdf') {
            previewArea.innerHTML = `
                <div class="text-center">
                    <svg class="w-16 h-16 text-red-600 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"></path>
                    </svg>
                    <p class="text-green-600 font-semibold">PDF uploaded successfully</p>
                    <p class="text-sm text-gray-500">${file.name}</p>
                    <button id="changeIDBtn" class="mt-2 text-blue-600 text-sm hover:underline">Change file</button>
                </div>
            `;
        } else {
            const reader = new FileReader();
            reader.onload = (e) => {
                previewArea.innerHTML = `
                    <div class="text-center">
                        <img src="${e.target.result}" alt="ID Preview" class="max-w-full max-h-48 mx-auto mb-2 rounded-lg">
                        <p class="text-green-600 font-semibold">ID uploaded successfully</p>
                        <button id="changeIDBtn" class="mt-2 text-blue-600 text-sm hover:underline">Change file</button>
                    </div>
                `;
                
                document.getElementById('changeIDBtn').addEventListener('click', () => {
                    this.showIDUploadScreen();
                });
            };
            reader.readAsDataURL(file);
        }
    }

    // Show face scan screen
    showFaceScanScreen() {
        const content = document.getElementById('verificationContent');
        content.innerHTML = `
            <div>
                <div class="mb-6">
                    <h3 class="text-xl font-semibold text-gray-800 mb-2">Face Verification</h3>
                    <p class="text-gray-600">Follow the guided steps to complete your face verification.</p>
                </div>
                
                <!-- Progress Indicator -->
                <div class="mb-6">
                    <div class="flex justify-between items-center mb-2">
                        <span class="text-sm font-medium text-gray-600">Step <span id="currentStepNumber">1</span> of 6</span>
                        <span class="text-sm text-gray-500"><span id="completedSteps">0</span> completed</span>
                    </div>
                    <div class="w-full bg-gray-200 rounded-full h-2">
                        <div id="progressBar" class="bg-blue-600 h-2 rounded-full transition-all duration-300" style="width: 0%"></div>
                    </div>
                </div>
                
                <!-- Instructions Panel -->
                <div id="instructionPanel" class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
                    <div class="flex items-center">
                        <div class="bg-blue-100 rounded-full p-2 mr-3">
                            <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                            </svg>
                        </div>
                        <div>
                            <p id="instructionText" class="font-medium text-blue-800">Position your face in the center of the circle and look directly at the camera</p>
                            <p id="instructionSubtext" class="text-sm text-blue-600 mt-1">Make sure your face is well-lit and clearly visible</p>
                        </div>
                    </div>
                </div>
                
                <div class="relative mb-6">
                    <video id="faceVideo" class="w-full max-w-md mx-auto rounded-lg bg-gray-200" autoplay playsinline></video>
                    <div id="faceOverlay" class="absolute inset-0 pointer-events-none">
                        <div class="w-full h-full flex items-center justify-center">
                            <div id="faceGuideCircle" class="border-2 border-blue-500 rounded-full w-48 h-48 opacity-50 transition-all duration-300"></div>
                            <!-- Direction Indicators -->
                            <div id="directionIndicators" class="absolute inset-0">
                                <div id="upArrow" class="absolute top-8 left-1/2 transform -translate-x-1/2 hidden">
                                    <svg class="w-8 h-8 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 15l7-7 7 7"></path>
                                    </svg>
                                </div>
                                <div id="leftArrow" class="absolute top-1/2 left-8 transform -translate-y-1/2 hidden">
                                    <svg class="w-8 h-8 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M15 19l-7-7 7-7"></path>
                                    </svg>
                                </div>
                                <div id="downArrow" class="absolute bottom-8 left-1/2 transform -translate-x-1/2 hidden">
                                    <svg class="w-8 h-8 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M19 9l-7 7-7-7"></path>
                                    </svg>
                                </div>
                                <div id="rightArrow" class="absolute top-1/2 right-8 transform -translate-y-1/2 hidden">
                                    <svg class="w-8 h-8 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M9 5l7 7-7 7"></path>
                                    </svg>
                                </div>
                                <div id="centerDot" class="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2">
                                    <div class="w-4 h-4 bg-green-500 rounded-full opacity-75"></div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <!-- Pose Detection Status -->
                <div id="poseStatus" class="text-center mb-4">
                    <div id="poseIndicator" class="inline-flex items-center px-3 py-1 rounded-full text-sm">
                        <span id="poseStatusText">Position your face in the circle</span>
                    </div>
                </div>
                
                <div id="faceCapture" class="hidden mb-6">
                    <div class="grid grid-cols-3 gap-2 mb-4">
                        <div id="capturedPoses">
                            <!-- Captured poses will be shown here -->
                        </div>
                    </div>
                    <div class="text-center mt-4">
                        <p class="text-green-600 font-semibold">All poses captured successfully!</p>
                        <button id="retakeFaceBtn" class="mt-2 text-blue-600 text-sm hover:underline">Retake verification</button>
                    </div>
                </div>
                
                <div class="flex space-x-4">
                    <button id="backToIDBtn" class="flex-1 bg-gray-300 text-gray-700 py-3 rounded-lg hover:bg-gray-400 transition">
                        Back
                    </button>
                    <button id="capturePoseBtn" class="flex-1 modern-button">
                        Capture Pose
                    </button>
                    <button id="skipPoseBtn" class="flex-1 bg-yellow-500 text-white py-3 rounded-lg hover:bg-yellow-600 transition hidden">
                        Skip This Pose
                    </button>
                    <button id="submitVerificationBtn" class="flex-1 modern-button hidden">
                        Submit Verification
                    </button>
                </div>
            </div>
        `;

        // Initialize guided face scanning
        this.initializeGuidedFaceScanning();

        // Setup event listeners
        document.getElementById('backToIDBtn').addEventListener('click', () => {
            this.stopCamera();
            this.showIDUploadScreen();
        });

        document.getElementById('capturePoseBtn').addEventListener('click', () => {
            this.captureCurrentPose();
        });

        document.getElementById('skipPoseBtn').addEventListener('click', () => {
            this.skipCurrentPose();
        });

        document.getElementById('submitVerificationBtn').addEventListener('click', () => {
            this.submitVerification();
        });
    }

    // Initialize guided face scanning
    async initializeGuidedFaceScanning() {
        // Initialize scanning state
        this.scanningState = {
            currentPose: 0,
            poses: [
                { name: 'center', instruction: 'Look directly at the camera', subtext: 'Keep your face centered in the circle', arrow: 'centerDot' },
                { name: 'up', instruction: 'Look up while keeping your face in the circle', subtext: 'Tilt your head slightly upward', arrow: 'upArrow' },
                { name: 'left', instruction: 'Turn your head to the left', subtext: 'Look toward the left side while staying in frame', arrow: 'leftArrow' },
                { name: 'down', instruction: 'Look down while keeping your face visible', subtext: 'Tilt your head slightly downward', arrow: 'downArrow' },
                { name: 'right', instruction: 'Turn your head to the right', subtext: 'Look toward the right side while staying in frame', arrow: 'rightArrow' },
                { name: 'center_final', instruction: 'Look directly at the camera again', subtext: 'Return to center position for final capture', arrow: 'centerDot' }
            ],
            capturedPoses: [],
            completedCount: 0
        };

        // Initialize camera
        await this.initializeCamera();
        
        // Start pose guidance
        this.updatePoseInstructions();
        
        // Setup retake functionality
        document.getElementById('retakeFaceBtn').addEventListener('click', () => {
            this.resetGuidedScanning();
        });
    }

    // Initialize camera for face scanning
    async initializeCamera() {
        try {
            const video = document.getElementById('faceVideo');
            const stream = await this.verification.startFaceScanning();
            video.srcObject = stream;
            video.play();
        } catch (error) {
            console.error('Camera initialization error:', error);
            alert('Unable to access camera. Please ensure camera permissions are granted.');
        }
    }

    // Update pose instructions and UI
    updatePoseInstructions() {
        const currentPose = this.scanningState.poses[this.scanningState.currentPose];
        const progress = (this.scanningState.completedCount / this.scanningState.poses.length) * 100;
        
        // Update progress indicators
        document.getElementById('currentStepNumber').textContent = this.scanningState.currentPose + 1;
        document.getElementById('completedSteps').textContent = this.scanningState.completedCount;
        document.getElementById('progressBar').style.width = `${progress}%`;
        
        // Update instructions
        document.getElementById('instructionText').textContent = currentPose.instruction;
        document.getElementById('instructionSubtext').textContent = currentPose.subtext;
        
        // Update visual indicators
        this.updateDirectionIndicators(currentPose.arrow);
        
        // Update pose status
        this.updatePoseStatus('waiting');
        
        // Show skip button for optional poses (not center poses)
        const skipBtn = document.getElementById('skipPoseBtn');
        if (currentPose.name !== 'center' && currentPose.name !== 'center_final') {
            skipBtn.classList.remove('hidden');
        } else {
            skipBtn.classList.add('hidden');
        }
    }

    // Update direction indicators
    updateDirectionIndicators(activeArrow) {
        const indicators = ['upArrow', 'leftArrow', 'downArrow', 'rightArrow', 'centerDot'];
        
        indicators.forEach(indicator => {
            const element = document.getElementById(indicator);
            if (indicator === activeArrow) {
                element.classList.remove('hidden');
                element.classList.add('animate-pulse');
            } else {
                element.classList.add('hidden');
                element.classList.remove('animate-pulse');
            }
        });
    }

    // Update pose status indicator
    updatePoseStatus(status) {
        const indicator = document.getElementById('poseIndicator');
        const text = document.getElementById('poseStatusText');
        
        // Reset classes
        indicator.className = 'inline-flex items-center px-3 py-1 rounded-full text-sm';
        
        switch (status) {
            case 'waiting':
                indicator.classList.add('bg-gray-100', 'text-gray-800');
                text.textContent = 'Position yourself as instructed';
                break;
            case 'ready':
                indicator.classList.add('bg-green-100', 'text-green-800');
                text.textContent = 'Good! Ready to capture';
                break;
            case 'captured':
                indicator.classList.add('bg-blue-100', 'text-blue-800');
                text.textContent = 'Pose captured successfully';
                break;
            case 'error':
                indicator.classList.add('bg-red-100', 'text-red-800');
                text.textContent = 'Please adjust your position';
                break;
        }
    }

    // Capture current pose
    async captureCurrentPose() {
        try {
            const video = document.getElementById('faceVideo');
            const faceData = await this.verification.captureFace(video);
            
            // Analyze face
            const detection = await this.verification.detectFace(faceData.dataUrl);
            
            if (detection.faceDetected && detection.confidence > 0.7) {
                const currentPose = this.scanningState.poses[this.scanningState.currentPose];
                
                // Store captured pose data
                const poseData = {
                    pose: currentPose.name,
                    data: faceData,
                    confidence: detection.confidence,
                    timestamp: new Date().toISOString()
                };
                
                this.scanningState.capturedPoses.push(poseData);
                this.scanningState.completedCount++;
                
                // Update status
                this.updatePoseStatus('captured');
                
                // Add visual feedback
                this.flashSuccessIndicator();
                
                // Move to next pose after a short delay
                setTimeout(() => {
                    this.moveToNextPose();
                }, 1000);
                
            } else {
                this.updatePoseStatus('error');
                alert('Face not detected clearly. Please ensure good lighting and position your face as instructed.');
            }
        } catch (error) {
            console.error('Pose capture error:', error);
            this.updatePoseStatus('error');
            alert('Failed to capture pose. Please try again.');
        }
    }

    // Skip current pose (for optional poses only)
    skipCurrentPose() {
        const currentPose = this.scanningState.poses[this.scanningState.currentPose];
        
        // Only allow skipping non-essential poses
        if (currentPose.name !== 'center' && currentPose.name !== 'center_final') {
            this.moveToNextPose();
        }
    }

    // Move to next pose or complete scanning
    moveToNextPose() {
        this.scanningState.currentPose++;
        
        if (this.scanningState.currentPose >= this.scanningState.poses.length) {
            // All poses completed
            this.completeFaceScanning();
        } else {
            // Move to next pose
            this.updatePoseInstructions();
        }
    }

    // Complete face scanning process
    completeFaceScanning() {
        // Combine all captured poses into verification data
        this.capturedFaceData = {
            poses: this.scanningState.capturedPoses,
            confidence: this.calculateAverageConfidence(),
            completedAt: new Date().toISOString()
        };
        
        // Show captured poses grid
        this.showCapturedPoses();
        
        // Hide pose controls and show submit button
        document.getElementById('capturePoseBtn').classList.add('hidden');
        document.getElementById('skipPoseBtn').classList.add('hidden');
        document.getElementById('submitVerificationBtn').classList.remove('hidden');
        document.getElementById('faceCapture').classList.remove('hidden');
        
        // Stop camera
        this.stopCamera();
        
        // Update final status
        this.updatePoseStatus('captured');
        document.getElementById('instructionText').textContent = 'Face verification completed successfully!';
        document.getElementById('instructionSubtext').textContent = 'Review your captured poses and submit when ready';
    }

    // Calculate average confidence from all poses
    calculateAverageConfidence() {
        if (this.scanningState.capturedPoses.length === 0) return 0;
        
        const totalConfidence = this.scanningState.capturedPoses.reduce((sum, pose) => sum + pose.confidence, 0);
        return totalConfidence / this.scanningState.capturedPoses.length;
    }

    // Show captured poses in a grid
    showCapturedPoses() {
        const container = document.getElementById('capturedPoses');
        container.innerHTML = '';
        
        this.scanningState.capturedPoses.forEach((poseData, index) => {
            const poseElement = document.createElement('div');
            poseElement.className = 'relative';
            poseElement.innerHTML = `
                <img src="${poseData.data.dataUrl}" alt="${poseData.pose}" class="w-full h-20 object-cover rounded-lg">
                <div class="absolute bottom-1 left-1 bg-black bg-opacity-50 text-white text-xs px-1 rounded">
                    ${poseData.pose}
                </div>
            `;
            container.appendChild(poseElement);
        });
    }

    // Reset guided scanning process
    resetGuidedScanning() {
        // Reset state
        this.scanningState.currentPose = 0;
        this.scanningState.capturedPoses = [];
        this.scanningState.completedCount = 0;
        
        // Reset UI
        document.getElementById('faceCapture').classList.add('hidden');
        document.getElementById('capturePoseBtn').classList.remove('hidden');
        document.getElementById('submitVerificationBtn').classList.add('hidden');
        
        // Restart camera and instructions
        this.initializeCamera();
        this.updatePoseInstructions();
    }

    // Flash success indicator
    flashSuccessIndicator() {
        const circle = document.getElementById('faceGuideCircle');
        circle.classList.remove('border-blue-500');
        circle.classList.add('border-green-500', 'bg-green-100');
        
        setTimeout(() => {
            circle.classList.remove('border-green-500', 'bg-green-100');
            circle.classList.add('border-blue-500');
        }, 500);
    }

    // Stop camera stream
    stopCamera() {
        const video = document.getElementById('faceVideo');
        if (video.srcObject) {
            video.srcObject.getTracks().forEach(track => track.stop());
            video.srcObject = null;
        }
    }

    // Submit verification request
    async submitVerification() {
        try {
            // Show loading
            document.getElementById('submitVerificationBtn').textContent = 'Submitting...';
            document.getElementById('submitVerificationBtn').disabled = true;

            const currentUser = JSON.parse(localStorage.getItem('currentUser'));
            
            // Submit verification with enhanced face data
            const result = await this.verification.submitVerificationRequest(
                currentUser.email,
                this.uploadedIDData,
                this.capturedFaceData
            );

            // Show success screen
            this.showSuccessScreen();
            
        } catch (error) {
            console.error('Verification submission error:', error);
            alert('Failed to submit verification. Please try again.');
            
            // Reset button
            document.getElementById('submitVerificationBtn').textContent = 'Submit Verification';
            document.getElementById('submitVerificationBtn').disabled = false;
        }
    }

    // Show success screen
    showSuccessScreen() {
        const content = document.getElementById('verificationContent');
        content.innerHTML = `
            <div class="text-center">
                <div class="mb-6">
                    <div class="bg-green-100 rounded-full p-4 w-16 h-16 mx-auto mb-4">
                        <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                        </svg>
                    </div>
                    <h3 class="text-xl font-semibold text-gray-800 mb-2">Verification Submitted!</h3>
                    <p class="text-gray-600 mb-4">Your verification request has been submitted successfully. We'll review your documents and notify you within 24-48 hours.</p>
                    <p class="text-sm text-gray-500">You'll receive an email confirmation once your verification is approved.</p>
                </div>
                
                <button id="closeModalBtn" class="modern-button">
                    Close
                </button>
            </div>
        `;

        document.getElementById('closeModalBtn').addEventListener('click', () => {
            this.closeModal();
            // Refresh page to show updated verification status
            window.location.reload();
        });
    }

    // Show verification modal
    showModal() {
        document.getElementById('verificationModal').style.display = 'flex';
        this.showStartScreen();
    }

    // Close verification modal
    closeModal() {
        this.stopCamera();
        document.getElementById('verificationModal').style.display = 'none';
        
        // Reset state
        this.currentStep = 'start';
        this.uploadedIDData = null;
        this.capturedFaceData = null;
    }
}

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { VerificationSystem, VerificationUI };
}