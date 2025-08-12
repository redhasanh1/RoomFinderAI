package com.roomfinder.android;

import android.os.Bundle;
import android.util.Log;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;
import com.google.android.material.bottomnavigation.BottomNavigationView;
import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.databinding.ActivityMainBinding;
import com.roomfinder.android.fragments.*;
import com.roomfinder.android.models.User;

public class MainActivity extends AppCompatActivity {
    
    private static final String TAG = "MainActivity";
    private ActivityMainBinding binding;
    private AuthManager authManager;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        try {
            binding = ActivityMainBinding.inflate(getLayoutInflater());
            setContentView(binding.getRoot());
            
            // Initialize authentication service for session restoration
            initializeAuth();
            
            setupBottomNavigation();
            
            // Load default fragment
            if (savedInstanceState == null) {
                loadFragment(new HomeFragment());
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in onCreate: " + e.getMessage(), e);
            // Create fallback minimal UI
            createFallbackUI();
        }
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
                    if (itemId == R.id.navigation_home) {
                        fragment = new HomeFragment();
                    } else if (itemId == R.id.navigation_search) {
                        fragment = new SearchFragment();
                    } else if (itemId == R.id.navigation_post) {
                        fragment = new PostFragment();
                    } else if (itemId == R.id.navigation_chat) {
                        fragment = new ChatFragment();
                    } else if (itemId == R.id.navigation_profile) {
                        fragment = new ProfileFragment();
                    }
                    
                    if (fragment != null) {
                        return loadFragment(fragment);
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
                    .commitAllowingStateLoss(); // Use commitAllowingStateLoss to prevent crashes
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Error loading fragment: " + e.getMessage(), e);
            return false;
        }
    }
    
    private void initializeAuth() {
        try {
            // Initialize auth manager (this will automatically restore session if available)
            authManager = AuthManager.getInstance(this);
            
            User currentUser = authManager.getCurrentUser();
            if (currentUser != null) {
                Log.d(TAG, "Session restored for user: " + currentUser.getEmail());
            } else {
                Log.d(TAG, "No active session found");
            }
        } catch (Exception e) {
            Log.e(TAG, "Error initializing auth: " + e.getMessage(), e);
            // Continue without auth if there's an error
        }
    }
    
    private void createFallbackUI() {
        try {
            // Create a simple fallback UI if the main UI fails to load
            android.widget.LinearLayout fallbackLayout = new android.widget.LinearLayout(this);
            fallbackLayout.setOrientation(android.widget.LinearLayout.VERTICAL);
            fallbackLayout.setGravity(android.view.Gravity.CENTER);
            
            android.widget.TextView errorText = new android.widget.TextView(this);
            errorText.setText("RoomFinder is starting up...");
            errorText.setTextSize(18);
            errorText.setGravity(android.view.Gravity.CENTER);
            errorText.setPadding(50, 50, 50, 50);
            
            android.widget.Button retryButton = new android.widget.Button(this);
            retryButton.setText("Retry");
            retryButton.setOnClickListener(v -> {
                // Restart the activity
                recreate();
            });
            
            fallbackLayout.addView(errorText);
            fallbackLayout.addView(retryButton);
            
            setContentView(fallbackLayout);
            
        } catch (Exception e) {
            Log.e(TAG, "Error creating fallback UI: " + e.getMessage(), e);
            // Last resort - just finish the activity
            finish();
        }
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        try {
            Log.d(TAG, "MainActivity resumed");
        } catch (Exception e) {
            Log.e(TAG, "Error in onResume: " + e.getMessage(), e);
        }
    }
    
    @Override
    protected void onPause() {
        super.onPause();
        try {
            Log.d(TAG, "MainActivity paused");
        } catch (Exception e) {
            Log.e(TAG, "Error in onPause: " + e.getMessage(), e);
        }
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        try {
            // Clean up resources
            binding = null;
            authManager = null;
            Log.d(TAG, "MainActivity destroyed");
        } catch (Exception e) {
            Log.e(TAG, "Error in onDestroy: " + e.getMessage(), e);
        }
    }
}