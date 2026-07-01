package com.roomfinder.android.models;

import java.util.ArrayList;
import java.util.List;

public class LegalIssue {
    public enum IssueCategory {
        RENT_ISSUES("Rent & Payments"),
        SECURITY_DEPOSITS("Security Deposits"),
        MAINTENANCE_REPAIRS("Maintenance & Repairs"),
        EVICTION("Eviction"),
        PRIVACY_RIGHTS("Privacy Rights"),
        DISCRIMINATION("Discrimination"),
        LEASE_VIOLATIONS("Lease Violations"),
        NOISE_DISPUTES("Noise Disputes"),
        SUBLETTING("Subletting & Roommates"),
        OTHER("Other");

        private final String displayName;

        IssueCategory(String displayName) {
            this.displayName = displayName;
        }

        public String getDisplayName() {
            return displayName;
        }
    }

    public enum Urgency {
        LOW("Low", "#10B981"),
        MEDIUM("Medium", "#F59E0B"),
        HIGH("High", "#EF4444"),
        EMERGENCY("Emergency", "#DC2626");

        private final String displayName;
        private final String color;

        Urgency(String displayName, String color) {
            this.displayName = displayName;
            this.color = color;
        }

        public String getDisplayName() { return displayName; }
        public String getColor() { return color; }
    }

    public enum Status {
        OPEN("Open"),
        IN_PROGRESS("In Progress"),
        RESOLVED("Resolved"),
        ESCALATED("Escalated");

        private final String displayName;

        Status(String displayName) {
            this.displayName = displayName;
        }

        public String getDisplayName() { return displayName; }
    }

    private String issueId;
    private IssueCategory category;
    private String title;
    private String description;
    private Urgency urgency;
    private Status status;
    private String state;
    private String propertyAddress;
    private List<String> recommendations;
    private List<String> nextSteps;
    private List<String> requiredDocuments;
    private double confidenceScore;
    private long createdAt;
    private long lastUpdated;
    private String userId;

    public LegalIssue() {
        this.recommendations = new ArrayList<>();
        this.nextSteps = new ArrayList<>();
        this.requiredDocuments = new ArrayList<>();
        this.createdAt = System.currentTimeMillis();
        this.lastUpdated = this.createdAt;
        this.status = Status.OPEN;
    }

    public LegalIssue(IssueCategory category, String title, String description, Urgency urgency, String state) {
        this();
        this.category = category;
        this.title = title;
        this.description = description;
        this.urgency = urgency;
        this.state = state;
        generateRecommendations();
    }

    public void generateRecommendations() {
        recommendations.clear();
        nextSteps.clear();
        requiredDocuments.clear();

        switch (category) {
            case RENT_ISSUES:
                recommendations.add("Review your lease agreement for rent payment terms");
                recommendations.add("Document all rent payments made");
                recommendations.add("Check state laws regarding late fees and grace periods");
                nextSteps.add("Gather rent payment records");
                nextSteps.add("Contact landlord in writing about the issue");
                nextSteps.add("Consult local tenant rights organization if needed");
                requiredDocuments.add("Lease Agreement");
                requiredDocuments.add("Payment Records");
                requiredDocuments.add("Written Communication");
                break;

            case SECURITY_DEPOSITS:
                recommendations.add("Document property condition at move-in and move-out");
                recommendations.add("Know your state's security deposit laws");
                recommendations.add("Send written request for deposit return");
                nextSteps.add("Take photos of property condition");
                nextSteps.add("Send formal written request");
                nextSteps.add("File complaint if necessary");
                requiredDocuments.add("Move-in Inspection Report");
                requiredDocuments.add("Photos of Property Condition");
                requiredDocuments.add("Security Deposit Receipt");
                break;

            case MAINTENANCE_REPAIRS:
                recommendations.add("Report maintenance issues in writing immediately");
                recommendations.add("Know your rights regarding habitability");
                recommendations.add("Document the problem with photos/videos");
                nextSteps.add("Submit written maintenance request");
                nextSteps.add("Follow up if no response within reasonable time");
                nextSteps.add("Consider legal action for serious habitability issues");
                requiredDocuments.add("Written Maintenance Request");
                requiredDocuments.add("Photos/Videos of Issue");
                requiredDocuments.add("Communication Records");
                break;

            case EVICTION:
                recommendations.add("Respond to eviction notice immediately");
                recommendations.add("Know your state's eviction process and timeline");
                recommendations.add("Seek legal assistance immediately");
                nextSteps.add("File response to eviction notice if required");
                nextSteps.add("Gather all relevant documentation");
                nextSteps.add("Contact legal aid organization");
                requiredDocuments.add("Eviction Notice");
                requiredDocuments.add("Lease Agreement");
                requiredDocuments.add("Payment Records");
                break;

            case PRIVACY_RIGHTS:
                recommendations.add("Know your state's laws about landlord entry");
                recommendations.add("Document unauthorized entries");
                recommendations.add("Send written notice asserting your privacy rights");
                nextSteps.add("Review lease agreement entry provisions");
                nextSteps.add("Document incidents with dates and times");
                nextSteps.add("Send formal notice to landlord");
                requiredDocuments.add("Lease Agreement");
                requiredDocuments.add("Documentation of Incidents");
                requiredDocuments.add("Written Notice to Landlord");
                break;

            case DISCRIMINATION:
                recommendations.add("Document all discriminatory actions or statements");
                recommendations.add("Know your rights under Fair Housing laws");
                recommendations.add("File complaint with appropriate agency");
                nextSteps.add("Document discrimination incidents");
                nextSteps.add("Contact Fair Housing organization");
                nextSteps.add("File formal complaint");
                requiredDocuments.add("Evidence of Discrimination");
                requiredDocuments.add("Witness Statements");
                requiredDocuments.add("Communication Records");
                break;
        }

        // Set confidence score based on category complexity
        confidenceScore = calculateConfidenceScore();
    }

    private double calculateConfidenceScore() {
        double baseScore = 0.7;
        
        // Adjust based on issue complexity
        switch (category) {
            case RENT_ISSUES:
            case MAINTENANCE_REPAIRS:
                baseScore = 0.85;
                break;
            case SECURITY_DEPOSITS:
            case PRIVACY_RIGHTS:
                baseScore = 0.80;
                break;
            case EVICTION:
            case DISCRIMINATION:
                baseScore = 0.70;
                break;
            case LEASE_VIOLATIONS:
            case NOISE_DISPUTES:
                baseScore = 0.75;
                break;
        }

        // Adjust based on urgency
        switch (urgency) {
            case EMERGENCY:
            case HIGH:
                baseScore -= 0.05; // More complex/uncertain
                break;
            case LOW:
                baseScore += 0.05; // Simpler cases
                break;
        }

        return Math.min(0.95, Math.max(0.60, baseScore));
    }

    public String getUrgencyColor() {
        return urgency.getColor();
    }

    public boolean requiresImmediateAction() {
        return urgency == Urgency.EMERGENCY || urgency == Urgency.HIGH;
    }

    public boolean requiresLegalAssistance() {
        return category == IssueCategory.EVICTION || 
               category == IssueCategory.DISCRIMINATION ||
               urgency == Urgency.EMERGENCY;
    }

    public List<String> getRelevantLaws() {
        List<String> laws = new ArrayList<>();
        
        switch (category) {
            case RENT_ISSUES:
                laws.add("State Rent Control Laws");
                laws.add("Late Fee Regulations");
                break;
            case SECURITY_DEPOSITS:
                laws.add("Security Deposit Return Laws");
                laws.add("Interest Requirements");
                break;
            case MAINTENANCE_REPAIRS:
                laws.add("Warranty of Habitability");
                laws.add("Repair and Deduct Laws");
                break;
            case EVICTION:
                laws.add("Unlawful Detainer Laws");
                laws.add("Notice Requirements");
                break;
            case DISCRIMINATION:
                laws.add("Fair Housing Act");
                laws.add("State Anti-Discrimination Laws");
                break;
        }
        
        return laws;
    }

    // Getters and Setters
    public String getIssueId() { return issueId; }
    public void setIssueId(String issueId) { this.issueId = issueId; }

    public IssueCategory getCategory() { return category; }
    public void setCategory(IssueCategory category) { 
        this.category = category; 
        generateRecommendations();
    }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Urgency getUrgency() { return urgency; }
    public void setUrgency(Urgency urgency) { 
        this.urgency = urgency;
        generateRecommendations();
    }

    public Status getStatus() { return status; }
    public void setStatus(Status status) { 
        this.status = status; 
        this.lastUpdated = System.currentTimeMillis();
    }

    public String getState() { return state; }
    public void setState(String state) { this.state = state; }

    public String getPropertyAddress() { return propertyAddress; }
    public void setPropertyAddress(String propertyAddress) { this.propertyAddress = propertyAddress; }

    public List<String> getRecommendations() { return recommendations; }
    public void setRecommendations(List<String> recommendations) { this.recommendations = recommendations; }

    public List<String> getNextSteps() { return nextSteps; }
    public void setNextSteps(List<String> nextSteps) { this.nextSteps = nextSteps; }

    public List<String> getRequiredDocuments() { return requiredDocuments; }
    public void setRequiredDocuments(List<String> requiredDocuments) { this.requiredDocuments = requiredDocuments; }

    public double getConfidenceScore() { return confidenceScore; }
    public void setConfidenceScore(double confidenceScore) { this.confidenceScore = confidenceScore; }

    public long getCreatedAt() { return createdAt; }
    public void setCreatedAt(long createdAt) { this.createdAt = createdAt; }

    public long getLastUpdated() { return lastUpdated; }
    public void setLastUpdated(long lastUpdated) { this.lastUpdated = lastUpdated; }

    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }
}