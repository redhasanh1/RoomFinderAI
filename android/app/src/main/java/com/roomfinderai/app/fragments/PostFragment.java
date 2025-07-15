package com.roomfinderai.app.fragments;

import android.os.Bundle;
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

public class PostFragment extends Fragment {
    
    private EditText titleInput, descriptionInput, priceInput;
    private EditText addressInput, cityInput, postalCodeInput;
    private EditText bedroomsInput, bathroomsInput, sizeInput;
    private Spinner typeSpinner;
    private CheckBox parkingCheckbox, petsCheckbox, furnishedCheckbox, utilitiesCheckbox;
    private Button addPhotosButton, submitButton;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_post, container, false);
        
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
        // Collect all form data
        String title = titleInput.getText().toString();
        String description = descriptionInput.getText().toString();
        String price = priceInput.getText().toString();
        String type = typeSpinner.getSelectedItem().toString();
        String address = addressInput.getText().toString();
        String city = cityInput.getText().toString();
        String postalCode = postalCodeInput.getText().toString();
        
        // TODO: Submit to backend API
        Toast.makeText(getContext(), "Listing posted successfully!", Toast.LENGTH_LONG).show();
        
        // Clear form
        clearForm();
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