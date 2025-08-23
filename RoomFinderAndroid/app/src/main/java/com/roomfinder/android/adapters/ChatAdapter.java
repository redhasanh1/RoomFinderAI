package com.roomfinder.android.adapters;

import android.animation.AnimatorInflater;
import android.animation.AnimatorSet;
import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.text.style.ImageSpan;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;
import androidx.core.content.ContextCompat;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import com.roomfinder.android.R;
import com.roomfinder.android.models.ChatMessage;
import com.roomfinder.android.models.Listing;
import java.util.List;

public class ChatAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    
    private static final int VIEW_TYPE_USER = 1;
    private static final int VIEW_TYPE_AI = 2;
    private static final int VIEW_TYPE_SYSTEM = 3;
    private static final int VIEW_TYPE_TYPING = 4;
    private static final int VIEW_TYPE_USER_PHOTO = 5;
    private static final int VIEW_TYPE_AI_PHOTO = 6;
    private static final int VIEW_TYPE_PROPERTY_CARD = 7;
    
    private List<ChatMessage> messages;
    private String currentUserEmail;
    private OnPropertyCardClickListener propertyCardClickListener;
    
    public interface OnPropertyCardClickListener {
        void onContactLandlordClick(Listing listing);
    }
    
    public ChatAdapter(List<ChatMessage> messages) {
        this.messages = messages;
    }
    
    public ChatAdapter(List<ChatMessage> messages, String currentUserEmail) {
        this.messages = messages;
        this.currentUserEmail = currentUserEmail;
    }
    
    public void setOnPropertyCardClickListener(OnPropertyCardClickListener listener) {
        this.propertyCardClickListener = listener;
    }
    
    @Override
    public int getItemViewType(int position) {
        ChatMessage message = messages.get(position);
        
        // Determine view type based on sender and typing status
        if (message.isTyping()) {
            return VIEW_TYPE_TYPING;
        } else if (message.getType() == ChatMessage.MessageType.PROPERTY_CARD) {
            return VIEW_TYPE_PROPERTY_CARD;
        } else if (message.isFileMessage()) {
            // Handle photo/file messages
            if (message.isRealUserMessage()) {
                if (currentUserEmail != null && message.isFromCurrentUser(currentUserEmail)) {
                    return VIEW_TYPE_USER_PHOTO;
                } else {
                    return VIEW_TYPE_AI_PHOTO;
                }
            } else if (message.isFromUser()) {
                return VIEW_TYPE_USER_PHOTO;
            } else {
                return VIEW_TYPE_AI_PHOTO;
            }
        } else if (message.isRealUserMessage()) {
            // For real user messages, check if it's from current user
            if (currentUserEmail != null && message.isFromCurrentUser(currentUserEmail)) {
                return VIEW_TYPE_USER;
            } else {
                return VIEW_TYPE_AI; // Use AI layout for other users' messages
            }
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
            case VIEW_TYPE_USER_PHOTO:
                View userPhotoView = inflater.inflate(R.layout.item_chat_user_photo, parent, false);
                return new UserPhotoViewHolder(userPhotoView);
            case VIEW_TYPE_AI_PHOTO:
                View aiPhotoView = inflater.inflate(R.layout.item_chat_ai_photo, parent, false);
                return new AiPhotoViewHolder(aiPhotoView);
            case VIEW_TYPE_TYPING:
                View typingView = inflater.inflate(R.layout.item_chat_typing, parent, false);
                return new TypingViewHolder(typingView);
            case VIEW_TYPE_PROPERTY_CARD:
                View propertyCardView = inflater.inflate(R.layout.item_chat_property_card, parent, false);
                return new PropertyCardViewHolder(propertyCardView);
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
        } else if (holder instanceof UserPhotoViewHolder) {
            ((UserPhotoViewHolder) holder).bind(message);
            applySlideInAnimation(holder.itemView, VIEW_TYPE_USER);
        } else if (holder instanceof AiPhotoViewHolder) {
            ((AiPhotoViewHolder) holder).bind(message);
            applySlideInAnimation(holder.itemView, VIEW_TYPE_AI);
        } else if (holder instanceof PropertyCardViewHolder) {
            PropertyCardViewHolder propertyHolder = (PropertyCardViewHolder) holder;
            propertyHolder.bind(message);
            applySlideInAnimation(holder.itemView, VIEW_TYPE_AI);
            
            // Set click listener for contact button
            if (propertyCardClickListener != null && message.getAssociatedListing() != null) {
                propertyHolder.contactLandlordButton.setOnClickListener(v -> 
                    propertyCardClickListener.onContactLandlordClick(message.getAssociatedListing()));
            }
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
            
            // Replace icon placeholders with drawable icons first
            spannableString = replaceIconsWithDrawables(text, spannableString);
            
            // Highlight property names and prices
            String finalText = spannableString.toString();
            if (finalText.contains("$")) {
                int start = finalText.indexOf("$");
                while (start != -1) {
                    int end = finalText.indexOf(" ", start);
                    if (end == -1) end = finalText.indexOf("\n", start);
                    if (end == -1) end = finalText.length();
                    
                    spannableString.setSpan(
                        new ForegroundColorSpan(Color.parseColor("#4CAF50")), 
                        start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                    );
                    
                    start = finalText.indexOf("$", end);
                }
            }
            
            messageText.setText(spannableString);
            timestamp.setText(message.getFormattedTime());
            
            // Add subtle avatar animation
            if (aiAvatar != null) {
                animateAvatarGlow(aiAvatar);
            }
        }
        
        private SpannableString replaceIconsWithDrawables(String text, SpannableString spannable) {
            Context context = messageText.getContext();
            
            // Create a new SpannableString to work with
            SpannableString newSpannable = new SpannableString(text);
            
            // Replace all icon placeholders with the AI Negotiator Assistant logo
            newSpannable = replaceIconWithDrawable(newSpannable, "[ICON:home]", R.drawable.ai_negotiator_logo, context);
            newSpannable = replaceIconWithDrawable(newSpannable, "[ICON:handshake]", R.drawable.ai_negotiator_logo, context);
            newSpannable = replaceIconWithDrawable(newSpannable, "[ICON:document]", R.drawable.ai_negotiator_logo, context);
            
            return newSpannable;
        }
        
        private SpannableString replaceIconWithDrawable(SpannableString spannable, String placeholder, int drawableRes, Context context) {
            String text = spannable.toString();
            int index = text.indexOf(placeholder);
            
            while (index != -1) {
                // Get the drawable and set its bounds
                Drawable drawable = ContextCompat.getDrawable(context, drawableRes);
                if (drawable != null) {
                    int size = (int) (messageText.getTextSize() * 1.2f); // Make icon slightly larger than text
                    drawable.setBounds(0, 0, size, size);
                    
                    // Create ImageSpan and replace the placeholder
                    ImageSpan imageSpan = new ImageSpan(drawable, ImageSpan.ALIGN_BASELINE);
                    spannable.setSpan(imageSpan, index, index + placeholder.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                }
                
                // Find next occurrence
                index = text.indexOf(placeholder, index + 1);
            }
            
            return spannable;
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
    
    // User Photo Message ViewHolder
    static class UserPhotoViewHolder extends RecyclerView.ViewHolder {
        ImageView photoImageView;
        TextView photoCaptionText;
        TextView timestamp;
        ImageView deliveryStatus;
        ImageView userAvatar;
        View photoLoadingProgress;
        View photoErrorOverlay;
        
        UserPhotoViewHolder(View itemView) {
            super(itemView);
            photoImageView = itemView.findViewById(R.id.photoImageView);
            photoCaptionText = itemView.findViewById(R.id.photoCaptionText);
            timestamp = itemView.findViewById(R.id.timestamp);
            deliveryStatus = itemView.findViewById(R.id.deliveryStatus);
            userAvatar = itemView.findViewById(R.id.userAvatar);
            photoLoadingProgress = itemView.findViewById(R.id.photoLoadingProgress);
            photoErrorOverlay = itemView.findViewById(R.id.photoErrorOverlay);
        }
        
        void bind(ChatMessage message) {
            // Set timestamp
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
            
            // Handle photo caption
            if (message.getContent() != null && !message.getContent().trim().isEmpty()) {
                photoCaptionText.setText(message.getContent());
                photoCaptionText.setVisibility(View.VISIBLE);
            } else {
                photoCaptionText.setVisibility(View.GONE);
            }
            
            // Load photo image
            loadPhotoImage(message);
        }
        
        private void loadPhotoImage(ChatMessage message) {
            if (message.getFileUrl() != null && !message.getFileUrl().isEmpty()) {
                // Show loading state
                photoLoadingProgress.setVisibility(View.VISIBLE);
                photoErrorOverlay.setVisibility(View.GONE);
                
                String fileUrl = message.getFileUrl();
                
                try {
                    if (fileUrl.startsWith("data:image/")) {
                        // Handle base64 data URLs
                        loadBase64Image(fileUrl);
                    } else if (fileUrl.startsWith("http")) {
                        // Handle regular HTTP URLs (Supabase Storage)
                        loadNetworkImage(fileUrl);
                    } else {
                        // Handle local file URIs
                        loadLocalImage(fileUrl);
                    }
                } catch (Exception e) {
                    android.util.Log.e("ChatAdapter", "Error loading image: " + e.getMessage());
                    showImageError();
                }
                
                // Add click listener for full-screen view
                photoImageView.setOnClickListener(v -> {
                    // TODO: Open full-screen image viewer
                });
            } else {
                // Show error state
                showImageError();
            }
        }
        
        private void loadBase64Image(String dataUrl) {
            try {
                // Extract base64 data from data URL
                String base64Data = dataUrl.substring(dataUrl.indexOf(",") + 1);
                byte[] imageBytes = android.util.Base64.decode(base64Data, android.util.Base64.DEFAULT);
                
                // Convert to bitmap
                android.graphics.Bitmap bitmap = android.graphics.BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.length);
                
                if (bitmap != null) {
                    photoLoadingProgress.setVisibility(View.GONE);
                    photoImageView.setImageBitmap(bitmap);
                } else {
                    showImageError();
                }
            } catch (Exception e) {
                android.util.Log.e("ChatAdapter", "Error loading base64 image", e);
                showImageError();
            }
        }
        
        private void loadNetworkImage(String url) {
            // TODO: Implement proper network image loading with Glide
            // For now, show placeholder
            photoLoadingProgress.setVisibility(View.GONE);
            photoImageView.setImageResource(R.drawable.ic_image);
        }
        
        private void loadLocalImage(String uri) {
            try {
                android.net.Uri imageUri = android.net.Uri.parse(uri);
                photoLoadingProgress.setVisibility(View.GONE);
                photoImageView.setImageURI(imageUri);
            } catch (Exception e) {
                android.util.Log.e("ChatAdapter", "Error loading local image", e);
                showImageError();
            }
        }
        
        private void showImageError() {
            photoLoadingProgress.setVisibility(View.GONE);
            photoErrorOverlay.setVisibility(View.VISIBLE);
        }
    }
    
    // AI/Other User Photo Message ViewHolder
    static class AiPhotoViewHolder extends RecyclerView.ViewHolder {
        ImageView photoImageView;
        TextView photoCaptionText;
        TextView timestamp;
        ImageView aiAvatar;
        View photoLoadingProgress;
        View photoErrorOverlay;
        
        AiPhotoViewHolder(View itemView) {
            super(itemView);
            photoImageView = itemView.findViewById(R.id.photoImageView);
            photoCaptionText = itemView.findViewById(R.id.photoCaptionText);
            timestamp = itemView.findViewById(R.id.timestamp);
            aiAvatar = itemView.findViewById(R.id.aiAvatar);
            photoLoadingProgress = itemView.findViewById(R.id.photoLoadingProgress);
            photoErrorOverlay = itemView.findViewById(R.id.photoErrorOverlay);
        }
        
        void bind(ChatMessage message) {
            // Set timestamp
            timestamp.setText(message.getFormattedTime());
            
            // Handle photo caption
            if (message.getContent() != null && !message.getContent().trim().isEmpty()) {
                photoCaptionText.setText(message.getContent());
                photoCaptionText.setVisibility(View.VISIBLE);
            } else {
                photoCaptionText.setVisibility(View.GONE);
            }
            
            // Load photo image
            loadPhotoImage(message);
            
            // Add subtle avatar animation
            if (aiAvatar != null) {
                animateAvatar(aiAvatar);
            }
        }
        
        private void loadPhotoImage(ChatMessage message) {
            if (message.getFileUrl() != null && !message.getFileUrl().isEmpty()) {
                // Show loading state
                photoLoadingProgress.setVisibility(View.VISIBLE);
                photoErrorOverlay.setVisibility(View.GONE);
                
                String fileUrl = message.getFileUrl();
                
                try {
                    if (fileUrl.startsWith("data:image/")) {
                        // Handle base64 data URLs
                        loadBase64Image(fileUrl);
                    } else if (fileUrl.startsWith("http")) {
                        // Handle regular HTTP URLs (Supabase Storage)
                        loadNetworkImage(fileUrl);
                    } else {
                        // Handle local file URIs
                        loadLocalImage(fileUrl);
                    }
                } catch (Exception e) {
                    android.util.Log.e("ChatAdapter", "Error loading image: " + e.getMessage());
                    showImageError();
                }
                
                // Add click listener for full-screen view
                photoImageView.setOnClickListener(v -> {
                    // TODO: Open full-screen image viewer
                });
            } else {
                // Show error state
                showImageError();
            }
        }
        
        private void loadBase64Image(String dataUrl) {
            try {
                // Extract base64 data from data URL
                String base64Data = dataUrl.substring(dataUrl.indexOf(",") + 1);
                byte[] imageBytes = android.util.Base64.decode(base64Data, android.util.Base64.DEFAULT);
                
                // Convert to bitmap
                android.graphics.Bitmap bitmap = android.graphics.BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.length);
                
                if (bitmap != null) {
                    photoLoadingProgress.setVisibility(View.GONE);
                    photoImageView.setImageBitmap(bitmap);
                } else {
                    showImageError();
                }
            } catch (Exception e) {
                android.util.Log.e("ChatAdapter", "Error loading base64 image", e);
                showImageError();
            }
        }
        
        private void loadNetworkImage(String url) {
            // TODO: Implement proper network image loading with Glide
            // For now, show placeholder
            photoLoadingProgress.setVisibility(View.GONE);
            photoImageView.setImageResource(R.drawable.ic_image);
        }
        
        private void loadLocalImage(String uri) {
            try {
                android.net.Uri imageUri = android.net.Uri.parse(uri);
                photoLoadingProgress.setVisibility(View.GONE);
                photoImageView.setImageURI(imageUri);
            } catch (Exception e) {
                android.util.Log.e("ChatAdapter", "Error loading local image", e);
                showImageError();
            }
        }
        
        private void showImageError() {
            photoLoadingProgress.setVisibility(View.GONE);
            photoErrorOverlay.setVisibility(View.VISIBLE);
        }
        
        private void animateAvatar(View avatar) {
            avatar.animate()
                .scaleX(1.02f).scaleY(1.02f)
                .setDuration(800)
                .withEndAction(() -> 
                    avatar.animate().scaleX(1f).scaleY(1f).setDuration(800).start())
                .start();
        }
    }
    
    static class PropertyCardViewHolder extends RecyclerView.ViewHolder {
        TextView propertyTitle;
        TextView propertyLocation;
        TextView propertyPrice;
        TextView propertyBedBath;
        TextView propertyType;
        TextView timestamp;
        ImageView aiAvatar;
        com.google.android.material.button.MaterialButton contactLandlordButton;
        
        PropertyCardViewHolder(View itemView) {
            super(itemView);
            propertyTitle = itemView.findViewById(R.id.propertyTitle);
            propertyLocation = itemView.findViewById(R.id.propertyLocation);
            propertyPrice = itemView.findViewById(R.id.propertyPrice);
            propertyBedBath = itemView.findViewById(R.id.propertyBedBath);
            propertyType = itemView.findViewById(R.id.propertyType);
            timestamp = itemView.findViewById(R.id.timestamp);
            aiAvatar = itemView.findViewById(R.id.aiAvatar);
            contactLandlordButton = itemView.findViewById(R.id.contactLandlordButton);
        }
        
        void bind(ChatMessage message) {
            if (message.getAssociatedListing() != null) {
                Listing listing = message.getAssociatedListing();
                
                propertyTitle.setText(listing.getTitle());
                propertyLocation.setText(listing.getLocation());
                propertyPrice.setText(String.format("$%,.0f/month", listing.getPrice()));
                propertyBedBath.setText(String.format("%d bed, %d bath", listing.getBedrooms(), listing.getBathrooms()));
                propertyType.setText(listing.getHouseType());
                
                // Format timestamp
                timestamp.setText(formatTime(message.getTimestamp()));
                
                // Add avatar animation
                if (aiAvatar != null) {
                    animateAvatar(aiAvatar);
                }
            }
        }
        
        private String formatTime(long timestamp) {
            java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("h:mm a", java.util.Locale.getDefault());
            return sdf.format(new java.util.Date(timestamp));
        }
        
        private void animateAvatar(View avatar) {
            avatar.animate()
                .scaleX(1.02f).scaleY(1.02f)
                .setDuration(800)
                .withEndAction(() -> 
                    avatar.animate().scaleX(1f).scaleY(1f).setDuration(800).start())
                .start();
        }
    }
}