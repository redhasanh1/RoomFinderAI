package com.roomfinder.android.fragments;

import android.animation.AnimatorInflater;
import android.animation.AnimatorSet;
import android.app.AlertDialog;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.HapticFeedbackConstants;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
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
import com.roomfinder.android.services.AiNegotiationService;
import com.roomfinder.android.network.SupabaseService;
import com.roomfinder.android.utils.NetworkUtils;
import com.roomfinder.android.activities.IndividualChatActivity;
import com.roomfinder.android.services.ChatStorageService;
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
    
    // Conversation context management (simplified)
    private String pendingUserResponse = null;
    private NegotiationState negotiationState = NegotiationState.IDLE;
    private List<Listing> matchingListings = new ArrayList<>();
    private Map<String, Boolean> activeConversations = new HashMap<>();
    private List<String> conversationHistory = new ArrayList<>();
    
    // AI Negotiation Service for background messaging
    private AiNegotiationService aiNegotiationService;
    
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
        
        // Enable menu for this fragment
        setHasOptionsMenu(true);
        
        initializeServices();
        initializeAnimations();
        setupToolbar();
        setupRecyclerView();
        setupClickListeners();
        setupSendButtonAnimations();
        loadConversationHistory(); // Load previous conversation like web version
        // Welcome message is now handled by AiNegotiationService
        checkNetworkConnection();
    }
    
    private void initializeServices() {
        aiService = new AiNegotiatorService();
        mainHandler = new Handler(Looper.getMainLooper());
        
        // Initialize AI Negotiation Service for background messaging
        aiNegotiationService = AiNegotiationService.getInstance(requireContext());
        
        // Check authentication status for enhanced features
        AuthManager authManager = AuthManager.getInstance(requireContext());
        if (authManager.isUserAuthenticated()) {
            Log.d(TAG, "AI Negotiator services initialized for authenticated user - enhanced features available");
            
            // Initialize negotiation service with user email
            String userEmail = authManager.getCurrentUser().getEmail();
            aiNegotiationService.init(userEmail, new AiNegotiationService.AiChatCallback() {
                @Override
                public void onMessage(String sender, String message) {
                    // Display messages from negotiation service in the chat
                    mainHandler.post(() -> {
                        ChatMessage aiMessage = ChatMessage.createAiMessage(message);
                        addMessageAndUpdate(aiMessage);
                    });
                }
                
                @Override
                public void onSearchResults(List<Listing> listings) {
                    // Already handled by our own search
                }
                
                @Override
                public void onNegotiationStarted(String listingId) {
                    Log.d(TAG, "Negotiation started for listing: " + listingId);
                }
                
                @Override
                public void onNegotiationComplete(String listingId, String result) {
                    Log.d(TAG, "Negotiation complete for listing: " + listingId);
                }
                
                @Override
                public void onError(String error) {
                    mainHandler.post(() -> {
                        ChatMessage errorMessage = ChatMessage.createAiMessage("❌ " + error);
                        addMessageAndUpdate(errorMessage);
                    });
                }
            });
        } else {
            Log.d(TAG, "AI Negotiator services initialized for guest user - basic features available");
            // Guest users can still use AI negotiator but with limited features
        }
    }
    
    private void checkNetworkConnection() {
        if (!NetworkUtils.isNetworkAvailable(requireContext())) {
            addSystemMessage("⚠️ No internet connection. Please check your network and try again.", ChatMessage.MessageType.ERROR);
        }
    }
    
    private void setupToolbar() {
        binding.backButton.setOnClickListener(v -> {
            requireActivity().onBackPressed();
        });
        
        // Note: Menu functionality can be added later if needed
        // For now, we have a clean glassmorphism header without menu
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
        
        // 3-dot menu button click handler
        if (binding.menuButton != null) {
            binding.menuButton.setOnClickListener(v -> {
                // Show popup menu
                androidx.appcompat.widget.PopupMenu popup = new androidx.appcompat.widget.PopupMenu(requireContext(), v);
                popup.getMenuInflater().inflate(R.menu.ai_chat_menu, popup.getMenu());
                
                popup.setOnMenuItemClickListener(item -> {
                    if (item.getItemId() == R.id.action_clear_chat) {
                        showClearChatConfirmation();
                        return true;
                    }
                    return false;
                });
                
                popup.show();
            });
        }
    }
    
    // Welcome message is now handled by AiNegotiationService to avoid duplicates
    
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
        
        // Add user message using optimized method
        ChatMessage userMessage = ChatMessage.createUserMessage(messageText);
        addMessageAndUpdate(userMessage);
        
        // Save conversation history after each message (like web version)
        conversationHistory.add(messageText);
        saveConversationHistory();
        
        // Clear input and disable sending
        binding.messageInput.setText("");
        setProcessingState(true);
        
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
        
        // Check if user is asking about negotiation status
        if (checkForNegotiationStatusQuery(originalMessage)) {
            return; // Query handled
        }
        
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
    
    // Start negotiations for all matching listings (matching web ai-chat.js) - AUTOMATED BACKGROUND NEGOTIATION
    private void startNegotiationsForAllListings() {
        Log.d(TAG, "📧 Starting automated negotiations for all matching listings");
        
        if (matchingListings.isEmpty()) {
            ChatMessage noListingsMessage = ChatMessage.createAiMessage(
                "No listings available for negotiation. Please search for properties first."
            );
            addMessageAndUpdate(noListingsMessage);
            return;
        }
        
        // Set the listings in the negotiation service
        if (aiNegotiationService != null) {
            aiNegotiationService.setMatchingListings(matchingListings);
        }
        
        // Show initial message
        ChatMessage startMessage = ChatMessage.createAiMessage(
            "📧 Contacting landlords for " + matchingListings.size() + " listing(s)...\n" +
            "I'll send professional negotiation messages to each landlord automatically."
        );
        addMessageAndUpdate(startMessage);
        
        // Process each listing in background
        new Thread(() -> {
            try {
                for (int i = 0; i < matchingListings.size(); i++) {
                    Listing listing = matchingListings.get(i);
                    final int index = i + 1;
                    
                    // Update progress
                    mainHandler.post(() -> {
                        ChatMessage progressMessage = ChatMessage.createAiMessage(
                            "📤 Sending negotiation message " + index + " of " + matchingListings.size() + 
                            " for **" + listing.getTitle() + "**..."
                        );
                        addMessageAndUpdate(progressMessage);
                    });
                    
                    // Directly start negotiation for this listing using the service
                    if (aiNegotiationService != null) {
                        // The service will handle creating conversation and sending messages
                        aiNegotiationService.startNegotiationForListing(listing);
                    }
                    
                    // Small delay between messages
                    Thread.sleep(500);
                }
                
                // Show completion message
                mainHandler.post(() -> {
                    ChatMessage completeMessage = ChatMessage.createAiMessage(
                        "✅ All negotiations initiated! The landlords will receive your messages and you can continue the conversation in the chat section."
                    );
                    addMessageAndUpdate(completeMessage);
                });
                
            } catch (Exception e) {
                Log.e(TAG, "Error in automated negotiation", e);
                mainHandler.post(() -> {
                    showSimpleError("Failed to complete all negotiations. Some messages may have been sent.");
                });
            }
        }).start();
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
    
    // Show property listing cards with contact buttons - OPTIMIZED FOR PERFORMANCE
    private void showPropertyListingCards() {
        // Move to background thread for processing
        new Thread(() -> {
            try {
                // Prepare all messages in background
                List<ChatMessage> propertyMessages = new ArrayList<>();
                
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
                    propertyMessages.add(propertyMessage);
                }
                
                // Add more message if needed
                if (matchingListings.size() > 3) {
                    ChatMessage moreMessage = ChatMessage.createAiMessage(
                        String.format("...and %d more properties available. Would you like to see more options?", 
                        matchingListings.size() - 3)
                    );
                    propertyMessages.add(moreMessage);
                }
                
                // Update UI on main thread with batch insert
                mainHandler.post(() -> {
                    addMessagesAndUpdate(propertyMessages);
                });
                
            } catch (Exception e) {
                Log.e(TAG, "Error processing property cards", e);
                mainHandler.post(() -> showSimpleError("Failed to display properties. Please try again."));
            }
        }).start();
    }
    
    // Handle contact landlord action - START SIMPLE AI NEGOTIATION
    public void contactLandlord(Listing listing) {
        if (listing == null || listing.getTitle() == null) {
            showSimpleError("Invalid property data");
            return;
        }
        
        Log.d(TAG, "Starting simple negotiation for: " + listing.getTitle());
        
        // Show starting message
        ChatMessage aiMessage = ChatMessage.createAiMessage(
            "🤖 Opening chat with the landlord for **" + listing.getTitle() + "**..."
        );
        addMessageAndUpdate(aiMessage);
        
        // Launch chat directly - no complex validation
        launchSimpleNegotiationChat(listing);
    }
    
    // Launch simple negotiation chat - with validation to prevent self-chat
    private void launchSimpleNegotiationChat(Listing listing) {
        // Check if user is trying to chat with themselves
        AuthManager authManager = AuthManager.getInstance(requireContext());
        String currentUserEmail = authManager.getCurrentUser() != null ? authManager.getCurrentUser().getEmail() : "";
        
        if (currentUserEmail.equals(listing.getUserEmail())) {
            // This is the user's own listing - show appropriate message
            ChatMessage ownListingMsg = ChatMessage.createAiMessage(
                "💡 This appears to be your own property listing! You can't negotiate with yourself. " +
                "Try searching for properties listed by other landlords to start negotiations."
            );
            addMessageAndUpdate(ownListingMsg);
            return;
        }
        
        String defaultMessage = "Hi! I'm interested in your property '" + listing.getTitle() + 
                               "'. I'd like to discuss the rental terms. When would be a good time to chat?";
        
        Intent chatIntent = new Intent(getActivity(), IndividualChatActivity.class);
        
        // Pass all necessary data for proper chat setup
        chatIntent.putExtra("listing_id", listing.getId());
        chatIntent.putExtra("listing_title", listing.getTitle());
        chatIntent.putExtra("owner_email", listing.getUserEmail());
        
        // AI negotiation specific data
        chatIntent.putExtra("LANDLORD_EMAIL", listing.getUserEmail());
        chatIntent.putExtra("LANDLORD_NAME", "Landlord of " + listing.getTitle());
        chatIntent.putExtra("PROPERTY_TITLE", listing.getTitle());
        chatIntent.putExtra("CONVERSATION_TYPE", "AI_NEGOTIATION");
        chatIntent.putExtra("AI_GENERATED_MESSAGE", defaultMessage);
        chatIntent.putExtra("AI_NEGOTIATION_ID", "ai_neg_" + System.currentTimeMillis()); // Generate unique negotiation ID
        
        startActivity(chatIntent);
        
        // Show success message
        ChatMessage successMsg = ChatMessage.createAiMessage(
            "💬 Chat opened with landlord! The conversation has been started with a professional message."
        );
        addMessageAndUpdate(successMsg);
    }
    
    
    
    
    // Check if user is asking about negotiation status
    private boolean checkForNegotiationStatusQuery(String message) {
        String lowerMessage = message.toLowerCase();
        
        String[] statusKeywords = {"negotiation status", "how are my negotiations", "negotiation progress", 
                                  "active negotiations", "negotiation summary", "my deals"};
        
        for (String keyword : statusKeywords) {
            if (lowerMessage.contains(keyword)) {
                ChatMessage statusMsg = ChatMessage.createAiMessage(
                    "Your negotiations are handled through individual chat conversations. " +
                    "Search for properties and I'll help you contact landlords directly!"
                );
                messages.add(statusMsg);
                chatAdapter.notifyItemInserted(messages.size() - 1);
                scrollToBottom();
                return true;
            }
        }
        
        return false;
    }
    
    // Show simple error message
    private void showSimpleError(String error) {
        ChatMessage errorMsg = ChatMessage.createAiMessage(
            "❌ " + error + ". Please try again or search for other properties."
        );
        messages.add(errorMsg);
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
    
    // Loading indicator helpers for better UX during background processing
    private void showLoadingIndicator(String message) {
        ChatMessage loadingMessage = ChatMessage.createAiMessage("⏳ " + message);
        addMessageAndUpdate(loadingMessage);
    }
    
    private void hideLoadingIndicator() {
        // Remove the last message if it's a loading message
        if (!messages.isEmpty()) {
            ChatMessage lastMessage = messages.get(messages.size() - 1);
            if (lastMessage.getContent() != null && lastMessage.getContent().startsWith("⏳")) {
                messages.remove(messages.size() - 1);
                chatAdapter.notifyItemRemoved(messages.size());
            }
        }
    }
    
    // Batch UI update helper to reduce main thread work
    private void addMessageAndUpdate(ChatMessage message) {
        messages.add(message);
        chatAdapter.notifyItemInserted(messages.size() - 1);
        scrollToBottom();
    }
    
    // Batch UI update for multiple messages
    private void addMessagesAndUpdate(List<ChatMessage> newMessages) {
        int startPosition = messages.size();
        messages.addAll(newMessages);
        chatAdapter.notifyItemRangeInserted(startPosition, newMessages.size());
        scrollToBottom();
    }
    
    
    // Optimized scrolling with debouncing to reduce main thread work
    private Runnable pendingScrollRunnable = null;
    
    private void scrollToBottom() {
        if (messages.size() > 0) {
            // Cancel any pending scroll to debounce multiple calls
            if (pendingScrollRunnable != null) {
                mainHandler.removeCallbacks(pendingScrollRunnable);
            }
            
            // Schedule scroll with slight delay to batch multiple scroll requests
            pendingScrollRunnable = () -> {
                if (layoutManager != null && isAdded()) {
                    // Use smooth scroll to last position
                    layoutManager.smoothScrollToPosition(binding.messagesRecyclerView, null, messages.size() - 1);
                }
                pendingScrollRunnable = null;
            };
            
            mainHandler.postDelayed(pendingScrollRunnable, 50); // 50ms delay for batching
        }
    }
    
    // Immediate scroll for urgent cases
    private void scrollToBottomImmediate() {
        if (messages.size() > 0 && layoutManager != null && isAdded()) {
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
    
    @Override
    public void onCreateOptionsMenu(@NonNull Menu menu, @NonNull MenuInflater inflater) {
        inflater.inflate(R.menu.ai_chat_menu, menu);
        super.onCreateOptionsMenu(menu, inflater);
    }
    
    @Override
    public boolean onOptionsItemSelected(@NonNull MenuItem item) {
        if (item.getItemId() == R.id.action_clear_chat) {
            showClearChatConfirmation();
            return true;
        }
        return super.onOptionsItemSelected(item);
    }
    
    private void showClearChatConfirmation() {
        new AlertDialog.Builder(requireContext())
            .setTitle("Clear Chat History")
            .setMessage("Are you sure you want to clear all AI negotiator chat history? This action cannot be undone.")
            .setPositiveButton("Clear History", (dialog, which) -> {
                clearConversationHistory();
                
                // Also clear from ChatStorageService for completeness
                try {
                    ChatStorageService chatStorage = ChatStorageService.getInstance(requireContext());
                    chatStorage.clearAllData();
                    Toast.makeText(requireContext(), "Chat history cleared successfully", Toast.LENGTH_SHORT).show();
                } catch (Exception e) {
                    Log.e(TAG, "Error clearing storage: " + e.getMessage(), e);
                }
            })
            .setNegativeButton("Cancel", null)
            .show();
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
            
            // Show ChatGPT-style welcome message after clearing (exact match to image)
            ChatMessage welcomeMessage = ChatMessage.createAiMessage(
                "Hello! I'm your AI\n" +
                "Negotiation Assistant. I\n" +
                "can help you:\n\n" +
                "[ICON:home] Find rental properties\n" +
                "       based on your criteria\n\n" +
                "[ICON:handshake] based on your criteria\n\n" +
                "[ICON:document] Write professional\n" +
                "         messages to property\n" +
                "         owners\n\n" +
                "Try saying: \"Find me a 2-bedroom\n" +
                "apartment in [city] under $2000\"\n" +
                "or \"Help me negotiate rent\""
            );
            messages.add(welcomeMessage);
            chatAdapter.notifyItemInserted(messages.size() - 1);
            scrollToBottom();
            
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