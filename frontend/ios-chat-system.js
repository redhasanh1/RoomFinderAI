/**
 * iOS-Compatible Chat System for RoomFinderAI
 * 
 * This module provides iOS-compatible chat functionality that replaces all
 * fetch calls with @capacitor/http for reliable iOS networking.
 */

import { fetch } from './ios-universal-fetch.js';
import { createClient } from './ios-supabase-client.js';
import iosAuthManager from './ios-auth-manager.js';

// Supabase configuration
const SUPABASE_URL = 'https://zmxyysauqtfkvntgtjsm.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM';

class IOSChatSystem {
    constructor() {
        this.supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        this.debug = true;
        this.activeListeners = new Map();
        
        if (this.debug) {
            console.log('💬 iOS Chat System initialized');
        }
    }

    /**
     * Get all conversations for the current user
     */
    async getConversations() {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to view conversations');
            }

            if (this.debug) {
                console.log('💬 Getting conversations for user:', currentUser.email);
            }

            const conversations = await this.supabase
                .from('conversations')
                .select(`
                    *,
                    listings (
                        id,
                        title,
                        price,
                        location,
                        image_url
                    )
                `)
                .or(`sender_email.eq.${currentUser.email},receiver_email.eq.${currentUser.email}`)
                .order('last_message_at', { ascending: false })
                .exec();

            if (this.debug) {
                console.log(`✅ Retrieved ${conversations.length} conversations`);
            }

            return { data: conversations, error: null };
        } catch (error) {
            console.error('❌ Get conversations error:', error);
            return { data: [], error };
        }
    }

    /**
     * Get or create a conversation
     */
    async getOrCreateConversation(listingId, receiverEmail) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to create conversations');
            }

            if (this.debug) {
                console.log('💬 Getting/creating conversation for listing:', listingId);
            }

            // Check if conversation already exists
            // Select only needed columns to reduce egress costs
            const existingConversation = await this.supabase
                .from('conversations')
                .select('id, listing_id, sender_email, receiver_email, created_at, last_message_at')
                .eq('listing_id', listingId)
                .or(`sender_email.eq.${currentUser.email},receiver_email.eq.${currentUser.email}`)
                .or(`sender_email.eq.${receiverEmail},receiver_email.eq.${receiverEmail}`)
                .single()
                .exec();

            if (existingConversation) {
                if (this.debug) {
                    console.log('✅ Found existing conversation:', existingConversation.id);
                }
                return { data: existingConversation, error: null };
            }

            // Create new conversation
            const conversationData = {
                listing_id: listingId,
                sender_email: currentUser.email,
                receiver_email: receiverEmail,
                created_at: new Date().toISOString(),
                last_message_at: new Date().toISOString()
            };

            const { data, error } = await this.supabase
                .from('conversations')
                .insert([conversationData]);

            if (error) {
                throw error;
            }

            if (this.debug) {
                console.log('✅ Created new conversation:', data?.[0]?.id);
            }

            return { data: data?.[0], error: null };
        } catch (error) {
            console.error('❌ Get/create conversation error:', error);
            return { data: null, error };
        }
    }

    /**
     * Get messages for a conversation
     */
    async getMessages(conversationId) {
        try {
            if (this.debug) {
                console.log('💬 Getting messages for conversation:', conversationId);
            }

            // Select only needed columns to reduce egress costs
            const messages = await this.supabase
                .from('messages')
                .select('id, conversation_id, sender_email, content, message_type, file_url, file_name, file_size, file_type, created_at, read')
                .eq('conversation_id', conversationId)
                .order('created_at', { ascending: true })
                .exec();

            if (this.debug) {
                console.log(`✅ Retrieved ${messages.length} messages`);
            }

            return { data: messages, error: null };
        } catch (error) {
            console.error('❌ Get messages error:', error);
            return { data: [], error };
        }
    }

    /**
     * Send a message
     */
    async sendMessage(conversationId, content, messageType = 'text') {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to send messages');
            }

            if (this.debug) {
                console.log('💬 Sending message to conversation:', conversationId);
            }

            const messageData = {
                conversation_id: conversationId,
                sender_email: currentUser.email,
                content,
                message_type: messageType,
                created_at: new Date().toISOString()
            };

            const { data, error } = await this.supabase
                .from('messages')
                .insert([messageData]);

            if (error) {
                throw error;
            }

            // Update conversation's last_message_at
            await this.supabase
                .from('conversations')
                .update({ last_message_at: new Date().toISOString() })
                .eq('id', conversationId);

            if (this.debug) {
                console.log('✅ Message sent successfully');
            }

            return { data: data?.[0], error: null };
        } catch (error) {
            console.error('❌ Send message error:', error);
            return { data: null, error };
        }
    }

    /**
     * Upload file for chat
     */
    async uploadChatFile(conversationId, file) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to upload files');
            }

            if (this.debug) {
                console.log('📎 Uploading file to conversation:', conversationId);
            }

            // Create unique filename
            const timestamp = Date.now();
            const fileExtension = file.name.split('.').pop();
            const fileName = `${conversationId}_${timestamp}.${fileExtension}`;
            const filePath = `chat-files/${fileName}`;

            // Upload to Supabase Storage
            const { data, error } = await this.supabase.storage
                .from('chat-documents')
                .upload(filePath, file, {
                    cacheControl: '3600',
                    upsert: false
                });

            if (error) {
                throw error;
            }

            // Get public URL
            const { data: urlData } = this.supabase.storage
                .from('chat-documents')
                .getPublicUrl(filePath);

            if (this.debug) {
                console.log('✅ File uploaded successfully:', urlData.publicUrl);
            }

            return { 
                data: { 
                    url: urlData.publicUrl, 
                    path: filePath,
                    fileName: file.name,
                    fileSize: file.size,
                    fileType: file.type
                }, 
                error: null 
            };
        } catch (error) {
            console.error('❌ Upload file error:', error);
            return { data: null, error };
        }
    }

    /**
     * Send file message
     */
    async sendFileMessage(conversationId, file) {
        try {
            if (this.debug) {
                console.log('📎 Sending file message');
            }

            // Upload file first
            const uploadResult = await this.uploadChatFile(conversationId, file);
            if (uploadResult.error) {
                throw uploadResult.error;
            }

            // Send message with file info
            const fileInfo = {
                url: uploadResult.data.url,
                fileName: uploadResult.data.fileName,
                fileSize: uploadResult.data.fileSize,
                fileType: uploadResult.data.fileType
            };

            const messageResult = await this.sendMessage(
                conversationId,
                JSON.stringify(fileInfo),
                'file'
            );

            if (this.debug) {
                console.log('✅ File message sent successfully');
            }

            return messageResult;
        } catch (error) {
            console.error('❌ Send file message error:', error);
            return { data: null, error };
        }
    }

    /**
     * Send image message
     */
    async sendImageMessage(conversationId, imageFile) {
        try {
            if (this.debug) {
                console.log('🖼️ Sending image message');
            }

            // Upload image first
            const uploadResult = await this.uploadChatFile(conversationId, imageFile);
            if (uploadResult.error) {
                throw uploadResult.error;
            }

            // Send message with image info
            const imageInfo = {
                url: uploadResult.data.url,
                fileName: uploadResult.data.fileName,
                fileSize: uploadResult.data.fileSize,
                fileType: uploadResult.data.fileType
            };

            const messageResult = await this.sendMessage(
                conversationId,
                JSON.stringify(imageInfo),
                'image'
            );

            if (this.debug) {
                console.log('✅ Image message sent successfully');
            }

            return messageResult;
        } catch (error) {
            console.error('❌ Send image message error:', error);
            return { data: null, error };
        }
    }

    /**
     * Mark messages as read
     */
    async markMessagesAsRead(conversationId) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to mark messages as read');
            }

            if (this.debug) {
                console.log('👁️ Marking messages as read for conversation:', conversationId);
            }

            const { error } = await this.supabase
                .from('messages')
                .update({ read: true })
                .eq('conversation_id', conversationId)
                .neq('sender_email', currentUser.email);

            if (error) {
                throw error;
            }

            if (this.debug) {
                console.log('✅ Messages marked as read');
            }

            return { error: null };
        } catch (error) {
            console.error('❌ Mark messages as read error:', error);
            return { error };
        }
    }

    /**
     * Get unread message count
     */
    async getUnreadMessageCount() {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to get unread count');
            }

            if (this.debug) {
                console.log('🔢 Getting unread message count');
            }

            // Get conversations where user is receiver
            const conversations = await this.supabase
                .from('conversations')
                .select('id')
                .eq('receiver_email', currentUser.email)
                .exec();

            if (conversations.length === 0) {
                return { data: 0, error: null };
            }

            const conversationIds = conversations.map(conv => conv.id);

            // Count unread messages
            const unreadMessages = await this.supabase
                .from('messages')
                .select('id')
                .in('conversation_id', conversationIds)
                .eq('read', false)
                .neq('sender_email', currentUser.email)
                .exec();

            const count = unreadMessages.length;

            if (this.debug) {
                console.log(`✅ Found ${count} unread messages`);
            }

            return { data: count, error: null };
        } catch (error) {
            console.error('❌ Get unread message count error:', error);
            return { data: 0, error };
        }
    }

    /**
     * Delete a conversation
     */
    async deleteConversation(conversationId) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to delete conversations');
            }

            if (this.debug) {
                console.log('🗑️ Deleting conversation:', conversationId);
            }

            // Delete messages first
            await this.supabase
                .from('messages')
                .delete()
                .eq('conversation_id', conversationId);

            // Delete conversation
            const { error } = await this.supabase
                .from('conversations')
                .delete()
                .eq('id', conversationId)
                .or(`sender_email.eq.${currentUser.email},receiver_email.eq.${currentUser.email}`);

            if (error) {
                throw error;
            }

            if (this.debug) {
                console.log('✅ Conversation deleted successfully');
            }

            return { error: null };
        } catch (error) {
            console.error('❌ Delete conversation error:', error);
            return { error };
        }
    }

    /**
     * Search conversations
     */
    async searchConversations(query) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to search conversations');
            }

            if (this.debug) {
                console.log('🔍 Searching conversations for:', query);
            }

            const conversations = await this.supabase
                .from('conversations')
                .select(`
                    *,
                    listings (
                        id,
                        title,
                        price,
                        location,
                        image_url
                    )
                `)
                .or(`sender_email.eq.${currentUser.email},receiver_email.eq.${currentUser.email}`)
                .order('last_message_at', { ascending: false })
                .exec();

            // Filter conversations based on listing title or participant email
            const filteredConversations = conversations.filter(conv => {
                const listingTitle = conv.listings?.title?.toLowerCase() || '';
                const otherEmail = conv.sender_email === currentUser.email ? conv.receiver_email : conv.sender_email;
                
                return listingTitle.includes(query.toLowerCase()) || 
                       otherEmail.toLowerCase().includes(query.toLowerCase());
            });

            if (this.debug) {
                console.log(`✅ Found ${filteredConversations.length} matching conversations`);
            }

            return { data: filteredConversations, error: null };
        } catch (error) {
            console.error('❌ Search conversations error:', error);
            return { data: [], error };
        }
    }

    /**
     * Get conversation details
     */
    async getConversationDetails(conversationId) {
        try {
            if (this.debug) {
                console.log('📋 Getting conversation details:', conversationId);
            }

            const conversation = await this.supabase
                .from('conversations')
                .select(`
                    *,
                    listings (
                        id,
                        title,
                        price,
                        location,
                        image_url,
                        user_email
                    )
                `)
                .eq('id', conversationId)
                .single()
                .exec();

            if (this.debug) {
                console.log('✅ Retrieved conversation details');
            }

            return { data: conversation, error: null };
        } catch (error) {
            console.error('❌ Get conversation details error:', error);
            return { data: null, error };
        }
    }

    /**
     * Listen for new messages (simplified polling for iOS)
     */
    startMessageListener(conversationId, callback) {
        if (this.debug) {
            console.log('👂 Starting message listener for conversation:', conversationId);
        }

        // Stop existing listener if any
        this.stopMessageListener(conversationId);

        let lastMessageCount = 0;

        const checkForNewMessages = async () => {
            try {
                const { data: messages } = await this.getMessages(conversationId);
                
                if (messages.length > lastMessageCount) {
                    const newMessages = messages.slice(lastMessageCount);
                    callback(newMessages);
                    lastMessageCount = messages.length;
                }
            } catch (error) {
                console.error('❌ Message listener error:', error);
            }
        };

        // Initial check
        checkForNewMessages();

        // Poll every 30 seconds (reduced from 2s to lower egress costs)
        const interval = setInterval(checkForNewMessages, 30000);
        this.activeListeners.set(conversationId, interval);

        // Return cleanup function
        return () => this.stopMessageListener(conversationId);
    }

    /**
     * Stop message listener
     */
    stopMessageListener(conversationId) {
        const interval = this.activeListeners.get(conversationId);
        if (interval) {
            clearInterval(interval);
            this.activeListeners.delete(conversationId);
            
            if (this.debug) {
                console.log('🛑 Stopped message listener for conversation:', conversationId);
            }
        }
    }

    /**
     * Stop all message listeners
     */
    stopAllMessageListeners() {
        this.activeListeners.forEach((interval, conversationId) => {
            clearInterval(interval);
            if (this.debug) {
                console.log('🛑 Stopped message listener for conversation:', conversationId);
            }
        });
        this.activeListeners.clear();
    }

    /**
     * Get message statistics
     */
    async getMessageStatistics() {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to get statistics');
            }

            if (this.debug) {
                console.log('📊 Getting message statistics');
            }

            const conversations = await this.getConversations();
            const unreadCount = await this.getUnreadMessageCount();

            const stats = {
                totalConversations: conversations.data.length,
                unreadMessages: unreadCount.data,
                activeChats: conversations.data.filter(conv => {
                    const lastMessage = new Date(conv.last_message_at);
                    const dayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
                    return lastMessage > dayAgo;
                }).length
            };

            if (this.debug) {
                console.log('✅ Retrieved message statistics:', stats);
            }

            return { data: stats, error: null };
        } catch (error) {
            console.error('❌ Get message statistics error:', error);
            return { data: null, error };
        }
    }
}

// Create singleton instance
const iosChatSystem = new IOSChatSystem();

/**
 * Export singleton instance
 */
export default iosChatSystem;

/**
 * Export chat functions for convenience
 */
export const {
    getConversations,
    getOrCreateConversation,
    getMessages,
    sendMessage,
    uploadChatFile,
    sendFileMessage,
    sendImageMessage,
    markMessagesAsRead,
    getUnreadMessageCount,
    deleteConversation,
    searchConversations,
    getConversationDetails,
    startMessageListener,
    stopMessageListener,
    stopAllMessageListeners,
    getMessageStatistics
} = iosChatSystem;

console.log('✅ iOS Chat System module loaded successfully');