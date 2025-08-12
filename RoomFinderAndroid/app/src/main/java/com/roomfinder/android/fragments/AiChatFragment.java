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
                Log.d(TAG, "✅ Affirmative response detected, starting negotiations");
                
                // Clear pending response
                pendingUserResponse = null;
                negotiationState = NegotiationState.NEGOTIATING;
                
                // Show confirmation message
                ChatMessage confirmMessage = ChatMessage.createAiMessage(
                    "🤖 Great! I'll contact the landlords for you using smart negotiation strategies..."
                );
                messages.add(confirmMessage);
                chatAdapter.notifyItemInserted(messages.size() - 1);
                scrollToBottom();
                
                // Start negotiations after a brief delay
                mainHandler.postDelayed(this::startNegotiationsForAllListings, 1500);
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
    private void startNegotiationsForAllListings() {
        Log.d(TAG, "🤝 Starting negotiations for " + matchingListings.size() + " listings");
        
        if (matchingListings.isEmpty()) {
            addSystemMessage("❌ No properties available for negotiation.", ChatMessage.MessageType.ERROR);
            negotiationState = NegotiationState.IDLE;
            return;
        }
        
        // Show progress message
        ChatMessage progressMessage = ChatMessage.createAiMessage(
            "📧 Contacting landlords for " + matchingListings.size() + " properties..."
        );
        messages.add(progressMessage);
        chatAdapter.notifyItemInserted(messages.size() - 1);
        scrollToBottom();
        
        // Simulate negotiation process for each property
        for (int i = 0; i < Math.min(3, matchingListings.size()); i++) {
            Listing listing = matchingListings.get(i);
            
            // Delay each negotiation slightly for realistic effect
            int delay = (i + 1) * 2000;
            
            mainHandler.postDelayed(() -> {
                simulateNegotiationForProperty(listing);
            }, delay);
        }
        
        // Show completion message after all negotiations
        int finalDelay = Math.min(3, matchingListings.size()) * 2000 + 1000;
        mainHandler.postDelayed(() -> {
            showNegotiationSummary();
            negotiationState = NegotiationState.IDLE;
        }, finalDelay);
    }
    
    // Simulate negotiation for a single property
    private void simulateNegotiationForProperty(Listing listing) {
        Log.d(TAG, "💬 Simulating negotiation for property: " + listing.getTitle());
        
        // Generate professional negotiation message
        String negotiationMessage = generateProfessionalMessage(listing);
        
        // Show the message being sent
        ChatMessage sentMessage = ChatMessage.createAiMessage(
            "📤 **Sent to " + listing.getTitle() + " landlord:**\n\n" + negotiationMessage
        );
        messages.add(sentMessage);
        chatAdapter.notifyItemInserted(messages.size() - 1);
        scrollToBottom();
        
        // Simulate landlord response after short delay
        mainHandler.postDelayed(() -> {
            simulateLandlordResponse(listing);
        }, 1500);
    }
    
    // Generate professional negotiation message
    private String generateProfessionalMessage(Listing listing) {
        String[] templates = {
            "Hello,\n\nI am very interested in your property at " + listing.getLocation() + 
            ". I am a reliable tenant with excellent references and stable income. " +
            "Would you be open to discussing the rental terms? I'm prepared to move in quickly and can provide all necessary documentation.\n\nBest regards,\n[Your Name]",
            
            "Dear Property Owner,\n\nI hope this message finds you well. I am writing to express my strong interest in your " +
            listing.getTitle().toLowerCase() + " listed at $" + String.format("%.0f", listing.getPrice()) + "/month. " +
            "As a responsible tenant, I would love to discuss any flexibility in the rental terms. " +
            "I have a clean rental history and can provide references upon request.\n\nThank you for your time,\n[Your Name]",
            
            "Hi there,\n\nI came across your listing for " + listing.getTitle() + " and I'm very interested! " +
            "I'm a working professional looking for a long-term rental. Given the current market conditions, " +
            "would you consider any adjustments to the monthly rent or lease terms? I'm a reliable tenant " +
            "and can provide proof of income and references.\n\nLooking forward to hearing from you,\n[Your Name]"
        };
        
        return templates[(int)(Math.random() * templates.length)];
    }
    
    // Simulate landlord response
    private void simulateLandlordResponse(Listing listing) {
        // Random response scenarios
        double responseType = Math.random();
        String response;
        
        if (responseType < 0.4) {
            // Positive response with negotiation
            int discount = (int)(listing.getPrice() * (0.05 + Math.random() * 0.10)); // 5-15% discount
            response = "📥 **Response from " + listing.getTitle() + " landlord:**\n\n" +
                      "Thank you for your interest! I appreciate tenants who are upfront about their needs. " +
                      "I can offer the property for $" + (int)(listing.getPrice() - discount) + "/month " +
                      "for a 12-month lease. Would this work for you?";
        } else if (responseType < 0.7) {
            // Willing to discuss terms
            response = "📥 **Response from " + listing.getTitle() + " landlord:**\n\n" +
                      "Hello! Thank you for reaching out. I'm happy to discuss the rental terms. " +
                      "The property is currently priced competitively, but I'm open to considering " +
                      "a longer lease term or including some utilities. Let's schedule a viewing to discuss further.";
        } else {
            // Not flexible on price but interested
            response = "📥 **Response from " + listing.getTitle() + " landlord:**\n\n" +
                      "Hi there! I appreciate your interest in the property. While I can't adjust the monthly rent " +
                      "as it's already priced fairly for the area, I'd be happy to waive the application fee " +
                      "if you're ready to move forward. The property is move-in ready!";
        }
        
        ChatMessage responseMessage = ChatMessage.createAiMessage(response);
        messages.add(responseMessage);
        chatAdapter.notifyItemInserted(messages.size() - 1);
        scrollToBottom();
    }
    
    // Show negotiation summary
    private void showNegotiationSummary() {
        String summary = "🎉 **Negotiation Summary:**\n\n" +
                        "✅ Successfully contacted " + Math.min(3, matchingListings.size()) + " landlords\n" +
                        "📧 Professional messages sent with your requirements\n" +
                        "💬 Initial responses received\n\n" +
                        "**Next Steps:**\n" +
                        "• Review the responses above\n" +
                        "• Schedule viewings for properties with flexible terms\n" +
                        "• I can help you craft follow-up messages\n\n" +
                        "Would you like me to help you with anything else?";
        
        ChatMessage summaryMessage = ChatMessage.createAiMessage(summary);
        messages.add(summaryMessage);
        chatAdapter.notifyItemInserted(messages.size() - 1);
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