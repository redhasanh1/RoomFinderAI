package com.roomfinder.android.fragments;

import android.animation.AnimatorInflater;
import android.animation.AnimatorSet;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.HapticFeedbackConstants;
import android.view.LayoutInflater;
import android.view.MotionEvent;
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
    private AnimatorSet pressAnimator;
    private AnimatorSet releaseAnimator;
    private AnimatorSet iconAnimator;
    private Handler animationHandler = new Handler(Looper.getMainLooper());
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentChatBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        initializeAnimations();
        setupClickListeners();
        setupTouchFeedback();
    }
    
    private void initializeAnimations() {
        try {
            // Initialize smooth press and release animations
            pressAnimator = (AnimatorSet) AnimatorInflater.loadAnimator(requireContext(), 
                R.animator.ai_chat_card_press_scale);
            releaseAnimator = (AnimatorSet) AnimatorInflater.loadAnimator(requireContext(), 
                R.animator.ai_chat_card_release_scale);
            iconAnimator = (AnimatorSet) AnimatorInflater.loadAnimator(requireContext(), 
                R.animator.ai_chat_icon_rotation);
                
            // Set animation targets
            pressAnimator.setTarget(binding.aiChatCard);
            releaseAnimator.setTarget(binding.aiChatCard);
            iconAnimator.setTarget(binding.aiChatIcon);
        } catch (Exception e) {
            // Fallback if animations fail to load
            e.printStackTrace();
        }
    }
    
    private void setupTouchFeedback() {
        // Enhanced touch feedback for AI Chat Card
        binding.aiChatCard.setOnTouchListener((v, event) -> {
            switch (event.getAction()) {
                case MotionEvent.ACTION_DOWN:
                    // Haptic feedback
                    v.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY);
                    // Start press animation
                    if (pressAnimator != null) {
                        releaseAnimator.cancel();
                        pressAnimator.start();
                    }
                    return false; // Allow click to continue
                    
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    // Start release animation with delay
                    animationHandler.postDelayed(() -> {
                        if (releaseAnimator != null) {
                            pressAnimator.cancel();
                            releaseAnimator.start();
                        }
                    }, 50);
                    return false;
            }
            return false;
        });
    }
    
    private void setupClickListeners() {
        // AI Negotiator Chat Card
        binding.aiChatCard.setOnClickListener(v -> {
            // Trigger icon animation
            if (iconAnimator != null) {
                iconAnimator.start();
            }
            
            // Navigate to AI Chat Fragment with slight delay for animation
            animationHandler.postDelayed(() -> {
                navigateToAiChat();
            }, 150);
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
        
        // Clean up animations
        if (pressAnimator != null) {
            pressAnimator.cancel();
            pressAnimator = null;
        }
        if (releaseAnimator != null) {
            releaseAnimator.cancel();
            releaseAnimator = null;
        }
        if (iconAnimator != null) {
            iconAnimator.cancel();
            iconAnimator = null;
        }
        
        // Remove any pending animation callbacks
        animationHandler.removeCallbacksAndMessages(null);
        
        binding = null;
    }
}