package com.roomfinder.android;

import android.os.Bundle;
import android.view.View;
import android.util.Log;
import androidx.annotation.IdRes;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;

import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.databinding.ActivityMainBinding;
import com.roomfinder.android.fragments.*;
import com.roomfinder.android.models.User;

public class MainActivity extends AppCompatActivity {
    
    private static final String TAG = "MainActivity";
    private ActivityMainBinding binding;
    private AuthManager authManager;
    private int currentTabId = View.NO_ID;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        try {
            binding = ActivityMainBinding.inflate(getLayoutInflater());
            setContentView(binding.getRoot());
            
            applySystemBarInsets();

            initializeAuth();

            // Load the start tab BEFORE attaching the navigation listener.
            // Doing it the other way round made setSelectedItemId() fire the
            // listener and build a second HomeFragment, so every cold start ran
            // two identical listing loads over the network.
            if (savedInstanceState == null) {
                loadFragment(new HomeFragment());
                currentTabId = R.id.navigation_home;
                binding.bottomNavigation.setSelectedItemId(R.id.navigation_home);
            }

            setupBottomNavigation();

            handleNegotiatorRequest(getIntent());
        } catch (Exception e) {
            Log.e(TAG, "Error in onCreate: " + e.getMessage(), e);
            createFallbackUI();
        }
    }
    
    /**
     * Keeps content clear of the status bar and the gesture bar.
     *
     * Apps targeting SDK 35 are drawn edge to edge on Android 15 whether they
     * ask for it or not, and android:statusBarColor is ignored -- so a scrolling
     * header ran up behind the clock until the inset was applied here.
     */
    /** Tab bar height once measured, falling back to the system inset. */
    private int tabBarHeight(int fallback) {
        if (binding == null || binding.bottomNavigation == null) {
            return fallback;
        }
        int measured = binding.bottomNavigation.getHeight();
        return measured > 0 ? measured : fallback;
    }

    private void applySystemBarInsets() {
        if (binding == null) {
            return;
        }
        androidx.core.view.ViewCompat.setOnApplyWindowInsetsListener(binding.getRoot(), (view, insets) -> {
            androidx.core.graphics.Insets bars =
                    insets.getInsets(androidx.core.view.WindowInsetsCompat.Type.systemBars());
            // Bottom padding is the tab bar's own height, measured after it is
            // laid out. Without it the Post wizard's Next / Post Listing buttons
            // sat underneath the tab bar and could not be tapped at all.
            binding.fragmentContainer.setPadding(0, bars.top, 0, tabBarHeight(bars.bottom));
            binding.bottomNavigation.setPadding(
                    binding.bottomNavigation.getPaddingLeft(),
                    binding.bottomNavigation.getPaddingTop(),
                    binding.bottomNavigation.getPaddingRight(),
                    bars.bottom);
            return insets;
        });

        binding.bottomNavigation.addOnLayoutChangeListener(
                (v, l, t, r, b, ol, ot, or_, ob) -> {
                    int height = b - t;
                    if (height > 0 && binding.fragmentContainer.getPaddingBottom() != height) {
                        binding.fragmentContainer.setPadding(
                                0, binding.fragmentContainer.getPaddingTop(), 0, height);
                    }
                });
    }

    @Override
    protected void onNewIntent(android.content.Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleNegotiatorRequest(intent);
    }

    /**
     * Opens the negotiator against a specific room, with the question already
     * written. Arriving at a blank prompt after tapping "Negotiate this rent"
     * makes you do the work the button offered to do.
     */
    private void handleNegotiatorRequest(android.content.Intent intent) {
        if (intent == null || !intent.getBooleanExtra("open_negotiator", false)) {
            return;
        }
        intent.removeExtra("open_negotiator");

        String title = intent.getStringExtra("negotiate_listing_title");
        double price = intent.getDoubleExtra("negotiate_listing_price", 0);
        String location = intent.getStringExtra("negotiate_listing_location");

        StringBuilder seed = new StringBuilder("Help me negotiate the rent on ");
        seed.append(title == null || title.isEmpty() ? "this room" : title);
        if (location != null && !location.isEmpty()) {
            seed.append(" in ").append(location);
        }
        if (price > 0) {
            seed.append(String.format(java.util.Locale.US, ", listed at $%,.0f a month", price));
        }
        seed.append(".");

        AiChatFragment negotiator = new AiChatFragment();
        Bundle args = new Bundle();
        args.putString(AiChatFragment.ARG_SEED_MESSAGE, seed.toString());
        negotiator.setArguments(args);

        currentTabId = R.id.navigation_chat;
        binding.bottomNavigation.setSelectedItemId(R.id.navigation_chat);
        loadFragment(negotiator);
    }

    private void setupBottomNavigation() {
        try {
            if (binding == null || binding.bottomNavigation == null) {
                Log.e(TAG, "Binding or bottom navigation is null");
                return;
            }
            
            binding.bottomNavigation.setOnItemSelectedListener(item -> {
                try {
                    Fragment fragment = null;
                    
                    int itemId = item.getItemId();

                    // Re-tapping the tab you are already on should not rebuild
                    // the fragment (and re-run its network calls).
                    if (itemId == currentTabId
                            && getSupportFragmentManager().findFragmentById(R.id.fragmentContainer) != null) {
                        return true;
                    }

                    if (itemId == R.id.navigation_home) {
                        fragment = new HomeFragment();
                    } else if (itemId == R.id.navigation_search) {
                        // "People" on iOS: subleases and RoomPal. Student
                        // housing was removed from the site and has no iOS
                        // counterpart, so it no longer owns a tab here either.
                        fragment = new PeopleFragment();
                    } else if (itemId == R.id.navigation_post) {
                        fragment = new PostFragment();
                    } else if (itemId == R.id.navigation_chat) {
                        fragment = new ChatFragment();
                    } else if (itemId == R.id.navigation_profile) {
                        fragment = new ProfileFragment();
                    }
                    
                    if (fragment != null) {
                        boolean loaded = loadFragment(fragment);
                        if (loaded) {
                            currentTabId = itemId;
                        }
                        return loaded;
                    }
                    return false;
                } catch (Exception e) {
                    Log.e(TAG, "Error in navigation: " + e.getMessage(), e);
                    return false;
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "Error setting up bottom navigation: " + e.getMessage(), e);
        }
    }

    public void navigateToTab(@IdRes int menuItemId) {
        if (binding == null || binding.bottomNavigation == null) {
            return;
        }
        binding.bottomNavigation.setSelectedItemId(menuItemId);
    }

    public void openFragment(@NonNull Fragment fragment) {
        // A tool screen opened from Home is not a tab; forget the tab identity so
        // tapping the tab again reloads it properly.
        currentTabId = View.NO_ID;
        loadFragment(fragment);
    }
    
    private boolean loadFragment(Fragment fragment) {
        try {
            if (fragment == null) {
                Log.e(TAG, "Fragment is null");
                return false;
            }
            
            if (getSupportFragmentManager() == null) {
                Log.e(TAG, "FragmentManager is null");
                return false;
            }
            
            getSupportFragmentManager()
                    .beginTransaction()
                    .replace(R.id.fragmentContainer, fragment)
                    .commitAllowingStateLoss();
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Error loading fragment: " + e.getMessage(), e);
            return false;
        }
    }
    
    private void initializeAuth() {
        try {
            authManager = AuthManager.getInstance(this);
            
            User currentUser = authManager.getCurrentUser();
            if (currentUser != null) {
                Log.d(TAG, "Session restored for user: " + currentUser.getEmail());
            } else {
                Log.d(TAG, "No active session found");
            }
        } catch (Exception e) {
            Log.e(TAG, "Error initializing auth: " + e.getMessage(), e);
        }
    }
    
    private void createFallbackUI() {
        try {
            android.widget.LinearLayout fallbackLayout = new android.widget.LinearLayout(this);
            fallbackLayout.setOrientation(android.widget.LinearLayout.VERTICAL);
            fallbackLayout.setGravity(android.view.Gravity.CENTER);
            
            android.widget.TextView errorText = new android.widget.TextView(this);
            errorText.setText("RoomFinderAI is starting up...");
            errorText.setTextSize(18);
            errorText.setGravity(android.view.Gravity.CENTER);
            errorText.setPadding(50, 50, 50, 50);
            
            android.widget.Button retryButton = new android.widget.Button(this);
            retryButton.setText("Retry");
            retryButton.setOnClickListener(v -> recreate());
            
            fallbackLayout.addView(errorText);
            fallbackLayout.addView(retryButton);
            
            setContentView(fallbackLayout);
            
        } catch (Exception e) {
            Log.e(TAG, "Error creating fallback UI: " + e.getMessage(), e);
            finish();
        }
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        Log.d(TAG, "MainActivity resumed");
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        binding = null;
        authManager = null;
        Log.d(TAG, "MainActivity destroyed");
    }
}
