package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import com.google.android.material.card.MaterialCardView;
import com.roomfinder.android.R;
import com.roomfinder.android.databinding.FragmentChatBinding;

public class ChatFragment extends Fragment {
    
    private FragmentChatBinding binding;
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentChatBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        setupClickListeners();
    }
    
    private void setupClickListeners() {
        // AI Negotiator Chat Card
        binding.aiChatCard.setOnClickListener(v -> {
            // Navigate to AI Chat Fragment
            navigateToAiChat();
        });
        
        // Normal Chat Card
        binding.normalChatCard.setOnClickListener(v -> {
            // Navigate to Normal Chat Fragment
            navigateToNormalChat();
        });
    }
    
    private void navigateToAiChat() {
        AiChatFragment aiChatFragment = new AiChatFragment();
        getParentFragmentManager()
                .beginTransaction()
                .replace(R.id.fragmentContainer, aiChatFragment)
                .addToBackStack(null)
                .commit();
    }
    
    private void navigateToNormalChat() {
        NormalChatFragment normalChatFragment = new NormalChatFragment();
        getParentFragmentManager()
                .beginTransaction()
                .replace(R.id.fragmentContainer, normalChatFragment)
                .addToBackStack(null)
                .commit();
    }
    
    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}