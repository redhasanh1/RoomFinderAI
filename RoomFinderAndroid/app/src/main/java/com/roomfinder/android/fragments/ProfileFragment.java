package com.roomfinder.android.fragments;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import com.bumptech.glide.Glide;
import com.roomfinder.android.R;
import com.roomfinder.android.activities.LoginActivity;
import com.roomfinder.android.auth.SupabaseAuthService;
import com.roomfinder.android.databinding.FragmentProfileBinding;
import com.roomfinder.android.models.User;

public class ProfileFragment extends Fragment {
    
    private static final String TAG = "ProfileFragment";
    private static final int LOGIN_REQUEST_CODE = 1001;
    
    private FragmentProfileBinding binding;
    private SupabaseAuthService authService;
    private User currentUser;
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentProfileBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        authService = SupabaseAuthService.getInstance(requireContext());
        checkAuthStatus();
        setupViews();
    }
    
    private void checkAuthStatus() {
        currentUser = authService.getCurrentUser();
        Log.d(TAG, "Current user: " + (currentUser != null ? currentUser.getEmail() : "none"));
    }
    
    private void setupViews() {
        if (currentUser != null) {
            showLoggedInView();
        } else {
            showGuestView();
        }
    }
    
    private void showGuestView() {
        binding.guestLayout.setVisibility(View.VISIBLE);
        binding.profileLayout.setVisibility(View.GONE);
        
        binding.loginButton.setOnClickListener(v -> {
            Intent intent = new Intent(requireContext(), LoginActivity.class);
            startActivityForResult(intent, LOGIN_REQUEST_CODE);
        });
        
        binding.signupButton.setOnClickListener(v -> {
            Intent intent = new Intent(requireContext(), LoginActivity.class);
            intent.putExtra("show_signup", true);
            startActivityForResult(intent, LOGIN_REQUEST_CODE);
        });
        
        binding.browseAsGuestButton.setOnClickListener(v -> {
            // Just dismiss or go back to home
            requireActivity().getSupportFragmentManager()
                .beginTransaction()
                .replace(R.id.fragmentContainer, new HomeFragment())
                .commit();
        });
    }
    
    private void showLoggedInView() {
        binding.guestLayout.setVisibility(View.GONE);
        binding.profileLayout.setVisibility(View.VISIBLE);
        
        if (currentUser == null) return;
        
        // Load user data
        binding.userNameText.setText(currentUser.getFullName());
        binding.userEmailText.setText(currentUser.getEmail());
        
        // Load profile image
        if (currentUser.getProfileImage() != null && !currentUser.getProfileImage().isEmpty()) {
            Glide.with(this)
                .load(currentUser.getProfileImage())
                .placeholder(R.drawable.ic_person)
                .error(R.drawable.ic_person)
                .circleCrop()
                .into(binding.profileImageView);
        }
        
        // Setup menu items
        binding.myListingsItem.setOnClickListener(v -> {
            // TODO: Navigate to my listings
        });
        
        binding.myFavoritesItem.setOnClickListener(v -> {
            // Navigate to favorites
            requireActivity().getSupportFragmentManager()
                .beginTransaction()
                .replace(R.id.fragmentContainer, new FavoritesFragment())
                .commit();
        });
        
        binding.messagesItem.setOnClickListener(v -> {
            // TODO: Navigate to messages
        });
        
        binding.settingsItem.setOnClickListener(v -> {
            // TODO: Navigate to settings
        });
        
        binding.logoutButton.setOnClickListener(v -> {
            performLogout();
        });
    }
    
    @Override
    public void onResume() {
        super.onResume();
        // Check auth status again when returning to this fragment
        checkAuthStatus();
        setupViews();
    }
    
    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        
        if (requestCode == LOGIN_REQUEST_CODE && resultCode == getActivity().RESULT_OK) {
            // User successfully logged in, refresh the view
            checkAuthStatus();
            setupViews();
        }
    }
    
    private void performLogout() {
        authService.signOut(new SupabaseAuthService.SignOutCallback() {
            @Override
            public void onSuccess() {
                Log.d(TAG, "Logout successful");
                Toast.makeText(requireContext(), "Logged out successfully", Toast.LENGTH_SHORT).show();
                
                // Refresh view
                currentUser = null;
                setupViews();
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Logout error: " + error);
                Toast.makeText(requireContext(), "Logout failed: " + error, Toast.LENGTH_SHORT).show();
            }
        });
    }
}