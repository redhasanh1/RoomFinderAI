import { createClient } from '@supabase/supabase-js';

/**
 * Supabase Service for RoomFinderAI
 * Handles all backend API operations using your existing Supabase configuration
 */

class SupabaseService {
  constructor() {
    // Your existing Supabase configuration
    this.SUPABASE_URL = 'https://zmxyysauqtfkvntgtjsm.supabase.co';
    this.SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM';
    
    // Initialize Supabase client
    this.supabase = createClient(this.SUPABASE_URL, this.SUPABASE_ANON_KEY, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: false
      },
      global: {
        headers: {
          'X-Client-Info': 'RoomFinderAI-iOS-ReactNative'
        }
      }
    });

    this.currentUser = null;
    this.initialized = false;
  }

  /**
   * Initialize the service
   */
  async init() {
    try {
      console.log('🔄 Initializing Supabase service...');
      
      // Test connection
      const { data, error } = await this.supabase
        .from('listings')
        .select('id')
        .limit(1);

      if (error) {
        console.warn('⚠️ Supabase connection test failed:', error.message);
        console.log('💡 This might be due to RLS policies - check your database settings');
      } else {
        console.log('✅ Supabase connection test successful');
      }

      this.initialized = true;
      return true;
    } catch (error) {
      console.error('❌ Failed to initialize Supabase service:', error);
      return false;
    }
  }

  /**
   * Authentication Methods
   */

  // Sign up a new user
  async signUp(email, password, userData = {}) {
    try {
      console.log('📝 Creating new user account...');
      
      const { data, error } = await this.supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            first_name: userData.firstName || '',
            last_name: userData.lastName || '',
            phone: userData.phone || ''
          }
        }
      });

      if (error) {
        console.error('❌ Sign up error:', error);
        throw error;
      }

      // Create profile if user was created successfully
      if (data.user) {
        await this.createUserProfile(data.user, userData);
      }

      console.log('✅ User created successfully');
      return data;
    } catch (error) {
      console.error('❌ Sign up failed:', error);
      throw error;
    }
  }

  // Sign in existing user
  async signIn(email, password) {
    try {
      console.log('🔐 Signing in user...');
      
      const { data, error } = await this.supabase.auth.signInWithPassword({
        email,
        password
      });

      if (error) {
        console.error('❌ Sign in error:', error);
        throw error;
      }

      this.currentUser = data.user;
      console.log('✅ User signed in successfully');
      return data;
    } catch (error) {
      console.error('❌ Sign in failed:', error);
      throw error;
    }
  }

  // Sign out user
  async signOut() {
    try {
      console.log('🚪 Signing out user...');
      
      const { error } = await this.supabase.auth.signOut();
      
      if (error) {
        console.error('❌ Sign out error:', error);
        throw error;
      }

      this.currentUser = null;
      console.log('✅ User signed out successfully');
      return true;
    } catch (error) {
      console.error('❌ Sign out failed:', error);
      throw error;
    }
  }

  // Get current user
  async getCurrentUser() {
    try {
      const { data: { user } } = await this.supabase.auth.getUser();
      this.currentUser = user;
      return user;
    } catch (error) {
      console.error('❌ Get current user failed:', error);
      return null;
    }
  }

  // Create user profile
  async createUserProfile(user, userData = {}) {
    try {
      console.log('📄 Creating user profile...');
      
      const profile = {
        id: user.id,
        email: user.email,
        first_name: userData.firstName || '',
        last_name: userData.lastName || '',
        phone: userData.phone || '',
        profile_image: this.getDefaultProfileImage(),
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      };

      const { data, error } = await this.supabase
        .from('profiles')
        .insert([profile])
        .select()
        .single();

      if (error) {
        console.error('❌ Create profile error:', error);
        throw error;
      }

      console.log('✅ User profile created successfully');
      return data;
    } catch (error) {
      console.error('❌ Create profile failed:', error);
      throw error;
    }
  }

  // Get user profile
  async getUserProfile(email) {
    try {
      const { data, error } = await this.supabase
        .from('profiles')
        .select('*')
        .eq('email', email)
        .single();

      if (error) {
        console.error('❌ Get profile error:', error);
        throw error;
      }

      return data;
    } catch (error) {
      console.error('❌ Get profile failed:', error);
      throw error;
    }
  }

  /**
   * Listings Methods
   */

  // Fetch all listings with optional filters
  async getListings(options = {}) {
    try {
      console.log('📥 Fetching listings...');
      
      const { limit = 50, offset = 0, filters = {} } = options;
      
      let query = this.supabase
        .from('listings')
        .select('*')
        .order('created_at', { ascending: false });

      // Apply filters
      if (filters.city) {
        query = query.ilike('city', `%${filters.city}%`);
      }
      if (filters.maxPrice) {
        query = query.lte('price', filters.maxPrice);
      }
      if (filters.minPrice) {
        query = query.gte('price', filters.minPrice);
      }
      if (filters.houseType) {
        query = query.eq('house_type', filters.houseType);
      }
      if (filters.bedrooms) {
        query = query.eq('bedrooms', filters.bedrooms);
      }
      if (filters.excludeUserEmail) {
        query = query.neq('user_email', filters.excludeUserEmail);
      }

      // Apply pagination
      if (limit > 0) {
        query = query.range(offset, offset + limit - 1);
      }

      const { data, error } = await query;

      if (error) {
        console.error('❌ Get listings error:', error);
        throw error;
      }

      console.log(`✅ Fetched ${data?.length || 0} listings`);
      return data || [];
    } catch (error) {
      console.error('❌ Get listings failed:', error);
      throw error;
    }
  }

  // Get listing by ID
  async getListingById(id) {
    try {
      console.log('📥 Fetching listing by ID:', id);
      
      const { data, error } = await this.supabase
        .from('listings')
        .select('*')
        .eq('id', id)
        .single();

      if (error) {
        console.error('❌ Get listing by ID error:', error);
        throw error;
      }

      console.log('✅ Listing fetched successfully');
      return data;
    } catch (error) {
      console.error('❌ Get listing by ID failed:', error);
      throw error;
    }
  }

  // Search listings
  async searchListings(searchTerm, filters = {}) {
    try {
      console.log('🔍 Searching listings for:', searchTerm);
      
      let query = this.supabase
        .from('listings')
        .select('*');

      // Search in multiple fields
      if (searchTerm) {
        query = query.or(`title.ilike.%${searchTerm}%,city.ilike.%${searchTerm}%,street.ilike.%${searchTerm}%,description.ilike.%${searchTerm}%`);
      }

      // Apply additional filters
      if (filters.maxPrice) {
        query = query.lte('price', filters.maxPrice);
      }
      if (filters.minPrice) {
        query = query.gte('price', filters.minPrice);
      }
      if (filters.houseType) {
        query = query.eq('house_type', filters.houseType);
      }
      if (filters.bedrooms) {
        query = query.eq('bedrooms', filters.bedrooms);
      }
      if (filters.excludeUserEmail) {
        query = query.neq('user_email', filters.excludeUserEmail);
      }

      const { data, error } = await query
        .order('created_at', { ascending: false })
        .limit(50);

      if (error) {
        console.error('❌ Search listings error:', error);
        throw error;
      }

      console.log(`✅ Found ${data?.length || 0} matching listings`);
      return data || [];
    } catch (error) {
      console.error('❌ Search listings failed:', error);
      throw error;
    }
  }

  // Create new listing
  async createListing(listingData) {
    try {
      console.log('📝 Creating new listing...');
      
      const { data, error } = await this.supabase
        .from('listings')
        .insert([{
          ...listingData,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        }])
        .select()
        .single();

      if (error) {
        console.error('❌ Create listing error:', error);
        throw error;
      }

      console.log('✅ Listing created successfully');
      return data;
    } catch (error) {
      console.error('❌ Create listing failed:', error);
      throw error;
    }
  }

  // Update listing
  async updateListing(id, updates) {
    try {
      console.log('📝 Updating listing:', id);
      
      const { data, error } = await this.supabase
        .from('listings')
        .update({
          ...updates,
          updated_at: new Date().toISOString()
        })
        .eq('id', id)
        .select()
        .single();

      if (error) {
        console.error('❌ Update listing error:', error);
        throw error;
      }

      console.log('✅ Listing updated successfully');
      return data;
    } catch (error) {
      console.error('❌ Update listing failed:', error);
      throw error;
    }
  }

  // Delete listing
  async deleteListing(id) {
    try {
      console.log('🗑️ Deleting listing:', id);
      
      const { error } = await this.supabase
        .from('listings')
        .delete()
        .eq('id', id);

      if (error) {
        console.error('❌ Delete listing error:', error);
        throw error;
      }

      console.log('✅ Listing deleted successfully');
      return true;
    } catch (error) {
      console.error('❌ Delete listing failed:', error);
      throw error;
    }
  }

  // Get user's listings
  async getUserListings(userEmail) {
    try {
      console.log('📥 Fetching user listings for:', userEmail);
      
      const { data, error } = await this.supabase
        .from('listings')
        .select('*')
        .eq('user_email', userEmail)
        .order('created_at', { ascending: false });

      if (error) {
        console.error('❌ Get user listings error:', error);
        throw error;
      }

      console.log(`✅ Fetched ${data?.length || 0} user listings`);
      return data || [];
    } catch (error) {
      console.error('❌ Get user listings failed:', error);
      throw error;
    }
  }

  /**
   * AI Chat Methods
   */

  // Send AI chat message
  async sendAIMessage(message, userEmail, conversationHistory = []) {
    try {
      console.log('🤖 Sending AI message...');
      
      // Save user message to chat history
      await this.saveAIChat(userEmail, 'user', message);

      // For demo purposes, simulate AI response
      // In your actual implementation, this would call your AI service
      const aiResponse = await this.generateAIResponse(message, conversationHistory);
      
      // Save AI response to chat history
      await this.saveAIChat(userEmail, 'ai', aiResponse);

      return aiResponse;
    } catch (error) {
      console.error('❌ Send AI message failed:', error);
      throw error;
    }
  }

  // Generate AI response (placeholder - replace with your actual AI service)
  async generateAIResponse(message, conversationHistory) {
    // This is a placeholder implementation
    // Replace with your actual AI service integration
    
    const responses = [
      "I understand you're looking for a place to rent. Can you tell me your budget and preferred location?",
      "Let me search for properties that match your criteria. What type of property are you interested in?",
      "I found several properties that might interest you. Would you like me to help you contact the landlords?",
      "Based on your preferences, I recommend checking out these listings. Would you like me to negotiate on your behalf?",
      "I can help you with that! Let me search our database for matching properties."
    ];

    // Simple keyword-based response selection
    const lowerMessage = message.toLowerCase();
    
    if (lowerMessage.includes('budget') || lowerMessage.includes('price')) {
      return "What's your budget range? I can help you find properties within your price range.";
    }
    
    if (lowerMessage.includes('location') || lowerMessage.includes('area')) {
      return "Which area are you looking in? I can search for properties in specific cities or neighborhoods.";
    }
    
    if (lowerMessage.includes('bedroom') || lowerMessage.includes('room')) {
      return "How many bedrooms do you need? I can filter properties based on the number of bedrooms.";
    }
    
    // Default response
    return responses[Math.floor(Math.random() * responses.length)];
  }

  // Save AI chat message
  async saveAIChat(userEmail, role, message, metadata = {}) {
    try {
      const { data, error } = await this.supabase
        .from('ai_chats')
        .insert([{
          user_email: userEmail,
          role,
          message,
          metadata,
          created_at: new Date().toISOString()
        }])
        .select()
        .single();

      if (error) {
        console.error('❌ Save AI chat error:', error);
        throw error;
      }

      return data;
    } catch (error) {
      console.error('❌ Save AI chat failed:', error);
      throw error;
    }
  }

  // Get AI chat history
  async getAIChatHistory(userEmail, limit = 50) {
    try {
      const { data, error } = await this.supabase
        .from('ai_chats')
        .select('*')
        .eq('user_email', userEmail)
        .order('created_at', { ascending: true })
        .limit(limit);

      if (error) {
        console.error('❌ Get AI chat history error:', error);
        throw error;
      }

      return data || [];
    } catch (error) {
      console.error('❌ Get AI chat history failed:', error);
      throw error;
    }
  }

  /**
   * Real-time Subscriptions
   */

  // Subscribe to listings changes
  subscribeToListings(callback) {
    try {
      console.log('📡 Setting up listings subscription...');
      
      const subscription = this.supabase
        .channel('listings-changes')
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'listings'
        }, (payload) => {
          console.log('📨 Listings change received:', payload);
          callback(payload);
        })
        .subscribe();

      return subscription;
    } catch (error) {
      console.error('❌ Subscribe to listings failed:', error);
      throw error;
    }
  }

  // Subscribe to AI chat changes
  subscribeToAIChat(userEmail, callback) {
    try {
      console.log('📡 Setting up AI chat subscription...');
      
      const subscription = this.supabase
        .channel('ai-chat-changes')
        .on('postgres_changes', {
          event: 'INSERT',
          schema: 'public',
          table: 'ai_chats',
          filter: `user_email=eq.${userEmail}`
        }, (payload) => {
          console.log('📨 AI chat change received:', payload);
          callback(payload);
        })
        .subscribe();

      return subscription;
    } catch (error) {
      console.error('❌ Subscribe to AI chat failed:', error);
      throw error;
    }
  }

  /**
   * Utility Methods
   */

  // Get default profile image
  getDefaultProfileImage() {
    return 'data:image/svg+xml;base64,' + btoa(`
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
        <rect width="100" height="100" rx="50" fill="#E5E7EB"/>
        <path d="M50 45C56.075 45 61 40.075 61 34C61 27.925 56.075 23 50 23C43.925 23 39 27.925 39 34C39 40.075 43.925 45 50 45Z" fill="#9CA3AF"/>
        <path d="M30 77C30 77 30 66.103 30 62C30 55.373 36.268 50 44 50H56C63.732 50 70 55.373 70 62C70 66.103 70 77 70 77" fill="#9CA3AF"/>
      </svg>
    `.trim());
  }

  // Format price
  formatPrice(price) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0
    }).format(price);
  }

  // Format date
  formatDate(dateString) {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  }
}

// Create and export singleton instance
const supabaseService = new SupabaseService();
export default supabaseService;