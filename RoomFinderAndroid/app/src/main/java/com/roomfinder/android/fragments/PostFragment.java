package com.roomfinder.android.fragments;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.MediaStore;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.content.FileProvider;
import androidx.fragment.app.Fragment;
import com.google.android.material.chip.Chip;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.roomfinder.android.databinding.FragmentPostBinding;
import com.roomfinder.android.services.AttachmentUploadService;
import java.io.File;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class PostFragment extends Fragment {
    
    private static final String TAG = "PostFragment";
    
    // Request codes
    private static final int REQUEST_CAMERA_PERMISSION = 1001;
    private static final int REQUEST_STORAGE_PERMISSION = 1002;
    private static final int REQUEST_IMAGE_CAPTURE = 2001;
    private static final int REQUEST_IMAGE_PICK = 2002;
    
    private FragmentPostBinding binding;
    private int currentStep = 1;
    private final int TOTAL_STEPS = 4;
    
    // Form data
    private String selectedPropertyType = "";
    private String selectedBedrooms = "";
    private String selectedBathrooms = "";
    private int photoCount = 0;
    
    // Photo upload functionality
    private AttachmentUploadService attachmentService;
    private List<String> uploadedPhotoUrls = new ArrayList<>();
    private Uri currentPhotoUri;
    private String currentPhotoPath;
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentPostBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        // Initialize attachment service
        attachmentService = new AttachmentUploadService(requireContext());
        
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
        binding.photoUploadArea.setOnClickListener(v -> showPhotoOptions());
    }
    
    /**
     * Show photo selection options dialog
     */
    private void showPhotoOptions() {
        if (uploadedPhotoUrls.size() >= 10) {
            Toast.makeText(getContext(), "Maximum 10 photos allowed", Toast.LENGTH_SHORT).show();
            return;
        }
        
        String[] options = {"Camera", "Photo Gallery"};
        
        new MaterialAlertDialogBuilder(requireContext())
                .setTitle("Add Photo")
                .setItems(options, (dialog, which) -> {
                    switch (which) {
                        case 0:
                            openCamera();
                            break;
                        case 1:
                            openGallery();
                            break;
                    }
                })
                .setNegativeButton("Cancel", null)
                .show();
    }
    
    /**
     * Open camera to take a photo
     */
    private void openCamera() {
        if (ContextCompat.checkSelfPermission(requireContext(), Manifest.permission.CAMERA) 
                != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(requireActivity(), 
                    new String[]{Manifest.permission.CAMERA}, 
                    REQUEST_CAMERA_PERMISSION);
            return;
        }
        
        try {
            Intent takePictureIntent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
            
            // Create the File where the photo should go
            File photoFile = createImageFile();
            if (photoFile != null) {
                currentPhotoUri = FileProvider.getUriForFile(requireContext(),
                        requireContext().getPackageName() + ".fileprovider",
                        photoFile);
                takePictureIntent.putExtra(MediaStore.EXTRA_OUTPUT, currentPhotoUri);
                
                // Grant temporary permissions for the camera app
                takePictureIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                takePictureIntent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
                
                startActivityForResult(takePictureIntent, REQUEST_IMAGE_CAPTURE);
            } else {
                Toast.makeText(getContext(), "Error creating photo file", Toast.LENGTH_SHORT).show();
            }
        } catch (Exception ex) {
            Log.e(TAG, "Error opening camera", ex);
            Toast.makeText(getContext(), "Error opening camera", Toast.LENGTH_SHORT).show();
        }
    }
    
    /**
     * Open gallery to select a photo
     */
    private void openGallery() {
        // Check permissions based on Android version
        String permission;
        if (Build.VERSION.SDK_INT >= 33) { // Android 13 (API 33)
            permission = Manifest.permission.READ_MEDIA_IMAGES;
        } else {
            permission = Manifest.permission.READ_EXTERNAL_STORAGE;
        }
        
        if (ContextCompat.checkSelfPermission(requireContext(), permission) 
                != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(requireActivity(), 
                    new String[]{permission}, 
                    REQUEST_STORAGE_PERMISSION);
            return;
        }
        
        try {
            // Try multiple approaches to open gallery
            Intent intent = null;
            
            // Method 1: Standard ACTION_PICK with MediaStore
            intent = new Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
            intent.setType("image/*");
            
            if (intent.resolveActivity(requireContext().getPackageManager()) != null) {
                startActivityForResult(intent, REQUEST_IMAGE_PICK);
                return;
            }
            
            // Method 2: ACTION_GET_CONTENT (works with more apps)
            intent = new Intent(Intent.ACTION_GET_CONTENT);
            intent.setType("image/*");
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            
            if (intent.resolveActivity(requireContext().getPackageManager()) != null) {
                startActivityForResult(Intent.createChooser(intent, "Select Photo"), REQUEST_IMAGE_PICK);
                return;
            }
            
            // Method 3: Open any file manager/gallery app
            intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.setType("image/*");
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            
            if (intent.resolveActivity(requireContext().getPackageManager()) != null) {
                startActivityForResult(intent, REQUEST_IMAGE_PICK);
                return;
            }
            
            Toast.makeText(getContext(), "No photo app available", Toast.LENGTH_SHORT).show();
            
        } catch (Exception e) {
            Log.e(TAG, "Error opening gallery", e);
            Toast.makeText(getContext(), "Error opening photo gallery", Toast.LENGTH_SHORT).show();
        }
    }
    
    /**
     * Create a temporary file for camera photo
     */
    private File createImageFile() throws IOException {
        // Create an image file name
        String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
        String imageFileName = "JPEG_" + timeStamp + "_";
        File storageDir = requireContext().getExternalFilesDir(android.os.Environment.DIRECTORY_PICTURES);
        
        File image = File.createTempFile(
                imageFileName,  /* prefix */
                ".jpg",         /* suffix */
                storageDir      /* directory */
        );
        
        // Save a file: path for use with ACTION_VIEW intents
        currentPhotoPath = image.getAbsolutePath();
        return image;
    }
    
    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        
        switch (requestCode) {
            case REQUEST_CAMERA_PERMISSION:
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    openCamera();
                } else {
                    Toast.makeText(getContext(), "Camera permission required to take photos", Toast.LENGTH_SHORT).show();
                }
                break;
            case REQUEST_STORAGE_PERMISSION:
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    openGallery();
                } else {
                    String message = Build.VERSION.SDK_INT >= 33 ? 
                        "Media access permission required to select photos" : 
                        "Storage permission required to select photos";
                    Toast.makeText(getContext(), message, Toast.LENGTH_LONG).show();
                }
                break;
        }
    }
    
    @Override
    public void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        
        if (resultCode == Activity.RESULT_OK) {
            switch (requestCode) {
                case REQUEST_IMAGE_CAPTURE:
                    if (currentPhotoUri != null) {
                        handlePhotoSelected(currentPhotoUri);
                    } else {
                        Toast.makeText(getContext(), "Error capturing photo", Toast.LENGTH_SHORT).show();
                    }
                    break;
                case REQUEST_IMAGE_PICK:
                    if (data != null && data.getData() != null) {
                        handlePhotoSelected(data.getData());
                    } else {
                        Toast.makeText(getContext(), "No photo selected", Toast.LENGTH_SHORT).show();
                    }
                    break;
            }
        }
    }
    
    /**
     * Handle selected photo and upload to Supabase
     */
    private void handlePhotoSelected(Uri photoUri) {
        Log.d(TAG, "Photo selected: " + photoUri.toString());
        
        // Validate file
        AttachmentUploadService.FileValidationResult validation = attachmentService.validateFile(photoUri);
        if (!validation.isValid) {
            Toast.makeText(getContext(), validation.error, Toast.LENGTH_LONG).show();
            return;
        }
        
        // Generate file name for listing photo
        String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
        String fileName = "listing_photo_" + timeStamp + "_" + (uploadedPhotoUrls.size() + 1) + ".jpg";
        
        // Show uploading progress
        Toast.makeText(getContext(), "Uploading photo...", Toast.LENGTH_SHORT).show();
        
        // Upload to Supabase storage
        String bucketPath = "listing-photos/" + fileName;
        attachmentService.uploadFile(photoUri, bucketPath, null, new AttachmentUploadService.UploadCallback() {
            @Override
            public void onSuccess(String publicUrl, String fileName, String mimeType) {
                if (getActivity() != null) {
                    getActivity().runOnUiThread(() -> {
                        uploadedPhotoUrls.add(publicUrl);
                        photoCount = uploadedPhotoUrls.size();
                        binding.photoCounter.setText(photoCount + " / 10 photos added");
                        Toast.makeText(getContext(), "Photo uploaded successfully!", Toast.LENGTH_SHORT).show();
                        
                        // Revalidate step 3
                        validateStep3();
                        
                        Log.d(TAG, "Photo uploaded: " + publicUrl);
                    });
                }
            }
            
            @Override
            public void onProgress(int percentage) {
                // Could show progress indicator here
                Log.d(TAG, "Upload progress: " + percentage + "%");
            }
            
            @Override
            public void onError(String error) {
                if (getActivity() != null) {
                    getActivity().runOnUiThread(() -> {
                        Toast.makeText(getContext(), "Upload failed: " + error, Toast.LENGTH_LONG).show();
                        Log.e(TAG, "Photo upload error: " + error);
                    });
                }
            }
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
        // Require at least 1 photo
        return uploadedPhotoUrls.size() >= 1;
    }
    
    private boolean validateStep4() {
        // No validation needed for step 4
        return true;
    }
    
    private boolean validateAllSteps() {
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
        uploadedPhotoUrls.clear();
        
        // Clear all inputs
        binding.titleInput.setText("");
        binding.locationInput.setText("");
        binding.priceInput.setText("");
        binding.descriptionInput.setText("");
        binding.propertyTypeChipGroup.clearCheck();
        binding.bedroomsChipGroup.clearCheck();
        binding.bathroomsChipGroup.clearCheck();
        binding.photoCounter.setText("0 / 10 photos added");
        
        updateStepUI();
    }
    
    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}