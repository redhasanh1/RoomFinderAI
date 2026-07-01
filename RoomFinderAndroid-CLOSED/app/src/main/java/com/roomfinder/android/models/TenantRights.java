package com.roomfinder.android.models;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class TenantRights {
    public enum RightCategory {
        RENT_PAYMENT("Rent & Payment Rights"),
        SECURITY_DEPOSITS("Security Deposit Rights"),
        HABITABILITY("Habitability Rights"),
        PRIVACY("Privacy Rights"),
        DISCRIMINATION("Anti-Discrimination Rights"),
        EVICTION_PROTECTION("Eviction Protection"),
        REPAIRS_MAINTENANCE("Repair & Maintenance Rights"),
        LEASE_TERMS("Lease Agreement Rights");

        private final String displayName;

        RightCategory(String displayName) {
            this.displayName = displayName;
        }

        public String getDisplayName() { return displayName; }
    }

    private String state;
    private String city;
    private RightCategory category;
    private String title;
    private String description;
    private List<String> keyPoints;
    private List<String> exceptions;
    private Map<String, String> stateLaws;
    private List<String> relatedResources;
    private boolean isStatutory;
    private String lastUpdated;

    public TenantRights() {
        this.keyPoints = new ArrayList<>();
        this.exceptions = new ArrayList<>();
        this.stateLaws = new HashMap<>();
        this.relatedResources = new ArrayList<>();
    }

    public TenantRights(String state, RightCategory category) {
        this();
        this.state = state;
        this.category = category;
        initializeRightsForState();
    }

    private void initializeRightsForState() {
        switch (category) {
            case RENT_PAYMENT:
                initializeRentRights();
                break;
            case SECURITY_DEPOSITS:
                initializeSecurityDepositRights();
                break;
            case HABITABILITY:
                initializeHabitabilityRights();
                break;
            case PRIVACY:
                initializePrivacyRights();
                break;
            case DISCRIMINATION:
                initializeDiscriminationRights();
                break;
            case EVICTION_PROTECTION:
                initializeEvictionRights();
                break;
            case REPAIRS_MAINTENANCE:
                initializeRepairRights();
                break;
            case LEASE_TERMS:
                initializeLeaseRights();
                break;
        }
    }

    private void initializeRentRights() {
        title = "Rent Payment Rights";
        description = "Your rights regarding rent payments, increases, and related fees.";
        
        keyPoints.add("Grace period for late rent varies by state (typically 3-5 days)");
        keyPoints.add("Late fees must be reasonable and specified in lease");
        keyPoints.add("Rent increases require proper notice (usually 30-60 days)");
        keyPoints.add("Partial rent payments may be accepted at landlord's discretion");
        keyPoints.add("Rent control laws may limit increase amounts in some cities");
        
        exceptions.add("Emergency situations may allow immediate rent increases");
        exceptions.add("Month-to-month tenancies may have different notice requirements");
        
        stateLaws.put("California", "Civil Code § 1946.1 - 30 days notice for rent increases under 10%");
        stateLaws.put("New York", "Real Property Law § 226-c - Rent stabilization requirements");
        stateLaws.put("Texas", "Property Code § 92.019 - Late fee limitations");
        
        relatedResources.add("State Rent Control Board");
        relatedResources.add("Local Housing Authority");
        relatedResources.add("Tenant Rights Organizations");
    }

    private void initializeSecurityDepositRights() {
        title = "Security Deposit Rights";
        description = "Your rights regarding security deposits, returns, and deductions.";
        
        keyPoints.add("Security deposits must be returned within 14-60 days (varies by state)");
        keyPoints.add("Landlord must provide itemized list of deductions");
        keyPoints.add("Normal wear and tear cannot be deducted");
        keyPoints.add("Some states require deposits be held in separate account");
        keyPoints.add("Interest may be required on deposits in some states");
        
        exceptions.add("Damage beyond normal wear and tear is deductible");
        exceptions.add("Unpaid rent can be deducted from deposit");
        
        stateLaws.put("California", "Civil Code § 1950.5 - 21 days return, itemized deductions required");
        stateLaws.put("Florida", "Florida Statutes § 83.49 - 15-60 days return period");
        stateLaws.put("Illinois", "765 ILCS 710/1 - Interest required on deposits");
        
        relatedResources.add("State Consumer Protection Agency");
        relatedResources.add("Small Claims Court");
        relatedResources.add("Legal Aid Organizations");
    }

    private void initializeHabitabilityRights() {
        title = "Habitability Rights";
        description = "Your right to live in safe, habitable housing conditions.";
        
        keyPoints.add("Landlord must maintain property in habitable condition");
        keyPoints.add("Essential services (heat, water, electricity) must be provided");
        keyPoints.add("Property must meet local building and health codes");
        keyPoints.add("Serious defects that affect health/safety must be repaired");
        keyPoints.add("Tenant may have right to withhold rent or repair and deduct");
        
        exceptions.add("Tenant-caused damage is not landlord's responsibility");
        exceptions.add("Some cosmetic issues may not affect habitability");
        
        stateLaws.put("California", "Civil Code § 1941.1 - Warranty of habitability");
        stateLaws.put("New York", "Multiple Dwelling Law - Habitability standards");
        stateLaws.put("Texas", "Property Code § 92.052 - Landlord's duty to repair");
        
        relatedResources.add("Local Building Department");
        relatedResources.add("Health Department");
        relatedResources.add("Code Enforcement");
    }

    private void initializePrivacyRights() {
        title = "Privacy Rights";
        description = "Your right to privacy and quiet enjoyment of your home.";
        
        keyPoints.add("Landlord must give 24-48 hours notice before entry (varies by state)");
        keyPoints.add("Entry allowed for repairs, inspections, showing to prospective tenants");
        keyPoints.add("Emergency entry allowed without notice");
        keyPoints.add("Tenant has right to refuse unreasonable entry requests");
        keyPoints.add("Landlord cannot harass or interfere with quiet enjoyment");
        
        exceptions.add("Emergency situations allow immediate entry");
        exceptions.add("Court orders may allow entry without notice");
        
        stateLaws.put("California", "Civil Code § 1954 - 24 hours notice required");
        stateLaws.put("Florida", "Florida Statutes § 83.53 - 12 hours notice required");
        stateLaws.put("Texas", "Property Code § 92.0081 - Entry requirements");
        
        relatedResources.add("Tenant Rights Organizations");
        relatedResources.add("Local Housing Authorities");
        relatedResources.add("Legal Aid");
    }

    private void initializeDiscriminationRights() {
        title = "Anti-Discrimination Rights";
        description = "Your protection from housing discrimination based on protected characteristics.";
        
        keyPoints.add("Protected classes: race, color, religion, sex, national origin, familial status, disability");
        keyPoints.add("Discrimination prohibited in rental, sales, advertising, financing");
        keyPoints.add("Reasonable accommodations must be made for disabilities");
        keyPoints.add("Harassment based on protected characteristics is illegal");
        keyPoints.add("Retaliation for filing discrimination complaints is prohibited");
        
        exceptions.add("Small owner-occupied buildings may have limited exemptions");
        exceptions.add("Religious organizations may have some exemptions");
        
        stateLaws.put("Federal", "Fair Housing Act - 42 U.S.C. § 3601");
        stateLaws.put("California", "Unruh Civil Rights Act, Fair Employment and Housing Act");
        stateLaws.put("New York", "Human Rights Law - Executive Law § 296");
        
        relatedResources.add("HUD Fair Housing Office");
        relatedResources.add("State Civil Rights Agencies");
        relatedResources.add("Fair Housing Organizations");
    }

    private void initializeEvictionRights() {
        title = "Eviction Protection Rights";
        description = "Your rights and protections during the eviction process.";
        
        keyPoints.add("Landlord must follow proper legal eviction process");
        keyPoints.add("Proper notice required (3-30 days depending on reason)");
        keyPoints.add("Right to court hearing before eviction");
        keyPoints.add("Self-help evictions (changing locks, shutting utilities) are illegal");
        keyPoints.add("Right to legal representation in eviction proceedings");
        
        exceptions.add("Serious lease violations may allow faster eviction");
        exceptions.add("Holdover tenants after lease expiration have fewer protections");
        
        stateLaws.put("California", "Code of Civil Procedure § 1161 - Unlawful detainer");
        stateLaws.put("New York", "Real Property Actions and Proceedings Law");
        stateLaws.put("Texas", "Property Code Chapter 24 - Forcible entry and detainer");
        
        relatedResources.add("Legal Aid Organizations");
        relatedResources.add("Tenant Rights Groups");
        relatedResources.add("Court Self-Help Centers");
    }

    private void initializeRepairRights() {
        title = "Repair & Maintenance Rights";
        description = "Your rights regarding property repairs and maintenance issues.";
        
        keyPoints.add("Landlord responsible for maintaining rental property");
        keyPoints.add("Reasonable time allowed for non-emergency repairs");
        keyPoints.add("Emergency repairs must be addressed immediately");
        keyPoints.add("Tenant may have right to repair and deduct costs");
        keyPoints.add("Written notice of repair needs should be given to landlord");
        
        exceptions.add("Tenant-caused damage is tenant's responsibility");
        exceptions.add("Some maintenance tasks may be tenant's responsibility per lease");
        
        stateLaws.put("California", "Civil Code § 1942 - Repair and deduct remedy");
        stateLaws.put("Texas", "Property Code § 92.056 - Tenant's remedies");
        stateLaws.put("Illinois", "765 ILCS 735/1.4 - Residential Tenant Right to Repair Act");
        
        relatedResources.add("Local Building Inspectors");
        relatedResources.add("Code Enforcement");
        relatedResources.add("Tenant Rights Organizations");
    }

    private void initializeLeaseRights() {
        title = "Lease Agreement Rights";
        description = "Your rights regarding lease terms, modifications, and enforcement.";
        
        keyPoints.add("Lease terms must comply with state and local laws");
        keyPoints.add("Unconscionable lease terms may be unenforceable");
        keyPoints.add("Right to receive copy of signed lease");
        keyPoints.add("Lease modifications require mutual agreement");
        keyPoints.add("Automatic renewal clauses have specific requirements");
        
        exceptions.add("Some lease terms may override state law if more favorable to tenant");
        exceptions.add("Commercial leases may have different rules");
        
        stateLaws.put("California", "Civil Code § 1946.5 - Lease disclosure requirements");
        stateLaws.put("Florida", "Florida Statutes § 83.45 - Rental agreement compliance");
        stateLaws.put("New York", "General Obligations Law § 7-103 - Unconscionable agreements");
        
        relatedResources.add("Consumer Protection Agencies");
        relatedResources.add("Legal Aid Organizations");
        relatedResources.add("Bar Association");
    }

    // Helper methods
    public boolean isApplicableToState(String state) {
        return this.state == null || this.state.equalsIgnoreCase(state);
    }

    public String getStateLaw(String state) {
        return stateLaws.get(state);
    }

    public boolean hasStateLaw(String state) {
        return stateLaws.containsKey(state);
    }

    // Getters and Setters
    public String getState() { return state; }
    public void setState(String state) { this.state = state; }

    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }

    public RightCategory getCategory() { return category; }
    public void setCategory(RightCategory category) { this.category = category; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public List<String> getKeyPoints() { return keyPoints; }
    public void setKeyPoints(List<String> keyPoints) { this.keyPoints = keyPoints; }

    public List<String> getExceptions() { return exceptions; }
    public void setExceptions(List<String> exceptions) { this.exceptions = exceptions; }

    public Map<String, String> getStateLaws() { return stateLaws; }
    public void setStateLaws(Map<String, String> stateLaws) { this.stateLaws = stateLaws; }

    public List<String> getRelatedResources() { return relatedResources; }
    public void setRelatedResources(List<String> relatedResources) { this.relatedResources = relatedResources; }

    public boolean isStatutory() { return isStatutory; }
    public void setStatutory(boolean statutory) { isStatutory = statutory; }

    public String getLastUpdated() { return lastUpdated; }
    public void setLastUpdated(String lastUpdated) { this.lastUpdated = lastUpdated; }
}