package com.roomfinder.android.models;

public class MortgageRate {
    public enum LoanType {
        CONVENTIONAL_30_YEAR("30-Year Fixed"),
        CONVENTIONAL_15_YEAR("15-Year Fixed"),
        FHA_30_YEAR("FHA 30-Year"),
        VA_30_YEAR("VA 30-Year"),
        JUMBO_30_YEAR("Jumbo 30-Year"),
        ARM_5_1("5/1 ARM");

        private final String displayName;

        LoanType(String displayName) {
            this.displayName = displayName;
        }

        public String getDisplayName() {
            return displayName;
        }
    }

    private LoanType loanType;
    private double rate;
    private double apr;
    private int points;
    private String lenderName;
    private long lastUpdated;
    private boolean isFeatured;
    private double minDownPayment;
    private double maxLoanAmount;
    private int creditScoreMin;

    public MortgageRate() {
        this.lastUpdated = System.currentTimeMillis();
    }

    public MortgageRate(LoanType loanType, double rate, double apr) {
        this();
        this.loanType = loanType;
        this.rate = rate;
        this.apr = apr;
        setDefaultValues();
    }

    private void setDefaultValues() {
        switch (loanType) {
            case CONVENTIONAL_30_YEAR:
                this.minDownPayment = 3.0;
                this.maxLoanAmount = 766550;
                this.creditScoreMin = 620;
                break;
            case CONVENTIONAL_15_YEAR:
                this.minDownPayment = 3.0;
                this.maxLoanAmount = 766550;
                this.creditScoreMin = 620;
                break;
            case FHA_30_YEAR:
                this.minDownPayment = 3.5;
                this.maxLoanAmount = 472030;
                this.creditScoreMin = 580;
                break;
            case VA_30_YEAR:
                this.minDownPayment = 0.0;
                this.maxLoanAmount = 766550;
                this.creditScoreMin = 580;
                break;
            case JUMBO_30_YEAR:
                this.minDownPayment = 10.0;
                this.maxLoanAmount = Double.MAX_VALUE;
                this.creditScoreMin = 700;
                break;
            case ARM_5_1:
                this.minDownPayment = 5.0;
                this.maxLoanAmount = 766550;
                this.creditScoreMin = 640;
                break;
        }
    }

    // Static methods for getting current market rates
    public static MortgageRate[] getCurrentRates() {
        return new MortgageRate[] {
            new MortgageRate(LoanType.CONVENTIONAL_30_YEAR, 7.25, 7.35),
            new MortgageRate(LoanType.CONVENTIONAL_15_YEAR, 6.75, 6.85),
            new MortgageRate(LoanType.FHA_30_YEAR, 7.15, 7.45),
            new MortgageRate(LoanType.VA_30_YEAR, 7.05, 7.25),
            new MortgageRate(LoanType.JUMBO_30_YEAR, 7.35, 7.45),
            new MortgageRate(LoanType.ARM_5_1, 6.85, 7.15)
        };
    }

    public static MortgageRate getBestRate() {
        MortgageRate[] rates = getCurrentRates();
        MortgageRate bestRate = rates[0];
        for (MortgageRate rate : rates) {
            if (rate.getRate() < bestRate.getRate()) {
                bestRate = rate;
            }
        }
        return bestRate;
    }

    // Utility methods
    public boolean isEligible(double loanAmount, int creditScore, double downPaymentPercent) {
        return loanAmount <= maxLoanAmount && 
               creditScore >= creditScoreMin && 
               downPaymentPercent >= minDownPayment;
    }

    public String getFormattedRate() {
        return String.format("%.3f%%", rate);
    }

    public String getFormattedAPR() {
        return String.format("%.3f%%", apr);
    }

    public String getRateComparison() {
        double marketAverage = 7.20; // Current market average
        double difference = rate - marketAverage;
        if (difference < -0.1) {
            return String.format("%.2f%% below market", Math.abs(difference));
        } else if (difference > 0.1) {
            return String.format("%.2f%% above market", difference);
        } else {
            return "Near market rate";
        }
    }

    // Getters and Setters
    public LoanType getLoanType() { return loanType; }
    public void setLoanType(LoanType loanType) { this.loanType = loanType; }

    public double getRate() { return rate; }
    public void setRate(double rate) { this.rate = rate; }

    public double getApr() { return apr; }
    public void setApr(double apr) { this.apr = apr; }

    public int getPoints() { return points; }
    public void setPoints(int points) { this.points = points; }

    public String getLenderName() { return lenderName; }
    public void setLenderName(String lenderName) { this.lenderName = lenderName; }

    public long getLastUpdated() { return lastUpdated; }
    public void setLastUpdated(long lastUpdated) { this.lastUpdated = lastUpdated; }

    public boolean isFeatured() { return isFeatured; }
    public void setFeatured(boolean featured) { isFeatured = featured; }

    public double getMinDownPayment() { return minDownPayment; }
    public void setMinDownPayment(double minDownPayment) { this.minDownPayment = minDownPayment; }

    public double getMaxLoanAmount() { return maxLoanAmount; }
    public void setMaxLoanAmount(double maxLoanAmount) { this.maxLoanAmount = maxLoanAmount; }

    public int getCreditScoreMin() { return creditScoreMin; }
    public void setCreditScoreMin(int creditScoreMin) { this.creditScoreMin = creditScoreMin; }
}