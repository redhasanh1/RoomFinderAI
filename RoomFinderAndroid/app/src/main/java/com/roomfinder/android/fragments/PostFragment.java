package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import com.google.android.material.chip.Chip;
import com.roomfinder.android.databinding.FragmentPostBinding;

public class PostFragment extends Fragment {
    
    private FragmentPostBinding binding;
    private int currentStep = 1;
    private final int TOTAL_STEPS = 4;
    
    // Form data
    private String selectedPropertyType = "";
    private String selectedBedrooms = "";
    private String selectedBathrooms = "";
    private int photoCount = 0;
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentPostBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        setupStepNavigation();
        setupFormValidation();
        setupPropertyTypeSelection();
        setupBedroomBathroomSelection();
        setupPhotoUpload();
        updateStepUI();
    }
    
    private void setupStepNavigation() {
        binding.previousButton.setOnClickListener(v -> {
            if (currentStep > 1) {
                currentStep--;
                updateStepUI();
            }
        });
        
        binding.nextButton.setOnClickListener(v -> {
            if (validateCurrentStep()) {
                if (currentStep < TOTAL_STEPS) {
                    currentStep++;
                    updateStepUI();
                }
            }
        });
        
        binding.postButton.setOnClickListener(v -> {
            if (validateAllSteps()) {
                submitListing();
            }
        });
    }
    
    private void updateStepUI() {
        // Update progress indicator
        binding.stepIndicator.setText("Step " + currentStep + " of " + TOTAL_STEPS);
        int progress = (currentStep * 100) / TOTAL_STEPS;
        binding.progressBar.setProgress(progress);
        binding.completionPercentage.setText(progress + "% Complete");
        
        // Update step title and description
        String[] stepTitles = {"Basic Information", "Property Details", "Photos", "Review"};
        String[] stepDescriptions = {
            "Tell us about your property",
            "Add bedrooms, bathrooms, and description", 
            "Upload photos of your property",
            "Review and publish your listing"
        };
        
        binding.stepTitle.setText(stepTitles[currentStep - 1]);
        binding.stepDescription.setText(stepDescriptions[currentStep - 1]);
        
        // Show/hide step containers
        binding.step1Container.setVisibility(currentStep == 1 ? View.VISIBLE : View.GONE);
        binding.step2Container.setVisibility(currentStep == 2 ? View.VISIBLE : View.GONE);
        binding.step3Container.setVisibility(currentStep == 3 ? View.VISIBLE : View.GONE);
        binding.step4Container.setVisibility(currentStep == 4 ? View.VISIBLE : View.GONE);
        
        // Update navigation buttons
        binding.previousButton.setVisibility(currentStep > 1 ? View.VISIBLE : View.GONE);
        
        if (currentStep < TOTAL_STEPS) {
            binding.nextButton.setVisibility(View.VISIBLE);
            binding.postButton.setVisibility(View.GONE);
            
            String[] nextButtonTexts = {
                "Next: Property Details",
                "Next: Add Photos", 
                "Next: Review"
            };
            binding.nextButton.setText(nextButtonTexts[currentStep - 1]);
        } else {
            binding.nextButton.setVisibility(View.GONE);
            binding.postButton.setVisibility(View.VISIBLE);
        }
        
        // Update preview in step 4
        if (currentStep == 4) {
            updatePreview();
        }
    }
    
    private void setupPropertyTypeSelection() {
        binding.propertyTypeChipGroup.setOnCheckedStateChangeListener((group, checkedIds) -> {
            if (!checkedIds.isEmpty()) {
                Chip selectedChip = group.findViewById(checkedIds.get(0));
                if (selectedChip != null) {
                    String chipText = selectedChip.getText().toString().toLowerCase();
                    // Remove emoji from property type and set selectedPropertyType
                    if (chipText.contains("apartment")) selectedPropertyType = "apartment";
                    else if (chipText.contains("house")) selectedPropertyType = "house";
                    else if (chipText.contains("condo")) selectedPropertyType = "condo";
                    else if (chipText.contains("studio")) selectedPropertyType = "studio";
                    else {
                        // Fallback: use the chip text directly (cleaned)
                        selectedPropertyType = chipText.replaceAll("[^a-zA-Z]", "").toLowerCase();
                    }
                    
                    // Debug log to verify selection
                    android.util.Log.d("PostFragment", "Property type selected: " + selectedPropertyType);
                    validateStep1();
                }
            } else {
                // No chip selected, reset property type
                selectedPropertyType = "";
                validateStep1();
            }
        });
    }
    
    private void setupBedroomBathroomSelection() {
        binding.bedroomsChipGroup.setOnCheckedStateChangeListener((group, checkedIds) -> {
            if (!checkedIds.isEmpty()) {
                Chip selectedChip = group.findViewById(checkedIds.get(0));
                selectedBedrooms = selectedChip.getText().toString();
                validateStep2();
            }
        });
        
        binding.bathroomsChipGroup.setOnCheckedStateChangeListener((group, checkedIds) -> {
            if (!checkedIds.isEmpty()) {
                Chip selectedChip = group.findViewById(checkedIds.get(0));
                selectedBathrooms = selectedChip.getText().toString();
                validateStep2();
            }
        });
    }
    
    private void setupFormValidation() {
        // Real-time validation for text fields
        binding.titleInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            
            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                validateStep1();
            }
            
            @Override
            public void afterTextChanged(Editable s) {}
        });
        
        binding.locationInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            
            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                validateStep1();
            }
            
            @Override
            public void afterTextChanged(Editable s) {}
        });
        
        binding.priceInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            
            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                validateStep1();
                showPriceSuggestion(s.toString());
            }
            
            @Override
            public void afterTextChanged(Editable s) {}
        });
        
        binding.descriptionInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            
            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                validateStep2();
            }
            
            @Override
            public void afterTextChanged(Editable s) {}
        });
    }
    
    private void setupPhotoUpload() {
        binding.photoUploadArea.setOnClickListener(v -> {
            // TODO: Implement photo picker
            Toast.makeText(getContext(), "Photo picker coming soon!", Toast.LENGTH_SHORT).show();
            
            // Simulate adding photos for demo
            photoCount++;
            binding.photoCounter.setText(photoCount + " / 10 photos added");
            validateStep3();
        });
    }
    
    private void showPriceSuggestion(String priceText) {
        if (!priceText.isEmpty()) {
            try {
                int price = Integer.parseInt(priceText);
                if (price > 0) {
                    // Show price suggestion based on typical market rates
                    if (price < 800) {
                        binding.priceSuggestion.setText("💡 Consider: Similar properties rent for $800-1200/month");
                    } else if (price > 3000) {
                        binding.priceSuggestion.setText("💡 High-end: Make sure to highlight luxury features");
                    } else {
                        binding.priceSuggestion.setText("💡 Good range: Competitive with similar properties");
                    }
                    binding.priceSuggestion.setVisibility(View.VISIBLE);
                } else {
                    binding.priceSuggestion.setVisibility(View.GONE);
                }
            } catch (NumberFormatException e) {
                binding.priceSuggestion.setVisibility(View.GONE);
            }
        } else {
            binding.priceSuggestion.setVisibility(View.GONE);
        }
    }
    
    private boolean validateCurrentStep() {
        switch (currentStep) {
            case 1: return validateStep1();
            case 2: return validateStep2();
            case 3: return validateStep3();
            case 4: return validateStep4();
            default: return false;
        }
    }
    
    private boolean validateStep1() {
        boolean isValid = true;
        
        // Validate property type
        if (selectedPropertyType.isEmpty()) {
            Toast.makeText(getContext(), "Please select a property type to continue", Toast.LENGTH_SHORT).show();
            isValid = false;
        }
        
        // Validate title
        String title = binding.titleInput.getText().toString().trim();
        if (title.isEmpty()) {
            binding.titleInputLayout.setError("Title is required");
            isValid = false;
        } else {
            binding.titleInputLayout.setError(null);
        }
        
        // Validate location
        String location = binding.locationInput.getText().toString().trim();
        if (location.isEmpty()) {
            binding.locationInputLayout.setError("Address is required");
            isValid = false;
        } else {
            binding.locationInputLayout.setError(null);
        }
        
        // Validate price
        String price = binding.priceInput.getText().toString().trim();
        if (price.isEmpty()) {
            binding.priceInputLayout.setError("Price is required");
            isValid = false;
        } else {
            try {
                int priceValue = Integer.parseInt(price);
                if (priceValue <= 0) {
                    binding.priceInputLayout.setError("Price must be greater than 0");
                    isValid = false;
                } else {
                    binding.priceInputLayout.setError(null);
                }
            } catch (NumberFormatException e) {
                binding.priceInputLayout.setError("Please enter a valid number");
                isValid = false;
            }
        }
        
        return isValid;
    }
    
    private boolean validateStep2() {
        boolean isValid = true;
        
        // Validate bedrooms selection
        if (selectedBedrooms.isEmpty()) {
            isValid = false;
        }
        
        // Validate bathrooms selection
        if (selectedBathrooms.isEmpty()) {
            isValid = false;
        }
        
        // Validate description (no minimum length required)
        String description = binding.descriptionInput.getText().toString().trim();
        binding.descriptionInputLayout.setError(null);
        
        return isValid;
    }
    
    private boolean validateStep3() {
        // Require at least 1 photo (in real app, would be 3)
        return photoCount >= 1;
    }
    
    private boolean validateStep4() {
        // Check terms agreement
        return binding.termsCheckbox.isChecked();
    }
    
    private boolean validateAllSteps() {
        if (!validateStep4()) {
            Toast.makeText(getContext(), "Please agree to the terms and conditions", Toast.LENGTH_SHORT).show();
            return false;
        }
        return validateStep1() && validateStep2() && validateStep3() && validateStep4();
    }
    
    private void updatePreview() {
        String title = binding.titleInput.getText().toString().trim();
        String location = binding.locationInput.getText().toString().trim();
        String price = binding.priceInput.getText().toString().trim();
        
        binding.previewTitle.setText(title.isEmpty() ? "Property Title" : title);
        binding.previewLocation.setText(location.isEmpty() ? "Location" : location);
        
        String details = selectedBedrooms + " bed • " + selectedBathrooms + " bath";
        if (!price.isEmpty()) {
            details += " • $" + price + "/month";
        }
        binding.previewDetails.setText(details);
    }
    
    private void submitListing() {
        // TODO: Implement actual API submission
        Toast.makeText(getContext(), "Listing posted successfully!", Toast.LENGTH_LONG).show();
        
        // Reset form
        currentStep = 1;
        selectedPropertyType = "";
        selectedBedrooms = "";
        selectedBathrooms = "";
        photoCount = 0;
        
        // Clear all inputs
        binding.titleInput.setText("");
        binding.locationInput.setText("");
        binding.priceInput.setText("");
        binding.descriptionInput.setText("");
        binding.propertyTypeChipGroup.clearCheck();
        binding.bedroomsChipGroup.clearCheck();
        binding.bathroomsChipGroup.clearCheck();
        binding.termsCheckbox.setChecked(false);
        binding.photoCounter.setText("0 / 10 photos added");
        
        updateStepUI();
    }
    
    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}