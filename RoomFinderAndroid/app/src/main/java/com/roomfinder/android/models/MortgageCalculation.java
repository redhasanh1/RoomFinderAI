package com.roomfinder.android.models;

public class MortgageCalculation {
    private double loanAmount;
    private double interestRate;
    private int loanTermYears;
    private double monthlyPayment;
    private double totalInterest;
    private double totalAmount;
    private double downPayment;
    private double homePrice;
    private double pmiAmount;
    private double propertyTax;
    private double homeInsurance;
    private double totalMonthlyPayment;

    public MortgageCalculation() {}

    public MortgageCalculation(double loanAmount, double interestRate, int loanTermYears) {
        this.loanAmount = loanAmount;
        this.interestRate = interestRate;
        this.loanTermYears = loanTermYears;
        calculatePayments();
    }

    public void calculatePayments() {
        if (loanAmount <= 0 || interestRate < 0 || loanTermYears <= 0) {
            return;
        }

        double monthlyRate = interestRate / 100 / 12;
        int totalMonths = loanTermYears * 12;

        if (monthlyRate > 0) {
            monthlyPayment = loanAmount * (monthlyRate * Math.pow(1 + monthlyRate, totalMonths)) 
                           / (Math.pow(1 + monthlyRate, totalMonths) - 1);
        } else {
            monthlyPayment = loanAmount / totalMonths;
        }

        totalAmount = monthlyPayment * totalMonths;
        totalInterest = totalAmount - loanAmount;
        
        calculateTotalMonthlyPayment();
    }

    private void calculateTotalMonthlyPayment() {
        totalMonthlyPayment = monthlyPayment + pmiAmount + propertyTax + homeInsurance;
    }

    // Getters and Setters
    public double getLoanAmount() { return loanAmount; }
    public void setLoanAmount(double loanAmount) {
        this.loanAmount = loanAmount;
        calculatePayments();
    }

    public double getInterestRate() { return interestRate; }
    public void setInterestRate(double interestRate) {
        this.interestRate = interestRate;
        calculatePayments();
    }

    public int getLoanTermYears() { return loanTermYears; }
    public void setLoanTermYears(int loanTermYears) {
        this.loanTermYears = loanTermYears;
        calculatePayments();
    }

    public double getMonthlyPayment() { return monthlyPayment; }
    public double getTotalInterest() { return totalInterest; }
    public double getTotalAmount() { return totalAmount; }

    public double getDownPayment() { return downPayment; }
    public void setDownPayment(double downPayment) {
        this.downPayment = downPayment;
        this.loanAmount = homePrice - downPayment;
        calculatePayments();
    }

    public double getHomePrice() { return homePrice; }
    public void setHomePrice(double homePrice) {
        this.homePrice = homePrice;
        this.loanAmount = homePrice - downPayment;
        calculatePayments();
    }

    public double getPmiAmount() { return pmiAmount; }
    public void setPmiAmount(double pmiAmount) {
        this.pmiAmount = pmiAmount;
        calculateTotalMonthlyPayment();
    }

    public double getPropertyTax() { return propertyTax; }
    public void setPropertyTax(double propertyTax) {
        this.propertyTax = propertyTax;
        calculateTotalMonthlyPayment();
    }

    public double getHomeInsurance() { return homeInsurance; }
    public void setHomeInsurance(double homeInsurance) {
        this.homeInsurance = homeInsurance;
        calculateTotalMonthlyPayment();
    }

    public double getTotalMonthlyPayment() { return totalMonthlyPayment; }

    public double getDownPaymentPercentage() {
        return homePrice > 0 ? (downPayment / homePrice) * 100 : 0;
    }

    public double getLoanToValueRatio() {
        return homePrice > 0 ? (loanAmount / homePrice) * 100 : 0;
    }

    public boolean isPmiRequired() {
        return getLoanToValueRatio() > 80;
    }
}