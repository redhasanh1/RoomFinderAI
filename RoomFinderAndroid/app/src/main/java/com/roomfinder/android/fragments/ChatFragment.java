package com.roomfinder.android.fragments;

import android.content.Intent;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import com.google.android.material.card.MaterialCardView;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.roomfinder.android.R;
import com.roomfinder.android.activities.LoginActivity;
import com.roomfinder.android.auth.AuthManager;
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
        AuthManager authManager = AuthManager.getInstance(requireContext());
        
        if (authManager.isUserAuthenticated()) {
            // User is logged in, proceed to AI Chat
            AiChatFragment aiChatFragment = new AiChatFragment();
            getParentFragmentManager()
                    .beginTransaction()
                    .replace(R.id.fragmentContainer, aiChatFragment)
                    .addToBackStack(null)
                    .commit();
        } else {
            // User is not logged in, show login requirement dialog
            showLoginRequiredDialog();
        }
    }
    
    private void showLoginRequiredDialog() {
        new MaterialAlertDialogBuilder(requireContext())
                .setTitle("Login Required")
                .setMessage("You need to sign in to access the AI Negotiator. The AI assistant helps you find and negotiate rental properties.")
                .setPositiveButton("Sign In", (dialog, which) -> {
                    // Navigate to login activity
                    Intent loginIntent = new Intent(requireContext(), LoginActivity.class);
                    startActivity(loginIntent);
                })
                .setNegativeButton("Cancel", (dialog, which) -> {
                    dialog.dismiss();
                })
                .setIcon(R.drawable.ic_bot)
                .show();
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