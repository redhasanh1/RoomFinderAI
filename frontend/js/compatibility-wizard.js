/**
 * Compatibility Wizard - 47-Factor Roommate Matching Questionnaire
 *
 * Features:
 * - Paginated 10-step wizard to prevent overwhelm
 * - Progress tracking with encouragement
 * - Auto-save to localStorage
 * - i18n support
 * - Accessibility (ARIA labels, keyboard navigation)
 * - Validation with helpful error messages
 * - Engagement psychology (progressive disclosure, positive reinforcement)
 *
 * @version 2.0.0
 */

class CompatibilityWizard {
    constructor(options = {}) {
        this.containerId = options.containerId || 'compatibility-wizard';
        this.onComplete = options.onComplete || (() => {});
        this.onStepChange = options.onStepChange || (() => {});

        // Wizard state
        this.currentStepIndex = 0;
        this.answers = this.loadSavedAnswers() || {};
        this.startTime = Date.now();
        this.userId = this.getCurrentUserId();

        // Step configuration (10 steps total)
        this.steps = this.initializeSteps();

        // Auto-save timer
        this.autoSaveTimer = null;

        // Bind methods
        this.handleNext = this.handleNext.bind(this);
        this.handleBack = this.handleBack.bind(this);
        this.handleSkip = this.handleSkip.bind(this);
    }

    /**
     * Initialize all 10 wizard steps with 47 compatibility questions
     */
    initializeSteps() {
        return [
            // Step 0: Welcome
            {
                id: 'welcome',
                title: window.i18n?.t('onboarding.welcome_title') || 'Welcome to RoomPal!',
                subtitle: window.i18n?.t('onboarding.welcome_subtitle') || 'Find your perfect roommate in 5-7 minutes',
                description: window.i18n?.t('onboarding.welcome_message') || 'We\'ll ask about your lifestyle, preferences, and what you\'re looking for.',
                category: null,
                questions: [],
                showProgress: false
            },

            // Step 1: Basic Info
            {
                id: 'basic_info',
                title: window.i18n?.t('profile.basic_info') || 'Basic Information',
                subtitle: 'Tell us about yourself',
                category: 'basic',
                questions: [
                    {
                        id: 'name',
                        type: 'text',
                        label: window.i18n?.t('profile.name') || 'Name',
                        placeholder: 'John Doe',
                        required: true,
                        icon: '👤'
                    },
                    {
                        id: 'age',
                        type: 'number',
                        label: window.i18n?.t('profile.age') || 'Age',
                        min: 18,
                        max: 100,
                        required: true,
                        icon: '🎂'
                    },
                    {
                        id: 'occupation',
                        type: 'text',
                        label: window.i18n?.t('profile.occupation') || 'Occupation',
                        placeholder: 'Software Engineer',
                        required: false,
                        icon: '💼'
                    },
                    {
                        id: 'location',
                        type: 'text',
                        label: window.i18n?.t('profile.location') || 'Location',
                        placeholder: 'San Francisco, CA',
                        required: true,
                        icon: '📍'
                    },
                    {
                        id: 'bio',
                        type: 'textarea',
                        label: window.i18n?.t('profile.bio') || 'Bio',
                        placeholder: window.i18n?.t('profile.bio_placeholder') || 'Tell us a bit about yourself...',
                        required: false,
                        maxLength: 500,
                        icon: '✍️'
                    }
                ]
            },

            // Step 2: Photo Upload
            {
                id: 'photo',
                title: window.i18n?.t('profile.photo_upload') || 'Profile Photo',
                subtitle: window.i18n?.t('profile.photo_tip') || 'Profiles with photos get 10x more matches',
                category: 'photo',
                questions: [
                    {
                        id: 'avatar',
                        type: 'photo',
                        label: 'Upload your photo',
                        required: false,
                        icon: '📸'
                    }
                ],
                skippable: true
            },

            // Step 3: Living Habits (12 questions)
            {
                id: 'living_habits',
                title: window.i18n?.t('compatibility.category_living') || 'Living Habits',
                subtitle: 'How do you live day-to-day?',
                category: 'living_habits',
                questions: [
                    {
                        id: 'cleanliness',
                        type: 'slider',
                        label: window.i18n?.t('compatibility.cleanliness_label') || 'How clean do you keep shared spaces?',
                        min: 1,
                        max: 10,
                        default: 5,
                        labels: [
                            window.i18n?.t('compatibility.cleanliness_relaxed') || 'Relaxed',
                            window.i18n?.t('compatibility.cleanliness_moderate') || 'Moderate',
                            window.i18n?.t('compatibility.cleanliness_spotless') || 'Spotless'
                        ],
                        weight: 'critical',
                        icon: '🧹'
                    },
                    {
                        id: 'cleanlinessImportance',
                        type: 'choice',
                        label: 'How important is cleanliness to you?',
                        options: [
                            { value: 'low', label: 'Not very important', icon: '🤷' },
                            { value: 'medium', label: 'Somewhat important', icon: '👍' },
                            { value: 'high', label: 'Very important', icon: '⭐' }
                        ],
                        default: 'high',
                        icon: '❗'
                    },
                    {
                        id: 'sleepScheduleBedtime',
                        type: 'time',
                        label: window.i18n?.t('compatibility.sleep_bedtime') || 'What time do you usually go to bed?',
                        default: '22:00',
                        weight: 'high',
                        icon: '😴'
                    },
                    {
                        id: 'sleepScheduleWakeup',
                        type: 'time',
                        label: window.i18n?.t('compatibility.sleep_wakeup') || 'What time do you wake up?',
                        default: '07:00',
                        weight: 'high',
                        icon: '⏰'
                    },
                    {
                        id: 'noiseLevel',
                        type: 'slider',
                        label: window.i18n?.t('compatibility.noise_level_label') || 'How quiet do you need your living space?',
                        min: 1,
                        max: 10,
                        default: 5,
                        labels: ['Lively', 'Moderate', 'Library Quiet'],
                        weight: 'high',
                        icon: '🔊'
                    },
                    {
                        id: 'noiseTolerance',
                        type: 'slider',
                        label: 'How tolerant are you of noise?',
                        min: 1,
                        max: 10,
                        default: 5,
                        labels: ['Very Sensitive', 'Moderate', 'Very Tolerant'],
                        icon: '🎧'
                    },
                    {
                        id: 'temperaturePreference',
                        type: 'number',
                        label: 'Preferred room temperature (°C)?',
                        min: 15,
                        max: 30,
                        default: 21,
                        icon: '🌡️'
                    },
                    {
                        id: 'organizationStyle',
                        type: 'slider',
                        label: 'How organized are you?',
                        min: 1,
                        max: 10,
                        default: 5,
                        labels: ['Relaxed', 'Moderate', 'Very Organized'],
                        icon: '📋'
                    },
                    {
                        id: 'commonAreaUsage',
                        type: 'slider',
                        label: 'How often do you use common areas?',
                        min: 1,
                        max: 10,
                        default: 5,
                        labels: ['Rarely', 'Sometimes', 'Very Often'],
                        icon: '🛋️'
                    },
                    {
                        id: 'kitchenUsage',
                        type: 'slider',
                        label: 'How often do you use the kitchen?',
                        min: 1,
                        max: 10,
                        default: 5,
                        labels: ['Rarely', 'Sometimes', 'Daily'],
                        icon: '🍳'
                    },
                    {
                        id: 'bathroomRoutine',
                        type: 'choice',
                        label: 'When do you typically shower/get ready?',
                        options: [
                            { value: 'morning', label: 'Morning', icon: '🌅' },
                            { value: 'evening', label: 'Evening', icon: '🌙' },
                            { value: 'flexible', label: 'Flexible', icon: '🤷' }
                        ],
                        default: 'flexible',
                        icon: '🚿'
                    }
                ]
            },

            // Step 4: Social & Lifestyle (10 questions)
            {
                id: 'social_lifestyle',
                title: window.i18n?.t('compatibility.category_social') || 'Social & Lifestyle',
                subtitle: 'How do you interact at home?',
                category: 'social',
                questions: [
                    {
                        id: 'socialLevel',
                        type: 'slider',
                        label: window.i18n?.t('compatibility.social_level_label') || 'How social are you at home?',
                        min: 1,
                        max: 10,
                        default: 5,
                        labels: ['Prefer Privacy', 'Balanced', 'Very Social'],
                        weight: 'high',
                        icon: '👥'
                    },
                    {
                        id: 'guestFrequency',
                        type: 'slider',
                        label: 'How often do you have guests over?',
                        min: 0,
                        max: 7,
                        default: 2,
                        unit: 'times/week',
                        icon: '🚪'
                    },
                    {
                        id: 'guestOvernightPolicy',
                        type: 'choice',
                        label: window.i18n?.t('compatibility.guest_overnight_label') || 'Overnight guest policy?',
                        options: [
                            { value: 'never', label: 'Never okay', icon: '🚫' },
                            { value: 'ask', label: 'Ask first', icon: '🤝' },
                            { value: 'welcome', label: 'Always welcome', icon: '✅' }
                        ],
                        default: 'ask',
                        weight: 'medium',
                        icon: '🛏️'
                    },
                    {
                        id: 'sharedMeals',
                        type: 'slider',
                        label: 'Interest in sharing meals together?',
                        min: 1,
                        max: 10,
                        default: 5,
                        labels: ['Prefer Separate', 'Occasionally', 'Often'],
                        icon: '🍽️'
                    },
                    {
                        id: 'communicationStyle',
                        type: 'choice',
                        label: 'Communication preference?',
                        options: [
                            { value: 'direct', label: 'Direct & Open', icon: '💬' },
                            { value: 'indirect', label: 'Subtle & Polite', icon: '😊' },
                            { value: 'minimal', label: 'Minimal', icon: '🤐' }
                        ],
                        default: 'direct',
                        icon: '📞'
                    },
                    {
                        id: 'conflictResolution',
                        type: 'choice',
                        label: 'How do you resolve conflicts?',
                        options: [
                            { value: 'discussion', label: 'Talk it out', icon: '💬' },
                            { value: 'mediator', label: 'Need mediator', icon: '🤝' },
                            { value: 'avoid', label: 'Avoid confrontation', icon: '🙈' }
                        ],
                        default: 'discussion',
                        weight: 'medium',
                        icon: '⚖️'
                    },
                    {
                        id: 'privacyNeeds',
                        type: 'slider',
                        label: 'How important is privacy to you?',
                        min: 1,
                        max: 10,
                        default: 7,
                        labels: ['Not Important', 'Moderate', 'Very Important'],
                        icon: '🔒'
                    },
                    {
                        id: 'aloneTimeNeeds',
                        type: 'slider',
                        label: 'How much alone time do you need?',
                        min: 1,
                        max: 10,
                        default: 6,
                        labels: ['Little', 'Moderate', 'Lots'],
                        icon: '🧘'
                    },
                    {
                        id: 'introvertExtrovert',
                        type: 'slider',
                        label: 'Introvert or Extrovert?',
                        min: 1,
                        max: 10,
                        default: 5,
                        labels: ['Introvert', 'Ambivert', 'Extrovert'],
                        icon: '🎭'
                    },
                    {
                        id: 'workFromHomeFrequency',
                        type: 'slider',
                        label: 'How often do you work from home?',
                        min: 0,
                        max: 7,
                        default: 2,
                        unit: 'days/week',
                        icon: '💻'
                    }
                ]
            },

            // Step 5: Food & Kitchen (5 questions)
            {
                id: 'food_kitchen',
                title: window.i18n?.t('compatibility.category_food') || 'Food & Kitchen',
                subtitle: 'Your cooking and eating habits',
                category: 'food',
                questions: [
                    {
                        id: 'cookingFrequency',
                        type: 'slider',
                        label: window.i18n?.t('compatibility.cooking_label') || 'How often do you cook at home?',
                        min: 0,
                        max: 7,
                        default: 5,
                        unit: 'days/week',
                        weight: 'medium',
                        icon: '🍳'
                    },
                    {
                        id: 'cuisinePreferences',
                        type: 'multi_select',
                        label: window.i18n?.t('compatibility.cuisine_label') || 'What cuisines do you enjoy?',
                        options: [
                            'Italian', 'Chinese', 'Mexican', 'Indian',
                            'Mediterranean', 'Japanese', 'Thai', 'American',
                            'Middle Eastern', 'Other'
                        ],
                        icon: '🌍'
                    },
                    {
                        id: 'dietaryRestrictions',
                        type: 'multi_select',
                        label: window.i18n?.t('compatibility.dietary_label') || 'Dietary preferences?',
                        options: [
                            'None', 'Vegetarian', 'Vegan', 'Halal', 'Kosher',
                            'Gluten-Free', 'Lactose-Free', 'Pescatarian'
                        ],
                        weight: 'medium',
                        icon: '🥗'
                    },
                    {
                        id: 'foodSharingPolicy',
                        type: 'choice',
                        label: 'Food sharing policy?',
                        options: [
                            { value: 'never', label: 'Keep separate', icon: '🚫' },
                            { value: 'ask', label: 'Ask first', icon: '🤝' },
                            { value: 'share', label: 'Happy to share', icon: '✅' }
                        ],
                        default: 'ask',
                        icon: '🍎'
                    },
                    {
                        id: 'kitchenCleanupTiming',
                        type: 'choice',
                        label: 'When do you clean up after cooking?',
                        options: [
                            { value: 'immediate', label: 'Immediately', icon: '⚡' },
                            { value: 'daily', label: 'End of day', icon: '🌙' },
                            { value: 'flexible', label: 'Flexible', icon: '🤷' }
                        ],
                        default: 'immediate',
                        weight: 'medium',
                        icon: '🧽'
                    }
                ]
            },

            // Step 6: Health & Habits (8 questions)
            {
                id: 'health_habits',
                title: window.i18n?.t('compatibility.category_health') || 'Health & Habits',
                subtitle: 'Lifestyle and health preferences',
                category: 'health',
                questions: [
                    {
                        id: 'smokingPolicy',
                        type: 'choice',
                        label: window.i18n?.t('compatibility.smoking_label') || 'Smoking preference?',
                        options: [
                            { value: 'no_smoking', label: 'No smoking anywhere', icon: '🚭' },
                            { value: 'outside_only', label: 'Outside only', icon: '🏞️' },
                            { value: 'smoking_ok', label: 'Smoking is fine', icon: '🚬' }
                        ],
                        default: 'no_smoking',
                        weight: 'critical',
                        icon: '🚭'
                    },
                    {
                        id: 'drinkingFrequency',
                        type: 'slider',
                        label: 'How often do you drink alcohol?',
                        min: 0,
                        max: 7,
                        default: 1,
                        unit: 'days/week',
                        icon: '🍷'
                    },
                    {
                        id: 'substancePolicy',
                        type: 'choice',
                        label: 'Substance use policy?',
                        options: [
                            { value: 'none', label: 'No substances', icon: '🚫' },
                            { value: 'occasional', label: 'Occasional/Medical', icon: '⚕️' },
                            { value: 'open', label: 'Open-minded', icon: '✅' }
                        ],
                        default: 'none',
                        weight: 'high',
                        icon: '💊'
                    },
                    {
                        id: 'petPolicy',
                        type: 'choice',
                        label: window.i18n?.t('compatibility.pets_label') || 'How do you feel about pets?',
                        options: [
                            { value: 'love', label: 'Love pets', icon: '🐕' },
                            { value: 'ok', label: 'Pets are okay', icon: '🐈' },
                            { value: 'allergic', label: 'Allergic / No pets', icon: '🚫' }
                        ],
                        default: 'ok',
                        weight: 'high',
                        icon: '🐾'
                    },
                    {
                        id: 'petAllergies',
                        type: 'multi_select',
                        label: 'Any pet allergies?',
                        options: ['None', 'Dogs', 'Cats', 'Birds', 'Rodents', 'Other'],
                        icon: '🤧'
                    },
                    {
                        id: 'exerciseRoutine',
                        type: 'choice',
                        label: 'Exercise routine?',
                        options: [
                            { value: 'sedentary', label: 'Sedentary', icon: '🛋️' },
                            { value: 'light', label: 'Light (1-2x/week)', icon: '🚶' },
                            { value: 'moderate', label: 'Moderate (3-4x/week)', icon: '🏃' },
                            { value: 'active', label: 'Very Active (5+x/week)', icon: '💪' }
                        ],
                        default: 'moderate',
                        icon: '🏋️'
                    },
                    {
                        id: 'healthConditions',
                        type: 'multi_select',
                        label: 'Any health considerations? (optional, for matching only)',
                        options: ['None', 'Allergies', 'Asthma', 'Sleep Disorder', 'Other'],
                        optional: true,
                        icon: '🏥'
                    }
                ]
            },

            // Step 7: Financial (7 questions)
            {
                id: 'financial',
                title: window.i18n?.t('compatibility.category_financial') || 'Financial',
                subtitle: 'Money matters and responsibilities',
                category: 'financial',
                questions: [
                    {
                        id: 'rentSplitPreference',
                        type: 'choice',
                        label: window.i18n?.t('compatibility.rent_split_label') || 'How should rent be split?',
                        options: [
                            { value: 'equal', label: 'Equal split', icon: '⚖️' },
                            { value: 'proportional', label: 'By room size', icon: '📐' },
                            { value: 'flexible', label: 'Flexible/Negotiable', icon: '🤝' }
                        ],
                        default: 'equal',
                        weight: 'high',
                        icon: '💰'
                    },
                    {
                        id: 'budgetFlexibility',
                        type: 'choice',
                        label: 'Budget flexibility?',
                        options: [
                            { value: 'strict', label: 'Strict budget', icon: '📊' },
                            { value: 'moderate', label: 'Moderate', icon: '💵' },
                            { value: 'flexible', label: 'Very flexible', icon: '💳' }
                        ],
                        default: 'moderate',
                        icon: '💸'
                    },
                    {
                        id: 'utilitiesSplitMethod',
                        type: 'choice',
                        label: 'How to split utilities?',
                        options: [
                            { value: 'equal', label: 'Equal split', icon: '⚖️' },
                            { value: 'usage', label: 'Based on usage', icon: '📊' },
                            { value: 'included', label: 'Included in rent', icon: '💡' }
                        ],
                        default: 'equal',
                        icon: '⚡'
                    },
                    {
                        id: 'sharedExpenses',
                        type: 'choice',
                        label: 'Share household items (toilet paper, soap, etc.)?',
                        options: [
                            { value: true, label: 'Yes, share costs', icon: '✅' },
                            { value: false, label: 'No, buy separately', icon: '🚫' }
                        ],
                        default: true,
                        icon: '🧻'
                    },
                    {
                        id: 'latePaymentTolerance',
                        type: 'choice',
                        label: 'Tolerance for late rent payments?',
                        options: [
                            { value: 'low', label: 'Must be on time', icon: '⏰' },
                            { value: 'moderate', label: 'Few days okay', icon: '📅' },
                            { value: 'high', label: 'Very flexible', icon: '🤷' }
                        ],
                        default: 'low',
                        weight: 'medium',
                        icon: '💳'
                    },
                    {
                        id: 'securityDepositComfort',
                        type: 'choice',
                        label: 'Comfortable with security deposit?',
                        options: [
                            { value: true, label: 'Yes', icon: '✅' },
                            { value: false, label: 'Prefer not', icon: '❌' }
                        ],
                        default: true,
                        icon: '🔐'
                    },
                    {
                        id: 'leaseTermPreference',
                        type: 'choice',
                        label: 'Preferred lease term?',
                        options: [
                            { value: '6months', label: '6 months', icon: '📅' },
                            { value: '12months', label: '12 months', icon: '📆' },
                            { value: 'flexible', label: 'Flexible', icon: '🤷' }
                        ],
                        default: '12months',
                        icon: '📋'
                    }
                ]
            },

            // Step 8: Cultural & Values (5 questions)
            {
                id: 'cultural_values',
                title: window.i18n?.t('compatibility.category_cultural') || 'Cultural & Values',
                subtitle: 'Cultural practices and values',
                category: 'cultural',
                questions: [
                    {
                        id: 'religiousPractices',
                        type: 'multi_select',
                        label: 'Religious practices? (optional)',
                        options: ['None', 'Prayer', 'Meditation', 'Fasting', 'Sabbath', 'Other'],
                        optional: true,
                        icon: '🙏'
                    },
                    {
                        id: 'religiousAccommodations',
                        type: 'multi_select',
                        label: 'Need any religious accommodations?',
                        options: ['None', 'Prayer space', 'Dietary requirements', 'Quiet hours', 'Other'],
                        optional: true,
                        icon: '🕌'
                    },
                    {
                        id: 'culturalCelebrations',
                        type: 'multi_select',
                        label: 'Cultural celebrations you observe?',
                        options: ['Christmas', 'Hanukkah', 'Ramadan', 'Diwali', 'Lunar New Year', 'Other', 'None'],
                        optional: true,
                        icon: '🎉'
                    },
                    {
                        id: 'languagePreferences',
                        type: 'multi_select',
                        label: 'Languages you speak?',
                        options: ['English', 'Spanish', 'Mandarin', 'French', 'German', 'Arabic', 'Hindi', 'Japanese', 'Korean', 'Other'],
                        icon: '🌍'
                    },
                    {
                        id: 'valueAlignment',
                        type: 'multi_select',
                        label: 'Important values to you?',
                        options: ['Respect', 'Honesty', 'Cleanliness', 'Community', 'Independence', 'Sustainability', 'Health', 'Family'],
                        icon: '💎'
                    }
                ]
            },

            // Step 9: Deal Breakers
            {
                id: 'dealbreakers',
                title: window.i18n?.t('compatibility.category_dealbreakers') || 'Deal Breakers',
                subtitle: 'What are your non-negotiables?',
                category: 'dealbreakers',
                questions: [
                    {
                        id: 'dealBreakers',
                        type: 'multi_select',
                        label: window.i18n?.t('compatibility.dealbreakers_label') || 'Select any absolute deal-breakers:',
                        options: [
                            'Smoking',
                            'Pets',
                            'Overnight Guests',
                            'Late Rent Payments',
                            'Excessive Noise',
                            'Poor Cleanliness',
                            'Substance Use',
                            'Different Political Views',
                            'Different Religion'
                        ],
                        icon: '❌'
                    }
                ]
            },

            // Step 10: Completion
            {
                id: 'completion',
                title: '🎉 Congratulations!',
                subtitle: 'Your profile is complete!',
                description: 'We\'re finding your perfect matches now...',
                category: null,
                questions: [],
                showMatches: true
            }
        ];
    }

    /**
     * Initialize and render the wizard
     */
    init() {
        const container = document.getElementById(this.containerId);
        if (!container) {
            console.error(`Container #${this.containerId} not found`);
            return;
        }

        this.container = container;
        this.render();
        this.attachEventListeners();
    }

    /**
     * Render current step
     */
    render() {
        const step = this.steps[this.currentStepIndex];
        const progress = this.calculateProgress();

        this.container.innerHTML = `
            <div class="wizard-container" role="dialog" aria-labelledby="wizard-title" aria-modal="true">
                ${this.currentStepIndex > 0 && this.currentStepIndex < this.steps.length - 1 ? `
                    <div class="wizard-progress" role="progressbar" aria-valuenow="${progress}" aria-valuemin="0" aria-valuemax="100">
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: ${progress}%"></div>
                        </div>
                        <p class="progress-text" aria-live="polite">
                            ${this.getProgressText(progress)}
                        </p>
                    </div>
                ` : ''}

                <div class="wizard-content">
                    <div class="wizard-header">
                        <h1 id="wizard-title" class="wizard-title">${step.title}</h1>
                        ${step.subtitle ? `<p class="wizard-subtitle">${step.subtitle}</p>` : ''}
                        ${step.description ? `<p class="wizard-description">${step.description}</p>` : ''}
                    </div>

                    <div class="wizard-body">
                        ${this.renderStepContent(step)}
                    </div>

                    <div class="wizard-footer">
                        ${this.renderNavigationButtons(step)}
                    </div>
                </div>
            </div>
        `;
    }

    /**
     * Render step-specific content
     */
    renderStepContent(step) {
        if (step.id === 'welcome') {
            return this.renderWelcomeStep();
        } else if (step.id === 'completion') {
            return this.renderCompletionStep();
        } else {
            return this.renderQuestions(step.questions);
        }
    }

    /**
     * Render welcome step
     */
    renderWelcomeStep() {
        return `
            <div class="welcome-content">
                <div class="welcome-icon">🏠</div>
                <ul class="welcome-benefits">
                    <li>✨ Get matched with highly compatible roommates</li>
                    <li>⏱️ Takes only 5-7 minutes to complete</li>
                    <li>🎯 Answer 47 questions for accurate matching</li>
                    <li>🔒 Your information is private and secure</li>
                </ul>
            </div>
        `;
    }

    /**
     * Render completion step
     */
    renderCompletionStep() {
        return `
            <div class="completion-content">
                <div class="completion-animation">
                    <div class="checkmark-circle">
                        <div class="checkmark">✓</div>
                    </div>
                </div>
                <div class="completion-stats">
                    <div class="stat">
                        <span class="stat-number">100%</span>
                        <span class="stat-label">Profile Complete</span>
                    </div>
                    <div class="stat">
                        <span class="stat-number">${this.calculateTimeSpent()}</span>
                        <span class="stat-label">Time Spent</span>
                    </div>
                </div>
                <div class="completion-message">
                    <p>Great job! We're analyzing your preferences to find the perfect matches...</p>
                </div>
            </div>
        `;
    }

    /**
     * Render questions for a step
     */
    renderQuestions(questions) {
        return `
            <form class="wizard-form" id="step-form">
                ${questions.map(q => this.renderQuestion(q)).join('')}
            </form>
        `;
    }

    /**
     * Render individual question based on type
     */
    renderQuestion(question) {
        const value = this.answers[question.id] || question.default || '';
        const isRequired = question.required && !question.optional;

        let questionHTML = `
            <div class="question-item" data-question-id="${question.id}">
                <label class="question-label" for="${question.id}">
                    ${question.icon ? `<span class="question-icon" aria-hidden="true">${question.icon}</span>` : ''}
                    ${question.label}
                    ${isRequired ? '<span class="required-mark" aria-label="required">*</span>' : ''}
                </label>
        `;

        switch (question.type) {
            case 'text':
            case 'number':
                questionHTML += `
                    <input
                        type="${question.type}"
                        id="${question.id}"
                        name="${question.id}"
                        value="${value}"
                        placeholder="${question.placeholder || ''}"
                        ${isRequired ? 'required' : ''}
                        ${question.min ? `min="${question.min}"` : ''}
                        ${question.max ? `max="${question.max}"` : ''}
                        class="input-field"
                        aria-describedby="${question.id}-help"
                    />
                `;
                break;

            case 'textarea':
                questionHTML += `
                    <textarea
                        id="${question.id}"
                        name="${question.id}"
                        placeholder="${question.placeholder || ''}"
                        ${isRequired ? 'required' : ''}
                        ${question.maxLength ? `maxlength="${question.maxLength}"` : ''}
                        rows="4"
                        class="textarea-field"
                        aria-describedby="${question.id}-help"
                    >${value}</textarea>
                    ${question.maxLength ? `<small class="char-count">${value.length}/${question.maxLength}</small>` : ''}
                `;
                break;

            case 'slider':
                questionHTML += `
                    <div class="slider-container">
                        <input
                            type="range"
                            id="${question.id}"
                            name="${question.id}"
                            min="${question.min}"
                            max="${question.max}"
                            value="${value}"
                            class="slider-input"
                            aria-valuemin="${question.min}"
                            aria-valuemax="${question.max}"
                            aria-valuenow="${value}"
                            aria-valuetext="${this.getSliderValueText(question, value)}"
                        />
                        <div class="slider-labels" aria-hidden="true">
                            ${question.labels ? question.labels.map((label, idx) => `
                                <span class="slider-label">${label}</span>
                            `).join('') : ''}
                        </div>
                        <div class="slider-value" aria-live="polite">
                            ${value}${question.unit ? ` ${question.unit}` : ''}
                        </div>
                    </div>
                `;
                break;

            case 'choice':
                questionHTML += `
                    <div class="choice-container" role="radiogroup" aria-labelledby="${question.id}">
                        ${question.options.map(opt => `
                            <label class="choice-option ${value === opt.value ? 'selected' : ''}">
                                <input
                                    type="radio"
                                    name="${question.id}"
                                    value="${opt.value}"
                                    ${value === opt.value ? 'checked' : ''}
                                    ${isRequired ? 'required' : ''}
                                />
                                <span class="choice-icon" aria-hidden="true">${opt.icon || ''}</span>
                                <span class="choice-label">${opt.label}</span>
                            </label>
                        `).join('')}
                    </div>
                `;
                break;

            case 'multi_select':
                const selectedValues = Array.isArray(value) ? value : (value ? [value] : []);
                questionHTML += `
                    <div class="multi-select-container" role="group" aria-labelledby="${question.id}">
                        ${question.options.map(opt => `
                            <label class="multi-select-option ${selectedValues.includes(opt) ? 'selected' : ''}">
                                <input
                                    type="checkbox"
                                    name="${question.id}"
                                    value="${opt}"
                                    ${selectedValues.includes(opt) ? 'checked' : ''}
                                />
                                <span class="multi-select-label">${opt}</span>
                            </label>
                        `).join('')}
                    </div>
                `;
                break;

            case 'time':
                questionHTML += `
                    <input
                        type="time"
                        id="${question.id}"
                        name="${question.id}"
                        value="${value}"
                        ${isRequired ? 'required' : ''}
                        class="time-input"
                    />
                `;
                break;

            case 'photo':
                questionHTML += `
                    <div class="photo-upload-container">
                        <input
                            type="file"
                            id="${question.id}"
                            name="${question.id}"
                            accept="image/*"
                            class="photo-input"
                            aria-describedby="${question.id}-help"
                        />
                        <label for="${question.id}" class="photo-label">
                            <div class="photo-preview ${value ? 'has-photo' : ''}">
                                ${value ? `<img src="${value}" alt="Profile photo" />` : `
                                    <span class="photo-placeholder">
                                        📸<br/>Click to upload
                                    </span>
                                `}
                            </div>
                        </label>
                    </div>
                `;
                break;
        }

        questionHTML += `</div>`;
        return questionHTML;
    }

    /**
     * Get slider value text for accessibility
     */
    getSliderValueText(question, value) {
        if (!question.labels || question.labels.length === 0) {
            return `${value}${question.unit ? ` ${question.unit}` : ''}`;
        }

        const index = Math.floor((value - question.min) / (question.max - question.min) * (question.labels.length - 1));
        return question.labels[index] || value;
    }

    /**
     * Render navigation buttons
     */
    renderNavigationButtons(step) {
        const isFirst = this.currentStepIndex === 0;
        const isLast = this.currentStepIndex === this.steps.length - 1;
        const canSkip = step.skippable;

        return `
            <div class="wizard-navigation">
                ${!isFirst && !isLast ? `
                    <button type="button" class="btn-secondary" data-action="back">
                        ← Back
                    </button>
                ` : ''}

                ${canSkip ? `
                    <button type="button" class="btn-text" data-action="skip">
                        Skip for now
                    </button>
                ` : ''}

                ${!isLast ? `
                    <button type="button" class="btn-primary" data-action="next">
                        ${isFirst ? 'Let\'s Begin!' : 'Continue'} →
                    </button>
                ` : `
                    <button type="button" class="btn-primary" data-action="complete">
                        View Matches 🎉
                    </button>
                `}
            </div>
        `;
    }

    /**
     * Attach event listeners
     */
    attachEventListeners() {
        // Navigation buttons
        this.container.addEventListener('click', (e) => {
            const button = e.target.closest('[data-action]');
            if (!button) return;

            const action = button.dataset.action;

            if (action === 'next') {
                this.handleNext();
            } else if (action === 'back') {
                this.handleBack();
            } else if (action === 'skip') {
                this.handleSkip();
            } else if (action === 'complete') {
                this.handleComplete();
            }
        });

        // Auto-save on input change
        this.container.addEventListener('input', (e) => {
            if (e.target.matches('input, textarea, select')) {
                this.saveCurrentAnswers();
                this.scheduleAutoSave();
            }
        });

        // Slider real-time updates
        this.container.addEventListener('input', (e) => {
            if (e.target.type === 'range') {
                const valueDisplay = e.target.parentElement.querySelector('.slider-value');
                if (valueDisplay) {
                    const question = this.getCurrentStepQuestions().find(q => q.id === e.target.id);
                    valueDisplay.textContent = `${e.target.value}${question?.unit ? ` ${question.unit}` : ''}`;
                    e.target.setAttribute('aria-valuenow', e.target.value);
                    e.target.setAttribute('aria-valuetext', this.getSliderValueText(question, e.target.value));
                }
            }
        });

        // Choice selection visual feedback
        this.container.addEventListener('change', (e) => {
            if (e.target.type === 'radio') {
                const container = e.target.closest('.choice-container');
                if (container) {
                    container.querySelectorAll('.choice-option').forEach(opt => {
                        opt.classList.toggle('selected', opt.querySelector('input')?.checked);
                    });
                }
            } else if (e.target.type === 'checkbox') {
                const label = e.target.closest('.multi-select-option');
                if (label) {
                    label.classList.toggle('selected', e.target.checked);
                }
            }
        });

        // Photo upload preview
        this.container.addEventListener('change', (e) => {
            if (e.target.type === 'file' && e.target.accept === 'image/*') {
                this.handlePhotoUpload(e.target);
            }
        });
    }

    /**
     * Handle next button
     */
    async handleNext() {
        // Validate current step
        if (!this.validateCurrentStep()) {
            return;
        }

        // Save answers
        this.saveCurrentAnswers();

        // Move to next step
        if (this.currentStepIndex < this.steps.length - 1) {
            this.currentStepIndex++;
            this.render();
            this.attachEventListeners();
            this.onStepChange(this.currentStepIndex);

            // Scroll to top
            this.container.scrollIntoView({ behavior: 'smooth' });
        }
    }

    /**
     * Handle back button
     */
    handleBack() {
        if (this.currentStepIndex > 0) {
            this.currentStepIndex--;
            this.render();
            this.attachEventListeners();
            this.onStepChange(this.currentStepIndex);
        }
    }

    /**
     * Handle skip button
     */
    handleSkip() {
        this.handleNext();
    }

    /**
     * Handle completion
     */
    async handleComplete() {
        // Save all answers
        this.saveAllAnswers();

        // Mark completion in database
        await this.markOnboardingComplete();

        // Trigger completion callback
        this.onComplete(this.answers);
    }

    /**
     * Validate current step
     */
    validateCurrentStep() {
        const step = this.steps[this.currentStepIndex];
        if (!step.questions || step.questions.length === 0) {
            return true;
        }

        const form = this.container.querySelector('#step-form');
        if (!form) return true;

        // HTML5 validation
        if (!form.checkValidity()) {
            form.reportValidity();
            return false;
        }

        return true;
    }

    /**
     * Save current step answers
     */
    saveCurrentAnswers() {
        const form = this.container.querySelector('#step-form');
        if (!form) return;

        const formData = new FormData(form);

        for (const [key, value] of formData.entries()) {
            const question = this.getCurrentStepQuestions().find(q => q.id === key);

            if (question?.type === 'multi_select') {
                // Collect all checked values
                this.answers[key] = formData.getAll(key);
            } else if (question?.type === 'number') {
                this.answers[key] = parseFloat(value);
            } else {
                this.answers[key] = value;
            }
        }

        // Save to localStorage
        localStorage.setItem('roompal_wizard_answers', JSON.stringify(this.answers));
    }

    /**
     * Save all answers to database
     */
    async saveAllAnswers() {
        try {
            // This would integrate with your RoommateAPI
            console.log('Saving compatibility answers:', this.answers);

            // Example API call (uncomment when backend is ready):
            /*
            const api = new RoommateAPIService();
            await api.saveExtendedCompatibility({
                userId: this.userId,
                compatibility_scores: this.answers,
                profile_completion_percentage: 100
            });
            */

            localStorage.setItem('roompal_wizard_complete', 'true');
        } catch (error) {
            console.error('Error saving answers:', error);
        }
    }

    /**
     * Mark onboarding as complete
     */
    async markOnboardingComplete() {
        const timeSpent = Math.floor((Date.now() - this.startTime) / 1000);

        try {
            // Update onboarding progress
            console.log('Marking onboarding complete. Time spent:', timeSpent, 'seconds');

            // Example API call:
            /*
            await api.updateOnboardingProgress({
                userId: this.userId,
                current_step: 'completed',
                profile_completion_percentage: 100,
                onboarding_completed_at: new Date().toISOString(),
                time_spent_seconds: timeSpent
            });
            */
        } catch (error) {
            console.error('Error marking completion:', error);
        }
    }

    /**
     * Schedule auto-save
     */
    scheduleAutoSave() {
        clearTimeout(this.autoSaveTimer);
        this.autoSaveTimer = setTimeout(() => {
            this.saveCurrentAnswers();
        }, 1000); // Save after 1 second of inactivity
    }

    /**
     * Calculate progress percentage
     */
    calculateProgress() {
        // Exclude welcome and completion steps
        const totalSteps = this.steps.length - 2;
        const currentStep = Math.max(0, this.currentStepIndex - 1);
        return Math.round((currentStep / totalSteps) * 100);
    }

    /**
     * Get progress text with encouragement
     */
    getProgressText(progress) {
        const step = this.currentStepIndex;
        const total = this.steps.length - 2;

        let encouragement = '';
        if (progress < 25) {
            encouragement = window.i18n?.t('onboarding.encouragement_start') || "You're off to a great start! 🚀";
        } else if (progress < 50) {
            encouragement = window.i18n?.t('onboarding.encouragement_quarter') || "Great progress! Keep going! 💪";
        } else if (progress < 75) {
            encouragement = window.i18n?.t('onboarding.encouragement_half') || "Halfway there! You're doing amazing! ⭐";
        } else {
            encouragement = window.i18n?.t('onboarding.encouragement_three_quarter') || "Almost done! Hang in there! 🎯";
        }

        return `${encouragement} <br/> Step ${step} of ${total} • ${progress}% Complete`;
    }

    /**
     * Calculate time spent
     */
    calculateTimeSpent() {
        const seconds = Math.floor((Date.now() - this.startTime) / 1000);
        const minutes = Math.floor(seconds / 60);
        return minutes > 0 ? `${minutes}m` : `${seconds}s`;
    }

    /**
     * Get current step questions
     */
    getCurrentStepQuestions() {
        return this.steps[this.currentStepIndex]?.questions || [];
    }

    /**
     * Load saved answers from localStorage
     */
    loadSavedAnswers() {
        try {
            const saved = localStorage.getItem('roompal_wizard_answers');
            return saved ? JSON.parse(saved) : {};
        } catch (error) {
            console.error('Error loading saved answers:', error);
            return {};
        }
    }

    /**
     * Get current user ID
     */
    getCurrentUserId() {
        try {
            const user = JSON.parse(localStorage.getItem('currentUser') || '{}');
            return user.userId || null;
        } catch {
            return null;
        }
    }

    /**
     * Handle photo upload
     */
    handlePhotoUpload(input) {
        const file = input.files[0];
        if (!file) return;

        // Check file size (max 5MB)
        if (file.size > 5 * 1024 * 1024) {
            alert('Photo must be less than 5MB');
            input.value = '';
            return;
        }

        // Read and preview
        const reader = new FileReader();
        reader.onload = (e) => {
            const preview = input.parentElement.querySelector('.photo-preview');
            if (preview) {
                preview.innerHTML = `<img src="${e.target.result}" alt="Profile photo" />`;
                preview.classList.add('has-photo');
            }
            this.answers.avatar = e.target.result;
            this.saveCurrentAnswers();
        };
        reader.readAsDataURL(file);
    }
}

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
    module.exports = CompatibilityWizard;
}
