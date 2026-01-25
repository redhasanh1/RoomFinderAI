/**
 * Report Handler Module
 * Quick reporting system for inappropriate content, users, listings, and messages
 */

class ReportHandler {
    constructor() {
        this.supabase = window.supabase;
        this.currentUser = null;
        this.initializeUser();
    }

    async initializeUser() {
        try {
            const { data: { user } } = await this.supabase.auth.getUser();
            this.currentUser = user;
        } catch (error) {
            console.error('Error initializing user:', error);
        }
    }

    /**
     * Show quick report modal
     * @param {Object} options - Report options {type, targetId, targetEmail, targetUrl}
     */
    showReportModal(options) {
        const { type, targetId, targetEmail, targetUrl } = options;

        const modal = document.createElement('div');
        modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4';
        modal.innerHTML = `
            <div class="bg-white rounded-2xl max-w-md w-full shadow-2xl transform transition-all">
                <div class="bg-gradient-to-r from-red-500 to-pink-500 text-white p-6 rounded-t-2xl">
                    <div class="flex items-center justify-between">
                        <div>
                            <div class="text-3xl mb-2">🚩</div>
                            <h2 class="text-2xl font-bold">Report ${this.getTypeLabel(type)}</h2>
                        </div>
                        <button class="text-white hover:text-gray-200 transition" onclick="this.closest('.fixed').remove()">
                            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="width" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                            </svg>
                        </button>
                    </div>
                </div>

                <div class="p-6 space-y-4">
                    <div>
                        <label class="block text-sm font-semibold text-gray-700 mb-2">Report Type</label>
                        <select id="reportType" class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent">
                            ${this.getReportTypeOptions(type)}
                        </select>
                    </div>

                    <div>
                        <label class="block text-sm font-semibold text-gray-700 mb-2">Description (Optional)</label>
                        <textarea id="reportDescription" rows="4" class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent resize-none" placeholder="Please provide additional details..."></textarea>
                        <p class="text-xs text-gray-500 mt-1">Help us understand the issue better</p>
                    </div>

                    <div class="bg-blue-50 border-l-4 border-blue-500 p-4 rounded">
                        <p class="text-sm text-blue-800">
                            <strong>What happens next:</strong> We review all reports within 24-48 hours. For urgent safety concerns, we respond immediately.
                        </p>
                    </div>

                    <div class="flex space-x-3">
                        <button onclick="this.closest('.fixed').remove()" class="flex-1 px-6 py-3 border border-gray-300 text-gray-700 rounded-lg font-semibold hover:bg-gray-50 transition">
                            Cancel
                        </button>
                        <button id="submitReportBtn" class="flex-1 px-6 py-3 bg-red-600 text-white rounded-lg font-semibold hover:bg-red-700 transition">
                            Submit Report
                        </button>
                    </div>

                    <div class="text-center">
                        <p class="text-sm text-gray-600">Need more formal resolution?</p>
                        <a href="file-dispute.html" class="text-indigo-600 hover:underline font-semibold text-sm">File a Full Dispute →</a>
                    </div>
                </div>
            </div>
        `;

        document.body.appendChild(modal);

        // Handle submit
        const submitBtn = modal.querySelector('#submitReportBtn');
        submitBtn.addEventListener('click', async () => {
            await this.submitReport(modal, {
                type,
                targetId,
                targetEmail,
                targetUrl
            });
        });

        // Close on background click
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.remove();
            }
        });
    }

    /**
     * Submit report to database
     */
    async submitReport(modal, options) {
        try {
            if (!this.currentUser) {
                alert('You must be logged in to report content');
                return;
            }

            const reportType = modal.querySelector('#reportType').value;
            const description = modal.querySelector('#reportDescription').value;
            const submitBtn = modal.querySelector('#submitReportBtn');

            // Disable button
            submitBtn.disabled = true;
            submitBtn.textContent = 'Submitting...';

            // Prepare report data
            const reportData = {
                reporter_email: this.currentUser.email,
                reported_user_email: options.targetEmail || null,
                report_type: reportType,
                description: description || null,
                status: 'pending'
            };

            // Add related IDs based on type
            if (options.type === 'listing') {
                reportData.related_listing_id = options.targetId;
            } else if (options.type === 'message') {
                reportData.related_message_id = options.targetId;
            }

            // Insert into user_reports table
            const { data, error } = await this.supabase
                .from('user_reports')
                .insert(reportData);

            if (error) throw error;

            // Show success
            modal.innerHTML = `
                <div class="bg-white rounded-2xl p-8 max-w-md w-full text-center">
                    <div class="text-6xl mb-4">✅</div>
                    <h2 class="text-2xl font-bold text-gray-900 mb-3">Report Submitted</h2>
                    <p class="text-gray-600 mb-6">
                        Thank you for helping keep RoomFinderAI safe. We'll review this report within 24-48 hours.
                    </p>
                    <button onclick="this.closest('.fixed').remove()" class="px-8 py-3 bg-indigo-600 text-white rounded-lg font-semibold hover:bg-indigo-700 transition">
                        Done
                    </button>
                </div>
            `;

            // Auto-close after 3 seconds
            setTimeout(() => {
                modal.remove();
            }, 3000);

        } catch (error) {
            console.error('Error submitting report:', error);
            alert('Error submitting report. Please try again or contact support.');

            const submitBtn = modal.querySelector('#submitReportBtn');
            if (submitBtn) {
                submitBtn.disabled = false;
                submitBtn.textContent = 'Submit Report';
            }
        }
    }

    /**
     * Get report type options based on context
     */
    getReportTypeOptions(contextType) {
        const allOptions = {
            listing: [
                { value: 'inappropriate_listing', label: 'Inappropriate/Fake Listing' },
                { value: 'spam', label: 'Spam' },
                { value: 'suspicious_activity', label: 'Scam or Suspicious Activity' },
                { value: 'other', label: 'Other' }
            ],
            user: [
                { value: 'fake_profile', label: 'Fake Profile' },
                { value: 'spam', label: 'Spam' },
                { value: 'suspicious_activity', label: 'Suspicious Activity' },
                { value: 'other', label: 'Other' }
            ],
            message: [
                { value: 'offensive_message', label: 'Offensive/Harassing Message' },
                { value: 'spam', label: 'Spam' },
                { value: 'suspicious_activity', label: 'Phishing or Scam' },
                { value: 'other', label: 'Other' }
            ]
        };

        const options = allOptions[contextType] || allOptions.listing;
        return options.map(opt =>
            `<option value="${opt.value}">${opt.label}</option>`
        ).join('');
    }

    /**
     * Get label for type
     */
    getTypeLabel(type) {
        const labels = {
            listing: 'Listing',
            user: 'User',
            message: 'Message',
            profile: 'Profile'
        };
        return labels[type] || 'Content';
    }

    /**
     * Add report button to an element
     * @param {HTMLElement} element - Element to add button to
     * @param {Object} options - Report options
     */
    addReportButton(element, options) {
        const button = document.createElement('button');
        button.className = 'text-gray-500 hover:text-red-600 transition flex items-center space-x-1 text-sm';
        button.innerHTML = `
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 21v-4m0 0V5a2 2 0 012-2h6.5l1 1H21l-3 6 3 6h-8.5l-1-1H5a2 2 0 00-2 2zm9-13.5V9"/>
            </svg>
            <span>Report</span>
        `;

        button.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            this.showReportModal(options);
        });

        element.appendChild(button);
    }
}

// Create global instance
window.reportHandler = new ReportHandler();

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ReportHandler;
}
