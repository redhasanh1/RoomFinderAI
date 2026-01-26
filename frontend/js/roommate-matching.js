// RoomPal - Simple Roommate Matching App
// Simplified, no-hassle platform to find roommates quickly

class RoomPalApp {
    constructor() {
        this.currentSection = 'selector';
        this.currentUser = null;
        this.userProfile = null;
        this.userGroup = null;
        this.api = null;
        this.currentSearchLocation = null;
        this.allSeekers = [];
        this.filteredSeekers = [];
        this.activeFilters = {
            budget: '',
            moveIn: '',
            activeOnly: false
        };

        // Popular cities for autocomplete
        this.popularCities = [
            { name: 'New York, USA', count: 234 },
            { name: 'London, UK', count: 189 },
            { name: 'Los Angeles, USA', count: 156 },
            { name: 'Tokyo, Japan', count: 142 },
            { name: 'San Francisco, USA', count: 128 },
            { name: 'Seattle, USA', count: 115 },
            { name: 'Paris, France', count: 98 },
            { name: 'Sydney, Australia', count: 87 },
            { name: 'Toronto, Canada', count: 76 },
            { name: 'Berlin, Germany', count: 65 },
            { name: 'Singapore', count: 54 },
            { name: 'Dubai, UAE', count: 48 },
            { name: 'Chicago, USA', count: 45 },
            { name: 'Boston, USA', count: 42 },
            { name: 'Amsterdam, Netherlands', count: 38 },
            { name: 'Melbourne, Australia', count: 35 },
            { name: 'Vancouver, Canada', count: 32 },
            { name: 'Austin, USA', count: 29 },
            { name: 'Denver, USA', count: 26 },
            { name: 'Portland, USA', count: 23 }
        ];

        this.init();
    }

    async init() {
        // Initialize API service
        if (typeof RoommateAPIService !== 'undefined') {
            this.api = new RoommateAPIService();
        }

        // Load current user from localStorage
        this.loadCurrentUser();

        // Update header to show user name if logged in
        this.updateHeader();

        // Setup event listeners
        this.setupEventListeners();

        // Setup worldwide search
        this.setupWorldwideSearch();

        // Setup profile completion tracking
        this.setupProfileCompletion();

        // Load initial data
        await this.loadPreviewData();

        console.log('RoomPal App initialized');
    }

    loadCurrentUser() {
        const stored = localStorage.getItem('currentUser');
        if (stored) {
            this.currentUser = JSON.parse(stored);
        }

        const storedProfile = localStorage.getItem('roommateProfile');
        if (storedProfile) {
            this.userProfile = JSON.parse(storedProfile);
        }

        const storedGroup = localStorage.getItem('roommateGroup');
        if (storedGroup) {
            this.userGroup = JSON.parse(storedGroup);
        }
    }

    updateHeader() {
        const desktopAuth = document.getElementById('desktopAuthSection');
        const mobileAuth = document.getElementById('mobileAuthLink');

        if (this.currentUser) {
            const userName = this.currentUser.firstName || this.currentUser.name || 'User';

            // Update desktop header
            if (desktopAuth) {
                desktopAuth.innerHTML = `
                    <div class="flex items-center gap-3">
                        <span class="text-gray-700">Hi, ${userName}</span>
                        <a href="profile.html" class="btn-secondary">Profile</a>
                    </div>
                `;
            }

            // Update mobile menu
            if (mobileAuth) {
                mobileAuth.textContent = `Hi, ${userName}`;
                mobileAuth.href = 'profile.html';
            }
        }
    }

    setupEventListeners() {
        // Tab switching
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.addEventListener('click', (e) => this.handleTabClick(e));
        });

        // Filter pills
        document.querySelectorAll('.filter-pill').forEach(pill => {
            pill.addEventListener('click', (e) => this.handleFilterClick(e));
        });

        // Seeker form submission
        const seekerForm = document.getElementById('seekerForm');
        if (seekerForm) {
            seekerForm.addEventListener('submit', (e) => this.handleSeekerFormSubmit(e));
        }

        // Compatibility form submission
        const compatibilityForm = document.getElementById('compatibilityForm');
        if (compatibilityForm) {
            compatibilityForm.addEventListener('submit', (e) => this.handleCompatibilitySubmit(e));
        }

        // Message form submission
        const messageForm = document.getElementById('messageForm');
        if (messageForm) {
            messageForm.addEventListener('submit', (e) => this.handleMessageSubmit(e));
        }

        // Photo upload handler
        const profilePhoto = document.getElementById('profilePhoto');
        if (profilePhoto) {
            profilePhoto.addEventListener('change', (e) => this.handlePhotoUpload(e));
        }
    }

    // ==================== WORLDWIDE SEARCH ====================

    setupWorldwideSearch() {
        const searchInput = document.getElementById('locationSearch');
        const suggestionsContainer = document.getElementById('searchSuggestions');

        if (!searchInput || !suggestionsContainer) return;

        // Handle input for autocomplete
        searchInput.addEventListener('input', (e) => {
            const query = e.target.value.toLowerCase().trim();

            if (query.length < 2) {
                suggestionsContainer.classList.remove('active');
                return;
            }

            const filtered = this.popularCities.filter(city =>
                city.name.toLowerCase().includes(query)
            ).slice(0, 6);

            if (filtered.length > 0) {
                suggestionsContainer.innerHTML = filtered.map(city => `
                    <div class="search-suggestion" onclick="roomPalApp.selectSearchLocation('${city.name}')">
                        <span class="flex items-center gap-2">
                            <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
                            </svg>
                            ${city.name}
                        </span>
                        <span class="search-count">${city.count} people</span>
                    </div>
                `).join('');
                suggestionsContainer.classList.add('active');
            } else {
                // Show "search any city" option
                suggestionsContainer.innerHTML = `
                    <div class="search-suggestion" onclick="roomPalApp.selectSearchLocation('${e.target.value}')">
                        <span class="flex items-center gap-2">
                            <svg class="w-4 h-4 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                            </svg>
                            Search for "${e.target.value}"
                        </span>
                    </div>
                `;
                suggestionsContainer.classList.add('active');
            }
        });

        // Handle enter key
        searchInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                this.selectSearchLocation(searchInput.value);
            }
        });

        // Close suggestions on click outside
        document.addEventListener('click', (e) => {
            if (!e.target.closest('.search-input-wrapper')) {
                suggestionsContainer.classList.remove('active');
            }
        });
    }

    selectSearchLocation(location) {
        if (!location.trim()) return;

        this.currentSearchLocation = location;
        const searchInput = document.getElementById('locationSearch');
        const suggestionsContainer = document.getElementById('searchSuggestions');

        if (searchInput) searchInput.value = location;
        if (suggestionsContainer) suggestionsContainer.classList.remove('active');

        // Update stats display
        const statsEl = document.getElementById('searchStats');
        if (statsEl) {
            const randomCount = Math.floor(Math.random() * 50) + 10;
            statsEl.innerHTML = `<span class="text-white font-medium">${randomCount} people looking in ${location}</span>`;
        }

        // Show browse sections with location filter
        this.showToast(`Searching in ${location}...`, 'info');

        // Navigate to appropriate section
        setTimeout(() => {
            this.showSection('browseSeekers');
            this.updateLocationLabels(location);
        }, 500);
    }

    updateLocationLabels(location) {
        const seekersLabel = document.getElementById('seekersLocationLabel');
        if (seekersLabel) seekersLabel.textContent = `in ${location}`;
    }

    // ==================== PROFILE COMPLETION ====================

    setupProfileCompletion() {
        const seekerForm = document.getElementById('seekerForm');
        if (!seekerForm) return;

        // Track form field changes
        const fields = seekerForm.querySelectorAll('input, textarea, select');
        fields.forEach(field => {
            field.addEventListener('input', () => this.updateProfileCompletion());
            field.addEventListener('change', () => this.updateProfileCompletion());
        });

        // Initial check
        this.updateProfileCompletion();
    }

    updateProfileCompletion() {
        const helper = document.getElementById('profileCompletionHelper');
        const percentEl = document.getElementById('completionPercent');
        const levelEl = document.getElementById('completionLevel');
        const fillEl = document.getElementById('completionProgressFill');
        const tipEl = document.getElementById('completionTip');

        if (!helper) return;

        // Calculate completion based on form fields
        const form = document.getElementById('seekerForm');
        if (!form) return;

        const checks = {
            budgetMin: !!form.querySelector('[name="budget_min"]')?.value,
            budgetMax: !!form.querySelector('[name="budget_max"]')?.value,
            areas: !!form.querySelector('[name="preferred_areas"]')?.value,
            moveIn: !!form.querySelector('[name="move_in_date"]')?.value,
            bio: (form.querySelector('[name="bio"]')?.value?.length || 0) > 20,
            photo: !!this.uploadedAvatar,
            compatibility: !!this.userProfile?.compatibility_scores
        };

        const completed = Object.values(checks).filter(Boolean).length;
        const total = Object.keys(checks).length;
        const percent = Math.round((completed / total) * 100);

        // Update UI
        helper.classList.remove('hidden');
        if (percentEl) percentEl.textContent = percent;
        if (fillEl) fillEl.style.width = `${percent}%`;

        // Update level text
        if (levelEl) {
            if (percent < 30) levelEl.textContent = 'Just getting started';
            else if (percent < 50) levelEl.textContent = 'Making progress';
            else if (percent < 75) levelEl.textContent = 'Looking good!';
            else if (percent < 100) levelEl.textContent = 'Almost there!';
            else levelEl.textContent = 'Profile complete!';
        }

        // Update tip
        if (tipEl) {
            const tips = [];
            if (!checks.photo) tips.push('Add a photo to get 3x more responses!');
            if (!checks.bio) tips.push('Write a longer bio to stand out');
            if (!checks.compatibility) tips.push('Take the compatibility quiz for better matches');

            if (tips.length > 0) {
                tipEl.innerHTML = `
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                    </svg>
                    <span>${tips[0]}</span>
                `;
            } else {
                tipEl.innerHTML = `
                    <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                    </svg>
                    <span class="text-green-700">Great job! Your profile is complete!</span>
                `;
            }
        }
    }

    // ==================== QUICK INTEREST BUTTON ====================

    async sendQuickInterest(type, id, name) {
        // Require login
        if (!this.requireAuth('express interest')) {
            return;
        }

        const btn = event?.target?.closest('.btn-interested');
        if (btn && btn.classList.contains('sent')) {
            this.showToast('Interest already sent!', 'info');
            return;
        }

        // Send automatic interest message
        const message = "Hi! I'm interested, let's connect!";

        try {
            if (this.api && this.api.initialized) {
                await this.api.sendMessage(id, message);
            }

            // Update button state
            if (btn) {
                btn.classList.add('sent');
                btn.innerHTML = `
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    Sent!
                `;
            }

            this.showToast(`Interest sent to ${name}!`, 'success');
        } catch (error) {
            console.error('Error sending interest:', error);
            this.showToast('Failed to send interest', 'error');
        }
    }

    // ==================== MESSAGE TEMPLATES ====================

    useMessageTemplate(template) {
        const textarea = document.getElementById('messageTextarea');
        if (textarea) {
            textarea.value = template;
            textarea.focus();
        }
    }

    // ==================== FILTER FUNCTIONS ====================

    applySeekerBudgetFilter(value) {
        this.activeFilters.budget = value;
        this.applyAllFilters();
    }

    applySeekerMoveInFilter(value) {
        this.activeFilters.moveIn = value;
        this.applyAllFilters();
    }

    toggleActiveOnly() {
        this.activeFilters.activeOnly = !this.activeFilters.activeOnly;
        this.applyAllFilters();

        // Update button state
        const btn = event?.target?.closest('.filter-pill');
        if (btn) {
            btn.classList.toggle('active', this.activeFilters.activeOnly);
        }
    }

    applyAllFilters() {
        this.filteredSeekers = this.allSeekers.filter(seeker => {
            // Budget filter
            if (this.activeFilters.budget) {
                const [min, max] = this.activeFilters.budget.split('-').map(v => v.replace('+', ''));
                const seekerMax = seeker.budget_max;
                if (max) {
                    if (seekerMax < parseInt(min) || seekerMax > parseInt(max)) return false;
                } else {
                    if (seekerMax < parseInt(min)) return false;
                }
            }

            // Active only filter
            if (this.activeFilters.activeOnly && !seeker.is_active) {
                return false;
            }

            return true;
        });

        this.renderFilteredSeekers('allSeekersGrid');
        this.updateResultsCount('seekersResultsCount', this.filteredSeekers.length, this.allSeekers.length);
    }

    renderFilteredSeekers(containerId) {
        const container = document.getElementById(containerId);
        if (!container) return;
        container.innerHTML = this.filteredSeekers.map(seeker => this.createSeekerCard(seeker)).join('');
    }

    updateResultsCount(elementId, showing, total) {
        const el = document.getElementById(elementId);
        if (el) {
            el.textContent = showing === total
                ? `Showing all ${total} results`
                : `Showing ${showing} of ${total} results`;
        }
    }

    // ==================== SECTION NAVIGATION ====================

    showSection(section) {
        // Map section names to element IDs
        const sectionMap = {
            'selector': 'sectionSelector',
            'seeking': 'seekingSection',
            'browseSeekers': 'browseSeekersSection'
        };

        // Hide all sections
        document.querySelectorAll('.section-view').forEach(el => {
            el.classList.remove('active');
        });

        // Show target section
        const targetId = sectionMap[section];
        if (targetId) {
            const targetEl = document.getElementById(targetId);
            if (targetEl) {
                targetEl.classList.add('active');
                this.currentSection = section;

                // Load section-specific data
                this.loadSectionData(section);
            }
        }

        // Scroll to top
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    async loadSectionData(section) {
        switch (section) {
            case 'browseSeekers':
                await this.loadSeekersGrid('allSeekersGrid');
                break;
            case 'seeking':
                await this.loadSeekersGrid('seekersGrid');
                this.updateGroupDashboard();
                break;
        }
    }

    // ==================== TAB HANDLING ====================

    handleTabClick(e) {
        const tabBtn = e.target;
        const tabName = tabBtn.dataset.tab;
        const tabContainer = tabBtn.closest('.section-view');

        // Update tab buttons
        tabContainer.querySelectorAll('.tab-btn').forEach(btn => {
            btn.classList.remove('active');
        });
        tabBtn.classList.add('active');

        // Show/hide tab content based on section
        if (tabContainer.id === 'seekingSection') {
            this.showSeekingTab(tabName);
        }
    }

    showSeekingTab(tabName) {
        document.getElementById('createProfileTab').classList.toggle('hidden', tabName !== 'createProfile');
        document.getElementById('browsePeopleTab').classList.toggle('hidden', tabName !== 'browsePeople');
        document.getElementById('myGroupTab').classList.toggle('hidden', tabName !== 'myGroup');

        if (tabName === 'browsePeople') {
            this.loadSeekersGrid('seekersGrid');
        } else if (tabName === 'myGroup') {
            this.updateGroupDashboard();
        }
    }

    // ==================== FILTER HANDLING ====================

    handleFilterClick(e) {
        const pill = e.target;
        const container = pill.closest('.section-view') || pill.closest('div');

        // Update active state
        container.querySelectorAll('.filter-pill').forEach(p => {
            p.classList.remove('active');
        });
        pill.classList.add('active');

        // Apply filter
        const filterValue = pill.textContent.trim();
        this.applyFilter(filterValue);
    }

    applyFilter(filterValue) {
        // Filter logic would go here
        console.log('Applying filter:', filterValue);
    }

    // ==================== DATA LOADING ====================

    async loadPreviewData() {
        await this.loadSeekersGrid('previewSeekersGrid', 3);
    }

    async loadSeekersGrid(containerId, limit = 12) {
        const container = document.getElementById(containerId);
        if (!container) return;

        // Get seekers from API or use mock data
        const seekers = await this.getSeekers(limit);

        // Store for filtering
        if (containerId === 'allSeekersGrid') {
            this.allSeekers = seekers;
            this.filteredSeekers = seekers;
            this.updateResultsCount('seekersResultsCount', seekers.length, seekers.length);
        }

        container.innerHTML = seekers.map(seeker => this.createSeekerCard(seeker)).join('');
    }

    async getSeekers(limit = 12) {
        // Try to get from API
        if (this.api) {
            try {
                const seekers = await this.api.getSeekerProfiles({ limit });
                if (seekers && seekers.length > 0) return seekers;
            } catch (e) {
                console.log('Using mock seeker data');
            }
        }

        // Return mock data
        return this.getMockSeekers().slice(0, limit);
    }

    // ==================== CARD TEMPLATES ====================

    createSeekerCard(seeker) {
        const avatarUrl = seeker.avatar_url || seeker.avatar?.photos?.[0]?.url || `https://ui-avatars.com/api/?name=${encodeURIComponent(seeker.name || 'User')}&background=6366f1&color=fff&size=160`;
        const verified = seeker.is_verified ? '<span class="verified-badge ml-1">Verified</span>' : '';
        const budgetRange = seeker.budget_min && seeker.budget_max ? `$${seeker.budget_min} - $${seeker.budget_max}` : 'Budget flexible';
        const moveDate = seeker.move_in_date ? this.formatDate(seeker.move_in_date) : 'Flexible';
        const areas = Array.isArray(seeker.preferred_areas) ? seeker.preferred_areas.slice(0, 2).join(', ') : (seeker.preferred_areas || 'Any area');

        // Prominent match score with color coding
        let matchScoreHtml = '';
        if (seeker.compatibility_score) {
            const score = seeker.compatibility_score;
            let scoreClass = 'low';
            if (score >= 80) scoreClass = 'high';
            else if (score >= 60) scoreClass = 'medium';

            matchScoreHtml = `
                <div class="match-score ${scoreClass} mb-2">
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                    </svg>
                    ${score}% match
                </div>
            `;
        }

        // Match reasons
        const matchReasons = this.getMatchReasons(seeker);
        const matchReasonsHtml = matchReasons.length > 0
            ? `<p class="match-reasons">You both prefer: ${matchReasons.join(', ')}</p>`
            : '';

        // Active indicator - check if logged in within 24 hours
        const isActive = seeker.is_active || (seeker.last_active && (Date.now() - new Date(seeker.last_active).getTime()) < 24 * 60 * 60 * 1000);
        const activeIndicator = isActive ? '<div class="active-indicator"></div>' : '';
        const activeLabel = isActive
            ? '<span class="active-label">Active today</span>'
            : (seeker.last_active ? '<span class="active-label inactive">Active this week</span>' : '');

        return `
            <div class="card p-6 text-center cursor-pointer" onclick="roomPalApp.viewSeeker('${seeker.id}')">
                <div class="avatar-wrapper mx-auto mb-4">
                    <img src="${avatarUrl}" alt="${seeker.name}" class="seeker-avatar">
                    ${activeIndicator}
                </div>
                <div class="flex items-center justify-center gap-1 mb-1">
                    <h3 class="font-bold text-gray-900">${seeker.name || 'Anonymous'}</h3>
                    ${verified}
                </div>
                ${activeLabel}
                ${matchScoreHtml}
                ${matchReasonsHtml}
                <p class="text-indigo-600 font-medium mb-1">${budgetRange}</p>
                <p class="text-sm text-gray-500 mb-1">${areas}</p>
                <p class="text-sm text-gray-400 mb-3">Moving: ${moveDate}</p>
                <p class="text-sm text-gray-600 line-clamp-2 mb-4">${seeker.bio || 'Looking for roommates!'}</p>
                <div class="flex gap-2">
                    <button onclick="event.stopPropagation(); roomPalApp.sendQuickInterest('seeker', '${seeker.id}', '${seeker.name || 'User'}')" class="btn-interested flex-1">
                        <svg class="w-4 h-4 heart-icon" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clip-rule="evenodd"/>
                        </svg>
                        Interested
                    </button>
                    <button onclick="event.stopPropagation(); roomPalApp.openMessage('seeker', '${seeker.id}', '${seeker.name || 'User'}')" class="btn-message flex-1">
                        Connect
                    </button>
                </div>
            </div>
        `;
    }

    getMatchReasons(seeker) {
        const reasons = [];
        const userPrefs = this.userProfile?.compatibility_scores;
        const seekerPrefs = seeker.compatibility_scores;

        if (!userPrefs || !seekerPrefs) return reasons;

        if (userPrefs.cleanliness === seekerPrefs.cleanliness) reasons.push('cleanliness');
        if (userPrefs.sleepSchedule === seekerPrefs.sleepSchedule) reasons.push('sleep schedule');
        if (userPrefs.smoking === seekerPrefs.smoking) reasons.push('no smoking');
        if (userPrefs.pets === seekerPrefs.pets) reasons.push('pet-friendly');
        if (userPrefs.socialLevel === seekerPrefs.socialLevel) reasons.push('social style');

        return reasons.slice(0, 3);
    }

    // ==================== FORM HANDLERS ====================

    async handleSeekerFormSubmit(e) {
        e.preventDefault();

        const form = e.target;
        const formData = new FormData(form);

        const areas = formData.get('preferred_areas').split(',').map(a => a.trim()).filter(a => a);

        const profileData = {
            user_type: 'seeking',
            budget_min: parseInt(formData.get('budget_min')),
            budget_max: parseInt(formData.get('budget_max')),
            preferred_areas: areas,
            move_in_date: formData.get('move_in_date'),
            bio: formData.get('bio'),
            avatar_url: this.uploadedAvatar || null,
            name: this.currentUser?.firstName || 'Anonymous'
        };

        // Show loading state
        const submitBtn = form.querySelector('button[type="submit"]');
        const originalText = submitBtn.textContent;
        submitBtn.textContent = 'Creating...';
        submitBtn.disabled = true;

        try {
            // Save to API or localStorage
            if (this.api && this.api.initialized) {
                await this.api.saveSeekerProfile(profileData);
            } else {
                // Save locally
                profileData.id = 'seeker_' + Date.now();
                profileData.created_at = new Date().toISOString();
                localStorage.setItem('roommateProfile', JSON.stringify(profileData));
                this.userProfile = profileData;
            }

            // Show success
            this.showToast('Profile created successfully!', 'success');

        } catch (error) {
            console.error('Error creating profile:', error);
            this.showToast('Failed to create profile. Please try again.', 'error');
        } finally {
            submitBtn.textContent = originalText;
            submitBtn.disabled = false;
        }
    }

    handleCompatibilitySubmit(e) {
        e.preventDefault();

        const form = e.target;
        const formData = new FormData(form);

        const compatibilityData = {
            sleepSchedule: formData.get('sleepSchedule'),
            cleanliness: formData.get('cleanliness'),
            socialLevel: formData.get('socialLevel'),
            smoking: formData.get('smoking'),
            pets: formData.get('pets')
        };

        // Save compatibility preferences
        const profile = this.userProfile || {};
        profile.compatibility_scores = compatibilityData;
        localStorage.setItem('roommateProfile', JSON.stringify(profile));
        this.userProfile = profile;

        // Close modal
        this.closeCompatibilityModal();
        this.showToast('Preferences saved!', 'success');
    }

    async handleMessageSubmit(e) {
        e.preventDefault();

        // Verify user is still authenticated
        if (!this.requireAuth('send messages')) {
            return;
        }

        const form = e.target;
        const message = form.querySelector('textarea[name="message"]').value;

        // Show loading state
        const submitBtn = form.querySelector('button[type="submit"]');
        const originalText = submitBtn.textContent;
        submitBtn.textContent = 'Sending...';
        submitBtn.disabled = true;

        try {
            // Send through API if available
            if (this.api && this.api.initialized) {
                const result = await this.api.sendMessage(this.messageRecipient.id, message);
                if (!result.success) {
                    throw new Error(result.error || 'Failed to send message');
                }
            }

            this.showToast('Message sent!', 'success');
            this.closeMessageModal();
            form.reset();
        } catch (error) {
            console.error('Error sending message:', error);
            this.showToast('Failed to send message. Please try again.', 'error');
        } finally {
            submitBtn.textContent = originalText;
            submitBtn.disabled = false;
        }
    }

    handlePhotoUpload(e) {
        const files = e.target.files;
        if (!files.length) return;

        const file = files[0];
        const reader = new FileReader();
        reader.onload = (event) => {
            this.uploadedAvatar = event.target.result;
            document.getElementById('avatarPreview').innerHTML = `
                <img src="${event.target.result}" class="w-24 h-24 rounded-full object-cover mx-auto">
            `;
        };
        reader.readAsDataURL(file);
    }

    // ==================== GROUP MANAGEMENT ====================

    createGroup() {
        const groupName = prompt('Enter a name for your group:') || 'Our Roommate Group';

        this.userGroup = {
            id: 'group_' + Date.now(),
            name: groupName,
            creator_id: this.currentUser?.id || 'user_' + Date.now(),
            members: [{
                user_id: this.currentUser?.id || 'user_' + Date.now(),
                name: this.currentUser?.firstName || this.userProfile?.name || 'You',
                avatar: this.userProfile?.avatar_url,
                budget_min: this.userProfile?.budget_min || 800,
                budget_max: this.userProfile?.budget_max || 1500,
                role: 'creator',
                status: 'accepted'
            }],
            status: 'forming',
            created_at: new Date().toISOString()
        };

        localStorage.setItem('roommateGroup', JSON.stringify(this.userGroup));
        this.updateGroupDashboard();
        this.showToast('Group created!', 'success');
    }

    inviteToGroup(seekerId) {
        // Require login before inviting
        if (!this.requireAuth('invite people to your group')) {
            return;
        }

        if (!this.userGroup) {
            if (confirm('You need to create a group first. Create one now?')) {
                this.createGroup();
            }
            return;
        }

        // In a real app, this would send an invitation through the API
        this.showToast('Invitation sent!', 'success');
    }

    updateGroupDashboard() {
        const noGroupView = document.getElementById('noGroupView');
        const groupDashboard = document.getElementById('groupDashboard');

        if (!noGroupView || !groupDashboard) return;

        if (this.userGroup) {
            noGroupView.classList.add('hidden');
            groupDashboard.classList.remove('hidden');

            // Update group name
            document.getElementById('groupName').textContent = this.userGroup.name;

            // Update members list
            const membersList = document.getElementById('groupMembersList');
            membersList.innerHTML = this.userGroup.members.map(member => `
                <div class="group-member">
                    <img src="${member.avatar || `https://ui-avatars.com/api/?name=${encodeURIComponent(member.name)}&background=6366f1&color=fff`}"
                         class="w-10 h-10 rounded-full">
                    <div class="flex-1">
                        <p class="font-medium text-gray-900">${member.name}</p>
                        <p class="text-sm text-gray-500">$${member.budget_min} - $${member.budget_max}/mo</p>
                    </div>
                    ${member.role === 'creator' ? '<span class="text-xs text-indigo-600">Creator</span>' : ''}
                </div>
            `).join('');

            // Calculate combined budget
            const totalMin = this.userGroup.members.reduce((sum, m) => sum + (m.budget_min || 0), 0);
            const totalMax = this.userGroup.members.reduce((sum, m) => sum + (m.budget_max || 0), 0);
            document.getElementById('combinedBudget').textContent = `$${totalMin.toLocaleString()} - $${totalMax.toLocaleString()}`;

        } else {
            noGroupView.classList.remove('hidden');
            groupDashboard.classList.add('hidden');
        }
    }

    // ==================== MODALS ====================

    openMessage(type, id, name) {
        // Require login before messaging
        if (!this.requireAuth('send messages')) {
            return;
        }

        this.messageRecipient = { type, id, name };

        const recipientEl = document.getElementById('messageRecipient');
        recipientEl.innerHTML = `
            <div class="w-10 h-10 bg-indigo-100 rounded-full flex items-center justify-center">
                <svg class="w-5 h-5 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                </svg>
            </div>
            <div>
                <p class="font-medium text-gray-900">${name}</p>
                <p class="text-sm text-gray-500">Roommate seeker</p>
            </div>
        `;

        const modal = document.getElementById('messageModal');
        modal.classList.remove('hidden');
        modal.classList.add('flex');
    }

    closeMessageModal() {
        const modal = document.getElementById('messageModal');
        modal.classList.add('hidden');
        modal.classList.remove('flex');
    }

    showCompatibilityQuestions() {
        const modal = document.getElementById('compatibilityModal');
        modal.classList.remove('hidden');
        modal.classList.add('flex');
    }

    closeCompatibilityModal() {
        const modal = document.getElementById('compatibilityModal');
        modal.classList.add('hidden');
        modal.classList.remove('flex');
    }

    viewSeeker(seekerId) {
        console.log('Viewing seeker:', seekerId);
        // In a real app, this would open a detailed seeker profile
    }

    // ==================== AUTHENTICATION ====================

    requireAuth(action = 'perform this action') {
        // Check localStorage user first
        if (this.currentUser) {
            return true;
        }

        // Not authenticated - show message and redirect
        alert(`Please log in to ${action}.`);
        window.location.href = 'login.html';
        return false;
    }

    // ==================== UTILITIES ====================

    formatDate(dateStr) {
        if (!dateStr) return 'Flexible';
        const date = new Date(dateStr);
        const now = new Date();
        const diffDays = Math.ceil((date - now) / (1000 * 60 * 60 * 24));

        if (diffDays <= 0) return 'Available Now';
        if (diffDays <= 7) return 'This Week';
        if (diffDays <= 14) return 'Next Week';
        if (diffDays <= 30) return 'This Month';

        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }

    showToast(message, type = 'info') {
        // Create toast element
        const toast = document.createElement('div');
        toast.className = `fixed bottom-4 right-4 px-6 py-3 rounded-lg text-white z-50 transition-all transform translate-y-0 opacity-100 ${
            type === 'success' ? 'bg-emerald-500' :
            type === 'error' ? 'bg-red-500' : 'bg-indigo-500'
        }`;
        toast.textContent = message;

        document.body.appendChild(toast);

        // Remove after 3 seconds
        setTimeout(() => {
            toast.classList.add('opacity-0', 'translate-y-2');
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }

    // ==================== MOCK DATA ====================

    getMockSeekers() {
        return [
            {
                id: 'seeker_1',
                name: 'Sarah',
                budget_min: 800,
                budget_max: 1200,
                preferred_areas: ['Capitol Hill', 'Downtown', 'Fremont'],
                move_in_date: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString(),
                bio: 'Software developer looking for a quiet, clean household. Love cooking and weekend hikes!',
                avatar_url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop&crop=face',
                is_verified: true,
                is_active: true,
                last_active: new Date(Date.now() - 30 * 60 * 1000).toISOString(), // 30 min ago
                compatibility_score: 92,
                compatibility_scores: { cleanliness: 'very-clean', sleepSchedule: 'early', smoking: 'no', pets: 'love', socialLevel: 'balanced' }
            },
            {
                id: 'seeker_2',
                name: 'Marcus',
                budget_min: 900,
                budget_max: 1400,
                preferred_areas: ['Ballard', 'Fremont', 'Wallingford'],
                move_in_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
                bio: 'Graduate student at UW. Quiet, respectful, and enjoy good conversations. Night owl but respectful of quiet hours.',
                avatar_url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=face',
                is_verified: true,
                is_active: true,
                last_active: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(), // 2 hours ago
                compatibility_score: 87,
                compatibility_scores: { cleanliness: 'clean', sleepSchedule: 'night-owl', smoking: 'no', pets: 'ok', socialLevel: 'quiet' }
            },
            {
                id: 'seeker_3',
                name: 'Emily',
                budget_min: 700,
                budget_max: 1000,
                preferred_areas: ['University District', 'Ravenna'],
                move_in_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
                bio: 'Medical student looking for roommates! Clean and organized. Usually studying but love movie nights.',
                avatar_url: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&h=200&fit=crop&crop=face',
                is_verified: false,
                is_active: false,
                last_active: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString(), // 3 days ago
                compatibility_score: 78,
                compatibility_scores: { cleanliness: 'very-clean', sleepSchedule: 'moderate', smoking: 'no', pets: 'allergic', socialLevel: 'quiet' }
            },
            {
                id: 'seeker_4',
                name: 'David',
                budget_min: 1000,
                budget_max: 1500,
                preferred_areas: ['Downtown', 'South Lake Union', 'Capitol Hill'],
                move_in_date: new Date().toISOString(),
                bio: 'Remote worker in tech. Looking for a social household with professionals. Love board games and cooking!',
                avatar_url: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop&crop=face',
                is_verified: true,
                is_active: true,
                last_active: new Date(Date.now() - 15 * 60 * 1000).toISOString(), // 15 min ago
                compatibility_score: 85,
                compatibility_scores: { cleanliness: 'clean', sleepSchedule: 'moderate', smoking: 'no', pets: 'love', socialLevel: 'social' }
            },
            {
                id: 'seeker_5',
                name: 'Lisa',
                budget_min: 850,
                budget_max: 1200,
                preferred_areas: ['Queen Anne', 'Magnolia', 'Ballard'],
                move_in_date: new Date(Date.now() + 21 * 24 * 60 * 60 * 1000).toISOString(),
                bio: 'Artist and part-time barista. Creative, easy-going, and love plants. Looking for a chill environment.',
                avatar_url: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&h=200&fit=crop&crop=face',
                is_verified: false,
                is_active: false,
                last_active: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(), // 5 days ago
                compatibility_score: 81,
                compatibility_scores: { cleanliness: 'relaxed', sleepSchedule: 'night-owl', smoking: 'outside', pets: 'love', socialLevel: 'balanced' }
            },
            {
                id: 'seeker_6',
                name: 'Kevin',
                budget_min: 750,
                budget_max: 1100,
                preferred_areas: ['Beacon Hill', 'Columbia City', 'Georgetown'],
                move_in_date: new Date(Date.now() + 45 * 24 * 60 * 60 * 1000).toISOString(),
                bio: 'Teacher at local high school. Active and social but respect quiet time. Love outdoor activities!',
                avatar_url: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
                is_verified: true,
                is_active: true,
                last_active: new Date(Date.now() - 4 * 60 * 60 * 1000).toISOString(), // 4 hours ago
                compatibility_score: 89,
                compatibility_scores: { cleanliness: 'clean', sleepSchedule: 'early', smoking: 'no', pets: 'ok', socialLevel: 'social' }
            }
        ];
    }
}

// Global functions for onclick handlers
function showSection(section) {
    if (window.roomPalApp) {
        window.roomPalApp.showSection(section);
    }
}

function showCompatibilityQuestions() {
    if (window.roomPalApp) {
        window.roomPalApp.showCompatibilityQuestions();
    }
}

function closeCompatibilityModal() {
    if (window.roomPalApp) {
        window.roomPalApp.closeCompatibilityModal();
    }
}

function closeMessageModal() {
    if (window.roomPalApp) {
        window.roomPalApp.closeMessageModal();
    }
}

function createGroup() {
    if (window.roomPalApp) {
        window.roomPalApp.createGroup();
    }
}

// Global functions for quick interest and templates
function sendQuickInterest(type, id, name) {
    if (window.roomPalApp) {
        window.roomPalApp.sendQuickInterest(type, id, name);
    }
}

function useMessageTemplate(template) {
    if (window.roomPalApp) {
        window.roomPalApp.useMessageTemplate(template);
    }
}

// Initialize app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.roomPalApp = new RoomPalApp();
});
