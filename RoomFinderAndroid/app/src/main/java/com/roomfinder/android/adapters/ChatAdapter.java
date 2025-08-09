package com.roomfinder.android.adapters;

import android.graphics.Color;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import com.roomfinder.android.R;
import com.roomfinder.android.models.ChatMessage;
import java.util.List;

public class ChatAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    
    private static final int VIEW_TYPE_USER = 1;
    private static final int VIEW_TYPE_AI = 2;
    private static final int VIEW_TYPE_SYSTEM = 3;
    private static final int VIEW_TYPE_TYPING = 4;
    
    private List<ChatMessage> messages;
    
    public ChatAdapter(List<ChatMessage> messages) {
        this.messages = messages;
    }
    
    @Override
    public int getItemViewType(int position) {
        ChatMessage message = messages.get(position);
        
        // Determine view type based on sender and typing status
        if (message.isTyping()) {
            return VIEW_TYPE_TYPING;
        } else if (message.isFromUser()) {
            return VIEW_TYPE_USER;
        } else if (message.isFromAi()) {
            return VIEW_TYPE_AI;
        } else {
            return VIEW_TYPE_SYSTEM;
        }
    }
    
    @NonNull
    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        LayoutInflater inflater = LayoutInflater.from(parent.getContext());
        
        switch (viewType) {
            case VIEW_TYPE_USER:
                View userView = inflater.inflate(R.layout.item_chat_user, parent, false);
                return new UserMessageViewHolder(userView);
            case VIEW_TYPE_AI:
                View aiView = inflater.inflate(R.layout.item_chat_ai, parent, false);
                return new AiMessageViewHolder(aiView);
            case VIEW_TYPE_TYPING:
                View typingView = inflater.inflate(R.layout.item_chat_typing, parent, false);
                return new TypingViewHolder(typingView);
            case VIEW_TYPE_SYSTEM:
            default:
                View systemView = inflater.inflate(R.layout.item_chat_system, parent, false);
                return new SystemMessageViewHolder(systemView);
        }
    }
    
    @Override
    public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
        ChatMessage message = messages.get(position);
        
        if (holder instanceof UserMessageViewHolder) {
            ((UserMessageViewHolder) holder).bind(message);
        } else if (holder instanceof AiMessageViewHolder) {
            ((AiMessageViewHolder) holder).bind(message);
        } else if (holder instanceof SystemMessageViewHolder) {
            ((SystemMessageViewHolder) holder).bind(message);
        } else if (holder instanceof TypingViewHolder) {
            ((TypingViewHolder) holder).bind(message);
        }
    }
    
    @Override
    public int getItemCount() {
        return messages.size();
    }
    
    public void addMessage(ChatMessage message) {
        messages.add(message);
        notifyItemInserted(messages.size() - 1);
    }
    
    public void removeTypingIndicator() {
        for (int i = messages.size() - 1; i >= 0; i--) {
            if (messages.get(i).isTyping()) {
                messages.remove(i);
                notifyItemRemoved(i);
                break;
            }
        }
    }
    
    public void updateLastMessage(String newText) {
        if (!messages.isEmpty()) {
            ChatMessage lastMessage = messages.get(messages.size() - 1);
            lastMessage.setContent(newText);
            notifyItemChanged(messages.size() - 1);
        }
    }
    
    // User Message ViewHolder
    static class UserMessageViewHolder extends RecyclerView.ViewHolder {
        TextView messageText;
        TextView timestamp;
        
        UserMessageViewHolder(View itemView) {
            super(itemView);
            messageText = itemView.findViewById(R.id.messageText);
            timestamp = itemView.findViewById(R.id.timestamp);
        }
        
        void bind(ChatMessage message) {
            messageText.setText(message.getContent());
            timestamp.setText(message.getFormattedTime());
        }
    }
    
    // AI Message ViewHolder
    static class AiMessageViewHolder extends RecyclerView.ViewHolder {
        TextView messageText;
        TextView timestamp;
        
        AiMessageViewHolder(View itemView) {
            super(itemView);
            messageText = itemView.findViewById(R.id.messageText);
            timestamp = itemView.findViewById(R.id.timestamp);
        }
        
        void bind(ChatMessage message) {
            // Format AI messages with special formatting
            String text = message.getContent();
            SpannableString spannableString = new SpannableString(text);
            
            // Highlight property names and prices
            if (text.contains("$")) {
                int start = text.indexOf("$");
                while (start != -1) {
                    int end = text.indexOf(" ", start);
                    if (end == -1) end = text.indexOf("\n", start);
                    if (end == -1) end = text.length();
                    
                    spannableString.setSpan(
                        new ForegroundColorSpan(Color.parseColor("#4CAF50")), 
                        start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                    );
                    
                    start = text.indexOf("$", end);
                }
            }
            
            messageText.setText(spannableString);
            timestamp.setText(message.getFormattedTime());
        }
    }
    
    // System Message ViewHolder
    static class SystemMessageViewHolder extends RecyclerView.ViewHolder {
        TextView messageText;
        
        SystemMessageViewHolder(View itemView) {
            super(itemView);
            messageText = itemView.findViewById(R.id.messageText);
        }
        
        void bind(ChatMessage message) {
            messageText.setText(message.getContent());
            
            // Set color based on message type
            if (message.isErrorMessage()) {
                messageText.setTextColor(Color.parseColor("#F44336"));
            } else {
                messageText.setTextColor(Color.parseColor("#666666"));
            }
        }
    }
    
    // Typing Indicator ViewHolder
    static class TypingViewHolder extends RecyclerView.ViewHolder {
        
        TypingViewHolder(View itemView) {
            super(itemView);
        }
        
        void bind(ChatMessage message) {
            // Typing indicator animation is handled by the layout
        }
    }
}