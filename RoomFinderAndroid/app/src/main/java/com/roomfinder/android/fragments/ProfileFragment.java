package com.roomfinder.android.fragments;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import android.content.Context;
import com.roomfinder.android.activities.LoginActivity;
import com.roomfinder.android.databinding.FragmentProfileBinding;

public class ProfileFragment extends Fragment {
    
    private FragmentProfileBinding binding;
    private SharedPreferences prefs;
    private boolean isLoggedIn = false;
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentProfileBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        prefs = requireContext().getSharedPreferences("roomfinder_prefs", Context.MODE_PRIVATE);
        checkLoginStatus();
        setupViews();
    }
    
    private void checkLoginStatus() {
        // Check if user is logged in (for now just check if we have a saved user email)
        String userEmail = prefs.getString("user_email", null);
        isLoggedIn = userEmail != null;
    }
    
    private void setupViews() {
        if (isLoggedIn) {
            showLoggedInView();
        } else {
            showGuestView();
        }
    }
    
    private void showGuestView() {
        binding.guestLayout.setVisibility(View.VISIBLE);
        binding.profileLayout.setVisibility(View.GONE);
        
        binding.loginButton.setOnClickListener(v -> {
            startActivity(new Intent(requireContext(), LoginActivity.class));
        });
        
        binding.signupButton.setOnClickListener(v -> {
            Intent intent = new Intent(requireContext(), LoginActivity.class);
            intent.putExtra("show_signup", true);
            startActivity(intent);
        });
        
        binding.browseAsGuestButton.setOnClickListener(v -> {
            // Just dismiss or go back to home
            requireActivity().getSupportFragmentManager()
                .beginTransaction()
                .replace(binding.getRoot().getId(), new HomeFragment())
                .commit();
        });
    }
    
    private void showLoggedInView() {
        binding.guestLayout.setVisibility(View.GONE);
        binding.profileLayout.setVisibility(View.VISIBLE);
        
        // Load user data
        String userName = prefs.getString("user_name", "User");
        String userEmail = prefs.getString("user_email", "");
        
        binding.userNameText.setText(userName);
        binding.userEmailText.setText(userEmail);
        
        // Setup menu items
        binding.myListingsItem.setOnClickListener(v -> {
            // TODO: Navigate to my listings
        });
        
        binding.myFavoritesItem.setOnClickListener(v -> {
            // Navigate to favorites
            requireActivity().getSupportFragmentManager()
                .beginTransaction()
                .replace(binding.getRoot().getId(), new FavoritesFragment())
                .commit();
        });
        
        binding.messagesItem.setOnClickListener(v -> {
            // TODO: Navigate to messages
        });
        
        binding.settingsItem.setOnClickListener(v -> {
            // TODO: Navigate to settings
        });
        
        binding.logoutButton.setOnClickListener(v -> {
            // Clear saved user data
            prefs.edit()
                .remove("user_email")
                .remove("user_name")
                .remove("auth_token")
                .apply();
            
            // Refresh view
            isLoggedIn = false;
            setupViews();
        });
    }
    
    @Override
    public void onResume() {
        super.onResume();
        // Check login status again when returning to this fragment
        checkLoginStatus();
        setupViews();
    }
}