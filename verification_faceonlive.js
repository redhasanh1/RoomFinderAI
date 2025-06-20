// FaceOnLive ID-Verification-OpenKYC Integration for RoomFinderAI
class FaceOnLiveVerification {
    constructor(supabaseClient, config = {}) {
        this.supabase = supabaseClient;
        this.config = {
            apiKey: config.apiKey || process.env.FACEONLIVE_API_KEY,
            baseUrl: config.baseUrl || 'https://api.faceonlive.com/v1',
            timeout: config.timeout || 30000,
            ...config
        };
        this.sessionId = null;
        this.initialized = false;
    }

    // Initialize FaceOnLive SDK
    async initialize() {
        try {
            if (!this.config.apiKey) {
                throw new Error('FaceOnLive API key is required');
            }

            // Load FaceOnLive SDK
            await this.loadFaceOnLiveSDK();
            
            // Initialize session
            this.sessionId = await this.createVerificationSession();
            this.initialized = true;
            
            return true;
        } catch (error) {
            console.error('FaceOnLive initialization failed:', error);
            throw error;
        }
    }

    // Load FaceOnLive SDK
    async loadFaceOnLiveSDK() {
        return new Promise((resolve, reject) => {
            // Check if SDK is already loaded
            if (window.FaceOnLiveSDK) {
                resolve();
                return;
            }

            const script = document.createElement('script');
            script.src = 'https://cdn.faceonlive.com/sdk/v1/faceonlive-sdk.min.js';
            script.onload = () => {
                if (window.FaceOnLiveSDK) {
                    resolve();
                } else {
                    reject(new Error('FaceOnLive SDK failed to load'));
                }
            };
            script.onerror = () => reject(new Error('Failed to load FaceOnLive SDK'));
            document.head.appendChild(script);
        });
    }

    // Create verification session
    async createVerificationSession() {
        try {
            const response = await fetch(`${this.config.baseUrl}/verification/session`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.config.apiKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    verification_type: 'full_kyc',
                    liveness_check: true,
                    document_verification: true,
                    face_matching: true
                })
            });

            if (!response.ok) {
                throw new Error(`Session creation failed: ${response.statusText}`);
            }

            const data = await response.json();
            return data.session_id;
        } catch (error) {
            console.error('Session creation error:', error);
            throw error;
        }
    }

    // Start ID document verification
    async verifyIDDocument(documentFile, documentType = 'auto') {
        try {
            if (!this.initialized) {
                await this.initialize();
            }

            const formData = new FormData();
            formData.append('document', documentFile);
            formData.append('session_id', this.sessionId);
            formData.append('document_type', documentType);

            const response = await fetch(`${this.config.baseUrl}/verification/document`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.config.apiKey}`
                },
                body: formData
            });

            if (!response.ok) {
                throw new Error(`Document verification failed: ${response.statusText}`);
            }

            const result = await response.json();
            return {
                success: result.status === 'verified',
                documentData: result.document_data,
                confidence: result.confidence,
                extractedInfo: result.extracted_info,
                verificationId: result.verification_id
            };
        } catch (error) {
            console.error('Document verification error:', error);
            throw error;
        }
    }

    // Start face liveness detection
    async startFaceLivenessDetection() {
        try {
            if (!this.initialized) {
                await this.initialize();
            }

            // Initialize camera for liveness detection
            const stream = await navigator.mediaDevices.getUserMedia({
                video: {
                    width: { ideal: 1280 },
                    height: { ideal: 720 },
                    facingMode: 'user'
                }
            });

            return {
                stream,
                sessionId: this.sessionId
            };
        } catch (error) {
            console.error('Face liveness initialization error:', error);
            throw error;
        }
    }

    // Perform liveness check with guided instructions
    async performLivenessCheck(videoElement) {
        try {
            const livenessInstructions = [
                { action: 'look_center', instruction: 'Look directly at the camera', duration: 2000 },
                { action: 'blink', instruction: 'Blink naturally', duration: 1000 },
                { action: 'smile', instruction: 'Smile naturally', duration: 2000 },
                { action: 'turn_left', instruction: 'Turn your head slightly left', duration: 2000 },
                { action: 'turn_right', instruction: 'Turn your head slightly right', duration: 2000 },
                { action: 'look_center_final', instruction: 'Look directly at the camera again', duration: 2000 }
            ];

            const livenessResults = [];

            for (const step of livenessInstructions) {
                const result = await this.performLivenessStep(videoElement, step);
                livenessResults.push(result);
                
                if (!result.success) {
                    throw new Error(`Liveness check failed at step: ${step.action}`);
                }
            }

            return {
                success: true,
                livenessScore: this.calculateLivenessScore(livenessResults),
                steps: livenessResults
            };
        } catch (error) {
            console.error('Liveness check error:', error);
            throw error;
        }
    }

    // Perform individual liveness step
    async performLivenessStep(videoElement, step) {
        return new Promise((resolve) => {
            const canvas = document.createElement('canvas');
            const context = canvas.getContext('2d');
            
            canvas.width = videoElement.videoWidth;
            canvas.height = videoElement.videoHeight;
            
            // Capture frame
            context.drawImage(videoElement, 0, 0, canvas.width, canvas.height);
            
            // Convert to blob and send for analysis
            canvas.toBlob(async (blob) => {
                try {
                    const result = await this.analyzeLivenessFrame(blob, step.action);
                    resolve({
                        success: result.is_live,
                        action: step.action,
                        confidence: result.confidence,
                        timestamp: new Date().toISOString()
                    });
                } catch (error) {
                    resolve({
                        success: false,
                        action: step.action,
                        error: error.message,
                        timestamp: new Date().toISOString()
                    });
                }
            }, 'image/jpeg', 0.8);
        });
    }

    // Analyze frame for liveness
    async analyzeLivenessFrame(frameBlob, action) {
        try {
            const formData = new FormData();
            formData.append('frame', frameBlob);
            formData.append('session_id', this.sessionId);
            formData.append('action', action);

            const response = await fetch(`${this.config.baseUrl}/verification/liveness`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.config.apiKey}`
                },
                body: formData
            });

            if (!response.ok) {
                throw new Error(`Liveness analysis failed: ${response.statusText}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Liveness analysis error:', error);
            throw error;
        }
    }

    // Perform face matching between selfie and ID
    async performFaceMatching(selfieBlob, idDocumentData) {
        try {
            const formData = new FormData();
            formData.append('selfie', selfieBlob);
            formData.append('session_id', this.sessionId);
            formData.append('document_verification_id', idDocumentData.verificationId);

            const response = await fetch(`${this.config.baseUrl}/verification/face-match`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.config.apiKey}`
                },
                body: formData
            });

            if (!response.ok) {
                throw new Error(`Face matching failed: ${response.statusText}`);
            }

            const result = await response.json();
            return {
                success: result.match,
                confidence: result.confidence,
                similarityScore: result.similarity_score,
                matchingId: result.matching_id
            };
        } catch (error) {
            console.error('Face matching error:', error);
            throw error;
        }
    }

    // Calculate overall liveness score
    calculateLivenessScore(livenessResults) {
        const successfulSteps = livenessResults.filter(step => step.success);
        const totalConfidence = successfulSteps.reduce((sum, step) => sum + (step.confidence || 0), 0);
        
        return {
            overallScore: totalConfidence / successfulSteps.length,
            stepsCompleted: successfulSteps.length,
            totalSteps: livenessResults.length,
            passRate: (successfulSteps.length / livenessResults.length) * 100
        };
    }

    // Complete verification process
    async completeVerification(documentResult, livenessResult, faceMatchResult) {
        try {
            const verificationData = {
                session_id: this.sessionId,
                document_verification: documentResult,
                liveness_verification: livenessResult,
                face_matching: faceMatchResult,
                completed_at: new Date().toISOString()
            };

            const response = await fetch(`${this.config.baseUrl}/verification/complete`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.config.apiKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(verificationData)
            });

            if (!response.ok) {
                throw new Error(`Verification completion failed: ${response.statusText}`);
            }

            const result = await response.json();
            return {
                verificationId: result.verification_id,
                status: result.status,
                overallScore: result.overall_score,
                report: result.verification_report
            };
        } catch (error) {
            console.error('Verification completion error:', error);
            throw error;
        }
    }

    // Get verification status
    async getVerificationStatus(verificationId) {
        try {
            const response = await fetch(`${this.config.baseUrl}/verification/status/${verificationId}`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${this.config.apiKey}`
                }
            });

            if (!response.ok) {
                throw new Error(`Status check failed: ${response.statusText}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Status check error:', error);
            throw error;
        }
    }

    // Cleanup resources
    cleanup() {
        this.sessionId = null;
        this.initialized = false;
    }
}

// FaceOnLive Verification UI Component
class FaceOnLiveVerificationUI {
    constructor(verificationSystem) {
        this.verification = verificationSystem;
        this.currentStep = 'document';
        this.documentResult = null;
        this.livenessResult = null;
        this.faceMatchResult = null;
        this.currentLivenessStep = 0;
    }

    // Create FaceOnLive verification modal
    createVerificationModal() {
        const modal = document.createElement('div');
        modal.id = 'faceOnLiveModal';
        modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
        modal.style.display = 'none';

        modal.innerHTML = `
            <div class="bg-white rounded-2xl p-8 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
                <div class="flex justify-between items-center mb-6">
                    <h2 class="text-2xl font-bold text-gray-800">Professional ID Verification</h2>
                    <button id="closeFaceOnLiveModal" class="text-gray-500 hover:text-gray-700">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                        </svg>
                    </button>
                </div>
                
                <div id="faceOnLiveContent">
                    <!-- Dynamic content will be inserted here -->
                </div>
            </div>
        `;

        return modal;
    }

    // Show modal and start verification
    async showModal() {
        document.getElementById('faceOnLiveModal').style.display = 'flex';
        await this.showWelcomeScreen();
    }

    // Close modal
    closeModal() {
        document.getElementById('faceOnLiveModal').style.display = 'none';
        this.verification.cleanup();
    }

    // Show welcome screen
    async showWelcomeScreen() {
        const content = document.getElementById('faceOnLiveContent');
        content.innerHTML = `
            <div class="text-center">
                <div class="mb-6">
                    <div class="bg-blue-100 rounded-full p-4 w-16 h-16 mx-auto mb-4">
                        <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.5-2a8.5 8.5 0 11-17 0 8.5 8.5 0 0117 0z"></path>
                        </svg>
                    </div>
                    <h3 class="text-xl font-semibold text-gray-800 mb-2">Professional AI-Powered Verification</h3>
                    <p class="text-gray-600">Advanced biometric security with 99.9% accuracy</p>
                </div>
                
                <div class="space-y-4 mb-8">
                    <div class="flex items-center text-left">
                        <div class="bg-green-100 rounded-full p-2 mr-4">
                            <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                            </svg>
                        </div>
                        <span class="text-gray-700">AI-powered document verification (10,000+ ID types)</span>
                    </div>
                    <div class="flex items-center text-left">
                        <div class="bg-green-100 rounded-full p-2 mr-4">
                            <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                            </svg>
                        </div>
                        <span class="text-gray-700">Advanced liveness detection with anti-spoofing</span>
                    </div>
                    <div class="flex items-center text-left">
                        <div class="bg-green-100 rounded-full p-2 mr-4">
                            <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                            </svg>
                        </div>
                        <span class="text-gray-700">Secure face-to-ID matching technology</span>
                    </div>
                </div>
                
                <button id="startFaceOnLiveBtn" class="modern-button w-full">
                    Start Professional Verification
                </button>
            </div>
        `;

        document.getElementById('startFaceOnLiveBtn').addEventListener('click', async () => {
            await this.initializeAndStart();
        });
    }

    // Initialize and start verification process
    async initializeAndStart() {
        try {
            const content = document.getElementById('faceOnLiveContent');
            content.innerHTML = '<div class="text-center"><p class="text-blue-600">Initializing verification system...</p></div>';
            
            await this.verification.initialize();
            this.showDocumentUpload();
        } catch (error) {
            console.error('Initialization error:', error);
            alert('Failed to initialize verification system. Please try again.');
        }
    }

    // Show document upload screen
    showDocumentUpload() {
        const content = document.getElementById('faceOnLiveContent');
        content.innerHTML = `
            <div>
                <div class="mb-6">
                    <h3 class="text-xl font-semibold text-gray-800 mb-2">Upload Government ID</h3>
                    <p class="text-gray-600">Upload a clear photo of your government-issued ID document.</p>
                </div>
                
                <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center mb-6">
                    <div id="documentUploadArea">
                        <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
                        </svg>
                        <p class="text-gray-600 mb-4">Click to upload or drag and drop</p>
                        <p class="text-sm text-gray-500">Supports: Driver's License, Passport, National ID</p>
                        <input type="file" id="documentInput" class="hidden" accept="image/*">
                        <button id="selectDocumentBtn" class="mt-4 bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition">
                            Select Document
                        </button>
                    </div>
                </div>
                
                <div class="text-center">
                    <button id="backToWelcome" class="bg-gray-300 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-400 transition">
                        Back
                    </button>
                </div>
            </div>
        `;

        this.setupDocumentUploadListeners();
    }

    // Setup document upload event listeners
    setupDocumentUploadListeners() {
        document.getElementById('selectDocumentBtn').addEventListener('click', () => {
            document.getElementById('documentInput').click();
        });

        document.getElementById('documentInput').addEventListener('change', async (e) => {
            await this.handleDocumentUpload(e.target.files[0]);
        });

        document.getElementById('backToWelcome').addEventListener('click', () => {
            this.showWelcomeScreen();
        });
    }

    // Handle document upload and verification
    async handleDocumentUpload(file) {
        if (!file) return;

        try {
            document.getElementById('documentUploadArea').innerHTML = '<p class="text-blue-600">Verifying document...</p>';
            
            this.documentResult = await this.verification.verifyIDDocument(file);
            
            if (this.documentResult.success) {
                this.showLivenessDetection();
            } else {
                alert('Document verification failed. Please upload a clear, valid government ID.');
                this.showDocumentUpload();
            }
        } catch (error) {
            console.error('Document upload error:', error);
            alert('Failed to verify document. Please try again.');
            this.showDocumentUpload();
        }
    }

    // Show liveness detection screen
    async showLivenessDetection() {
        const content = document.getElementById('faceOnLiveContent');
        content.innerHTML = `
            <div>
                <div class="mb-6">
                    <h3 class="text-xl font-semibold text-gray-800 mb-2">Face Liveness Verification</h3>
                    <p class="text-gray-600">Follow the instructions to complete liveness detection.</p>
                </div>
                
                <div class="relative mb-6">
                    <video id="livenessVideo" class="w-full max-w-md mx-auto rounded-lg bg-gray-200" autoplay playsinline></video>
                    <div id="livenessInstructions" class="absolute bottom-4 left-0 right-0 text-center">
                        <div class="bg-black bg-opacity-75 text-white px-4 py-2 rounded-lg inline-block">
                            <span id="instructionText">Preparing camera...</span>
                        </div>
                    </div>
                </div>
                
                <div class="text-center mb-4">
                    <button id="startLivenessBtn" class="modern-button">
                        Start Liveness Check
                    </button>
                </div>
            </div>
        `;

        await this.initializeLivenessCamera();
    }

    // Initialize liveness camera
    async initializeLivenessCamera() {
        try {
            const video = document.getElementById('livenessVideo');
            const cameraData = await this.verification.startFaceLivenessDetection();
            video.srcObject = cameraData.stream;
            video.play();

            document.getElementById('startLivenessBtn').addEventListener('click', async () => {
                await this.performLivenessCheck();
            });

            document.getElementById('instructionText').textContent = 'Camera ready. Click "Start Liveness Check" when ready.';
        } catch (error) {
            console.error('Camera initialization error:', error);
            alert('Unable to access camera. Please ensure camera permissions are granted.');
        }
    }

    // Perform complete liveness check
    async performLivenessCheck() {
        try {
            const video = document.getElementById('livenessVideo');
            document.getElementById('startLivenessBtn').style.display = 'none';
            
            this.livenessResult = await this.verification.performLivenessCheck(video);
            
            if (this.livenessResult.success) {
                await this.performFaceMatching();
            } else {
                alert('Liveness check failed. Please try again.');
                this.showLivenessDetection();
            }
        } catch (error) {
            console.error('Liveness check error:', error);
            alert('Liveness verification failed. Please try again.');
        }
    }

    // Perform face matching
    async performFaceMatching() {
        try {
            document.getElementById('instructionText').textContent = 'Performing face matching...';
            
            // Capture final selfie for matching
            const video = document.getElementById('livenessVideo');
            const canvas = document.createElement('canvas');
            const context = canvas.getContext('2d');
            
            canvas.width = video.videoWidth;
            canvas.height = video.videoHeight;
            context.drawImage(video, 0, 0, canvas.width, canvas.height);
            
            canvas.toBlob(async (blob) => {
                this.faceMatchResult = await this.verification.performFaceMatching(blob, this.documentResult);
                
                if (this.faceMatchResult.success) {
                    await this.completeVerification();
                } else {
                    alert('Face matching failed. Please ensure your face matches the ID photo.');
                    this.showLivenessDetection();
                }
            }, 'image/jpeg', 0.8);
        } catch (error) {
            console.error('Face matching error:', error);
            alert('Face matching failed. Please try again.');
        }
    }

    // Complete verification process
    async completeVerification() {
        try {
            const finalResult = await this.verification.completeVerification(
                this.documentResult,
                this.livenessResult,
                this.faceMatchResult
            );

            this.showSuccessScreen(finalResult);
        } catch (error) {
            console.error('Verification completion error:', error);
            alert('Failed to complete verification. Please try again.');
        }
    }

    // Show success screen
    showSuccessScreen(result) {
        const content = document.getElementById('faceOnLiveContent');
        content.innerHTML = `
            <div class="text-center">
                <div class="mb-6">
                    <div class="bg-green-100 rounded-full p-4 w-16 h-16 mx-auto mb-4">
                        <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                        </svg>
                    </div>
                    <h3 class="text-xl font-semibold text-gray-800 mb-2">Verification Complete!</h3>
                    <p class="text-gray-600 mb-4">Your identity has been successfully verified with ${result.overallScore}% confidence.</p>
                    <p class="text-sm text-gray-500">Verification ID: ${result.verificationId}</p>
                </div>
                
                <button id="closeFinalBtn" class="modern-button">
                    Complete
                </button>
            </div>
        `;

        document.getElementById('closeFinalBtn').addEventListener('click', () => {
            this.closeModal();
            // Refresh to show verification status
            window.location.reload();
        });
    }
}

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { FaceOnLiveVerification, FaceOnLiveVerificationUI };
}