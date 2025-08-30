package com.roomfinder.android.fragments;

import android.content.Intent;
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
import com.roomfinder.android.utils.DocumentTemplates;
import com.roomfinder.android.utils.DocumentTemplates.DocumentType;
import com.roomfinder.android.utils.DocumentTemplates.DocumentData;
import com.roomfinder.android.utils.DocumentTemplates.GeneratedDocument;

public class DocumentGeneratorFragment extends Fragment {

    // UI Components
    private MaterialButton leaseAgreementBtn;
    private MaterialButton terminationNoticeBtn;
    private MaterialButton complaintLetterBtn;
    
    private TextInputEditText stateInput;
    private TextInputEditText propertyAddressInput;
    private TextInputEditText monthlyRentInput;
    private TextInputEditText securityDepositInput;
    
    private MaterialButton generateDocumentButton;
    
    // Results Section
    private LinearLayout resultsSection;
    private TextView documentTypeResult;
    private TextView documentPreview;
    private MaterialButton previewDocumentButton;
    private MaterialButton downloadDocumentButton;
    
    // State
    private DocumentType selectedDocumentType = DocumentType.LEASE_AGREEMENT;
    private GeneratedDocument currentDocument;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_document_generator, container, false);
        
        initializeViews(view);
        setupButtonListeners();
        updateDocumentTypeSelection();
        
        return view;
    }

    private void initializeViews(View view) {
        // Document type buttons
        leaseAgreementBtn = view.findViewById(R.id.leaseAgreementBtn);
        terminationNoticeBtn = view.findViewById(R.id.terminationNoticeBtn);
        complaintLetterBtn = view.findViewById(R.id.complaintLetterBtn);
        
        // Input fields
        stateInput = view.findViewById(R.id.stateInput);
        propertyAddressInput = view.findViewById(R.id.propertyAddressInput);
        monthlyRentInput = view.findViewById(R.id.monthlyRentInput);
        securityDepositInput = view.findViewById(R.id.securityDepositInput);
        
        // Action button
        generateDocumentButton = view.findViewById(R.id.generateDocumentButton);
        
        // Results section
        resultsSection = view.findViewById(R.id.resultsSection);
        documentTypeResult = view.findViewById(R.id.documentTypeResult);
        documentPreview = view.findViewById(R.id.documentPreview);
        previewDocumentButton = view.findViewById(R.id.previewDocumentButton);
        downloadDocumentButton = view.findViewById(R.id.downloadDocumentButton);
    }

    private void setupButtonListeners() {
        // Document type selection
        leaseAgreementBtn.setOnClickListener(v -> {
            selectedDocumentType = DocumentType.LEASE_AGREEMENT;
            updateDocumentTypeSelection();
            updateInputVisibility();
        });
        
        terminationNoticeBtn.setOnClickListener(v -> {
            selectedDocumentType = DocumentType.TERMINATION_NOTICE;
            updateDocumentTypeSelection();
            updateInputVisibility();
        });
        
        complaintLetterBtn.setOnClickListener(v -> {
            selectedDocumentType = DocumentType.COMPLAINT_LETTER;
            updateDocumentTypeSelection();
            updateInputVisibility();
        });
        
        // Generate document
        generateDocumentButton.setOnClickListener(v -> generateDocument());
        
        // Results actions
        previewDocumentButton.setOnClickListener(v -> previewFullDocument());
        downloadDocumentButton.setOnClickListener(v -> downloadDocument());
    }

    private void updateDocumentTypeSelection() {
        // Reset all buttons to unselected state
        leaseAgreementBtn.setBackgroundTintList(getResources().getColorStateList(R.color.gray_100, null));
        leaseAgreementBtn.setTextColor(getResources().getColor(R.color.text_primary, null));
        terminationNoticeBtn.setBackgroundTintList(getResources().getColorStateList(R.color.gray_100, null));
        terminationNoticeBtn.setTextColor(getResources().getColor(R.color.text_primary, null));
        complaintLetterBtn.setBackgroundTintList(getResources().getColorStateList(R.color.gray_100, null));
        complaintLetterBtn.setTextColor(getResources().getColor(R.color.text_primary, null));
        
        // Highlight selected button
        MaterialButton selectedButton = null;
        switch (selectedDocumentType) {
            case LEASE_AGREEMENT:
                selectedButton = leaseAgreementBtn;
                break;
            case TERMINATION_NOTICE:
                selectedButton = terminationNoticeBtn;
                break;
            case COMPLAINT_LETTER:
                selectedButton = complaintLetterBtn;
                break;
        }
        
        if (selectedButton != null) {
            selectedButton.setBackgroundTintList(getResources().getColorStateList(R.color.purple_primary, null));
            selectedButton.setTextColor(getResources().getColor(R.color.white, null));
        }
    }

    private void updateInputVisibility() {
        // Show/hide input fields based on document type
        switch (selectedDocumentType) {
            case LEASE_AGREEMENT:
                monthlyRentInput.getParent().setVisibility(View.VISIBLE);
                securityDepositInput.getParent().setVisibility(View.VISIBLE);
                break;
            case TERMINATION_NOTICE:
                monthlyRentInput.getParent().setVisibility(View.GONE);
                securityDepositInput.getParent().setVisibility(View.GONE);
                break;
            case COMPLAINT_LETTER:
                monthlyRentInput.getParent().setVisibility(View.GONE);
                securityDepositInput.getParent().setVisibility(View.GONE);
                break;
        }
    }

    private void generateDocument() {
        try {
            // Collect input data
            DocumentData data = new DocumentData();
            data.setField("state", stateInput.getText().toString().trim());
            data.setField("propertyAddress", propertyAddressInput.getText().toString().trim());
            data.setField("monthlyRent", monthlyRentInput.getText().toString().trim());
            data.setField("securityDeposit", securityDepositInput.getText().toString().trim());
            
            // Add issue description for complaint letters
            if (selectedDocumentType == DocumentType.COMPLAINT_LETTER) {
                data.setField("issueDescription", "Please describe the specific issue(s) that need to be addressed.");
            }

            // Validate required fields
            if (!DocumentTemplates.hasRequiredFields(selectedDocumentType, data)) {
                showError("Please fill in all required fields");
                return;
            }
            
            // Validate numeric fields where applicable
            if (selectedDocumentType == DocumentType.LEASE_AGREEMENT) {
                try {
                    double rent = Double.parseDouble(data.getField("monthlyRent"));
                    double deposit = Double.parseDouble(data.getField("securityDeposit"));
                    
                    if (rent <= 0 || deposit < 0) {
                        showError("Please enter valid amounts");
                        return;
                    }
                } catch (NumberFormatException e) {
                    showError("Please enter valid numbers for rent and deposit");
                    return;
                }
            }

            // Generate the document
            currentDocument = DocumentTemplates.generateDocument(selectedDocumentType, data);
            
            // Display results
            displayResults();
            resultsSection.setVisibility(View.VISIBLE);
            
            // Scroll to results
            if (getView() != null) {
                getView().post(() -> resultsSection.requestFocus());
            }

        } catch (Exception e) {
            showError("Error generating document: " + e.getMessage());
        }
    }

    private void displayResults() {
        if (currentDocument == null) return;

        // Update result display
        documentTypeResult.setText(currentDocument.getTitle());
        documentPreview.setText(currentDocument.getPreview());
        
        // Show success message
        if (getContext() != null) {
            Toast.makeText(getContext(), "Document generated successfully!", Toast.LENGTH_SHORT).show();
        }
    }

    private void previewFullDocument() {
        if (currentDocument == null) {
            showError("Please generate a document first");
            return;
        }

        // For now, show the full content in a toast or dialog
        // In a full implementation, this would open a new activity with the full document
        if (getContext() != null) {
            // Create a simple preview dialog or activity
            showDocumentPreview(currentDocument.getContent());
        }
    }

    private void showDocumentPreview(String content) {
        // Simple preview - in a real app, you'd create a proper document viewer
        android.app.AlertDialog.Builder builder = new android.app.AlertDialog.Builder(getContext());
        builder.setTitle("Document Preview")
               .setMessage(content.length() > 500 ? 
                   content.substring(0, 500) + "...\n\n[Full document available for download]" : 
                   content)
               .setPositiveButton("Close", null)
               .show();
    }

    private void downloadDocument() {
        if (currentDocument == null) {
            showError("Please generate a document first");
            return;
        }

        try {
            // Create share intent with the document content
            String shareText = currentDocument.getTitle() + "\n\n" + currentDocument.getContent() + 
                             "\n\nGenerated with RoomFinder Legal Tools";

            Intent shareIntent = new Intent(Intent.ACTION_SEND);
            shareIntent.setType("text/plain");
            shareIntent.putExtra(Intent.EXTRA_TEXT, shareText);
            shareIntent.putExtra(Intent.EXTRA_SUBJECT, currentDocument.getTitle());
            
            startActivity(Intent.createChooser(shareIntent, "Share Document"));

        } catch (Exception e) {
            showError("Error sharing document: " + e.getMessage());
        }
    }

    private void showError(String message) {
        if (getContext() != null) {
            Toast.makeText(getContext(), message, Toast.LENGTH_SHORT).show();
        }
    }
}