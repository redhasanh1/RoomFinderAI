package com.roomfinderai.app.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.LinearLayout;
import android.widget.Toast;
import androidx.fragment.app.Fragment;
import androidx.appcompat.app.AlertDialog;
import com.roomfinderai.app.R;

public class SettingsFragment extends Fragment {
    
    private LinearLayout profileSection;
    private LinearLayout themeSection;
    private LinearLayout locationSection;
    private LinearLayout notificationSection;
    private LinearLayout privacySection;
    private LinearLayout aboutSection;
    private LinearLayout logoutSection;
    
    private Switch notificationSwitch;
    private Switch darkModeSwitch;
    private TextView currentLocationText;
    private TextView profileNameText;
    private TextView profileEmailText;
    
    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_settings, container, false);
        
        initializeViews(view);
        setupClickListeners();
        loadUserPreferences();
        
        return view;
    }
    
    private void initializeViews(View view) {
        // Sections
        profileSection = view.findViewById(R.id.profileSection);
        themeSection = view.findViewById(R.id.themeSection);
        locationSection = view.findViewById(R.id.locationSection);
        notificationSection = view.findViewById(R.id.notificationSection);
        privacySection = view.findViewById(R.id.privacySection);
        aboutSection = view.findViewById(R.id.aboutSection);
        logoutSection = view.findViewById(R.id.logoutSection);
        
        // Switches
        notificationSwitch = view.findViewById(R.id.notificationSwitch);
        darkModeSwitch = view.findViewById(R.id.darkModeSwitch);
        
        // Text views
        currentLocationText = view.findViewById(R.id.currentLocationText);
        profileNameText = view.findViewById(R.id.profileNameText);
        profileEmailText = view.findViewById(R.id.profileEmailText);
    }
    
    private void setupClickListeners() {
        profileSection.setOnClickListener(v -> openProfileSettings());
        themeSection.setOnClickListener(v -> toggleTheme());
        locationSection.setOnClickListener(v -> openLocationSettings());
        notificationSection.setOnClickListener(v -> toggleNotifications());
        privacySection.setOnClickListener(v -> openPrivacySettings());
        aboutSection.setOnClickListener(v -> showAboutDialog());
        logoutSection.setOnClickListener(v -> showLogoutConfirmation());
        
        // Switch listeners
        darkModeSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            applyTheme(isChecked);
        });
        
        notificationSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            saveNotificationPreference(isChecked);
        });
    }
    
    private void loadUserPreferences() {
        // Load user data (replace with actual data from preferences/database)
        profileNameText.setText("John Doe");
        profileEmailText.setText("john.doe@example.com");
        currentLocationText.setText("Toronto, ON");
        
        // Load preferences
        darkModeSwitch.setChecked(false); // Load from SharedPreferences
        notificationSwitch.setChecked(true); // Load from SharedPreferences
    }
    
    private void openProfileSettings() {
        // Create a dialog or navigate to profile edit fragment
        AlertDialog.Builder builder = new AlertDialog.Builder(getContext());
        builder.setTitle("Profile Settings");
        
        View dialogView = LayoutInflater.from(getContext()).inflate(R.layout.dialog_profile_edit, null);
        builder.setView(dialogView);
        
        builder.setPositiveButton("Save", (dialog, which) -> {
            // Save profile changes
            Toast.makeText(getContext(), "Profile updated", Toast.LENGTH_SHORT).show();
        });
        
        builder.setNegativeButton("Cancel", null);
        builder.show();
    }
    
    private void toggleTheme() {
        darkModeSwitch.setChecked(!darkModeSwitch.isChecked());
    }
    
    private void applyTheme(boolean isDarkMode) {
        if (isDarkMode) {
            // Apply dark theme
            getActivity().setTheme(R.style.MarketplaceTheme_Dark);
            Toast.makeText(getContext(), "Dark mode enabled", Toast.LENGTH_SHORT).show();
        } else {
            // Apply light theme
            getActivity().setTheme(R.style.MarketplaceTheme);
            Toast.makeText(getContext(), "Light mode enabled", Toast.LENGTH_SHORT).show();
        }
        // Save preference
        // getActivity().recreate(); // Uncomment to restart activity with new theme
    }
    
    private void openLocationSettings() {
        String[] locations = {"Toronto, ON", "Vancouver, BC", "Montreal, QC", "Calgary, AB", "Ottawa, ON"};
        
        AlertDialog.Builder builder = new AlertDialog.Builder(getContext());
        builder.setTitle("Select Location");
        builder.setItems(locations, (dialog, which) -> {
            currentLocationText.setText(locations[which]);
            Toast.makeText(getContext(), "Location changed to " + locations[which], Toast.LENGTH_SHORT).show();
        });
        builder.show();
    }
    
    private void toggleNotifications() {
        notificationSwitch.setChecked(!notificationSwitch.isChecked());
    }
    
    private void saveNotificationPreference(boolean enabled) {
        // Save to SharedPreferences
        String message = enabled ? "Notifications enabled" : "Notifications disabled";
        Toast.makeText(getContext(), message, Toast.LENGTH_SHORT).show();
    }
    
    private void openPrivacySettings() {
        AlertDialog.Builder builder = new AlertDialog.Builder(getContext());
        builder.setTitle("Privacy Settings");
        
        String[] privacyOptions = {
            "Profile Visibility",
            "Show Contact Info",
            "Activity Status",
            "Data Sharing"
        };
        
        boolean[] checkedItems = {true, false, true, false}; // Default values
        
        builder.setMultiChoiceItems(privacyOptions, checkedItems, (dialog, which, isChecked) -> {
            // Handle privacy setting changes
        });
        
        builder.setPositiveButton("Save", (dialog, which) -> {
            Toast.makeText(getContext(), "Privacy settings updated", Toast.LENGTH_SHORT).show();
        });
        
        builder.setNegativeButton("Cancel", null);
        builder.show();
    }
    
    private void showAboutDialog() {
        AlertDialog.Builder builder = new AlertDialog.Builder(getContext());
        builder.setTitle("About RoomFinder AI");
        builder.setMessage("RoomFinder AI v1.0.0\n\n" +
                "Your intelligent room finding assistant\n\n" +
                "© 2024 RoomFinder AI\n" +
                "All rights reserved");
        builder.setPositiveButton("OK", null);
        builder.show();
    }
    
    private void showLogoutConfirmation() {
        AlertDialog.Builder builder = new AlertDialog.Builder(getContext());
        builder.setTitle("Logout");
        builder.setMessage("Are you sure you want to logout?");
        builder.setPositiveButton("Logout", (dialog, which) -> {
            // Perform logout
            Toast.makeText(getContext(), "Logged out successfully", Toast.LENGTH_SHORT).show();
            // Navigate to login screen
        });
        builder.setNegativeButton("Cancel", null);
        builder.show();
    }
}