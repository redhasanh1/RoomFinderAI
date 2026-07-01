package com.roomfinder.android.services;

import com.roomfinder.android.models.MortgageRate;
import java.util.Arrays;
import java.util.List;
import java.util.ArrayList;
import java.util.Random;

public class MortgageRateService {
    
    private static final Random random = new Random();
    private static MortgageRate[] cachedRates;
    private static long lastUpdateTime = 0;
    private static final long CACHE_DURATION = 15 * 60 * 1000; // 15 minutes

    public static List<MortgageRate> getCurrentRates() {
        updateRatesIfNeeded();
        return Arrays.asList(cachedRates);
    }

    public static MortgageRate getRateForLoanType(MortgageRate.LoanType loanType) {
        updateRatesIfNeeded();
        
        for (MortgageRate rate : cachedRates) {
            if (rate.getLoanType() == loanType) {
                return rate;
            }
        }
        
        // Fallback to default rate if not found
        return new MortgageRate(loanType, 7.25, 7.35);
    }

    public static MortgageRate getBestAvailableRate(double loanAmount, int creditScore, double downPaymentPercent) {
        updateRatesIfNeeded();
        
        MortgageRate bestRate = null;
        double lowestRate = Double.MAX_VALUE;
        
        for (MortgageRate rate : cachedRates) {
            if (rate.isEligible(loanAmount, creditScore, downPaymentPercent) && rate.getRate() < lowestRate) {
                lowestRate = rate.getRate();
                bestRate = rate;
            }
        }
        
        return bestRate;
    }

    public static List<MortgageRate> getEligibleRates(double loanAmount, int creditScore, double downPaymentPercent) {
        updateRatesIfNeeded();
        
        List<MortgageRate> eligibleRates = new ArrayList<>();
        
        for (MortgageRate rate : cachedRates) {
            if (rate.isEligible(loanAmount, creditScore, downPaymentPercent)) {
                eligibleRates.add(rate);
            }
        }
        
        return eligibleRates;
    }

    private static void updateRatesIfNeeded() {
        long currentTime = System.currentTimeMillis();
        
        if (cachedRates == null || (currentTime - lastUpdateTime) > CACHE_DURATION) {
            refreshRates();
            lastUpdateTime = currentTime;
        }
    }

    private static void refreshRates() {
        // Simulate realistic market rate fluctuations
        cachedRates = new MortgageRate[] {
            createRate(MortgageRate.LoanType.CONVENTIONAL_30_YEAR, 7.25, 7.35, "Wells Fargo"),
            createRate(MortgageRate.LoanType.CONVENTIONAL_15_YEAR, 6.75, 6.85, "Chase Bank"),
            createRate(MortgageRate.LoanType.FHA_30_YEAR, 7.15, 7.45, "Quicken Loans"),
            createRate(MortgageRate.LoanType.VA_30_YEAR, 7.05, 7.25, "Navy Federal"),
            createRate(MortgageRate.LoanType.JUMBO_30_YEAR, 7.35, 7.45, "Bank of America"),
            createRate(MortgageRate.LoanType.ARM_5_1, 6.85, 7.15, "Rocket Mortgage")
        };
        
        // Add some rate variation
        for (MortgageRate rate : cachedRates) {
            double variation = (random.nextDouble() - 0.5) * 0.3; // ±0.15% variation
            double newRate = Math.max(5.0, Math.min(9.0, rate.getRate() + variation));
            rate.setRate(newRate);
            rate.setApr(newRate + 0.1); // APR typically 0.1% higher
        }
    }

    private static MortgageRate createRate(MortgageRate.LoanType loanType, double rate, double apr, String lender) {
        MortgageRate mortgageRate = new MortgageRate(loanType, rate, apr);
        mortgageRate.setLenderName(lender);
        return mortgageRate;
    }

    public static double getMarketAverageRate() {
        updateRatesIfNeeded();
        
        double totalRate = 0;
        int count = 0;
        
        for (MortgageRate rate : cachedRates) {
            if (rate.getLoanType() == MortgageRate.LoanType.CONVENTIONAL_30_YEAR ||
                rate.getLoanType() == MortgageRate.LoanType.CONVENTIONAL_15_YEAR) {
                totalRate += rate.getRate();
                count++;
            }
        }
        
        return count > 0 ? totalRate / count : 7.25;
    }

    public static String getRateTrend() {
        // This would typically come from external API
        // For now, simulate based on current rates
        double currentAverage = getMarketAverageRate();
        
        if (currentAverage < 7.0) {
            return "Rates are historically low";
        } else if (currentAverage > 7.5) {
            return "Rates are elevated";
        } else {
            return "Rates are moderate";
        }
    }

    public static List<String> getRateFactors(int creditScore) {
        List<String> factors = new ArrayList<>();
        
        if (creditScore >= 760) {
            factors.add("Excellent credit - qualify for best rates");
        } else if (creditScore >= 700) {
            factors.add("Good credit - qualify for competitive rates");
        } else if (creditScore >= 640) {
            factors.add("Fair credit - may pay higher rates");
        } else {
            factors.add("Poor credit - limited options with higher rates");
        }
        
        factors.add("Current Federal Reserve policy impacts rates");
        factors.add("Market volatility affects daily rate changes");
        factors.add("Loan amount and down payment affect rate offers");
        
        return factors;
    }

    public static double estimateRateWithCreditScore(MortgageRate baseRate, int creditScore) {
        double adjustment = 0;
        
        if (creditScore >= 760) {
            adjustment = -0.125; // Best rate
        } else if (creditScore >= 700) {
            adjustment = 0; // Base rate
        } else if (creditScore >= 680) {
            adjustment = 0.125;
        } else if (creditScore >= 660) {
            adjustment = 0.25;
        } else if (creditScore >= 640) {
            adjustment = 0.375;
        } else if (creditScore >= 620) {
            adjustment = 0.5;
        } else {
            adjustment = 0.75; // Poor credit penalty
        }
        
        return Math.max(5.0, baseRate.getRate() + adjustment);
    }

    public static MortgageRate createCustomRate(MortgageRate.LoanType loanType, int creditScore, 
                                              double loanAmount, double downPaymentPercent) {
        MortgageRate baseRate = getRateForLoanType(loanType);
        double adjustedRate = estimateRateWithCreditScore(baseRate, creditScore);
        
        // LTV adjustment
        double ltvRatio = ((loanAmount) / (loanAmount + (loanAmount * downPaymentPercent / 100))) * 100;
        if (ltvRatio > 90) {
            adjustedRate += 0.125;
        } else if (ltvRatio > 80) {
            adjustedRate += 0.0625;
        }
        
        MortgageRate customRate = new MortgageRate(loanType, adjustedRate, adjustedRate + 0.1);
        customRate.setLenderName("Estimated Rate");
        
        return customRate;
    }
}