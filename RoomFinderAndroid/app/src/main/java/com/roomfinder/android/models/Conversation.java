package com.roomfinder.android.models;

import java.util.Date;

/**
 * Model class representing a conversation between two users about a listing
 */
public class Conversation {
    private String id;
    private String listingId;
    private String senderEmail;
    private String receiverEmail;
    private long createdAt;
    private long lastMessageAt;
    
    // Additional fields for UI display
    private String lastMessage;
    private String lastMessageSender;
    private boolean hasUnreadMessages;
    private int unreadCount;
    private String listingTitle;
    private String listingImage;
    private String otherUserName; // Name of the other user in conversation
    private String otherUserEmail; // Email of the other user
    
    public Conversation() {
        this.createdAt = System.currentTimeMillis();
        this.lastMessageAt = System.currentTimeMillis();
        this.hasUnreadMessages = false;
        this.unreadCount = 0;
    }
    
    public Conversation(String listingId, String senderEmail, String receiverEmail) {
        this();
        this.listingId = listingId;
        this.senderEmail = senderEmail;
        this.receiverEmail = receiverEmail;
    }
    
    // Getters and Setters
    public String getId() {
        return id;
    }
    
    public void setId(String id) {
        this.id = id;
    }
    
    public String getListingId() {
        return listingId;
    }
    
    public void setListingId(String listingId) {
        this.listingId = listingId;
    }
    
    public String getSenderEmail() {
        return senderEmail;
    }
    
    public void setSenderEmail(String senderEmail) {
        this.senderEmail = senderEmail;
    }
    
    public String getReceiverEmail() {
        return receiverEmail;
    }
    
    public void setReceiverEmail(String receiverEmail) {
        this.receiverEmail = receiverEmail;
    }
    
    public long getCreatedAt() {
        return createdAt;
    }
    
    public void setCreatedAt(long createdAt) {
        this.createdAt = createdAt;
    }
    
    public long getLastMessageAt() {
        return lastMessageAt;
    }
    
    public void setLastMessageAt(long lastMessageAt) {
        this.lastMessageAt = lastMessageAt;
    }
    
    public String getLastMessage() {
        return lastMessage;
    }
    
    public void setLastMessage(String lastMessage) {
        this.lastMessage = lastMessage;
    }
    
    public String getLastMessageSender() {
        return lastMessageSender;
    }
    
    public void setLastMessageSender(String lastMessageSender) {
        this.lastMessageSender = lastMessageSender;
    }
    
    public boolean hasUnreadMessages() {
        return hasUnreadMessages;
    }
    
    public void setHasUnreadMessages(boolean hasUnreadMessages) {
        this.hasUnreadMessages = hasUnreadMessages;
    }
    
    public int getUnreadCount() {
        return unreadCount;
    }
    
    public void setUnreadCount(int unreadCount) {
        this.unreadCount = unreadCount;
    }
    
    public String getListingTitle() {
        return listingTitle;
    }
    
    public void setListingTitle(String listingTitle) {
        this.listingTitle = listingTitle;
    }
    
    public String getListingImage() {
        return listingImage;
    }
    
    public void setListingImage(String listingImage) {
        this.listingImage = listingImage;
    }
    
    public String getOtherUserName() {
        return otherUserName;
    }
    
    public void setOtherUserName(String otherUserName) {
        this.otherUserName = otherUserName;
    }
    
    public String getOtherUserEmail() {
        return otherUserEmail;
    }
    
    public void setOtherUserEmail(String otherUserEmail) {
        this.otherUserEmail = otherUserEmail;
    }
    
    // Helper methods
    public String getOtherParticipantEmail(String currentUserEmail) {
        if (currentUserEmail.equals(senderEmail)) {
            return receiverEmail;
        } else {
            return senderEmail;
        }
    }
    
    public boolean isParticipant(String userEmail) {
        return userEmail.equals(senderEmail) || userEmail.equals(receiverEmail);
    }
    
    public Date getCreatedAtDate() {
        return new Date(createdAt);
    }
    
    public Date getLastMessageAtDate() {
        return new Date(lastMessageAt);
    }
    
    public String getFormattedLastMessageTime() {
        Date date = new Date(lastMessageAt);
        long now = System.currentTimeMillis();
        long diff = now - lastMessageAt;
        
        // Less than 1 minute
        if (diff < 60 * 1000) {
            return "now";
        }
        
        // Less than 1 hour
        if (diff < 60 * 60 * 1000) {
            int minutes = (int) (diff / (60 * 1000));
            return minutes + "m";
        }
        
        // Less than 24 hours
        if (diff < 24 * 60 * 60 * 1000) {
            int hours = (int) (diff / (60 * 60 * 1000));
            return hours + "h";
        }
        
        // Less than 7 days
        if (diff < 7 * 24 * 60 * 60 * 1000) {
            int days = (int) (diff / (24 * 60 * 60 * 1000));
            return days + "d";
        }
        
        // More than 7 days
        java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("MMM dd", java.util.Locale.getDefault());
        return sdf.format(date);
    }
    
    public String getLastMessagePreview() {
        if (lastMessage == null || lastMessage.isEmpty()) {
            return "No messages yet";
        }
        
        // Truncate long messages
        if (lastMessage.length() > 50) {
            return lastMessage.substring(0, 47) + "...";
        }
        
        return lastMessage;
    }
    
    public String getConversationTitle() {
        if (listingTitle != null && !listingTitle.isEmpty()) {
            return listingTitle;
        }
        
        if (otherUserName != null && !otherUserName.isEmpty()) {
            return otherUserName;
        }
        
        if (otherUserEmail != null && !otherUserEmail.isEmpty()) {
            return otherUserEmail;
        }
        
        return "Conversation";
    }
    
    public void updateFromMessage(ChatMessage message) {
        this.lastMessage = message.getContent();
        this.lastMessageSender = message.getSenderEmail();
        this.lastMessageAt = message.getTimestamp();
        
        // Update unread status if message is not from current user
        // This would need to be handled by the caller with current user context
    }
    
    @Override
    public String toString() {
        return "Conversation{" +
                "id='" + id + '\'' +
                ", listingId='" + listingId + '\'' +
                ", senderEmail='" + senderEmail + '\'' +
                ", receiverEmail='" + receiverEmail + '\'' +
                ", lastMessage='" + getLastMessagePreview() + '\'' +
                ", unreadCount=" + unreadCount +
                '}';
    }
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        
        Conversation that = (Conversation) o;
        
        if (id != null) {
            return id.equals(that.id);
        }
        
        // If no ID, compare by listing and participants
        return listingId.equals(that.listingId) &&
                ((senderEmail.equals(that.senderEmail) && receiverEmail.equals(that.receiverEmail)) ||
                 (senderEmail.equals(that.receiverEmail) && receiverEmail.equals(that.senderEmail)));
    }
    
    @Override
    public int hashCode() {
        if (id != null) {
            return id.hashCode();
        }
        
        int result = listingId != null ? listingId.hashCode() : 0;
        result = 31 * result + (senderEmail != null ? senderEmail.hashCode() : 0);
        result = 31 * result + (receiverEmail != null ? receiverEmail.hashCode() : 0);
        return result;
    }
}