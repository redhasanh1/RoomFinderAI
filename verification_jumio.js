// Jumio Integration for Professional Identity Verification
// This file implements Jumio's identity verification and biometric services

class JumioVerificationService {
    constructor(apiToken, apiSecret, environment = 'production') {
        this.apiToken = apiToken;
        this.apiSecret = apiSecret;
        this.baseUrl = environment === 'production' 
            ? 'https://netverify.com/api/netverify/v2'
            : 'https://lon.netverify.com/api/netverify/v2';
        this.webBaseUrl = environment === 'production'
            ? 'https://netverify.com/widget/v2'
            : 'https://lon.netverify.com/widget/v2';
    }

    // Generate authentication header
    getAuthHeader() {
        const credentials = btoa(`${this.apiToken}:${this.apiSecret}`);
        return `Basic ${credentials}`;
    }

    // Initialize Jumio Web SDK
    async initializeWebSDK(userData, containerId) {
        try {
            // Create scan session
            const scanSession = await this.createScanSession(userData);
            
            // Load Jumio Web SDK
            await this.loadJumioSDK();
            
            // Initialize Jumio widget
            const jumioWidget = new window.Jumio({
                authorizationToken: scanSession.authorizationToken,
                locale: 'en',
                successUrl: `${window.location.origin}/verification-success`,
                errorUrl: `${window.location.origin}/verification-error`,
                callbackUrl: `${window.location.origin}/api/jumio/callback`,
                
                // Verification settings
                presets: {
                    index: 1,
                    initiate: {
                        workflowDefinition: {
                            key: 1,
                            credentials: [
                                {
                                    category: 'ID',
                                    type: {
                                        values: ['DRIVING_LICENSE', 'PASSPORT', 'ID_CARD']
                                    },
                                    country: {
                                        predefinedValues: ['CAN', 'USA']
                                    }
                                }
                            ],
                            capabilities: [
                                'extraction',
                                'imageChecks',
                                'watchlistScreening',
                                'faceComparison'
                            ]
                        }
                    }
                }
            });

            // Event handlers
            jumioWidget.on('loaded', () => {
                console.log('Jumio widget loaded successfully');
            });

            jumioWidget.on('userClosed', (data) => {
                console.log('User closed Jumio widget:', data);
                this.onVerificationExit(data);
            });

            jumioWidget.on('error', (error) => {
                console.error('Jumio widget error:', error);
                this.onVerificationError(error);
            });

            // Render widget
            jumioWidget.render(containerId);

            return {
                scanReference: scanSession.scanReference,
                widget: jumioWidget
            };
        } catch (error) {
            console.error('Error initializing Jumio Web SDK:', error);
            throw error;
        }
    }

    // Load Jumio SDK
    async loadJumioSDK() {
        return new Promise((resolve, reject) => {
            if (window.Jumio) {
                resolve();
                return;
            }

            const script = document.createElement('script');
            script.src = `${this.webBaseUrl}/initiate.js`;
            script.onload = resolve;
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }

    // Create scan session
    async createScanSession(userData) {
        try {
            const requestBody = {
                customerInternalReference: userData.email,
                userReference: userData.email,
                workflowDefinition: {
                    key: 1,
                    credentials: [
                        {
                            category: 'ID',
                            type: {
                                values: ['DRIVING_LICENSE', 'PASSPORT', 'ID_CARD']
                            },
                            country: {
                                predefinedValues: ['CAN', 'USA']
                            }
                        }
                    ],
                    capabilities: [
                        'extraction',
                        'imageChecks',
                        'watchlistScreening',
                        'faceComparison'
                    ]
                },
                web: {
                    successUrl: `${window.location.origin}/verification-success`,
                    errorUrl: `${window.location.origin}/verification-error`,
                    locale: 'en'
                }
            };

            const response = await fetch(`${this.baseUrl}/initiateNetverify`, {
                method: 'POST',
                headers: {
                    'Authorization': this.getAuthHeader(),
                    'Content-Type': 'application/json',
                    'User-Agent': 'RoomFinderAI Verification/1.0'
                },
                body: JSON.stringify(requestBody)
            });

            if (!response.ok) {
                const error = await response.text();
                throw new Error(`Jumio session creation failed: ${error}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Error creating Jumio scan session:', error);
            throw error;
        }
    }

    // Get scan details
    async getScanDetails(scanReference) {
        try {
            const response = await fetch(`${this.baseUrl}/scans/${scanReference}`, {
                method: 'GET',
                headers: {
                    'Authorization': this.getAuthHeader(),
                    'User-Agent': 'RoomFinderAI Verification/1.0'
                }
            });

            if (!response.ok) {
                const error = await response.text();
                throw new Error(`Failed to get scan details: ${error}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Error getting scan details:', error);
            throw error;
        }
    }

    // Process Jumio callback
    async processCallback(callbackData) {
        try {
            const { scanReference, verificationStatus, idScanStatus } = callbackData;
            
            // Get detailed scan results
            const scanDetails = await this.getScanDetails(scanReference);
            
            // Determine overall verification status
            const isApproved = verificationStatus === 'APPROVED_VERIFIED' && 
                             idScanStatus === 'SUCCESS';
            
            const status = isApproved ? 'approved' : 'rejected';
            
            // Extract rejection reasons
            const rejectionReasons = [];
            if (!isApproved) {
                if (callbackData.rejectReason) {
                    rejectionReasons.push(callbackData.rejectReason.detailsCode);
                }
                if (callbackData.idScanRejectReason) {
                    rejectionReasons.push(callbackData.idScanRejectReason.detailsCode);
                }
            }

            return {
                scanReference,
                status,
                verificationStatus,
                idScanStatus,
                scanDetails,
                rejectionReasons: rejectionReasons.join(', '),
                completedAt: callbackData.callbackDate
            };
        } catch (error) {
            console.error('Error processing Jumio callback:', error);
            throw error;
        }
    }

    // Event handlers (to be overridden)
    onVerificationComplete(data) {
        console.log('Jumio verification completed:', data);
    }

    onVerificationError(error) {
        console.error('Jumio verification error:', error);
    }

    onVerificationExit(data) {
        console.log('Jumio verification exited:', data);
    }
}

// Integration with existing verification system
class JumioEnhancedVerificationSystem extends VerificationSystem {
    constructor(supabaseClient, jumioApiToken, jumioApiSecret, environment = 'production') {
        super(supabaseClient);
        this.jumio = new JumioVerificationService(jumioApiToken, jumioApiSecret, environment);
    }

    // Start Jumio verification process
    async startJumioVerification(userData, containerId) {
        try {
            // Initialize Jumio Web SDK
            const result = await this.jumio.initializeWebSDK(userData, containerId);
            
            // Store scan reference for later use
            this.currentScanReference = result.scanReference;
            
            return result;
        } catch (error) {
            console.error('Error starting Jumio verification:', error);
            throw error;
        }
    }

    // Handle Jumio completion (called from webhook)
    async handleJumioCompletion(callbackData) {
        try {
            // Process callback data
            const processedData = await this.jumio.processCallback(callbackData);
            
            // Update verification status in database
            const verificationData = {
                verification_status: processedData.status,
                jumio_scan_reference: processedData.scanReference,
                third_party_verification_data: {
                    scan_reference: processedData.scanReference,
                    verification_status: processedData.verificationStatus,
                    id_scan_status: processedData.idScanStatus,
                    scan_details: processedData.scanDetails,
                    provider: 'jumio'
                },
                processed_at: new Date().toISOString(),
                verified_at: processedData.status === 'approved' ? new Date().toISOString() : null,
                rejection_reason: processedData.rejectionReasons || null
            };

            return verificationData;
        } catch (error) {
            console.error('Error handling Jumio completion:', error);
            throw error;
        }
    }
}

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { JumioVerificationService, JumioEnhancedVerificationSystem };
}