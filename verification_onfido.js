// Onfido Integration for Professional Identity Verification
// This file implements Onfido's identity verification and face biometric services

class OnfidoVerificationService {
    constructor(apiToken, region = 'eu') {
        this.apiToken = apiToken;
        this.baseUrl = region === 'us' 
            ? 'https://api.us.onfido.com/v3.6'
            : 'https://api.eu.onfido.com/v3.6';
        this.sdkLoaded = false;
    }

    // Load Onfido SDK
    async loadOnfidoSDK() {
        if (this.sdkLoaded) return;

        return new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = 'https://sdk.onfido.com/dist/onfido.min.js';
            script.onload = () => {
                this.sdkLoaded = true;
                resolve();
            };
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }

    // Create Onfido applicant
    async createApplicant(userData) {
        try {
            const response = await fetch(`${this.baseUrl}/applicants`, {
                method: 'POST',
                headers: {
                    'Authorization': `Token token=${this.apiToken}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    first_name: userData.firstName,
                    last_name: userData.lastName,
                    email: userData.email,
                    dob: userData.dateOfBirth, // YYYY-MM-DD format
                    address: {
                        street: userData.address?.street,
                        town: userData.address?.city,
                        state: userData.address?.state,
                        postcode: userData.address?.postalCode,
                        country: userData.address?.country || 'CAN'
                    }
                })
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(`Onfido API error: ${error.error?.message || 'Unknown error'}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Error creating Onfido applicant:', error);
            throw error;
        }
    }

    // Generate SDK token for frontend
    async generateSDKToken(applicantId) {
        try {
            const response = await fetch(`${this.baseUrl}/sdk_token`, {
                method: 'POST',
                headers: {
                    'Authorization': `Token token=${this.apiToken}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    applicant_id: applicantId,
                    referrer: window.location.origin
                })
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(`SDK token error: ${error.error?.message || 'Unknown error'}`);
            }

            const data = await response.json();
            return data.token;
        } catch (error) {
            console.error('Error generating SDK token:', error);
            throw error;
        }
    }

    // Initialize Onfido SDK flow
    async initializeVerificationFlow(applicantId, containerId) {
        try {
            await this.loadOnfidoSDK();
            const sdkToken = await this.generateSDKToken(applicantId);

            const onfidoOut = window.Onfido.init({
                token: sdkToken,
                containerId: containerId,
                steps: [
                    {
                        type: 'welcome',
                        options: {
                            title: 'Verify Your Identity',
                            descriptions: [
                                'We need to verify your identity to ensure platform safety',
                                'This process is secure and your data is protected',
                                'Verification typically takes 2-3 minutes'
                            ]
                        }
                    },
                    {
                        type: 'document',
                        options: {
                            documentTypes: {
                                passport: true,
                                driving_licence: {
                                    country: 'CAN'
                                },
                                national_identity_card: {
                                    country: 'CAN'
                                }
                            },
                            hideCountrySelection: false,
                            forceCrossDevice: false
                        }
                    },
                    {
                        type: 'face',
                        options: {
                            requestedVariant: 'standard', // or 'video'
                            uploadFallback: false
                        }
                    },
                    'complete'
                ],
                onComplete: (data) => {
                    console.log('Onfido verification completed:', data);
                    this.onVerificationComplete(data);
                },
                onError: (error) => {
                    console.error('Onfido verification error:', error);
                    this.onVerificationError(error);
                },
                onUserExit: (exitCode) => {
                    console.log('User exited Onfido flow:', exitCode);
                    this.onVerificationExit(exitCode);
                }
            });

            return onfidoOut;
        } catch (error) {
            console.error('Error initializing Onfido flow:', error);
            throw error;
        }
    }

    // Create verification check
    async createCheck(applicantId, reportTypes = ['document', 'facial_similarity_photo']) {
        try {
            const response = await fetch(`${this.baseUrl}/checks`, {
                method: 'POST',
                headers: {
                    'Authorization': `Token token=${this.apiToken}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    applicant_id: applicantId,
                    report_names: reportTypes,
                    suppress_form_emails: true,
                    asynchronous: false
                })
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(`Check creation error: ${error.error?.message || 'Unknown error'}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Error creating verification check:', error);
            throw error;
        }
    }

    // Get check results
    async getCheckResults(checkId) {
        try {
            const response = await fetch(`${this.baseUrl}/checks/${checkId}`, {
                method: 'GET',
                headers: {
                    'Authorization': `Token token=${this.apiToken}`
                }
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(`Check retrieval error: ${error.error?.message || 'Unknown error'}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Error getting check results:', error);
            throw error;
        }
    }

    // Webhook handler for Onfido events
    async handleWebhook(webhookData, signature, webhookSecret) {
        try {
            // Verify webhook signature
            const crypto = require('crypto');
            const expectedSignature = crypto
                .createHmac('sha256', webhookSecret)
                .update(JSON.stringify(webhookData))
                .digest('hex');

            if (signature !== expectedSignature) {
                throw new Error('Invalid webhook signature');
            }

            const { resource_type, action, object } = webhookData.payload;

            if (resource_type === 'check' && action === 'check.completed') {
                // Check completed - update verification status
                return await this.processCompletedCheck(object.id);
            }

            return { processed: true, type: resource_type, action };
        } catch (error) {
            console.error('Webhook processing error:', error);
            throw error;
        }
    }

    // Process completed verification check
    async processCompletedCheck(checkId) {
        try {
            const checkResults = await this.getCheckResults(checkId);
            
            // Determine verification status based on check results
            const isApproved = checkResults.result === 'clear';
            const status = isApproved ? 'approved' : 'rejected';
            
            // Extract rejection reasons if any
            const rejectionReasons = [];
            if (checkResults.reports) {
                checkResults.reports.forEach(report => {
                    if (report.result !== 'clear' && report.breakdown) {
                        Object.keys(report.breakdown).forEach(key => {
                            if (report.breakdown[key]?.result !== 'clear') {
                                rejectionReasons.push(`${report.name}: ${key}`);
                            }
                        });
                    }
                });
            }

            return {
                checkId,
                status,
                result: checkResults.result,
                reports: checkResults.reports,
                rejectionReasons: rejectionReasons.join(', '),
                completedAt: checkResults.completed_at,
                applicantId: checkResults.applicant_id
            };
        } catch (error) {
            console.error('Error processing completed check:', error);
            throw error;
        }
    }

    // Event handlers (to be overridden by implementing class)
    onVerificationComplete(data) {
        console.log('Verification completed:', data);
    }

    onVerificationError(error) {
        console.error('Verification error:', error);
    }

    onVerificationExit(exitCode) {
        console.log('Verification exited:', exitCode);
    }
}

// Integration with existing verification system
class EnhancedVerificationSystem extends VerificationSystem {
    constructor(supabaseClient, onfidoApiToken, onfidoRegion = 'eu') {
        super(supabaseClient);
        this.onfido = new OnfidoVerificationService(onfidoApiToken, onfidoRegion);
    }

    // Start Onfido verification process
    async startOnfidoVerification(userData, containerId) {
        try {
            // Create Onfido applicant
            const applicant = await this.onfido.createApplicant(userData);
            
            // Initialize verification flow
            const onfidoFlow = await this.onfido.initializeVerificationFlow(
                applicant.id, 
                containerId
            );

            // Override completion handler
            this.onfido.onVerificationComplete = async (data) => {
                await this.handleOnfidoCompletion(applicant.id, data);
            };

            return {
                applicantId: applicant.id,
                onfidoFlow
            };
        } catch (error) {
            console.error('Error starting Onfido verification:', error);
            throw error;
        }
    }

    // Handle Onfido completion
    async handleOnfidoCompletion(applicantId, completionData) {
        try {
            // Create verification check
            const check = await this.onfido.createCheck(applicantId);
            
            // Submit verification record to database
            const currentUser = JSON.parse(localStorage.getItem('currentUser'));
            
            const verificationData = {
                user_email: currentUser.email,
                verification_status: 'pending',
                onfido_check_id: check.id,
                third_party_verification_data: {
                    applicant_id: applicantId,
                    check_id: check.id,
                    completion_data: completionData,
                    provider: 'onfido'
                },
                ip_address: await this.getUserIP(),
                user_agent: navigator.userAgent
            };

            const response = await fetch('http://localhost:3000/api/verification/submit', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(verificationData)
            });

            if (!response.ok) {
                throw new Error('Failed to submit verification to database');
            }

            return await response.json();
        } catch (error) {
            console.error('Error handling Onfido completion:', error);
            throw error;
        }
    }
}

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { OnfidoVerificationService, EnhancedVerificationSystem };
}