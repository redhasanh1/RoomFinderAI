package com.roomfinder.android.models;

import java.util.ArrayList;
import java.util.List;

public class MortgageScenario {
    private String scenarioName;
    private MortgageCalculation mortgageCalculation;
    private double closingCosts;
    private double monthlyIncome;
    private double monthlyDebts;
    private double debtToIncomeRatio;
    private boolean isApprovalLikely;
    private String riskLevel;
    private List<String> recommendations;
    private long timestamp;

    public MortgageScenario() {
        this.recommendations = new ArrayList<>();
        this.timestamp = System.currentTimeMillis();
    }

    public MortgageScenario(String scenarioName, MortgageCalculation mortgageCalculation) {
        this();
        this.scenarioName = scenarioName;
        this.mortgageCalculation = mortgageCalculation;
        analyzeScenario();
    }

    public void analyzeScenario() {
        calculateDebtToIncomeRatio();
        assessApprovalLikelihood();
        determineRiskLevel();
        generateRecommendations();
    }

    private void calculateDebtToIncomeRatio() {
        if (monthlyIncome > 0) {
            double totalMonthlyDebt = monthlyDebts + (mortgageCalculation != null ? mortgageCalculation.getTotalMonthlyPayment() : 0);
            debtToIncomeRatio = (totalMonthlyDebt / monthlyIncome) * 100;
        }
    }

    private void assessApprovalLikelihood() {
        isApprovalLikely = debtToIncomeRatio <= 43 && monthlyIncome > 0 && 
                          mortgageCalculation != null && mortgageCalculation.getDownPaymentPercentage() >= 3;
    }

    private void determineRiskLevel() {
        if (debtToIncomeRatio <= 28) {
            riskLevel = "Low";
        } else if (debtToIncomeRatio <= 36) {
            riskLevel = "Moderate";
        } else if (debtToIncomeRatio <= 43) {
            riskLevel = "High";
        } else {
            riskLevel = "Very High";
        }
    }

    private void generateRecommendations() {
        recommendations.clear();

        if (mortgageCalculation == null) return;

        if (debtToIncomeRatio > 43) {
            recommendations.add("Consider reducing monthly debts or increasing income");
            recommendations.add("Look for homes with lower monthly payments");
        }

        if (mortgageCalculation.getDownPaymentPercentage() < 20) {
            recommendations.add("Consider saving for a larger down payment to avoid PMI");
        }

        if (mortgageCalculation.isPmiRequired()) {
            recommendations.add("PMI required - consider 20% down payment to avoid it");
        }

        if (mortgageCalculation.getInterestRate() > 7.0) {
            recommendations.add("Interest rate is high - consider improving credit score");
        }

        if (closingCosts > mortgageCalculation.getHomePrice() * 0.05) {
            recommendations.add("Closing costs seem high - shop around for better rates");
        }

        if (monthlyIncome > 0) {
            double housingRatio = (mortgageCalculation.getTotalMonthlyPayment() / monthlyIncome) * 100;
            if (housingRatio > 28) {
                recommendations.add("Housing payment exceeds 28% of income - consider lower price range");
            }
        }
    }

    // Getters and Setters
    public String getScenarioName() { return scenarioName; }
    public void setScenarioName(String scenarioName) { this.scenarioName = scenarioName; }

    public MortgageCalculation getMortgageCalculation() { return mortgageCalculation; }
    public void setMortgageCalculation(MortgageCalculation mortgageCalculation) {
        this.mortgageCalculation = mortgageCalculation;
        analyzeScenario();
    }

    public double getClosingCosts() { return closingCosts; }
    public void setClosingCosts(double closingCosts) {
        this.closingCosts = closingCosts;
        analyzeScenario();
    }

    public double getMonthlyIncome() { return monthlyIncome; }
    public void setMonthlyIncome(double monthlyIncome) {
        this.monthlyIncome = monthlyIncome;
        analyzeScenario();
    }

    public double getMonthlyDebts() { return monthlyDebts; }
    public void setMonthlyDebts(double monthlyDebts) {
        this.monthlyDebts = monthlyDebts;
        analyzeScenario();
    }

    public double getDebtToIncomeRatio() { return debtToIncomeRatio; }
    public boolean isApprovalLikely() { return isApprovalLikely; }
    public String getRiskLevel() { return riskLevel; }
    public List<String> getRecommendations() { return recommendations; }
    public long getTimestamp() { return timestamp; }

    public double getTotalUpfrontCosts() {
        double downPayment = mortgageCalculation != null ? mortgageCalculation.getDownPayment() : 0;
        return downPayment + closingCosts;
    }

    public double getHousingPaymentRatio() {
        if (monthlyIncome <= 0 || mortgageCalculation == null) return 0;
        return (mortgageCalculation.getTotalMonthlyPayment() / monthlyIncome) * 100;
    }
}