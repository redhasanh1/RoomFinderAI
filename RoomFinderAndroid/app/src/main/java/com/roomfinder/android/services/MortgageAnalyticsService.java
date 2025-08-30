package com.roomfinder.android.services;

import com.roomfinder.android.models.MortgageCalculation;
import com.roomfinder.android.models.MortgageScenario;
import com.roomfinder.android.models.MortgageRate;
import java.util.ArrayList;
import java.util.List;

public class MortgageAnalyticsService {

    public static class FinancialHealthScore {
        public int score; // 0-100
        public String grade; // A+, A, B, C, D, F
        public String description;
        public List<String> strengths;
        public List<String> improvements;

        public FinancialHealthScore() {
            this.strengths = new ArrayList<>();
            this.improvements = new ArrayList<>();
        }
    }

    public static class StressTestResult {
        public boolean passesStressTest;
        public double stressTestRate;
        public double stressTestPayment;
        public double paymentIncrease;
        public String riskLevel;
        public List<String> recommendations;

        public StressTestResult() {
            this.recommendations = new ArrayList<>();
        }
    }

    public static FinancialHealthScore analyzeFinancialHealth(MortgageScenario scenario) {
        FinancialHealthScore score = new FinancialHealthScore();
        int points = 100;

        if (scenario.getMortgageCalculation() == null) {
            score.score = 0;
            score.grade = "F";
            score.description = "Unable to analyze - insufficient data";
            return score;
        }

        MortgageCalculation calc = scenario.getMortgageCalculation();

        // Debt-to-Income Analysis (25 points)
        double dtiRatio = scenario.getDebtToIncomeRatio();
        if (dtiRatio <= 28) {
            score.strengths.add("Excellent debt-to-income ratio (" + String.format("%.1f", dtiRatio) + "%)");
        } else if (dtiRatio <= 36) {
            points -= 5;
            score.improvements.add("Consider reducing monthly debts to improve DTI ratio");
        } else if (dtiRatio <= 43) {
            points -= 15;
            score.improvements.add("High debt-to-income ratio - consider debt consolidation");
        } else {
            points -= 25;
            score.improvements.add("Very high debt-to-income ratio - may not qualify for mortgage");
        }

        // Down Payment Analysis (20 points)
        double downPaymentPercent = calc.getDownPaymentPercentage();
        if (downPaymentPercent >= 20) {
            score.strengths.add("Excellent down payment (" + String.format("%.1f", downPaymentPercent) + "%) - no PMI required");
        } else if (downPaymentPercent >= 10) {
            points -= 5;
            score.improvements.add("Consider saving more for down payment to reduce PMI");
        } else if (downPaymentPercent >= 5) {
            points -= 10;
            score.improvements.add("Low down payment will require PMI");
        } else {
            points -= 20;
            score.improvements.add("Very low down payment - consider FHA loan options");
        }

        // Housing Payment Ratio (20 points)
        double housingRatio = scenario.getHousingPaymentRatio();
        if (housingRatio <= 28) {
            score.strengths.add("Housing payment within recommended 28% of income");
        } else if (housingRatio <= 31) {
            points -= 5;
            score.improvements.add("Housing payment slightly above recommended ratio");
        } else if (housingRatio <= 35) {
            points -= 10;
            score.improvements.add("Housing payment above recommended ratio - consider lower price");
        } else {
            points -= 20;
            score.improvements.add("Housing payment too high - seriously consider lower price range");
        }

        // Interest Rate Analysis (15 points)
        double interestRate = calc.getInterestRate();
        if (interestRate <= 6.5) {
            score.strengths.add("Excellent interest rate (" + String.format("%.2f", interestRate) + "%)");
        } else if (interestRate <= 7.5) {
            points -= 5;
            score.improvements.add("Consider shopping for better rates");
        } else {
            points -= 15;
            score.improvements.add("High interest rate - work on improving credit score");
        }

        // Emergency Fund Analysis (10 points)
        double totalUpfront = scenario.getTotalUpfrontCosts();
        if (scenario.getMonthlyIncome() > 0) {
            double monthsOfEmergencyFund = 6; // Assume 6 months emergency fund
            double emergencyFundNeeded = scenario.getMonthlyIncome() * monthsOfEmergencyFund;
            // This is a simplified assumption - in real app, this would be user input
            if (totalUpfront < scenario.getMonthlyIncome() * 3) {
                score.strengths.add("Reasonable upfront costs relative to income");
            } else {
                points -= 10;
                score.improvements.add("High upfront costs - ensure adequate emergency fund remains");
            }
        }

        // Loan Term Analysis (10 points)
        if (calc.getLoanTermYears() <= 15) {
            score.strengths.add("Short loan term will save significant interest");
        } else if (calc.getLoanTermYears() <= 30) {
            // Standard term, no penalty
        } else {
            points -= 10;
            score.improvements.add("Extended loan term increases total interest paid");
        }

        score.score = Math.max(0, points);
        
        // Assign letter grade
        if (score.score >= 90) {
            score.grade = "A+";
            score.description = "Excellent financial position for homebuying";
        } else if (score.score >= 80) {
            score.grade = "A";
            score.description = "Very strong financial position";
        } else if (score.score >= 70) {
            score.grade = "B";
            score.description = "Good financial position with minor concerns";
        } else if (score.score >= 60) {
            score.grade = "C";
            score.description = "Adequate financial position but room for improvement";
        } else if (score.score >= 50) {
            score.grade = "D";
            score.description = "Weak financial position - consider waiting";
        } else {
            score.grade = "F";
            score.description = "Poor financial position for homebuying";
        }

        return score;
    }

    public static StressTestResult performCanadianStressTest(MortgageCalculation calculation, 
                                                           double monthlyIncome, 
                                                           double monthlyDebts) {
        StressTestResult result = new StressTestResult();
        
        // Canadian stress test uses higher of contract rate + 2% or 5.25%
        double contractRate = calculation.getInterestRate();
        result.stressTestRate = Math.max(contractRate + 2.0, 5.25);
        
        // Calculate payment at stress test rate
        MortgageCalculation stressTestCalc = new MortgageCalculation(
            calculation.getLoanAmount(), 
            result.stressTestRate, 
            calculation.getLoanTermYears()
        );
        
        result.stressTestPayment = stressTestCalc.getMonthlyPayment();
        result.paymentIncrease = result.stressTestPayment - calculation.getMonthlyPayment();
        
        // Check if borrower qualifies under stress test
        double totalDebts = monthlyDebts + result.stressTestPayment;
        double stressTestDTI = (totalDebts / monthlyIncome) * 100;
        
        result.passesStressTest = stressTestDTI <= 44; // Canadian maximum
        
        // Determine risk level
        if (stressTestDTI <= 35) {
            result.riskLevel = "Low Risk";
            result.recommendations.add("Excellent - comfortably passes stress test");
        } else if (stressTestDTI <= 40) {
            result.riskLevel = "Moderate Risk";
            result.recommendations.add("Passes stress test but monitor interest rate changes");
        } else if (stressTestDTI <= 44) {
            result.riskLevel = "High Risk";
            result.recommendations.add("Barely passes stress test - consider smaller loan");
            result.recommendations.add("Build emergency fund for potential rate increases");
        } else {
            result.riskLevel = "Very High Risk";
            result.recommendations.add("Fails stress test - will not qualify for mortgage");
            result.recommendations.add("Reduce debts or increase income before applying");
        }
        
        return result;
    }

    public static List<MortgageScenario> compareScenarios(List<MortgageScenario> scenarios) {
        List<MortgageScenario> sortedScenarios = new ArrayList<>(scenarios);
        
        // Sort by total cost (interest + principal)
        sortedScenarios.sort((s1, s2) -> {
            if (s1.getMortgageCalculation() == null || s2.getMortgageCalculation() == null) {
                return 0;
            }
            
            double cost1 = s1.getMortgageCalculation().getTotalAmount();
            double cost2 = s2.getMortgageCalculation().getTotalAmount();
            
            return Double.compare(cost1, cost2);
        });
        
        // Add comparison insights
        for (int i = 0; i < sortedScenarios.size(); i++) {
            MortgageScenario scenario = sortedScenarios.get(i);
            List<String> comparisons = scenario.getRecommendations();
            
            if (i == 0 && sortedScenarios.size() > 1) {
                MortgageCalculation bestCalc = scenario.getMortgageCalculation();
                MortgageCalculation worstCalc = sortedScenarios.get(sortedScenarios.size() - 1).getMortgageCalculation();
                
                if (bestCalc != null && worstCalc != null) {
                    double savings = worstCalc.getTotalAmount() - bestCalc.getTotalAmount();
                    comparisons.add("BEST OPTION - Saves $" + String.format("%.0f", savings) + " vs worst option");
                }
            }
        }
        
        return sortedScenarios;
    }

    public static double calculateTotalCostOfOwnership(MortgageCalculation calculation, 
                                                     int yearsOfOwnership, 
                                                     double maintenanceRate,
                                                     double appreciationRate) {
        
        double totalMortgagePayments = calculation.getMonthlyPayment() * 12 * yearsOfOwnership;
        double totalPropertyTax = calculation.getPropertyTax() * 12 * yearsOfOwnership;
        double totalInsurance = calculation.getHomeInsurance() * 12 * yearsOfOwnership;
        double totalPMI = calculation.getPmiAmount() * 12 * yearsOfOwnership;
        
        // Estimate maintenance costs
        double maintenanceCosts = calculation.getHomePrice() * maintenanceRate * yearsOfOwnership;
        
        // Calculate home appreciation
        double futureHomeValue = calculation.getHomePrice() * Math.pow(1 + appreciationRate, yearsOfOwnership);
        
        double totalCosts = totalMortgagePayments + totalPropertyTax + totalInsurance + 
                           totalPMI + maintenanceCosts;
        
        // Net cost after selling (assuming no selling costs for simplicity)
        return totalCosts - (futureHomeValue - calculation.getHomePrice());
    }

    public static List<String> generatePersonalizedInsights(MortgageScenario scenario) {
        List<String> insights = new ArrayList<>();
        
        if (scenario.getMortgageCalculation() == null) {
            insights.add("Complete your mortgage details for personalized insights");
            return insights;
        }
        
        MortgageCalculation calc = scenario.getMortgageCalculation();
        
        // Interest savings insight
        if (calc.getLoanTermYears() == 30) {
            MortgageCalculation calc15Year = new MortgageCalculation(calc.getLoanAmount(), 
                                                                   calc.getInterestRate() - 0.5, 15);
            double interestSavings = calc.getTotalInterest() - calc15Year.getTotalInterest();
            double paymentIncrease = calc15Year.getMonthlyPayment() - calc.getMonthlyPayment();
            
            insights.add(String.format("15-year loan would save $%.0f in interest but increase payment by $%.0f", 
                                     interestSavings, paymentIncrease));
        }
        
        // PMI removal insight
        if (calc.isPmiRequired()) {
            double monthsToRemovePMI = calculateMonthsToRemovePMI(calc);
            insights.add(String.format("PMI can be removed in ~%.0f months when you reach 80%% LTV", 
                                     monthsToRemovePMI));
        }
        
        // Rate shopping insight
        double potentialSavings = calculateRateShoppingSavings(calc);
        if (potentialSavings > 1000) {
            insights.add(String.format("Shopping for 0.25%% better rate could save $%.0f over loan term", 
                                     potentialSavings));
        }
        
        return insights;
    }

    private static double calculateMonthsToRemovePMI(MortgageCalculation calculation) {
        double targetBalance = calculation.getHomePrice() * 0.80;
        double currentBalance = calculation.getLoanAmount();
        double monthlyPrincipal = calculation.getMonthlyPayment() - 
                                  (currentBalance * calculation.getInterestRate() / 100 / 12);
        
        return (currentBalance - targetBalance) / monthlyPrincipal;
    }

    private static double calculateRateShoppingSavings(MortgageCalculation calculation) {
        MortgageCalculation betterRate = new MortgageCalculation(calculation.getLoanAmount(),
                                                               calculation.getInterestRate() - 0.25,
                                                               calculation.getLoanTermYears());
        
        return calculation.getTotalInterest() - betterRate.getTotalInterest();
    }
}