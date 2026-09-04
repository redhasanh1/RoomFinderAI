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
import com.roomfinder.android.activities.LoginActivity;
import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.databinding.FragmentPostBinding;
import com.roomfinder.android.services.AttachmentUploadService;
import java.io.File;
import java.io.IOException;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.TimeUnit;
import java.util.Map;

import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import org.json.JSONArray;
import org.json.JSONObject;

public class PostFragment extends Fragment {
    
    private static final String TAG = "PostFragment";
    
    // Request codes
    private static final int REQUEST_CAMERA_PERMISSION = 1001;
    private static final int REQUEST_STORAGE_PERMISSION = 1002;
    private static final int REQUEST_IMAGE_CAPTURE = 2001;
    private static final int REQUEST_IMAGE_PICK = 2002;
    
    // Draft persistence. Survives the trip to LoginActivity and process death.
    private static final String DRAFT_PREFS = "post_listing_draft";
    private static final String DRAFT_TITLE = "title";
    private static final String DRAFT_LOCATION = "location";
    private static final String DRAFT_PRICE = "price";
    private static final String DRAFT_DESCRIPTION = "description";
    private static final String DRAFT_PROPERTY_TYPE = "propertyType";
    private static final String DRAFT_BEDROOMS = "bedrooms";
    private static final String DRAFT_BATHROOMS = "bathrooms";
    private static final String DRAFT_PHOTOS = "photos";
    private static final String DRAFT_STEP = "step";

    /**
     * Suppresses validation while a draft is being written back into the form.
     *
     * setText() on a restored field fires its TextWatcher, which calls
     * validateStep1(). During restore that runs before selectedPropertyType has
     * been assigned, so the form greeted a returning landlord with "Pick a type
     * of place to continue" - about a chip that was about to be re-selected a
     * few lines later. Caught on an emulator; it does not show up in a compile
     * and it would have shipped.
     */
    private boolean restoringDraft = false;

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
    private com.roomfinder.android.services.ListingDraftService draftService;
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
    
    /**
     * Asks for sign-in at publish, and does not lose the form doing it.
     *
     * There have been three versions of this and the history matters, because
     * the obvious fix is the one that was already tried and reverted.
     *
     * v1 checked auth inside submitListing(), on the final tap of step 4. A
     * signed-out person chose a property type, wrote a title, typed an address,
     * set a rent, filled in bedrooms and bathrooms, added photos, read the
     * preview - and only then got "Please sign in to post a listing" and was
     * thrown to the login screen with the whole form behind them. Nothing was
     * saved. That is the worst outcome available.
     *
     * v2 (this method's previous form) moved the check to onResume(), so the
     * dialog appeared before the first field. One tap lost instead of a full
     * form, and given only those two options it was the right call.
     *
     * It still cost us the thing the app is for. The one feature here that is
     * better than posting on Kijiji is step 3: a photo goes in and the vision
     * model writes the title, the description and a suggested price. A landlord
     * arriving from a Facebook post met a demand for an account before seeing
     * any of that - commitment asked before value shown, from someone with no
     * reason to trust us yet.
     *
     * v3 is this: build the listing signed out, ask for the account at Publish,
     * and carry the draft across the login round trip. The bug that forced the
     * entry gate was never "we asked at the wrong time", it was "we did not
     * save their work" - so saving the work is what removes the choice between
     * two bad options. saveDraft() runs before LoginActivity starts and
     * restoreDraft() runs when we come back.
     *
     * Returns true when publishing may proceed.
     */
    private boolean requireSignInToPublish() {
        AuthManager authManager = AuthManager.getInstance(requireContext());
        if (authManager.isUserAuthenticated()) {
            return true;
        }
        saveDraft();
        new com.google.android.material.dialog.MaterialAlertDialogBuilder(requireContext())
                .setTitle("Almost there")
                .setMessage("Your listing is attached to your account so renters can message "
                        + "you about it. We have saved what you have written - sign in and it "
                        + "will be here waiting.")
                .setPositiveButton("Sign in and publish", (dialog, which) ->
                        startActivity(new Intent(requireContext(), LoginActivity.class)))
                .setNegativeButton("Not now", null)
                .show();
        return false;
    }

    @Override
    public void onResume() {
        super.onResume();
        // Coming back from LoginActivity lands here. Restore before anything
        // else touches the form, and only when there is something to restore -
        // an empty draft must not stamp blanks over a form in progress.
        if (hasDraft()) {
            restoreDraft();
        }
    }

    @Override
    public void onPause() {
        super.onPause();
        // Not only for the login trip. Android kills backgrounded processes
        // without warning, and a landlord who alt-tabs to find the postcode
        // must not come back to an empty form. Cheap enough to do every time.
        if (binding != null && isFormStarted()) {
            saveDraft();
        }
    }

    /** True once anything has been entered - used to avoid saving empty drafts. */
    private boolean isFormStarted() {
        return !binding.titleInput.getText().toString().trim().isEmpty()
                || !binding.locationInput.getText().toString().trim().isEmpty()
                || !binding.priceInput.getText().toString().trim().isEmpty()
                || !binding.descriptionInput.getText().toString().trim().isEmpty()
                || !selectedPropertyType.isEmpty()
                || !uploadedPhotoUrls.isEmpty();
    }

    private android.content.SharedPreferences draftPrefs() {
        return requireContext().getSharedPreferences(DRAFT_PREFS, android.content.Context.MODE_PRIVATE);
    }

    private boolean hasDraft() {
        return draftPrefs().contains(DRAFT_TITLE);
    }

    /**
     * Persists the form.
     *
     * Photos need no special handling, which is the part that makes this small:
     * uploadedPhotoUrls already holds remote URLs because AttachmentUploadService
     * uploads each photo as it is picked. There are no local content:// URIs to
     * keep alive across a process death, and no permission to re-request.
     */
    private void saveDraft() {
        JSONArray photos = new JSONArray(uploadedPhotoUrls);
        draftPrefs().edit()
                .putString(DRAFT_TITLE, binding.titleInput.getText().toString())
                .putString(DRAFT_LOCATION, binding.locationInput.getText().toString())
                .putString(DRAFT_PRICE, binding.priceInput.getText().toString())
                .putString(DRAFT_DESCRIPTION, binding.descriptionInput.getText().toString())
                .putString(DRAFT_PROPERTY_TYPE, selectedPropertyType)
                .putString(DRAFT_BEDROOMS, selectedBedrooms)
                .putString(DRAFT_BATHROOMS, selectedBathrooms)
                .putString(DRAFT_PHOTOS, photos.toString())
                .putInt(DRAFT_STEP, currentStep)
                .apply();
        Log.d(TAG, "Draft saved at step " + currentStep + " with " + uploadedPhotoUrls.size() + " photos");
    }

    private void restoreDraft() {
        android.content.SharedPreferences prefs = draftPrefs();
        restoringDraft = true;
        try {
            restoreDraftFields(prefs);
        } finally {
            // A throw part-way through must not leave validation permanently
            // switched off - the form would then accept an empty listing.
            restoringDraft = false;
        }
        updateStepUI();
        Log.d(TAG, "Draft restored at step " + currentStep);
    }

    private void restoreDraftFields(android.content.SharedPreferences prefs) {
        // Model first, then the chips, then the text. setText fires watchers,
        // and a watcher that runs before selectedPropertyType is set validates
        // against a half-restored form.
        selectedPropertyType = prefs.getString(DRAFT_PROPERTY_TYPE, "");
        selectedBedrooms = prefs.getString(DRAFT_BEDROOMS, "");
        selectedBathrooms = prefs.getString(DRAFT_BATHROOMS, "");

        binding.titleInput.setText(prefs.getString(DRAFT_TITLE, ""));
        binding.locationInput.setText(prefs.getString(DRAFT_LOCATION, ""));
        binding.priceInput.setText(prefs.getString(DRAFT_PRICE, ""));
        binding.descriptionInput.setText(prefs.getString(DRAFT_DESCRIPTION, ""));

        uploadedPhotoUrls.clear();
        try {
            JSONArray photos = new JSONArray(prefs.getString(DRAFT_PHOTOS, "[]"));
            for (int i = 0; i < photos.length(); i++) {
                uploadedPhotoUrls.add(photos.getString(i));
            }
        } catch (org.json.JSONException e) {
            // A malformed photo list must not take the rest of the draft with
            // it - the words are the expensive part, the photos can be re-added.
            Log.w(TAG, "Could not restore draft photos", e);
        }
        photoCount = uploadedPhotoUrls.size();
        binding.photoCounter.setText(photoCount + " / 10 photos added");

        // The chips carry the visible state; the strings above are only what we
        // send. Re-check them by matching text, or the restored form shows a
        // type that is set in the model and blank on screen.
        recheckChip(binding.propertyTypeChipGroup, selectedPropertyType, true);
        recheckChip(binding.bedroomsChipGroup, selectedBedrooms, false);
        recheckChip(binding.bathroomsChipGroup, selectedBathrooms, false);

        currentStep = prefs.getInt(DRAFT_STEP, 1);
    }

    /**
     * Re-selects the chip matching a saved value.
     *
     * Property type is stored normalised ("apartment") while the chip reads
     * something like "[emoji] Apartment", so that one matches on contains;
     * bedrooms and bathrooms are stored as the chip's own text and match
     * exactly. Getting this wrong is silent - the value posts correctly and the
     * screen looks unanswered.
     */
    private void recheckChip(com.google.android.material.chip.ChipGroup group, String value, boolean fuzzy) {
        if (value == null || value.isEmpty() || group == null) {
            return;
        }
        for (int i = 0; i < group.getChildCount(); i++) {
            View child = group.getChildAt(i);
            if (!(child instanceof Chip)) {
                continue;
            }
            String text = ((Chip) child).getText().toString();
            boolean hit = fuzzy
                    ? text.toLowerCase().contains(value.toLowerCase())
                    : text.equals(value);
            if (hit) {
                group.check(child.getId());
                return;
            }
        }
    }

    private void clearDraft() {
        draftPrefs().edit().clear().apply();
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
            // Validate first, then ask for the account. Sending someone to sign
            // in and returning them to a form that then refuses to publish is
            // two disappointments where one would do.
            if (!validateAllSteps()) {
                return;
            }
            if (!requireSignInToPublish()) {
                return;
            }
            submitListing();
        });
    }
    
    private void updateStepUI() {
        // Update progress indicator
        binding.stepIndicator.setText("Step " + currentStep + " of " + TOTAL_STEPS);
        int progress = (currentStep * 100) / TOTAL_STEPS;
        binding.progressBar.setProgress(progress);
        binding.completionPercentage.setText(progress + "% Complete");
        
        // Update step title and description
        String[] stepTitles = {"The basics", "Details", "Photos", "Review"};
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
                "Next: details",
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

        // Both AI routes: a photo the model reads, or the facts already typed.
        binding.aiDraftBanner.setOnClickListener(v -> showPhotoOptions());
        binding.writeForMeButton.setOnClickListener(v -> writeListingFromDetails());
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
    /**
     * Sends the first photo to the vision model and fills the form from what it
     * reads back: title, description, property type, bedrooms, a suggested
     * rent and the address. Anything the host already typed is left alone.
     */
    /**
     * Writes the listing from what has been entered, for hosts with no photo to
     * hand. Same endpoint the website uses.
     */
    private void writeListingFromDetails() {
        if (binding == null) {
            return;
        }
        if (draftService == null) {
            draftService = new com.roomfinder.android.services.ListingDraftService();
        }

        String location = binding.locationInput.getText() == null
                ? "" : binding.locationInput.getText().toString().trim();
        String city = location;
        String street = "";
        if (location.contains(",")) {
            street = location.substring(0, location.indexOf(',')).trim();
            city = location.substring(location.indexOf(',') + 1).trim();
        }

        String houseType = selectedChipText(binding.propertyTypeChipGroup, "Apartment");
        String bedroomsText = selectedChipText(binding.bedroomsChipGroup, "1");
        int bedrooms = "studio".equalsIgnoreCase(bedroomsText) ? 0 : parseLeadingInt(bedroomsText, 1);
        String price = binding.priceInput.getText() == null
                ? "" : binding.priceInput.getText().toString().trim();

        binding.writeForMeButton.setEnabled(false);
        binding.writeForMeButton.setText("Writing");
        setDraftingState(true, "Writing your listing");
        binding.aiStatusDetail.setText("Using the address, type and rent you entered");

        draftService.draftFromDetails(city, street, houseType, bedrooms, price, true,
                binding.titleInput.getText() == null ? "" : binding.titleInput.getText().toString(),
                new com.roomfinder.android.services.ListingDraftService.DraftCallback() {
                    @Override
                    public void onDraft(com.roomfinder.android.services.ListingDraftService.Draft draft) {
                        if (binding == null) {
                            return;
                        }
                        restoreWriteButton();
                        showDraftResult("Description written", "Edit it however you like");
                        if (draft.title != null && isBlank(binding.titleInput)) {
                            binding.titleInput.setText(draft.title);
                        }
                        if (draft.description != null) {
                            binding.descriptionInput.setText(draft.description);
                        }
                        updateStepUI();
                    }

                    @Override
                    public void onError(String message) {
                        if (binding == null) {
                            return;
                        }
                        restoreWriteButton();
                        showDraftResult("Could not write it", message);
                    }
                });
    }

    private void restoreWriteButton() {
        binding.writeForMeButton.setEnabled(true);
        binding.writeForMeButton.setText("Write it for me");
    }

    private String selectedChipText(com.google.android.material.chip.ChipGroup group, String fallback) {
        int id = group.getCheckedChipId();
        if (id == View.NO_ID) {
            return fallback;
        }
        com.google.android.material.chip.Chip chip = group.findViewById(id);
        return chip == null ? fallback : chip.getText().toString();
    }

    private int parseLeadingInt(String value, int fallback) {
        StringBuilder digits = new StringBuilder();
        for (char c : value.toCharArray()) {
            if (Character.isDigit(c)) {
                digits.append(c);
            } else if (digits.length() > 0) {
                break;
            }
        }
        try {
            return digits.length() == 0 ? fallback : Integer.parseInt(digits.toString());
        } catch (NumberFormatException e) {
            return fallback;
        }
    }

    private void analysePhotoForDraft(android.net.Uri photoUri) {
        if (draftService == null) {
            draftService = new com.roomfinder.android.services.ListingDraftService();
        }
        setDraftingState(true, "Reading your photo");
        binding.aiStatusDetail.setText("Working out the title, rent and description");

        draftService.draftFromPhoto(requireContext(), photoUri,
                new com.roomfinder.android.services.ListingDraftService.DraftCallback() {
                    @Override
                    public void onDraft(com.roomfinder.android.services.ListingDraftService.Draft draft) {
                        if (binding == null) {
                            return;
                        }
                        setDraftingState(false, null);
                        applyDraft(draft);
                    }

                    @Override
                    public void onError(String message) {
                        if (binding == null) {
                            return;
                        }
                        // A rejected photo carries a specific, useful reason
                        // ("a styled interior rendering, not a photograph of a
                        // real rental"). Worth keeping on screen.
                        showDraftResult("Could not read that photo", message);
                    }
                });
    }

    /** Fills only the fields the host has not already filled in themselves. */
    private void applyDraft(com.roomfinder.android.services.ListingDraftService.Draft draft) {
        if (draft.title != null && isBlank(binding.titleInput)) {
            binding.titleInput.setText(draft.title);
        }
        if (draft.description != null && isBlank(binding.descriptionInput)) {
            binding.descriptionInput.setText(draft.description);
        }
        if (draft.price != null && isBlank(binding.priceInput)) {
            binding.priceInput.setText(String.valueOf(draft.price));
        }
        if (draft.hasLocation() && isBlank(binding.locationInput)) {
            StringBuilder address = new StringBuilder();
            if (draft.street != null) {
                address.append(draft.street);
            }
            if (draft.city != null) {
                if (address.length() > 0) {
                    address.append(", ");
                }
                address.append(draft.city);
            }
            if (draft.postalCode != null) {
                if (address.length() > 0) {
                    address.append(" ");
                }
                address.append(draft.postalCode);
            }
            binding.locationInput.setText(address.toString());
        }
        if (draft.houseType != null) {
            selectPropertyTypeChip(draft.houseType);
        }
        if (draft.bedrooms != null) {
            selectBedroomChip(draft.bedrooms);
        }

        StringBuilder summary = new StringBuilder("It spotted");
        if (!draft.features.isEmpty()) {
            summary.append(" ");
            for (int i = 0; i < Math.min(3, draft.features.size()); i++) {
                if (i > 0) {
                    summary.append(", ");
                }
                summary.append(draft.features.get(i));
            }
        }
        if (draft.locationIsApproximate) {
            // Told, not trusted: an IP-derived area is city-level at best.
            summary.append(". Check the address, it is approximate.");
        }
        String detail = draft.features.isEmpty()
                ? "Title, rent and description are filled in - edit anything you like"
                : summary.toString();
        showDraftResult("Filled in from your photo", detail);
        updateStepUI();
    }

    private boolean isBlank(android.widget.EditText field) {
        return field == null || field.getText() == null || field.getText().toString().trim().isEmpty();
    }

    private void selectPropertyTypeChip(String houseType) {
        String wanted = houseType.trim().toLowerCase();
        for (int i = 0; i < binding.propertyTypeChipGroup.getChildCount(); i++) {
            android.view.View child = binding.propertyTypeChipGroup.getChildAt(i);
            if (child instanceof com.google.android.material.chip.Chip) {
                com.google.android.material.chip.Chip chip = (com.google.android.material.chip.Chip) child;
                if (chip.getText().toString().toLowerCase().startsWith(wanted)
                        || wanted.startsWith(chip.getText().toString().toLowerCase())) {
                    chip.setChecked(true);
                    return;
                }
            }
        }
    }

    private void selectBedroomChip(int bedrooms) {
        String wanted = bedrooms == 0 ? "studio" : String.valueOf(bedrooms);
        for (int i = 0; i < binding.bedroomsChipGroup.getChildCount(); i++) {
            android.view.View child = binding.bedroomsChipGroup.getChildAt(i);
            if (child instanceof com.google.android.material.chip.Chip) {
                com.google.android.material.chip.Chip chip = (com.google.android.material.chip.Chip) child;
                if (chip.getText().toString().toLowerCase().startsWith(wanted)) {
                    chip.setChecked(true);
                    return;
                }
            }
        }
    }

    /**
     * Shows what the AI is doing, inline and for as long as it takes.
     *
     * This was a Toast, which is gone in two seconds and says nothing about a
     * request that can run for the better part of a minute - so the screen just
     * looked frozen while a vision model read the photo.
     */
    private void setDraftingState(boolean drafting, String message) {
        if (binding == null) {
            return;
        }
        binding.aiStatusCard.setVisibility(View.VISIBLE);
        binding.aiStatusSpinner.setVisibility(drafting ? View.VISIBLE : View.GONE);
        binding.aiStatusDone.setVisibility(drafting ? View.GONE : View.VISIBLE);
        if (message != null) {
            binding.aiStatusTitle.setText(message);
        }
    }

    /** The finished state: what it filled in, kept on screen rather than flashed. */
    private void showDraftResult(String title, String detail) {
        if (binding == null) {
            return;
        }
        binding.aiStatusCard.setVisibility(View.VISIBLE);
        binding.aiStatusSpinner.setVisibility(View.GONE);
        binding.aiStatusDone.setVisibility(View.VISIBLE);
        binding.aiStatusTitle.setText(title);
        binding.aiStatusDetail.setText(detail);
    }

    private void hideDraftStatus() {
        if (binding != null) {
            binding.aiStatusCard.setVisibility(View.GONE);
        }
    }

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
        Toast.makeText(getContext(), "Adding photo", Toast.LENGTH_SHORT).show();

        // The first photo also gets read by the vision model, which writes the
        // whole listing. Writing the description is where people abandon
        // posting a room, so the photo they were adding anyway is the cheapest
        // possible way to get one.
        if (uploadedPhotoUrls.isEmpty()) {
            analysePhotoForDraft(photoUri);
        }
        
        // Upload to Supabase storage (listing-media bucket, same as web)
        attachmentService.uploadListingPhoto(photoUri, fileName, new AttachmentUploadService.UploadCallback() {
            @Override
            public void onSuccess(String publicUrl, String fileName, String mimeType) {
                if (getActivity() != null) {
                    getActivity().runOnUiThread(() -> {
                        uploadedPhotoUrls.add(publicUrl);
                        photoCount = uploadedPhotoUrls.size();
                        binding.photoCounter.setText(photoCount + " / 10 photos added");
                        Toast.makeText(getContext(), "Photo added", Toast.LENGTH_SHORT).show();
                        
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
        if (restoringDraft) {
            return true;
        }
        boolean isValid = true;
        // Tracks the first field that failed, so the form can take you to it.
        // Painting every field red at once and leaving the cursor where it was
        // tells you that you failed, not what to do next.
        com.google.android.material.textfield.TextInputLayout firstInvalid = null;
        
        // Validate property type
        if (selectedPropertyType.isEmpty()) {
            Toast.makeText(getContext(), "Pick a type of place to continue", Toast.LENGTH_SHORT).show();
            isValid = false;
        }
        
        // Validate title
        String title = binding.titleInput.getText().toString().trim();
        if (title.isEmpty()) {
            binding.titleInputLayout.setError("Title is required");
            firstInvalid = firstInvalid != null ? firstInvalid : binding.titleInputLayout;
            isValid = false;
        } else {
            binding.titleInputLayout.setError(null);
        }
        
        // Validate location
        String location = binding.locationInput.getText().toString().trim();
        if (location.isEmpty()) {
            binding.locationInputLayout.setError("Address is required");
            firstInvalid = firstInvalid != null ? firstInvalid : binding.locationInputLayout;
            isValid = false;
        } else {
            binding.locationInputLayout.setError(null);
        }
        
        // Validate price
        String price = binding.priceInput.getText().toString().trim();
        if (price.isEmpty()) {
            binding.priceInputLayout.setError("Price is required");
            firstInvalid = firstInvalid != null ? firstInvalid : binding.priceInputLayout;
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
                firstInvalid = firstInvalid != null ? firstInvalid : binding.priceInputLayout;
                isValid = false;
            }
        }

        focusFirstInvalid(firstInvalid);
        return isValid;
    }

    /** Scrolls the first failing field into view and puts the cursor in it. */
    private void focusFirstInvalid(com.google.android.material.textfield.TextInputLayout field) {
        if (field == null) {
            return;
        }
        field.requestFocus();
        field.post(() -> {
            View child = field.getEditText();
            if (child != null) {
                child.requestFocus();
            }
            field.getParent().requestChildFocus(field, field);
        });
    }

    private boolean validateStep2() {
        if (restoringDraft) {
            return true;
        }
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
        // A photo is required, but the button used to fail this check in
        // silence: tapping "Next: Review" with no photos did nothing at all and
        // said nothing, so posting a room simply could not be finished. Say
        // what is missing, and point at the control that fixes it.
        if (uploadedPhotoUrls.isEmpty()) {
            // The message has to appear on this step: the AI status card lives
            // on step one and is not on screen here.
            binding.photoCounter.setText("Add at least one photo to continue");
            binding.photoCounter.setTextColor(androidx.core.content.ContextCompat.getColor(
                    requireContext(), com.roomfinder.android.R.color.negative));
            return false;
        }
        binding.photoCounter.setTextColor(androidx.core.content.ContextCompat.getColor(
                requireContext(), com.roomfinder.android.R.color.ink_secondary));
        return true;
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
        // requireSignInToPublish() is the gate; this is the backstop for any
        // other caller, and it keeps the draft rather than discarding it.
        AuthManager authManager = AuthManager.getInstance(requireContext());
        if (!authManager.isUserAuthenticated()) {
            requireSignInToPublish();
            return;
        }

        final String userEmail = authManager.getUserEmail();
        if (userEmail == null || userEmail.isEmpty()) {
            Toast.makeText(getContext(), "Unable to determine your account email", Toast.LENGTH_LONG).show();
            return;
        }

        binding.postButton.setEnabled(false);
        Toast.makeText(getContext(), "Publishing listing...", Toast.LENGTH_SHORT).show();

        new Thread(() -> {
            try {
                JSONObject body = new JSONObject();
                String location = binding.locationInput.getText().toString().trim();
                body.put("title", binding.titleInput.getText().toString().trim());
                body.put("city", location);
                body.put("street", location);
                body.put("postalCode", "");
                body.put("price", binding.priceInput.getText().toString().trim());
                body.put("houseType", selectedPropertyType.isEmpty() ? "apartment" : selectedPropertyType);
                String bedroomsValue = selectedBedrooms.replace("+", "").trim();
                body.put("bedrooms", bedroomsValue.isEmpty() ? "1" : bedroomsValue);
                body.put("utilities", "included");
                body.put("description", binding.descriptionInput.getText().toString().trim());
                body.put("media", new JSONArray(uploadedPhotoUrls));
                body.put("userEmail", userEmail);

                OkHttpClient client = new OkHttpClient.Builder()
                        .connectTimeout(30, TimeUnit.SECONDS)
                        .readTimeout(30, TimeUnit.SECONDS)
                        .build();

                Request request = new Request.Builder()
                        .url("https://www.roomfinderai.com/api/listings")
                        .post(RequestBody.create(body.toString(), MediaType.parse("application/json")))
                        .build();

                try (Response response = client.newCall(request).execute()) {
                    if (!response.isSuccessful()) {
                        String errorBody = response.body() != null ? response.body().string() : "Unknown error";
                        throw new IOException("Server error " + response.code() + ": " + errorBody);
                    }

                    if (getActivity() != null) {
                        getActivity().runOnUiThread(() -> {
                            Toast.makeText(getContext(), "Listing posted successfully!", Toast.LENGTH_LONG).show();
                            resetFormAfterSubmit();
                        });
                    }
                }
            } catch (Exception e) {
                Log.e(TAG, "Failed to submit listing", e);
                if (getActivity() != null) {
                    getActivity().runOnUiThread(() -> {
                        Toast.makeText(getContext(), "Failed to post listing: " + e.getMessage(), Toast.LENGTH_LONG).show();
                        binding.postButton.setEnabled(true);
                    });
                }
            }
        }).start();
    }

    private void resetFormAfterSubmit() {
        // Only reached after the server accepted the listing. Clearing earlier
        // would throw the draft away on a failed publish, which is exactly when
        // it is needed.
        clearDraft();
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
        binding.postButton.setEnabled(true);
        
        updateStepUI();
    }
    
    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}