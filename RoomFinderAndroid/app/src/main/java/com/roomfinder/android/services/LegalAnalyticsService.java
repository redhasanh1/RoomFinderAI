package com.roomfinder.android.services;

import com.roomfinder.android.models.LegalIssue;
import java.util.ArrayList;
import java.util.List;

public class LegalAnalyticsService {
    
    public static class IssueAnalysis {
        public double confidenceScore;
        public String recommendation;
        public List<String> nextSteps;
        public List<String> requiredDocuments;
        public boolean requiresLegalAssistance;
        public String riskLevel;
        public List<String> relevantLaws;
        
        public IssueAnalysis() {
            this.nextSteps = new ArrayList<>();
            this.requiredDocuments = new ArrayList<>();
            this.relevantLaws = new ArrayList<>();
        }
    }
    
    public static IssueAnalysis analyzeIssue(LegalIssue issue) {
        IssueAnalysis analysis = new IssueAnalysis();
        
        // Generate analysis based on issue category and urgency
        analysis.confidenceScore = issue.getConfidenceScore();
        analysis.nextSteps = new ArrayList<>(issue.getNextSteps());
        analysis.requiredDocuments = new ArrayList<>(issue.getRequiredDocuments());
        analysis.requiresLegalAssistance = issue.requiresLegalAssistance();
        analysis.relevantLaws = issue.getRelevantLaws();
        
        // Generate recommendation
        analysis.recommendation = generateRecommendation(issue);
        
        // Determine risk level
        analysis.riskLevel = determineRiskLevel(issue);
        
        return analysis;
    }
    
    private static String generateRecommendation(LegalIssue issue) {
        StringBuilder recommendation = new StringBuilder();
        
        switch (issue.getCategory()) {
            case RENT_ISSUES:
                recommendation.append("Review your lease agreement and payment records. ");
                if (issue.getUrgency() == LegalIssue.Urgency.HIGH || issue.getUrgency() == LegalIssue.Urgency.EMERGENCY) {
                    recommendation.append("Contact your landlord immediately and consider legal consultation.");
                } else {
                    recommendation.append("Document the issue and communicate with your landlord in writing.");
                }
                break;
                
            case SECURITY_DEPOSITS:
                recommendation.append("Document the property condition thoroughly and know your state's deposit laws. ");
                recommendation.append("Send written requests for deposit return within the required timeframe.");
                break;
                
            case MAINTENANCE_REPAIRS:
                recommendation.append("Report maintenance issues in writing immediately. ");
                if (issue.getUrgency() == LegalIssue.Urgency.EMERGENCY) {
                    recommendation.append("For emergency repairs affecting health/safety, contact authorities if landlord is unresponsive.");
                }
                break;
                
            case EVICTION:
                recommendation.append("Seek legal assistance immediately. Time is critical in eviction cases. ");
                recommendation.append("Respond to all notices promptly and gather all relevant documentation.");
                break;
                
            case PRIVACY_RIGHTS:
                recommendation.append("Document unauthorized entries and know your state's entry laws. ");
                recommendation.append("Send written notice asserting your privacy rights.");
                break;
                
            case DISCRIMINATION:
                recommendation.append("Document all instances of discrimination and contact fair housing organizations. ");
                recommendation.append("File complaints with appropriate agencies promptly.");
                break;
                
            default:
                recommendation.append("Document the issue thoroughly and review your lease agreement. ");
                recommendation.append("Consider consulting with a tenant rights organization.");
        }
        
        return recommendation.toString();
    }
    
    private static String determineRiskLevel(LegalIssue issue) {
        if (issue.getCategory() == LegalIssue.IssueCategory.EVICTION) {
            return "Very High";
        }
        
        if (issue.getCategory() == LegalIssue.IssueCategory.DISCRIMINATION) {
            return "High";
        }
        
        switch (issue.getUrgency()) {
            case EMERGENCY:
                return "Very High";
            case HIGH:
                return "High";
            case MEDIUM:
                return "Medium";
            case LOW:
                return "Low";
            default:
                return "Medium";
        }
    }
    
    public static List<String> generateActionPlan(LegalIssue issue) {
        List<String> actionPlan = new ArrayList<>();
        
        // Immediate actions
        actionPlan.add("Document the issue with photos, videos, and written description");
        actionPlan.add("Review your lease agreement for relevant terms");
        actionPlan.add("Gather all related documents and communications");
        
        // Category-specific actions
        switch (issue.getCategory()) {
            case EVICTION:
                actionPlan.add("Contact legal aid organization immediately");
                actionPlan.add("File response to eviction notice if required");
                actionPlan.add("Prepare for court hearing");
                break;
                
            case MAINTENANCE_REPAIRS:
                actionPlan.add("Submit written maintenance request to landlord");
                actionPlan.add("Follow up if no response within reasonable time");
                actionPlan.add("Contact code enforcement if serious habitability issues");
                break;
                
            case SECURITY_DEPOSITS:
                actionPlan.add("Take detailed photos of property condition");
                actionPlan.add("Send formal written request for deposit return");
                actionPlan.add("File complaint with appropriate agency if needed");
                break;
                
            case DISCRIMINATION:
                actionPlan.add("Contact Fair Housing organization");
                actionPlan.add("File complaint with HUD or state agency");
                actionPlan.add("Gather witness statements if available");
                break;
        }
        
        // Follow-up actions
        actionPlan.add("Keep detailed records of all actions taken");
        actionPlan.add("Follow up on any requests or complaints filed");
        actionPlan.add("Consider legal consultation if issue persists");
        
        return actionPlan;
    }
    
    public static List<LegalIssue> getSimilarIssues(LegalIssue issue) {
        // In a real implementation, this would query a database
        // For now, return sample similar issues
        List<LegalIssue> similarIssues = new ArrayList<>();
        
        // Create sample similar issues based on category
        for (int i = 0; i < 3; i++) {
            LegalIssue similar = new LegalIssue(
                issue.getCategory(),
                "Similar Issue " + (i + 1),
                "Description of similar issue",
                LegalIssue.Urgency.MEDIUM,
                issue.getState()
            );
            similar.setStatus(LegalIssue.Status.RESOLVED);
            similarIssues.add(similar);
        }
        
        return similarIssues;
    }
    
    public static double calculateSuccessLikelihood(LegalIssue issue) {
        double baseSuccess = 0.7;
        
        // Adjust based on category
        switch (issue.getCategory()) {
            case SECURITY_DEPOSITS:
                baseSuccess = 0.85; // High success rate
                break;
            case MAINTENANCE_REPAIRS:
                baseSuccess = 0.80;
                break;
            case RENT_ISSUES:
                baseSuccess = 0.75;
                break;
            case PRIVACY_RIGHTS:
                baseSuccess = 0.70;
                break;
            case EVICTION:
                baseSuccess = 0.60; // More complex
                break;
            case DISCRIMINATION:
                baseSuccess = 0.65;
                break;
        }
        
        // Adjust based on urgency (urgent cases may be harder to resolve favorably)
        switch (issue.getUrgency()) {
            case LOW:
                baseSuccess += 0.1;
                break;
            case HIGH:
            case EMERGENCY:
                baseSuccess -= 0.1;
                break;
        }
        
        return Math.min(0.95, Math.max(0.30, baseSuccess));
    }
    
    public static List<String> getLegalResources(LegalIssue issue) {
        List<String> resources = new ArrayList<>();
        
        // General resources
        resources.add("Local Tenant Rights Organization");
        resources.add("Legal Aid Society");
        resources.add("State Housing Authority");
        
        // Category-specific resources
        switch (issue.getCategory()) {
            case EVICTION:
                resources.add("Eviction Defense Clinic");
                resources.add("Court Self-Help Center");
                break;
            case DISCRIMINATION:
                resources.add("Fair Housing Council");
                resources.add("HUD Fair Housing Office");
                break;
            case MAINTENANCE_REPAIRS:
                resources.add("Code Enforcement Office");
                resources.add("Health Department");
                break;
        }
        
        return resources;
    }
}