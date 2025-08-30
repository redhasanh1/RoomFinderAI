package com.roomfinder.android.models;

import java.util.ArrayList;
import java.util.List;

public class LegalDocument {
    public enum DocumentType {
        LEASE_AGREEMENT("Lease Agreement"),
        TERMINATION_NOTICE("Termination Notice"),
        COMPLAINT_LETTER("Complaint Letter"),
        SECURITY_DEPOSIT_REQUEST("Security Deposit Request"),
        RENT_INCREASE_NOTICE("Rent Increase Notice"),
        MAINTENANCE_REQUEST("Maintenance Request"),
        SUBLETTING_AGREEMENT("Subletting Agreement"),
        ROOMMATE_AGREEMENT("Roommate Agreement");

        private final String displayName;

        DocumentType(String displayName) {
            this.displayName = displayName;
        }

        public String getDisplayName() {
            return displayName;
        }
    }

    private String documentId;
    private DocumentType type;
    private String title;
    private String description;
    private String state;
    private String content;
    private List<DocumentField> requiredFields;
    private boolean isTemplate;
    private long createdAt;
    private long lastModified;
    private String createdBy;
    private boolean isFavorite;

    public static class DocumentField {
        public String fieldId;
        public String fieldName;
        public String fieldType; // text, date, number, dropdown, checkbox
        public String placeholder;
        public boolean isRequired;
        public List<String> options; // for dropdown fields
        public String value;

        public DocumentField() {
            this.options = new ArrayList<>();
        }

        public DocumentField(String fieldId, String fieldName, String fieldType, boolean isRequired) {
            this();
            this.fieldId = fieldId;
            this.fieldName = fieldName;
            this.fieldType = fieldType;
            this.isRequired = isRequired;
        }
    }

    public LegalDocument() {
        this.requiredFields = new ArrayList<>();
        this.createdAt = System.currentTimeMillis();
        this.lastModified = this.createdAt;
    }

    public LegalDocument(DocumentType type, String title, String description, String state) {
        this();
        this.type = type;
        this.title = title;
        this.description = description;
        this.state = state;
        this.isTemplate = true;
        initializeDefaultFields();
    }

    private void initializeDefaultFields() {
        requiredFields.clear();
        
        // Common fields for all documents
        requiredFields.add(new DocumentField("tenant_name", "Tenant Name", "text", true));
        requiredFields.add(new DocumentField("landlord_name", "Landlord Name", "text", true));
        requiredFields.add(new DocumentField("property_address", "Property Address", "text", true));
        requiredFields.add(new DocumentField("date", "Date", "date", true));

        // Document-specific fields
        switch (type) {
            case LEASE_AGREEMENT:
                requiredFields.add(new DocumentField("lease_term", "Lease Term (months)", "number", true));
                requiredFields.add(new DocumentField("monthly_rent", "Monthly Rent", "number", true));
                requiredFields.add(new DocumentField("security_deposit", "Security Deposit", "number", true));
                requiredFields.add(new DocumentField("move_in_date", "Move-in Date", "date", true));
                break;
                
            case TERMINATION_NOTICE:
                requiredFields.add(new DocumentField("termination_date", "Termination Date", "date", true));
                requiredFields.add(new DocumentField("notice_period", "Notice Period (days)", "number", true));
                requiredFields.add(new DocumentField("reason", "Reason for Termination", "text", false));
                break;
                
            case COMPLAINT_LETTER:
                requiredFields.add(new DocumentField("issue_description", "Issue Description", "text", true));
                requiredFields.add(new DocumentField("incident_date", "Incident Date", "date", true));
                requiredFields.add(new DocumentField("requested_action", "Requested Action", "text", true));
                break;
                
            case SECURITY_DEPOSIT_REQUEST:
                requiredFields.add(new DocumentField("deposit_amount", "Security Deposit Amount", "number", true));
                requiredFields.add(new DocumentField("move_out_date", "Move-out Date", "date", true));
                requiredFields.add(new DocumentField("forwarding_address", "Forwarding Address", "text", true));
                break;
                
            case RENT_INCREASE_NOTICE:
                requiredFields.add(new DocumentField("current_rent", "Current Rent", "number", true));
                requiredFields.add(new DocumentField("new_rent", "New Rent Amount", "number", true));
                requiredFields.add(new DocumentField("effective_date", "Effective Date", "date", true));
                break;
                
            case MAINTENANCE_REQUEST:
                requiredFields.add(new DocumentField("maintenance_issue", "Maintenance Issue", "text", true));
                requiredFields.add(new DocumentField("urgency", "Urgency Level", "dropdown", true));
                DocumentField urgencyField = requiredFields.get(requiredFields.size() - 1);
                urgencyField.options.add("Low");
                urgencyField.options.add("Medium");
                urgencyField.options.add("High");
                urgencyField.options.add("Emergency");
                break;
        }
    }

    public String generateDocument() {
        if (content == null || content.isEmpty()) {
            return generateTemplateContent();
        }
        return replaceFieldPlaceholders(content);
    }

    private String generateTemplateContent() {
        StringBuilder template = new StringBuilder();
        
        switch (type) {
            case LEASE_AGREEMENT:
                template.append("RESIDENTIAL LEASE AGREEMENT\n\n");
                template.append("This lease agreement is made between {{landlord_name}} (Landlord) ");
                template.append("and {{tenant_name}} (Tenant) for the property located at {{property_address}}.\n\n");
                template.append("Term: {{lease_term}} months\n");
                template.append("Monthly Rent: ${{monthly_rent}}\n");
                template.append("Security Deposit: ${{security_deposit}}\n");
                template.append("Move-in Date: {{move_in_date}}\n\n");
                template.append("This agreement is governed by the laws of {{state}}.\n\n");
                template.append("Date: {{date}}\n\n");
                template.append("Landlord Signature: ________________\n");
                template.append("Tenant Signature: ________________");
                break;
                
            case TERMINATION_NOTICE:
                template.append("NOTICE TO TERMINATE TENANCY\n\n");
                template.append("To: {{landlord_name}}\n");
                template.append("From: {{tenant_name}}\n");
                template.append("Property: {{property_address}}\n\n");
                template.append("Please take notice that I will terminate my tenancy ");
                template.append("on {{termination_date}}, providing {{notice_period}} days notice ");
                template.append("as required by law.\n\n");
                if (getFieldValue("reason") != null && !getFieldValue("reason").isEmpty()) {
                    template.append("Reason: {{reason}}\n\n");
                }
                template.append("Date: {{date}}\n\n");
                template.append("Tenant Signature: ________________");
                break;
                
            case COMPLAINT_LETTER:
                template.append("FORMAL COMPLAINT\n\n");
                template.append("Date: {{date}}\n\n");
                template.append("To: {{landlord_name}}\n");
                template.append("From: {{tenant_name}}\n");
                template.append("Property: {{property_address}}\n\n");
                template.append("I am writing to formally complain about the following issue:\n\n");
                template.append("{{issue_description}}\n\n");
                template.append("This incident occurred on {{incident_date}}.\n\n");
                template.append("I request the following action: {{requested_action}}\n\n");
                template.append("Please respond within a reasonable time frame.\n\n");
                template.append("Sincerely,\n{{tenant_name}}");
                break;
        }
        
        return replaceFieldPlaceholders(template.toString());
    }

    private String replaceFieldPlaceholders(String template) {
        String result = template;
        for (DocumentField field : requiredFields) {
            String placeholder = "{{" + field.fieldId + "}}";
            String value = field.value != null ? field.value : "[" + field.fieldName + "]";
            result = result.replace(placeholder, value);
        }
        return result;
    }

    private String getFieldValue(String fieldId) {
        for (DocumentField field : requiredFields) {
            if (field.fieldId.equals(fieldId)) {
                return field.value;
            }
        }
        return null;
    }

    public void setFieldValue(String fieldId, String value) {
        for (DocumentField field : requiredFields) {
            if (field.fieldId.equals(fieldId)) {
                field.value = value;
                break;
            }
        }
        this.lastModified = System.currentTimeMillis();
    }

    public boolean isComplete() {
        for (DocumentField field : requiredFields) {
            if (field.isRequired && (field.value == null || field.value.trim().isEmpty())) {
                return false;
            }
        }
        return true;
    }

    // Getters and Setters
    public String getDocumentId() { return documentId; }
    public void setDocumentId(String documentId) { this.documentId = documentId; }

    public DocumentType getType() { return type; }
    public void setType(DocumentType type) { this.type = type; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getState() { return state; }
    public void setState(String state) { this.state = state; }

    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }

    public List<DocumentField> getRequiredFields() { return requiredFields; }
    public void setRequiredFields(List<DocumentField> requiredFields) { this.requiredFields = requiredFields; }

    public boolean isTemplate() { return isTemplate; }
    public void setTemplate(boolean template) { isTemplate = template; }

    public long getCreatedAt() { return createdAt; }
    public void setCreatedAt(long createdAt) { this.createdAt = createdAt; }

    public long getLastModified() { return lastModified; }
    public void setLastModified(long lastModified) { this.lastModified = lastModified; }

    public String getCreatedBy() { return createdBy; }
    public void setCreatedBy(String createdBy) { this.createdBy = createdBy; }

    public boolean isFavorite() { return isFavorite; }
    public void setFavorite(boolean favorite) { isFavorite = favorite; }
}