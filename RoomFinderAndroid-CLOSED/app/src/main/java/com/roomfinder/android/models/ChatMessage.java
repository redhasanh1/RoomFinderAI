package com.roomfinder.android.models;

import java.util.Date;

public class ChatMessage {
    private String id;
    private String content;
    private String sender; // "user" or "ai" for AI chat, or email for real messaging
    private String senderEmail; // Email of the sender for real messaging
    private String conversationId; // For real messaging conversations
    private long timestamp;
    private boolean isTyping;
    private boolean delivered; // For message delivery status
    private MessageType type;
    private String propertyId; // For property-related messages
    private String messageType; // "text", "file", "lease" for real messaging
    private String fileUrl; // For file messages
    private String fileName; // For file messages
    private Long fileSize; // For file messages
    private String fileType; // For file messages
    private Listing associatedListing; // For property card messages
    
    public enum MessageType {
        TEXT,
        PROPERTY_SEARCH,
        NEGOTIATION_ADVICE,
        TEMPLATE_MESSAGE,
        SYSTEM_MESSAGE,
        ERROR,
        USER_MESSAGE,
        FILE_MESSAGE,
        PROPERTY_CARD
    }
    
    // Constructors
    public ChatMessage() {
        this.timestamp = System.currentTimeMillis();
        this.type = MessageType.TEXT;
        this.isTyping = false;
        this.delivered = false;
        this.messageType = "text";
    }
    
    public ChatMessage(String content, String sender) {
        this();
        this.content = content;
        this.sender = sender;
    }
    
    public ChatMessage(String content, String sender, MessageType type) {
        this(content, sender);
        this.type = type;
    }
    
    // Static factory methods
    public static ChatMessage createUserMessage(String content) {
        return new ChatMessage(content, "user", MessageType.TEXT);
    }
    
    public static ChatMessage createRealUserMessage(String content, String senderEmail, String conversationId) {
        ChatMessage message = new ChatMessage(content, senderEmail, MessageType.USER_MESSAGE);
        message.setSenderEmail(senderEmail);
        message.setConversationId(conversationId);
        return message;
    }
    
    public static ChatMessage createFileMessage(String fileName, String fileUrl, String senderEmail, String conversationId) {
        ChatMessage message = new ChatMessage(fileName, senderEmail, MessageType.FILE_MESSAGE);
        message.setSenderEmail(senderEmail);
        message.setConversationId(conversationId);
        message.setFileUrl(fileUrl);
        message.setFileName(fileName);
        message.setMessageType("file");
        return message;
    }
    
    public static ChatMessage createAiMessage(String content) {
        return new ChatMessage(content, "ai", MessageType.TEXT);
    }
    
    public static ChatMessage createPropertySearchMessage(String content) {
        return new ChatMessage(content, "ai", MessageType.PROPERTY_SEARCH);
    }
    
    public static ChatMessage createNegotiationAdvice(String content) {
        return new ChatMessage(content, "ai", MessageType.NEGOTIATION_ADVICE);
    }
    
    public static ChatMessage createTemplateMessage(String content) {
        return new ChatMessage(content, "ai", MessageType.TEMPLATE_MESSAGE);
    }
    
    public static ChatMessage createSystemMessage(String content) {
        return new ChatMessage(content, "system", MessageType.SYSTEM_MESSAGE);
    }
    
    public static ChatMessage createErrorMessage(String content) {
        return new ChatMessage(content, "system", MessageType.ERROR);
    }
    
    public static ChatMessage createTypingIndicator() {
        ChatMessage message = new ChatMessage("AI is typing...", "ai", MessageType.SYSTEM_MESSAGE);
        message.setTyping(true);
        return message;
    }
    
    public static ChatMessage createPropertyCardMessage(String content, Listing listing) {
        ChatMessage message = new ChatMessage(content, "ai", MessageType.PROPERTY_CARD);
        message.setAssociatedListing(listing);
        return message;
    }
    
    // Getters and Setters
    public String getId() {
        return id;
    }
    
    public void setId(String id) {
        this.id = id;
    }
    
    public String getContent() {
        return content;
    }
    
    public void setContent(String content) {
        this.content = content;
    }
    
    public String getSender() {
        return sender;
    }
    
    public void setSender(String sender) {
        this.sender = sender;
    }
    
    public String getSenderEmail() {
        return senderEmail;
    }
    
    public void setSenderEmail(String senderEmail) {
        this.senderEmail = senderEmail;
    }
    
    public String getConversationId() {
        return conversationId;
    }
    
    public void setConversationId(String conversationId) {
        this.conversationId = conversationId;
    }
    
    public String getMessageType() {
        return messageType;
    }
    
    public void setMessageType(String messageType) {
        this.messageType = messageType;
    }
    
    public String getFileUrl() {
        return fileUrl;
    }
    
    public void setFileUrl(String fileUrl) {
        this.fileUrl = fileUrl;
    }
    
    public String getFileName() {
        return fileName;
    }
    
    public void setFileName(String fileName) {
        this.fileName = fileName;
    }
    
    public Long getFileSize() {
        return fileSize;
    }
    
    public void setFileSize(Long fileSize) {
        this.fileSize = fileSize;
    }
    
    public String getFileType() {
        return fileType;
    }
    
    public void setFileType(String fileType) {
        this.fileType = fileType;
    }
    
    public long getTimestamp() {
        return timestamp;
    }
    
    public void setTimestamp(long timestamp) {
        this.timestamp = timestamp;
    }
    
    public Date getDate() {
        return new Date(timestamp);
    }
    
    public boolean isTyping() {
        return isTyping;
    }
    
    public void setTyping(boolean typing) {
        isTyping = typing;
    }
    
    public MessageType getType() {
        return type;
    }
    
    public void setType(MessageType type) {
        this.type = type;
    }
    
    public String getPropertyId() {
        return propertyId;
    }
    
    public void setPropertyId(String propertyId) {
        this.propertyId = propertyId;
    }
    
    public boolean isDelivered() {
        return delivered;
    }
    
    public void setDelivered(boolean delivered) {
        this.delivered = delivered;
    }
    
    public Listing getAssociatedListing() {
        return associatedListing;
    }
    
    public void setAssociatedListing(Listing associatedListing) {
        this.associatedListing = associatedListing;
    }
    
    // Helper methods
    public boolean isFromUser() {
        return "user".equals(sender);
    }
    
    public boolean isFromAi() {
        return "ai".equals(sender);
    }
    
    public boolean isFromCurrentUser(String currentUserEmail) {
        return currentUserEmail != null && currentUserEmail.equals(senderEmail);
    }
    
    public boolean isFileMessage() {
        return type == MessageType.FILE_MESSAGE || "file".equals(messageType);
    }
    
    public boolean isRealUserMessage() {
        return type == MessageType.USER_MESSAGE && senderEmail != null;
    }
    
    public boolean isSystemMessage() {
        return "system".equals(sender) || type == MessageType.SYSTEM_MESSAGE;
    }
    
    public boolean isErrorMessage() {
        return type == MessageType.ERROR;
    }
    
    public boolean isPropertyRelated() {
        return type == MessageType.PROPERTY_SEARCH || propertyId != null;
    }
    
    public boolean isNegotiationAdvice() {
        return type == MessageType.NEGOTIATION_ADVICE;
    }
    
    public boolean isTemplateMessage() {
        return type == MessageType.TEMPLATE_MESSAGE;
    }
    
    // Format timestamp for display
    public String getFormattedTime() {
        Date date = new Date(timestamp);
        java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault());
        return sdf.format(date);
    }
    
    public String getFormattedFileSize() {
        if (fileSize == null) return "";
        
        long bytes = fileSize;
        if (bytes < 1024) return bytes + " B";
        
        int exp = (int) (Math.log(bytes) / Math.log(1024));
        String pre = "KMGTPE".charAt(exp-1) + "";
        return String.format("%.1f %sB", bytes / Math.pow(1024, exp), pre);
    }
    
    public String getFormattedDate() {
        Date date = new Date(timestamp);
        java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("MMM dd, yyyy", java.util.Locale.getDefault());
        return sdf.format(date);
    }
    
    // Check if message is recent (within last 5 minutes)
    public boolean isRecent() {
        long fiveMinutesAgo = System.currentTimeMillis() - (5 * 60 * 1000);
        return timestamp > fiveMinutesAgo;
    }
    
    // Get content preview (first 50 characters)
    public String getPreview() {
        if (content == null || content.isEmpty()) {
            return "";
        }
        
        if (content.length() <= 50) {
            return content;
        }
        
        return content.substring(0, 47) + "...";
    }
    
    @Override
    public String toString() {
        return "ChatMessage{" +
                "id='" + id + '\'' +
                ", sender='" + sender + '\'' +
                ", type=" + type +
                ", timestamp=" + timestamp +
                ", content='" + getPreview() + '\'' +
                ", isTyping=" + isTyping +
                '}';
    }
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        
        ChatMessage that = (ChatMessage) o;
        
        if (id != null) {
            return id.equals(that.id);
        }
        
        // If no ID, compare by content, sender, and timestamp
        return timestamp == that.timestamp &&
                sender.equals(that.sender) &&
                content.equals(that.content);
    }
    
    @Override
    public int hashCode() {
        if (id != null) {
            return id.hashCode();
        }
        
        int result = content != null ? content.hashCode() : 0;
        result = 31 * result + (sender != null ? sender.hashCode() : 0);
        result = 31 * result + (int) (timestamp ^ (timestamp >>> 32));
        return result;
    }
}