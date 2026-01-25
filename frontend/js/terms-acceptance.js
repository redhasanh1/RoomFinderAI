/**
 * Terms Acceptance Tracking Module
 * Logs user acceptance of legal documents with IP/user agent for legal defensibility
 */

class TermsAcceptanceManager {
    constructor() {
        this.supabase = window.supabase;
        this.currentUser = null;
        this.initializeUser();
    }

    /**
     * Initialize current user from authentication
     */
    async initializeUser() {
        try {
            const { data: { user } } = await this.supabase.auth.getUser();
            this.currentUser = user;
        } catch (error) {
            console.error('Error initializing user:', error);
        }
    }

    /**
     * Get client IP address (best effort)
     */
    async getClientIP() {
        try {
            const response = await fetch('https://api.ipify.org?format=json');
            const data = await response.json();
            return data.ip;
        } catch (error) {
            console.warn('Could not fetch IP address:', error);
            return null;
        }
    }

    /**
     * Get user agent string
     */
    getUserAgent() {
        return navigator.userAgent;
    }

    /**
     * Log acceptance of a legal document
     * @param {string} documentType - Type of document (e.g., 'terms_of_service', 'privacy_policy')
     * @param {string} version - Version number of the document
     * @param {string} userEmail - Email of the user accepting (optional if logged in)
     */
    async logAcceptance(documentType, version, userEmail = null) {
        try {
            // Ensure user is set
            if (!this.currentUser && !userEmail) {
                throw new Error('User not authenticated and no email provided');
            }

            const email = userEmail || this.currentUser?.email;

            // Get IP and user agent
            const [ipAddress, userAgent] = await Promise.all([
                this.getClientIP(),
                Promise.resolve(this.getUserAgent())
            ]);

            // Insert into terms_acceptance table
            const { data, error } = await this.supabase
                .from('terms_acceptance')
                .insert({
                    user_email: email,
                    document_type: documentType,
                    version: version,
                    ip_address: ipAddress,
                    user_agent: userAgent,
                    accepted_at: new Date().toISOString()
                });

            if (error) throw error;

            console.log(`Terms acceptance logged: ${documentType} v${version} for ${email}`);
            return { success: true, data };
        } catch (error) {
            console.error('Error logging terms acceptance:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Log multiple acceptances at once (e.g., during signup)
     * @param {Array} documents - Array of {type, version} objects
     * @param {string} userEmail - Email of the user accepting
     */
    async logMultipleAcceptances(documents, userEmail = null) {
        try {
            const email = userEmail || this.currentUser?.email;
            if (!email) {
                throw new Error('User email required');
            }

            // Get IP and user agent once
            const [ipAddress, userAgent] = await Promise.all([
                this.getClientIP(),
                Promise.resolve(this.getUserAgent())
            ]);

            // Prepare all records
            const records = documents.map(doc => ({
                user_email: email,
                document_type: doc.type,
                version: doc.version,
                ip_address: ipAddress,
                user_agent: userAgent,
                accepted_at: new Date().toISOString()
            }));

            // Bulk insert
            const { data, error } = await this.supabase
                .from('terms_acceptance')
                .insert(records);

            if (error) throw error;

            console.log(`Logged ${documents.length} terms acceptances for ${email}`);
            return { success: true, data };
        } catch (error) {
            console.error('Error logging multiple acceptances:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Check if user has accepted a specific document version
     * @param {string} documentType - Type of document
     * @param {string} version - Version to check
     * @param {string} userEmail - Email to check (optional if logged in)
     */
    async hasAccepted(documentType, version, userEmail = null) {
        try {
            const email = userEmail || this.currentUser?.email;
            if (!email) return false;

            const { data, error } = await this.supabase
                .from('terms_acceptance')
                .select('*')
                .eq('user_email', email)
                .eq('document_type', documentType)
                .eq('version', version)
                .maybeSingle();

            if (error) throw error;

            return !!data; // Returns true if record exists
        } catch (error) {
            console.error('Error checking acceptance:', error);
            return false;
        }
    }

    /**
     * Get all acceptances for a user
     * @param {string} userEmail - Email to query (optional if logged in)
     */
    async getUserAcceptances(userEmail = null) {
        try {
            const email = userEmail || this.currentUser?.email;
            if (!email) {
                throw new Error('User email required');
            }

            const { data, error } = await this.supabase
                .from('terms_acceptance')
                .select('*')
                .eq('user_email', email)
                .order('accepted_at', { ascending: false });

            if (error) throw error;

            return { success: true, data };
        } catch (error) {
            console.error('Error fetching user acceptances:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Prompt user to accept updated terms
     * @param {string} documentType - Type of document updated
     * @param {string} newVersion - New version number
     * @param {string} documentUrl - URL to the document
     */
    async promptReacceptance(documentType, newVersion, documentUrl) {
        // Check if already accepted new version
        const hasAccepted = await this.hasAccepted(documentType, newVersion);
        if (hasAccepted) return;

        // Show modal prompting re-acceptance
        const modal = document.createElement('div');
        modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
        modal.innerHTML = `
            <div class="bg-white rounded-2xl p-8 max-w-md mx-4 shadow-2xl">
                <div class="text-center mb-6">
                    <div class="text-5xl mb-3">📄</div>
                    <h2 class="text-2xl font-bold text-gray-900 mb-2">Updated Terms</h2>
                    <p class="text-gray-600">We've updated our ${this.formatDocumentName(documentType)}.</p>
                </div>
                <p class="text-sm text-gray-700 mb-6">
                    To continue using RoomFinderAI, please review and accept the updated terms (Version ${newVersion}).
                </p>
                <div class="space-y-3">
                    <a href="${documentUrl}" target="_blank" class="block w-full px-6 py-3 bg-indigo-600 text-white rounded-lg font-semibold text-center hover:bg-indigo-700 transition">
                        Review Updated Terms →
                    </a>
                    <label class="flex items-start space-x-3 cursor-pointer">
                        <input type="checkbox" id="termsAcceptCheckbox" class="mt-1">
                        <span class="text-sm text-gray-700">I have read and agree to the updated ${this.formatDocumentName(documentType)}</span>
                    </label>
                    <button id="acceptTermsBtn" disabled class="w-full px-6 py-3 bg-gray-300 text-gray-500 rounded-lg font-semibold cursor-not-allowed">
                        Accept & Continue
                    </button>
                </div>
            </div>
        `;

        document.body.appendChild(modal);

        // Enable button when checkbox checked
        const checkbox = modal.querySelector('#termsAcceptCheckbox');
        const button = modal.querySelector('#acceptTermsBtn');

        checkbox.addEventListener('change', () => {
            if (checkbox.checked) {
                button.disabled = false;
                button.className = 'w-full px-6 py-3 bg-indigo-600 text-white rounded-lg font-semibold hover:bg-indigo-700 transition cursor-pointer';
            } else {
                button.disabled = true;
                button.className = 'w-full px-6 py-3 bg-gray-300 text-gray-500 rounded-lg font-semibold cursor-not-allowed';
            }
        });

        // Handle acceptance
        button.addEventListener('click', async () => {
            if (!checkbox.checked) return;

            button.textContent = 'Saving...';
            button.disabled = true;

            const result = await this.logAcceptance(documentType, newVersion);

            if (result.success) {
                modal.remove();
            } else {
                alert('Error saving acceptance. Please try again.');
                button.textContent = 'Accept & Continue';
                button.disabled = false;
            }
        });
    }

    /**
     * Format document type name for display
     */
    formatDocumentName(documentType) {
        const names = {
            'terms_of_service': 'Terms of Service',
            'privacy_policy': 'Privacy Policy',
            'acceptable_use': 'Acceptable Use Policy',
            'cookie_policy': 'Cookie Policy',
            'dispute_resolution': 'Dispute Resolution Policy',
            'landlord_responsibilities': 'Landlord Responsibilities',
            'ai_negotiation_disclaimer': 'AI Negotiation Disclaimer'
        };
        return names[documentType] || documentType.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
    }
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = TermsAcceptanceManager;
}

// Create global instance
window.termsAcceptance = new TermsAcceptanceManager();
