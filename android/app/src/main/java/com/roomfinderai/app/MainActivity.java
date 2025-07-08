package com.roomfinderai.app;

import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.Toast;
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

// PURE NATIVE ANDROID APP - NO WEBVIEW, NO CAPACITOR
public class MainActivity extends AppCompatActivity {
    private static final String TAG = "RoomFinderAI-NATIVE";
    
    private BottomNavigationView bottomNavigation;
    private EditText searchBar;
    private ImageButton filterButton;
    private FragmentManager fragmentManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // FORCE NATIVE LAYOUT - NO WEBVIEW
        setContentView(R.layout.activity_main);
        
        // Show a toast to confirm native app is running
        Toast.makeText(this, "NATIVE KIJIJI LAYOUT - NO WEBVIEW!", Toast.LENGTH_LONG).show();
        
        Log.d(TAG, "====================================");
        Log.d(TAG, "NATIVE ANDROID APP STARTED");
        Log.d(TAG, "NO CAPACITOR - NO WEBVIEW");
        Log.d(TAG, "PURE NATIVE UI WITH KIJIJI LAYOUT");
        Log.d(TAG, "====================================");
        
        try {
            initializeViews();
            setupBottomNavigation();
            setupSearchBar();
            
            // Load the home fragment immediately
            if (savedInstanceState == null) {
                loadFragment(new ListingsFragment());
                bottomNavigation.setSelectedItemId(R.id.navigation_home);
            }
            
            // Set window background to purple theme
            getWindow().getDecorView().setBackgroundColor(getResources().getColor(R.color.background_primary));
            
        } catch (Exception e) {
            Log.e(TAG, "Error in native app: " + e.getMessage(), e);
            Toast.makeText(this, "Native app error: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    private void initializeViews() {
        bottomNavigation = findViewById(R.id.bottomNavigation);
        searchBar = findViewById(R.id.searchBar);
        filterButton = findViewById(R.id.filterButton);
        fragmentManager = getSupportFragmentManager();
        
        // Make sure views are visible
        if (bottomNavigation != null) {
            bottomNavigation.setVisibility(View.VISIBLE);
            Log.d(TAG, "Bottom navigation initialized and visible");
        }
        
        if (searchBar != null) {
            searchBar.setVisibility(View.VISIBLE);
            searchBar.setHint("Search properties...");
            Log.d(TAG, "Search bar initialized and visible");
        }
    }

    private void setupBottomNavigation() {
        if (bottomNavigation == null) {
            Log.e(TAG, "ERROR: Bottom navigation is null!");
            return;
        }
        
        bottomNavigation.setOnNavigationItemSelectedListener(item -> {
            Fragment fragment = null;
            String fragmentName = "";
            
            int itemId = item.getItemId();
            if (itemId == R.id.navigation_home) {
                fragment = new ListingsFragment();
                fragmentName = "Home/Listings";
            } else if (itemId == R.id.navigation_categories) {
                fragment = new CategoriesFragment();
                fragmentName = "Categories";
            } else if (itemId == R.id.navigation_post) {
                fragment = new PostFragment();
                fragmentName = "Post";
            } else if (itemId == R.id.navigation_messages) {
                fragment = new MessagesFragment();
                fragmentName = "Messages";
            } else if (itemId == R.id.navigation_profile) {
                fragment = new ProfileFragment();
                fragmentName = "Profile";
            }
            
            if (fragment != null) {
                loadFragment(fragment);
                Toast.makeText(this, "Selected: " + fragmentName, Toast.LENGTH_SHORT).show();
                Log.d(TAG, "Navigation to: " + fragmentName);
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
            Log.e(TAG, "Search components not found!");
            return;
        }
        
        searchBar.setOnEditorActionListener((v, actionId, event) -> {
            String query = searchBar.getText().toString();
            performSearch(query);
            Toast.makeText(this, "Searching: " + query, Toast.LENGTH_SHORT).show();
            return true;
        });

        filterButton.setOnClickListener(v -> {
            Toast.makeText(this, "Filter clicked!", Toast.LENGTH_SHORT).show();
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
        Log.d(TAG, "Native app resumed - NO WEBVIEW");
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