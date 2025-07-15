import { universalApi } from './universal-api';
import { supabaseApi, openaiApi, paymentApi } from './api-config';

export interface Property {
  id: string;
  title: string;
  description: string;
  address: string;
  city: string;
  state: string;
  zipCode: string;
  price: number;
  bedrooms: number;
  bathrooms: number;
  propertyType: string;
  images: string[];
  amenities: string[];
  isAvailable: boolean;
  createdAt: string;
  updatedAt: string;
  landlordId: string;
  latitude?: number;
  longitude?: number;
}

export interface User {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  phone?: string;
  profileImage?: string;
  userType: 'tenant' | 'landlord' | 'admin';
  createdAt: string;
  updatedAt: string;
}

export interface ChatConversation {
  id: string;
  propertyId: string;
  tenantId: string;
  landlordId: string;
  lastMessage: string;
  lastMessageTime: string;
  isActive: boolean;
  messages: ChatMessage[];
}

export interface ChatMessage {
  id: string;
  conversationId: string;
  senderId: string;
  content: string;
  messageType: 'text' | 'image' | 'ai_response' | 'negotiation';
  timestamp: string;
  isRead: boolean;
}

export interface AIResponse {
  id: string;
  userId: string;
  propertyId: string;
  query: string;
  response: string;
  confidence: number;
  timestamp: string;
  feedback?: 'helpful' | 'not_helpful';
}

export interface PaymentIntent {
  id: string;
  userId: string;
  amount: number;
  currency: string;
  status: 'pending' | 'succeeded' | 'failed';
  description: string;
  createdAt: string;
}

class MobileApiService {
  private static instance: MobileApiService;
  private baseUrl: string;

  private constructor() {
    this.baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || 'https://roomfinder-ai-negotiator-production.up.railway.app';
  }

  static getInstance(): MobileApiService {
    if (!MobileApiService.instance) {
      MobileApiService.instance = new MobileApiService();
    }
    return MobileApiService.instance;
  }

  // Authentication Methods
  async signUp(email: string, password: string, userData: Partial<User>): Promise<{ user: User; token: string }> {
    try {
      const response = await supabaseApi.signUp(email, password, userData);
      return response;
    } catch (error) {
      console.error('Sign up error:', error);
      throw error;
    }
  }

  async signIn(email: string, password: string): Promise<{ user: User; token: string }> {
    try {
      const response = await supabaseApi.signIn(email, password);
      return response;
    } catch (error) {
      console.error('Sign in error:', error);
      throw error;
    }
  }

  async signOut(): Promise<void> {
    try {
      await supabaseApi.signOut();
    } catch (error) {
      console.error('Sign out error:', error);
      throw error;
    }
  }

  async getCurrentUser(): Promise<User | null> {
    try {
      const response = await supabaseApi.getUser();
      return response;
    } catch (error) {
      console.error('Get current user error:', error);
      return null;
    }
  }

  async updateUserProfile(userId: string, updates: Partial<User>): Promise<User> {
    try {
      const response = await supabaseApi.update('users', updates, {
        where: { id: userId }
      });
      return response[0];
    } catch (error) {
      console.error('Update user profile error:', error);
      throw error;
    }
  }

  // Property Methods
  async fetchProperties(filters?: {
    city?: string;
    minPrice?: number;
    maxPrice?: number;
    bedrooms?: number;
    bathrooms?: number;
    propertyType?: string;
    limit?: number;
    offset?: number;
  }): Promise<Property[]> {
    try {
      const query: any = {};
      
      if (filters?.city) {
        query.city = { like: `%${filters.city}%` };
      }
      
      if (filters?.minPrice !== undefined) {
        query.price = { gte: filters.minPrice };
      }
      
      if (filters?.maxPrice !== undefined) {
        query.price = { ...query.price, lte: filters.maxPrice };
      }
      
      if (filters?.bedrooms !== undefined) {
        query.bedrooms = filters.bedrooms;
      }
      
      if (filters?.bathrooms !== undefined) {
        query.bathrooms = filters.bathrooms;
      }
      
      if (filters?.propertyType) {
        query.propertyType = filters.propertyType;
      }

      const response = await supabaseApi.select('properties', {
        where: query,
        limit: filters?.limit || 50,
        offset: filters?.offset || 0,
        order: { column: 'createdAt', ascending: false }
      });

      return response;
    } catch (error) {
      console.error('Fetch properties error:', error);
      throw error;
    }
  }

  async getPropertyById(id: string): Promise<Property | null> {
    try {
      const response = await supabaseApi.select('properties', {
        where: { id },
        limit: 1
      });
      
      return response[0] || null;
    } catch (error) {
      console.error('Get property by ID error:', error);
      return null;
    }
  }

  async searchProperties(query: string, filters?: any): Promise<Property[]> {
    try {
      const searchQuery = {
        or: [
          { title: { like: `%${query}%` } },
          { description: { like: `%${query}%` } },
          { address: { like: `%${query}%` } },
          { city: { like: `%${query}%` } }
        ]
      };

      const response = await supabaseApi.select('properties', {
        where: searchQuery,
        limit: 50
      });

      return response;
    } catch (error) {
      console.error('Search properties error:', error);
      throw error;
    }
  }

  // Chat Methods
  async getConversations(userId: string): Promise<ChatConversation[]> {
    try {
      const response = await supabaseApi.select('conversations', {
        where: {
          or: [
            { tenantId: userId },
            { landlordId: userId }
          ]
        },
        order: { column: 'lastMessageTime', ascending: false }
      });

      return response;
    } catch (error) {
      console.error('Get conversations error:', error);
      throw error;
    }
  }

  async getMessages(conversationId: string): Promise<ChatMessage[]> {
    try {
      const response = await supabaseApi.select('messages', {
        where: { conversationId },
        order: { column: 'timestamp', ascending: true }
      });

      return response;
    } catch (error) {
      console.error('Get messages error:', error);
      throw error;
    }
  }

  async sendMessage(conversationId: string, senderId: string, content: string, messageType: string = 'text'): Promise<ChatMessage> {
    try {
      const message = {
        conversationId,
        senderId,
        content,
        messageType,
        timestamp: new Date().toISOString(),
        isRead: false
      };

      const response = await supabaseApi.insert('messages', message);
      return response[0];
    } catch (error) {
      console.error('Send message error:', error);
      throw error;
    }
  }

  async createConversation(propertyId: string, tenantId: string, landlordId: string): Promise<ChatConversation> {
    try {
      const conversation = {
        propertyId,
        tenantId,
        landlordId,
        lastMessage: '',
        lastMessageTime: new Date().toISOString(),
        isActive: true
      };

      const response = await supabaseApi.insert('conversations', conversation);
      return response[0];
    } catch (error) {
      console.error('Create conversation error:', error);
      throw error;
    }
  }

  // AI Methods
  async getAIResponse(query: string, context?: any): Promise<string> {
    try {
      const systemPrompt = `You are a helpful real estate assistant for RoomFinderAI. 
      Help users with property searches, rental advice, and housing questions. 
      Be friendly, informative, and concise.`;

      const response = await openaiApi.simpleChat(query, systemPrompt);
      return response;
    } catch (error) {
      console.error('AI response error:', error);
      throw new Error('Sorry, I couldn\'t process your request right now.');
    }
  }

  async getNegotiationHelp(propertyId: string, currentOffer: number, targetRent: number): Promise<string> {
    try {
      const property = await this.getPropertyById(propertyId);
      if (!property) throw new Error('Property not found');

      const prompt = `As a rental negotiation expert, help me negotiate rent for this property:
      
      Property: ${property.title}
      Listed Price: $${property.price}
      Current Offer: $${currentOffer}
      Target Rent: $${targetRent}
      
      Provide 3 specific negotiation strategies and talking points.`;

      const response = await openaiApi.simpleChat(prompt);
      return response;
    } catch (error) {
      console.error('Negotiation help error:', error);
      throw error;
    }
  }

  async generatePropertySummary(propertyId: string): Promise<string> {
    try {
      const property = await this.getPropertyById(propertyId);
      if (!property) throw new Error('Property not found');

      const prompt = `Summarize this rental property in 2-3 sentences:
      
      ${property.title}
      ${property.description}
      Location: ${property.address}, ${property.city}
      Price: $${property.price}
      Bedrooms: ${property.bedrooms}
      Bathrooms: ${property.bathrooms}`;

      const response = await openaiApi.generateSummary(prompt, 50);
      return response;
    } catch (error) {
      console.error('Property summary error:', error);
      throw error;
    }
  }

  // Payment Methods
  async createPaymentIntent(amount: number, currency: string, description: string): Promise<PaymentIntent> {
    try {
      const response = await paymentApi.createBackendPaymentIntent({
        amount,
        currency,
        description
      });

      return response;
    } catch (error) {
      console.error('Create payment intent error:', error);
      throw error;
    }
  }

  async processPayment(paymentIntentId: string, paymentMethodId: string): Promise<PaymentIntent> {
    try {
      const response = await paymentApi.confirmBackendPayment({
        payment_intent_id: paymentIntentId,
        payment_method_id: paymentMethodId
      });

      return response;
    } catch (error) {
      console.error('Process payment error:', error);
      throw error;
    }
  }

  // Favorites Methods
  async getFavorites(userId: string): Promise<Property[]> {
    try {
      const response = await supabaseApi.select('favorites', {
        where: { userId },
        select: 'property:properties(*)'
      });

      return response.map((fav: any) => fav.property);
    } catch (error) {
      console.error('Get favorites error:', error);
      throw error;
    }
  }

  async addToFavorites(userId: string, propertyId: string): Promise<void> {
    try {
      await supabaseApi.insert('favorites', {
        userId,
        propertyId,
        createdAt: new Date().toISOString()
      });
    } catch (error) {
      console.error('Add to favorites error:', error);
      throw error;
    }
  }

  async removeFromFavorites(userId: string, propertyId: string): Promise<void> {
    try {
      await supabaseApi.delete('favorites', {
        where: { userId, propertyId }
      });
    } catch (error) {
      console.error('Remove from favorites error:', error);
      throw error;
    }
  }

  // File Upload Methods
  async uploadPropertyImage(file: File, propertyId: string): Promise<string> {
    try {
      const fileName = `properties/${propertyId}/${Date.now()}_${file.name}`;
      const response = await supabaseApi.uploadFile('property-images', fileName, file);
      return response.Key || response.path;
    } catch (error) {
      console.error('Upload property image error:', error);
      throw error;
    }
  }

  async uploadUserAvatar(file: File, userId: string): Promise<string> {
    try {
      const fileName = `avatars/${userId}/${Date.now()}_${file.name}`;
      const response = await supabaseApi.uploadFile('user-avatars', fileName, file);
      return response.Key || response.path;
    } catch (error) {
      console.error('Upload user avatar error:', error);
      throw error;
    }
  }

  // Utility Methods
  async getLocationSuggestions(query: string): Promise<string[]> {
    try {
      const response = await universalApi.get(
        `https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(query)}.json?access_token=${process.env.MAPBOX_TOKEN}&country=US&types=place,locality`
      );

      return response.data.features.map((feature: any) => feature.place_name);
    } catch (error) {
      console.error('Location suggestions error:', error);
      return [];
    }
  }

  async reportIssue(userId: string, issueType: string, description: string): Promise<void> {
    try {
      await supabaseApi.insert('support_tickets', {
        userId,
        issueType,
        description,
        status: 'open',
        createdAt: new Date().toISOString()
      });
    } catch (error) {
      console.error('Report issue error:', error);
      throw error;
    }
  }

  // Analytics Methods
  async trackUserAction(userId: string, action: string, metadata?: any): Promise<void> {
    try {
      await supabaseApi.insert('user_analytics', {
        userId,
        action,
        metadata,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      console.error('Track user action error:', error);
      // Don't throw error for analytics
    }
  }

  async getDashboardStats(userId: string): Promise<any> {
    try {
      const [favorites, conversations, recentSearches] = await Promise.all([
        this.getFavorites(userId),
        this.getConversations(userId),
        supabaseApi.select('user_analytics', {
          where: { userId, action: 'search' },
          limit: 10,
          order: { column: 'timestamp', ascending: false }
        })
      ]);

      return {
        favoriteCount: favorites.length,
        conversationCount: conversations.length,
        recentSearchCount: recentSearches.length,
        totalSavings: 1250 // Calculate based on negotiations
      };
    } catch (error) {
      console.error('Dashboard stats error:', error);
      return {
        favoriteCount: 0,
        conversationCount: 0,
        recentSearchCount: 0,
        totalSavings: 0
      };
    }
  }
}

export default MobileApiService.getInstance();