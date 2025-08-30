package com.roomfinder.android.models;

import java.util.ArrayList;
import java.util.List;

public class LegalResource {
    public enum ResourceType {
        FORM("Legal Form"),
        GUIDE("Guide"),
        FAQ("FAQ"),
        CALCULATOR("Calculator"),
        CHECKLIST("Checklist"),
        TEMPLATE("Template"),
        VIDEO("Video"),
        ARTICLE("Article");

        private final String displayName;

        ResourceType(String displayName) {
            this.displayName = displayName;
        }

        public String getDisplayName() { return displayName; }
    }

    public enum ResourceCategory {
        LEASE_AGREEMENTS("Lease Agreements"),
        RENT_ISSUES("Rent Issues"),
        SECURITY_DEPOSITS("Security Deposits"),
        MAINTENANCE("Maintenance & Repairs"),
        EVICTION("Eviction"),
        TENANT_RIGHTS("Tenant Rights"),
        DISCRIMINATION("Discrimination"),
        MOVING("Moving In/Out"),
        ROOMMATES("Roommate Issues"),
        LEGAL_PROCESS("Legal Process");

        private final String displayName;

        ResourceCategory(String displayName) {
            this.displayName = displayName;
        }

        public String getDisplayName() { return displayName; }
    }

    private String resourceId;
    private ResourceType type;
    private ResourceCategory category;
    private String title;
    private String description;
    private String content;
    private String downloadUrl;
    private List<String> tags;
    private String state;
    private boolean isFree;
    private int downloadCount;
    private double rating;
    private int ratingCount;
    private long createdAt;
    private long lastUpdated;
    private String author;
    private boolean isFeatured;
    private String fileSize;
    private String fileFormat;

    public LegalResource() {
        this.tags = new ArrayList<>();
        this.createdAt = System.currentTimeMillis();
        this.lastUpdated = this.createdAt;
        this.isFree = true;
        this.rating = 0.0;
        this.ratingCount = 0;
    }

    public LegalResource(ResourceType type, ResourceCategory category, String title, String description) {
        this();
        this.type = type;
        this.category = category;
        this.title = title;
        this.description = description;
        initializeDefaultContent();
    }

    private void initializeDefaultContent() {
        switch (type) {
            case FORM:
                initializeFormContent();
                break;
            case GUIDE:
                initializeGuideContent();
                break;
            case FAQ:
                initializeFAQContent();
                break;
            case CALCULATOR:
                initializeCalculatorContent();
                break;
            case CHECKLIST:
                initializeChecklistContent();
                break;
        }
    }

    private void initializeFormContent() {
        switch (category) {
            case LEASE_AGREEMENTS:
                content = createLeaseAgreementForm();
                fileFormat = "PDF";
                break;
            case MAINTENANCE:
                content = createMaintenanceRequestForm();
                fileFormat = "PDF";
                break;
            case SECURITY_DEPOSITS:
                content = createSecurityDepositForm();
                fileFormat = "PDF";
                break;
        }
    }

    private void initializeGuideContent() {
        switch (category) {
            case TENANT_RIGHTS:
                content = createTenantRightsGuide();
                break;
            case EVICTION:
                content = createEvictionGuide();
                break;
            case MOVING:
                content = createMovingGuide();
                break;
        }
    }

    private void initializeFAQContent() {
        switch (category) {
            case RENT_ISSUES:
                content = createRentFAQ();
                break;
            case SECURITY_DEPOSITS:
                content = createSecurityDepositFAQ();
                break;
        }
    }

    private void initializeCalculatorContent() {
        switch (category) {
            case SECURITY_DEPOSITS:
                content = createSecurityDepositCalculator();
                break;
            case RENT_ISSUES:
                content = createRentCalculator();
                break;
        }
    }

    private void initializeChecklistContent() {
        switch (category) {
            case MOVING:
                content = createMovingChecklist();
                break;
            case LEASE_AGREEMENTS:
                content = createLeaseReviewChecklist();
                break;
        }
    }

    // Sample content generators
    private String createLeaseAgreementForm() {
        return "RESIDENTIAL LEASE AGREEMENT TEMPLATE\n\n" +
               "This template provides a standard residential lease agreement format.\n" +
               "Please customize for your specific state and situation.\n\n" +
               "[Form fields and legal language would be included here]";
    }

    private String createMaintenanceRequestForm() {
        return "MAINTENANCE REQUEST FORM\n\n" +
               "Use this form to formally request maintenance or repairs from your landlord.\n\n" +
               "Date: _____________\n" +
               "Tenant Name: _____________\n" +
               "Property Address: _____________\n" +
               "Issue Description: _____________\n" +
               "Urgency Level: [ ] Low [ ] Medium [ ] High [ ] Emergency\n" +
               "Tenant Signature: _____________";
    }

    private String createSecurityDepositForm() {
        return "SECURITY DEPOSIT RETURN REQUEST\n\n" +
               "Use this form to request the return of your security deposit.\n\n" +
               "[Form fields and instructions would be included here]";
    }

    private String createTenantRightsGuide() {
        return "TENANT RIGHTS GUIDE\n\n" +
               "1. Right to Habitable Housing\n" +
               "2. Privacy Rights\n" +
               "3. Protection from Discrimination\n" +
               "4. Security Deposit Rights\n" +
               "5. Eviction Protection\n\n" +
               "[Detailed explanations would follow]";
    }

    private String createEvictionGuide() {
        return "EVICTION PROCESS GUIDE\n\n" +
               "Understanding Your Rights During Eviction:\n" +
               "1. Notice Requirements\n" +
               "2. Court Process\n" +
               "3. Your Rights\n" +
               "4. Legal Resources\n\n" +
               "[Detailed step-by-step guide would follow]";
    }

    private String createMovingGuide() {
        return "MOVING IN/OUT GUIDE\n\n" +
               "Moving In Checklist:\n" +
               "• Document property condition\n" +
               "• Review lease thoroughly\n" +
               "• Understand policies\n\n" +
               "Moving Out Checklist:\n" +
               "• Clean thoroughly\n" +
               "• Document condition\n" +
               "• Request deposit return\n\n" +
               "[Complete guide would follow]";
    }

    private String createRentFAQ() {
        return "RENT ISSUES - FREQUENTLY ASKED QUESTIONS\n\n" +
               "Q: How much notice is required for rent increases?\n" +
               "A: Varies by state, typically 30-60 days for month-to-month leases.\n\n" +
               "Q: What happens if I pay rent late?\n" +
               "A: Late fees may apply as specified in your lease agreement.\n\n" +
               "[Additional FAQs would follow]";
    }

    private String createSecurityDepositFAQ() {
        return "SECURITY DEPOSIT - FREQUENTLY ASKED QUESTIONS\n\n" +
               "Q: When should I get my security deposit back?\n" +
               "A: Typically within 14-60 days after move-out, depending on state law.\n\n" +
               "Q: What can be deducted from my security deposit?\n" +
               "A: Unpaid rent, damages beyond normal wear and tear, and cleaning fees.\n\n" +
               "[Additional FAQs would follow]";
    }

    private String createSecurityDepositCalculator() {
        return "Security Deposit Calculator\n\n" +
               "This tool helps calculate potential deductions and return amounts.\n" +
               "[Calculator interface would be implemented in the UI]";
    }

    private String createRentCalculator() {
        return "Rent Calculator\n\n" +
               "Calculate late fees, prorated rent, and payment schedules.\n" +
               "[Calculator interface would be implemented in the UI]";
    }

    private String createMovingChecklist() {
        return "MOVING CHECKLIST\n\n" +
               "Before Moving In:\n" +
               "☐ Review lease agreement\n" +
               "☐ Document property condition\n" +
               "☐ Take photos/video\n" +
               "☐ Test all appliances\n" +
               "☐ Check for damages\n\n" +
               "Before Moving Out:\n" +
               "☐ Give proper notice\n" +
               "☐ Clean thoroughly\n" +
               "☐ Document final condition\n" +
               "☐ Return all keys\n" +
               "☐ Provide forwarding address";
    }

    private String createLeaseReviewChecklist() {
        return "LEASE AGREEMENT REVIEW CHECKLIST\n\n" +
               "Essential Items to Check:\n" +
               "☐ Rent amount and due date\n" +
               "☐ Security deposit amount\n" +
               "☐ Lease term and renewal\n" +
               "☐ Pet policies\n" +
               "☐ Maintenance responsibilities\n" +
               "☐ Entry notice requirements\n" +
               "☐ Termination procedures\n" +
               "☐ Late fee policies";
    }

    // Static factory methods for common resources
    public static List<LegalResource> getPopularResources() {
        List<LegalResource> resources = new ArrayList<>();
        
        resources.add(new LegalResource(ResourceType.FORM, ResourceCategory.LEASE_AGREEMENTS, 
            "Standard Lease Agreement Template", "Customizable lease agreement template"));
        resources.add(new LegalResource(ResourceType.GUIDE, ResourceCategory.TENANT_RIGHTS,
            "Know Your Rights Guide", "Comprehensive guide to tenant rights"));
        resources.add(new LegalResource(ResourceType.CHECKLIST, ResourceCategory.MOVING,
            "Moving In/Out Checklist", "Essential checklist for moving"));
        resources.add(new LegalResource(ResourceType.CALCULATOR, ResourceCategory.SECURITY_DEPOSITS,
            "Security Deposit Calculator", "Calculate expected deposit return"));
        resources.add(new LegalResource(ResourceType.FAQ, ResourceCategory.RENT_ISSUES,
            "Rent Issues FAQ", "Common questions about rent payments"));
        
        return resources;
    }

    public static List<LegalResource> getResourcesByCategory(ResourceCategory category) {
        List<LegalResource> allResources = getPopularResources();
        List<LegalResource> filtered = new ArrayList<>();
        
        for (LegalResource resource : allResources) {
            if (resource.getCategory() == category) {
                filtered.add(resource);
            }
        }
        
        return filtered;
    }

    // Helper methods
    public void incrementDownloadCount() {
        this.downloadCount++;
    }

    public void addRating(double rating) {
        double totalRating = this.rating * this.ratingCount;
        this.ratingCount++;
        this.rating = (totalRating + rating) / this.ratingCount;
    }

    public String getFormattedRating() {
        return String.format("%.1f (%d reviews)", rating, ratingCount);
    }

    public boolean isRecommended() {
        return rating >= 4.0 && ratingCount >= 10;
    }

    // Getters and Setters
    public String getResourceId() { return resourceId; }
    public void setResourceId(String resourceId) { this.resourceId = resourceId; }

    public ResourceType getType() { return type; }
    public void setType(ResourceType type) { this.type = type; }

    public ResourceCategory getCategory() { return category; }
    public void setCategory(ResourceCategory category) { this.category = category; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }

    public String getDownloadUrl() { return downloadUrl; }
    public void setDownloadUrl(String downloadUrl) { this.downloadUrl = downloadUrl; }

    public List<String> getTags() { return tags; }
    public void setTags(List<String> tags) { this.tags = tags; }

    public String getState() { return state; }
    public void setState(String state) { this.state = state; }

    public boolean isFree() { return isFree; }
    public void setFree(boolean free) { isFree = free; }

    public int getDownloadCount() { return downloadCount; }
    public void setDownloadCount(int downloadCount) { this.downloadCount = downloadCount; }

    public double getRating() { return rating; }
    public void setRating(double rating) { this.rating = rating; }

    public int getRatingCount() { return ratingCount; }
    public void setRatingCount(int ratingCount) { this.ratingCount = ratingCount; }

    public long getCreatedAt() { return createdAt; }
    public void setCreatedAt(long createdAt) { this.createdAt = createdAt; }

    public long getLastUpdated() { return lastUpdated; }
    public void setLastUpdated(long lastUpdated) { this.lastUpdated = lastUpdated; }

    public String getAuthor() { return author; }
    public void setAuthor(String author) { this.author = author; }

    public boolean isFeatured() { return isFeatured; }
    public void setFeatured(boolean featured) { isFeatured = featured; }

    public String getFileSize() { return fileSize; }
    public void setFileSize(String fileSize) { this.fileSize = fileSize; }

    public String getFileFormat() { return fileFormat; }
    public void setFileFormat(String fileFormat) { this.fileFormat = fileFormat; }
}