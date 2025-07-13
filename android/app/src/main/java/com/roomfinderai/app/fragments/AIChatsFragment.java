package com.roomfinderai.app.fragments;

import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.TextView;
import android.widget.Toast;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.roomfinderai.app.R;
import com.roomfinderai.app.models.ChatMessage;
import com.roomfinderai.app.services.Repository;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public class AIChatsFragment extends Fragment {
    
    private static final String TAG = "AIChatsFragment";
    private RecyclerView chatRecyclerView;
    private EditText messageInput;
    private ImageButton sendButton;
    private TextView aiTypingIndicator;
    private ChatAdapter chatAdapter;
    private List<ChatMessage> messages;
    private Repository repository;
    private String sessionId;
    private String userId = "user123"; // TODO: Get from user session
    
    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_ai_chats, container, false);
        
        repository = new Repository();
        sessionId = UUID.randomUUID().toString();
        
        initializeViews(view);
        setupChatInterface();
        
        return view;
    }
    
    private void initializeViews(View view) {
        chatRecyclerView = view.findViewById(R.id.chatRecyclerView);
        messageInput = view.findViewById(R.id.messageInput);
        sendButton = view.findViewById(R.id.sendButton);
        aiTypingIndicator = view.findViewById(R.id.aiTypingIndicator);
        
        messages = new ArrayList<>();
        messages.add(new ChatMessage("Hi! I'm your AI negotiator. I can help you find the perfect room or negotiate with landlords. How can I assist you today?", false));
    }
    
    private void setupChatInterface() {
        chatAdapter = new ChatAdapter(messages);
        chatRecyclerView.setLayoutManager(new LinearLayoutManager(getContext()));
        chatRecyclerView.setAdapter(chatAdapter);
        
        sendButton.setOnClickListener(v -> sendMessage());
        
        messageInput.setOnEditorActionListener((v, actionId, event) -> {
            sendMessage();
            return true;
        });
    }
    
    private void sendMessage() {
        String message = messageInput.getText().toString().trim();
        if (!message.isEmpty()) {
            // Add user message to chat
            ChatMessage userMessage = new ChatMessage(message, true);
            messages.add(userMessage);
            chatAdapter.notifyItemInserted(messages.size() - 1);
            chatRecyclerView.scrollToPosition(messages.size() - 1);
            
            messageInput.setText("");
            
            // Show typing indicator
            aiTypingIndicator.setVisibility(View.VISIBLE);
            
            // Send message to AI API
            sendMessageToAI(message);
        }
    }
    
    private void sendMessageToAI(String message) {
        repository.sendMessage(message, userId, sessionId, new Repository.ApiCallback<ChatMessage>() {
            @Override
            public void onSuccess(ChatMessage result) {
                if (getActivity() != null) {
                    getActivity().runOnUiThread(() -> {
                        aiTypingIndicator.setVisibility(View.GONE);
                        
                        if (result != null && result.getMessage() != null) {
                            // Add AI response to chat
                            ChatMessage aiMessage = new ChatMessage(result.getMessage(), false);
                            messages.add(aiMessage);
                            chatAdapter.notifyItemInserted(messages.size() - 1);
                            chatRecyclerView.scrollToPosition(messages.size() - 1);
                            
                            Log.d(TAG, "Received AI response: " + result.getMessage());
                        } else {
                            // Fallback to local response if API response is empty
                            String fallbackResponse = generateFallbackResponse(message);
                            ChatMessage aiMessage = new ChatMessage(fallbackResponse, false);
                            messages.add(aiMessage);
                            chatAdapter.notifyItemInserted(messages.size() - 1);
                            chatRecyclerView.scrollToPosition(messages.size() - 1);
                        }
                    });
                }
            }

            @Override
            public void onError(String error) {
                if (getActivity() != null) {
                    getActivity().runOnUiThread(() -> {
                        aiTypingIndicator.setVisibility(View.GONE);
                        
                        Log.e(TAG, "AI API error: " + error);
                        
                        // Show error message to user
                        Toast.makeText(getContext(), "AI service temporarily unavailable", Toast.LENGTH_SHORT).show();
                        
                        // Provide fallback response
                        String fallbackResponse = generateFallbackResponse(message);
                        ChatMessage aiMessage = new ChatMessage(fallbackResponse, false);
                        messages.add(aiMessage);
                        chatAdapter.notifyItemInserted(messages.size() - 1);
                        chatRecyclerView.scrollToPosition(messages.size() - 1);
                    });
                }
            }
        });
    }
    
    private String generateFallbackResponse(String userMessage) {
        // Fallback response logic when API is unavailable
        if (userMessage.toLowerCase().contains("price") || userMessage.toLowerCase().contains("negotiate")) {
            return "I can help you negotiate the price. What's your budget range and what features are most important to you?";
        } else if (userMessage.toLowerCase().contains("location")) {
            return "Location is crucial! Are you looking for something near public transit, schools, or specific neighborhoods?";
        } else if (userMessage.toLowerCase().contains("room") || userMessage.toLowerCase().contains("apartment")) {
            return "I'll help you find the perfect place. What size are you looking for and when do you need to move in?";
        } else {
            return "I understand. Let me help you with that. Could you provide more details about what you're looking for?";
        }
    }
    
    
    // Chat adapter
    private class ChatAdapter extends RecyclerView.Adapter<ChatAdapter.ChatViewHolder> {
        private List<ChatMessage> messages;
        
        public ChatAdapter(List<ChatMessage> messages) {
            this.messages = messages;
        }
        
        @Override
        public ChatViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
            View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_chat_message, parent, false);
            return new ChatViewHolder(view);
        }
        
        @Override
        public void onBindViewHolder(ChatViewHolder holder, int position) {
            ChatMessage message = messages.get(position);
            holder.bind(message);
        }
        
        @Override
        public int getItemCount() {
            return messages.size();
        }
        
        class ChatViewHolder extends RecyclerView.ViewHolder {
            TextView messageText;
            View messageContainer;
            
            ChatViewHolder(View itemView) {
                super(itemView);
                messageText = itemView.findViewById(R.id.messageText);
                messageContainer = itemView.findViewById(R.id.messageContainer);
            }
            
            void bind(ChatMessage message) {
                messageText.setText(message.getMessage());
                
                // Align message based on sender
                ViewGroup.MarginLayoutParams params = (ViewGroup.MarginLayoutParams) messageContainer.getLayoutParams();
                if (message.isUser()) {
                    params.leftMargin = 100;
                    params.rightMargin = 16;
                    messageContainer.setBackgroundResource(R.drawable.user_message_background);
                } else {
                    params.leftMargin = 16;
                    params.rightMargin = 100;
                    messageContainer.setBackgroundResource(R.drawable.ai_message_background);
                }
                messageContainer.setLayoutParams(params);
            }
        }
    }
}