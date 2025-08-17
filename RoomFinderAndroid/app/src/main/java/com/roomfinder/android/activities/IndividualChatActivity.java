package com.roomfinder.android.activities;

import android.content.Intent;
import android.os.Bundle;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import com.roomfinder.android.adapters.ChatAdapter;
import com.roomfinder.android.databinding.ActivityIndividualChatBinding;
import com.roomfinder.android.models.ChatMessage;
import com.roomfinder.android.models.Conversation;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.services.RealTimeChatService;
import com.roomfinder.android.auth.AuthManager;

import java.util.ArrayList;
import java.util.List;

public class IndividualChatActivity extends AppCompatActivity implements RealTimeChatService.MessageListener {
    
    private static final String TAG = "IndividualChatActivity";
    
    private ActivityIndividualChatBinding binding;
    private ChatAdapter chatAdapter;
    private List<ChatMessage> messages = new ArrayList<>();
    
    // Real-time messaging
    private RealTimeChatService chatService;
    private String conversationId;
    private String currentUserEmail;
    private String otherUserEmail;
    private Listing currentListing;
    private boolean isLoadingMessages = false;
    
    // Intent data
    private String listingId;
    private String listingTitle;
    private String listingOwnerEmail;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        binding = ActivityIndividualChatBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        
        // Get user authentication
        AuthManager authManager = AuthManager.getInstance(this);
        if (!authManager.isUserAuthenticated()) {
            Toast.makeText(this, "Please log in to use chat", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }
        
        currentUserEmail = authManager.getCurrentUser().getEmail();
        
        // Get intent data
        getIntentData();
        
        if (listingId == null || otherUserEmail == null) {
            Toast.makeText(this, "Error: Missing chat information", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }
        
        setupUI();
        initializeChatService();
    }
    
    private void getIntentData() {
        Intent intent = getIntent();
        
        // Check if this is an existing conversation
        conversationId = intent.getStringExtra("conversation_id");
        
        // Get listing and other user data
        listingId = intent.getStringExtra("listing_id");
        listingTitle = intent.getStringExtra("listing_title");
        listingOwnerEmail = intent.getStringExtra("owner_email");
        otherUserEmail = intent.getStringExtra("other_user_email");
        
        // If no explicit other_user_email, use owner_email
        if (otherUserEmail == null) {
            otherUserEmail = listingOwnerEmail;
        }
        
        // Create listing object if we have the data
        if (listingId != null && listingTitle != null) {
            currentListing = new Listing();
            currentListing.setId(listingId);
            currentListing.setTitle(listingTitle);
            currentListing.setUserEmail(listingOwnerEmail);
        }
        
        Log.d(TAG, "Intent data - listingId: " + listingId + ", otherUser: " + otherUserEmail + ", conversationId: " + conversationId);
    }
    
    private void setupUI() {
        // Set title
        if (listingTitle != null) {
            binding.toolbar.setTitle("Chat about " + listingTitle);
        } else {
            binding.toolbar.setTitle("Chat with " + getDisplayName(otherUserEmail));
        }
        
        // Setup RecyclerView
        chatAdapter = new ChatAdapter(messages, currentUserEmail);
        binding.messagesRecyclerView.setLayoutManager(new LinearLayoutManager(this));
        binding.messagesRecyclerView.setAdapter(chatAdapter);
        
        // Setup click listeners
        binding.sendButton.setOnClickListener(v -> sendMessage());
        binding.toolbar.setNavigationOnClickListener(v -> finish());
        
        // Handle enter key in message input
        binding.messageInput.setOnEditorActionListener((v, actionId, event) -> {
            sendMessage();
            return true;
        });
    }
    
    private String getDisplayName(String email) {
        if (email == null) return "User";
        
        // Extract name from email (before @)
        int atIndex = email.indexOf('@');
        if (atIndex > 0) {
            return email.substring(0, atIndex);
        }
        return email;
    }
    
    private void initializeChatService() {
        chatService = RealTimeChatService.getInstance(this);
        chatService.initialize();
        
        if (conversationId != null) {
            // Existing conversation
            loadMessagesForConversation();
        } else if (currentListing != null) {
            // New conversation
            startNewConversation();
        } else {
            Toast.makeText(this, "Cannot start chat: Missing listing information", Toast.LENGTH_SHORT).show();
            finish();
        }
    }
    
    private void startNewConversation() {
        if (currentListing == null || otherUserEmail == null) {
            Toast.makeText(this, "Cannot start chat: Missing information", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }
        
        Log.d(TAG, "Starting new conversation for listing: " + currentListing.getId() + " with user: " + otherUserEmail);
        
        chatService.startConversation(currentListing, otherUserEmail, new RealTimeChatService.ConversationCallback() {
            @Override
            public void onSuccess(Conversation conversation) {
                conversationId = conversation.getId();
                Log.d(TAG, "Conversation started: " + conversationId);
                loadMessagesForConversation();
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Failed to start conversation: " + error);
                Toast.makeText(IndividualChatActivity.this, "Failed to start chat: " + error, Toast.LENGTH_SHORT).show();
                finish();
            }
        });
    }
    
    private void loadMessagesForConversation() {
        if (conversationId == null || isLoadingMessages) return;
        
        isLoadingMessages = true;
        Log.d(TAG, "Loading messages for conversation: " + conversationId);
        
        // Register for real-time updates
        chatService.registerMessageListener(conversationId, this);
        
        // Load existing messages
        chatService.loadMessages(conversationId, new RealTimeChatService.MessagesCallback() {
            @Override
            public void onSuccess(List<ChatMessage> loadedMessages) {
                isLoadingMessages = false;
                runOnUiThread(() -> {
                    messages.clear();
                    messages.addAll(loadedMessages);
                    chatAdapter.notifyDataSetChanged();
                    scrollToBottom();
                    Log.d(TAG, "Loaded " + loadedMessages.size() + " messages");
                });
            }
            
            @Override
            public void onError(String error) {
                isLoadingMessages = false;
                runOnUiThread(() -> {
                    Log.e(TAG, "Failed to load messages: " + error);
                    Toast.makeText(IndividualChatActivity.this, "Failed to load messages", Toast.LENGTH_SHORT).show();
                });
            }
        });
    }
    
    private void sendMessage() {
        String messageText = binding.messageInput.getText().toString().trim();
        if (TextUtils.isEmpty(messageText) || conversationId == null) {
            return;
        }
        
        // Clear input immediately for better UX
        binding.messageInput.setText("");
        
        Log.d(TAG, "Sending message: " + messageText);
        
        // Send message through chat service
        chatService.sendMessage(conversationId, messageText, this);
    }
    
    private void scrollToBottom() {
        if (messages.size() > 0) {
            binding.messagesRecyclerView.scrollToPosition(messages.size() - 1);
        }
    }
    
    // RealTimeChatService.MessageListener implementation
    @Override
    public void onMessageReceived(ChatMessage message) {
        runOnUiThread(() -> {
            // Only add if not already in list (avoid duplicates)
            boolean exists = false;
            for (ChatMessage existingMessage : messages) {
                if (message.getId() != null && message.getId().equals(existingMessage.getId())) {
                    exists = true;
                    break;
                }
            }
            
            if (!exists) {
                messages.add(message);
                chatAdapter.notifyItemInserted(messages.size() - 1);
                scrollToBottom();
                Log.d(TAG, "Message received: " + message.getContent());
            }
        });
    }
    
    @Override
    public void onMessageSent(ChatMessage message) {
        runOnUiThread(() -> {
            // Add sent message to UI
            messages.add(message);
            chatAdapter.notifyItemInserted(messages.size() - 1);
            scrollToBottom();
            Log.d(TAG, "Message sent: " + message.getContent());
        });
    }
    
    @Override
    public void onTypingIndicator(String senderEmail, boolean isTyping) {
        // Handle typing indicator if needed
        Log.d(TAG, "Typing indicator: " + senderEmail + " is " + (isTyping ? "typing" : "not typing"));
    }
    
    @Override
    public void onError(String error) {
        runOnUiThread(() -> {
            Toast.makeText(this, "Chat error: " + error, Toast.LENGTH_SHORT).show();
            Log.e(TAG, "Chat error: " + error);
        });
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        
        // Cleanup chat service
        if (chatService != null && conversationId != null) {
            chatService.unregisterMessageListener(conversationId);
        }
    }
    
    // Static helper methods to start chat from other activities
    public static void startChatWithUser(android.content.Context context, String listingId, String listingTitle, String ownerEmail) {
        Intent intent = new Intent(context, IndividualChatActivity.class);
        intent.putExtra("listing_id", listingId);
        intent.putExtra("listing_title", listingTitle);
        intent.putExtra("owner_email", ownerEmail);
        intent.putExtra("other_user_email", ownerEmail);
        context.startActivity(intent);
    }
    
    public static void openExistingConversation(android.content.Context context, String conversationId, String otherUserEmail) {
        Intent intent = new Intent(context, IndividualChatActivity.class);
        intent.putExtra("conversation_id", conversationId);
        intent.putExtra("other_user_email", otherUserEmail);
        context.startActivity(intent);
    }
}