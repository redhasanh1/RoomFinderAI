package com.roomfinder.android.fragments;

import android.content.Intent;
import android.os.AsyncTask;
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
import com.google.android.material.textfield.TextInputEditText;
import com.roomfinder.android.R;
import com.roomfinder.android.data.StateRightsData;

public class IssueAnalyzerFragment extends Fragment {

    // UI Components
    // Issue category buttons
    private MaterialButton rentIssuesBtn;
    private MaterialButton repairsBtn;
    private MaterialButton evictionBtn;
    
    // Urgency level buttons
    private MaterialButton lowUrgencyBtn;
    private MaterialButton mediumUrgencyBtn;
    private MaterialButton highUrgencyBtn;
    
    // Input fields
    private TextInputEditText issueDescriptionInput;
    private TextInputEditText locationInput;
    private MaterialButton analyzeIssueButton;
    
    // Results section
    private LinearLayout analysisResultsSection;
    private TextView urgencyBadge;
    private TextView issueSummary;
    private TextView recommendationsText;
    private MaterialButton newAnalysisButton;
    private MaterialButton shareAnalysisButton;
    
    // State
    private enum IssueCategory { RENT_ISSUES, REPAIRS, EVICTION }
    private enum UrgencyLevel { LOW, MEDIUM, HIGH }
    
    private IssueCategory selectedCategory = IssueCategory.RENT_ISSUES;
    private UrgencyLevel selectedUrgency = UrgencyLevel.LOW;
    private String currentAnalysis;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_issue_analyzer, container, false);
        
        initializeViews(view);
        setupButtonListeners();
        updateCategorySelection();
        updateUrgencySelection();
        
        return view;
    }

    private void initializeViews(View view) {
        // Category buttons
        rentIssuesBtn = view.findViewById(R.id.rentIssuesBtn);
        repairsBtn = view.findViewById(R.id.repairsBtn);
        evictionBtn = view.findViewById(R.id.evictionBtn);
        
        // Urgency buttons
        lowUrgencyBtn = view.findViewById(R.id.lowUrgencyBtn);
        mediumUrgencyBtn = view.findViewById(R.id.mediumUrgencyBtn);
        highUrgencyBtn = view.findViewById(R.id.highUrgencyBtn);
        
        // Input fields
        issueDescriptionInput = view.findViewById(R.id.issueDescriptionInput);
        locationInput = view.findViewById(R.id.locationInput);
        analyzeIssueButton = view.findViewById(R.id.analyzeIssueButton);
        
        // Results section
        analysisResultsSection = view.findViewById(R.id.analysisResultsSection);
        urgencyBadge = view.findViewById(R.id.urgencyBadge);
        issueSummary = view.findViewById(R.id.issueSummary);
        recommendationsText = view.findViewById(R.id.recommendationsText);
        newAnalysisButton = view.findViewById(R.id.newAnalysisButton);
        shareAnalysisButton = view.findViewById(R.id.shareAnalysisButton);
    }

    private void setupButtonListeners() {
        // Category selection
        rentIssuesBtn.setOnClickListener(v -> {
            selectedCategory = IssueCategory.RENT_ISSUES;
            updateCategorySelection();
        });
        
        repairsBtn.setOnClickListener(v -> {
            selectedCategory = IssueCategory.REPAIRS;
            updateCategorySelection();
        });
        
        evictionBtn.setOnClickListener(v -> {
            selectedCategory = IssueCategory.EVICTION;
            updateCategorySelection();
        });
        
        // Urgency selection
        lowUrgencyBtn.setOnClickListener(v -> {
            selectedUrgency = UrgencyLevel.LOW;
            updateUrgencySelection();
        });
        
        mediumUrgencyBtn.setOnClickListener(v -> {
            selectedUrgency = UrgencyLevel.MEDIUM;
            updateUrgencySelection();
        });
        
        highUrgencyBtn.setOnClickListener(v -> {
            selectedUrgency = UrgencyLevel.HIGH;
            updateUrgencySelection();
        });
        
        // Analysis
        analyzeIssueButton.setOnClickListener(v -> analyzeIssue());
        
        // Results actions
        newAnalysisButton.setOnClickListener(v -> startNewAnalysis());
        shareAnalysisButton.setOnClickListener(v -> shareAnalysis());
    }

    private void updateCategorySelection() {
        // Reset all category buttons
        rentIssuesBtn.setBackgroundTintList(getResources().getColorStateList(R.color.gray_100, null));
        rentIssuesBtn.setTextColor(getResources().getColor(R.color.text_primary, null));
        repairsBtn.setBackgroundTintList(getResources().getColorStateList(R.color.gray_100, null));
        repairsBtn.setTextColor(getResources().getColor(R.color.text_primary, null));
        evictionBtn.setBackgroundTintList(getResources().getColorStateList(R.color.gray_100, null));
        evictionBtn.setTextColor(getResources().getColor(R.color.text_primary, null));
        
        // Highlight selected button
        MaterialButton selectedButton = null;
        int selectedColor = R.color.error;
        
        switch (selectedCategory) {
            case RENT_ISSUES:
                selectedButton = rentIssuesBtn;
                selectedColor = R.color.error;
                break;
            case REPAIRS:
                selectedButton = repairsBtn;
                selectedColor = R.color.purple_primary;
                break;
            case EVICTION:
                selectedButton = evictionBtn;
                selectedColor = R.color.error;
                break;
        }
        
        if (selectedButton != null) {
            selectedButton.setBackgroundTintList(getResources().getColorStateList(selectedColor, null));
            selectedButton.setTextColor(getResources().getColor(R.color.white, null));
        }
    }

    private void updateUrgencySelection() {
        // Reset all urgency buttons
        lowUrgencyBtn.setBackgroundTintList(getResources().getColorStateList(R.color.gray_100, null));
        lowUrgencyBtn.setTextColor(getResources().getColor(R.color.text_primary, null));
        mediumUrgencyBtn.setBackgroundTintList(getResources().getColorStateList(R.color.gray_100, null));
        mediumUrgencyBtn.setTextColor(getResources().getColor(R.color.text_primary, null));
        highUrgencyBtn.setBackgroundTintList(getResources().getColorStateList(R.color.gray_100, null));
        highUrgencyBtn.setTextColor(getResources().getColor(R.color.text_primary, null));
        
        // Highlight selected button
        MaterialButton selectedButton = null;
        int selectedColor = R.color.success;
        
        switch (selectedUrgency) {
            case LOW:
                selectedButton = lowUrgencyBtn;
                selectedColor = R.color.success;
                break;
            case MEDIUM:
                selectedButton = mediumUrgencyBtn;
                selectedColor = R.color.blue_accent;
                break;
            case HIGH:
                selectedButton = highUrgencyBtn;
                selectedColor = R.color.error;
                break;
        }
        
        if (selectedButton != null) {
            selectedButton.setBackgroundTintList(getResources().getColorStateList(selectedColor, null));
            selectedButton.setTextColor(getResources().getColor(R.color.white, null));
        }
    }

    private void analyzeIssue() {
        String description = issueDescriptionInput.getText().toString().trim();
        String location = locationInput.getText().toString().trim();
        
        if (description.isEmpty()) {
            showError("Please describe your legal issue");
            return;
        }
        
        if (location.isEmpty()) {
            showError("Please enter your state/city");
            return;
        }
        
        // Perform analysis in background to avoid ANR
        new IssueAnalysisTask().execute(description, location);
    }

    private class IssueAnalysisTask extends AsyncTask<String, Void, String[]> {
        
        @Override
        protected String[] doInBackground(String... params) {
            try {
                String description = params[0];
                String location = params[1];
                
                // Simulate AI analysis - in a real app, this would call an AI service
                Thread.sleep(1000); // Simulate processing time
                
                String summary = generateIssueSummary(description, location);
                String recommendations = generateRecommendations(description, location);
                
                return new String[]{summary, recommendations};
                
            } catch (Exception e) {
                return new String[]{"Analysis failed: " + e.getMessage(), ""};
            }
        }
        
        @Override
        protected void onPostExecute(String[] results) {
            if (results != null && results.length >= 2) {
                displayAnalysisResults(results[0], results[1]);
            } else {
                showError("Analysis failed");
            }
        }
    }

    private String generateIssueSummary(String description, String location) {
        StringBuilder summary = new StringBuilder();
        
        summary.append("Based on your description, this appears to be a ");
        
        switch (selectedCategory) {
            case RENT_ISSUES:
                summary.append("rent payment or rent-related dispute");
                break;
            case REPAIRS:
                summary.append("property maintenance or repair issue");
                break;
            case EVICTION:
                summary.append("potential eviction or lease termination matter");
                break;
        }
        
        summary.append(" that ");
        
        switch (selectedUrgency) {
            case LOW:
                summary.append("requires attention but is not immediately urgent");
                break;
            case MEDIUM:
                summary.append("requires prompt attention within the next few days");
                break;
            case HIGH:
                summary.append("requires immediate attention and action");
                break;
        }
        
        summary.append(". Your rights in ").append(location).append(" include specific protections that may apply to your situation.");
        
        return summary.toString();
    }

    private String generateRecommendations(String description, String location) {
        StringBuilder recommendations = new StringBuilder();
        
        // Get state-specific information
        try {
            StateRightsData.TenantRightsInfo rightsInfo = StateRightsData.getRightsForState(location);
            
            recommendations.append("1. Document everything in writing\n\n");
            recommendations.append("2. Review your lease agreement for specific clauses\n\n");
            recommendations.append("3. Check ").append(location).append(" tenant rights regarding ");
            
            switch (selectedCategory) {
                case RENT_ISSUES:
                    recommendations.append("rent payment disputes\n\n");
                    break;
                case REPAIRS:
                    recommendations.append("maintenance and habitability issues\n\n");
                    break;
                case EVICTION:
                    recommendations.append("eviction protection and notice requirements\n\n");
                    break;
            }
            
            if (selectedUrgency == UrgencyLevel.HIGH) {
                recommendations.append("4. URGENT: Contact a tenant's rights organization immediately\n\n");
                recommendations.append("5. Consider emergency legal assistance if facing immediate eviction\n\n");
            } else {
                recommendations.append("4. Consider contacting a tenant's rights organization\n\n");
                recommendations.append("5. If needed, consult with a qualified attorney\n\n");
            }
            
            recommendations.append("6. Keep all communications with your landlord in writing");
            
        } catch (Exception e) {
            // Fallback recommendations
            recommendations.append("1. Document everything in writing\n");
            recommendations.append("2. Review your lease agreement\n");
            recommendations.append("3. Contact local tenant rights organizations\n");
            recommendations.append("4. Consider legal consultation if needed");
        }
        
        return recommendations.toString();
    }

    private void displayAnalysisResults(String summary, String recommendations) {
        // Update urgency badge
        String urgencyText = selectedUrgency.toString() + " URGENCY";
        int urgencyColor;
        
        switch (selectedUrgency) {
            case LOW:
                urgencyColor = R.color.success;
                break;
            case MEDIUM:
                urgencyColor = R.color.blue_accent;
                break;
            case HIGH:
                urgencyColor = R.color.error;
                break;
            default:
                urgencyColor = R.color.success;
                break;
        }
        
        urgencyBadge.setText(urgencyText);
        urgencyBadge.setTextColor(getResources().getColor(urgencyColor, null));
        urgencyBadge.setBackgroundTintList(getResources().getColorStateList(urgencyColor, null));
        urgencyBadge.getBackground().setAlpha(30); // Light background
        
        // Update content
        issueSummary.setText(summary);
        recommendationsText.setText(recommendations);
        
        // Store current analysis for sharing
        currentAnalysis = "Issue Analysis:\n\n" + summary + "\n\nRecommended Actions:\n" + recommendations;
        
        // Show results section
        analysisResultsSection.setVisibility(View.VISIBLE);
        
        if (getContext() != null) {
            Toast.makeText(getContext(), "Analysis complete!", Toast.LENGTH_SHORT).show();
        }
    }

    private void startNewAnalysis() {
        // Clear inputs and hide results
        issueDescriptionInput.setText("");
        locationInput.setText("California");
        analysisResultsSection.setVisibility(View.GONE);
        currentAnalysis = null;
        
        // Reset selections
        selectedCategory = IssueCategory.RENT_ISSUES;
        selectedUrgency = UrgencyLevel.LOW;
        updateCategorySelection();
        updateUrgencySelection();
    }

    private void shareAnalysis() {
        if (currentAnalysis == null) {
            showError("Please complete an analysis first");
            return;
        }
        
        try {
            String shareText = currentAnalysis + "\n\nGenerated with RoomFinder Legal Tools";

            Intent shareIntent = new Intent(Intent.ACTION_SEND);
            shareIntent.setType("text/plain");
            shareIntent.putExtra(Intent.EXTRA_TEXT, shareText);
            shareIntent.putExtra(Intent.EXTRA_SUBJECT, "Legal Issue Analysis");
            
            startActivity(Intent.createChooser(shareIntent, "Share Analysis"));

        } catch (Exception e) {
            showError("Error sharing analysis: " + e.getMessage());
        }
    }

    private void showError(String message) {
        if (getContext() != null) {
            Toast.makeText(getContext(), message, Toast.LENGTH_SHORT).show();
        }
    }
}