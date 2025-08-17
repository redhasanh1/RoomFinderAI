package com.roomfinder.android.fragments;

import android.content.Intent;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.roomfinder.android.R;
import com.roomfinder.android.activities.IndividualChatActivity;
import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.databinding.FragmentNormalChatBinding;
import com.roomfinder.android.databinding.ItemConversationBinding;
import com.roomfinder.android.services.ChatStorageService;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class NormalChatFragment extends Fragment {
    
    private FragmentNormalChatBinding binding;
    private List<ChatStorageService.Conversation> conversations = new ArrayList<>();
    private ConversationAdapter conversationAdapter;
    private ChatStorageService chatStorage;
    private AuthManager authManager;
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentNormalChatBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        chatStorage = ChatStorageService.getInstance(requireContext());
        authManager = AuthManager.getInstance(requireContext());
        
        setupToolbar();
        setupRecyclerView();
        setupClickListeners();
        loadConversations();
    }
    
    private void setupToolbar() {
        binding.toolbar.setNavigationOnClickListener(v -> {
            requireActivity().onBackPressed();
        });
    }
    
    private void setupRecyclerView() {
        conversationAdapter = new ConversationAdapter();
        binding.conversationsRecyclerView.setLayoutManager(new LinearLayoutManager(getContext()));
        binding.conversationsRecyclerView.setAdapter(conversationAdapter);
    }
    
    private void setupClickListeners() {
        binding.browseListingsButton.setOnClickListener(v -> {
            // Navigate to search fragment
            navigateToSearch();
        });
        
        binding.newChatFab.setOnClickListener(v -> {
            // In a real app, this would open a contact selection or new chat creation screen
            // For now, we'll show a placeholder message
            showNewChatOptions();
        });
    }
    
    private void loadConversations() {
        if (authManager.isUserAuthenticated()) {
            String userEmail = authManager.getUserEmail();
            
            // Use async version to prevent UI blocking
            chatStorage.getUserConversationsAsync(userEmail, new ChatStorageService.ConversationsCallback() {
                @Override
                public void onConversationsLoaded(List<ChatStorageService.Conversation> userConversations) {
                    conversations.clear();
                    conversations.addAll(userConversations);
                    updateUI();
                }
                
                @Override
                public void onError(String error) {
                    android.util.Log.e("NormalChatFragment", "Failed to load conversations: " + error);
                    updateUI(); // Show empty state
                }
            });
        } else {
            updateUI();
        }
    }
    
    private void updateUI() {
        if (conversations.isEmpty()) {
            binding.conversationsRecyclerView.setVisibility(View.GONE);
            binding.emptyStateLayout.setVisibility(View.VISIBLE);
            binding.newChatFab.setVisibility(View.GONE);
        } else {
            binding.conversationsRecyclerView.setVisibility(View.VISIBLE);
            binding.emptyStateLayout.setVisibility(View.GONE);
            binding.newChatFab.setVisibility(View.VISIBLE);
            conversationAdapter.notifyDataSetChanged();
        }
    }
    
    private void navigateToSearch() {
        // Navigate to search fragment
        SearchFragment searchFragment = new SearchFragment();
        getParentFragmentManager()
                .beginTransaction()
                .replace(R.id.fragmentContainer, searchFragment)
                .addToBackStack(null)
                .commit();
    }
    
    private void showNewChatOptions() {
        android.widget.Toast.makeText(getContext(), 
            "Contact property owners through their listings to start chatting!", 
            android.widget.Toast.LENGTH_LONG).show();
    }
    
    @Override
    public void onResume() {
        super.onResume();
        // Reload conversations when returning to this fragment
        loadConversations();
    }
    
    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
    
    
    // Conversation Adapter
    private class ConversationAdapter extends RecyclerView.Adapter<ConversationAdapter.ConversationViewHolder> {
        
        @NonNull
        @Override
        public ConversationViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            ItemConversationBinding binding = ItemConversationBinding.inflate(
                LayoutInflater.from(parent.getContext()), parent, false
            );
            return new ConversationViewHolder(binding);
        }
        
        @Override
        public void onBindViewHolder(@NonNull ConversationViewHolder holder, int position) {
            holder.bind(conversations.get(position));
        }
        
        @Override
        public int getItemCount() {
            return conversations.size();
        }
        
        class ConversationViewHolder extends RecyclerView.ViewHolder {
            private final ItemConversationBinding binding;
            
            public ConversationViewHolder(ItemConversationBinding binding) {
                super(binding.getRoot());
                this.binding = binding;
            }
            
            public void bind(ChatStorageService.Conversation conversation) {
                // Set avatar initials
                String initials = getInitials(conversation.otherUserEmail);
                binding.avatarText.setText(initials);
                
                // Set name (email for now)
                binding.nameText.setText(conversation.otherUserEmail);
                
                // Set property title
                binding.propertyText.setText(conversation.listingTitle);
                
                // Set last message
                binding.lastMessageText.setText(conversation.lastMessage);
                
                // Set time
                String timeText = formatTime(conversation.lastMessageTime);
                binding.timeText.setText(timeText);
                
                // Set unread badge
                if (conversation.unreadCount > 0) {
                    binding.unreadBadge.setVisibility(View.VISIBLE);
                    binding.unreadBadge.setText(String.valueOf(conversation.unreadCount));
                } else {
                    binding.unreadBadge.setVisibility(View.GONE);
                }
                
                // Click listener to open chat
                binding.getRoot().setOnClickListener(v -> {
                    Intent intent = new Intent(requireContext(), IndividualChatActivity.class);
                    intent.putExtra("listing_id", conversation.listingId);
                    intent.putExtra("listing_title", conversation.listingTitle);
                    intent.putExtra("owner_email", conversation.otherUserEmail);
                    intent.putExtra("current_user_email", conversation.currentUserEmail);
                    startActivity(intent);
                    
                    // Mark as read
                    chatStorage.markAsRead(conversation.id);
                });
            }
            
            private String getInitials(String email) {
                if (email == null || email.isEmpty()) return "??";
                String[] parts = email.split("@")[0].split("[._-]");
                if (parts.length >= 2) {
                    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
                } else if (parts.length == 1 && parts[0].length() >= 2) {
                    return parts[0].substring(0, 2).toUpperCase();
                } else {
                    return parts[0].substring(0, 1).toUpperCase();
                }
            }
            
            private String formatTime(long timestamp) {
                Date now = new Date();
                Date messageDate = new Date(timestamp);
                
                long diff = now.getTime() - messageDate.getTime();
                long hours = diff / (1000 * 60 * 60);
                
                if (hours < 24) {
                    return new SimpleDateFormat("h:mm a", Locale.getDefault()).format(messageDate);
                } else if (hours < 48) {
                    return "Yesterday";
                } else {
                    return new SimpleDateFormat("MMM d", Locale.getDefault()).format(messageDate);
                }
            }
        }
    }
}