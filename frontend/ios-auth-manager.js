/**
 * iOS-Compatible Authentication Manager for RoomFinderAI
 * 
 * This module provides iOS-compatible authentication that replaces all
 * fetch calls with @capacitor/http for reliable iOS networking.
 */

import { fetch } from './ios-universal-fetch.js';
import { createClient } from './ios-supabase-client.js';

// Supabase configuration
const SUPABASE_URL = 'https://zmxyysauqtfkvntgtjsm.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM';

class IOSAuthManager {
    constructor() {
        this.supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        this.currentUser = null;
        this.isInitialized = false;
        this.debug = true;
        
        if (this.debug) {
            console.log('🔐 iOS Auth Manager initialized');
        }
    }

    /**
     * Initialize authentication
     */
    async initialize() {
        if (this.isInitialized) return;
        
        try {
            // Check for existing session
            const { data: user, error } = await this.supabase.auth.getUser();
            
            if (user && !error) {
                this.currentUser = user;
                await this.setCurrentUserInDatabase(user.email);
                if (this.debug) {
                    console.log('✅ Restored user session:', user.email);
                }
            }
            
            this.isInitialized = true;
        } catch (error) {
            console.error('❌ Auth initialization error:', error);
            this.isInitialized = true; // Set as initialized even on error
        }
    }

    /**
     * Sign up with email and password
     */
    async signUp(email, password, userData = {}) {
        try {
            if (this.debug) {
                console.log('📝 Signing up user:', email);
            }

            const { data, error } = await this.supabase.auth.signUp({
                email,
                password
            });

            if (error) {
                throw error;
            }

            if (data.user) {
                this.currentUser = data.user;
                
                // Create user profile
                await this.createUserProfile(data.user, userData);
                
                if (this.debug) {
                    console.log('✅ User signed up successfully:', email);
                }
            }

            return { data, error: null };
        } catch (error) {
            console.error('❌ Sign up error:', error);
            return { data: null, error };
        }
    }

    /**
     * Sign in with email and password
     */
    async signIn(email, password) {
        try {
            if (this.debug) {
                console.log('🔑 Signing in user:', email);
            }

            const { data, error } = await this.supabase.auth.signInWithPassword({
                email,
                password
            });

            if (error) {
                throw error;
            }

            if (data.user) {
                this.currentUser = data.user;
                await this.setCurrentUserInDatabase(email);
                
                if (this.debug) {
                    console.log('✅ User signed in successfully:', email);
                }
            }

            return { data, error: null };
        } catch (error) {
            console.error('❌ Sign in error:', error);
            return { data: null, error };
        }
    }

    /**
     * Sign out
     */
    async signOut() {
        try {
            if (this.debug) {
                console.log('🚪 Signing out user');
            }

            const { error } = await this.supabase.auth.signOut();
            
            if (error) {
                throw error;
            }

            this.currentUser = null;
            
            if (this.debug) {
                console.log('✅ User signed out successfully');
            }

            return { error: null };
        } catch (error) {
            console.error('❌ Sign out error:', error);
            return { error };
        }
    }

    /**
     * Get current user
     */
    getCurrentUser() {
        return this.currentUser;
    }

    /**
     * Check if user is authenticated
     */
    isAuthenticated() {
        return this.currentUser !== null;
    }

    /**
     * Get user profile from database
     */
    async getUserProfile(email) {
        try {
            const profileData = await this.supabase
                .from('profiles')
                .select('*')
                .eq('email', email)
                .single()
                .exec();

            return { data: profileData, error: null };
        } catch (error) {
            console.error('❌ Get user profile error:', error);
            return { data: null, error };
        }
    }

    /**
     * Update user profile
     */
    async updateUserProfile(email, updates) {
        try {
            const { data, error } = await this.supabase
                .from('profiles')
                .update(updates)
                .eq('email', email);

            if (error) {
                throw error;
            }

            if (this.debug) {
                console.log('✅ User profile updated:', email);
            }

            return { data, error: null };
        } catch (error) {
            console.error('❌ Update user profile error:', error);
            return { data: null, error };
        }
    }

    /**
     * Create user profile in database
     */
    async createUserProfile(user, userData = {}) {
        try {
            const profileData = {
                email: user.email,
                user_id: user.id,
                first_name: userData.first_name || '',
                last_name: userData.last_name || '',
                phone: userData.phone || '',
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
            };

            const { data, error } = await this.supabase
                .from('profiles')
                .insert([profileData]);

            if (error) {
                // Profile might already exist, try to update it
                await this.updateUserProfile(user.email, {
                    ...userData,
                    updated_at: new Date().toISOString()
                });
            }

            if (this.debug) {
                console.log('✅ User profile created:', user.email);
            }

            return { data, error: null };
        } catch (error) {
            console.error('❌ Create user profile error:', error);
            return { data: null, error };
        }
    }

    /**
     * Set current user in database (for RLS)
     */
    async setCurrentUserInDatabase(email) {
        try {
            await this.supabase.rpc('set_current_user_email', { email });
            
            if (this.debug) {
                console.log('✅ Set current user in database:', email);
            }
        } catch (error) {
            console.error('❌ Set current user error:', error);
        }
    }

    /**
     * Reset password
     */
    async resetPassword(email) {
        try {
            const { data, error } = await this.supabase.auth.resetPasswordForEmail(email, {
                redirectTo: `${window.location.origin}/reset-password.html`
            });

            if (error) {
                throw error;
            }

            if (this.debug) {
                console.log('✅ Password reset email sent:', email);
            }

            return { data, error: null };
        } catch (error) {
            console.error('❌ Reset password error:', error);
            return { data: null, error };
        }
    }

    /**
     * Update password
     */
    async updatePassword(newPassword) {
        try {
            const { data, error } = await this.supabase.auth.updateUser({
                password: newPassword
            });

            if (error) {
                throw error;
            }

            if (this.debug) {
                console.log('✅ Password updated successfully');
            }

            return { data, error: null };
        } catch (error) {
            console.error('❌ Update password error:', error);
            return { data: null, error };
        }
    }

    /**
     * Check if email exists
     */
    async emailExists(email) {
        try {
            const profileData = await this.supabase
                .from('profiles')
                .select('email')
                .eq('email', email)
                .single()
                .exec();

            return profileData !== null;
        } catch (error) {
            return false;
        }
    }

    /**
     * Validate user session
     */
    async validateSession() {
        try {
            const { data: user, error } = await this.supabase.auth.getUser();
            
            if (error || !user) {
                this.currentUser = null;
                return false;
            }

            this.currentUser = user;
            return true;
        } catch (error) {
            console.error('❌ Session validation error:', error);
            this.currentUser = null;
            return false;
        }
    }

    /**
     * Get user permissions
     */
    async getUserPermissions() {
        if (!this.currentUser) {
            return { canPost: false, canChat: false, canViewPremium: false };
        }

        try {
            const { data: profile } = await this.getUserProfile(this.currentUser.email);
            
            const permissions = {
                canPost: true,
                canChat: true,
                canViewPremium: profile?.subscription_type === 'premium' || false
            };

            return permissions;
        } catch (error) {
            console.error('❌ Get permissions error:', error);
            return { canPost: false, canChat: false, canViewPremium: false };
        }
    }

    /**
     * Listen for authentication state changes
     */
    onAuthStateChange(callback) {
        // For iOS, we'll use a simplified polling mechanism
        // In a real implementation, you'd want to use proper event listeners
        
        let lastUserState = this.currentUser;
        
        const checkAuthState = async () => {
            const isValid = await this.validateSession();
            const currentState = this.currentUser;
            
            if (lastUserState !== currentState) {
                callback(currentState);
                lastUserState = currentState;
            }
        };

        // Check auth state every 30 seconds
        const interval = setInterval(checkAuthState, 30000);
        
        // Return unsubscribe function
        return () => clearInterval(interval);
    }
}

// Create singleton instance
const iosAuthManager = new IOSAuthManager();

// Initialize on load
iosAuthManager.initialize();

/**
 * Export singleton instance
 */
export default iosAuthManager;

/**
 * Export auth functions for convenience
 */
export const {
    signUp,
    signIn,
    signOut,
    getCurrentUser,
    isAuthenticated,
    getUserProfile,
    updateUserProfile,
    resetPassword,
    updatePassword,
    emailExists,
    validateSession,
    getUserPermissions,
    onAuthStateChange
} = iosAuthManager;

console.log('✅ iOS Auth Manager module loaded successfully');