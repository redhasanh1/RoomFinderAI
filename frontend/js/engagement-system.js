/**
 * Engagement System - Tasteful Gamification for RoomPal
 *
 * Features:
 * - Badges and achievements
 * - Progressive encouragement (not manipulation)
 * - Expectation management
 * - Recovery prompts for inactive users
 * - Login streak tracking
 * - Points system
 *
 * Design Philosophy:
 * - Positive reinforcement, NOT pressure
 * - Authentic progress tracking
 * - No artificial scarcity or FOMO tactics
 * - No pay-to-win mechanics
 *
 * @version 1.0.0
 */

class EngagementSystem {
    constructor(userId = null) {
        this.userId = userId || this.getCurrentUserId();
        this.metrics = this.loadMetrics();
        this.badges = this.initializeBadges();
        this.achievements = this.initializeAchievements();
    }

    /**
     * Initialize badge definitions
     */
    initializeBadges() {
        return {
            // Profile completion badges
            'profile_complete': {
                id: 'profile_complete',
                name: 'Profile Master',
                description: 'Completed your full profile',
                icon: '✨',
                points: 50,
                category: 'profile',
                criteria: (metrics) => metrics.profileCompletionPercentage >= 100
            },
            'photo_uploaded': {
                id: 'photo_uploaded',
                name: 'Picture Perfect',
                description: 'Added a profile photo',
                icon: '📸',
                points: 25,
                category: 'profile',
                criteria: (metrics) => metrics.hasPhoto === true
            },

            // Matching badges
            'first_match': {
                id: 'first_match',
                name: 'First Connection',
                description: 'Got your first match',
                icon: '🎉',
                points: 25,
                category: 'matching',
                criteria: (metrics) => metrics.matchesMade >= 1
            },
            'perfect_match': {
                id: 'perfect_match',
                name: 'Perfect Match',
                description: 'Found a 95%+ compatibility match',
                icon: '💯',
                points: 100,
                category: 'matching',
                criteria: (metrics) => metrics.highestCompatibility >= 95
            },
            'ten_matches': {
                id: 'ten_matches',
                name: 'Popular',
                description: 'Received 10 match requests',
                icon: '⭐',
                points: 75,
                category: 'matching',
                criteria: (metrics) => metrics.matchesMade >= 10
            },

            // Engagement badges
            'week_streak': {
                id: 'week_streak',
                name: '7-Day Streak',
                description: 'Logged in 7 days in a row',
                icon: '🔥',
                points: 75,
                category: 'engagement',
                criteria: (metrics) => metrics.loginStreak >= 7
            },
            'early_bird': {
                id: 'early_bird',
                name: 'Early Adopter',
                description: 'Joined RoomPal in the first month',
                icon: '🐦',
                points: 50,
                category: 'engagement',
                criteria: (metrics) => this.isEarlyAdopter(metrics.createdAt)
            },

            // Interaction badges
            'chatty': {
                id: 'chatty',
                name: 'Great Communicator',
                description: 'Sent 50+ messages',
                icon: '💬',
                points: 50,
                category: 'interaction',
                criteria: (metrics) => metrics.messagesSent >= 50
            },
            'helpful': {
                id: 'helpful',
                name: 'Community Helper',
                description: 'Helped improve translations',
                icon: '🌍',
                points: 30,
                category: 'community',
                criteria: (metrics) => metrics.translationContributions >= 5
            }
        };
    }

    /**
     * Initialize achievement definitions
     */
    initializeAchievements() {
        return {
            'onboarding_complete': {
                id: 'onboarding_complete',
                name: 'Welcome Aboard!',
                description: 'Completed the compatibility questionnaire',
                points: 50,
                icon: '🎯'
            },
            'first_message': {
                id: 'first_message',
                name: 'Breaking the Ice',
                description: 'Sent your first message',
                points: 15,
                icon: '💭'
            },
            'profile_viewed_10': {
                id: 'profile_viewed_10',
                name: 'Window Shopper',
                description: 'Viewed 10 profiles',
                points: 20,
                icon: '👀'
            },
            'group_created': {
                id: 'group_created',
                name: 'Team Player',
                description: 'Created a roommate group',
                points: 30,
                icon: '👥'
            },
            'verification_complete': {
                id: 'verification_complete',
                name: 'Verified User',
                description: 'Completed identity verification',
                points: 40,
                icon: '✓'
            }
        };
    }

    /**
     * Load user metrics from localStorage/database
     */
    loadMetrics() {
        try {
            const saved = localStorage.getItem(`engagement_metrics_${this.userId}`);
            if (saved) {
                return JSON.parse(saved);
            }
        } catch (error) {
            console.error('Error loading metrics:', error);
        }

        // Default metrics
        return {
            profileCompletionPercentage: 0,
            hasPhoto: false,
            profileViews: 0,
            matchesMade: 0,
            messagesSent: 0,
            loginStreak: 0,
            lastLogin: null,
            totalLogins: 0,
            earnedBadges: [],
            completedAchievements: [],
            totalPoints: 0,
            highestCompatibility: 0,
            translationContributions: 0,
            createdAt: new Date().toISOString()
        };
    }

    /**
     * Save metrics
     */
    saveMetrics() {
        try {
            localStorage.setItem(`engagement_metrics_${this.userId}`, JSON.stringify(this.metrics));
        } catch (error) {
            console.error('Error saving metrics:', error);
        }
    }

    /**
     * Track login
     */
    trackLogin() {
        const now = new Date();
        const lastLogin = this.metrics.lastLogin ? new Date(this.metrics.lastLogin) : null;

        this.metrics.totalLogins++;

        // Calculate streak
        if (lastLogin) {
            const daysSinceLastLogin = this.daysBetween(lastLogin, now);

            if (daysSinceLastLogin === 1) {
                // Consecutive day login
                this.metrics.loginStreak++;
                this.showEncouragement(`🔥 ${this.metrics.loginStreak} day streak!`);
            } else if (daysSinceLastLogin > 1) {
                // Streak broken
                this.metrics.loginStreak = 1;
            }
        } else {
            this.metrics.loginStreak = 1;
        }

        this.metrics.lastLogin = now.toISOString();
        this.saveMetrics();
        this.checkBadges();

        // Show recovery message if user was inactive
        if (lastLogin && this.daysBetween(lastLogin, now) >= 3) {
            this.showRecoveryPrompt();
        }
    }

    /**
     * Track profile completion
     */
    trackProfileCompletion(percentage) {
        this.metrics.profileCompletionPercentage = percentage;
        this.saveMetrics();
        this.checkBadges();
        this.checkAchievements();

        // Show encouragement at milestones
        if (percentage === 100) {
            this.awardAchievement('onboarding_complete');
            this.showCelebration('🎉 Profile Complete! You\'re ready to find amazing roommates!');
        }
    }

    /**
     * Track photo upload
     */
    trackPhotoUpload() {
        this.metrics.hasPhoto = true;
        this.saveMetrics();
        this.checkBadges();
    }

    /**
     * Track match creation
     */
    trackMatch(compatibilityScore = 0) {
        this.metrics.matchesMade++;
        this.metrics.highestCompatibility = Math.max(this.metrics.highestCompatibility, compatibilityScore);
        this.saveMetrics();
        this.checkBadges();

        // First match achievement
        if (this.metrics.matchesMade === 1) {
            this.awardAchievement('first_match');
        }

        // High compatibility match
        if (compatibilityScore >= 95) {
            this.showCelebration(`💯 Wow! ${compatibilityScore}% compatibility - this is an excellent match!`);
        }
    }

    /**
     * Track message sent
     */
    trackMessage() {
        this.metrics.messagesSent++;
        this.saveMetrics();
        this.checkBadges();

        if (this.metrics.messagesSent === 1) {
            this.awardAchievement('first_message');
        }
    }

    /**
     * Track profile view
     */
    trackProfileView() {
        this.metrics.profileViews++;
        this.saveMetrics();

        if (this.metrics.profileViews === 10) {
            this.awardAchievement('profile_viewed_10');
        }
    }

    /**
     * Track group creation
     */
    trackGroupCreation() {
        this.awardAchievement('group_created');
        this.saveMetrics();
    }

    /**
     * Check and award badges
     */
    checkBadges() {
        Object.values(this.badges).forEach(badge => {
            // Check if already earned
            if (this.metrics.earnedBadges.includes(badge.id)) {
                return;
            }

            // Check criteria
            if (badge.criteria(this.metrics)) {
                this.awardBadge(badge);
            }
        });
    }

    /**
     * Check and award achievements
     */
    checkAchievements() {
        // Achievements are awarded explicitly via track* methods
        // This method is for future automated achievements
    }

    /**
     * Award a badge
     */
    awardBadge(badge) {
        if (this.metrics.earnedBadges.includes(badge.id)) {
            return; // Already earned
        }

        this.metrics.earnedBadges.push(badge.id);
        this.metrics.totalPoints += badge.points;
        this.saveMetrics();

        this.showBadgeNotification(badge);
    }

    /**
     * Award an achievement
     */
    awardAchievement(achievementId) {
        if (this.metrics.completedAchievements.includes(achievementId)) {
            return; // Already completed
        }

        const achievement = this.achievements[achievementId];
        if (!achievement) return;

        this.metrics.completedAchievements.push(achievementId);
        this.metrics.totalPoints += achievement.points;
        this.saveMetrics();

        this.showAchievementNotification(achievement);
    }

    /**
     * Show badge notification
     */
    showBadgeNotification(badge) {
        this.showToast({
            type: 'badge',
            icon: badge.icon,
            title: `Badge Earned: ${badge.name}`,
            message: badge.description,
            points: badge.points,
            duration: 5000
        });
    }

    /**
     * Show achievement notification
     */
    showAchievementNotification(achievement) {
        this.showToast({
            type: 'achievement',
            icon: achievement.icon,
            title: `Achievement Unlocked: ${achievement.name}`,
            message: achievement.description,
            points: achievement.points,
            duration: 4000
        });
    }

    /**
     * Show encouragement message
     */
    showEncouragement(message) {
        this.showToast({
            type: 'encouragement',
            icon: '💪',
            message: message,
            duration: 3000
        });
    }

    /**
     * Show celebration animation
     */
    showCelebration(message) {
        this.showToast({
            type: 'celebration',
            icon: '🎉',
            message: message,
            duration: 4000,
            animate: true
        });
    }

    /**
     * Show recovery prompt for inactive users
     */
    showRecoveryPrompt() {
        const daysSince = this.daysSinceLastLogin();

        let message;
        if (daysSince >= 7) {
            message = `We've missed you! ${this.getNewMatchesCount()} new potential matches are waiting 👋`;
        } else if (daysSince >= 3) {
            message = `Welcome back! Check out your new matches 🏠`;
        }

        if (message) {
            this.showToast({
                type: 'recovery',
                icon: '👋',
                title: 'Welcome Back!',
                message: message,
                duration: 5000
            });
        }
    }

    /**
     * Show expectation management message
     */
    showExpectationManagement(context = 'general') {
        const messages = {
            'no_matches_yet': {
                icon: '⏳',
                title: 'Hang tight!',
                message: 'Most users find matches within 3 days. Keep checking back!',
                tip: 'Complete your profile for better matches'
            },
            'many_passes': {
                icon: '🎯',
                title: 'Being selective is good!',
                message: 'Take your time to find the right fit. Quality over quantity!',
                tip: 'Try adjusting your preferences to see more options'
            },
            'high_compatibility': {
                icon: '⭐',
                title: '92% compatibility is excellent!',
                message: 'Matches above 85% typically make great roommates',
                tip: 'Don\'t wait too long to reach out'
            },
            'general': {
                icon: 'ℹ️',
                title: 'Did you know?',
                message: 'The average match time is 3-5 days. Perfect matches take time!',
                tip: 'Stay active and keep browsing'
            }
        };

        const msg = messages[context] || messages.general;

        this.showToast({
            type: 'expectation',
            icon: msg.icon,
            title: msg.title,
            message: msg.message,
            tip: msg.tip,
            duration: 6000
        });
    }

    /**
     * Show toast notification
     */
    showToast(options) {
        const {
            type = 'info',
            icon = 'ℹ️',
            title = '',
            message = '',
            tip = '',
            points = 0,
            duration = 3000,
            animate = false
        } = options;

        // Create toast element
        const toast = document.createElement('div');
        toast.className = `engagement-toast toast-${type} ${animate ? 'animate-celebration' : ''}`;
        toast.setAttribute('role', 'status');
        toast.setAttribute('aria-live', 'polite');

        toast.innerHTML = `
            <div class="toast-icon">${icon}</div>
            <div class="toast-content">
                ${title ? `<div class="toast-title">${title}</div>` : ''}
                <div class="toast-message">${message}</div>
                ${tip ? `<div class="toast-tip">💡 ${tip}</div>` : ''}
                ${points > 0 ? `<div class="toast-points">+${points} points</div>` : ''}
            </div>
            <button class="toast-close" aria-label="Close notification">×</button>
        `;

        // Add to page
        let container = document.querySelector('.toast-container');
        if (!container) {
            container = document.createElement('div');
            container.className = 'toast-container';
            document.body.appendChild(container);
        }
        container.appendChild(toast);

        // Close button
        toast.querySelector('.toast-close').addEventListener('click', () => {
            this.removeToast(toast);
        });

        // Auto-remove after duration
        setTimeout(() => {
            this.removeToast(toast);
        }, duration);

        // Add entrance animation
        setTimeout(() => {
            toast.classList.add('show');
        }, 10);
    }

    /**
     * Remove toast
     */
    removeToast(toast) {
        toast.classList.add('hide');
        setTimeout(() => {
            toast.remove();
        }, 300);
    }

    /**
     * Get progress percentage
     */
    getProgressPercentage() {
        return this.metrics.profileCompletionPercentage;
    }

    /**
     * Get total points
     */
    getTotalPoints() {
        return this.metrics.totalPoints;
    }

    /**
     * Get earned badges
     */
    getEarnedBadges() {
        return this.metrics.earnedBadges.map(id => this.badges[id]).filter(Boolean);
    }

    /**
     * Get completed achievements
     */
    getCompletedAchievements() {
        return this.metrics.completedAchievements.map(id => this.achievements[id]).filter(Boolean);
    }

    /**
     * Get next badge to earn
     */
    getNextBadge() {
        return Object.values(this.badges).find(badge =>
            !this.metrics.earnedBadges.includes(badge.id)
        );
    }

    /**
     * Render user stats dashboard
     */
    renderStatsDashboard(containerId) {
        const container = document.getElementById(containerId);
        if (!container) return;

        const earnedBadges = this.getEarnedBadges();
        const nextBadge = this.getNextBadge();

        container.innerHTML = `
            <div class="engagement-dashboard">
                <div class="stats-header">
                    <h3>Your Progress</h3>
                    <div class="total-points">
                        <span class="points-icon">⭐</span>
                        <span class="points-value">${this.metrics.totalPoints}</span>
                        <span class="points-label">points</span>
                    </div>
                </div>

                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-icon">📋</div>
                        <div class="stat-value">${this.metrics.profileCompletionPercentage}%</div>
                        <div class="stat-label">Profile Complete</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-icon">🤝</div>
                        <div class="stat-value">${this.metrics.matchesMade}</div>
                        <div class="stat-label">Matches</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-icon">💬</div>
                        <div class="stat-value">${this.metrics.messagesSent}</div>
                        <div class="stat-label">Messages</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-icon">🔥</div>
                        <div class="stat-value">${this.metrics.loginStreak}</div>
                        <div class="stat-label">Day Streak</div>
                    </div>
                </div>

                ${earnedBadges.length > 0 ? `
                    <div class="badges-section">
                        <h4>Badges Earned (${earnedBadges.length})</h4>
                        <div class="badges-grid">
                            ${earnedBadges.map(badge => `
                                <div class="badge-item" title="${badge.description}">
                                    <div class="badge-icon">${badge.icon}</div>
                                    <div class="badge-name">${badge.name}</div>
                                </div>
                            `).join('')}
                        </div>
                    </div>
                ` : ''}

                ${nextBadge ? `
                    <div class="next-badge-section">
                        <h4>Next Badge</h4>
                        <div class="next-badge">
                            <div class="badge-icon locked">${nextBadge.icon}</div>
                            <div class="badge-info">
                                <div class="badge-name">${nextBadge.name}</div>
                                <div class="badge-description">${nextBadge.description}</div>
                                <div class="badge-points">+${nextBadge.points} points</div>
                            </div>
                        </div>
                    </div>
                ` : ''}
            </div>
        `;
    }

    /**
     * Helper: Days between two dates
     */
    daysBetween(date1, date2) {
        const oneDay = 24 * 60 * 60 * 1000;
        return Math.round(Math.abs((date1 - date2) / oneDay));
    }

    /**
     * Helper: Days since last login
     */
    daysSinceLastLogin() {
        if (!this.metrics.lastLogin) return 0;
        return this.daysBetween(new Date(this.metrics.lastLogin), new Date());
    }

    /**
     * Helper: Check if early adopter
     */
    isEarlyAdopter(createdAt) {
        if (!createdAt) return false;
        const created = new Date(createdAt);
        const launchDate = new Date('2026-01-01'); // Adjust to actual launch date
        const oneMonthLater = new Date(launchDate);
        oneMonthLater.setMonth(oneMonthLater.getMonth() + 1);
        return created >= launchDate && created <= oneMonthLater;
    }

    /**
     * Helper: Get new matches count (mock)
     */
    getNewMatchesCount() {
        // This would come from actual API
        return Math.floor(Math.random() * 10) + 1;
    }

    /**
     * Helper: Get current user ID
     */
    getCurrentUserId() {
        try {
            const user = JSON.parse(localStorage.getItem('currentUser') || '{}');
            return user.userId || 'anonymous';
        } catch {
            return 'anonymous';
        }
    }
}

// Create global instance
window.engagementSystem = new EngagementSystem();

// Auto-track login on page load
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.engagementSystem.trackLogin();
    });
} else {
    window.engagementSystem.trackLogin();
}

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = EngagementSystem;
}
