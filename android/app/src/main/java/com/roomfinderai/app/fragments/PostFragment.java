package com.roomfinderai.app.fragments;

import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.Toast;
import androidx.fragment.app.Fragment;
import com.roomfinderai.app.R;
import com.roomfinderai.app.models.Listing;
import com.roomfinderai.app.services.Repository;
import java.util.ArrayList;
import java.util.List;

public class PostFragment extends Fragment {
    
    private static final String TAG = "PostFragment";
    private EditText titleInput, descriptionInput, priceInput;
    private EditText addressInput, cityInput, postalCodeInput;
    private EditText bedroomsInput, bathroomsInput, sizeInput;
    private Spinner typeSpinner;
    private CheckBox parkingCheckbox, petsCheckbox, furnishedCheckbox, utilitiesCheckbox;
    private Button addPhotosButton, submitButton;
    private Repository repository;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_post, container, false);
        
        repository = new Repository();
        
        initializeViews(view);
        setupSpinner();
        setupClickListeners();
        
        return view;
    }
    
    private void initializeViews(View view) {
        // Basic info
        titleInput = view.findViewById(R.id.titleInput);
        descriptionInput = view.findViewById(R.id.descriptionInput);
        priceInput = view.findViewById(R.id.priceInput);
        typeSpinner = view.findViewById(R.id.typeSpinner);
        
        // Location
        addressInput = view.findViewById(R.id.addressInput);
        cityInput = view.findViewById(R.id.cityInput);
        postalCodeInput = view.findViewById(R.id.postalCodeInput);
        
        // Details
        bedroomsInput = view.findViewById(R.id.bedroomsInput);
        bathroomsInput = view.findViewById(R.id.bathroomsInput);
        sizeInput = view.findViewById(R.id.sizeInput);
        
        // Amenities
        parkingCheckbox = view.findViewById(R.id.parkingCheckbox);
        petsCheckbox = view.findViewById(R.id.petsCheckbox);
        furnishedCheckbox = view.findViewById(R.id.furnishedCheckbox);
        utilitiesCheckbox = view.findViewById(R.id.utilitiesCheckbox);
        
        // Buttons
        addPhotosButton = view.findViewById(R.id.addPhotosButton);
        submitButton = view.findViewById(R.id.submitButton);
    }
    
    private void setupSpinner() {
        String[] types = {"Room", "Apartment", "House", "Condo", "Studio", "Shared Room"};
        ArrayAdapter<String> adapter = new ArrayAdapter<>(getContext(), 
            android.R.layout.simple_spinner_item, types);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        typeSpinner.setAdapter(adapter);
    }
    
    private void setupClickListeners() {
        addPhotosButton.setOnClickListener(v -> {
            // TODO: Implement photo picker
            Toast.makeText(getContext(), "Photo selection coming soon", Toast.LENGTH_SHORT).show();
        });
        
        submitButton.setOnClickListener(v -> {
            if (validateForm()) {
                submitListing();
            }
        });
    }
    
    private boolean validateForm() {
        if (titleInput.getText().toString().trim().isEmpty()) {
            titleInput.setError("Title is required");
            return false;
        }
        
        if (priceInput.getText().toString().trim().isEmpty()) {
            priceInput.setError("Price is required");
            return false;
        }
        
        if (addressInput.getText().toString().trim().isEmpty()) {
            addressInput.setError("Address is required");
            return false;
        }
        
        return true;
    }
    
    private void submitListing() {
        // Disable submit button to prevent double-submission
        submitButton.setEnabled(false);
        submitButton.setText("Submitting...");
        
        try {
            // Collect all form data
            String title = titleInput.getText().toString().trim();
            String description = descriptionInput.getText().toString().trim();
            String priceText = priceInput.getText().toString().trim();
            String type = typeSpinner.getSelectedItem().toString();
            String address = addressInput.getText().toString().trim();
            String city = cityInput.getText().toString().trim();
            String postalCode = postalCodeInput.getText().toString().trim();
            String bedroomsText = bedroomsInput.getText().toString().trim();
            String bathroomsText = bathroomsInput.getText().toString().trim();
            
            // Parse numeric values
            double price = Double.parseDouble(priceText);
            int bedrooms = bedroomsText.isEmpty() ? 1 : Integer.parseInt(bedroomsText);
            double bathrooms = bathroomsText.isEmpty() ? 1.0 : Double.parseDouble(bathroomsText);
            
            // Build full location
            String fullLocation = address;
            if (!city.isEmpty()) {
                fullLocation += ", " + city;
            }
            if (!postalCode.isEmpty()) {
                fullLocation += " " + postalCode;
            }
            
            // Create amenities list
            List<String> amenities = new ArrayList<>();
            if (parkingCheckbox.isChecked()) amenities.add("Parking");
            if (petsCheckbox.isChecked()) amenities.add("Pet-friendly");
            if (furnishedCheckbox.isChecked()) amenities.add("Furnished");
            if (utilitiesCheckbox.isChecked()) amenities.add("Utilities included");
            
            // Create listing object
            Listing listing = new Listing(title, description, price, fullLocation, bedrooms, bathrooms, new ArrayList<>());
            listing.setPropertyType(type);
            // Note: Amenities could be appended to description if needed since database doesn't have amenities field
            
            // Submit to API
            repository.createListing(listing, new Repository.ApiCallback<Listing>() {
                @Override
                public void onSuccess(Listing result) {
                    if (getActivity() != null) {
                        getActivity().runOnUiThread(() -> {
                            submitButton.setEnabled(true);
                            submitButton.setText("Submit Listing");
                            
                            Toast.makeText(getContext(), "Listing posted successfully!", Toast.LENGTH_LONG).show();
                            Log.d(TAG, "Listing created with ID: " + result.getId());
                            
                            // Clear form
                            clearForm();
                        });
                    }
                }

                @Override
                public void onError(String error) {
                    if (getActivity() != null) {
                        getActivity().runOnUiThread(() -> {
                            submitButton.setEnabled(true);
                            submitButton.setText("Submit Listing");
                            
                            Log.e(TAG, "Error creating listing: " + error);
                            Toast.makeText(getContext(), "Error posting listing: " + error, Toast.LENGTH_LONG).show();
                        });
                    }
                }
            });
            
        } catch (NumberFormatException e) {
            submitButton.setEnabled(true);
            submitButton.setText("Submit Listing");
            Toast.makeText(getContext(), "Please enter valid numbers for price, bedrooms, and bathrooms", Toast.LENGTH_LONG).show();
        } catch (Exception e) {
            submitButton.setEnabled(true);
            submitButton.setText("Submit Listing");
            Log.e(TAG, "Error submitting listing", e);
            Toast.makeText(getContext(), "Error submitting listing: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }
    
    private void clearForm() {
        titleInput.setText("");
        descriptionInput.setText("");
        priceInput.setText("");
        addressInput.setText("");
        cityInput.setText("");
        postalCodeInput.setText("");
        bedroomsInput.setText("");
        bathroomsInput.setText("");
        sizeInput.setText("");
        
        parkingCheckbox.setChecked(false);
        petsCheckbox.setChecked(false);
        furnishedCheckbox.setChecked(false);
        utilitiesCheckbox.setChecked(false);
        
        typeSpinner.setSelection(0);
    }
}