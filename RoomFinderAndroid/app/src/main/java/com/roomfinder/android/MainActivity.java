package com.roomfinder.android;

import android.os.Bundle;
import android.util.Log;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;
import com.google.android.material.bottomnavigation.BottomNavigationView;
import com.roomfinder.android.auth.SupabaseAuthService;
import com.roomfinder.android.databinding.ActivityMainBinding;
import com.roomfinder.android.fragments.*;
import com.roomfinder.android.models.User;

public class MainActivity extends AppCompatActivity {
    
    private static final String TAG = "MainActivity";
    private ActivityMainBinding binding;
    private SupabaseAuthService authService;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        binding = ActivityMainBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        
        // Initialize authentication service for session restoration
        initializeAuth();
        
        setupBottomNavigation();
        
        // Load default fragment
        if (savedInstanceState == null) {
            loadFragment(new HomeFragment());
        }
    }
    
    private void setupBottomNavigation() {
        binding.bottomNavigation.setOnItemSelectedListener(item -> {
            Fragment fragment = null;
            
            int itemId = item.getItemId();
            if (itemId == R.id.navigation_home) {
                fragment = new HomeFragment();
            } else if (itemId == R.id.navigation_search) {
                fragment = new SearchFragment();
            } else if (itemId == R.id.navigation_post) {
                fragment = new PostFragment();
            } else if (itemId == R.id.navigation_favorites) {
                fragment = new FavoritesFragment();
            } else if (itemId == R.id.navigation_profile) {
                fragment = new ProfileFragment();
            }
            
            if (fragment != null) {
                loadFragment(fragment);
                return true;
            }
            return false;
        });
    }
    
    private void loadFragment(Fragment fragment) {
        getSupportFragmentManager()
                .beginTransaction()
                .replace(R.id.fragmentContainer, fragment)
                .commit();
    }
    
    private void initializeAuth() {
        // Initialize auth service (this will automatically restore session if available)
        authService = SupabaseAuthService.getInstance(this);
        
        User currentUser = authService.getCurrentUser();
        if (currentUser != null) {
            Log.d(TAG, "Session restored for user: " + currentUser.getEmail());
        } else {
            Log.d(TAG, "No active session found");
        }
    }
}