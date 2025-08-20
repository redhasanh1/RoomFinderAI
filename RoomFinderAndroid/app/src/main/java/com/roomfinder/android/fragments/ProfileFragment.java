package com.roomfinder.android.fragments;

import android.animation.ValueAnimator;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import android.content.Context;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.roomfinder.android.R;
import com.roomfinder.android.activities.IndividualChatActivity;
import com.roomfinder.android.activities.LoginActivity;
import com.roomfinder.android.adapters.ListingsAdapter;
import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.databinding.FragmentProfileBinding;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.network.SupabaseService;
import java.util.ArrayList;
import java.util.List;

public class ProfileFragment extends Fragment implements ListingsAdapter.OnListingClickListener {
    
    private static final String TAG = "ProfileFragment";
    private FragmentProfileBinding binding;
    private SharedPreferences prefs;
    private boolean isLoggedIn = false;
    private SupabaseService supabaseService;
    private ListingsAdapter recentListingsAdapter;
    private List<Listing> recentListings = new ArrayList<>();
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentProfileBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        try {
            prefs = requireContext().getSharedPreferences("roomfinder_prefs", Context.MODE_PRIVATE);
            supabaseService = SupabaseService.getInstance();
            
            checkLoginStatus();
            setupViews();
            setupRecentListings();
            
            if (!isLoggedIn) {
                loadRecentListings();
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error in onViewCreated: " + e.getMessage(), e);
            showErrorMessage("Error loading profile");
        }
    }
    
    private void checkLoginStatus() {
        try {
            String userEmail = prefs.getString("user_email", null);
            isLoggedIn = userEmail != null;
            Log.d(TAG, "Login status: " + (isLoggedIn ? "Logged in" : "Guest"));
        } catch (Exception e) {
            Log.e(TAG, "Error checking login status: " + e.getMessage(), e);
            isLoggedIn = false;
        }
    }
    
    private void setupViews() {
        try {
            if (isLoggedIn) {
                showUserViewWithAnimation();
            } else {
                showGuestViewWithAnimation();
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in setupViews: " + e.getMessage(), e);
            // Fallback without animation
            if (isLoggedIn) {
                showUserView();
            } else {
                showGuestView();
            }
        }
    }
    
    private void showGuestView() {
        if (binding == null) return;
        
        binding.guestView.setVisibility(View.VISIBLE);
        binding.userView.setVisibility(View.GONE);
        
        setupGuestViewClicks();
    }
    
    private void showGuestViewWithAnimation() {
        if (binding == null) return;
        
        binding.userView.setVisibility(View.GONE);
        
        // Fade in animation
        binding.guestView.setAlpha(0f);
        binding.guestView.setVisibility(View.VISIBLE);
        binding.guestView.animate()
                .alpha(1f)
                .setDuration(300)
                .setInterpolator(new AccelerateDecelerateInterpolator())
                .start();
        
        setupGuestViewClicks();
    }
    
    private void setupGuestViewClicks() {
        if (binding == null) return;
        
        try {
            binding.loginButton.setOnClickListener(v -> {
                addRippleEffect(v);
                Intent intent = new Intent(requireContext(), LoginActivity.class);
                startActivityForResult(intent, 1001);
            });
            
            binding.signupButton.setOnClickListener(v -> {
                addRippleEffect(v);
                Intent intent = new Intent(requireContext(), LoginActivity.class);
                intent.putExtra("show_signup", true);
                startActivityForResult(intent, 1001);
            });
            
            binding.browseAsGuestButton.setOnClickListener(v -> {
                addRippleEffect(v);
                navigateToFragment(new HomeFragment());
            });
            
        } catch (Exception e) {
            Log.e(TAG, "Error setting up guest view clicks: " + e.getMessage(), e);
        }
    }
    
    private void showUserView() {
        if (binding == null) return;
        
        binding.guestView.setVisibility(View.GONE);
        binding.userView.setVisibility(View.VISIBLE);
        
        loadUserData();
        setupUserViewClicks();
    }
    
    private void showUserViewWithAnimation() {
        if (binding == null) return;
        
        binding.guestView.setVisibility(View.GONE);
        
        // Fade in animation
        binding.userView.setAlpha(0f);
        binding.userView.setVisibility(View.VISIBLE);
        binding.userView.animate()
                .alpha(1f)
                .setDuration(300)
                .setInterpolator(new AccelerateDecelerateInterpolator())
                .start();
        
        loadUserData();
        setupUserViewClicks();
    }
    
    private void loadUserData() {
        if (binding == null) return;
        
        try {
            // Load user profile data
            String userName = prefs.getString("user_name", "User");
            String userEmail = prefs.getString("user_email", "user@example.com");
            
            binding.userName.setText(userName);
            binding.userEmail.setText(userEmail);
            
            // Load user stats (placeholder data - replace with actual data)
            animateCounter(binding.savedCount, 0, 12, 500);
            animateCounter(binding.postedCount, 0, 3, 600);
            animateCounter(binding.messagesCount, 0, 5, 700);
            
        } catch (Exception e) {
            Log.e(TAG, "Error loading user data: " + e.getMessage(), e);
        }
    }
    
    private void setupUserViewClicks() {
        if (binding == null) return;
        
        try {
            binding.myListingsCard.setOnClickListener(v -> {
                addCardClickAnimation(v);
                Toast.makeText(requireContext(), "My Listings - Coming Soon", Toast.LENGTH_SHORT).show();
            });
            
            binding.savedPropertiesCard.setOnClickListener(v -> {
                addCardClickAnimation(v);
                navigateToFragment(new FavoritesFragment());
            });
            
            binding.messagesCard.setOnClickListener(v -> {
                addCardClickAnimation(v);
                navigateToFragment(new ChatFragment());
            });
            
            binding.aiAssistantCard.setOnClickListener(v -> {
                addCardClickAnimation(v);
                navigateToFragment(new AiChatFragment());
            });
            
            binding.settingsItem.setOnClickListener(v -> {
                addRippleEffect(v);
                Toast.makeText(requireContext(), "Settings - Coming Soon", Toast.LENGTH_SHORT).show();
            });
            
            binding.helpItem.setOnClickListener(v -> {
                addRippleEffect(v);
                Toast.makeText(requireContext(), "Help & Support - Coming Soon", Toast.LENGTH_SHORT).show();
            });
            
            binding.logoutButton.setOnClickListener(v -> {
                addRippleEffect(v);
                performLogout();
            });
            
            binding.deleteAccountItem.setOnClickListener(v -> {
                addRippleEffect(v);
                showDeleteAccountDialog();
            });
            
        } catch (Exception e) {
            Log.e(TAG, "Error setting up user view clicks: " + e.getMessage(), e);
        }
    }
    
    private void setupRecentListings() {
        if (binding == null || binding.recentListingsRecycler == null) return;
        
        try {
            recentListingsAdapter = new ListingsAdapter(recentListings, this);
            binding.recentListingsRecycler.setLayoutManager(
                new LinearLayoutManager(requireContext(), LinearLayoutManager.HORIZONTAL, false));
            binding.recentListingsRecycler.setAdapter(recentListingsAdapter);
            
        } catch (Exception e) {
            Log.e(TAG, "Error setting up recent listings: " + e.getMessage(), e);
        }
    }
    
    private void loadRecentListings() {
        if (supabaseService == null) return;
        
        try {
            supabaseService.getAllListings(new SupabaseService.ListingsCallback() {
                @Override
                public void onSuccess(List<Listing> listings) {
                    if (getActivity() == null || binding == null) return;
                    
                    getActivity().runOnUiThread(() -> {
                        try {
                            recentListings.clear();
                            // Show only first 5 listings for preview
                            int maxItems = Math.min(listings.size(), 5);
                            for (int i = 0; i < maxItems; i++) {
                                recentListings.add(listings.get(i));
                            }
                            
                            if (recentListingsAdapter != null) {
                                recentListingsAdapter.notifyDataSetChanged();
                            }
                            
                        } catch (Exception e) {
                            Log.e(TAG, "Error updating recent listings UI: " + e.getMessage(), e);
                        }
                    });
                }
                
                @Override
                public void onError(String error) {
                    Log.e(TAG, "Error loading recent listings: " + error);
                    if (getActivity() != null) {
                        getActivity().runOnUiThread(() -> {
                            showErrorMessage("Error loading recent listings");
                        });
                    }
                }
            });
            
        } catch (Exception e) {
            Log.e(TAG, "Error in loadRecentListings: " + e.getMessage(), e);
        }
    }
    
    private void performLogout() {
        try {
            // Clear ALL authentication data using AuthManager
            AuthManager authManager = AuthManager.getInstance(requireContext());
            authManager.completeLogout();
            authManager.clearAllAuthData();
            
            // Clear saved user data from SharedPreferences
            prefs.edit()
                .remove("user_email")
                .remove("user_name")
                .remove("auth_token")
                .apply();
            
            Toast.makeText(requireContext(), "Signed out successfully", Toast.LENGTH_SHORT).show();
            
            // Navigate to login activity and clear task stack to prevent back navigation
            Intent loginIntent = new Intent(requireContext(), LoginActivity.class);
            loginIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
            startActivity(loginIntent);
            
            // Finish the current activity if possible
            if (getActivity() != null) {
                getActivity().finish();
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error during logout: " + e.getMessage(), e);
            showErrorMessage("Error during logout");
        }
    }
    
    private void navigateToFragment(Fragment fragment) {
        try {
            if (getActivity() != null && getActivity().getSupportFragmentManager() != null) {
                getActivity().getSupportFragmentManager()
                    .beginTransaction()
                    .replace(R.id.fragmentContainer, fragment)
                    .addToBackStack(null)
                    .commit();
            }
        } catch (Exception e) {
            Log.e(TAG, "Error navigating to fragment: " + e.getMessage(), e);
        }
    }
    
    // Animation helper methods
    private void addRippleEffect(View view) {
        try {
            view.animate()
                .scaleX(0.95f)
                .scaleY(0.95f)
                .setDuration(100)
                .withEndAction(() -> {
                    view.animate()
                        .scaleX(1f)
                        .scaleY(1f)
                        .setDuration(100)
                        .start();
                })
                .start();
        } catch (Exception e) {
            Log.e(TAG, "Error adding ripple effect: " + e.getMessage(), e);
        }
    }
    
    private void addCardClickAnimation(View view) {
        try {
            view.animate()
                .scaleX(0.97f)
                .scaleY(0.97f)
                .setDuration(150)
                .withEndAction(() -> {
                    view.animate()
                        .scaleX(1f)
                        .scaleY(1f)
                        .setDuration(150)
                        .start();
                })
                .start();
        } catch (Exception e) {
            Log.e(TAG, "Error adding card click animation: " + e.getMessage(), e);
        }
    }
    
    private void animateCounter(android.widget.TextView textView, int start, int end, int duration) {
        try {
            ValueAnimator animator = ValueAnimator.ofInt(start, end);
            animator.setDuration(duration);
            animator.setInterpolator(new AccelerateDecelerateInterpolator());
            animator.addUpdateListener(animation -> {
                if (textView != null) {
                    textView.setText(String.valueOf(animation.getAnimatedValue()));
                }
            });
            animator.start();
        } catch (Exception e) {
            Log.e(TAG, "Error animating counter: " + e.getMessage(), e);
            // Fallback - just set the final value
            if (textView != null) {
                textView.setText(String.valueOf(end));
            }
        }
    }
    
    private void showErrorMessage(String message) {
        try {
            if (getContext() != null) {
                Toast.makeText(getContext(), message, Toast.LENGTH_SHORT).show();
            }
        } catch (Exception e) {
            Log.e(TAG, "Error showing error message: " + e.getMessage(), e);
        }
    }
    
    private void showDeleteAccountDialog() {
        try {
            new MaterialAlertDialogBuilder(requireContext())
                    .setTitle("Delete Account")
                    .setMessage("Are you sure you want to delete your account? This action cannot be undone. All your data, listings, and chat history will be permanently deleted.")
                    .setPositiveButton("Delete Account", (dialog, which) -> {
                        performDeleteAccount();
                    })
                    .setNegativeButton("Cancel", null)
                    .setIcon(android.R.drawable.ic_menu_delete)
                    .show();
        } catch (Exception e) {
            Log.e(TAG, "Error showing delete account dialog: " + e.getMessage(), e);
            showErrorMessage("Error showing delete dialog");
        }
    }
    
    private void performDeleteAccount() {
        try {
            AuthManager authManager = AuthManager.getInstance(requireContext());
            User currentUser = authManager.getCurrentUser();
            
            if (currentUser == null) {
                showErrorMessage("No user found to delete");
                return;
            }
            
            // Clear ALL authentication data
            authManager.completeLogout();
            authManager.clearAllAuthData();
            
            // Clear saved user data from SharedPreferences
            prefs.edit().clear().apply();
            
            Toast.makeText(requireContext(), "Account deleted successfully", Toast.LENGTH_LONG).show();
            
            // Navigate to login activity and clear task stack
            Intent loginIntent = new Intent(requireContext(), LoginActivity.class);
            loginIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
            startActivity(loginIntent);
            
            // Finish the current activity
            if (getActivity() != null) {
                getActivity().finish();
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error deleting account: " + e.getMessage(), e);
            showErrorMessage("Error deleting account");
        }
    }
    
    @Override
    public void onListingClick(Listing listing) {
        try {
            Toast.makeText(requireContext(), 
                "Sign up to view full listing details for " + listing.getTitle(), 
                Toast.LENGTH_SHORT).show();
        } catch (Exception e) {
            Log.e(TAG, "Error handling listing click: " + e.getMessage(), e);
        }
    }
    
    @Override
    public void onFavoriteClick(Listing listing, int position) {
        try {
            Toast.makeText(requireContext(), 
                "Sign up to save favorites", 
                Toast.LENGTH_SHORT).show();
        } catch (Exception e) {
            Log.e(TAG, "Error handling favorite click: " + e.getMessage(), e);
        }
    }
    
    @Override
    public void onResume() {
        super.onResume();
        try {
            // Check login status again when returning to this fragment
            checkLoginStatus();
            setupViews();
        } catch (Exception e) {
            Log.e(TAG, "Error in onResume: " + e.getMessage(), e);
        }
    }
    
    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        
        if (requestCode == 1001 && resultCode == getActivity().RESULT_OK) {
            try {
                // User successfully logged in, refresh the view
                checkLoginStatus();
                setupViews();
            } catch (Exception e) {
                Log.e(TAG, "Error in onActivityResult: " + e.getMessage(), e);
            }
        }
    }
    
    @Override
    public void onDestroyView() {
        super.onDestroyView();
        try {
            binding = null;
            recentListingsAdapter = null;
            recentListings.clear();
        } catch (Exception e) {
            Log.e(TAG, "Error in onDestroyView: " + e.getMessage(), e);
        }
    }
    
    @Override
    public void onChatClick(Listing listing) {
        AuthManager authManager = AuthManager.getInstance(requireContext());
        
        if (authManager.isUserAuthenticated()) {
            String currentUserEmail = authManager.getUserEmail();
            
            Intent intent = new Intent(requireContext(), IndividualChatActivity.class);
            intent.putExtra("listing_id", listing.getId());
            intent.putExtra("listing_title", listing.getTitle());
            intent.putExtra("owner_email", listing.getUserEmail());
            intent.putExtra("current_user_email", currentUserEmail);
            startActivity(intent);
        } else {
            new MaterialAlertDialogBuilder(requireContext())
                    .setTitle("Login Required")
                    .setMessage("You need to sign in to chat with property owners.")
                    .setPositiveButton("Sign In", (dialog, which) -> {
                        Intent loginIntent = new Intent(requireContext(), LoginActivity.class);
                        startActivity(loginIntent);
                    })
                    .setNegativeButton("Cancel", null)
                    .setIcon(R.drawable.ic_chat)
                    .show();
        }
    }
}