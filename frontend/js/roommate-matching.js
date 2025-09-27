// RoomSync - Revolutionary Roommate Matching JavaScript

class RoomSyncApp {
    constructor() {
        this.currentStep = 1;
        this.userData = {
            preferences: {},
            selectedProperty: null,
            profile: {},
            matches: [],
            compatibility: {
                sleepSchedule: null,
                workSchedule: null,
                cleanlinessLevel: 7,
                organizationStyle: null,
                socialLevel: null,
                guestPolicy: null,
                communicationStyle: null,
                kitchenUsage: null,
                sharedMeals: null,
                commonAreaUsage: null,
                smokingPolicy: null,
                petPolicy: null,
                noiseLevel: null,
                dealBreakers: []
            }
        };
        this.animations = new AnimationManager();
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.initializeAnimations();
        this.loadInitialData();
        this.setupProgressTracking();
    }

    setupEventListeners() {
        // Step navigation
        document.addEventListener('click', (e) => {
            if (e.target.matches('[data-next-step]')) {
                const nextStep = parseInt(e.target.getAttribute('data-next-step'));
                this.nextStep(nextStep);
            }

            // Property selection
            if (e.target.closest('.property-card')) {
                this.selectProperty(e.target.closest('.property-card'));
            }

            // Roommate selection
            if (e.target.closest('.roommate-card')) {
                this.selectRoommate(e.target.closest('.roommate-card'));
            }

            // Social login
            if (e.target.matches('.social-login')) {
                this.handleSocialLogin(e.target.getAttribute('data-provider'));
            }
        });

        // Form inputs
        document.addEventListener('change', (e) => {
            if (e.target.matches('select, input[type="checkbox"], input[type="radio"], input[type="range"]')) {
                this.updateUserPreferences(e.target);
            }
        });

        // Range slider updates
        document.addEventListener('input', (e) => {
            if (e.target.matches('input[type="range"]')) {
                this.updateRangeDisplay(e.target);
                this.updateUserPreferences(e.target);
            }
        });

        // Keyboard navigation
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && e.target.matches('.property-card, .roommate-card')) {
                e.target.click();
            }
        });

        // Scroll effects
        window.addEventListener('scroll', () => {
            this.updateNavigationState();
        });
    }

    nextStep(step) {
        if (!this.validateCurrentStep()) {
            this.showValidationError();
            return;
        }

        // Hide current step with animation
        this.animations.slideOut(document.getElementById(`step${this.currentStep}`));

        // Update progress indicator
        this.updateStepIndicator(this.currentStep, 'completed');

        setTimeout(() => {
            // Hide current step
            document.getElementById(`step${this.currentStep}`).classList.remove('active');

            // Show next step
            this.currentStep = step;
            const nextStepElement = document.getElementById(`step${this.currentStep}`);
            nextStepElement.classList.add('active');

            // Update progress indicator
            this.updateStepIndicator(this.currentStep, 'active');

            // Animate in new step
            this.animations.slideIn(nextStepElement);

            // Scroll to top smoothly
            this.smoothScrollToTop();

            // Load step-specific data
            this.loadStepData(step);
        }, 300);
    }

    validateCurrentStep() {
        switch (this.currentStep) {
            case 1:
                const step1Valid = this.userData.preferences.budget &&
                                  this.userData.preferences.location &&
                                  this.userData.preferences.roomType;
                console.log('Step 1 validation:', {
                    budget: this.userData.preferences.budget,
                    location: this.userData.preferences.location,
                    roomType: this.userData.preferences.roomType,
                    valid: step1Valid
                });
                return step1Valid;
            case 2:
                return this.userData.profile.name || this.userData.profile.socialLogin;
            default:
                return true;
        }
    }

    selectProperty(propertyElement) {
        // Remove previous selections
        document.querySelectorAll('.property-card').forEach(card => {
            card.classList.remove('selected');
        });

        // Add selection with animation
        propertyElement.classList.add('selected');
        this.animations.bounceIn(propertyElement);

        // Store selection
        this.userData.selectedProperty = {
            id: propertyElement.getAttribute('data-property-id'),
            name: propertyElement.querySelector('.property-name')?.textContent,
            price: propertyElement.querySelector('.property-price')?.textContent
        };

        // Enable next button
        this.enableNextButton();
    }

    selectRoommate(roommateElement) {
        roommateElement.classList.toggle('selected');
        this.animations.bounceIn(roommateElement);

        // Update selected roommates array
        const roommateId = roommateElement.getAttribute('data-roommate-id');
        if (roommateElement.classList.contains('selected')) {
            this.userData.matches.push(roommateId);
        } else {
            this.userData.matches = this.userData.matches.filter(id => id !== roommateId);
        }

        // Update UI based on selections
        this.updateMatchingStatus();
    }

    updateUserPreferences(element) {
        const name = element.name || element.id;
        let value;

        if (element.type === 'checkbox') {
            if (name === 'dealBreakers') {
                // Handle deal breakers as an array
                if (!this.userData.compatibility.dealBreakers) {
                    this.userData.compatibility.dealBreakers = [];
                }
                const dealBreakerValue = element.value;
                if (element.checked) {
                    if (!this.userData.compatibility.dealBreakers.includes(dealBreakerValue)) {
                        this.userData.compatibility.dealBreakers.push(dealBreakerValue);
                    }
                } else {
                    const index = this.userData.compatibility.dealBreakers.indexOf(dealBreakerValue);
                    if (index > -1) {
                        this.userData.compatibility.dealBreakers.splice(index, 1);
                    }
                }
                value = this.userData.compatibility.dealBreakers;
            } else {
                value = element.checked;
            }
        } else if (element.type === 'radio') {
            value = element.value;
        } else if (element.type === 'range') {
            value = parseInt(element.value);
        } else {
            value = element.value;
        }

        // Store in appropriate object based on step
        if (this.currentStep === 1) {
            // Step 1: Basic preferences
            if (value && value.toString().trim() !== '') {
                this.userData.preferences[name] = value;
            } else {
                delete this.userData.preferences[name];
            }
        } else if (this.currentStep === 2) {
            // Step 2: Detailed compatibility factors
            if (name === 'dealBreakers') {
                this.userData.compatibility[name] = value;
            } else if (value && value.toString().trim() !== '') {
                this.userData.compatibility[name] = value;
            } else {
                this.userData.compatibility[name] = null;
            }
        }

        console.log('Updated data:', {
            preferences: this.userData.preferences,
            compatibility: this.userData.compatibility
        });

        // Update visual validation feedback
        this.updateValidationFeedback(name, value && value.toString().trim() !== '');

        // Check if all required fields are filled
        if (this.validateCurrentStep()) {
            this.enableNextButton();
            if (this.currentStep === 1) {
                this.generateAIRecommendations();
            } else if (this.currentStep === 2) {
                this.calculateCompatibilityPreview();
            }
        } else {
            this.disableNextButton();
        }
    }

    handleSocialLogin(provider) {
        this.showLoading(true);

        // Simulate social login
        setTimeout(() => {
            this.userData.profile = {
                socialLogin: provider,
                name: provider === 'google' ? 'John Doe' : 'Jane Smith',
                email: provider === 'google' ? 'john@gmail.com' : 'jane@icloud.com',
                avatar: this.generateAvatar(provider)
            };

            this.showLoading(false);
            this.displayUserProfile();
            this.enableNextButton();
        }, 2000);
    }

    generateAIRecommendations() {
        const recommendationsContainer = document.getElementById('ai-recommendations');
        if (!recommendationsContainer) return;

        this.showLoading(true, recommendationsContainer);

        // Simulate AI processing
        setTimeout(() => {
            const properties = this.generatePropertyRecommendations();
            this.displayPropertyRecommendations(properties);
            this.showLoading(false, recommendationsContainer);
        }, 1500);
    }

    generatePropertyRecommendations() {
        const { budget, location, roomType } = this.userData.preferences;

        // Mock AI-generated recommendations based on preferences
        const properties = [
            {
                id: 1,
                name: 'Modern Downtown Apartment',
                price: '$900/mo',
                location: 'Downtown District',
                features: ['Metro Access', 'Gym & Pool', 'Study Rooms'],
                matchScore: 95,
                icon: 'building',
                gradient: 'from-blue-500 to-purple-600'
            },
            {
                id: 2,
                name: 'Cozy University Area',
                price: '$650/mo',
                location: 'University District',
                features: ['Bike Friendly', 'Study Spaces', 'Cafes Nearby'],
                matchScore: 87,
                icon: 'book',
                gradient: 'from-green-500 to-teal-600'
            },
            {
                id: 3,
                name: 'Suburban Family Home',
                price: '$750/mo',
                location: 'Quiet Suburbs',
                features: ['Garden', 'Parking', 'Pet Friendly'],
                matchScore: 82,
                icon: 'home',
                gradient: 'from-orange-500 to-red-600'
            }
        ];

        return properties.sort((a, b) => b.matchScore - a.matchScore);
    }

    displayPropertyRecommendations(properties) {
        const container = document.getElementById('ai-recommendations');
        if (!container) return;

        container.innerHTML = properties.map(property => `
            <div class="property-card glass-card rounded-2xl p-6 text-white cursor-pointer"
                 data-property-id="${property.id}">
                <div class="flex items-center justify-between mb-4">
                    <div class="flex items-center space-x-3">
                        <div class="w-12 h-12 bg-gradient-to-r ${property.gradient} rounded-lg flex items-center justify-center">
                            ${this.getPropertyIcon(property.icon)}
                        </div>
                        <div class="font-semibold text-lg">${property.name}</div>
                    </div>
                    <div class="text-green-300 font-bold">${property.price}</div>
                </div>
                <div class="text-blue-100 text-sm mb-4 space-y-1">
                    <div class="flex items-center space-x-2">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
                        </svg>
                        <span>${property.location}</span>
                    </div>
                    <div class="flex items-center space-x-2 text-xs">
                        ${property.features.map(feature => `<span class="px-2 py-1 bg-white bg-opacity-10 rounded-md">${feature}</span>`).join('')}
                    </div>
                </div>
                <div class="flex justify-between items-center">
                    <div class="text-xs text-blue-200">${property.matchScore}% AI Match Score</div>
                    <div class="w-20 h-2 bg-white bg-opacity-30 rounded-full">
                        <div class="h-2 bg-gradient-to-r from-green-400 to-blue-400 rounded-full match-fill"
                             style="--score-width: ${property.matchScore}%"></div>
                    </div>
                </div>
            </div>
        `).join('');

        // Animate in each card
        container.querySelectorAll('.property-card').forEach((card, index) => {
            setTimeout(() => {
                this.animations.slideInUp(card);
            }, index * 200);
        });
    }

    updateStepIndicator(step, status) {
        const indicators = document.querySelectorAll('.step-indicator');
        const indicator = indicators[step - 1];

        if (status === 'completed') {
            indicator.classList.remove('active');
            indicator.classList.add('completed');
        } else if (status === 'active') {
            indicator.classList.add('active');
        }
    }

    enableNextButton() {
        const nextButton = document.querySelector(`#step${this.currentStep}-continue`);
        const validationMessage = document.querySelector('.validation-message');

        if (nextButton) {
            nextButton.disabled = false;
            nextButton.classList.remove('opacity-50', 'cursor-not-allowed');
            nextButton.classList.add('hover:shadow-lg', 'transform-gpu');
            this.animations.bounceIn(nextButton);
        }

        if (validationMessage) {
            validationMessage.textContent = 'Great! You can continue to the next step';
            validationMessage.classList.remove('text-red-300');
            validationMessage.classList.add('text-green-300');
        }
    }

    disableNextButton() {
        const nextButton = document.querySelector(`#step${this.currentStep}-continue`);
        const validationMessage = document.querySelector('.validation-message');

        if (nextButton) {
            nextButton.disabled = true;
            nextButton.classList.add('opacity-50', 'cursor-not-allowed');
            nextButton.classList.remove('hover:shadow-lg', 'transform-gpu');
        }

        if (validationMessage) {
            validationMessage.textContent = 'Please complete all fields above to continue';
            validationMessage.classList.add('text-blue-300');
            validationMessage.classList.remove('text-green-300');
        }
    }

    updateValidationFeedback(fieldName, isValid) {
        const validationDot = document.querySelector(`[data-field="${fieldName}"]`);
        const validationCheck = document.querySelector(`#${fieldName} + .validation-check`);

        if (validationDot) {
            if (isValid) {
                validationDot.classList.remove('bg-gray-400');
                validationDot.classList.add('bg-green-400');
            } else {
                validationDot.classList.remove('bg-green-400');
                validationDot.classList.add('bg-gray-400');
            }
        }

        if (validationCheck) {
            if (isValid) {
                validationCheck.classList.remove('hidden');
                setTimeout(() => validationCheck.classList.add('animate-fade-in'), 50);
            } else {
                validationCheck.classList.add('hidden');
                validationCheck.classList.remove('animate-fade-in');
            }
        }
    }

    showLoading(show, container = null) {
        if (container) {
            if (show) {
                container.classList.add('loading');
            } else {
                container.classList.remove('loading');
            }
        } else {
            // Global loading state
            document.body.style.cursor = show ? 'wait' : 'default';
        }
    }

    smoothScrollToTop() {
        window.scrollTo({
            top: 0,
            behavior: 'smooth'
        });
    }

    updateNavigationState() {
        const nav = document.querySelector('.premium-nav');
        if (window.scrollY > 50) {
            nav?.classList.add('scrolled');
        } else {
            nav?.classList.remove('scrolled');
        }
    }

    initializeAnimations() {
        // Intersection Observer for scroll animations
        const observerOptions = {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        };

        this.observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    this.animations.revealElement(entry.target);
                }
            });
        }, observerOptions);

        // Observe all animatable elements
        document.querySelectorAll('[class*="animate-"]').forEach(el => {
            this.observer.observe(el);
        });
    }

    loadInitialData() {
        // Load any initial data from localStorage or API
        const savedData = localStorage.getItem('roomsync-user-data');
        if (savedData) {
            this.userData = { ...this.userData, ...JSON.parse(savedData) };
        }
    }

    setupProgressTracking() {
        // Track user progress for analytics
        window.addEventListener('beforeunload', () => {
            localStorage.setItem('roomsync-user-data', JSON.stringify(this.userData));
        });
    }

    showValidationError() {
        // Show validation error with animation
        const errorMessage = document.createElement('div');
        errorMessage.className = 'fixed top-20 left-1/2 transform -translate-x-1/2 bg-red-500 text-white px-6 py-3 rounded-lg shadow-lg z-50';
        errorMessage.textContent = 'Please fill in all required fields before continuing.';

        document.body.appendChild(errorMessage);

        setTimeout(() => {
            errorMessage.remove();
        }, 3000);
    }

    updateMatchingStatus() {
        const selectedCount = this.userData.matches.length;
        const statusElement = document.querySelector('.matching-status');

        if (statusElement) {
            statusElement.textContent = `${selectedCount} matches selected`;
            this.animations.bounceIn(statusElement);
        }
    }

    displayUserProfile() {
        const profileContainer = document.getElementById('user-profile');
        if (!profileContainer || !this.userData.profile) return;

        const avatar = this.userData.profile.avatar;
        profileContainer.innerHTML = `
            <div class="flex items-center space-x-4 glass-card rounded-xl p-4">
                <div class="w-12 h-12 bg-gradient-to-r ${avatar.gradient} rounded-full flex items-center justify-center">
                    ${avatar.icon}
                </div>
                <div>
                    <div class="text-white font-semibold">${this.userData.profile.name}</div>
                    <div class="text-blue-200 text-sm">${this.userData.profile.email}</div>
                </div>
            </div>
        `;
    }

    generateAvatar(provider) {
        const avatarData = {
            google: {
                gradient: 'from-blue-500 to-blue-600',
                icon: this.getUserIcon()
            },
            apple: {
                gradient: 'from-gray-600 to-gray-700',
                icon: this.getUserIcon()
            },
            facebook: {
                gradient: 'from-blue-600 to-blue-700',
                icon: this.getUserIcon()
            }
        };
        return avatarData[provider] || { gradient: 'from-gray-500 to-gray-600', icon: this.getUserIcon() };
    }

    loadStepData(step) {
        switch (step) {
            case 2:
                this.loadProfileDefaults();
                break;
            case 3:
                this.generateRoommateMatches();
                break;
        }
    }

    loadProfileDefaults() {
        // Pre-fill profile defaults based on preferences
        const defaults = {
            lifestyle: ['clean', 'social', 'quiet-study'],
            living: ['shared-spaces', 'cooking-sometimes']
        };

        // Auto-check relevant boxes
        defaults.lifestyle.forEach(id => {
            const checkbox = document.getElementById(id);
            if (checkbox) checkbox.checked = true;
        });
    }

    generateRoommateMatches() {
        // Simulate AI matching process
        const matchingContainer = document.querySelector('.ai-matching-process');
        if (matchingContainer) {
            this.showAIMatchingAnimation();
        }

        setTimeout(() => {
            this.displayFinalMatches();
        }, 3000);
    }

    showAIMatchingAnimation() {
        // Enhanced AI visualization during matching
        const visualization = document.querySelector('.ai-visualization');
        if (visualization) {
            visualization.classList.add('matching-active');
        }
    }

    async displayFinalMatches() {
        console.log('🎯 Loading potential roommate matches...');

        try {
            const matches = await this.generateRoommateRecommendations();
            this.currentMatches = matches;
            this.currentCardIndex = 0;

            // Initialize Tinder-style card stack
            this.initializeCardStack(matches);
            this.setupSwipeGestures();

            console.log(`✅ Loaded ${matches.length} potential matches`);
        } catch (error) {
            console.error('❌ Error loading matches:', error);

            // Show error message to user
            const cardStack = document.getElementById('card-stack');
            if (cardStack) {
                cardStack.innerHTML = `
                    <div class="flex items-center justify-center h-full text-white text-center p-8">
                        <div>
                            <div class="text-4xl mb-4">😔</div>
                            <h3 class="text-xl font-bold mb-2">Oops! Something went wrong</h3>
                            <p class="text-white text-opacity-75 mb-4">We're having trouble loading potential matches right now.</p>
                            <button onclick="window.location.reload()" class="bg-white bg-opacity-20 text-white px-4 py-2 rounded-lg hover:bg-opacity-30 transition-all">
                                Try Again
                            </button>
                        </div>
                    </div>
                `;
            }
        }
    }

    initializeCardStack(matches) {
        const cardStack = document.getElementById('card-stack');
        const cardCounter = document.getElementById('card-counter');

        if (!cardStack) return;

        // Clear existing cards
        cardStack.innerHTML = '';

        // Create cards (show top 3 in stack)
        matches.slice(0, 3).forEach((match, index) => {
            const cardElement = this.createTinderCard(match, index);
            cardStack.appendChild(cardElement);
        });

        // Update counter
        if (cardCounter) {
            cardCounter.textContent = `1 of ${matches.length}`;
        }

        // Initialize current card
        this.currentCard = cardStack.querySelector('.tinder-card');
    }

    async generateRoommateRecommendations() {
        // Try to load profiles from database first, fallback to mock data
        try {
            if (window.roommateAPI) {
                console.log('🔄 Loading roommate profiles from database...');
                const profiles = await window.roommateAPI.getRoommateProfiles({
                    ageMin: 18,
                    ageMax: 35
                });

                if (profiles && profiles.length > 0) {
                    console.log(`✅ Loaded ${profiles.length} profiles from database`);
                    return this.calculateCompatibilityScores(profiles);
                }
            }

            console.log('📝 Using fallback mock data');
        } catch (error) {
            console.error('❌ Error loading profiles from database:', error);
            console.log('📝 Using fallback mock data');
        }

        // Enhanced roommate profiles with comprehensive data for Tinder-style cards (fallback)
        const baseProfiles = [
            {
                id: 1,
                name: 'Sarah',
                lastName: 'Chen',
                occupation: 'Computer Science Student',
                company: 'UC Berkeley',
                age: 22,
                location: 'Berkeley, CA',
                distance: '2.3 miles away',
                avatar: {
                    gradient: 'from-pink-400 via-purple-500 to-indigo-600',
                    icon: this.getUserIcon(),
                    photos: [
                        {
                            url: 'https://images.unsplash.com/photo-1494790108755-2616b612b5bc?w=400&h=600&fit=crop&crop=face',
                            type: 'main',
                            caption: 'Sarah in her favorite coding setup'
                        },
                        {
                            url: 'https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=400&h=600&fit=crop',
                            type: 'hobby',
                            caption: 'Gaming and study space'
                        },
                        {
                            url: 'https://images.unsplash.com/photo-1517816743773-6e0fd518b4a6?w=400&h=600&fit=crop',
                            type: 'lifestyle',
                            caption: 'Study session vibes'
                        },
                        {
                            url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=600&fit=crop',
                            type: 'social',
                            caption: 'Bubble tea adventures'
                        }
                    ]
                },
                personalInfo: {
                    education: 'UC Berkeley - Computer Science',
                    religion: 'Buddhist',
                    politicalViews: 'Liberal',
                    languages: ['English', 'Mandarin', 'Korean'],
                    zodiacSign: 'Gemini',
                    height: "5'4\"",
                    relationshipStatus: 'Single',
                    lookingFor: 'Study Partner & Friend'
                },
                lifestyle: {
                    exercise: 'Yoga & Hiking',
                    diet: 'Vegetarian',
                    drinking: 'Socially',
                    smoking: 'Never',
                    pets: 'Cat Person',
                    sleepSchedule: 'Night Owl (11 PM - 7 AM)',
                    workSchedule: 'Student (Flexible)'
                },
                hobbies: [
                    { name: 'Gaming', icon: '🎮', category: 'entertainment' },
                    { name: 'Coding', icon: '💻', category: 'professional' },
                    { name: 'Anime', icon: '🎭', category: 'entertainment' },
                    { name: 'K-Pop', icon: '🎵', category: 'music' },
                    { name: 'Bubble Tea', icon: '🧋', category: 'food' },
                    { name: 'Photography', icon: '📸', category: 'creative' },
                    { name: 'Meditation', icon: '🧘‍♀️', category: 'wellness' },
                    { name: 'Sci-Fi Books', icon: '📚', category: 'intellectual' }
                ],
                compatibility: {
                    sleepSchedule: 'night-owl',
                    workSchedule: 'student',
                    cleanlinessLevel: 8,
                    organizationStyle: 'organized',
                    socialLevel: 'introvert',
                    guestPolicy: 'occasional',
                    communicationStyle: 'friendly',
                    kitchenUsage: 'moderate-cook',
                    sharedMeals: 'sometimes',
                    commonAreaUsage: 'moderate',
                    smokingPolicy: 'no-smoking',
                    petPolicy: 'ok-with-pets',
                    noiseLevel: 'moderate',
                    dealBreakers: ['smoking', 'parties']
                },
                quickFacts: [
                    { icon: '🎓', text: 'CS Student' },
                    { icon: '🌙', text: 'Night Owl' },
                    { icon: '🧹', text: 'Very Clean' },
                    { icon: '🐱', text: 'Cat Lover' },
                    { icon: '🥬', text: 'Vegetarian' }
                ],
                topCompatibilityFactors: [
                    { name: 'Sleep Schedule', score: 95 },
                    { name: 'Cleanliness', score: 92 },
                    { name: 'Study Habits', score: 88 }
                ],
                verified: true,
                lastActive: '2 hours ago',
                bio: 'CS student who codes by night and games by day. Looking for a clean, quiet study buddy who appreciates good anime and boba runs. Let\'s build something amazing together! 🚀'
            },
            {
                id: 2,
                name: 'Alex',
                lastName: 'Rivera',
                occupation: 'Marketing Manager',
                company: 'TechFlow Inc.',
                age: 26,
                location: 'San Francisco, CA',
                distance: '1.8 miles away',
                avatar: {
                    gradient: 'from-blue-400 via-teal-500 to-green-600',
                    icon: this.getProfessionalIcon(),
                    photos: [
                        {
                            url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=600&fit=crop&crop=face',
                            type: 'main',
                            caption: 'Alex at a marketing conference'
                        },
                        {
                            url: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=600&fit=crop',
                            type: 'hobby',
                            caption: 'Rock climbing adventure'
                        },
                        {
                            url: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&h=600&fit=crop',
                            type: 'lifestyle',
                            caption: 'Sunday brunch vibes'
                        }
                    ]
                },
                personalInfo: {
                    education: 'Stanford - MBA Marketing',
                    religion: 'Catholic',
                    politicalViews: 'Moderate',
                    languages: ['English', 'Spanish'],
                    zodiacSign: 'Leo',
                    height: "5'11\"",
                    relationshipStatus: 'Single',
                    lookingFor: 'Social Roommate & Adventure Buddy'
                },
                lifestyle: {
                    exercise: 'CrossFit & Running',
                    diet: 'Balanced',
                    drinking: 'Regularly',
                    smoking: 'Never',
                    pets: 'Dog Person',
                    sleepSchedule: 'Early Bird (10 PM - 6 AM)',
                    workSchedule: 'Traditional (9-6)'
                },
                hobbies: [
                    { name: 'Cooking', icon: '👨‍🍳', category: 'lifestyle' },
                    { name: 'CrossFit', icon: '🏋️', category: 'fitness' },
                    { name: 'Travel', icon: '✈️', category: 'adventure' },
                    { name: 'Wine Tasting', icon: '🍷', category: 'social' },
                    { name: 'Hiking', icon: '🥾', category: 'outdoor' },
                    { name: 'Salsa Dancing', icon: '💃', category: 'social' },
                    { name: 'Podcasts', icon: '🎧', category: 'intellectual' },
                    { name: 'Board Games', icon: '🎲', category: 'entertainment' }
                ],
                compatibility: {
                    sleepSchedule: 'moderate',
                    workSchedule: 'traditional',
                    cleanlinessLevel: 7,
                    organizationStyle: 'organized',
                    socialLevel: 'extrovert',
                    guestPolicy: 'frequent',
                    communicationStyle: 'chatty',
                    kitchenUsage: 'frequent-cook',
                    sharedMeals: 'love-sharing',
                    commonAreaUsage: 'frequent',
                    smokingPolicy: 'no-smoking',
                    petPolicy: 'love-pets',
                    noiseLevel: 'flexible',
                    dealBreakers: ['smoking', 'messy']
                },
                quickFacts: [
                    { icon: '💼', text: 'Marketing Pro' },
                    { icon: '🌅', text: 'Early Riser' },
                    { icon: '👥', text: 'Social Butterfly' },
                    { icon: '🐕', text: 'Dog Lover' },
                    { icon: '🍳', text: 'Chef' }
                ],
                topCompatibilityFactors: [
                    { name: 'Social Level', score: 90 },
                    { name: 'Cooking', score: 85 },
                    { name: 'Schedule', score: 82 }
                ],
                verified: true,
                lastActive: '1 hour ago',
                bio: 'Marketing manager who loves hosting dinner parties and weekend adventures. Seeking an active, social roommate who enjoys good food and great conversations. Let\'s explore the city together! 🌟'
            },
            {
                id: 3,
                name: 'Maya',
                lastName: 'Patel',
                occupation: 'UX Designer',
                company: 'Creative Studio',
                age: 24,
                location: 'Oakland, CA',
                distance: '3.1 miles away',
                avatar: {
                    gradient: 'from-yellow-400 via-orange-500 to-pink-600',
                    icon: this.getCreativeIcon(),
                    photos: [
                        { gradient: 'from-yellow-400 to-orange-500', type: 'main' },
                        { gradient: 'from-orange-500 to-pink-600', type: 'hobby' },
                        { gradient: 'from-pink-600 to-yellow-400', type: 'lifestyle' }
                    ]
                },
                personalInfo: {
                    education: 'Art Institute - UX Design',
                    religion: 'Hindu',
                    politicalViews: 'Progressive',
                    languages: ['English', 'Hindi', 'Gujarati'],
                    zodiacSign: 'Virgo',
                    height: "5'2\"",
                    relationshipStatus: 'In a relationship',
                    lookingFor: 'Peaceful Co-living Space'
                },
                lifestyle: {
                    exercise: 'Yoga & Pilates',
                    diet: 'Vegan',
                    drinking: 'Rarely',
                    smoking: 'Never',
                    pets: 'Plant Parent Only',
                    sleepSchedule: 'Early Bird (9 PM - 5 AM)',
                    workSchedule: 'Freelance (Flexible)'
                },
                hobbies: [
                    { name: 'Digital Art', icon: '🎨', category: 'creative' },
                    { name: 'Yoga', icon: '🧘‍♀️', category: 'wellness' },
                    { name: 'Plant Care', icon: '🌱', category: 'lifestyle' },
                    { name: 'Meditation', icon: '🙏', category: 'wellness' },
                    { name: 'Photography', icon: '📷', category: 'creative' },
                    { name: 'Tea Ceremony', icon: '🍵', category: 'cultural' },
                    { name: 'Minimalism', icon: '✨', category: 'lifestyle' },
                    { name: 'Indie Music', icon: '🎶', category: 'music' }
                ],
                compatibility: {
                    sleepSchedule: 'early-bird',
                    workSchedule: 'flexible',
                    cleanlinessLevel: 9,
                    organizationStyle: 'minimalist',
                    socialLevel: 'introvert',
                    guestPolicy: 'rare',
                    communicationStyle: 'quiet',
                    kitchenUsage: 'basic-cook',
                    sharedMeals: 'rarely',
                    commonAreaUsage: 'minimal',
                    smokingPolicy: 'no-smoking',
                    petPolicy: 'allergic',
                    noiseLevel: 'quiet',
                    dealBreakers: ['pets', 'loud-music', 'parties']
                },
                quickFacts: [
                    { icon: '🎨', text: 'Creative' },
                    { icon: '🌅', text: 'Early Bird' },
                    { icon: '🧘‍♀️', text: 'Zen Lifestyle' },
                    { icon: '🌱', text: 'Plant Parent' },
                    { icon: '🤫', text: 'Quiet Space' }
                ],
                verified: true,
                lastActive: '30 minutes ago',
                bio: 'Zen UX designer creating beautiful digital experiences. Seeking a peaceful, plant-filled sanctuary for creativity and mindfulness. Perfect for someone who values tranquility and clean aesthetics. 🌿'
            }
        ];

        // Calculate compatibility scores for each profile
        return baseProfiles.map(profile => {
            const compatibilityScores = this.calculateDetailedCompatibility(profile);
            return {
                ...profile,
                ...compatibilityScores
            };
        }).sort((a, b) => b.overall - a.overall);
    }

    getPropertyIcon(iconType) {
        const icons = {
            building: `<svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path>
            </svg>`,
            book: `<svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"></path>
            </svg>`,
            home: `<svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path>
            </svg>`
        };
        return icons[iconType] || icons.building;
    }

    getUserIcon() {
        return `<svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
        </svg>`;
    }

    getProfessionalIcon() {
        return `<svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m8 6V9a2 2 0 00-2-2H10a2 2 0 00-2 2v3.159l5.886 2.943a1 1 0 001.228 0L16 12.159z"></path>
        </svg>`;
    }

    getCreativeIcon() {
        return `<svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zM21 5a2 2 0 00-2-2h-4a2 2 0 00-2 2v12a4 4 0 004 4h4a2 2 0 002-2V5z"></path>
        </svg>`;
    }

    updateRangeDisplay(rangeElement) {
        const value = rangeElement.value;
        const displayElement = document.querySelector('.cleanliness-value');
        if (displayElement) {
            displayElement.textContent = value;
        }
    }

    calculateCompatibilityPreview() {
        // Show a preview of how well-matched the user might be with others
        const preview = document.querySelector('.compatibility-preview');
        if (preview) {
            const completedFactors = Object.values(this.userData.compatibility).filter(v => v !== null && v !== undefined && (Array.isArray(v) ? v.length > 0 : true)).length;
            const totalFactors = Object.keys(this.userData.compatibility).length - 1; // -1 for dealBreakers array
            const completionRate = Math.round((completedFactors / totalFactors) * 100);

            preview.innerHTML = `
                <div class="text-center p-4 bg-blue-500 bg-opacity-20 rounded-lg">
                    <h5 class="text-white font-semibold mb-2">Compatibility Profile: ${completionRate}% Complete</h5>
                    <div class="w-full bg-gray-300 rounded-full h-2">
                        <div class="bg-blue-500 h-2 rounded-full transition-all duration-500" style="width: ${completionRate}%"></div>
                    </div>
                    <p class="text-blue-200 text-sm mt-2">The more details you provide, the better we can match you!</p>
                </div>
            `;
        }
    }

    calculateDetailedCompatibility(profile) {
        const userPrefs = this.userData.compatibility;
        const profilePrefs = profile.compatibility;

        let scores = {
            lifestyle: 0,
            schedule: 0,
            cleanliness: 0,
            social: 0,
            habits: 0,
            dealBreakers: 100
        };

        let totalComparisons = 0;

        // Sleep schedule compatibility
        if (userPrefs.sleepSchedule && profilePrefs.sleepSchedule) {
            const scheduleCompat = this.getScheduleCompatibility(userPrefs.sleepSchedule, profilePrefs.sleepSchedule);
            scores.schedule += scheduleCompat;
            totalComparisons++;
        }

        // Cleanliness level compatibility
        if (userPrefs.cleanlinessLevel && profilePrefs.cleanlinessLevel) {
            const cleanDiff = Math.abs(userPrefs.cleanlinessLevel - profilePrefs.cleanlinessLevel);
            scores.cleanliness = Math.max(0, 100 - (cleanDiff * 15)); // 15 points penalty per level difference
            totalComparisons++;
        }

        // Social level compatibility
        if (userPrefs.socialLevel && profilePrefs.socialLevel) {
            scores.social = userPrefs.socialLevel === profilePrefs.socialLevel ? 100 : 60;
            totalComparisons++;
        }

        // Guest policy compatibility
        if (userPrefs.guestPolicy && profilePrefs.guestPolicy) {
            scores.social += this.getGuestPolicyCompatibility(userPrefs.guestPolicy, profilePrefs.guestPolicy);
            totalComparisons++;
        }

        // Deal breakers check
        if (userPrefs.dealBreakers && userPrefs.dealBreakers.length > 0) {
            const conflicts = this.checkDealBreakers(userPrefs, profilePrefs);
            if (conflicts.length > 0) {
                scores.dealBreakers = Math.max(0, 100 - (conflicts.length * 30)); // Major penalty for deal breakers
            }
        }

        // Calculate weighted overall score
        const weights = {
            lifestyle: 0.25,
            schedule: 0.25,
            cleanliness: 0.20,
            social: 0.15,
            habits: 0.10,
            dealBreakers: 0.05
        };

        let overall = 0;
        Object.keys(weights).forEach(category => {
            overall += scores[category] * weights[category];
        });

        return {
            lifestyle: Math.round(scores.lifestyle || 85),
            schedule: Math.round(scores.schedule || 80),
            cleanliness: Math.round(scores.cleanliness || 85),
            social: Math.round(scores.social || 80),
            habits: Math.round(scores.habits || 85),
            overall: Math.round(overall || 85),
            compatibilityBreakdown: {
                strengths: this.getCompatibilityStrengths(userPrefs, profilePrefs),
                concerns: this.getCompatibilityConcerns(userPrefs, profilePrefs)
            }
        };
    }

    getScheduleCompatibility(userSchedule, profileSchedule) {
        const scheduleMatrix = {
            'early-bird': { 'early-bird': 100, 'moderate': 80, 'night-owl': 40, 'late-night': 20 },
            'moderate': { 'early-bird': 80, 'moderate': 100, 'night-owl': 80, 'late-night': 60 },
            'night-owl': { 'early-bird': 40, 'moderate': 80, 'night-owl': 100, 'late-night': 90 },
            'late-night': { 'early-bird': 20, 'moderate': 60, 'night-owl': 90, 'late-night': 100 }
        };
        return scheduleMatrix[userSchedule]?.[profileSchedule] || 70;
    }

    getGuestPolicyCompatibility(userPolicy, profilePolicy) {
        const guestMatrix = {
            'frequent': { 'frequent': 100, 'occasional': 80, 'rare': 50, 'no-guests': 20 },
            'occasional': { 'frequent': 80, 'occasional': 100, 'rare': 90, 'no-guests': 60 },
            'rare': { 'frequent': 50, 'occasional': 90, 'rare': 100, 'no-guests': 90 },
            'no-guests': { 'frequent': 20, 'occasional': 60, 'rare': 90, 'no-guests': 100 }
        };
        return guestMatrix[userPolicy]?.[profilePolicy] || 70;
    }

    checkDealBreakers(userPrefs, profilePrefs) {
        const conflicts = [];

        userPrefs.dealBreakers.forEach(dealBreaker => {
            switch(dealBreaker) {
                case 'smoking':
                    if (profilePrefs.smokingPolicy !== 'no-smoking') conflicts.push('smoking');
                    break;
                case 'pets':
                    if (profilePrefs.petPolicy === 'love-pets') conflicts.push('pets');
                    break;
                case 'loud-music':
                    if (profilePrefs.noiseLevel === 'lively') conflicts.push('noise');
                    break;
                case 'parties':
                    if (profilePrefs.guestPolicy === 'frequent') conflicts.push('parties');
                    break;
            }
        });

        return conflicts;
    }

    getCompatibilityStrengths(userPrefs, profilePrefs) {
        const strengths = [];

        if (userPrefs.cleanlinessLevel && profilePrefs.cleanlinessLevel) {
            const diff = Math.abs(userPrefs.cleanlinessLevel - profilePrefs.cleanlinessLevel);
            if (diff <= 2) strengths.push('Similar cleanliness standards');
        }

        if (userPrefs.socialLevel === profilePrefs.socialLevel) {
            strengths.push('Compatible social energy levels');
        }

        if (userPrefs.smokingPolicy === profilePrefs.smokingPolicy) {
            strengths.push('Aligned smoking preferences');
        }

        return strengths;
    }

    getCompatibilityConcerns(userPrefs, profilePrefs) {
        const concerns = [];

        if (userPrefs.cleanlinessLevel && profilePrefs.cleanlinessLevel) {
            const diff = Math.abs(userPrefs.cleanlinessLevel - profilePrefs.cleanlinessLevel);
            if (diff > 3) concerns.push('Different cleanliness expectations');
        }

        const conflicts = this.checkDealBreakers(userPrefs, profilePrefs);
        if (conflicts.length > 0) {
            concerns.push('Some deal-breaker conflicts');
        }

        return concerns;
    }

    getScoreColor(score) {
        if (score >= 90) return 'bg-green-500';
        if (score >= 80) return 'bg-yellow-500';
        if (score >= 70) return 'bg-orange-500';
        return 'bg-red-500';
    }

    getScoreTextColor(score) {
        if (score >= 90) return 'text-green-400';
        if (score >= 80) return 'text-yellow-400';
        if (score >= 70) return 'text-orange-400';
        return 'text-red-400';
    }

    openProfileModal(match) {
        const modal = document.createElement('div');
        modal.className = 'fixed inset-0 z-50 flex items-center justify-center p-4 bg-black bg-opacity-50 backdrop-blur-sm';
        modal.innerHTML = `
            <div class="bg-white rounded-3xl max-w-lg w-full max-h-[90vh] overflow-y-auto">
                <!-- Modal Header -->
                <div class="relative p-6 bg-gradient-to-r ${match.avatar.gradient} text-white rounded-t-3xl">
                    <button class="absolute top-4 right-4 w-8 h-8 bg-black bg-opacity-20 rounded-full flex items-center justify-center hover:bg-opacity-30 transition-colors" onclick="this.remove()">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                        </svg>
                    </button>

                    <div class="text-center">
                        <div class="w-24 h-24 bg-white bg-opacity-20 rounded-full mx-auto mb-4 flex items-center justify-center">
                            <div class="text-4xl">${match.avatar.icon}</div>
                        </div>
                        <h2 class="text-2xl font-bold">${match.name} ${match.lastName}</h2>
                        <p class="text-white text-opacity-90">${match.age} • ${match.occupation}</p>
                        <p class="text-white text-opacity-75 text-sm">${match.distance}</p>
                    </div>
                </div>

                <!-- Modal Content -->
                <div class="p-6 space-y-6">
                    <!-- Bio -->
                    <div>
                        <h3 class="font-semibold text-gray-800 mb-2">About Me</h3>
                        <p class="text-gray-600 leading-relaxed">${match.bio}</p>
                    </div>

                    <!-- Hobbies & Interests -->
                    <div>
                        <h3 class="font-semibold text-gray-800 mb-3">Hobbies & Interests</h3>
                        <div class="grid grid-cols-2 gap-2">
                            ${match.hobbies.map(hobby => `
                                <div class="flex items-center space-x-2 p-2 bg-gray-50 rounded-lg">
                                    <span class="text-lg">${hobby.icon}</span>
                                    <span class="text-sm font-medium text-gray-700">${hobby.name}</span>
                                </div>
                            `).join('')}
                        </div>
                    </div>

                    <!-- Lifestyle -->
                    <div>
                        <h3 class="font-semibold text-gray-800 mb-3">Lifestyle</h3>
                        <div class="space-y-2 text-sm">
                            <div class="flex justify-between">
                                <span class="text-gray-600">Exercise:</span>
                                <span class="font-medium">${match.lifestyle.exercise}</span>
                            </div>
                            <div class="flex justify-between">
                                <span class="text-gray-600">Diet:</span>
                                <span class="font-medium">${match.lifestyle.diet}</span>
                            </div>
                            <div class="flex justify-between">
                                <span class="text-gray-600">Sleep Schedule:</span>
                                <span class="font-medium">${match.lifestyle.sleepSchedule}</span>
                            </div>
                            <div class="flex justify-between">
                                <span class="text-gray-600">Pets:</span>
                                <span class="font-medium">${match.lifestyle.pets}</span>
                            </div>
                        </div>
                    </div>

                    <!-- Personal Info -->
                    <div>
                        <h3 class="font-semibold text-gray-800 mb-3">Personal Info</h3>
                        <div class="space-y-2 text-sm">
                            <div class="flex justify-between">
                                <span class="text-gray-600">Education:</span>
                                <span class="font-medium text-right">${match.personalInfo.education}</span>
                            </div>
                            <div class="flex justify-between">
                                <span class="text-gray-600">Languages:</span>
                                <span class="font-medium">${match.personalInfo.languages.join(', ')}</span>
                            </div>
                            <div class="flex justify-between">
                                <span class="text-gray-600">Looking For:</span>
                                <span class="font-medium text-right">${match.personalInfo.lookingFor}</span>
                            </div>
                        </div>
                    </div>

                    <!-- Compatibility Scores -->
                    <div>
                        <h3 class="font-semibold text-gray-800 mb-3">Compatibility</h3>
                        <div class="space-y-3">
                            ${['lifestyle', 'schedule', 'cleanliness', 'social'].map(category => `
                                <div class="flex items-center justify-between">
                                    <span class="text-sm text-gray-600 capitalize">${category}:</span>
                                    <div class="flex items-center space-x-2">
                                        <div class="w-20 h-2 bg-gray-200 rounded-full">
                                            <div class="h-2 ${this.getScoreColor(match[category])} rounded-full" style="width: ${match[category]}%"></div>
                                        </div>
                                        <span class="text-sm font-medium ${this.getScoreTextColor(match[category])}">${match[category]}%</span>
                                    </div>
                                </div>
                            `).join('')}
                        </div>
                    </div>

                    <!-- Action Buttons -->
                    <div class="flex space-x-3 pt-4">
                        <button class="flex-1 bg-red-500 hover:bg-red-600 text-white py-3 px-6 rounded-xl font-medium transition-colors" onclick="window.roomSyncApp.swipeCard('left'); this.closest('.fixed').remove()">
                            Pass
                        </button>
                        <button class="flex-1 bg-green-500 hover:bg-green-600 text-white py-3 px-6 rounded-xl font-medium transition-colors" onclick="window.roomSyncApp.swipeCard('right'); this.closest('.fixed').remove()">
                            Like
                        </button>
                    </div>
                </div>
            </div>
        `;

        document.body.appendChild(modal);

        // Add click outside to close
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.remove();
            }
        });
    }

    createTinderCard(match, stackIndex = 0) {
        const element = document.createElement('div');
        element.className = `tinder-card absolute inset-0 rounded-3xl overflow-hidden cursor-grab transition-all duration-300 shadow-2xl`;
        element.setAttribute('data-roommate-id', match.id);
        element.style.zIndex = 10 - stackIndex;
        element.style.transform = `scale(${1 - stackIndex * 0.05}) translateY(${stackIndex * 8}px)`;
        element.style.opacity = stackIndex === 0 ? 1 : 0.8;

        const compatibilityColor = match.overall >= 90 ? 'text-green-400' : match.overall >= 80 ? 'text-yellow-400' : 'text-orange-400';
        const compatibilityBg = match.overall >= 90 ? 'bg-green-500' : match.overall >= 80 ? 'bg-yellow-500' : 'bg-orange-500';

        // Enhanced photo handling - prioritize real photos over gradients
        const primaryPhoto = match.avatar.photos && match.avatar.photos.length > 0
            ? match.avatar.photos[0]
            : match.avatar;

        const hasRealPhoto = primaryPhoto.url && !primaryPhoto.url.includes('gradient');
        const backgroundImage = hasRealPhoto
            ? `background-image: url('${primaryPhoto.url}'); background-size: cover; background-position: center;`
            : `background: linear-gradient(135deg, ${primaryPhoto.gradient || 'from-blue-500 to-purple-600'});`;

        element.innerHTML = `
            <!-- Card Background with Photo or Gradient -->
            <div class="absolute inset-0 ${hasRealPhoto ? '' : 'bg-gradient-to-br ' + (primaryPhoto.gradient || 'from-blue-500 to-purple-600')}"
                 style="${hasRealPhoto ? backgroundImage : ''}">
                ${hasRealPhoto ? '<div class="absolute inset-0 bg-black bg-opacity-20"></div>' : ''}
            </div>

            <!-- Photo Gallery Indicator -->
            ${match.avatar.photos && match.avatar.photos.length > 1 ? `
                <div class="absolute top-4 left-4 z-20">
                    <div class="flex space-x-1">
                        ${match.avatar.photos.slice(0, 4).map((photo, index) => `
                            <div class="w-2 h-2 rounded-full ${index === 0 ? 'bg-white' : 'bg-white bg-opacity-40'}"></div>
                        `).join('')}
                    </div>
                </div>
            ` : ''}

            <!-- Card Content -->
            <div class="relative h-full flex flex-col">
                <!-- Main Profile Section (Top 65%) -->
                <div class="flex-1 relative p-6 flex flex-col justify-between">
                    <!-- Top Bar with Verification and Online Status -->
                    <div class="flex justify-between items-start mb-4">
                        <div class="flex items-center space-x-2">
                            ${match.verified ? `
                                <div class="w-8 h-8 bg-white bg-opacity-20 rounded-full flex items-center justify-center backdrop-blur-sm border border-white border-opacity-30">
                                    <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                </div>
                            ` : ''}
                            <span class="text-white text-xs bg-black bg-opacity-30 px-2 py-1 rounded-full backdrop-blur-sm border border-white border-opacity-20">
                                ${match.lastActive}
                            </span>
                        </div>
                        <div class="w-12 h-12 ${compatibilityBg} rounded-full flex items-center justify-center text-white font-bold text-lg shadow-xl border-2 border-white border-opacity-30">
                            ${match.overall}
                        </div>
                    </div>

                    <!-- Center Profile Image Area (Only if no real photo) -->
                    ${!hasRealPhoto ? `
                        <div class="flex-1 flex items-center justify-center">
                            <div class="w-32 h-32 bg-white bg-opacity-20 rounded-full flex items-center justify-center backdrop-blur-sm shadow-2xl border border-white border-opacity-30">
                                <div class="text-6xl">${match.avatar.icon}</div>
                            </div>
                        </div>
                    ` : `
                        <!-- Spacer for real photo cards -->
                        <div class="flex-1"></div>
                    `}
                </div>

                <!-- Info Section (Bottom 35%) -->
                <div class="bg-gradient-to-t from-black via-black/80 to-transparent backdrop-blur-md p-6 space-y-4">
                    <!-- Name and Basic Info -->
                    <div class="text-center">
                        <div class="flex items-center justify-center space-x-2 mb-2">
                            <h3 class="text-2xl font-bold text-white">
                                ${match.name}, ${match.age}
                            </h3>
                            ${match.verified ? `
                                <div class="w-6 h-6 bg-blue-500 rounded-full flex items-center justify-center">
                                    <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                </div>
                            ` : ''}
                        </div>
                        <p class="text-white text-opacity-90 text-sm font-medium">
                            ${match.occupation}
                        </p>
                        <p class="text-white text-opacity-75 text-xs">
                            ${match.company} • ${match.distance}
                        </p>
                    </div>

                    <!-- Compatibility Highlights -->
                    <div class="flex justify-center space-x-3 py-2">
                        ${match.topCompatibilityFactors.slice(0, 3).map(factor => `
                            <div class="bg-white bg-opacity-20 rounded-full px-3 py-1 backdrop-blur-sm border border-white border-opacity-30">
                                <span class="text-white text-xs font-medium">${factor.name}: ${factor.score}%</span>
                            </div>
                        `).join('')}
                    </div>

                    <!-- Top Hobbies/Interests -->
                    <div class="flex justify-center space-x-3 py-1">
                        ${match.hobbies.slice(0, 6).map(hobby => `
                            <div class="text-center group">
                                <div class="text-lg bg-white bg-opacity-10 w-8 h-8 rounded-full flex items-center justify-center backdrop-blur-sm border border-white border-opacity-20 group-hover:bg-opacity-20 transition-all">
                                    ${hobby.icon}
                                </div>
                            </div>
                        `).join('')}
                    </div>

                    <!-- Bio Preview -->
                    <div class="text-center">
                        <p class="text-white text-opacity-90 text-sm leading-relaxed line-clamp-2">
                            ${match.bio.length > 80 ? match.bio.substring(0, 80) + '...' : match.bio}
                        </p>
                    </div>

                    <!-- Interaction Hints -->
                    <div class="flex justify-center items-center space-x-4 pt-1">
                        <div class="flex items-center space-x-1 text-white text-opacity-60 text-xs">
                            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 11l5-5m0 0l5 5m-5-5v12"></path>
                            </svg>
                            <span>Tap for details</span>
                        </div>
                        ${match.avatar.photos && match.avatar.photos.length > 1 ? `
                            <div class="flex items-center space-x-1 text-white text-opacity-60 text-xs">
                                <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                                </svg>
                                <span>Tap to browse photos</span>
                            </div>
                        ` : ''}
                    </div>
                </div>
            </div>

            <!-- Swipe Indicators -->
            <div class="absolute top-1/2 left-8 transform -translate-y-1/2 opacity-0 transition-opacity duration-200 swipe-indicator swipe-left">
                <div class="w-20 h-20 border-4 border-red-500 rounded-full flex items-center justify-center bg-red-500 bg-opacity-20">
                    <svg class="w-10 h-10 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M6 18L18 6M6 6l12 12"></path>
                    </svg>
                </div>
            </div>

            <div class="absolute top-1/2 right-8 transform -translate-y-1/2 opacity-0 transition-opacity duration-200 swipe-indicator swipe-right">
                <div class="w-20 h-20 border-4 border-green-500 rounded-full flex items-center justify-center bg-green-500 bg-opacity-20">
                    <svg class="w-10 h-10 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"></path>
                    </svg>
                </div>
            </div>
        `;

        // Add photo cycling functionality for cards with multiple photos
        if (match.avatar.photos && match.avatar.photos.length > 1) {
            let currentPhotoIndex = 0;
            const backgroundDiv = element.querySelector('.absolute.inset-0');
            const photoIndicators = element.querySelectorAll('.absolute.top-4 .w-2.h-2');

            element.addEventListener('click', (e) => {
                // Only cycle photos if clicking on the upper part of the card (photo area)
                const rect = element.getBoundingClientRect();
                const clickY = e.clientY - rect.top;
                const cardHeight = rect.height;

                if (clickY < cardHeight * 0.65) { // Only if clicking in photo area
                    e.stopPropagation();
                    currentPhotoIndex = (currentPhotoIndex + 1) % match.avatar.photos.length;
                    const newPhoto = match.avatar.photos[currentPhotoIndex];

                    // Update background
                    if (newPhoto.url && !newPhoto.url.includes('gradient')) {
                        backgroundDiv.style.backgroundImage = `url('${newPhoto.url}')`;
                        backgroundDiv.style.backgroundSize = 'cover';
                        backgroundDiv.style.backgroundPosition = 'center';
                        backgroundDiv.className = 'absolute inset-0';
                    }

                    // Update photo indicators
                    photoIndicators.forEach((indicator, index) => {
                        if (index === currentPhotoIndex) {
                            indicator.className = 'w-2 h-2 rounded-full bg-white';
                        } else {
                            indicator.className = 'w-2 h-2 rounded-full bg-white bg-opacity-40';
                        }
                    });
                }
            });
        }

        return element;
    }

    setupSwipeGestures() {
        const cardStack = document.getElementById('card-stack');
        const passBtn = document.getElementById('pass-btn');
        const likeBtn = document.getElementById('like-btn');
        const infoBtn = document.getElementById('info-btn');

        if (!cardStack) return;

        let startX, startY, currentX, currentY;
        let isDragging = false;
        let currentCard = null;

        // Button actions
        if (passBtn) {
            passBtn.addEventListener('click', () => this.swipeCard('left'));
        }
        if (likeBtn) {
            likeBtn.addEventListener('click', () => this.swipeCard('right'));
        }
        if (infoBtn) {
            infoBtn.addEventListener('click', () => this.showDetailedProfile());
        }

        // Touch/Mouse events for swiping
        cardStack.addEventListener('mousedown', this.handleStart.bind(this));
        cardStack.addEventListener('touchstart', this.handleStart.bind(this), { passive: false });

        document.addEventListener('mousemove', this.handleMove.bind(this));
        document.addEventListener('touchmove', this.handleMove.bind(this), { passive: false });

        document.addEventListener('mouseup', this.handleEnd.bind(this));
        document.addEventListener('touchend', this.handleEnd.bind(this));

        // Card tap to expand
        cardStack.addEventListener('click', (e) => {
            if (!isDragging && e.target.closest('.tinder-card')) {
                this.showDetailedProfile();
            }
        });
    }

    handleStart(e) {
        const card = e.target.closest('.tinder-card');
        if (!card || card.style.zIndex != '10') return; // Only allow dragging top card

        this.isDragging = true;
        this.currentCard = card;

        const touch = e.touches ? e.touches[0] : e;
        this.startX = touch.clientX;
        this.startY = touch.clientY;
        this.currentX = this.startX;
        this.currentY = this.startY;

        card.style.cursor = 'grabbing';
        card.style.transition = 'none';

        e.preventDefault();
    }

    handleMove(e) {
        if (!this.isDragging || !this.currentCard) return;

        const touch = e.touches ? e.touches[0] : e;
        this.currentX = touch.clientX;
        this.currentY = touch.clientY;

        const deltaX = this.currentX - this.startX;
        const deltaY = this.currentY - this.startY;
        const rotation = deltaX * 0.1; // Subtle rotation

        // Transform the card
        this.currentCard.style.transform = `translateX(${deltaX}px) translateY(${deltaY}px) rotate(${rotation}deg)`;

        // Show swipe indicators
        const leftIndicator = this.currentCard.querySelector('.swipe-left');
        const rightIndicator = this.currentCard.querySelector('.swipe-right');

        if (Math.abs(deltaX) > 50) {
            if (deltaX > 0 && rightIndicator) {
                rightIndicator.style.opacity = Math.min(Math.abs(deltaX) / 150, 1);
                leftIndicator.style.opacity = 0;
            } else if (deltaX < 0 && leftIndicator) {
                leftIndicator.style.opacity = Math.min(Math.abs(deltaX) / 150, 1);
                rightIndicator.style.opacity = 0;
            }
        } else {
            if (leftIndicator) leftIndicator.style.opacity = 0;
            if (rightIndicator) rightIndicator.style.opacity = 0;
        }

        e.preventDefault();
    }

    handleEnd(e) {
        if (!this.isDragging || !this.currentCard) return;

        const deltaX = this.currentX - this.startX;
        const threshold = 100; // Minimum distance for swipe

        this.currentCard.style.cursor = 'grab';

        if (Math.abs(deltaX) > threshold) {
            // Swipe detected
            const direction = deltaX > 0 ? 'right' : 'left';
            this.animateCardExit(this.currentCard, direction);
        } else {
            // Return to center
            this.resetCard(this.currentCard);
        }

        this.isDragging = false;
        this.currentCard = null;
    }

    swipeCard(direction) {
        const topCard = document.querySelector('.tinder-card[style*="z-index: 10"]');
        if (topCard) {
            this.animateCardExit(topCard, direction);
        }
    }

    animateCardExit(card, direction) {
        const exitX = direction === 'right' ? 1000 : -1000;
        const exitRotation = direction === 'right' ? 30 : -30;

        card.style.transition = 'transform 0.3s ease-out, opacity 0.3s ease-out';
        card.style.transform = `translateX(${exitX}px) rotate(${exitRotation}deg)`;
        card.style.opacity = '0';

        // Record the action
        const roommateId = card.getAttribute('data-roommate-id');
        this.recordSwipeAction(roommateId, direction);

        setTimeout(() => {
            card.remove();
            this.showNextCard();
        }, 300);
    }

    resetCard(card) {
        card.style.transition = 'transform 0.2s ease-out';
        card.style.transform = 'translateX(0) translateY(0) rotate(0deg)';

        // Hide indicators
        const indicators = card.querySelectorAll('.swipe-indicator');
        indicators.forEach(indicator => {
            indicator.style.opacity = 0;
        });
    }

    showNextCard() {
        this.currentCardIndex++;
        const cardCounter = document.getElementById('card-counter');

        // Update counter
        if (cardCounter) {
            cardCounter.textContent = `${this.currentCardIndex + 1} of ${this.currentMatches.length}`;
        }

        // Update z-index for remaining cards
        const remainingCards = document.querySelectorAll('.tinder-card');
        remainingCards.forEach((card, index) => {
            card.style.zIndex = 10 - index;
            card.style.transform = `scale(${1 - index * 0.05}) translateY(${index * 8}px)`;
            card.style.opacity = index === 0 ? 1 : 0.8;
        });

        // Load next card if available
        if (this.currentCardIndex + 2 < this.currentMatches.length) {
            const nextMatch = this.currentMatches[this.currentCardIndex + 2];
            const cardStack = document.getElementById('card-stack');
            const newCard = this.createTinderCard(nextMatch, 2);
            cardStack.appendChild(newCard);
        }

        // Check if we've reached the end
        if (this.currentCardIndex >= this.currentMatches.length - 1) {
            setTimeout(() => {
                this.showEndOfCards();
            }, 500);
        }
    }

    async recordSwipeAction(roommateId, direction) {
        const action = direction === 'right' ? 'like' : 'pass';
        console.log(`${action.toUpperCase()} on roommate:`, roommateId);

        // Store user preferences locally
        if (!this.userData.swipeActions) {
            this.userData.swipeActions = [];
        }

        this.userData.swipeActions.push({
            roommateId: roommateId,
            action: action,
            timestamp: new Date().toISOString()
        });

        // Record in database via API
        try {
            if (window.roommateAPI) {
                const result = await window.roommateAPI.recordMatch(roommateId, action);

                if (result.success) {
                    console.log(`✅ Match ${action} recorded in database`);

                    // Show mutual match notification if it's a mutual like
                    if (result.isMutual && action === 'like') {
                        this.showMutualMatchNotification(roommateId);
                        return; // Don't show regular feedback for mutual matches
                    }
                } else {
                    console.error('❌ Failed to record match in database:', result.error);
                }
            }
        } catch (error) {
            console.error('❌ Error recording match:', error);
        }

        // Show regular feedback
        this.showSwipeFeedback(direction);
    }

    showMutualMatchNotification(roommateId) {
        // Find the roommate data
        const roommate = this.currentMatches.find(match => match.id == roommateId);
        if (!roommate) return;

        // Create mutual match overlay
        const overlay = document.createElement('div');
        overlay.className = 'fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center';
        overlay.innerHTML = `
            <div class="bg-white rounded-3xl p-8 mx-4 max-w-sm text-center animate-bounce-in">
                <div class="text-6xl mb-4">🎉</div>
                <h2 class="text-2xl font-bold text-gray-900 mb-2">It's a Match!</h2>
                <p class="text-gray-600 mb-6">You and ${roommate.name} liked each other!</p>
                <div class="flex space-x-4">
                    <button onclick="this.parentElement.parentElement.parentElement.remove()"
                            class="flex-1 bg-gray-200 text-gray-800 py-3 px-6 rounded-xl font-medium hover:bg-gray-300 transition-colors">
                        Keep Browsing
                    </button>
                    <button onclick="this.parentElement.parentElement.parentElement.remove()"
                            class="flex-1 bg-gradient-to-r from-blue-500 to-purple-600 text-white py-3 px-6 rounded-xl font-medium hover:from-blue-600 hover:to-purple-700 transition-all">
                        Send Message
                    </button>
                </div>
            </div>
        `;

        document.body.appendChild(overlay);

        // Auto-remove after 10 seconds
        setTimeout(() => {
            if (overlay.parentNode) {
                overlay.remove();
            }
        }, 10000);
    }

    showSwipeFeedback(direction) {
        const feedback = document.createElement('div');
        feedback.className = `fixed top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 z-50 transition-all duration-500`;
        feedback.innerHTML = `
            <div class="w-20 h-20 rounded-full flex items-center justify-center shadow-2xl ${
                direction === 'right'
                    ? 'bg-green-500 text-white'
                    : 'bg-red-500 text-white'
            }">
                <svg class="w-10 h-10" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    ${direction === 'right'
                        ? '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"></path>'
                        : '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M6 18L18 6M6 6l12 12"></path>'
                    }
                </svg>
            </div>
        `;

        document.body.appendChild(feedback);

        setTimeout(() => {
            feedback.style.transform = 'translate(-50%, -50%) scale(1.2)';
            feedback.style.opacity = '0';
        }, 100);

        setTimeout(() => {
            feedback.remove();
        }, 600);
    }

    showEndOfCards() {
        const cardStack = document.getElementById('card-stack');
        if (!cardStack) return;

        cardStack.innerHTML = `
            <div class="absolute inset-0 flex flex-col items-center justify-center text-center p-6 bg-gradient-to-br from-blue-500 to-purple-600 rounded-3xl">
                <div class="w-24 h-24 bg-white bg-opacity-20 rounded-full flex items-center justify-center mb-6">
                    <svg class="w-12 h-12 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                    </svg>
                </div>
                <h3 class="text-2xl font-bold text-white mb-4">All Caught Up!</h3>
                <p class="text-white text-opacity-90 mb-6 leading-relaxed">
                    You've seen all available roommates. Check back later for new matches or adjust your preferences for more options.
                </p>
                <div class="space-y-3 w-full">
                    <button class="w-full bg-white bg-opacity-20 hover:bg-opacity-30 text-white py-3 px-6 rounded-xl font-medium transition-all" onclick="window.location.reload()">
                        View My Matches
                    </button>
                    <button class="w-full bg-white bg-opacity-10 hover:bg-opacity-20 text-white py-3 px-6 rounded-xl font-medium transition-all" onclick="this.adjustPreferences()">
                        Adjust Preferences
                    </button>
                </div>
            </div>
        `;
    }

    showDetailedProfile() {
        const topCard = document.querySelector('.tinder-card[style*="z-index: 10"]');
        if (!topCard) return;

        const roommateId = parseInt(topCard.getAttribute('data-roommate-id'));
        const match = this.currentMatches.find(m => m.id === roommateId);

        if (match) {
            this.openProfileModal(match);
        }
    }
}

// Animation Manager Class
class AnimationManager {
    slideIn(element) {
        element.style.opacity = '0';
        element.style.transform = 'translateY(30px)';

        setTimeout(() => {
            element.style.transition = 'all 0.6s cubic-bezier(0.23, 1, 0.320, 1)';
            element.style.opacity = '1';
            element.style.transform = 'translateY(0)';
        }, 50);
    }

    slideOut(element) {
        element.style.transition = 'all 0.3s ease-out';
        element.style.opacity = '0';
        element.style.transform = 'translateY(-20px)';
    }

    slideInUp(element) {
        element.style.animation = 'slideInUp 0.6s ease-out forwards';
    }

    bounceIn(element) {
        element.style.animation = 'bounceIn 0.6s ease-out forwards';
    }

    revealElement(element) {
        element.style.opacity = '1';
        element.style.transform = 'translateY(0)';
    }
}

// Initialize the app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.roomSyncApp = new RoomSyncApp();
});

// Global functions for backward compatibility
window.nextStep = (step) => {
    if (window.roomSyncApp) {
        window.roomSyncApp.nextStep(step);
    }
};

window.viewProfile = (roommateId) => {
    console.log('Viewing profile for roommate:', roommateId);
    // TODO: Implement profile modal or page
    alert('Profile viewing will be implemented in the next phase!');
};

window.startChat = (roommateId) => {
    console.log('Starting chat with roommate:', roommateId);
    // TODO: Implement chat system
    alert('Chat system will be implemented in the next phase!');
};

// Export for modules if needed
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { RoomSyncApp, AnimationManager };
}