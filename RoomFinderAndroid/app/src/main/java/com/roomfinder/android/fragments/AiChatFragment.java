package com.roomfinder.android.fragments;

import android.animation.AnimatorInflater;
import android.animation.AnimatorSet;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.HapticFeedbackConstants;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.LinearSmoothScroller;
import androidx.recyclerview.widget.RecyclerView;
import com.roomfinder.android.R;
import com.roomfinder.android.databinding.FragmentAiChatBinding;
import com.roomfinder.android.adapters.ChatAdapter;
import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.models.ChatMessage;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.services.AiNegotiatorService;
import com.roomfinder.android.network.SupabaseService;
import com.roomfinder.android.utils.NetworkUtils;
import com.roomfinder.android.activities.IndividualChatActivity;
import android.content.Intent;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.HashMap;

public class AiChatFragment extends Fragment {
    
    private static final String TAG = "AiChatFragment";
    private FragmentAiChatBinding binding;
    private List<ChatMessage> messages = new ArrayList<>();
    private ChatAdapter chatAdapter;
    private AiNegotiatorService aiService;
    private Handler mainHandler;
    private boolean isProcessingMessage = false;
    private AnimatorSet sendButtonPressAnimator;
    private AnimatorSet sendButtonReleaseAnimator;
    private LinearLayoutManager layoutManager;
    
    // Conversation context management (matching web ai-chat.js exactly)
    private String pendingUserResponse = null; // Tracks expected user response type
    private NegotiationState negotiationState = NegotiationState.IDLE;
    private List<Listing> matchingListings = new ArrayList<>();
    private Map<String, Boolean> activeConversations = new HashMap<>(); // Track active chat contexts
    private List<String> conversationHistory = new ArrayList<>(); // Store conversation for context
    
    public enum NegotiationState {
        IDLE,           // No active negotiation context
        AWAITING_CONFIRMATION,  // Waiting for user to confirm negotiation
        NEGOTIATING     // Actively negotiating with landlords
    }
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentAiChatBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        initializeServices();
        initializeAnimations();
        setupToolbar();
        setupRecyclerView();
        setupClickListeners();
        setupSendButtonAnimations();
        loadConversationHistory(); // Load previous conversation like web version
        if (conversationHistory.isEmpty()) {
            loadWelcomeMessage(); // Only show welcome if no previous conversation
        }
        checkNetworkConnection();
    }
    
    private void initializeServices() {
        aiService = new AiNegotiatorService();
        mainHandler = new Handler(Looper.getMainLooper());
        
        // Check authentication status
        AuthManager authManager = AuthManager.getInstance(requireContext());
        if (!authManager.isUserAuthenticated()) {
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
    
    private void initializeAnimations() {
        try {
            // Initialize send button animations
            sendButtonPressAnimator = (AnimatorSet) AnimatorInflater.loadAnimator(
                requireContext(), R.animator.send_button_press);
            sendButtonReleaseAnimator = (AnimatorSet) AnimatorInflater.loadAnimator(
                requireContext(), R.animator.send_button_release);
                
            sendButtonPressAnimator.setTarget(binding.sendButton);
            sendButtonReleaseAnimator.setTarget(binding.sendButton);
        } catch (Exception e) {
            Log.w(TAG, "Failed to load animations", e);
        }
    }
    
    private void setupRecyclerView() {
        chatAdapter = new ChatAdapter(messages);
        layoutManager = new LinearLayoutManager(getContext());
        layoutManager.setStackFromEnd(true);
        
        // Set up property card click listener
        chatAdapter.setOnPropertyCardClickListener(this::contactLandlord);
        
        binding.messagesRecyclerView.setLayoutManager(layoutManager);
        binding.messagesRecyclerView.setAdapter(chatAdapter);
        
        // Enable smooth scrolling
        binding.messagesRecyclerView.setHasFixedSize(false);
        binding.messagesRecyclerView.setItemAnimator(new androidx.recyclerview.widget.DefaultItemAnimator());
        
        // Add scroll listener for better UX
        binding.messagesRecyclerView.addOnScrollListener(new RecyclerView.OnScrollListener() {
            @Override
            public void onScrolled(@NonNull RecyclerView recyclerView, int dx, int dy) {
                super.onScrolled(recyclerView, dx, dy);
                // Add any scroll-based effects here if needed
            }
        });
    }
    
    private void setupSendButtonAnimations() {
        binding.sendButton.setOnTouchListener((v, event) -> {
            switch (event.getAction()) {
                case MotionEvent.ACTION_DOWN:
                    // Haptic feedback
                    v.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY);
                    
                    // Press animation
                    if (sendButtonPressAnimator != null && !isProcessingMessage) {
                        sendButtonReleaseAnimator.cancel();
                        sendButtonPressAnimator.start();
                    }
                    return false; // Allow click to continue
                    
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    // Release animation
                    if (sendButtonReleaseAnimator != null) {
                        sendButtonPressAnimator.cancel();
                        sendButtonReleaseAnimator.start();
                    }
                    return false;
            }
            return false;
        });
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
    
    // Check if user response matches conversation context (matching web ai-chat.js exactly)
    private boolean checkForNegotiationResponse(String message) {
        Log.d(TAG, "🔍 [NEGOTIATION CHECK] Starting check for message: " + message);
        String cleanMessage = message.toLowerCase().trim();
        
        // First check: Do we have any active conversations waiting for user response?
        boolean hasActiveContext = pendingUserResponse != null || !activeConversations.isEmpty();
        
        if (hasActiveContext) {
            Log.d(TAG, "🔍 [NEGOTIATION CHECK] Has active context, checking responses...");
            
            // Check for affirmative responses (matching web version exactly)
            String[] affirmativeResponses = {"yes", "sure", "ok", "okay", "please", "go ahead", 
                                            "proceed", "contact them", "negotiate", "send message"};
            boolean isAffirmative = false;
            for (String response : affirmativeResponses) {
                if (cleanMessage.contains(response)) {
                    isAffirmative = true;
                    break;
                }
            }
            
            if (isAffirmative && !matchingListings.isEmpty()) {
                Log.d(TAG, "✅ [NEGOTIATION CHECK] Affirmative response detected, starting negotiations");
                
                ChatMessage aiMessage = ChatMessage.createAiMessage(
                    "🤖 Great! I'll contact the landlords for you using smart negotiation strategies..."
                );
                messages.add(aiMessage);
                chatAdapter.notifyItemInserted(messages.size() - 1);
                scrollToBottom();
                
                // Clear pending response
                pendingUserResponse = null;
                negotiationState = NegotiationState.NEGOTIATING;
                
                // Start negotiations for all matching listings (like web version)
                mainHandler.postDelayed(() -> startNegotiationsForAllListings(), 1000);
                return true;
            }
            
            // Check for negative responses
            String[] negativeResponses = {"no", "not", "don't", "nope", "cancel", "nevermind"};
            boolean isNegative = false;
            for (String response : negativeResponses) {
                if (cleanMessage.contains(response)) {
                    isNegative = true;
                    break;
                }
            }
            
            if (isNegative) {
                Log.d(TAG, "❌ [NEGOTIATION CHECK] Negative response detected, canceling");
                
                // Clear pending response
                pendingUserResponse = null;
                negotiationState = NegotiationState.IDLE;
                activeConversations.clear();
                
                ChatMessage cancelMessage = ChatMessage.createAiMessage(
                    "👍 No problem! Feel free to ask if you need help with anything else, like finding more properties or getting rental advice."
                );
                messages.add(cancelMessage);
                chatAdapter.notifyItemInserted(messages.size() - 1);
                scrollToBottom();
                return true;
            }
        }
        
        // Check for direct negotiation requests about specific listings
        String[] negotiationKeywords = {"negotiate", "contact", "message", "talk to landlord", "reach out"};
        boolean hasNegotiationKeyword = false;
        for (String keyword : negotiationKeywords) {
            if (cleanMessage.contains(keyword)) {
                hasNegotiationKeyword = true;
                break;
            }
        }
        
        if (hasNegotiationKeyword && !matchingListings.isEmpty()) {
            Log.d(TAG, "✅ [NEGOTIATION CHECK] Direct negotiation request detected");
            ChatMessage aiMessage = ChatMessage.createAiMessage(
                "🤖 I'll help you negotiate with the landlords. Starting contact now..."
            );
            messages.add(aiMessage);
            chatAdapter.notifyItemInserted(messages.size() - 1);
            scrollToBottom();
            
            mainHandler.postDelayed(() -> startNegotiationsForAllListings(), 1000);
            return true;
        }
        
        Log.d(TAG, "❌ [NEGOTIATION CHECK] No negotiation response detected");
        return false;
    }
    
    private void sendMessage(String messageText) {
        // Check authentication before processing any AI requests
        AuthManager authManager = AuthManager.getInstance(requireContext());
        if (!authManager.isUserAuthenticated()) {
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
        
        // Save conversation history after each message (like web version)
        conversationHistory.add(messageText);
        saveConversationHistory();
        
        // Clear input and disable sending
        binding.messageInput.setText("");
        setProcessingState(true);
        
        // Scroll to bottom
        scrollToBottom();
        
        // First check if this is a response to a pending negotiation question
        if (checkForNegotiationResponse(messageText)) {
            setProcessingState(false);
            return;
        }
        
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
        // Log the criteria being used for search
        Log.d(TAG, "🔍 Search Criteria Debug:");
        Log.d(TAG, "  Location: " + (criteria.location != null ? criteria.location : "not specified"));
        Log.d(TAG, "  Max Price: " + (criteria.maxPrice != null ? "$" + criteria.maxPrice : "not specified"));
        Log.d(TAG, "  Min Price: " + (criteria.minPrice != null ? "$" + criteria.minPrice : "not specified"));
        Log.d(TAG, "  Property Type: " + (criteria.propertyType != null ? criteria.propertyType : "not specified"));
        Log.d(TAG, "  Bedrooms: " + (criteria.bedrooms != null ? criteria.bedrooms : "not specified"));
        Log.d(TAG, "  Bathrooms: " + (criteria.bathrooms != null ? criteria.bathrooms : "not specified"));
        
        // Validate we have at least some criteria
        if (!criteria.hasValidCriteria()) {
            Log.w(TAG, "⚠️ No valid search criteria extracted!");
            ChatMessage errorMessage = ChatMessage.createAiMessage(
                "I couldn't extract specific search criteria from your message. Please try being more specific, like:\n" +
                "• \"2 bedroom apartment in downtown under $2000\"\n" +
                "• \"House in Chicago for $1500\"\n" +
                "• \"Studio apartment under $1000\""
            );
            messages.add(errorMessage);
            chatAdapter.notifyItemInserted(messages.size() - 1);
            scrollToBottom();
            return;
        }
        
        addSystemMessage("🔍 Searching for properties that match your criteria...", ChatMessage.MessageType.SYSTEM_MESSAGE);
        
        SupabaseService supabaseService = SupabaseService.getInstance();
        
        // Use the enhanced search method that includes bathrooms and all criteria
        supabaseService.searchWithCriteria(criteria, new SupabaseService.ListingsCallback() {
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
        });
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
            
            // Store matching listings for potential negotiations
            matchingListings.clear();
            matchingListings.addAll(listings);
            
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
            
            ChatMessage resultsMessage = ChatMessage.createPropertySearchMessage(resultMessage);
            messages.add(resultsMessage);
            chatAdapter.notifyItemInserted(messages.size() - 1);
            
            // Ask explicit confirmation question (like web version)
            ChatMessage confirmationMessage = ChatMessage.createAiMessage(
                "💡 Would you like me to help you negotiate with any of these landlords? I can send professional messages and negotiation strategies on your behalf!"
            );
            messages.add(confirmationMessage);
            chatAdapter.notifyItemInserted(messages.size() - 1);
            
            // Set conversation context to await user response
            pendingUserResponse = "negotiate_offer";
            negotiationState = NegotiationState.AWAITING_CONFIRMATION;
            
            Log.d(TAG, "✅ Set negotiation state to AWAITING_CONFIRMATION");
        }
        
        scrollToBottom();
    }
    
    // Start negotiations for all matching listings (matching web ai-chat.js)
    private void startNegotiationsForAllListings() {
        Log.d(TAG, "📧 Starting negotiations for all matching listings");
        
        if (matchingListings.isEmpty()) {
            ChatMessage noListingsMessage = ChatMessage.createAiMessage(
                "No listings available for negotiation. Please search for properties first."
            );
            messages.add(noListingsMessage);
            chatAdapter.notifyItemInserted(messages.size() - 1);
            scrollToBottom();
            return;
        }
        
        // Show AI response about helping with negotiations
        ChatMessage helpMessage = ChatMessage.createAiMessage(
            "🤖 Great! I'll help you contact the landlords using smart negotiation strategies. " +
            "Here are the properties you can contact:"
        );
        messages.add(helpMessage);
        chatAdapter.notifyItemInserted(messages.size() - 1);
        scrollToBottom();
        
        // Now show property cards with contact buttons (like web version)
        showPropertyContactOptions();
    }
    
    // Show property contact options (updated to match web flow)
    private void showPropertyContactOptions() {
        Log.d(TAG, "📋 Showing contact options for " + matchingListings.size() + " properties");
        
        if (matchingListings.isEmpty()) {
            addSystemMessage("❌ No properties available for contact.", ChatMessage.MessageType.ERROR);
            return;
        }
        
        // Show AI message with instructions
        ChatMessage instructionMessage = ChatMessage.createAiMessage(
            "🤖 Great! Here are the properties you can contact. I'll help you craft professional messages for each landlord.\n\n" +
            "📝 **Negotiation Tips:**\n" +
            "• Highlight your reliability as a tenant\n" +
            "• Mention stable income and references\n" +
            "• Show flexibility with lease terms\n" +
            "• Be respectful and professional\n\n" +
            "Tap **Contact Landlord** below to start a real conversation:"
        );
        messages.add(instructionMessage);
        chatAdapter.notifyItemInserted(messages.size() - 1);
        scrollToBottom();
        
        // Show property cards with contact buttons
        showPropertyListingCards();
    }
    
    // Show property listing cards with contact buttons
    private void showPropertyListingCards() {
        // Display up to 3 properties with contact buttons
        int displayCount = Math.min(3, matchingListings.size());
        
        for (int i = 0; i < displayCount; i++) {
            Listing listing = matchingListings.get(i);
            
            // Create property card message with contact button
            String propertyCard = String.format(
                "🏠 **%s**\n" +
                "📍 %s\n" +
                "💰 $%,.0f/month\n" +
                "🛏️ %d bed, %d bath\n" +
                "🏷️ %s\n\n" +
                "📧 Landlord: %s",
                listing.getTitle(),
                listing.getLocation(),
                listing.getPrice(),
                listing.getBedrooms(),
                listing.getBathrooms(),
                listing.getHouseType(),
                listing.getUserEmail()
            );
            
            // Create special property card message with contact action
            ChatMessage propertyMessage = ChatMessage.createPropertyCardMessage(propertyCard, listing);
            messages.add(propertyMessage);
            chatAdapter.notifyItemInserted(messages.size() - 1);
            scrollToBottom();
        }
        
        if (matchingListings.size() > 3) {
            ChatMessage moreMessage = ChatMessage.createAiMessage(
                String.format("...and %d more properties available. Would you like to see more options?", 
                matchingListings.size() - 3)
            );
            messages.add(moreMessage);
            chatAdapter.notifyItemInserted(messages.size() - 1);
            scrollToBottom();
        }
    }
    
    // Handle contact landlord action
    public void contactLandlord(Listing listing) {
        Log.d(TAG, "📱 Contacting landlord for property: " + listing.getTitle());
        
        // Generate professional negotiation message template
        String messageTemplate = generateNegotiationTemplate(listing);
        
        // Show AI message about what's happening
        ChatMessage aiMessage = ChatMessage.createAiMessage(
            "🤖 Opening chat with the landlord for **" + listing.getTitle() + "**...\n\n" +
            "💡 I've prepared a professional message template for you. You can use it as-is or customize it!"
        );
        messages.add(aiMessage);
        chatAdapter.notifyItemInserted(messages.size() - 1);
        scrollToBottom();
        
        // Launch real chat activity with the landlord
        Intent chatIntent = new Intent(getActivity(), IndividualChatActivity.class);
        chatIntent.putExtra("LANDLORD_EMAIL", listing.getUserEmail());
        chatIntent.putExtra("LANDLORD_NAME", "Landlord of " + listing.getTitle());
        chatIntent.putExtra("PROPERTY_TITLE", listing.getTitle());
        chatIntent.putExtra("CONVERSATION_TYPE", "LANDLORD_CONTACT");
        chatIntent.putExtra("AI_MESSAGE_TEMPLATE", messageTemplate);
        
        startActivity(chatIntent);
    }
    
    // Generate professional negotiation message template
    private String generateNegotiationTemplate(Listing listing) {
        String userEmail = AuthManager.getInstance(getContext()).getUserEmail();
        String userName = userEmail != null ? userEmail.split("@")[0] : "Prospective Tenant";
        
        return String.format(
            "Hello,\n\n" +
            "I hope this message finds you well. I am writing to express my strong interest in your property: %s, listed at $%,.0f/month.\n\n" +
            "As a reliable tenant with stable income, I would love to discuss the rental terms and schedule a viewing. " +
            "I have excellent references and can provide all necessary documentation quickly.\n\n" +
            "Would you be available to discuss this opportunity? I'm flexible with move-in dates and lease terms.\n\n" +
            "Thank you for your time and consideration.\n\n" +
            "Best regards,\n%s",
            listing.getTitle(),
            listing.getPrice(),
            userName
        );
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
            // Use smooth scroller for better animation
            LinearSmoothScroller smoothScroller = new LinearSmoothScroller(getContext()) {
                @Override
                protected int getVerticalSnapPreference() {
                    return LinearSmoothScroller.SNAP_TO_END;
                }
                
                @Override
                protected float calculateSpeedPerPixel(android.util.DisplayMetrics displayMetrics) {
                    return 100f / displayMetrics.densityDpi; // Faster scrolling
                }
            };
            
            smoothScroller.setTargetPosition(messages.size() - 1);
            layoutManager.startSmoothScroll(smoothScroller);
        }
    }
    
    // Load conversation history from SharedPreferences (matching web localStorage)
    private void loadConversationHistory() {
        try {
            AuthManager authManager = AuthManager.getInstance(requireContext());
            String userEmail = authManager.isUserAuthenticated() ? authManager.getUserEmail() : "anonymous";
            String storageKey = "ai_negotiator_chat_" + userEmail;
            
            android.content.SharedPreferences prefs = requireContext().getSharedPreferences("ai_chat", android.content.Context.MODE_PRIVATE);
            String savedHistory = prefs.getString(storageKey, null);
            
            if (savedHistory != null && !savedHistory.isEmpty()) {
                // Parse saved history and restore messages
                String[] messages = savedHistory.split("\\|\\|\\|");
                for (String msg : messages) {
                    if (msg.contains(":::")) {
                        String[] parts = msg.split(":::");
                        if (parts.length == 2) {
                            String role = parts[0];
                            String content = parts[1];
                            conversationHistory.add(content);
                            
                            // Display the message
                            if ("user".equals(role)) {
                                ChatMessage userMessage = ChatMessage.createUserMessage(content);
                                this.messages.add(userMessage);
                            } else {
                                ChatMessage aiMessage = ChatMessage.createAiMessage(content);
                                this.messages.add(aiMessage);
                            }
                        }
                    }
                }
                
                if (!this.messages.isEmpty()) {
                    chatAdapter.notifyDataSetChanged();
                    scrollToBottom();
                    Log.d(TAG, "📂 Loaded " + this.messages.size() + " messages from history");
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error loading conversation history: " + e.getMessage());
            conversationHistory.clear();
        }
    }
    
    // Save conversation history to SharedPreferences (matching web localStorage)
    private void saveConversationHistory() {
        try {
            AuthManager authManager = AuthManager.getInstance(requireContext());
            String userEmail = authManager.isUserAuthenticated() ? authManager.getUserEmail() : "anonymous";
            String storageKey = "ai_negotiator_chat_" + userEmail;
            
            // Build history string
            StringBuilder historyBuilder = new StringBuilder();
            for (int i = 0; i < messages.size(); i++) {
                ChatMessage msg = messages.get(i);
                if (msg.getSender().equals("user")) {
                    historyBuilder.append("user:::").append(msg.getContent());
                } else if (msg.getSender().equals("ai")) {
                    historyBuilder.append("ai:::").append(msg.getContent());
                }
                
                if (i < messages.size() - 1) {
                    historyBuilder.append("|||");
                }
            }
            
            android.content.SharedPreferences prefs = requireContext().getSharedPreferences("ai_chat", android.content.Context.MODE_PRIVATE);
            prefs.edit().putString(storageKey, historyBuilder.toString()).apply();
            
        } catch (Exception e) {
            Log.e(TAG, "Error saving conversation history: " + e.getMessage());
        }
    }
    
    // Clear conversation history (matching web version)
    private void clearConversationHistory() {
        try {
            AuthManager authManager = AuthManager.getInstance(requireContext());
            String userEmail = authManager.isUserAuthenticated() ? authManager.getUserEmail() : "anonymous";
            String storageKey = "ai_negotiator_chat_" + userEmail;
            
            android.content.SharedPreferences prefs = requireContext().getSharedPreferences("ai_chat", android.content.Context.MODE_PRIVATE);
            prefs.edit().remove(storageKey).apply();
            
            conversationHistory.clear();
            messages.clear();
            chatAdapter.notifyDataSetChanged();
            
            // Show welcome message after clearing
            loadWelcomeMessage();
            
        } catch (Exception e) {
            Log.e(TAG, "Error clearing conversation history: " + e.getMessage());
        }
    }
    
    @Override
    public void onDestroyView() {
        super.onDestroyView();
        
        // Save conversation history before destroying view
        saveConversationHistory();
        
        // Cancel any pending network requests
        NetworkUtils.cancelAllRequests();
        
        // Clean up animations
        if (sendButtonPressAnimator != null) {
            sendButtonPressAnimator.cancel();
            sendButtonPressAnimator = null;
        }
        if (sendButtonReleaseAnimator != null) {
            sendButtonReleaseAnimator.cancel();
            sendButtonReleaseAnimator = null;
        }
        
        // Remove any pending callbacks
        if (mainHandler != null) {
            mainHandler.removeCallbacksAndMessages(null);
        }
        
        binding = null;
    }
}