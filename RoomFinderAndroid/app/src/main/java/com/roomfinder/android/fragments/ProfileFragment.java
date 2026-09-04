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
import com.roomfinder.android.models.User;
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
            
            // Always try to set up delete account button regardless of login state
            setupDeleteAccountButton();
            
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
            // Use AuthManager for proper authentication check
            AuthManager authManager = AuthManager.getInstance(requireContext());
            boolean authManagerAuthenticated = authManager.isUserAuthenticated();
            
            // Also check SharedPreferences as fallback
            String userEmail = prefs.getString("user_email", null);
            boolean hasUserEmail = userEmail != null;
            
            // Set login state based on authentication
            isLoggedIn = authManagerAuthenticated;
            
            // If AuthManager says not authenticated but we have email, clear it
            if (!authManagerAuthenticated && hasUserEmail) {
                prefs.edit().remove("user_email").remove("user_name").remove("auth_token").apply();
            }
            
            Log.d(TAG, "Login status: " + (isLoggedIn ? "Logged in" : "Guest") + 
                      " (AuthManager: " + authManagerAuthenticated + ", SharedPrefs: " + hasUserEmail + ")");
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
            
            // Google, inline on the account screen, the way iOS offers it -
            // rather than only behind another screen.
            binding.googleButton.setOnClickListener(v -> {
                addRippleEffect(v);
                com.roomfinder.android.auth.SupabaseOAuthManager.launch(
                        requireActivity(),
                        com.roomfinder.android.auth.SupabaseOAuthManager.PROVIDER_GOOGLE);
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
            // Load user profile data from AuthManager
            AuthManager authManager = AuthManager.getInstance(requireContext());
            User currentUser = authManager.getCurrentUser();
            
            String userName = "User";
            String userEmail = "user@example.com";
            
            if (currentUser != null) {
                userName = currentUser.getFirstName() + " " + currentUser.getLastName();
                userEmail = currentUser.getEmail();
            } else {
                // Fallback to SharedPreferences for backward compatibility
                userName = prefs.getString("user_name", "User");
                userEmail = prefs.getString("user_email", "user@example.com");
            }
            
            binding.userName.setText(userName);
            binding.userEmail.setText(userEmail);
            
            loadRealCounts(userEmail);
            
        } catch (Exception e) {
            Log.e(TAG, "Error loading user data: " + e.getMessage(), e);
        }
    }
    
    /**
     * Fills in the numbers under the email from the user's actual data.
     *
     * These were hardcoded: every account, on every device, was shown
     * "12 saved, 3 posted, 5 messages" - animated counters climbing to invented
     * figures. It looked like real data, which made it worse than an obvious
     * placeholder, and it was wrong for literally everyone.
     *
     * They start blank and appear as each answer lands, rather than counting up
     * from a guess. The messages counter is gone: there is no endpoint behind it
     * and inventing a third number was the original problem.
     */
    private void loadRealCounts(String userEmail) {
        if (binding == null) {
            return;
        }
        binding.savedCount.setText("");
        binding.postedCount.setText("");
        if (binding.messagesCount != null) {
            binding.messagesCount.setVisibility(View.GONE);
        }
        if (userEmail == null || userEmail.isEmpty()) {
            return;
        }

        com.roomfinder.android.network.FavoritesService.get().loadFavorites(userEmail,
                new com.roomfinder.android.network.FavoritesService.ListCallback() {
                    @Override
                    public void onLoaded(java.util.List<Listing> favorites) {
                        if (binding == null) {
                            return;
                        }
                        animateCounter(binding.savedCount, 0, favorites.size(), 500, "saved");
                    }

                    @Override
                    public void onError(String message) {
                        // Leave it blank. A zero we are not sure about is just
                        // the old fiction with a smaller number.
                    }
                });

        SupabaseService.getInstance().getAllListings(new SupabaseService.ListingsCallback() {
            @Override
            public void onSuccess(java.util.List<Listing> listings) {
                if (binding == null) {
                    return;
                }
                int mine = 0;
                for (Listing listing : listings) {
                    if (userEmail.equalsIgnoreCase(listing.getUserEmail())) {
                        mine++;
                    }
                }
                animateCounter(binding.postedCount, 0, mine, 600, "posted");
            }

            @Override
            public void onError(String error) {
                // as above - no invented number
            }
        });
    }

    private void setupUserViewClicks() {
        if (binding == null) return;
        
        try {
            binding.myListingsCard.setOnClickListener(v -> {
                addCardClickAnimation(v);
                navigateToFragment(new MyListingsFragment());
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
            
            binding.toolsCard.setOnClickListener(v -> {
                addCardClickAnimation(v);
                navigateToFragment(new ToolsFragment());
            });
            
            // "Settings" is hidden rather than wired up. There is nothing behind
            // it - no notification preferences, no theme, no language - and a row
            // that exists only to apologise for itself is worse than no row. It
            // comes back when there is something to put in it.
            if (binding.settingsItem != null) {
                binding.settingsItem.setVisibility(View.GONE);
            }

            binding.helpItem.setOnClickListener(v -> {
                addRippleEffect(v);
                openSupport();
            });
            
            binding.logoutButton.setOnClickListener(v -> {
                addRippleEffect(v);
                performLogout();
            });
            
            // Set up delete account button
            setupDeleteAccountButton();
            
        } catch (Exception e) {
            Log.e(TAG, "Error setting up user view clicks: " + e.getMessage(), e);
        }
    }
    
    /**
     * Opens the support page on roomfinderai.com, falling back to an email.
     *
     * This row used to raise "Help & Support - Coming Soon", which is a strange
     * thing to tell someone who has gone looking for help. The site already has
     * /support.html and support@roomfinderai.com is the published address, so
     * there was nothing to build - only something to point at.
     */
    private void openSupport() {
        try {
            startActivity(new Intent(Intent.ACTION_VIEW,
                    android.net.Uri.parse("https://www.roomfinderai.com/support.html")));
        } catch (Exception e) {
            try {
                Intent email = new Intent(Intent.ACTION_SENDTO,
                        android.net.Uri.parse("mailto:support@roomfinderai.com"));
                email.putExtra(Intent.EXTRA_SUBJECT, "RoomFinderAI support");
                startActivity(email);
            } catch (Exception inner) {
                Toast.makeText(requireContext(),
                        "Email support@roomfinderai.com and we'll help", Toast.LENGTH_LONG).show();
            }
        }
    }

    private void setupDeleteAccountButton() {
        try {
            if (binding.deleteAccountItem != null) {
                Log.d(TAG, "Delete account button found, setting up click listener");
                binding.deleteAccountItem.setOnClickListener(v -> {
                    addRippleEffect(v);
                    showDeleteAccountDialog();
                });
            } else {
                Log.w(TAG, "Delete account button not found in layout - this might be a binding issue");
            }
        } catch (Exception e) {
            Log.e(TAG, "Error setting up delete account button: " + e.getMessage(), e);
        }
    }
    
    private void setupRecentListings() {
        if (binding == null || binding.recentListingsRecycler == null) return;
        
        try {
            recentListingsAdapter = new ListingsAdapter(recentListings, this);
            binding.recentListingsRecycler.setLayoutManager(
                new LinearLayoutManager(requireContext(), LinearLayoutManager.HORIZONTAL, false));
            binding.recentListingsRecycler.setAdapter(recentListingsAdapter);
            updateListingsSectionVisibility();
            
        } catch (Exception e) {
            Log.e(TAG, "Error setting up recent listings: " + e.getMessage(), e);
        }
    }
    
    /**
     * A section heading with nothing under it is a promise the screen does not
     * keep, so "Your listings" appears only once there are some.
     */
    private void updateListingsSectionVisibility() {
        if (binding == null) {
            return;
        }
        boolean hasListings = recentListings != null && !recentListings.isEmpty();
        binding.yourListingsHeader.setVisibility(hasListings ? View.VISIBLE : View.GONE);
        binding.recentListingsRecycler.setVisibility(hasListings ? View.VISIBLE : View.GONE);
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
                                updateListingsSectionVisibility();
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
            
            // Update login status and show guest view (stay on profile page)
            isLoggedIn = false;
            showGuestViewWithAnimation();
            
            // Also navigate to home fragment to show logged out state
            navigateToFragment(new HomeFragment());
            
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
        animateCounter(textView, start, end, duration, null);
    }

    private void animateCounter(android.widget.TextView textView, int start, int end,
                                int duration, String unit) {
        try {
            ValueAnimator animator = ValueAnimator.ofInt(start, end);
            animator.setDuration(duration);
            animator.setInterpolator(new AccelerateDecelerateInterpolator());
            animator.addUpdateListener(animation -> {
                if (textView != null) {
                    String value = String.valueOf(animation.getAnimatedValue());
                    textView.setText(unit == null ? value : value + " " + unit);
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
            // Ask for the password in the dialog itself. Deletion is
            // irreversible and the server refuses to do it without one, so
            // there is no point confirming twice and then asking.
            android.widget.EditText passwordField = new android.widget.EditText(requireContext());
            passwordField.setHint("Your password");
            passwordField.setInputType(android.text.InputType.TYPE_CLASS_TEXT
                    | android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD);

            int pad = (int) (20 * getResources().getDisplayMetrics().density);
            android.widget.FrameLayout wrapper = new android.widget.FrameLayout(requireContext());
            wrapper.setPadding(pad, pad / 2, pad, 0);
            wrapper.addView(passwordField);

            new MaterialAlertDialogBuilder(requireContext())
                    .setTitle("Delete account")
                    .setMessage("This permanently deletes your account, your listings, your "
                            + "roommate and sublease posts, your saved rooms and your AI "
                            + "conversations. It cannot be undone.\n\n"
                            + "Enter your password to confirm.")
                    .setView(wrapper)
                    .setPositiveButton("Delete account", (dialog, which) -> {
                        String password = passwordField.getText().toString();
                        if (password.isEmpty()) {
                            showErrorMessage("Enter your password to delete your account");
                            return;
                        }
                        performDeleteAccount(password);
                    })
                    .setNegativeButton("Cancel", null)
                    .setIcon(android.R.drawable.ic_menu_delete)
                    .show();
        } catch (Exception e) {
            Log.e(TAG, "Error showing delete account dialog: " + e.getMessage(), e);
            showErrorMessage("Error showing delete dialog");
        }
    }
    
    private void performDeleteAccount(String password) {
        try {
            AuthManager authManager = AuthManager.getInstance(requireContext());
            User currentUser = authManager.getCurrentUser();

            if (currentUser == null || currentUser.getEmail() == null) {
                showErrorMessage("No user found to delete");
                return;
            }

            final String email = currentUser.getEmail();
            Toast.makeText(requireContext(), "Deleting your account...", Toast.LENGTH_SHORT).show();

            // Local state is cleared only after the server confirms. This used
            // to run unconditionally: it wiped SharedPreferences, said "Account
            // deleted successfully" and logged out, while the account, its
            // listings and its messages stayed on the server untouched. The
            // dialog promised deletion, the Play data-safety form declares it,
            // and /delete-account.html says so publicly - so it has to be true.
            new com.roomfinder.android.network.AccountDeletionService().deleteAccount(
                    email, password,
                    new com.roomfinder.android.network.AccountDeletionService.Callback() {
                        @Override
                        public void onDeleted() {
                            if (!isAdded()) {
                                return;
                            }
                            AuthManager auth = AuthManager.getInstance(requireContext());
                            auth.completeLogout();
                            auth.clearAllAuthData();
                            prefs.edit().clear().apply();

                            Toast.makeText(requireContext(),
                                    "Your account has been deleted", Toast.LENGTH_LONG).show();

                            isLoggedIn = false;
                            showGuestViewWithAnimation();
                            navigateToFragment(new HomeFragment());
                        }

                        @Override
                        public void onFailure(String code, String message) {
                            if (!isAdded()) {
                                return;
                            }
                            // Nothing is cleared here on purpose: the account
                            // still exists, so the app must not behave as if it
                            // is gone.
                            if ("no_password".equals(code)) {
                                new MaterialAlertDialogBuilder(requireContext())
                                        .setTitle("Delete account")
                                        .setMessage(message)
                                        .setPositiveButton("OK", null)
                                        .show();
                            } else {
                                showErrorMessage(message);
                            }
                        }
                    });

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