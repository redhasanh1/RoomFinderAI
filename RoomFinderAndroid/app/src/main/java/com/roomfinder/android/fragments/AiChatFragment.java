package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import com.roomfinder.android.R;
import com.roomfinder.android.databinding.FragmentAiChatBinding;
import com.roomfinder.android.adapters.ChatAdapter;
import com.roomfinder.android.auth.SupabaseAuthService;
import com.roomfinder.android.models.ChatMessage;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.services.AiNegotiatorService;
import com.roomfinder.android.network.SupabaseService;
import com.roomfinder.android.utils.NetworkUtils;

import java.util.ArrayList;
import java.util.List;

public class AiChatFragment extends Fragment {
    
    private static final String TAG = "AiChatFragment";
    private FragmentAiChatBinding binding;
    private List<ChatMessage> messages = new ArrayList<>();
    private ChatAdapter chatAdapter;
    private AiNegotiatorService aiService;
    private Handler mainHandler;
    private boolean isProcessingMessage = false;
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentAiChatBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        initializeServices();
        setupToolbar();
        setupRecyclerView();
        setupClickListeners();
        loadWelcomeMessage();
        checkNetworkConnection();
    }
    
    private void initializeServices() {
        aiService = new AiNegotiatorService();
        mainHandler = new Handler(Looper.getMainLooper());
        
        // Check authentication status
        SupabaseAuthService authService = SupabaseAuthService.getInstance(requireContext());
        if (!authService.isAuthenticated()) {
            // This shouldn't happen if navigation is properly protected, but add safety check
            Log.w(TAG, "User not authenticated, redirecting to login");
            requireActivity().onBackPressed(); // Go back to previous screen
            return;
        }
        
        Log.d(TAG, "AI Negotiator services initialized for authenticated user");
    }
    
    private void checkNetworkConnection() {
        if (!NetworkUtils.isNetworkAvailable(requireContext())) {
            addSystemMessage("⚠️ No internet connection. Please check your network and try again.", ChatMessage.MessageType.ERROR);
        }
    }
    
    private void setupToolbar() {
        binding.toolbar.setNavigationOnClickListener(v -> {
            requireActivity().onBackPressed();
        });
    }
    
    private void setupRecyclerView() {
        chatAdapter = new ChatAdapter(messages);
        binding.messagesRecyclerView.setLayoutManager(new LinearLayoutManager(getContext()));
        binding.messagesRecyclerView.setAdapter(chatAdapter);
    }
    
    private void setupClickListeners() {
        binding.sendButton.setOnClickListener(v -> {
            String messageText = binding.messageInput.getText().toString().trim();
            if (!messageText.isEmpty() && !isProcessingMessage) {
                sendMessage(messageText);
            }
        });
        
        // Enter key support
        binding.messageInput.setOnEditorActionListener((v, actionId, event) -> {
            String messageText = binding.messageInput.getText().toString().trim();
            if (!messageText.isEmpty() && !isProcessingMessage) {
                sendMessage(messageText);
                return true;
            }
            return false;
        });
    }
    
    private void loadWelcomeMessage() {
        ChatMessage welcomeMessage = ChatMessage.createAiMessage(
            "Hello! I'm your AI Negotiation Assistant. I can help you:\n\n" +
            "🏠 Find rental properties based on your criteria\n" +
            "💰 Negotiate better rental deals with landlords\n" +
            "📝 Write professional messages to property owners\n" +
            "📊 Get market insights and rental advice\n\n" +
            "Try saying: \"Find me a 2-bedroom apartment in [city] under $2000\" or \"Help me negotiate rent\""
        );
        
        messages.add(welcomeMessage);
        chatAdapter.notifyItemInserted(messages.size() - 1);
        scrollToBottom();
    }
    
    private void sendMessage(String messageText) {
        // Check authentication before processing any AI requests
        SupabaseAuthService authService = SupabaseAuthService.getInstance(requireContext());
        if (!authService.isAuthenticated()) {
            addSystemMessage("❌ Authentication required. Please log in to continue using the AI Negotiator.", ChatMessage.MessageType.ERROR);
            return;
        }
        
        if (!NetworkUtils.isNetworkAvailable(requireContext())) {
            Toast.makeText(getContext(), "No internet connection", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Add user message
        ChatMessage userMessage = ChatMessage.createUserMessage(messageText);
        messages.add(userMessage);
        chatAdapter.notifyItemInserted(messages.size() - 1);
        
        // Clear input and disable sending
        binding.messageInput.setText("");
        setProcessingState(true);
        
        // Scroll to bottom
        scrollToBottom();
        
        // Show typing indicator
        showTypingIndicator();
        
        Log.d(TAG, "Sending message to AI: " + messageText);
        
        // Process message with AI service
        aiService.processMessage(messageText, new AiNegotiatorService.AiResponseCallback() {
            @Override
            public void onSuccess(AiNegotiatorService.AiResponse response) {
                mainHandler.post(() -> {
                    hideTypingIndicator();
                    handleAiResponse(response, messageText);
                    setProcessingState(false);
                });
            }
            
            @Override
            public void onError(String error) {
                mainHandler.post(() -> {
                    hideTypingIndicator();
                    handleAiError(error);
                    setProcessingState(false);
                });
            }
        });
    }
    
    private void handleAiResponse(AiNegotiatorService.AiResponse response, String originalMessage) {
        Log.d(TAG, "Received AI response: " + response.message);
        
        // Add AI response message
        ChatMessage aiMessage = ChatMessage.createAiMessage(response.message);
        messages.add(aiMessage);
        chatAdapter.notifyItemInserted(messages.size() - 1);
        scrollToBottom();
        
        // If the AI extracted property search criteria, search for properties
        if (response.extractedCriteria != null && response.extractedCriteria.hasValidCriteria()) {
            Log.d(TAG, "Property criteria detected, searching database...");
            searchProperties(response.extractedCriteria);
        }
    }
    
    private void searchProperties(AiNegotiatorService.PropertyCriteria criteria) {
        addSystemMessage("🔍 Searching for properties that match your criteria...", ChatMessage.MessageType.SYSTEM_MESSAGE);
        
        SupabaseService supabaseService = SupabaseService.getInstance();
        
        // Use the existing filter method which handles all our criteria
        supabaseService.filterListings(
            criteria.minPrice,
            criteria.maxPrice, 
            criteria.bedrooms,
            criteria.propertyType,
            criteria.location,
            new SupabaseService.ListingsCallback() {
                @Override
                public void onSuccess(List<Listing> listings) {
                    // SupabaseService already posts to main thread, so no need for mainHandler
                    handlePropertySearchResults(listings, criteria);
                }
                
                @Override
                public void onError(String error) {
                    Log.e(TAG, "Property search failed: " + error);
                    addSystemMessage("❌ Property search failed: " + error, ChatMessage.MessageType.ERROR);
                }
            }
        );
    }
    
    private void handlePropertySearchResults(List<Listing> listings, AiNegotiatorService.PropertyCriteria criteria) {
        if (listings.isEmpty()) {
            String message = "😔 No properties found matching your criteria. Try:\n\n" +
                           "• Expanding your search area\n" +
                           "• Increasing your budget range\n" +
                           "• Being more flexible with property type\n\n" +
                           "Would you like me to search with different criteria?";
            
            ChatMessage noResultsMessage = ChatMessage.createPropertySearchMessage(message);
            messages.add(noResultsMessage);
            chatAdapter.notifyItemInserted(messages.size() - 1);
        } else {
            Log.d(TAG, "Found " + listings.size() + " properties");
            
            String resultMessage = String.format("🏠 Found %d properties matching your criteria:\n\n", listings.size());
            
            // Show top 5 properties
            int displayCount = Math.min(5, listings.size());
            for (int i = 0; i < displayCount; i++) {
                Listing listing = listings.get(i);
                resultMessage += String.format("%d. **%s**\n", (i + 1), listing.getTitle());
                resultMessage += String.format("   📍 %s\n", listing.getLocation());
                resultMessage += String.format("   💰 $%,.0f/month\n", listing.getPrice());
                if (listing.getBedrooms() > 0) {
                    resultMessage += String.format("   🛏️ %d bed, %d bath\n", listing.getBedrooms(), listing.getBathrooms());
                }
                resultMessage += "\n";
            }
            
            if (listings.size() > 5) {
                resultMessage += String.format("...and %d more properties\n\n", listings.size() - 5);
            }
            
            resultMessage += "💡 Need help negotiating with any of these landlords? I can help you write professional messages and negotiation strategies!";
            
            ChatMessage resultsMessage = ChatMessage.createPropertySearchMessage(resultMessage);
            messages.add(resultsMessage);
            chatAdapter.notifyItemInserted(messages.size() - 1);
        }
        
        scrollToBottom();
    }
    
    private void handleAiError(String error) {
        Log.e(TAG, "AI response error: " + error);
        
        String errorMessage;
        if (error.contains("Network")) {
            errorMessage = "❌ Network error. Please check your internet connection and try again.";
        } else if (error.contains("API")) {
            errorMessage = "❌ AI service temporarily unavailable. Please try again in a moment.";
        } else {
            errorMessage = "❌ Sorry, I encountered an error. Please try rephrasing your message.";
        }
        
        addSystemMessage(errorMessage, ChatMessage.MessageType.ERROR);
    }
    
    private void showTypingIndicator() {
        ChatMessage typingMessage = ChatMessage.createTypingIndicator();
        messages.add(typingMessage);
        chatAdapter.notifyItemInserted(messages.size() - 1);
        scrollToBottom();
    }
    
    private void hideTypingIndicator() {
        // Remove typing indicator if it exists
        if (!messages.isEmpty()) {
            ChatMessage lastMessage = messages.get(messages.size() - 1);
            if (lastMessage.isTyping()) {
                messages.remove(messages.size() - 1);
                chatAdapter.notifyItemRemoved(messages.size());
            }
        }
    }
    
    private void addSystemMessage(String message, ChatMessage.MessageType type) {
        ChatMessage systemMessage = new ChatMessage(message, "system", type);
        messages.add(systemMessage);
        chatAdapter.notifyItemInserted(messages.size() - 1);
        scrollToBottom();
    }
    
    private void setProcessingState(boolean processing) {
        isProcessingMessage = processing;
        binding.sendButton.setEnabled(!processing);
        binding.messageInput.setEnabled(!processing);
        
        if (processing) {
            binding.sendButton.setAlpha(0.5f);
        } else {
            binding.sendButton.setAlpha(1.0f);
        }
    }
    
    private void scrollToBottom() {
        if (messages.size() > 0) {
            binding.messagesRecyclerView.smoothScrollToPosition(messages.size() - 1);
        }
    }
    
    @Override
    public void onDestroyView() {
        super.onDestroyView();
        // Cancel any pending network requests
        NetworkUtils.cancelAllRequests();
        binding = null;
    }

    // Simple ChatAdapter (you might want to create a separate file for this)
    private static class ChatAdapter extends androidx.recyclerview.widget.RecyclerView.Adapter<ChatAdapter.ChatViewHolder> {
        private List<ChatMessage> messages;
        
        public ChatAdapter(List<ChatMessage> messages) {
            this.messages = messages;
        }
        
        @NonNull
        @Override
        public ChatViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            // Create a proper chat bubble layout
            android.widget.LinearLayout container = new android.widget.LinearLayout(parent.getContext());
            container.setOrientation(android.widget.LinearLayout.VERTICAL);
            container.setPadding(16, 8, 16, 8);
            
            android.widget.TextView textView = new android.widget.TextView(parent.getContext());
            textView.setPadding(24, 16, 24, 16);
            textView.setTextSize(16);
            textView.setLineSpacing(4, 1.2f);
            
            container.addView(textView);
            return new ChatViewHolder(container, textView);
        }
        
        @Override
        public void onBindViewHolder(@NonNull ChatViewHolder holder, int position) {
            ChatMessage message = messages.get(position);
            
            holder.textView.setText(message.getContent());
            
            // Style based on sender and message type
            android.widget.LinearLayout.LayoutParams params = 
                (android.widget.LinearLayout.LayoutParams) holder.textView.getLayoutParams();
            
            if (message.isFromUser()) {
                // User messages - right aligned, blue background
                params.gravity = android.view.Gravity.END;
                holder.textView.setBackgroundResource(android.R.drawable.editbox_background);
                holder.textView.getBackground().setTint(0xFF6366F1); // Purple primary
                holder.textView.setTextColor(0xFFFFFFFF); // White text
                params.setMargins(80, 8, 16, 8);
            } else if (message.isSystemMessage() || message.isErrorMessage()) {
                // System/error messages - center aligned
                params.gravity = android.view.Gravity.CENTER;
                holder.textView.setBackgroundResource(android.R.drawable.editbox_background);
                
                if (message.isErrorMessage()) {
                    holder.textView.getBackground().setTint(0xFFEF4444); // Error red
                    holder.textView.setTextColor(0xFFFFFFFF);
                } else {
                    holder.textView.getBackground().setTint(0xFFF3F4F6); // Light gray
                    holder.textView.setTextColor(0xFF6B7280);
                }
                
                holder.textView.setTextSize(14);
                params.setMargins(32, 8, 32, 8);
            } else {
                // AI messages - left aligned, light background
                params.gravity = android.view.Gravity.START;
                holder.textView.setBackgroundResource(android.R.drawable.editbox_background);
                holder.textView.getBackground().setTint(0xFFFFFFFF); // White
                holder.textView.setTextColor(0xFF1F2937); // Dark text
                params.setMargins(16, 8, 80, 8);
                
                // Add subtle shadow for AI messages
                holder.textView.setElevation(2f);
            }
            
            // Special styling for typing indicator
            if (message.isTyping()) {
                holder.textView.setTextSize(14);
                holder.textView.setAlpha(0.7f);
            } else {
                holder.textView.setAlpha(1.0f);
            }
            
            holder.textView.setLayoutParams(params);
        }
        
        @Override
        public int getItemCount() {
            return messages.size();
        }
        
        static class ChatViewHolder extends androidx.recyclerview.widget.RecyclerView.ViewHolder {
            android.widget.TextView textView;
            
            public ChatViewHolder(@NonNull View itemView, android.widget.TextView textView) {
                super(itemView);
                this.textView = textView;
            }
        }
    }
}