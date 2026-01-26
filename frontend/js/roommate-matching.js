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
        const budgetRange = seeker.budget_min && seeker.budget_max ? `$${seeker.budget_min}-$${seeker.budget_max}` : 'Flexible';
        const moveDate = seeker.move_in_date ? this.formatDate(seeker.move_in_date) : 'Flexible';
        const areas = Array.isArray(seeker.preferred_areas) ? seeker.preferred_areas.slice(0, 1).join(', ') : (seeker.preferred_areas || 'Any area');

        // Match score badge
        const score = seeker.compatibility_score || 0;
        let scoreClass = 'low';
        if (score >= 80) scoreClass = 'high';
        else if (score >= 60) scoreClass = 'medium';

        // Active indicator
        const isActive = seeker.is_active || (seeker.last_active && (Date.now() - new Date(seeker.last_active).getTime()) < 24 * 60 * 60 * 1000);
        const onlineDot = isActive ? '<span class="online-dot"></span>' : '';

        // Verified badge
        const verifiedBadge = seeker.is_verified ? `
            <span class="verified-badge-modern">
                <svg width="12" height="12" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                </svg>
            </span>
        ` : '';

        // Match badge (colored pill)
        const matchBadge = score > 0 ? `<span class="match-badge ${scoreClass}">${score}% match</span>` : '';

        // Generate lifestyle tags
        const lifestyleTags = this.generateLifestyleTags(seeker);

        return `
            <div class="seeker-card-modern" onclick="roomPalApp.viewSeeker('${seeker.id}')">
                <div class="seeker-avatar-wrapper">
                    <img src="${avatarUrl}" alt="${seeker.name}" class="seeker-avatar-modern">
                    ${onlineDot}
                </div>

                <div class="seeker-content">
                    <div class="seeker-header">
                        <span class="seeker-name-modern">${seeker.name || 'Anonymous'}</span>
                        ${verifiedBadge}
                        ${matchBadge}
                    </div>

                    <div class="seeker-quick-stats">
                        <div class="stat-item">
                            <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                            </svg>
                            <span>${budgetRange}</span>
                        </div>
                        <div class="stat-item">
                            <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
                            </svg>
                            <span>${areas}</span>
                        </div>
                        <div class="stat-item">
                            <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                            </svg>
                            <span>${moveDate}</span>
                        </div>
                    </div>

                    ${lifestyleTags.length > 0 ? `
                    <div class="seeker-tags">
                        ${lifestyleTags.join(' ')}
                    </div>
                    ` : ''}

                    <p class="seeker-bio-preview">${seeker.bio || 'Looking for roommates!'}</p>

                    <button onclick="event.stopPropagation(); roomPalApp.openMessage('seeker', '${seeker.id}', '${seeker.name || 'User'}')" class="btn-connect-modern">
                        Connect
                        <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3"/>
                        </svg>
                    </button>
                </div>
            </div>
        `;
    }

    generateLifestyleTags(seeker) {
        const tags = [];
        const prefs = seeker.compatibility_scores || {};

        // Cleanliness
        if (prefs.cleanliness === 'very-clean' || prefs.cleanliness === 'clean') {
            tags.push('<span class="lifestyle-tag blue">Clean</span>');
        }

        // Sleep schedule
        if (prefs.sleepSchedule === 'early') {
            tags.push('<span class="lifestyle-tag yellow">Early bird</span>');
        } else if (prefs.sleepSchedule === 'night-owl') {
            tags.push('<span class="lifestyle-tag pink">Night owl</span>');
        }

        // Social level
        if (prefs.socialLevel === 'quiet' || prefs.socialLevel === 'introvert') {
            tags.push('<span class="lifestyle-tag yellow">Quiet</span>');
        } else if (prefs.socialLevel === 'social' || prefs.socialLevel === 'extrovert') {
            tags.push('<span class="lifestyle-tag pink">Social</span>');
        }

        // Pets
        if (prefs.pets === 'yes' || prefs.pets === 'have-pets' || prefs.pets === 'love-pets') {
            tags.push('<span class="lifestyle-tag green">Pet friendly</span>');
        }

        // Smoking
        if (prefs.smoking === 'no' || prefs.smoking === 'non-smoker') {
            tags.push('<span class="lifestyle-tag gray">No smoking</span>');
        }

        // Work from home
        if (prefs.workFromHome === 'yes' || prefs.workFromHome === 'full-time') {
            tags.push('<span class="lifestyle-tag purple">WFH</span>');
        }

        return tags.slice(0, 4); // Limit to 4 tags
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
