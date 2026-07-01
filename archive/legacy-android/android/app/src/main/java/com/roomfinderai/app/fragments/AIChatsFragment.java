package com.roomfinderai.app.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.TextView;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.roomfinderai.app.R;
import java.util.ArrayList;
import java.util.List;

public class AIChatsFragment extends Fragment {
    
    private RecyclerView chatRecyclerView;
    private EditText messageInput;
    private ImageButton sendButton;
    private TextView aiTypingIndicator;
    private ChatAdapter chatAdapter;
    private List<ChatMessage> messages;
    
    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_ai_chats, container, false);
        
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
            messages.add(new ChatMessage(message, true));
            chatAdapter.notifyItemInserted(messages.size() - 1);
            chatRecyclerView.scrollToPosition(messages.size() - 1);
            
            messageInput.setText("");
            
            // Show typing indicator
            aiTypingIndicator.setVisibility(View.VISIBLE);
            
            // Simulate AI response (replace with actual API call)
            simulateAIResponse(message);
        }
    }
    
    private void simulateAIResponse(String userMessage) {
        // Simulate network delay
        new android.os.Handler().postDelayed(() -> {
            aiTypingIndicator.setVisibility(View.GONE);
            
            String response = generateAIResponse(userMessage);
            messages.add(new ChatMessage(response, false));
            chatAdapter.notifyItemInserted(messages.size() - 1);
            chatRecyclerView.scrollToPosition(messages.size() - 1);
        }, 1500);
    }
    
    private String generateAIResponse(String userMessage) {
        // Basic response logic - replace with actual AI integration
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
    
    // Chat message model
    public static class ChatMessage {
        public String message;
        public boolean isUser;
        
        public ChatMessage(String message, boolean isUser) {
            this.message = message;
            this.isUser = isUser;
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
                messageText.setText(message.message);
                
                // Align message based on sender
                ViewGroup.MarginLayoutParams params = (ViewGroup.MarginLayoutParams) messageContainer.getLayoutParams();
                if (message.isUser) {
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