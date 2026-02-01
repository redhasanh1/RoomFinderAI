// RoomPal - Smart Roommate Matching System
// Find compatible roommates with intelligent filtering

class RoomPalApp {
    constructor() {
        this.currentSection = 'landing';
        this.currentUser = null;
        this.userProfile = null;
        this.api = null;
        this.allRooms = [];
        this.filteredRooms = [];
        this.allPeople = [];
        this.filteredPeople = [];
        this.uploadedPhoto = null;
        this.hasUserProfile = false;

        // Profile form state
        this.profileFormData = {
            cleanliness: 8,
            social: 5,
            sleep: null,
            smoking: 'Non-Smoker',
            pets: null
        };

        // Messages state
        this.currentConversationId = null;
        this.currentChatPartner = null;

        // Smart filter state
        this.filters = {
            city: '',
            budgetRange: '',
            moveIn: '',
            lifestyle: '',
            sort: 'match'
        };

        this.init();
    }

    async init() {
        // Initialize API service
        if (typeof RoommateAPIService !== 'undefined') {
            this.api = new RoommateAPIService();
        }

        // Load current user
        this.loadCurrentUser();
        this.updateHeader();

        // Setup event listeners
        this.setupEventListeners();

        // Load user's profile if logged in
        await this.loadUserProfile();

        // Show/hide create profile CTA
        this.updateProfileCTA();

        // Show landing section by default (don't auto-load matches)
        // Matches will load when user navigates to a section
        this.currentSection = 'landing';

        console.log('RoomPal Smart Matching initialized');
    }

    async loadUserProfile() {
        if (!this.currentUser || !this.api) return;

        try {
            const profiles = await this.api.getSeekerProfiles({ limit: 100 });
            this.userProfile = profiles.find(p => p.user_id === this.currentUser.id);
            this.hasUserProfile = !!this.userProfile;
        } catch (error) {
            console.error('Error loading user profile:', error);
        }
    }

    updateProfileCTA() {
        const cta = document.getElementById('createProfileCTA');
        if (cta) {
            if (!this.currentUser || !this.hasUserProfile) {
                cta.classList.remove('hidden');
            } else {
                cta.classList.add('hidden');
            }
        }
    }

    async loadRoommateMatches() {
        const grid = document.getElementById('matchResultsGrid');
        const emptyState = document.getElementById('matchEmptyState');
        const loadingState = document.getElementById('matchLoadingState');
        const resultsCount = document.getElementById('matchResultsCount');

        if (!grid) {
            console.error('matchResultsGrid not found in DOM');
            return;
        }

        // Show loading
        if (loadingState) loadingState.classList.remove('hidden');
        if (emptyState) emptyState.classList.add('hidden');
        grid.classList.add('hidden');

        try {
            // Wait for API to initialize
            if (this.api) {
                const isInitialized = await this.api.ensureInitialized();
                console.log('API initialized:', isInitialized);

                if (isInitialized) {
                    this.allPeople = await this.api.getSeekerProfiles({}) || [];
                    console.log('Fetched seeker profiles:', this.allPeople.length);
                } else {
                    console.warn('API not initialized, using demo profiles');
                    this.allPeople = this.getDemoProfiles();
                }
            } else {
                console.warn('No API instance available, using demo profiles');
                this.allPeople = this.getDemoProfiles();
            }

            // If database returned empty, show demo profiles so page isn't blank
            if (this.allPeople.length === 0) {
                console.log('No profiles in database, showing demo profiles');
                this.allPeople = this.getDemoProfiles();
            }

            // Filter out current user
            if (this.currentUser) {
                this.allPeople = this.allPeople.filter(p => p.user_id !== this.currentUser.id);
            }

            // Calculate compatibility scores
            this.allPeople = this.allPeople.map(person => ({
                ...person,
                matchScore: this.calculateMatchScore(person)
            }));

            // Apply filters and sort
            this.applySmartFilters();

        } catch (error) {
            console.error('Error loading roommate matches:', error);
            if (loadingState) loadingState.classList.add('hidden');
            if (emptyState) emptyState.classList.remove('hidden');
            grid.classList.add('hidden');
            if (resultsCount) resultsCount.textContent = 'Error loading matches. Please refresh.';
        }
    }

    getDemoProfiles() {
        // Demo profiles shown when database is empty
        return [
            {
                id: 'demo_1',
                user_id: 'demo_user_1',
                name: 'Sarah Chen',
                bio: 'Graduate student at UBC looking for a quiet, clean roommate. I love cooking and reading!',
                budget_max: 1200,
                preferred_areas: ['Vancouver', 'Burnaby'],
                move_in_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
                lifestyle: { sleepSchedule: 'Early Bird', smoking: 'Non-Smoker', petsOk: true },
                compatibility_scores: { cleanliness: 8, socialLevel: 4 },
                created_at: new Date().toISOString(),
                is_demo: true
            },
            {
                id: 'demo_2',
                user_id: 'demo_user_2',
                name: 'Marcus Johnson',
                bio: 'Young professional working in tech. Looking for a social roommate who enjoys occasional game nights!',
                budget_max: 1500,
                preferred_areas: ['Toronto', 'North York'],
                move_in_date: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString(),
                lifestyle: { sleepSchedule: 'Night Owl', smoking: 'Non-Smoker', petsOk: false },
                compatibility_scores: { cleanliness: 6, socialLevel: 8 },
                created_at: new Date().toISOString(),
                is_demo: true
            },
            {
                id: 'demo_3',
                user_id: 'demo_user_3',
                name: 'Emily Rodriguez',
                bio: 'Medical resident looking for a clean and respectful roommate. I have a small cat named Luna!',
                budget_max: 1400,
                preferred_areas: ['Montreal', 'Plateau'],
                move_in_date: new Date(Date.now() + 45 * 24 * 60 * 60 * 1000).toISOString(),
                lifestyle: { sleepSchedule: 'Early Bird', smoking: 'Non-Smoker', petsOk: true, hasPets: true },
                compatibility_scores: { cleanliness: 9, socialLevel: 5 },
                created_at: new Date().toISOString(),
                is_demo: true
            },
            {
                id: 'demo_4',
                user_id: 'demo_user_4',
                name: 'David Kim',
                bio: 'Software developer working from home. Looking for someone chill who respects quiet hours during work.',
                budget_max: 1600,
                preferred_areas: ['Calgary', 'Downtown'],
                move_in_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
                lifestyle: { sleepSchedule: 'Night Owl', smoking: 'Non-Smoker', petsOk: true },
                compatibility_scores: { cleanliness: 7, socialLevel: 4 },
                created_at: new Date().toISOString(),
                is_demo: true
            },
            {
                id: 'demo_5',
                user_id: 'demo_user_5',
                name: 'Aisha Patel',
                bio: 'Freelance designer and yoga enthusiast. Looking for a mindful, plant-friendly roommate!',
                budget_max: 1300,
                preferred_areas: ['Ottawa', 'Centretown'],
                move_in_date: new Date(Date.now() + 20 * 24 * 60 * 60 * 1000).toISOString(),
                lifestyle: { sleepSchedule: 'Early Bird', smoking: 'Non-Smoker', petsOk: true },
                compatibility_scores: { cleanliness: 8, socialLevel: 6 },
                created_at: new Date().toISOString(),
                is_demo: true
            },
            {
                id: 'demo_6',
                user_id: 'demo_user_6',
                name: 'Jake Thompson',
                bio: 'Culinary school student who loves to cook! Looking for a roommate who appreciates good food.',
                budget_max: 1100,
                preferred_areas: ['Edmonton', 'Whyte Ave'],
                move_in_date: new Date(Date.now() + 60 * 24 * 60 * 60 * 1000).toISOString(),
                lifestyle: { sleepSchedule: 'Night Owl', smoking: 'Non-Smoker', petsOk: false },
                compatibility_scores: { cleanliness: 7, socialLevel: 7 },
                created_at: new Date().toISOString(),
                is_demo: true
            }
        ];
    }

    calculateMatchScore(person) {
        if (!this.userProfile) {
            // Random score if no profile (still useful for demo)
            return Math.floor(Math.random() * 30) + 60; // 60-90
        }

        let score = 50; // Base score
        const userLifestyle = this.userProfile.lifestyle || {};
        const personLifestyle = person.lifestyle || {};
        const userScores = this.userProfile.compatibility_scores || {};
        const personScores = person.compatibility_scores || {};

        // Budget overlap (+20 points)
        const userBudgetMax = this.userProfile.budget_max || 2000;
        const personBudgetMax = person.budget_max || 2000;
        const budgetDiff = Math.abs(userBudgetMax - personBudgetMax);
        if (budgetDiff < 200) score += 20;
        else if (budgetDiff < 500) score += 10;

        // Location match (+15 points)
        const userAreas = this.userProfile.preferred_areas || [];
        const personAreas = person.preferred_areas || [];
        if (userAreas.some(a => personAreas.some(pa =>
            pa.toLowerCase().includes(a.toLowerCase()) || a.toLowerCase().includes(pa.toLowerCase())
        ))) {
            score += 15;
        }

        // Sleep schedule match (+10 points)
        if (userLifestyle.sleepSchedule && personLifestyle.sleepSchedule) {
            if (userLifestyle.sleepSchedule === personLifestyle.sleepSchedule) score += 10;
        }

        // Smoking compatibility (+10 points)
        if (userLifestyle.smoking === personLifestyle.smoking) score += 10;

        // Pet compatibility (+10 points)
        if (userLifestyle.petsOk === personLifestyle.petsOk) score += 10;

        // Cleanliness match (+5 points)
        const cleanDiff = Math.abs((userScores.cleanliness || 5) - (personScores.cleanliness || 5));
        if (cleanDiff <= 2) score += 5;

        return Math.min(99, Math.max(40, score));
    }

    applySmartFilters() {
        const grid = document.getElementById('matchResultsGrid');
        const emptyState = document.getElementById('matchEmptyState');
        const loadingState = document.getElementById('matchLoadingState');
        const resultsCount = document.getElementById('matchResultsCount');

        // Get filter values
        this.filters.city = document.getElementById('cityFilter')?.value || '';
        this.filters.budgetRange = document.getElementById('budgetRangeFilter')?.value || '';
        this.filters.moveIn = document.getElementById('moveInFilter')?.value || '';
        this.filters.lifestyle = document.getElementById('lifestyleFilter')?.value || '';
        this.filters.sort = document.getElementById('sortFilter')?.value || 'match';

        // Filter people
        this.filteredPeople = this.allPeople.filter(person => {
            // City filter
            if (this.filters.city) {
                const areas = (person.preferred_areas || []).join(' ').toLowerCase();
                if (!areas.includes(this.filters.city.toLowerCase())) return false;
            }

            // Budget filter
            if (this.filters.budgetRange) {
                const budget = person.budget_max || 0;
                const [min, max] = this.filters.budgetRange.split('-').map(n => parseInt(n) || 0);
                if (this.filters.budgetRange.includes('+')) {
                    if (budget < min) return false;
                } else {
                    if (budget < min || budget > max) return false;
                }
            }

            // Move-in date filter
            if (this.filters.moveIn && person.move_in_date) {
                const moveDate = new Date(person.move_in_date);
                const now = new Date();
                const diffDays = Math.ceil((moveDate - now) / (1000 * 60 * 60 * 24));

                if (this.filters.moveIn === 'immediate' && diffDays > 14) return false;
                if (this.filters.moveIn === '1month' && diffDays > 30) return false;
                if (this.filters.moveIn === '3months' && diffDays > 90) return false;
            }

            // Lifestyle filter
            if (this.filters.lifestyle) {
                const lifestyle = person.lifestyle || {};
                const scores = person.compatibility_scores || {};

                if (this.filters.lifestyle === 'quiet' && scores.socialLevel > 5) return false;
                if (this.filters.lifestyle === 'social' && scores.socialLevel < 5) return false;
                if (this.filters.lifestyle === 'pet-friendly' && !lifestyle.petsOk) return false;
                if (this.filters.lifestyle === 'non-smoker' && lifestyle.smoking !== 'Non-Smoker' && lifestyle.smoking !== 'Never') return false;
            }

            return true;
        });

        // Sort
        this.filteredPeople.sort((a, b) => {
            switch (this.filters.sort) {
                case 'match':
                    return (b.matchScore || 0) - (a.matchScore || 0);
                case 'newest':
                    return new Date(b.created_at || 0) - new Date(a.created_at || 0);
                case 'budget-low':
                    return (a.budget_max || 0) - (b.budget_max || 0);
                case 'budget-high':
                    return (b.budget_max || 0) - (a.budget_max || 0);
                default:
                    return 0;
            }
        });

        // Hide loading
        if (loadingState) loadingState.classList.add('hidden');

        // Check if showing demo profiles
        const hasRealProfiles = this.filteredPeople.some(p => !p.is_demo);
        const demoBanner = document.getElementById('demoBanner');

        // Show/hide demo banner
        if (!hasRealProfiles && this.filteredPeople.length > 0) {
            if (!demoBanner) {
                // Create demo banner if it doesn't exist
                const banner = document.createElement('div');
                banner.id = 'demoBanner';
                banner.className = 'bg-amber-50 border border-amber-200 rounded-xl p-4 mb-6';
                banner.innerHTML = `
                    <div class="flex items-start gap-3">
                        <svg class="w-5 h-5 text-amber-500 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                        </svg>
                        <div>
                            <p class="text-amber-800 font-medium">These are demo profiles</p>
                            <p class="text-amber-700 text-sm">Create your roommate profile to find real matches and appear in searches!</p>
                            <button onclick="showSection('seeking')" class="mt-2 text-sm font-medium text-amber-900 underline hover:no-underline">Create Your Profile</button>
                        </div>
                    </div>
                `;
                grid.parentElement.insertBefore(banner, grid);
            }
        } else if (demoBanner) {
            demoBanner.remove();
        }

        // Render results
        if (this.filteredPeople.length === 0) {
            grid.classList.add('hidden');
            if (emptyState) emptyState.classList.remove('hidden');
            if (resultsCount) resultsCount.textContent = '0 matches found';
        } else {
            grid.classList.remove('hidden');
            if (emptyState) emptyState.classList.add('hidden');
            if (resultsCount) resultsCount.textContent = `${this.filteredPeople.length} ${this.filteredPeople.length === 1 ? 'match' : 'matches'} found`;
            grid.innerHTML = this.filteredPeople.map(person => this.createMatchCard(person)).join('');
        }
    }

    createMatchCard(person) {
        const avatarUrl = person.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(person.name || 'User')}&background=6366f1&color=fff&size=160`;
        const name = person.name || 'Anonymous';
        const location = person.preferred_areas?.[0] || 'Location flexible';
        const budgetMax = person.budget_max || 0;
        const budgetText = budgetMax ? `Up to $${budgetMax}/mo` : 'Budget flexible';
        const bio = person.bio || 'Looking for a great roommate!';
        const truncatedBio = bio.length > 80 ? bio.substring(0, 80) + '...' : bio;
        const moveInDate = person.move_in_date ? this.formatDate(person.move_in_date) : 'Flexible';
        const matchScore = person.matchScore || 75;

        // Match score color
        let matchColor = 'bg-gray-400';
        if (matchScore >= 85) matchColor = 'bg-emerald-500';
        else if (matchScore >= 70) matchColor = 'bg-blue-500';
        else if (matchScore >= 55) matchColor = 'bg-yellow-500';

        // Lifestyle badges
        const lifestyle = person.lifestyle || {};
        const badges = [];
        if (lifestyle.smoking === 'Non-Smoker' || lifestyle.smoking === 'Never') badges.push('🚭');
        if (lifestyle.petsOk) badges.push('🐾');
        if (lifestyle.sleepSchedule?.includes('night') || lifestyle.sleepSchedule?.includes('owl')) badges.push('🌙');
        if (lifestyle.sleepSchedule?.includes('early') || lifestyle.sleepSchedule?.includes('morning')) badges.push('☀️');

        const isOwnProfile = this.currentUser && person.user_id === this.currentUser.id;

        return `
            <div class="bg-white rounded-2xl shadow-sm border hover:shadow-lg transition-all duration-300 overflow-hidden">
                <!-- Match Score Badge -->
                <div class="relative">
                    <div class="absolute top-3 right-3 ${matchColor} text-white px-3 py-1 rounded-full text-sm font-bold shadow-md">
                        ${matchScore}% Match
                    </div>
                    <div class="h-24 bg-gradient-to-br from-indigo-400 to-purple-500"></div>
                    <img src="${avatarUrl}" alt="${name}" class="w-20 h-20 rounded-full border-4 border-white absolute -bottom-10 left-1/2 -translate-x-1/2 object-cover" onerror="this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&background=6366f1&color=fff&size=160'">
                </div>

                <div class="pt-12 p-5 text-center">
                    <h3 class="text-lg font-bold text-gray-900 mb-1">${name}</h3>

                    <div class="flex items-center justify-center gap-1 text-gray-500 text-sm mb-2">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                        </svg>
                        ${location}
                    </div>

                    <div class="flex items-center justify-center gap-4 text-sm text-gray-600 mb-3">
                        <span class="flex items-center gap-1">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                            </svg>
                            ${budgetText}
                        </span>
                        <span class="flex items-center gap-1">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                            </svg>
                            ${moveInDate}
                        </span>
                    </div>

                    ${badges.length > 0 ? `
                        <div class="flex items-center justify-center gap-2 mb-3">
                            ${badges.map(b => `<span class="text-lg">${b}</span>`).join('')}
                        </div>
                    ` : ''}

                    <p class="text-gray-600 text-sm mb-4">${truncatedBio}</p>

                    ${isOwnProfile
                        ? `<span class="inline-block w-full text-center py-2.5 text-gray-500 bg-gray-100 rounded-xl text-sm font-medium">Your Profile</span>`
                        : person.is_demo
                        ? `<span class="inline-block w-full text-center py-2.5 text-amber-600 bg-amber-50 rounded-xl text-sm font-medium">Demo Profile</span>`
                        : `<button onclick="roomPalApp.openPersonContact('${person.user_id}', '${name.replace(/'/g, "\\'")}')" class="w-full bg-gradient-to-r from-indigo-500 to-purple-600 text-white py-2.5 rounded-xl font-semibold hover:from-indigo-600 hover:to-purple-700 transition-all">
                            Connect
                        </button>`
                    }
                </div>
            </div>
        `;
    }

    clearAllFilters() {
        document.getElementById('cityFilter').value = '';
        document.getElementById('budgetRangeFilter').value = '';
        document.getElementById('moveInFilter').value = '';
        document.getElementById('lifestyleFilter').value = '';
        document.getElementById('sortFilter').value = 'match';
        this.applySmartFilters();
    }

    async loadPreviewData() {
        try {
            // Load preview rooms
            const rooms = await this.getRooms();
            const previewRoomsGrid = document.getElementById('previewRoomsGrid');
            if (previewRoomsGrid && rooms.length > 0) {
                previewRoomsGrid.innerHTML = rooms.slice(0, 3).map(room => this.createRoomCard(room)).join('');
            } else if (previewRoomsGrid) {
                previewRoomsGrid.innerHTML = '<p class="text-gray-500 col-span-3 text-center py-8">No rooms posted yet. Be the first!</p>';
            }

            // Load preview seekers
            const people = await this.getPeople();
            const previewSeekersGrid = document.getElementById('previewSeekersGrid');
            if (previewSeekersGrid && people.length > 0) {
                previewSeekersGrid.innerHTML = people.slice(0, 3).map(person => this.createPersonCard(person)).join('');
            } else if (previewSeekersGrid) {
                previewSeekersGrid.innerHTML = '<p class="text-gray-500 col-span-3 text-center py-8">No seekers yet. Create your profile!</p>';
            }
        } catch (error) {
            console.log('Preview data loading skipped:', error.message);
        }
    }

    loadCurrentUser() {
        const stored = localStorage.getItem('currentUser');
        if (stored) {
            this.currentUser = JSON.parse(stored);
        }
    }

    updateHeader() {
        const desktopAuth = document.getElementById('desktopAuthSection');
        const mobileAuth = document.getElementById('mobileAuthLink');

        if (this.currentUser) {
            const userName = this.currentUser.firstName || this.currentUser.name || 'User';

            if (desktopAuth) {
                desktopAuth.innerHTML = `
                    <div class="flex items-center gap-4">
                        <span class="text-gray-700 font-medium">Hi, ${userName}</span>
                        <a href="profile.html" class="bg-indigo-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-indigo-700 transition-colors">My Profile</a>
                    </div>
                `;
            }

            if (mobileAuth) {
                mobileAuth.textContent = `Hi, ${userName} - Profile`;
                mobileAuth.href = 'profile.html';
                mobileAuth.className = 'block py-3 px-4 bg-indigo-600 text-white rounded-lg font-medium text-center hover:bg-indigo-700 transition-colors';
            }
        }
    }

    setupEventListeners() {
        // Room form submission
        const roomForm = document.getElementById('roomForm');
        if (roomForm) {
            roomForm.addEventListener('submit', (e) => this.handleRoomFormSubmit(e));
        }

        // Contact form submission
        const messageForm = document.getElementById('messageForm');
        if (messageForm) {
            messageForm.addEventListener('submit', (e) => this.handleContactSubmit(e));
        }

        // Photo upload
        const roomPhotos = document.getElementById('roomPhotos');
        if (roomPhotos) {
            roomPhotos.addEventListener('change', (e) => this.handlePhotoUpload(e, 'photoPreview'));
        }

        // Quick profile form submission
        const quickProfileForm = document.getElementById('quickProfileForm');
        if (quickProfileForm) {
            quickProfileForm.addEventListener('submit', (e) => this.handleQuickProfileSubmit(e));
        }

        // Compatibility form submission
        const compatibilityForm = document.getElementById('compatibilityForm');
        if (compatibilityForm) {
            compatibilityForm.addEventListener('submit', (e) => this.handleCompatibilitySubmit(e));
        }
    }

    // ==================== SECTION NAVIGATION ====================

    showSection(section) {
        const sectionMap = {
            'selector': 'sectionSelector',
            'hasRoom': 'hasRoomSection',
            'seeking': 'seekingSection',
            'browseRooms': 'browseRoomsSection',
            'browseSeekers': 'browseSeekersSection',
            'success': 'successSection',
            'messages': 'messagesSection'
        };

        // Handle landing section separately
        const landingSection = document.getElementById('landingSection');

        if (section === 'landing') {
            // Show landing, hide all other sections
            if (landingSection) landingSection.style.display = 'flex';
            document.querySelectorAll('.section-view').forEach(el => {
                el.classList.remove('active');
            });
            this.currentSection = 'landing';
            window.scrollTo({ top: 0, behavior: 'smooth' });
            return;
        }

        // Hide landing section when going to any other section
        if (landingSection) landingSection.style.display = 'none';

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

                // Load data for sections
                if (section === 'browseRooms') {
                    this.loadRooms();
                } else if (section === 'browseSeekers') {
                    this.loadPeople();
                } else if (section === 'hasRoom') {
                    // Load seekers when posting a room so host can see who's looking
                    this.loadRoommateMatches();
                } else if (section === 'selector') {
                    // Load roommate matches for the main matches view
                    this.loadRoommateMatches();
                } else if (section === 'messages') {
                    this.loadConversations();
                }
            }
        }

        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    // ==================== LOAD ROOMS ====================

    async loadRooms() {
        const grid = document.getElementById('roomsGrid');
        const emptyState = document.getElementById('emptyState');
        const resultsCount = document.getElementById('resultsCount');

        if (!grid) return;

        // Show loading
        grid.innerHTML = '<p class="col-span-2 text-center text-gray-500 py-8">Loading rooms...</p>';

        try {
            // Get rooms from API
            const rooms = await this.getRooms();
            this.allRooms = rooms;
            this.filteredRooms = rooms;

            this.renderRooms();
        } catch (error) {
            console.error('Error loading rooms:', error);
            grid.innerHTML = '<p class="col-span-2 text-center text-red-500 py-8">Failed to load rooms</p>';
        }
    }

    async getRooms() {
        if (this.api && this.api.initialized) {
            try {
                const rooms = await this.api.getRoomPosts({ limit: 50 });
                if (rooms && rooms.length > 0) {
                    return rooms;
                }
            } catch (e) {
                console.log('API error, returning empty:', e);
            }
        }
        return [];
    }

    renderRooms() {
        const grid = document.getElementById('roomsGrid');
        const emptyState = document.getElementById('emptyState');
        const resultsCount = document.getElementById('resultsCount');

        if (this.filteredRooms.length === 0) {
            grid.classList.add('hidden');
            emptyState.classList.remove('hidden');
            resultsCount.textContent = 'No rooms found';
            return;
        }

        grid.classList.remove('hidden');
        emptyState.classList.add('hidden');
        resultsCount.textContent = `${this.filteredRooms.length} room${this.filteredRooms.length !== 1 ? 's' : ''} available`;

        grid.innerHTML = this.filteredRooms.map(room => this.createRoomCard(room)).join('');
    }

    createRoomCard(room) {
        const photoUrl = room.room_photos?.[0] || room.photo_url || 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=400&h=300&fit=crop';
        const rent = room.room_rent || room.rent || 0;
        const location = room.room_location || room.location || 'Location not specified';
        const description = room.room_description || room.description || 'No description provided';
        const availableDate = room.room_available_date || room.available_date;
        const formattedDate = availableDate ? this.formatDate(availableDate) : 'Available Now';
        const hostName = room.name || 'Host';

        // Check if this is the current user's own room
        const isOwnRoom = this.currentUser && room.user_id === this.currentUser.id;

        return `
            <div class="room-card">
                <img src="${photoUrl}" alt="Room photo" class="room-image" onerror="this.src='https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=400&h=300&fit=crop'">
                <div class="p-5">
                    <div class="flex justify-between items-start mb-2">
                        <span class="room-price">$${rent}/mo</span>
                        <span class="text-sm text-gray-500">${formattedDate}</span>
                    </div>
                    <h3 class="room-location mb-2">${location}</h3>
                    <p class="room-description mb-4">${description}</p>
                    ${isOwnRoom
                        ? `<span class="inline-block w-full text-center py-2 text-gray-500 bg-gray-100 rounded-lg">Your Listing</span>`
                        : `<button onclick="roomPalApp.openContact('${room.user_id}', '${hostName}')" class="btn-primary w-full">Contact ${hostName}</button>`
                    }
                </div>
            </div>
        `;
    }

    // ==================== FILTERS ====================

    applyFilters() {
        const budgetFilter = document.getElementById('budgetFilter')?.value;

        this.filteredRooms = this.allRooms.filter(room => {
            const rent = room.room_rent || room.rent || 0;

            if (budgetFilter) {
                if (budgetFilter === '0-1000' && rent > 1000) return false;
                if (budgetFilter === '1000-1500' && (rent < 1000 || rent > 1500)) return false;
                if (budgetFilter === '1500-2000' && (rent < 1500 || rent > 2000)) return false;
                if (budgetFilter === '2000+' && rent < 2000) return false;
            }

            return true;
        });

        this.renderRooms();
    }

    // ==================== LOAD PEOPLE ====================

    async loadPeople() {
        const grid = document.getElementById('peopleGrid');
        const emptyState = document.getElementById('peopleEmptyState');
        const resultsCount = document.getElementById('peopleResultsCount');

        if (!grid) return;

        // Show loading
        grid.innerHTML = '<p class="col-span-full text-center text-gray-500 py-8">Loading people...</p>';

        try {
            // Get people from API
            const people = await this.getPeople();
            this.allPeople = people;
            this.filteredPeople = people;

            // Check if current user has a profile and show prompt if not
            if (this.currentUser) {
                await this.checkUserProfile();
                if (!this.hasUserProfile) {
                    this.showProfilePrompt();
                }
            }

            this.renderPeople();
        } catch (error) {
            console.error('Error loading people:', error);
            grid.innerHTML = '<p class="col-span-full text-center text-red-500 py-8">Failed to load people</p>';
        }
    }

    async getPeople() {
        if (this.api && this.api.initialized) {
            try {
                const people = await this.api.getSeekerProfiles({ limit: 50 });
                if (people && people.length > 0) {
                    return people;
                }
            } catch (e) {
                console.log('API error, returning empty:', e);
            }
        }
        return [];
    }

    renderPeople() {
        const grid = document.getElementById('peopleGrid');
        const emptyState = document.getElementById('peopleEmptyState');
        const resultsCount = document.getElementById('peopleResultsCount');

        if (this.filteredPeople.length === 0) {
            grid.classList.add('hidden');
            emptyState.classList.remove('hidden');
            resultsCount.textContent = 'No people found';
            return;
        }

        grid.classList.remove('hidden');
        emptyState.classList.add('hidden');
        resultsCount.textContent = `${this.filteredPeople.length} ${this.filteredPeople.length === 1 ? 'person' : 'people'} looking`;

        grid.innerHTML = this.filteredPeople.map(person => this.createPersonCard(person)).join('');
    }

    createPersonCard(person) {
        const avatarUrl = person.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(person.name || 'User')}&background=6366f1&color=fff&size=160`;
        const name = person.name || 'Anonymous';
        const age = person.age ? `, ${person.age}` : '';
        const location = person.preferred_areas?.[0] || person.location || 'Location flexible';
        const budgetMin = person.budget_min || 0;
        const budgetMax = person.budget_max || 0;
        const budgetText = budgetMin && budgetMax ? `$${budgetMin} - $${budgetMax}/mo` : (budgetMax ? `Up to $${budgetMax}/mo` : 'Budget flexible');
        const bio = person.bio || 'Looking for a great roommate situation!';
        const truncatedBio = bio.length > 100 ? bio.substring(0, 100) + '...' : bio;
        const moveInDate = person.move_in_date ? this.formatDate(person.move_in_date) : 'Flexible';

        // Extract lifestyle for badges
        const lifestyle = person.lifestyle || {};
        const scores = person.compatibility_scores || {};
        const badges = this.getLifestyleBadges(lifestyle, scores);
        const badgesHtml = badges.map(b =>
            `<span class="lifestyle-badge">${b.icon} ${b.label}</span>`
        ).join('');

        return `
            <div class="person-card">
                <div class="person-avatar-section">
                    <img src="${avatarUrl}" alt="${name}" class="person-avatar" onerror="this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&background=6366f1&color=fff&size=160'">
                </div>
                <div class="person-info">
                    <h3 class="person-name">${name}${age}</h3>
                    <div class="person-details">
                        <span class="person-detail">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
                            </svg>
                            ${location}
                        </span>
                        <span class="person-detail">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                            </svg>
                            ${budgetText}
                        </span>
                        <span class="person-detail">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                            </svg>
                            ${moveInDate}
                        </span>
                    </div>
                    ${badgesHtml ? `<div class="lifestyle-badges">${badgesHtml}</div>` : ''}
                    <p class="person-bio">${truncatedBio}</p>
                    ${this.currentUser && person.user_id === this.currentUser.id
                        ? `<span class="inline-block w-full text-center py-2 text-gray-500 bg-gray-100 rounded-lg text-sm">Your Profile</span>`
                        : `<button onclick="roomPalApp.openPersonContact('${person.user_id}', '${name.replace(/'/g, "\\'")}')" class="btn-connect">Connect</button>`
                    }
                </div>
            </div>
        `;
    }

    getLifestyleBadges(lifestyle, scores) {
        const badges = [];

        // Cleanliness badge
        if (scores.cleanliness >= 7) {
            badges.push({ icon: '🧹', label: 'Clean' });
        } else if (scores.cleanliness && scores.cleanliness <= 4) {
            badges.push({ icon: '🪴', label: 'Relaxed' });
        }

        // Sleep schedule
        if (lifestyle.sleepSchedule?.toLowerCase().includes('night') || lifestyle.sleepSchedule?.toLowerCase().includes('late')) {
            badges.push({ icon: '🌙', label: 'Night Owl' });
        } else if (lifestyle.sleepSchedule?.toLowerCase().includes('early') || lifestyle.sleepSchedule?.toLowerCase().includes('morning')) {
            badges.push({ icon: '☀️', label: 'Early Bird' });
        }

        // Smoking
        if (lifestyle.smoking === 'Never' || lifestyle.smoking === 'No' || lifestyle.smoking === 'Non-Smoker') {
            badges.push({ icon: '🚭', label: 'Non-Smoker' });
        }

        // Pets
        if (lifestyle.pets?.toLowerCase().includes('cat') || lifestyle.pets?.toLowerCase().includes('dog') || lifestyle.hasPets) {
            badges.push({ icon: '🐾', label: 'Pet Owner' });
        } else if (scores.petPolicy >= 7 || lifestyle.petsOk) {
            badges.push({ icon: '🐱', label: 'Pets OK' });
        } else if (scores.petPolicy !== undefined && scores.petPolicy <= 3) {
            badges.push({ icon: '🚫', label: 'No Pets' });
        }

        // Social level
        if (scores.socialLevel >= 7) {
            badges.push({ icon: '🎉', label: 'Social' });
        } else if (scores.socialLevel && scores.socialLevel <= 3) {
            badges.push({ icon: '📚', label: 'Quiet' });
        }

        return badges;
    }

    applyPeopleFilters() {
        const budgetFilter = document.getElementById('peopleBudgetFilter')?.value;
        const cleanFilter = document.getElementById('cleanFilter')?.value;
        const scheduleFilter = document.getElementById('scheduleFilter')?.value;
        const smokingFilter = document.getElementById('smokingFilter')?.value;
        const petsFilter = document.getElementById('petsFilter')?.value;

        this.filteredPeople = this.allPeople.filter(person => {
            const budgetMax = person.budget_max || 0;
            const lifestyle = person.lifestyle || {};
            const scores = person.compatibility_scores || {};

            // Budget filter
            if (budgetFilter) {
                if (budgetFilter === '0-800' && budgetMax > 800) return false;
                if (budgetFilter === '800-1200' && (budgetMax < 800 || budgetMax > 1200)) return false;
                if (budgetFilter === '1200-1600' && (budgetMax < 1200 || budgetMax > 1600)) return false;
                if (budgetFilter === '1600+' && budgetMax < 1600) return false;
            }

            // Cleanliness filter
            if (cleanFilter) {
                const cleanliness = scores.cleanliness || 5;
                if (cleanFilter === 'clean' && cleanliness < 7) return false;
                if (cleanFilter === 'relaxed' && cleanliness > 4) return false;
            }

            // Schedule filter
            if (scheduleFilter) {
                const schedule = (lifestyle.sleepSchedule || '').toLowerCase();
                if (scheduleFilter === 'night' && !schedule.includes('night') && !schedule.includes('late')) return false;
                if (scheduleFilter === 'early' && !schedule.includes('early') && !schedule.includes('morning')) return false;
            }

            // Smoking filter
            if (smokingFilter === 'no') {
                const smoking = lifestyle.smoking || '';
                if (smoking !== 'Never' && smoking !== 'No' && smoking !== 'Non-Smoker' && smoking !== '') return false;
            }

            // Pets filter
            if (petsFilter) {
                const petPolicy = scores.petPolicy || 5;
                const petsOk = lifestyle.petsOk;
                if (petsFilter === 'ok' && petPolicy < 5 && !petsOk) return false;
                if (petsFilter === 'no' && (petPolicy > 5 || petsOk)) return false;
            }

            return true;
        });

        this.renderPeople();
    }

    openPersonContact(personId, personName) {
        if (!this.currentUser) {
            alert('Please log in to connect with people.');
            window.location.href = 'login.html';
            return;
        }

        this.contactRoomId = personId;
        this.contactHostName = personName;

        // Update modal title
        const modalTitle = document.getElementById('contactModalTitle');
        if (modalTitle) {
            modalTitle.textContent = `Connect with ${personName}`;
        }

        // Update placeholder
        const messageInput = document.querySelector('#messageForm textarea[name="message"]');
        if (messageInput) {
            messageInput.placeholder = `Hi ${personName}! I have a room available that might interest you...`;
        }

        const recipientEl = document.getElementById('messageRecipient');
        if (recipientEl) {
            const person = this.allPeople.find(p => p.id === personId);
            const avatarUrl = person?.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(personName)}&background=6366f1&color=fff&size=80`;

            recipientEl.innerHTML = `
                <img src="${avatarUrl}" alt="${personName}" class="w-12 h-12 rounded-full object-cover" onerror="this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(personName)}&background=6366f1&color=fff&size=80'">
                <div>
                    <p class="font-medium text-gray-900">${personName}</p>
                    <p class="text-sm text-gray-500">Looking for a room</p>
                </div>
            `;
        }

        const modal = document.getElementById('messageModal');
        if (modal) {
            modal.classList.remove('hidden');
            modal.classList.add('flex');
        }
    }

    // ==================== FORM HANDLERS ====================

    async handleRoomFormSubmit(e) {
        e.preventDefault();

        // Check login
        if (!this.currentUser) {
            alert('Please log in to post a room.');
            window.location.href = 'login.html';
            return;
        }

        const form = e.target;
        const formData = new FormData(form);

        const roomData = {
            room_location: formData.get('room_location'),
            room_rent: parseInt(formData.get('room_rent')),
            room_available_date: formData.get('room_available_date'),
            room_description: formData.get('room_description'),
            room_type: formData.get('room_type'),
            room_photos: this.uploadedPhoto ? [this.uploadedPhoto] : [],
            name: this.currentUser?.firstName || 'Host'
        };

        // Show loading
        const submitBtn = form.querySelector('button[type="submit"]');
        const originalText = submitBtn.textContent;
        submitBtn.textContent = 'Posting...';
        submitBtn.disabled = true;

        try {
            if (this.api && this.api.initialized) {
                const result = await this.api.saveRoomPost(roomData);
                if (!result.success) {
                    throw new Error(result.error || 'Failed to post room');
                }
            } else {
                // Save locally as fallback
                const localRooms = JSON.parse(localStorage.getItem('localRooms') || '[]');
                roomData.id = 'room_' + Date.now();
                roomData.created_at = new Date().toISOString();
                localRooms.push(roomData);
                localStorage.setItem('localRooms', JSON.stringify(localRooms));
            }

            // Show success
            form.reset();
            this.uploadedPhoto = null;
            const photoPreview = document.getElementById('photoPreview');
            if (photoPreview) photoPreview.innerHTML = '';
            this.showSection('success');

        } catch (error) {
            console.error('Error posting room:', error);
            this.showToast('Failed to post room. Please try again.', 'error');
        } finally {
            submitBtn.textContent = originalText;
            submitBtn.disabled = false;
        }
    }

    handlePhotoUpload(e, previewId) {
        const files = e.target.files;
        if (!files.length) return;

        const file = files[0];
        const reader = new FileReader();
        reader.onload = (event) => {
            this.uploadedPhoto = event.target.result;
            const previewEl = document.getElementById(previewId);
            if (previewEl) {
                previewEl.innerHTML = `
                    <img src="${event.target.result}" class="w-32 h-24 object-cover rounded-lg">
                `;
            }
        };
        reader.readAsDataURL(file);
    }

    // ==================== CONTACT MODAL ====================

    openContact(roomId, hostName) {
        if (!this.currentUser) {
            alert('Please log in to contact hosts.');
            window.location.href = 'login.html';
            return;
        }

        this.contactRoomId = roomId;
        this.contactHostName = hostName;

        // Update placeholder
        const messageInput = document.querySelector('#messageForm textarea[name="message"]');
        if (messageInput) {
            messageInput.placeholder = "Hi! I'm interested in your room...";
        }

        const recipientEl = document.getElementById('messageRecipient');
        if (recipientEl) {
            recipientEl.innerHTML = `
                <div class="w-10 h-10 bg-indigo-100 rounded-full flex items-center justify-center">
                    <svg class="w-5 h-5 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                    </svg>
                </div>
                <div>
                    <p class="font-medium text-gray-900">${hostName}</p>
                    <p class="text-sm text-gray-500">Room host</p>
                </div>
            `;
        }

        const modal = document.getElementById('messageModal');
        if (modal) {
            modal.classList.remove('hidden');
            modal.classList.add('flex');
        }
    }

    closeContactModal() {
        const modal = document.getElementById('messageModal') || document.getElementById('contactModal');
        if (modal) {
            modal.classList.add('hidden');
            modal.classList.remove('flex');
        }
    }

    async handleContactSubmit(e) {
        e.preventDefault();

        const form = e.target;
        const message = form.querySelector('textarea[name="message"]').value;

        const submitBtn = form.querySelector('button[type="submit"]');
        const originalText = submitBtn.textContent;
        submitBtn.textContent = 'Sending...';
        submitBtn.disabled = true;

        try {
            if (this.api && this.api.initialized) {
                const result = await this.api.sendMessage(this.contactRoomId, message);
                if (!result.success) {
                    throw new Error(result.error || 'Failed to send message');
                }
            }

            this.showToast('Message sent!', 'success');
            this.closeContactModal();
            form.reset();
        } catch (error) {
            console.error('Error sending message:', error);
            this.showToast(error.message || 'Failed to send message', 'error');
        } finally {
            submitBtn.textContent = originalText;
            submitBtn.disabled = false;
        }
    }

    // ==================== PROFILE FORM ====================

    async checkUserProfile() {
        if (!this.currentUser || !this.api || !this.api.initialized) {
            return false;
        }

        try {
            const profiles = await this.api.getSeekerProfiles({ limit: 100 });
            const userProfile = profiles.find(p => p.user_id === this.currentUser.id);
            this.hasUserProfile = !!userProfile;
            return this.hasUserProfile;
        } catch (e) {
            console.log('Could not check profile:', e);
            return false;
        }
    }

    showProfilePrompt() {
        const prompt = document.getElementById('createProfilePrompt');
        if (prompt && this.currentUser && !this.hasUserProfile) {
            prompt.classList.remove('hidden');
        }
    }

    hideProfilePrompt() {
        const prompt = document.getElementById('createProfilePrompt');
        if (prompt) {
            prompt.classList.add('hidden');
        }
    }

    toggleProfileForm() {
        const form = document.getElementById('quickProfileForm');
        const toggleText = document.getElementById('profileFormToggleText');

        if (form.classList.contains('hidden')) {
            form.classList.remove('hidden');
            toggleText.textContent = 'Hide Form';
        } else {
            form.classList.add('hidden');
            toggleText.textContent = 'Show Form';
        }
    }

    selectScore(type, value) {
        this.profileFormData[type] = value;

        // Update UI
        const selectorId = type === 'cleanliness' ? 'cleanlinessSelector' : 'socialSelector';
        const buttons = document.querySelectorAll(`#${selectorId} .score-btn`);
        buttons.forEach(btn => {
            const btnScore = parseInt(btn.dataset.score);
            if (btnScore === value) {
                btn.classList.add('selected');
            } else {
                btn.classList.remove('selected');
            }
        });
    }

    selectOption(type, value) {
        this.profileFormData[type] = value;

        // Update UI - find parent container
        let container;
        if (type === 'sleep') {
            container = document.querySelector('button[data-value="Early Bird"]')?.parentElement;
        } else if (type === 'smoking') {
            container = document.querySelector('button[data-value="Non-Smoker"]')?.parentElement;
        } else if (type === 'pets') {
            container = document.querySelector('button[data-value="Have Pets"]')?.parentElement;
        }

        if (container) {
            container.querySelectorAll('.option-btn').forEach(btn => {
                if (btn.dataset.value === value) {
                    btn.classList.add('selected');
                } else {
                    btn.classList.remove('selected');
                }
            });
        }
    }

    async handleQuickProfileSubmit(e) {
        e.preventDefault();

        if (!this.currentUser) {
            alert('Please log in to create a profile.');
            window.location.href = 'login.html';
            return;
        }

        const form = e.target;
        const formData = new FormData(form);

        const profileData = {
            name: this.currentUser?.user_metadata?.first_name || this.currentUser?.email?.split('@')[0] || 'Anonymous',
            preferred_areas: formData.get('preferred_areas') ? formData.get('preferred_areas').split(',').map(s => s.trim()).filter(Boolean) : [],
            budget_min: parseInt(formData.get('budget_min')) || null,
            budget_max: parseInt(formData.get('budget_max')) || null,
            move_in_date: formData.get('move_in_date') || null,
            bio: formData.get('bio') || '',
            lifestyle: {
                sleepSchedule: this.profileFormData.sleep,
                smoking: this.profileFormData.smoking,
                pets: this.profileFormData.pets,
                petsOk: this.profileFormData.pets === 'Pets OK' || this.profileFormData.pets === 'Have Pets',
                hasPets: this.profileFormData.pets === 'Have Pets'
            },
            compatibility_scores: {
                cleanliness: this.profileFormData.cleanliness,
                socialLevel: this.profileFormData.social,
                petPolicy: this.profileFormData.pets === 'No Pets' ? 1 : (this.profileFormData.pets === 'Pets OK' || this.profileFormData.pets === 'Have Pets' ? 8 : 5)
            }
        };

        const submitBtn = form.querySelector('button[type="submit"]');
        const originalText = submitBtn.textContent;
        submitBtn.textContent = 'Creating Profile...';
        submitBtn.disabled = true;

        try {
            if (this.api && this.api.initialized) {
                const result = await this.api.saveSeekerProfile(profileData);
                if (!result.success) {
                    throw new Error(result.error || 'Failed to create profile');
                }
            }

            this.hasUserProfile = true;
            this.hideProfilePrompt();
            this.showToast('Profile created! Finding your matches...', 'success');

            // Navigate to matches page and load matches
            this.showSection('selector');
            await this.loadRoommateMatches();

        } catch (error) {
            console.error('Error creating profile:', error);
            this.showToast(error.message || 'Failed to create profile. Please try again.', 'error');
        } finally {
            submitBtn.textContent = originalText;
            submitBtn.disabled = false;
        }
    }

    // ==================== UTILITIES ====================

    formatDate(dateStr) {
        if (!dateStr) return 'Available Now';
        const date = new Date(dateStr);
        const now = new Date();
        const diffDays = Math.ceil((date - now) / (1000 * 60 * 60 * 24));

        if (diffDays <= 0) return 'Available Now';
        if (diffDays <= 7) return 'This Week';
        if (diffDays <= 14) return 'Next Week';

        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }

    async handleCompatibilitySubmit(e) {
        e.preventDefault();
        const form = e.target;
        const formData = new FormData(form);

        this.profileFormData = {
            ...this.profileFormData,
            sleepSchedule: formData.get('sleepSchedule'),
            cleanliness: formData.get('cleanliness'),
            socialLevel: formData.get('socialLevel'),
            smoking: formData.get('smoking'),
            pets: formData.get('pets')
        };

        closeCompatibilityModal();
        this.showToast('Preferences saved! Finding your matches...', 'success');

        // Navigate to matches page and load matches
        this.showSection('selector');
        await this.loadRoommateMatches();
    }

    showToast(message, type = 'info') {
        const toast = document.createElement('div');
        toast.className = `fixed bottom-4 right-4 px-6 py-3 rounded-lg text-white z-50 ${
            type === 'success' ? 'bg-emerald-500' :
            type === 'error' ? 'bg-red-500' : 'bg-indigo-500'
        }`;
        toast.textContent = message;

        document.body.appendChild(toast);

        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateY(10px)';
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }

    // ==================== MESSAGES ====================

    async loadConversations() {
        if (!this.currentUser) {
            const container = document.getElementById('conversationsList');
            container.innerHTML = `
                <div class="text-center py-12">
                    <p class="text-gray-600 mb-4">Please log in to view your messages</p>
                    <a href="login.html" class="btn-primary">Login</a>
                </div>
            `;
            return;
        }

        if (!this.api || !this.api.initialized) {
            return;
        }

        const container = document.getElementById('conversationsList');
        container.innerHTML = '<div class="text-center py-8"><div class="animate-spin w-8 h-8 border-2 border-indigo-500 border-t-transparent rounded-full mx-auto"></div></div>';

        try {
            const conversations = await this.api.getConversations();

            if (!conversations || conversations.length === 0) {
                container.innerHTML = `
                    <div class="text-center py-12 text-gray-500">
                        <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
                        </svg>
                        <p>No conversations yet</p>
                        <p class="text-sm mt-2">Start by messaging someone from the listings!</p>
                    </div>
                `;
                return;
            }

            container.innerHTML = conversations.map(conv => `
                <div class="conversation-item bg-white rounded-xl p-4 border hover:border-indigo-300 cursor-pointer transition-all" onclick="openChat('${conv.id}', '${conv.other_user_id}', '${conv.other_user_name}')">
                    <div class="flex items-center gap-3">
                        <div class="w-12 h-12 bg-gradient-to-br from-indigo-400 to-purple-500 rounded-full flex items-center justify-center text-white font-semibold text-lg">
                            ${conv.other_user_name ? conv.other_user_name.charAt(0).toUpperCase() : '?'}
                        </div>
                        <div class="flex-1 min-w-0">
                            <div class="flex justify-between items-start">
                                <h3 class="font-semibold text-gray-900 truncate">${conv.other_user_name || 'User'}</h3>
                                <span class="text-xs text-gray-400">${conv.last_message_time ? this.formatMessageTime(conv.last_message_time) : ''}</span>
                            </div>
                            <p class="text-sm text-gray-500 truncate">${conv.last_message || 'No messages yet'}</p>
                        </div>
                    </div>
                </div>
            `).join('');

        } catch (error) {
            console.error('Error loading conversations:', error);
            container.innerHTML = '<div class="text-center py-8 text-red-500">Failed to load conversations</div>';
        }
    }

    formatMessageTime(dateStr) {
        const date = new Date(dateStr);
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);

        if (diffMins < 1) return 'Just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffHours < 24) return `${diffHours}h ago`;
        if (diffDays < 7) return `${diffDays}d ago`;

        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }

    async openChat(conversationId, partnerId, partnerName) {
        this.currentConversationId = conversationId;
        this.currentChatPartner = { id: partnerId, name: partnerName };

        // Hide conversations list, show chat view
        document.getElementById('conversationsList').classList.add('hidden');
        document.getElementById('chatView').classList.remove('hidden');

        // Set partner info
        document.getElementById('chatPartnerInfo').innerHTML = `
            <div class="w-10 h-10 bg-gradient-to-br from-indigo-400 to-purple-500 rounded-full flex items-center justify-center text-white font-semibold">
                ${partnerName ? partnerName.charAt(0).toUpperCase() : '?'}
            </div>
            <span class="font-semibold text-gray-900">${partnerName || 'User'}</span>
        `;

        // Load messages
        await this.loadMessages(conversationId);

        // Setup reply form
        const replyForm = document.getElementById('chatReplyForm');
        replyForm.onsubmit = (e) => this.handleChatReply(e);
    }

    async loadMessages(conversationId) {
        const container = document.getElementById('messagesContainer');
        container.innerHTML = '<div class="text-center py-4"><div class="animate-spin w-6 h-6 border-2 border-indigo-500 border-t-transparent rounded-full mx-auto"></div></div>';

        try {
            const messages = await this.api.getMessages(conversationId);

            if (!messages || messages.length === 0) {
                container.innerHTML = '<div class="text-center py-8 text-gray-500">No messages yet. Say hello!</div>';
                return;
            }

            container.innerHTML = messages.map(msg => {
                const isMe = msg.sender_id === this.currentUser.id;
                return `
                    <div class="flex ${isMe ? 'justify-end' : 'justify-start'}">
                        <div class="${isMe ? 'bg-indigo-500 text-white' : 'bg-gray-100 text-gray-900'} rounded-2xl px-4 py-2 max-w-[75%]">
                            <p>${msg.content}</p>
                            <p class="text-xs ${isMe ? 'text-indigo-200' : 'text-gray-400'} mt-1">${this.formatMessageTime(msg.created_at)}</p>
                        </div>
                    </div>
                `;
            }).join('');

            // Scroll to bottom
            container.scrollTop = container.scrollHeight;

        } catch (error) {
            console.error('Error loading messages:', error);
            container.innerHTML = '<div class="text-center py-4 text-red-500">Failed to load messages</div>';
        }
    }

    async handleChatReply(e) {
        e.preventDefault();
        const form = e.target;
        const input = form.querySelector('input[name="reply"]');
        const message = input.value.trim();

        if (!message || !this.currentChatPartner) return;

        const submitBtn = form.querySelector('button[type="submit"]');
        submitBtn.disabled = true;
        submitBtn.textContent = '...';

        try {
            const result = await this.api.sendMessage(this.currentChatPartner.id, message);

            if (result.success) {
                input.value = '';
                await this.loadMessages(this.currentConversationId);
            } else {
                this.showToast(result.error || 'Failed to send', 'error');
            }
        } catch (error) {
            console.error('Error sending reply:', error);
            this.showToast('Failed to send message', 'error');
        } finally {
            submitBtn.disabled = false;
            submitBtn.textContent = 'Send';
        }
    }

    closeChatView() {
        document.getElementById('chatView').classList.add('hidden');
        document.getElementById('conversationsList').classList.remove('hidden');
        this.currentConversationId = null;
        this.currentChatPartner = null;
    }
}

// Global functions
function showSection(section) {
    if (window.roomPalApp) {
        window.roomPalApp.showSection(section);
    }
}

function closeContactModal() {
    if (window.roomPalApp) {
        window.roomPalApp.closeContactModal();
    }
}

function closeMessageModal() {
    if (window.roomPalApp) {
        window.roomPalApp.closeContactModal();
    }
}

function openChat(conversationId, partnerId, partnerName) {
    if (window.roomPalApp) {
        window.roomPalApp.openChat(conversationId, partnerId, partnerName);
    }
}

function closeChatView() {
    if (window.roomPalApp) {
        window.roomPalApp.closeChatView();
    }
}

function applySmartFilters() {
    if (window.roomPalApp) {
        window.roomPalApp.applySmartFilters();
    }
}

function clearAllFilters() {
    if (window.roomPalApp) {
        window.roomPalApp.clearAllFilters();
    }
}

function showCompatibilityQuestions() {
    const modal = document.getElementById('compatibilityModal');
    if (modal) {
        modal.classList.remove('hidden');
        modal.classList.add('flex');
    }
}

function closeCompatibilityModal() {
    const modal = document.getElementById('compatibilityModal');
    if (modal) {
        modal.classList.add('hidden');
        modal.classList.remove('flex');
    }
}

function createGroup() {
    if (window.roomPalApp) {
        window.roomPalApp.showToast('Group feature coming soon!', 'info');
    }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    window.roomPalApp = new RoomPalApp();
});
