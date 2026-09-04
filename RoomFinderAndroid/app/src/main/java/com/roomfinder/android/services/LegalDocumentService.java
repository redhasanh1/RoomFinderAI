package com.roomfinder.android.services;

import com.roomfinder.android.models.LegalDocument;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

public class LegalDocumentService {
    
    private static final Random random = new Random();
    
    public static List<LegalDocument> getAvailableTemplates() {
        List<LegalDocument> templates = new ArrayList<>();
        
        // Lease Agreement Templates
        templates.add(createTemplate(
            LegalDocument.DocumentType.LEASE_AGREEMENT,
            "Standard Residential Lease Agreement",
            "Comprehensive lease agreement template suitable for most residential rentals",
            "General"
        ));
        
        templates.add(createTemplate(
            LegalDocument.DocumentType.LEASE_AGREEMENT,
            "Month-to-Month Rental Agreement",
            "Flexible month-to-month lease agreement template",
            "General"
        ));
        
        // Notice Templates
        templates.add(createTemplate(
            LegalDocument.DocumentType.TERMINATION_NOTICE,
            "30-Day Notice to Terminate Tenancy",
            "Standard 30-day notice for ending month-to-month tenancy",
            "General"
        ));
        
        templates.add(createTemplate(
            LegalDocument.DocumentType.TERMINATION_NOTICE,
            "End of Lease Notice",
            "Notice for not renewing fixed-term lease",
            "General"
        ));
        
        // Complaint Letters
        templates.add(createTemplate(
            LegalDocument.DocumentType.COMPLAINT_LETTER,
            "Maintenance Request Letter",
            "Formal letter requesting maintenance or repairs",
            "General"
        ));
        
        templates.add(createTemplate(
            LegalDocument.DocumentType.COMPLAINT_LETTER,
            "Noise Complaint Letter",
            "Letter addressing noise disturbances",
            "General"
        ));
        
        // Security Deposit
        templates.add(createTemplate(
            LegalDocument.DocumentType.SECURITY_DEPOSIT_REQUEST,
            "Security Deposit Return Request",
            "Formal request for return of security deposit",
            "General"
        ));
        
        // Rent Issues
        templates.add(createTemplate(
            LegalDocument.DocumentType.RENT_INCREASE_NOTICE,
            "Rent Increase Notice (Landlord)",
            "Notice from landlord for rent increase",
            "General"
        ));
        
        // Maintenance
        templates.add(createTemplate(
            LegalDocument.DocumentType.MAINTENANCE_REQUEST,
            "Emergency Maintenance Request",
            "Urgent maintenance request form",
            "General"
        ));
        
        // Roommate/Subletting
        templates.add(createTemplate(
            LegalDocument.DocumentType.SUBLETTING_AGREEMENT,
            "Subletting Agreement",
            "Agreement between tenant and subtenant",
            "General"
        ));
        
        templates.add(createTemplate(
            LegalDocument.DocumentType.ROOMMATE_AGREEMENT,
            "Roommate Agreement",
            "Agreement between roommates sharing rental property",
            "General"
        ));
        
        return templates;
    }
    
    private static LegalDocument createTemplate(LegalDocument.DocumentType type, String title, String description, String state) {
        LegalDocument template = new LegalDocument(type, title, description, state);
        template.setDocumentId(generateDocumentId());
        template.setTemplate(true);
        return template;
    }
    
    public static List<LegalDocument> getTemplatesByType(LegalDocument.DocumentType type) {
        List<LegalDocument> allTemplates = getAvailableTemplates();
        List<LegalDocument> filtered = new ArrayList<>();
        
        for (LegalDocument template : allTemplates) {
            if (template.getType() == type) {
                filtered.add(template);
            }
        }
        
        return filtered;
    }
    
    public static List<LegalDocument> searchTemplates(String query) {
        List<LegalDocument> allTemplates = getAvailableTemplates();
        List<LegalDocument> filtered = new ArrayList<>();
        
        String lowerQuery = query.toLowerCase();
        
        for (LegalDocument template : allTemplates) {
            if (template.getTitle().toLowerCase().contains(lowerQuery) ||
                template.getDescription().toLowerCase().contains(lowerQuery) ||
                template.getType().getDisplayName().toLowerCase().contains(lowerQuery)) {
                filtered.add(template);
            }
        }
        
        return filtered;
    }
    
    public static LegalDocument createDocumentFromTemplate(LegalDocument template) {
        LegalDocument newDocument = new LegalDocument(template.getType(), template.getTitle(), template.getDescription(), template.getState());
        newDocument.setDocumentId(generateDocumentId());
        newDocument.setTemplate(false);
        newDocument.setContent(template.getContent());
        
        // Copy fields from template
        for (LegalDocument.DocumentField templateField : template.getRequiredFields()) {
            LegalDocument.DocumentField newField = new LegalDocument.DocumentField();
            newField.fieldId = templateField.fieldId;
            newField.fieldName = templateField.fieldName;
            newField.fieldType = templateField.fieldType;
            newField.placeholder = templateField.placeholder;
            newField.isRequired = templateField.isRequired;
            newField.options = new ArrayList<>(templateField.options);
            
            newDocument.getRequiredFields().add(newField);
        }
        
        return newDocument;
    }
    
    public static String generateDocument(LegalDocument document) {
        if (!document.isComplete()) {
            return null;
        }
        
        return document.generateDocument();
    }
    
    public static boolean validateDocument(LegalDocument document) {
        // Basic validation
        if (document.getTitle() == null || document.getTitle().trim().isEmpty()) {
            return false;
        }
        
        // Check required fields
        for (LegalDocument.DocumentField field : document.getRequiredFields()) {
            if (field.isRequired && (field.value == null || field.value.trim().isEmpty())) {
                return false;
            }
        }
        
        // Type-specific validation
        switch (document.getType()) {
            case LEASE_AGREEMENT:
                return validateLeaseAgreement(document);
            case TERMINATION_NOTICE:
                return validateTerminationNotice(document);
            case SECURITY_DEPOSIT_REQUEST:
                return validateSecurityDepositRequest(document);
            default:
                return true;
        }
    }
    
    private static boolean validateLeaseAgreement(LegalDocument document) {
        // Validate lease term is positive
        String leaseTerm = getFieldValue(document, "lease_term");
        if (leaseTerm != null && !leaseTerm.isEmpty()) {
            try {
                int term = Integer.parseInt(leaseTerm);
                if (term <= 0) return false;
            } catch (NumberFormatException e) {
                return false;
            }
        }
        
        // Validate rent amount is positive
        String rent = getFieldValue(document, "monthly_rent");
        if (rent != null && !rent.isEmpty()) {
            try {
                double rentAmount = Double.parseDouble(rent);
                if (rentAmount <= 0) return false;
            } catch (NumberFormatException e) {
                return false;
            }
        }
        
        return true;
    }
    
    private static boolean validateTerminationNotice(LegalDocument document) {
        // Validate notice period is appropriate
        String noticePeriod = getFieldValue(document, "notice_period");
        if (noticePeriod != null && !noticePeriod.isEmpty()) {
            try {
                int days = Integer.parseInt(noticePeriod);
                if (days < 3 || days > 365) return false; // Reasonable range
            } catch (NumberFormatException e) {
                return false;
            }
        }
        
        return true;
    }
    
    private static boolean validateSecurityDepositRequest(LegalDocument document) {
        // Validate deposit amount is positive
        String deposit = getFieldValue(document, "deposit_amount");
        if (deposit != null && !deposit.isEmpty()) {
            try {
                double amount = Double.parseDouble(deposit);
                if (amount <= 0) return false;
            } catch (NumberFormatException e) {
                return false;
            }
        }
        
        return true;
    }
    
    private static String getFieldValue(LegalDocument document, String fieldId) {
        for (LegalDocument.DocumentField field : document.getRequiredFields()) {
            if (field.fieldId.equals(fieldId)) {
                return field.value;
            }
        }
        return null;
    }
    
    public static List<String> getDocumentSuggestions(LegalDocument.DocumentType type, String state) {
        List<String> suggestions = new ArrayList<>();
        
        switch (type) {
            case LEASE_AGREEMENT:
                suggestions.add("Include all required disclosures for " + state);
                suggestions.add("Specify maintenance responsibilities clearly");
                suggestions.add("Include pet policy if applicable");
                suggestions.add("Add late fee policy within legal limits");
                break;
                
            case TERMINATION_NOTICE:
                suggestions.add("Verify notice period requirements for " + state);
                suggestions.add("Include specific termination date");
                suggestions.add("Keep copy for your records");
                suggestions.add("Consider certified mail delivery");
                break;
                
            case COMPLAINT_LETTER:
                suggestions.add("Document the issue with photos if possible");
                suggestions.add("Request reasonable timeline for resolution");
                suggestions.add("Keep copies of all correspondence");
                suggestions.add("Follow up in writing if no response");
                break;
                
            case SECURITY_DEPOSIT_REQUEST:
                suggestions.add("Include forwarding address for deposit return");
                suggestions.add("Reference move-out inspection if available");
                suggestions.add("Know your state's deposit return timeline");
                suggestions.add("Request itemized list if deductions are made");
                break;
        }
        
        return suggestions;
    }
    
    public static double calculateDocumentComplexity(LegalDocument document) {
        double complexity = 0.0;
        
        // Base complexity by type
        switch (document.getType()) {
            case LEASE_AGREEMENT:
                complexity = 0.8;
                break;
            case TERMINATION_NOTICE:
                complexity = 0.3;
                break;
            case COMPLAINT_LETTER:
                complexity = 0.4;
                break;
            case SECURITY_DEPOSIT_REQUEST:
                complexity = 0.3;
                break;
            case RENT_INCREASE_NOTICE:
                complexity = 0.5;
                break;
            case MAINTENANCE_REQUEST:
                complexity = 0.2;
                break;
            case SUBLETTING_AGREEMENT:
                complexity = 0.7;
                break;
            case ROOMMATE_AGREEMENT:
                complexity = 0.6;
                break;
        }
        
        // Adjust based on number of fields
        int totalFields = document.getRequiredFields().size();
        complexity += totalFields * 0.02;
        
        // Adjust based on completion
        int completedFields = 0;
        for (LegalDocument.DocumentField field : document.getRequiredFields()) {
            if (field.value != null && !field.value.trim().isEmpty()) {
                completedFields++;
            }
        }
        
        double completionRatio = (double) completedFields / totalFields;
        complexity = complexity * (1.0 - completionRatio * 0.2); // Reduce complexity as completion increases
        
        return Math.min(1.0, Math.max(0.1, complexity));
    }
    
    private static String generateDocumentId() {
        return "DOC_" + System.currentTimeMillis() + "_" + random.nextInt(1000);
    }
}