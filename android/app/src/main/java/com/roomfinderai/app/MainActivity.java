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
import com.roomfinderai.app.fragments.CategoriesFragment;
import com.roomfinderai.app.fragments.ListingsFragment;
import com.roomfinderai.app.fragments.MessagesFragment;
import com.roomfinderai.app.fragments.PostFragment;
import com.roomfinderai.app.fragments.ProfileFragment;

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
            
            int itemId = item.getItemId();
            if (itemId == R.id.navigation_home) {
                fragment = new ListingsFragment();
            } else if (itemId == R.id.navigation_categories) {
                fragment = new CategoriesFragment();
            } else if (itemId == R.id.navigation_post) {
                fragment = new PostFragment();
            } else if (itemId == R.id.navigation_messages) {
                fragment = new MessagesFragment();
            } else if (itemId == R.id.navigation_profile) {
                fragment = new ProfileFragment();
            }
            
            if (fragment != null) {
                loadFragment(fragment);
                Log.d(TAG, "Navigation: Loaded " + fragment.getClass().getSimpleName());
                return true;
            }
            return false;
        });
    }

    private void loadFragment(Fragment fragment) {
        try {
            FragmentTransaction transaction = fragmentManager.beginTransaction();
            transaction.setCustomAnimations(
                android.R.anim.fade_in,
                android.R.anim.fade_out,
                android.R.anim.fade_in,
                android.R.anim.fade_out
            );
            transaction.replace(R.id.fragmentContainer, fragment);
            transaction.commit();
            
            Log.d(TAG, "Fragment loaded: " + fragment.getClass().getSimpleName());
        } catch (Exception e) {
            Log.e(TAG, "Error loading fragment: " + e.getMessage(), e);
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