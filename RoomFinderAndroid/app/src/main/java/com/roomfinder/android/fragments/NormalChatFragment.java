package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import com.roomfinder.android.R;
import com.roomfinder.android.databinding.FragmentNormalChatBinding;
import java.util.ArrayList;
import java.util.List;

public class NormalChatFragment extends Fragment {
    
    private FragmentNormalChatBinding binding;
    private List<ChatConversation> conversations = new ArrayList<>();
    private ConversationAdapter conversationAdapter;
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentNormalChatBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
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
        conversationAdapter = new ConversationAdapter(conversations);
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
        // In a real app, you would load conversations from a database or API
        // For now, we'll show the empty state since there are no conversations
        updateUI();
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
        // In a real app, this would show options to start a new chat
        // For now, we'll just show a toast
        android.widget.Toast.makeText(getContext(), 
            "Contact property owners through their listings to start chatting!", 
            android.widget.Toast.LENGTH_LONG).show();
    }
    
    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
    
    // Simple ChatConversation class
    public static class ChatConversation {
        public String contactName;
        public String lastMessage;
        public long timestamp;
        public String propertyTitle;
        public boolean isUnread;
        
        public ChatConversation(String contactName, String lastMessage, long timestamp, 
                               String propertyTitle, boolean isUnread) {
            this.contactName = contactName;
            this.lastMessage = lastMessage;
            this.timestamp = timestamp;
            this.propertyTitle = propertyTitle;
            this.isUnread = isUnread;
        }
    }
    
    // Simple ConversationAdapter (you might want to create a separate file for this)
    private static class ConversationAdapter extends androidx.recyclerview.widget.RecyclerView.Adapter<ConversationAdapter.ConversationViewHolder> {
        private List<ChatConversation> conversations;
        
        public ConversationAdapter(List<ChatConversation> conversations) {
            this.conversations = conversations;
        }
        
        @NonNull
        @Override
        public ConversationViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            // For now, using a simple layout. In a real app, you'd create a proper conversation item layout
            View view = LayoutInflater.from(parent.getContext())
                    .inflate(android.R.layout.simple_list_item_2, parent, false);
            return new ConversationViewHolder(view);
        }
        
        @Override
        public void onBindViewHolder(@NonNull ConversationViewHolder holder, int position) {
            ChatConversation conversation = conversations.get(position);
            
            android.widget.TextView text1 = holder.itemView.findViewById(android.R.id.text1);
            android.widget.TextView text2 = holder.itemView.findViewById(android.R.id.text2);
            
            text1.setText(conversation.contactName + " - " + conversation.propertyTitle);
            text2.setText(conversation.lastMessage);
            
            // Add click listener to open individual chat
            holder.itemView.setOnClickListener(v -> {
                // In a real app, this would open the individual chat screen
                android.widget.Toast.makeText(v.getContext(), 
                    "Opening chat with " + conversation.contactName, 
                    android.widget.Toast.LENGTH_SHORT).show();
            });
        }
        
        @Override
        public int getItemCount() {
            return conversations.size();
        }
        
        static class ConversationViewHolder extends androidx.recyclerview.widget.RecyclerView.ViewHolder {
            public ConversationViewHolder(@NonNull View itemView) {
                super(itemView);
            }
        }
    }
}