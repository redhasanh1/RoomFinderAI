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
    
    // Conversation context management (like web version)
    private String pendingUserResponse = null;
    private NegotiationState negotiationState = NegotiationState.IDLE;
    private List<Listing> matchingListings = new ArrayList<>();
    
    public enum NegotiationState {
        IDLE,
        AWAITING_CONFIRMATION,
        NEGOTIATING
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
        loadWelcomeMessage();
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
    
    // Check if user response matches conversation context (like web version)
    private boolean checkForNegotiationResponse(String message) {
        Log.d(TAG, "🔍 Checking for negotiation response. State: " + negotiationState + ", Pending: " + pendingUserResponse);
        
        String cleanMessage = message.toLowerCase().trim();
        
        // Check if we're awaiting confirmation for negotiations
        if (negotiationState == NegotiationState.AWAITING_CONFIRMATION && 
            "negotiate_offer".equals(pendingUserResponse)) {
            
            // Check for affirmative responses
            boolean isAffirmative = cleanMessage.contains("yes") || 
                                  cleanMessage.contains("sure") || 
                                  cleanMessage.contains("ok") || 
                                  cleanMessage.contains("okay") || 
                                  cleanMessage.contains("go ahead") || 
                                  cleanMessage.contains("help me") || 
                                  cleanMessage.contains("negotiate") || 
                                  cleanMessage.equals("y");
            
            if (isAffirmative && !matchingListings.isEmpty()) {
                Log.d(TAG, "✅ Affirmative response detected, showing contact options");
                
                // Clear pending response
                pendingUserResponse = null;
                negotiationState = NegotiationState.IDLE;
                
                // Show property cards with contact buttons instead of fake negotiations
                showPropertyContactOptions();
                return true;
            }
            
            // Check for negative responses
            boolean isNegative = cleanMessage.contains("no") || 
                               cleanMessage.contains("not") || 
                               cleanMessage.contains("don't") || 
                               cleanMessage.contains("nope") || 
                               cleanMessage.equals("n");
            
            if (isNegative) {
                Log.d(TAG, "❌ Negative response detected, canceling negotiations");
                
                // Clear pending response
                pendingUserResponse = null;
                negotiationState = NegotiationState.IDLE;
                
                ChatMessage cancelMessage = ChatMessage.createAiMessage(
                    "👍 No problem! Feel free to ask if you need help with anything else, like finding more properties or getting rental advice."
                );
                messages.add(cancelMessage);
                chatAdapter.notifyItemInserted(messages.size() - 1);
                scrollToBottom();
                return true;
            }
        }
        
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
    
    // Start negotiations for all matching listings (like web version)
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
    
    @Override
    public void onDestroyView() {
        super.onDestroyView();
        
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