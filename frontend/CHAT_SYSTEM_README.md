# RoomFinderAI Chat System Module

A comprehensive, production-ready chat system module extracted from the RoomFinderAI platform. This module provides real-time messaging functionality with file upload capabilities, health monitoring, and seamless integration with Supabase.

## 🚀 Features

### Core Messaging
- **Real-time messaging** - Instant message delivery using Supabase real-time subscriptions
- **Message persistence** - All messages are stored in the database with full history
- **Message threading** - Organized conversations linked to specific listings
- **Message timestamps** - Accurate time tracking for all messages

### File Sharing
- **File upload support** - Upload and share documents, images, and other files
- **File size validation** - Configurable file size limits (default: 5MB)
- **File type restrictions** - Configurable allowed file types
- **Secure file storage** - Files stored in Supabase storage with public URLs
- **Role-based permissions** - Only landlords can upload files

### User Experience
- **Responsive design** - Works seamlessly on desktop, tablet, and mobile
- **Notification system** - Real-time notifications for new messages
- **Conversation management** - Easy access to all user conversations
- **Unread message tracking** - Visual indicators for unread messages
- **Connection monitoring** - Automatic connection status monitoring

### System Health & Monitoring
- **Health checks** - Comprehensive system health monitoring
- **Error recovery** - Automatic error detection and recovery
- **Diagnostics panel** - Real-time system diagnostics (optional)
- **Connection resilience** - Automatic reconnection on connection loss
- **Performance monitoring** - Database error tracking and constraint violation handling

### Integration & Compatibility
- **Modular design** - Clean separation from other system components
- **Authentication integration** - Seamless integration with existing auth systems
- **Supabase integration** - Optimized for Supabase backend
- **Accessibility support** - WCAG compliant design
- **Browser compatibility** - Modern browser support with graceful degradation

## 📁 Files Included

```
/app/frontend/
├── chat-system.js           # Main chat system module
├── chat-system.css          # Complete styling for chat system
├── chat-system-example.html # Integration example and demo
└── CHAT_SYSTEM_README.md    # This documentation file
```

## 🛠 Installation

### 1. Include Required Dependencies

```html
<!-- Tailwind CSS (for utility classes) -->
<script src="https://cdn.tailwindcss.com"></script>

<!-- Supabase Client -->
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>

<!-- Chat System Styles -->
<link rel="stylesheet" href="chat-system.css">
```

### 2. Add Required HTML Structure

```html
<!-- Chat Modal -->
<div id="chatModal" class="chat-modal">
    <div class="chat-modal-content">
        <div class="chat-header">
            <h2 id="chatTitle" class="text-xl font-bold text-white">Chat</h2>
            <span class="close-button chat-close-button">×</span>
        </div>
        <div id="chatMessages" class="chat-messages"></div>
        <div class="chat-input-container">
            <div class="flex items-end space-x-2">
                <div class="flex-1">
                    <textarea id="chatInput" class="chat-input" rows="2" placeholder="Type your message..."></textarea>
                </div>
                <div class="flex flex-col space-y-1">
                    <input type="file" id="fileInput" class="hidden" accept=".pdf,.doc,.docx,.jpg,.jpeg,.png,.txt" multiple>
                    <button id="fileUploadBtn" class="bg-gray-500 text-white px-3 py-2 rounded hover:bg-gray-600 transition text-sm hidden">
                        📎 Files
                    </button>
                    <button id="chatSendBtn" class="chat-send-btn">Send</button>
                </div>
            </div>
            <div id="selectedFiles" class="mt-2 space-y-1 hidden"></div>
        </div>
    </div>
</div>

<!-- Messaging Panel -->
<div id="messagingPanel" class="fixed bottom-4 right-4 z-50">
    <button id="messageToggleBtn" class="bg-blue-600 text-white rounded-full p-4 shadow-lg hover:bg-blue-700 transition flex items-center justify-center w-16 h-16 relative">
        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
        </svg>
        <span id="messageNotificationBadge" class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 text-xs flex items-center justify-center hidden">0</span>
        <span id="profileNotificationBadge" class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 text-xs flex items-center justify-center hidden">0</span>
    </button>
    
    <div id="messagePanel" class="hidden">
        <div class="bg-white rounded-lg shadow-lg border max-w-sm">
            <div class="p-4 border-b">
                <h3 class="font-semibold text-gray-900">Messages</h3>
            </div>
            <div id="conversationTabs" class="max-h-64 overflow-y-auto">
                <!-- Conversations will be loaded here -->
            </div>
        </div>
    </div>
</div>
```

### 3. Initialize the Chat System

```javascript
import ChatSystem from './chat-system.js';

// Initialize Supabase client
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Create and initialize chat system
const chatSystem = new ChatSystem();

await chatSystem.initialize(supabase, {
    maxFileSize: 5 * 1024 * 1024, // 5MB
    allowedFileTypes: ['.pdf', '.doc', '.docx', '.jpg', '.jpeg', '.png', '.txt'],
    enableDiagnostics: true, // Enable diagnostics panel
    enablePolling: true,     // Enable polling fallback
    pollingInterval: 3000    // Polling interval in ms
});
```

## 🔧 Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `maxFileSize` | number | `5242880` (5MB) | Maximum file size for uploads in bytes |
| `allowedFileTypes` | array | `['.pdf', '.doc', '.docx', '.jpg', '.jpeg', '.png', '.txt']` | Allowed file extensions |
| `enableDiagnostics` | boolean | `false` | Enable the diagnostics panel |
| `enablePolling` | boolean | `true` | Enable polling fallback for real-time updates |
| `pollingInterval` | number | `3000` | Polling interval in milliseconds |

## 📚 API Reference

### Core Methods

#### `initialize(supabaseClient, options)`
Initializes the chat system with the provided Supabase client and options.

```javascript
await chatSystem.initialize(supabase, {
    maxFileSize: 10 * 1024 * 1024, // 10MB
    enableDiagnostics: true
});
```

#### `startConversation(listing)`
Starts a new conversation or opens an existing one for a listing.

```javascript
const listing = {
    id: 'listing-123',
    title: 'Beautiful Apartment',
    user_email: 'landlord@example.com'
};

await chatSystem.startConversation(listing);
```

#### `loadMessages(conversationId)`
Loads all messages for a specific conversation.

```javascript
await chatSystem.loadMessages('conversation-id-123');
```

#### `sendMessage()`
Sends a message (called automatically by UI interactions).

```javascript
// Usually called automatically, but can be triggered manually
await chatSystem.sendMessage();
```

### Utility Methods

#### `getStatus()`
Returns the current system status.

```javascript
const status = chatSystem.getStatus();
console.log(status);
// Returns: { isInitialized, elementsReady, currentConversationId, ... }
```

#### `runDiagnostics()`
Runs comprehensive system diagnostics.

```javascript
chatSystem.runDiagnostics();
```

#### `cleanup()`
Cleans up resources and event listeners.

```javascript
chatSystem.cleanup();
```

### Conversation Management

#### `loadUserConversations()`
Loads all conversations for the current user.

```javascript
await chatSystem.loadUserConversations();
```

#### `openConversationInModal(conversationId, title, listingId, userEmail)`
Opens a specific conversation in the chat modal.

```javascript
await chatSystem.openConversationInModal(
    'conv-123',
    'Apartment Discussion',
    'listing-456',
    'user@example.com'
);
```

#### `markConversationAsRead(conversationId)`
Marks a conversation as read.

```javascript
await chatSystem.markConversationAsRead('conversation-id');
```

## 🗄 Database Schema

### Required Tables

#### `conversations`
```sql
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    listing_id UUID NOT NULL,
    sender_email TEXT NOT NULL,
    receiver_email TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (listing_id) REFERENCES listings(id)
);
```

#### `messages`
```sql
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL,
    sender_email TEXT NOT NULL,
    content TEXT,
    message_type TEXT DEFAULT 'text',
    file_url TEXT,
    file_name TEXT,
    file_size INTEGER,
    file_type TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (conversation_id) REFERENCES conversations(id)
);
```

#### `conversation_reads`
```sql
CREATE TABLE conversation_reads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL,
    user_email TEXT NOT NULL,
    last_read_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(conversation_id, user_email),
    FOREIGN KEY (conversation_id) REFERENCES conversations(id)
);
```

#### `profiles`
```sql
CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    first_name TEXT,
    last_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Storage Bucket

Create a storage bucket named `chat-documents` for file uploads:

```sql
-- Create storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-documents', 'chat-documents', true);

-- Set up RLS policies as needed
```

## 🎨 Styling Customization

The chat system uses CSS custom properties for easy theming:

```css
:root {
    --chat-primary-color: #667eea;
    --chat-secondary-color: #764ba2;
    --chat-background-color: #f9fafb;
    --chat-border-color: #e5e7eb;
    --chat-text-color: #374151;
    --chat-border-radius: 1rem;
}
```

### Custom Themes

```css
/* Dark theme example */
.dark-theme {
    --chat-background-color: #1f2937;
    --chat-border-color: #374151;
    --chat-text-color: #f9fafb;
}
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Chat System Not Initializing
```javascript
// Check if all required elements exist
const requiredElements = [
    'chatModal', 'chatMessages', 'chatInput', 
    'chatSendBtn', 'messageToggleBtn'
];

requiredElements.forEach(id => {
    if (!document.getElementById(id)) {
        console.error(`Missing element: ${id}`);
    }
});
```

#### 2. Real-time Updates Not Working
```javascript
// Enable diagnostics to monitor real-time status
const chatSystem = new ChatSystem();
await chatSystem.initialize(supabase, {
    enableDiagnostics: true,
    enablePolling: true // Fallback to polling
});
```

#### 3. File Uploads Failing
```javascript
// Check storage bucket configuration
const { data, error } = await supabase.storage
    .from('chat-documents')
    .list('', { limit: 1 });

if (error) {
    console.error('Storage bucket not accessible:', error);
}
```

### Debug Mode

Enable debug mode for detailed logging:

```javascript
// Temporary debug logging
window.chatSystemDebug = true;

// Or use the built-in diagnostics
chatSystem.runDiagnostics();
```

## 🚀 Advanced Usage

### Custom Event Handling

```javascript
// Listen for chat system events
document.addEventListener('chatSystemInitialized', (event) => {
    console.log('Chat system ready:', event.detail);
});

document.addEventListener('messageReceived', (event) => {
    console.log('New message:', event.detail);
});
```

### Integration with Existing Auth

```javascript
// Custom user validation
chatSystem.validateUser = async (user) => {
    // Custom validation logic
    return user && user.email && user.verified;
};
```

### Custom File Validation

```javascript
// Override file validation
chatSystem.validateFile = (file) => {
    // Custom validation logic
    const isValid = file.size <= customMaxSize && 
                   customAllowedTypes.includes(file.type);
    return { isValid, message: 'Custom validation message' };
};
```

## 📱 Mobile Optimization

The chat system is fully responsive and optimized for mobile devices:

- Touch-friendly interface
- Optimized for small screens
- Keyboard handling for mobile
- Swipe gestures support
- Offline message caching

## ♿ Accessibility Features

- ARIA labels and roles
- Keyboard navigation support
- Screen reader compatibility
- High contrast mode support
- Focus management
- Reduced motion preferences

## 🔐 Security Considerations

- Input sanitization for all user content
- File type validation
- File size restrictions
- Rate limiting (implement on backend)
- User authentication verification
- SQL injection prevention (via Supabase)

## 📈 Performance Optimization

- Lazy loading of conversations
- Message pagination (implement as needed)
- File upload progress tracking
- Connection pooling
- Efficient real-time subscriptions
- Memory leak prevention

## 🤝 Contributing

When contributing to the chat system:

1. Follow the existing code style
2. Add comprehensive error handling
3. Include unit tests for new features
4. Update documentation
5. Test on multiple devices and browsers

## 📄 License

This chat system module is part of the RoomFinderAI platform. See the main project license for details.

## 📞 Support

For support and questions:

- Check the troubleshooting section above
- Review the example implementation
- Enable diagnostics mode for debugging
- Check browser console for error messages

---

**Version:** 1.0.0  
**Last Updated:** January 2025  
**Compatibility:** Modern browsers, Supabase v2+