package com.roomfinder.android.utils;

import java.util.HashMap;
import java.util.Map;

public class LegalCalculators {
    
    // Security Deposit Calculator
    public static class SecurityDepositResult {
        private double maxDeposit;
        private String explanation;
        private String state;
        private boolean isFurnished;
        
        public SecurityDepositResult(double maxDeposit, String explanation, String state, boolean isFurnished) {
            this.maxDeposit = maxDeposit;
            this.explanation = explanation;
            this.state = state;
            this.isFurnished = isFurnished;
        }
        
        public double getMaxDeposit() { return maxDeposit; }
        public String getExplanation() { return explanation; }
        public String getState() { return state; }
        public boolean isFurnished() { return isFurnished; }
    }
    
    public static SecurityDepositResult calculateSecurityDeposit(double monthlyRent, String state, boolean isFurnished) {
        double multiplier = getSecurityDepositMultiplier(state, isFurnished);
        double maxDeposit = monthlyRent * multiplier;
        String explanation = getSecurityDepositExplanation(state, multiplier, isFurnished);
        
        return new SecurityDepositResult(maxDeposit, explanation, state, isFurnished);
    }
    
    private static double getSecurityDepositMultiplier(String state, boolean isFurnished) {
        Map<String, Double> unfurnishedRules = new HashMap<>();
        Map<String, Double> furnishedRules = new HashMap<>();
        
        // California
        unfurnishedRules.put("California", 2.0);
        furnishedRules.put("California", 3.0);
        
        // New York
        unfurnishedRules.put("New York", 1.0);
        furnishedRules.put("New York", 1.0);
        
        // Texas
        unfurnishedRules.put("Texas", 999.0); // No limit
        furnishedRules.put("Texas", 999.0);
        
        // Florida
        unfurnishedRules.put("Florida", 999.0); // No limit
        furnishedRules.put("Florida", 999.0);
        
        // Illinois
        unfurnishedRules.put("Illinois", 999.0); // No statewide limit
        furnishedRules.put("Illinois", 999.0);
        
        // Default for other states
        double defaultMultiplier = 2.0;
        
        if (isFurnished) {
            return furnishedRules.getOrDefault(state, defaultMultiplier + 1.0);
        } else {
            return unfurnishedRules.getOrDefault(state, defaultMultiplier);
        }
    }
    
    private static String getSecurityDepositExplanation(String state, double multiplier, boolean isFurnished) {
        String unitType = isFurnished ? "furnished" : "unfurnished";
        
        switch (state) {
            case "California":
                return String.format("Based on California law (%.0fx monthly rent for %s units)", 
                    multiplier, unitType);
            case "New York":
                return "Based on New York law (1x monthly rent maximum)";
            case "Texas":
                return "Texas has no statewide limit on security deposits";
            case "Florida":
                return "Florida has no statewide limit on security deposits";
            default:
                if (multiplier >= 999) {
                    return String.format("%s has no statewide limit on security deposits", state);
                } else {
                    return String.format("Based on typical %.0fx monthly rent limit for %s units", 
                        multiplier, unitType);
                }
        }
    }
    
    // Prorated Rent Calculator
    public static class ProratedRentResult {
        private double proratedAmount;
        private int daysInMonth;
        private int daysOccupied;
        private double dailyRate;
        private String explanation;
        
        public ProratedRentResult(double proratedAmount, int daysInMonth, int daysOccupied, 
                                double dailyRate, String explanation) {
            this.proratedAmount = proratedAmount;
            this.daysInMonth = daysInMonth;
            this.daysOccupied = daysOccupied;
            this.dailyRate = dailyRate;
            this.explanation = explanation;
        }
        
        public double getProratedAmount() { return proratedAmount; }
        public int getDaysInMonth() { return daysInMonth; }
        public int getDaysOccupied() { return daysOccupied; }
        public double getDailyRate() { return dailyRate; }
        public String getExplanation() { return explanation; }
    }
    
    public static ProratedRentResult calculateProratedRent(double monthlyRent, int daysInMonth, 
                                                         int daysOccupied) {
        if (daysInMonth <= 0 || daysOccupied < 0 || daysOccupied > daysInMonth) {
            throw new IllegalArgumentException("Invalid day parameters");
        }
        
        double dailyRate = monthlyRent / daysInMonth;
        double proratedAmount = dailyRate * daysOccupied;
        
        String explanation = String.format(
            "Daily rate: $%.2f (%d days occupied out of %d days in month)", 
            dailyRate, daysOccupied, daysInMonth
        );
        
        return new ProratedRentResult(proratedAmount, daysInMonth, daysOccupied, dailyRate, explanation);
    }
    
    // Late Fee Calculator
    public static class LateFeeResult {
        private double maxLateFee;
        private String explanation;
        private String state;
        private boolean isPercentageBased;
        
        public LateFeeResult(double maxLateFee, String explanation, String state, boolean isPercentageBased) {
            this.maxLateFee = maxLateFee;
            this.explanation = explanation;
            this.state = state;
            this.isPercentageBased = isPercentageBased;
        }
        
        public double getMaxLateFee() { return maxLateFee; }
        public String getExplanation() { return explanation; }
        public String getState() { return state; }
        public boolean isPercentageBased() { return isPercentageBased; }
    }
    
    public static LateFeeResult calculateLateFee(double monthlyRent, String state, int daysLate) {
        double maxLateFee;
        String explanation;
        boolean isPercentageBased = false;
        
        switch (state) {
            case "California":
                // California allows reasonable late fees, typically up to 6% of rent
                maxLateFee = monthlyRent * 0.06;
                isPercentageBased = true;
                explanation = "California allows reasonable late fees (typically up to 6% of monthly rent)";
                break;
                
            case "New York":
                // New York allows $50 or 5% of rent, whichever is less
                double nyPercentage = monthlyRent * 0.05;
                maxLateFee = Math.min(50.0, nyPercentage);
                explanation = "New York allows $50 or 5% of monthly rent, whichever is less";
                break;
                
            case "Texas":
                // Texas has no specific limit, but must be reasonable
                maxLateFee = monthlyRent * 0.12; // Assume 12% as reasonable maximum
                isPercentageBased = true;
                explanation = "Texas requires late fees to be reasonable (estimated 10-12% of rent)";
                break;
                
            case "Florida":
                // Florida has no specific limit, but must be reasonable
                maxLateFee = monthlyRent * 0.10;
                isPercentageBased = true;
                explanation = "Florida requires late fees to be reasonable (typically up to 10% of rent)";
                break;
                
            default:
                // Default reasonable estimate
                maxLateFee = monthlyRent * 0.08;
                isPercentageBased = true;
                explanation = String.format("%s - estimated reasonable late fee (8%% of monthly rent)", state);
                break;
        }
        
        // Apply additional charges for extended lateness in some cases
        if (daysLate > 30 && (state.equals("Texas") || state.equals("Florida"))) {
            maxLateFee *= 1.5; // 50% additional for very late payments
            explanation += ". Additional fees may apply for extended lateness.";
        }
        
        return new LateFeeResult(maxLateFee, explanation, state, isPercentageBased);
    }
    
    // Utility method to get days in current month
    public static int getDaysInCurrentMonth() {
        java.util.Calendar cal = java.util.Calendar.getInstance();
        return cal.getActualMaximum(java.util.Calendar.DAY_OF_MONTH);
    }
    
    // Utility method to validate positive numbers
    public static boolean isValidAmount(double amount) {
        return amount > 0 && amount < 1000000; // Reasonable upper limit
    }
    
    // Utility method to format currency
    public static String formatCurrency(double amount) {
        return String.format("$%,.2f", amount);
    }
}