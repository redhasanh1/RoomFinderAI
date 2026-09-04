package com.roomfinder.android.services;

import com.roomfinder.android.models.MortgageCalculation;
import com.roomfinder.android.models.MortgageRate;
import java.util.ArrayList;
import java.util.List;

public class MortgageCalculatorService {
    
    public static class AmortizationEntry {
        public int month;
        public double payment;
        public double principal;
        public double interest;
        public double remainingBalance;
        
        public AmortizationEntry(int month, double payment, double principal, double interest, double remainingBalance) {
            this.month = month;
            this.payment = payment;
            this.principal = principal;
            this.interest = interest;
            this.remainingBalance = remainingBalance;
        }
    }

    public static MortgageCalculation calculateMortgage(double homePrice, double downPayment, 
                                                      double interestRate, int loanTermYears) {
        MortgageCalculation calculation = new MortgageCalculation();
        calculation.setHomePrice(homePrice);
        calculation.setDownPayment(downPayment);
        calculation.setInterestRate(interestRate);
        calculation.setLoanTermYears(loanTermYears);
        
        // Calculate PMI if down payment is less than 20%
        if (calculation.getDownPaymentPercentage() < 20) {
            double pmi = calculation.getLoanAmount() * 0.005 / 12; // 0.5% annually
            calculation.setPmiAmount(pmi);
        }
        
        // Estimate property tax (1.2% annually average)
        double propertyTax = homePrice * 0.012 / 12;
        calculation.setPropertyTax(propertyTax);
        
        // Estimate home insurance (0.35% annually average)
        double homeInsurance = homePrice * 0.0035 / 12;
        calculation.setHomeInsurance(homeInsurance);
        
        return calculation;
    }

    public static double calculateAffordability(double monthlyIncome, double monthlyDebts, 
                                              double downPayment, double interestRate, 
                                              int loanTermYears, double debtToIncomeRatio) {
        
        // Calculate maximum monthly housing payment (DTI ratio - existing debts)
        double maxHousingPayment = (monthlyIncome * (debtToIncomeRatio / 100)) - monthlyDebts;
        
        // Account for property tax, insurance, and potential PMI (roughly 30% of total payment)
        double maxPrincipalAndInterest = maxHousingPayment * 0.70;
        
        // Calculate maximum loan amount based on payment capacity
        double monthlyRate = interestRate / 100 / 12;
        int totalMonths = loanTermYears * 12;
        
        double maxLoanAmount = 0;
        if (monthlyRate > 0) {
            maxLoanAmount = maxPrincipalAndInterest * (Math.pow(1 + monthlyRate, totalMonths) - 1) 
                           / (monthlyRate * Math.pow(1 + monthlyRate, totalMonths));
        } else {
            maxLoanAmount = maxPrincipalAndInterest * totalMonths;
        }
        
        return maxLoanAmount + downPayment;
    }

    public static List<AmortizationEntry> generateAmortizationSchedule(MortgageCalculation calculation) {
        List<AmortizationEntry> schedule = new ArrayList<>();
        
        if (calculation.getLoanAmount() <= 0 || calculation.getInterestRate() < 0 || 
            calculation.getLoanTermYears() <= 0) {
            return schedule;
        }
        
        double remainingBalance = calculation.getLoanAmount();
        double monthlyRate = calculation.getInterestRate() / 100 / 12;
        double monthlyPayment = calculation.getMonthlyPayment();
        int totalMonths = calculation.getLoanTermYears() * 12;
        
        for (int month = 1; month <= totalMonths && remainingBalance > 0.01; month++) {
            double interestPayment = remainingBalance * monthlyRate;
            double principalPayment = monthlyPayment - interestPayment;
            
            // Handle final payment
            if (principalPayment > remainingBalance) {
                principalPayment = remainingBalance;
                monthlyPayment = principalPayment + interestPayment;
            }
            
            remainingBalance -= principalPayment;
            
            schedule.add(new AmortizationEntry(month, monthlyPayment, principalPayment, 
                                             interestPayment, remainingBalance));
        }
        
        return schedule;
    }

    public static double calculateRefinanceSavings(MortgageCalculation currentMortgage, 
                                                  MortgageCalculation newMortgage, 
                                                  double closingCosts, int monthsRemaining) {
        
        double currentTotalPayments = currentMortgage.getMonthlyPayment() * monthsRemaining;
        double newTotalPayments = newMortgage.getTotalAmount() + closingCosts;
        
        return currentTotalPayments - newTotalPayments;
    }

    public static int calculateBreakEvenPoint(MortgageCalculation currentMortgage, 
                                            MortgageCalculation newMortgage, 
                                            double closingCosts) {
        
        double monthlySavings = currentMortgage.getMonthlyPayment() - newMortgage.getMonthlyPayment();
        
        if (monthlySavings <= 0) {
            return -1; // No break-even point
        }
        
        return (int) Math.ceil(closingCosts / monthlySavings);
    }

    public static double calculatePMI(double loanAmount, double homeValue, MortgageRate.LoanType loanType) {
        double ltvRatio = (loanAmount / homeValue) * 100;
        
        if (ltvRatio <= 80) {
            return 0; // No PMI required
        }
        
        double pmiRate = 0.005; // Default 0.5%
        
        switch (loanType) {
            case CONVENTIONAL_30_YEAR:
            case CONVENTIONAL_15_YEAR:
                if (ltvRatio > 95) {
                    pmiRate = 0.008; // 0.8%
                } else if (ltvRatio > 90) {
                    pmiRate = 0.006; // 0.6%
                } else {
                    pmiRate = 0.005; // 0.5%
                }
                break;
            case FHA_30_YEAR:
                pmiRate = 0.0085; // FHA MIP is typically 0.85%
                break;
            case VA_30_YEAR:
                return 0; // VA loans don't have PMI
            case JUMBO_30_YEAR:
                pmiRate = 0.007; // Jumbo loans typically have higher PMI
                break;
            case ARM_5_1:
                pmiRate = 0.0055;
                break;
        }
        
        return (loanAmount * pmiRate) / 12;
    }

    public static boolean canRemovePMI(double currentBalance, double originalHomeValue, 
                                     double currentHomeValue, int monthsPaid) {
        
        // Automatic removal at 78% LTV based on original value
        double currentLtvOriginal = (currentBalance / originalHomeValue) * 100;
        if (currentLtvOriginal <= 78) {
            return true;
        }
        
        // Request removal at 80% LTV based on current value (with appraisal)
        double currentLtvCurrent = (currentBalance / currentHomeValue) * 100;
        if (currentLtvCurrent <= 80 && monthsPaid >= 24) {
            return true;
        }
        
        return false;
    }

    public static String getPaymentBreakdown(MortgageCalculation calculation) {
        StringBuilder breakdown = new StringBuilder();
        breakdown.append("Principal & Interest: $").append(String.format("%.2f", calculation.getMonthlyPayment())).append("\n");
        
        if (calculation.getPropertyTax() > 0) {
            breakdown.append("Property Tax: $").append(String.format("%.2f", calculation.getPropertyTax())).append("\n");
        }
        
        if (calculation.getHomeInsurance() > 0) {
            breakdown.append("Home Insurance: $").append(String.format("%.2f", calculation.getHomeInsurance())).append("\n");
        }
        
        if (calculation.getPmiAmount() > 0) {
            breakdown.append("PMI: $").append(String.format("%.2f", calculation.getPmiAmount())).append("\n");
        }
        
        breakdown.append("Total Monthly Payment: $").append(String.format("%.2f", calculation.getTotalMonthlyPayment()));
        
        return breakdown.toString();
    }
}