package com.roomfinderai.app;

import android.os.Bundle;
import android.util.Log;
import android.widget.EditText;
import android.widget.ImageButton;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentManager;
import androidx.fragment.app.FragmentTransaction;
import com.google.android.material.bottomnavigation.BottomNavigationView;
import com.roomfinderai.app.fragments.AIChatsFragment;
import com.roomfinderai.app.fragments.DashboardFragment;
import com.roomfinderai.app.fragments.ListingsFragment;
import com.roomfinderai.app.fragments.PostFragment;
import com.roomfinderai.app.fragments.SettingsFragment;
import com.roomfinderai.app.fragments.TestApiFragment;
import com.roomfinderai.app.config.ApiConfig;

public class MainActivity extends AppCompatActivity {
    private static final String TAG = "RoomFinderAI";
    
    private BottomNavigationView bottomNavigation;
    private EditText searchBar;
    private ImageButton filterButton;
    private FragmentManager fragmentManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Force native theme and layout
        setTheme(R.style.MarketplaceTheme);
        setContentView(R.layout.activity_main);
        
        Log.d(TAG, "Native RoomFinderAI app started - NO WEBVIEW");
        
        // Initialize API configuration
        if (ApiConfig.isConfigValid()) {
            Log.d(TAG, "API configuration is valid");
        } else {
            Log.w(TAG, "API configuration is missing or invalid");
        }
        
        try {
            initializeViews();
            setupBottomNavigation();
            setupSearchBar();
            
            // Always load the listings fragment first
            if (savedInstanceState == null) {
                loadFragment(new ListingsFragment());
                // Set home as selected in bottom nav
                bottomNavigation.setSelectedItemId(R.id.navigation_home);
            }
            
            Log.d(TAG, "Native marketplace UI initialized successfully");
        } catch (Exception e) {
            Log.e(TAG, "Error initializing native UI: " + e.getMessage(), e);
            // If there's any error, show a simple message
            setTitle("RoomFinderAI - Native Mode");
        }
    }

    private void initializeViews() {
        bottomNavigation = findViewById(R.id.bottomNavigation);
        searchBar = findViewById(R.id.searchBar);
        filterButton = findViewById(R.id.filterButton);
        fragmentManager = getSupportFragmentManager();
        
        Log.d(TAG, "Views initialized - BottomNav: " + (bottomNavigation != null) + 
                  ", SearchBar: " + (searchBar != null) + 
                  ", FilterButton: " + (filterButton != null));
    }

    private void setupBottomNavigation() {
        if (bottomNavigation == null) {
            Log.e(TAG, "BottomNavigation is null!");
            return;
        }
        
        bottomNavigation.setOnNavigationItemSelectedListener(item -> {
            Fragment fragment = null;
            String tabName = "Unknown";
            
            int itemId = item.getItemId();
            Log.d(TAG, "🔄 Navigation item tapped - ID: " + itemId);
            
            if (itemId == R.id.navigation_home) {
                fragment = new ListingsFragment();
                tabName = "Home";
            } else if (itemId == R.id.navigation_ai_chats) {
                fragment = new AIChatsFragment();
                tabName = "AI Chats";
            } else if (itemId == R.id.navigation_add) {
                fragment = new PostFragment();
                tabName = "Add/Post";
            } else if (itemId == R.id.navigation_dashboard) {
                fragment = new DashboardFragment();
                tabName = "Dashboard";
            } else if (itemId == R.id.navigation_settings) {
                // Temporarily using TestApiFragment for testing
                fragment = new TestApiFragment();
                tabName = "Settings (API TEST FRAGMENT)";
                Log.d(TAG, "🧪 LOADING API TEST FRAGMENT - This should show test buttons!");
                // fragment = new SettingsFragment(); // Original settings
            }
            
            Log.d(TAG, "📱 Tab selected: " + tabName);
            
            if (fragment != null) {
                Log.d(TAG, "✅ Fragment created: " + fragment.getClass().getSimpleName());
                loadFragment(fragment);
                Log.d(TAG, "🔄 loadFragment() called for " + fragment.getClass().getSimpleName());
                return true;
            } else {
                Log.e(TAG, "❌ Fragment is NULL! Tab: " + tabName);
            }
            return false;
        });
    }

    private void loadFragment(Fragment fragment) {
        try {
            Log.d(TAG, "🔄 loadFragment() starting for: " + fragment.getClass().getSimpleName());
            Log.d(TAG, "📦 Fragment container ID: R.id.fragmentContainer");
            
            FragmentTransaction transaction = fragmentManager.beginTransaction();
            transaction.setCustomAnimations(
                android.R.anim.fade_in,
                android.R.anim.fade_out,
                android.R.anim.fade_in,
                android.R.anim.fade_out
            );
            transaction.replace(R.id.fragmentContainer, fragment);
            transaction.commit();
            
            Log.d(TAG, "✅ Fragment transaction committed successfully: " + fragment.getClass().getSimpleName());
            
            if (fragment instanceof com.roomfinderai.app.fragments.TestApiFragment) {
                Log.d(TAG, "🧪🧪🧪 API TEST FRAGMENT LOADED! You should see test buttons now! 🧪🧪🧪");
            }
            
        } catch (Exception e) {
            Log.e(TAG, "❌ Error loading fragment: " + e.getMessage(), e);
        }
    }

    private void setupSearchBar() {
        if (searchBar == null || filterButton == null) {
            Log.e(TAG, "SearchBar or FilterButton is null!");
            return;
        }
        
        searchBar.setOnEditorActionListener((v, actionId, event) -> {
            String query = searchBar.getText().toString();
            performSearch(query);
            return true;
        });

        filterButton.setOnClickListener(v -> {
            showFilterDialog();
        });
    }

    private void performSearch(String query) {
        Fragment currentFragment = fragmentManager.findFragmentById(R.id.fragmentContainer);
        if (currentFragment instanceof ListingsFragment) {
            ((ListingsFragment) currentFragment).searchListings(query);
        }
        Log.d(TAG, "Search performed: " + query);
    }

    private void showFilterDialog() {
        Log.d(TAG, "Filter dialog requested");
        // TODO: Implement filter dialog
    }
    
    @Override
    public void onResume() {
        super.onResume();
        Log.d(TAG, "Native app resumed");
    }
    
    @Override
    public void onPause() {
        super.onPause();
        Log.d(TAG, "Native app paused");
    }

    @Override
    public void onBackPressed() {
        if (fragmentManager.getBackStackEntryCount() > 0) {
            fragmentManager.popBackStack();
        } else {
            super.onBackPressed();
        }
    }
}