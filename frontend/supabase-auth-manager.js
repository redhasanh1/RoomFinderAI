/**
 * Supabase Auth Manager
 * Handles authentication using Supabase Auth instead of plaintext passwords
 */

class SupabaseAuthManager {
    constructor(supabaseClient) {
        this.supabase = supabaseClient;
        this.currentUser = null;
        this.authStateListeners = [];
    }

    /**
     * Initialize auth manager and set up listeners
     */
    async initialize() {
        console.log('🔐 Initializing Supabase Auth Manager...');
        
        // Check current session
        const { data: { session }, error } = await this.supabase.auth.getSession();
        if (session) {
            this.currentUser = session.user;
            await this.syncUserProfile(session.user);
        }

        // Set up auth state listener
        this.supabase.auth.onAuthStateChange(async (event, session) => {
            console.log('Auth state changed:', event);
            
            if (session) {
                this.currentUser = session.user;
                await this.syncUserProfile(session.user);
            } else {
                this.currentUser = null;
            }
            
            // Notify listeners
            this.authStateListeners.forEach(listener => listener(event, session));
        });

        console.log('✅ Supabase Auth Manager initialized');
    }

    /**
     * Register a new user with Supabase Auth
     */
    async signUp(email, password, metadata = {}) {
        try {
            const { data, error } = await this.supabase.auth.signUp({
                email,
                password,
                options: {
                    data: metadata
                }
            });

            if (error) throw error;

            // Create user profile
            if (data.user) {
                await this.createUserProfile(data.user, metadata);
            }

            return { success: true, user: data.user, message: 'Please check your email to verify your account.' };
        } catch (error) {
            console.error('Sign up error:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Sign in with email and password
     */
    async signIn(email, password) {
        try {
            const { data, error } = await this.supabase.auth.signInWithPassword({
                email,
                password
            });

            if (error) throw error;

            await this.syncUserProfile(data.user);
            return { success: true, user: data.user };
        } catch (error) {
            console.error('Sign in error:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Sign in with OAuth provider (Google, Apple, etc.)
     */
    async signInWithProvider(provider) {
        try {
            const { data, error } = await this.supabase.auth.signInWithOAuth({
                provider,
                options: {
                    redirectTo: window.location.origin
                }
            });

            if (error) throw error;
            return { success: true, data };
        } catch (error) {
            console.error('OAuth sign in error:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Sign out the current user
     */
    async signOut() {
        try {
            const { error } = await this.supabase.auth.signOut();
            if (error) throw error;
            
            this.currentUser = null;
            localStorage.removeItem('currentUser');
            return { success: true };
        } catch (error) {
            console.error('Sign out error:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Reset password for a user
     */
    async resetPassword(email) {
        try {
            const { data, error } = await this.supabase.auth.resetPasswordForEmail(email, {
                redirectTo: `${window.location.origin}/reset-password`
            });

            if (error) throw error;
            return { success: true, message: 'Password reset email sent.' };
        } catch (error) {
            console.error('Password reset error:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Update user password
     */
    async updatePassword(newPassword) {
        try {
            const { data, error } = await this.supabase.auth.updateUser({
                password: newPassword
            });

            if (error) throw error;
            return { success: true, user: data.user };
        } catch (error) {
            console.error('Password update error:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Create user profile in database
     */
    async createUserProfile(user, metadata = {}) {
        try {
            // Check if profile already exists
            const { data: existingProfile } = await this.supabase
                .from('profiles')
                .select('id')
                .eq('user_id', user.id)
                .single();

            if (existingProfile) return existingProfile;

            // Create new profile
            const { data, error } = await this.supabase
                .from('profiles')
                .insert({
                    user_id: user.id,
                    email: user.email,
                    first_name: metadata.firstName || user.user_metadata?.first_name || '',
                    last_name: metadata.lastName || user.user_metadata?.last_name || '',
                    profile_image_url: user.user_metadata?.avatar_url || null,
                    created_at: new Date().toISOString()
                })
                .select()
                .single();

            if (error) throw error;
            return data;
        } catch (error) {
            console.error('Error creating user profile:', error);
            return null;
        }
    }

    /**
     * Sync user profile with database
     */
    async syncUserProfile(user) {
        if (!user) return;

        try {
            // Get or create user record
            const { data: userRecord, error: userError } = await this.supabase
                .from('users')
                .select('*')
                .eq('email', user.email)
                .single();

            if (userError && userError.code === 'PGRST116') {
                // User doesn't exist, create it
                const { data: newUser, error: createError } = await this.supabase
                    .from('users')
                    .insert({
                        id: user.id,
                        email: user.email,
                        first_name: user.user_metadata?.first_name || '',
                        last_name: user.user_metadata?.last_name || '',
                        auth_id: user.id,
                        is_verified: user.email_confirmed_at !== null,
                        created_at: user.created_at
                    })
                    .select()
                    .single();

                if (!createError) {
                    await this.createUserProfile(newUser);
                }
            }

            // Store in localStorage for compatibility
            const userData = {
                id: user.id,
                email: user.email,
                firstName: user.user_metadata?.first_name || '',
                lastName: user.user_metadata?.last_name || '',
                isAuthenticated: true
            };
            localStorage.setItem('currentUser', JSON.stringify(userData));

        } catch (error) {
            console.error('Error syncing user profile:', error);
        }
    }

    /**
     * Update user profile
     */
    async updateProfile(updates) {
        try {
            if (!this.currentUser) {
                throw new Error('No authenticated user');
            }

            // Update auth metadata
            const { data: authData, error: authError } = await this.supabase.auth.updateUser({
                data: updates
            });

            if (authError) throw authError;

            // Update profile in database
            const { data, error } = await this.supabase
                .from('profiles')
                .update({
                    ...updates,
                    updated_at: new Date().toISOString()
                })
                .eq('user_id', this.currentUser.id)
                .select()
                .single();

            if (error) throw error;
            return { success: true, profile: data };
        } catch (error) {
            console.error('Error updating profile:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Upload profile image
     */
    async uploadProfileImage(file) {
        try {
            if (!this.currentUser) {
                throw new Error('No authenticated user');
            }

            // Upload to Supabase Storage
            const fileExt = file.name.split('.').pop();
            const fileName = `${this.currentUser.id}/profile.${fileExt}`;
            
            const { data: uploadData, error: uploadError } = await this.supabase.storage
                .from('profile-images')
                .upload(fileName, file, {
                    upsert: true
                });

            if (uploadError) throw uploadError;

            // Get public URL
            const { data: { publicUrl } } = this.supabase.storage
                .from('profile-images')
                .getPublicUrl(fileName);

            // Update profile with image URL
            const { data, error } = await this.supabase
                .from('profiles')
                .update({
                    profile_image_url: publicUrl,
                    updated_at: new Date().toISOString()
                })
                .eq('user_id', this.currentUser.id)
                .select()
                .single();

            if (error) throw error;

            return { success: true, imageUrl: publicUrl };
        } catch (error) {
            console.error('Error uploading profile image:', error);
            return { success: false, error: error.message };
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
        return !!this.currentUser;
    }

    /**
     * Add auth state listener
     */
    onAuthStateChange(callback) {
        this.authStateListeners.push(callback);
        return () => {
            this.authStateListeners = this.authStateListeners.filter(l => l !== callback);
        };
    }

    /**
     * Migrate existing user from plaintext to Supabase Auth
     */
    async migrateUser(email, plaintextPassword, profile) {
        try {
            // First try to sign up
            const { data: signUpData, error: signUpError } = await this.supabase.auth.signUp({
                email,
                password: plaintextPassword,
                options: {
                    data: {
                        first_name: profile.first_name,
                        last_name: profile.last_name
                    }
                }
            });

            if (signUpError && signUpError.message.includes('already registered')) {
                // User exists, update their password
                const { data: adminData, error: adminError } = await this.supabase.auth.admin.updateUserById(
                    profile.user_id,
                    { password: plaintextPassword }
                );

                if (adminError) {
                    console.error('Could not migrate password:', adminError);
                    return { success: false, error: 'Migration failed - please reset your password' };
                }
            }

            return { success: true, message: 'User migrated successfully' };
        } catch (error) {
            console.error('Migration error:', error);
            return { success: false, error: error.message };
        }
    }
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = SupabaseAuthManager;
} else {
    window.SupabaseAuthManager = SupabaseAuthManager;
}