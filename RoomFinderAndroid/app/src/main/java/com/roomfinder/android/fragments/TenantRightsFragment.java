package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.card.MaterialCardView;
import com.google.android.material.textfield.TextInputEditText;
import com.roomfinder.android.R;
import com.roomfinder.android.data.StateRightsData;
import com.roomfinder.android.data.StateRightsData.TenantRightsInfo;

public class TenantRightsFragment extends Fragment {

    // UI Components
    private TextInputEditText stateSelector;
    private MaterialButton loadRightsButton;
    
    // Rights category cards
    private LinearLayout rightsSection;
    private MaterialCardView securityDepositCard;
    private MaterialCardView rentControlCard;
    private MaterialCardView repairsMaintenanceCard;
    private MaterialCardView evictionProtectionCard;
    
    // Rights detail section
    private LinearLayout rightsDetailSection;
    private TextView rightsTitle;
    private TextView rightsContent;
    private MaterialButton backToRightsButton;
    
    // State
    private TenantRightsInfo currentRightsInfo;
    private String currentState = "California";

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_tenant_rights, container, false);
        
        initializeViews(view);
        setupButtonListeners();
        
        // Load default state (California)
        loadRightsForState(currentState);
        
        return view;
    }

    private void initializeViews(View view) {
        stateSelector = view.findViewById(R.id.stateSelector);
        loadRightsButton = view.findViewById(R.id.loadRightsButton);
        
        // Rights sections
        rightsSection = view.findViewById(R.id.rightsSection);
        securityDepositCard = view.findViewById(R.id.securityDepositCard);
        rentControlCard = view.findViewById(R.id.rentControlCard);
        repairsMaintenanceCard = view.findViewById(R.id.repairsMaintenanceCard);
        evictionProtectionCard = view.findViewById(R.id.evictionProtectionCard);
        
        // Detail section
        rightsDetailSection = view.findViewById(R.id.rightsDetailSection);
        rightsTitle = view.findViewById(R.id.rightsTitle);
        rightsContent = view.findViewById(R.id.rightsContent);
        backToRightsButton = view.findViewById(R.id.backToRightsButton);
        
        // Set default state
        stateSelector.setText(currentState);
    }

    private void setupButtonListeners() {
        // Load rights button
        loadRightsButton.setOnClickListener(v -> {
            String selectedState = stateSelector.getText().toString().trim();
            if (!selectedState.isEmpty()) {
                currentState = selectedState;
                loadRightsForState(currentState);
            } else {
                showError("Please enter a state name");
            }
        });
        
        // Rights category cards
        securityDepositCard.setOnClickListener(v -> 
            showRightsDetail("Security Deposit Rights", currentRightsInfo.getSecurityDepositRights()));
        
        rentControlCard.setOnClickListener(v -> 
            showRightsDetail("Rent Increase Rights", currentRightsInfo.getRentIncreaseRights()));
        
        repairsMaintenanceCard.setOnClickListener(v -> 
            showRightsDetail("Repairs & Maintenance Rights", currentRightsInfo.getRepairMaintenanceRights()));
        
        evictionProtectionCard.setOnClickListener(v -> 
            showRightsDetail("Eviction Protection Rights", currentRightsInfo.getEvictionProtectionRights()));
        
        // Back button
        backToRightsButton.setOnClickListener(v -> showRightsOverview());
    }

    private void loadRightsForState(String state) {
        try {
            // Get rights information for the state
            currentRightsInfo = StateRightsData.getRightsForState(state);
            
            if (currentRightsInfo != null) {
                // Show success message
                String message = StateRightsData.hasStateData(state) ? 
                    "Loaded detailed rights for " + state :
                    "Loaded general rights information for " + state;
                
                if (getContext() != null) {
                    Toast.makeText(getContext(), message, Toast.LENGTH_SHORT).show();
                }
                
                // Update the state selector to show the loaded state
                stateSelector.setText(currentRightsInfo.getState());
                
                // Show rights overview
                showRightsOverview();
                
            } else {
                showError("Unable to load rights information for " + state);
            }
            
        } catch (Exception e) {
            showError("Error loading rights: " + e.getMessage());
        }
    }

    private void showRightsOverview() {
        if (currentRightsInfo == null) return;
        
        // Hide detail section, show overview
        rightsDetailSection.setVisibility(View.GONE);
        rightsSection.setVisibility(View.VISIBLE);
        
        // Update cards to show they're clickable
        enableRightsCards(true);
    }

    private void showRightsDetail(String title, String content) {
        if (currentRightsInfo == null || content == null || content.isEmpty()) {
            showError("No detailed information available");
            return;
        }
        
        // Update detail content
        rightsTitle.setText(title);
        rightsContent.setText(content);
        
        // Hide overview, show detail
        rightsSection.setVisibility(View.GONE);
        rightsDetailSection.setVisibility(View.VISIBLE);
    }

    private void enableRightsCards(boolean enabled) {
        if (currentRightsInfo == null) return;
        
        float alpha = enabled ? 1.0f : 0.5f;
        securityDepositCard.setAlpha(alpha);
        rentControlCard.setAlpha(alpha);
        repairsMaintenanceCard.setAlpha(alpha);
        evictionProtectionCard.setAlpha(alpha);
        
        securityDepositCard.setClickable(enabled);
        rentControlCard.setClickable(enabled);
        repairsMaintenanceCard.setClickable(enabled);
        evictionProtectionCard.setClickable(enabled);
    }

    private void showError(String message) {
        if (getContext() != null) {
            Toast.makeText(getContext(), message, Toast.LENGTH_SHORT).show();
        }
    }
}