package com.roomfinder.android.adapters;

import android.animation.AnimatorInflater;
import android.animation.AnimatorSet;
import android.graphics.Color;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
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
            applySlideInAnimation(holder.itemView, VIEW_TYPE_USER);
        } else if (holder instanceof AiMessageViewHolder) {
            ((AiMessageViewHolder) holder).bind(message);
            applySlideInAnimation(holder.itemView, VIEW_TYPE_AI);
        } else if (holder instanceof SystemMessageViewHolder) {
            ((SystemMessageViewHolder) holder).bind(message);
        } else if (holder instanceof TypingViewHolder) {
            ((TypingViewHolder) holder).bind(message);
            applyTypingAnimation(holder);
        }
    }
    
    private void applySlideInAnimation(View view, int viewType) {
        try {
            AnimatorSet animator;
            
            if (viewType == VIEW_TYPE_USER) {
                animator = (AnimatorSet) AnimatorInflater.loadAnimator(view.getContext(), 
                    R.animator.message_slide_in_right);
            } else {
                animator = (AnimatorSet) AnimatorInflater.loadAnimator(view.getContext(), 
                    R.animator.message_slide_in_left);
            }
            
            animator.setTarget(view);
            animator.start();
        } catch (Exception e) {
            // Fallback animation
            view.setAlpha(0f);
            view.animate().alpha(1f).setDuration(300).start();
        }
    }
    
    private void applyTypingAnimation(RecyclerView.ViewHolder holder) {
        if (holder instanceof TypingViewHolder) {
            TypingViewHolder typingHolder = (TypingViewHolder) holder;
            
            // Animate typing dots with staggered delays
            if (typingHolder.typingDot1 != null) {
                animateTypingDot(typingHolder.typingDot1, 0);
            }
            if (typingHolder.typingDot2 != null) {
                animateTypingDot(typingHolder.typingDot2, 200);
            }
            if (typingHolder.typingDot3 != null) {
                animateTypingDot(typingHolder.typingDot3, 400);
            }
            
            // Pulse avatar
            if (typingHolder.avatarPulse != null) {
                animateAvatarPulse(typingHolder.avatarPulse);
            }
        }
    }
    
    private void animateTypingDot(View dot, int delay) {
        dot.postDelayed(() -> {
            try {
                AnimatorSet animator = (AnimatorSet) AnimatorInflater.loadAnimator(
                    dot.getContext(), R.animator.typing_dots_animation);
                animator.setTarget(dot);
                animator.start();
            } catch (Exception e) {
                // Fallback simple animation
                dot.animate()
                    .scaleX(1.2f).scaleY(1.2f).alpha(1f)
                    .setDuration(300)
                    .withEndAction(() -> 
                        dot.animate().scaleX(1f).scaleY(1f).alpha(0.4f).setDuration(300).start())
                    .start();
            }
        }, delay);
    }
    
    private void animateAvatarPulse(View avatar) {
        avatar.animate()
            .scaleX(1.05f).scaleY(1.05f).alpha(0.8f)
            .setDuration(1000)
            .withEndAction(() -> 
                avatar.animate().scaleX(1f).scaleY(1f).alpha(0.6f).setDuration(1000).start())
            .start();
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
        ImageView deliveryStatus;
        ImageView userAvatar;
        
        UserMessageViewHolder(View itemView) {
            super(itemView);
            messageText = itemView.findViewById(R.id.messageText);
            timestamp = itemView.findViewById(R.id.timestamp);
            deliveryStatus = itemView.findViewById(R.id.deliveryStatus);
            userAvatar = itemView.findViewById(R.id.userAvatar);
        }
        
        void bind(ChatMessage message) {
            messageText.setText(message.getContent());
            timestamp.setText(message.getFormattedTime());
            
            // Show delivery status if available
            if (deliveryStatus != null) {
                if (message.isDelivered()) {
                    deliveryStatus.setVisibility(View.VISIBLE);
                    deliveryStatus.setImageResource(R.drawable.ic_check);
                } else {
                    deliveryStatus.setVisibility(View.GONE);
                }
            }
        }
    }
    
    // AI Message ViewHolder
    static class AiMessageViewHolder extends RecyclerView.ViewHolder {
        TextView messageText;
        TextView timestamp;
        ImageView aiAvatar;
        View messageStatus;
        
        AiMessageViewHolder(View itemView) {
            super(itemView);
            messageText = itemView.findViewById(R.id.messageText);
            timestamp = itemView.findViewById(R.id.timestamp);
            aiAvatar = itemView.findViewById(R.id.aiAvatar);
            messageStatus = itemView.findViewById(R.id.messageStatus);
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
            
            // Add subtle avatar animation
            if (aiAvatar != null) {
                animateAvatarGlow(aiAvatar);
            }
        }
        
        private void animateAvatarGlow(View avatar) {
            avatar.animate()
                .scaleX(1.02f).scaleY(1.02f)
                .setDuration(800)
                .withEndAction(() -> 
                    avatar.animate().scaleX(1f).scaleY(1f).setDuration(800).start())
                .start();
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
        View typingDot1, typingDot2, typingDot3;
        View avatarPulse;
        ImageView aiAvatar;
        
        TypingViewHolder(View itemView) {
            super(itemView);
            typingDot1 = itemView.findViewById(R.id.typingDot1);
            typingDot2 = itemView.findViewById(R.id.typingDot2);
            typingDot3 = itemView.findViewById(R.id.typingDot3);
            avatarPulse = itemView.findViewById(R.id.avatarPulse);
            aiAvatar = itemView.findViewById(R.id.aiAvatar);
        }
        
        void bind(ChatMessage message) {
            // Typing indicator animations are applied in applyTypingAnimation method
        }
    }
}