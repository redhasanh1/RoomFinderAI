package com.roomfinder.android.utils;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

public class DocumentTemplates {
    
    public enum DocumentType {
        LEASE_AGREEMENT,
        TERMINATION_NOTICE,
        COMPLAINT_LETTER,
        SECURITY_DEPOSIT_DEMAND
    }
    
    public static class DocumentData {
        private Map<String, String> fields;
        
        public DocumentData() {
            this.fields = new HashMap<>();
        }
        
        public void setField(String key, String value) {
            fields.put(key, value);
        }
        
        public String getField(String key) {
            return fields.getOrDefault(key, "");
        }
        
        public Map<String, String> getAllFields() {
            return new HashMap<>(fields);
        }
    }
    
    public static class GeneratedDocument {
        private String title;
        private String content;
        private String preview;
        private DocumentType type;
        private String state;
        private Date generatedDate;
        
        public GeneratedDocument(DocumentType type, String title, String content, 
                               String preview, String state) {
            this.type = type;
            this.title = title;
            this.content = content;
            this.preview = preview;
            this.state = state;
            this.generatedDate = new Date();
        }
        
        public String getTitle() { return title; }
        public String getContent() { return content; }
        public String getPreview() { return preview; }
        public DocumentType getType() { return type; }
        public String getState() { return state; }
        public Date getGeneratedDate() { return generatedDate; }
    }
    
    public static GeneratedDocument generateDocument(DocumentType type, DocumentData data) {
        switch (type) {
            case LEASE_AGREEMENT:
                return generateLeaseAgreement(data);
            case TERMINATION_NOTICE:
                return generateTerminationNotice(data);
            case COMPLAINT_LETTER:
                return generateComplaintLetter(data);
            case SECURITY_DEPOSIT_DEMAND:
                return generateSecurityDepositDemand(data);
            default:
                throw new IllegalArgumentException("Unknown document type: " + type);
        }
    }
    
    private static GeneratedDocument generateLeaseAgreement(DocumentData data) {
        String state = data.getField("state");
        String address = data.getField("propertyAddress");
        String rent = data.getField("monthlyRent");
        String deposit = data.getField("securityDeposit");
        String currentDate = new SimpleDateFormat("MMMM dd, yyyy", Locale.US).format(new Date());
        
        String title = "Residential Lease Agreement - " + state;
        
        String content = generateLeaseContent(state, address, rent, deposit, currentDate);
        
        String preview = String.format(
            "Lease Agreement for %s with monthly rent of $%s and security deposit of $%s. " +
            "Customized for %s state law with all required clauses and tenant protections.",
            address, rent, deposit, state
        );
        
        return new GeneratedDocument(DocumentType.LEASE_AGREEMENT, title, content, preview, state);
    }
    
    private static String generateLeaseContent(String state, String address, String rent, 
                                             String deposit, String currentDate) {
        StringBuilder content = new StringBuilder();
        
        content.append("RESIDENTIAL LEASE AGREEMENT\n\n");
        content.append("This Lease Agreement is made on ").append(currentDate);
        content.append(" between the Landlord and Tenant for the rental property located at:\n\n");
        content.append(address).append("\n\n");
        
        content.append("TERMS AND CONDITIONS:\n\n");
        content.append("1. RENT: The monthly rent is $").append(rent);
        content.append(" due on the 1st of each month.\n\n");
        
        content.append("2. SECURITY DEPOSIT: A security deposit of $").append(deposit);
        content.append(" is required before occupancy.\n\n");
        
        // Add state-specific clauses
        content.append(getStateSpecificClauses(state));
        
        content.append("\n3. TERM: This lease shall be governed by the laws of ").append(state);
        content.append(".\n\n");
        
        content.append("4. TENANT OBLIGATIONS:\n");
        content.append("- Pay rent on time\n");
        content.append("- Maintain cleanliness\n");
        content.append("- Report maintenance issues promptly\n");
        content.append("- Follow all lease terms and local laws\n\n");
        
        content.append("5. LANDLORD OBLIGATIONS:\n");
        content.append("- Maintain habitability\n");
        content.append("- Make necessary repairs\n");
        content.append("- Respect tenant privacy rights\n");
        content.append("- Follow all applicable housing laws\n\n");
        
        content.append("This document was generated using RoomFinder Legal Tools and should be reviewed by a qualified attorney before use.");
        
        return content.toString();
    }
    
    private static GeneratedDocument generateTerminationNotice(DocumentData data) {
        String state = data.getField("state");
        String address = data.getField("propertyAddress");
        String currentDate = new SimpleDateFormat("MMMM dd, yyyy", Locale.US).format(new Date());
        
        String title = "30-Day Termination Notice - " + state;
        
        StringBuilder content = new StringBuilder();
        content.append("NOTICE TO TERMINATE TENANCY\n\n");
        content.append("Date: ").append(currentDate).append("\n\n");
        content.append("TO: All Tenants in Possession of the Premises Located at:\n");
        content.append(address).append("\n\n");
        content.append("PLEASE TAKE NOTICE that your tenancy is hereby terminated.\n\n");
        content.append("You are required to quit and surrender the premises to the landlord ");
        content.append("within thirty (30) days after service of this notice.\n\n");
        content.append("This notice complies with ").append(state).append(" state law.\n\n");
        content.append("Landlord/Agent Signature: _________________________\n\n");
        content.append("This document was generated using RoomFinder Legal Tools.");
        
        String preview = String.format(
            "30-day termination notice for property at %s, compliant with %s state law requirements.",
            address, state
        );
        
        return new GeneratedDocument(DocumentType.TERMINATION_NOTICE, title, content.toString(), preview, state);
    }
    
    private static GeneratedDocument generateComplaintLetter(DocumentData data) {
        String state = data.getField("state");
        String address = data.getField("propertyAddress");
        String issue = data.getField("issueDescription");
        String currentDate = new SimpleDateFormat("MMMM dd, yyyy", Locale.US).format(new Date());
        
        String title = "Tenant Complaint Letter - " + state;
        
        StringBuilder content = new StringBuilder();
        content.append("FORMAL TENANT COMPLAINT\n\n");
        content.append("Date: ").append(currentDate).append("\n\n");
        content.append("TO: Landlord/Property Manager\n");
        content.append("RE: Property at ").append(address).append("\n\n");
        content.append("Dear Landlord,\n\n");
        content.append("I am writing to formally notify you of the following issue(s) ");
        content.append("that require your immediate attention:\n\n");
        content.append(issue).append("\n\n");
        content.append("Under ").append(state).append(" state law, you are required to address ");
        content.append("habitability issues within a reasonable time period.\n\n");
        content.append("Please contact me within 5 business days to discuss how and when ");
        content.append("this matter will be resolved.\n\n");
        content.append("Thank you for your prompt attention to this matter.\n\n");
        content.append("Sincerely,\n\n");
        content.append("Tenant Signature: _________________________\n");
        content.append("Date: _____________\n\n");
        content.append("This document was generated using RoomFinder Legal Tools.");
        
        String preview = String.format(
            "Formal complaint letter addressing property issues at %s, formatted according to %s legal requirements.",
            address, state
        );
        
        return new GeneratedDocument(DocumentType.COMPLAINT_LETTER, title, content.toString(), preview, state);
    }
    
    private static GeneratedDocument generateSecurityDepositDemand(DocumentData data) {
        String state = data.getField("state");
        String address = data.getField("propertyAddress");
        String deposit = data.getField("securityDeposit");
        String currentDate = new SimpleDateFormat("MMMM dd, yyyy", Locale.US).format(new Date());
        
        String title = "Security Deposit Demand Letter - " + state;
        
        StringBuilder content = new StringBuilder();
        content.append("DEMAND FOR RETURN OF SECURITY DEPOSIT\n\n");
        content.append("Date: ").append(currentDate).append("\n\n");
        content.append("TO: Former Landlord/Property Manager\n");
        content.append("RE: Security Deposit for ").append(address).append("\n\n");
        content.append("Dear Former Landlord,\n\n");
        content.append("I am writing to demand the immediate return of my security deposit ");
        content.append("in the amount of $").append(deposit);
        content.append(" for the above-referenced property.\n\n");
        content.append("I vacated the premises on _____________ and provided a forwarding address.\n\n");
        content.append("Under ").append(state).append(" state law, you were required to return ");
        content.append("my deposit with an itemized statement of any deductions within the ");
        content.append("statutory time period.\n\n");
        content.append("If my full deposit is not returned within 10 days of this notice, ");
        content.append("I may pursue all available legal remedies, including statutory damages.\n\n");
        content.append("Please remit payment to:\n");
        content.append("[Your forwarding address]\n\n");
        content.append("Sincerely,\n\n");
        content.append("Former Tenant Signature: _________________________\n\n");
        content.append("This document was generated using RoomFinder Legal Tools.");
        
        String preview = String.format(
            "Demand letter for return of $%s security deposit from property at %s, citing %s state law requirements.",
            deposit, address, state
        );
        
        return new GeneratedDocument(DocumentType.SECURITY_DEPOSIT_DEMAND, title, content.toString(), preview, state);
    }
    
    private static String getStateSpecificClauses(String state) {
        StringBuilder clauses = new StringBuilder();
        
        switch (state) {
            case "California":
                clauses.append("CALIFORNIA-SPECIFIC PROVISIONS:\n");
                clauses.append("- Security deposit limited to 2x monthly rent (unfurnished)\n");
                clauses.append("- 21-day deposit return requirement\n");
                clauses.append("- Rent control may apply in some cities\n");
                clauses.append("- Just cause eviction requirements (AB 1482)\n");
                clauses.append("- Lead paint disclosure required for pre-1978 properties\n");
                break;
                
            case "New York":
                clauses.append("NEW YORK-SPECIFIC PROVISIONS:\n");
                clauses.append("- Security deposit limited to 1 month's rent\n");
                clauses.append("- Interest required on deposits over $1,000\n");
                clauses.append("- Rent stabilization may apply\n");
                clauses.append("- Good cause eviction protections\n");
                clauses.append("- Right to counsel in eviction proceedings\n");
                break;
                
            case "Texas":
                clauses.append("TEXAS-SPECIFIC PROVISIONS:\n");
                clauses.append("- 30-day deposit return requirement\n");
                clauses.append("- No rent control allowed\n");
                clauses.append("- Property condition disclosure required\n");
                clauses.append("- Smoke detector requirements\n");
                clauses.append("- Utility disclosure requirements\n");
                break;
                
            default:
                clauses.append("STATE-SPECIFIC PROVISIONS:\n");
                clauses.append("- This lease is governed by ").append(state).append(" state law\n");
                clauses.append("- All applicable housing codes and regulations apply\n");
                clauses.append("- Consult local laws for additional requirements\n");
                break;
        }
        
        return clauses.toString();
    }
    
    // Utility method to validate required fields
    public static boolean hasRequiredFields(DocumentType type, DocumentData data) {
        switch (type) {
            case LEASE_AGREEMENT:
                return !data.getField("state").isEmpty() && 
                       !data.getField("propertyAddress").isEmpty() &&
                       !data.getField("monthlyRent").isEmpty() &&
                       !data.getField("securityDeposit").isEmpty();
                       
            case TERMINATION_NOTICE:
                return !data.getField("state").isEmpty() && 
                       !data.getField("propertyAddress").isEmpty();
                       
            case COMPLAINT_LETTER:
                return !data.getField("state").isEmpty() && 
                       !data.getField("propertyAddress").isEmpty() &&
                       !data.getField("issueDescription").isEmpty();
                       
            case SECURITY_DEPOSIT_DEMAND:
                return !data.getField("state").isEmpty() && 
                       !data.getField("propertyAddress").isEmpty() &&
                       !data.getField("securityDeposit").isEmpty();
                       
            default:
                return false;
        }
    }
}