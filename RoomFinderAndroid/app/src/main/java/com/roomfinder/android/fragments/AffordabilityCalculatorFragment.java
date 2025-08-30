package com.roomfinder.android.fragments;

import android.content.Intent;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.textfield.TextInputEditText;
import com.roomfinder.android.R;
import com.roomfinder.android.models.MortgageCalculation;
import com.roomfinder.android.models.MortgageScenario;
import com.roomfinder.android.services.MortgageCalculatorService;
import com.roomfinder.android.services.MortgageAnalyticsService;
import java.text.NumberFormat;
import java.util.Locale;

public class AffordabilityCalculatorFragment extends Fragment {

    private TextInputEditText annualIncomeInput;
    private TextInputEditText monthlyDebtsInput;
    private TextInputEditText downPaymentInput;
    private TextInputEditText interestRateInput;
    
    private MaterialButton dti28;
    private MaterialButton dti36;
    private MaterialButton dti43;
    private MaterialButton calculateAffordabilityButton;
    
    private LinearLayout resultsSection;
    private TextView maxHomePriceResult;
    private TextView affordabilitySubtext;
    private TextView financialHealthGrade;
    private TextView financialHealthDescription;
    private TextView financialRecommendations;
    private TextView monthlyPaymentResult;
    private TextView loanAmountResult;
    private TextView affordabilityBreakdown;
    
    private MaterialButton stressTestButton;
    private MaterialButton shareAffordabilityButton;
    
    private double selectedDTI = 36.0;
    private NumberFormat currencyFormat;
    private MortgageScenario currentScenario;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_affordability_calculator, container, false);
        
        initializeViews(view);
        setupButtonListeners();
        
        currencyFormat = NumberFormat.getCurrencyInstance(Locale.US);
        
        return view;
    }

    private void initializeViews(View view) {
        annualIncomeInput = view.findViewById(R.id.annualIncomeInput);
        monthlyDebtsInput = view.findViewById(R.id.monthlyDebtsInput);
        downPaymentInput = view.findViewById(R.id.downPaymentInput);
        interestRateInput = view.findViewById(R.id.interestRateInput);
        
        dti28 = view.findViewById(R.id.dti28);
        dti36 = view.findViewById(R.id.dti36);
        dti43 = view.findViewById(R.id.dti43);
        calculateAffordabilityButton = view.findViewById(R.id.calculateAffordabilityButton);
        
        resultsSection = view.findViewById(R.id.resultsSection);
        maxHomePriceResult = view.findViewById(R.id.maxHomePriceResult);
        affordabilitySubtext = view.findViewById(R.id.affordabilitySubtext);
        financialHealthGrade = view.findViewById(R.id.financialHealthGrade);
        financialHealthDescription = view.findViewById(R.id.financialHealthDescription);
        financialRecommendations = view.findViewById(R.id.financialRecommendations);
        monthlyPaymentResult = view.findViewById(R.id.monthlyPaymentResult);
        loanAmountResult = view.findViewById(R.id.loanAmountResult);
        affordabilityBreakdown = view.findViewById(R.id.affordabilityBreakdown);
        
        stressTestButton = view.findViewById(R.id.stressTestButton);
        shareAffordabilityButton = view.findViewById(R.id.shareAffordabilityButton);
    }

    private void setupButtonListeners() {
        dti28.setOnClickListener(v -> {
            selectedDTI = 28.0;
            updateDTIButtons();
        });

        dti36.setOnClickListener(v -> {
            selectedDTI = 36.0;
            updateDTIButtons();
        });

        dti43.setOnClickListener(v -> {
            selectedDTI = 43.0;
            updateDTIButtons();
        });

        calculateAffordabilityButton.setOnClickListener(v -> calculateAffordability());
        
        stressTestButton.setOnClickListener(v -> performStressTest());
        
        shareAffordabilityButton.setOnClickListener(v -> shareResults());
    }

    private void updateDTIButtons() {
        // Reset all buttons
        resetDTIButtonStyles();
        
        // Highlight selected button
        MaterialButton selectedButton = null;
        if (selectedDTI == 28.0) {
            selectedButton = dti28;
        } else if (selectedDTI == 36.0) {
            selectedButton = dti36;
        } else if (selectedDTI == 43.0) {
            selectedButton = dti43;
        }
        
        if (selectedButton != null) {
            selectedButton.setBackgroundTintList(getResources().getColorStateList(R.color.success, null));
            selectedButton.setTextColor(getResources().getColor(R.color.white, null));
        }
    }

    private void resetDTIButtonStyles() {
        MaterialButton[] buttons = {dti28, dti36, dti43};
        for (MaterialButton button : buttons) {
            button.setBackgroundTintList(getResources().getColorStateList(R.color.gray_100, null));
            button.setTextColor(getResources().getColor(R.color.text_primary, null));
        }
    }

    private void calculateAffordability() {
        try {
            // Get input values
            String annualIncomeText = annualIncomeInput.getText().toString().trim();
            String monthlyDebtsText = monthlyDebtsInput.getText().toString().trim();
            String downPaymentText = downPaymentInput.getText().toString().trim();
            String interestRateText = interestRateInput.getText().toString().trim();

            if (annualIncomeText.isEmpty() || monthlyDebtsText.isEmpty() || 
                downPaymentText.isEmpty() || interestRateText.isEmpty()) {
                showError("Please fill in all fields");
                return;
            }

            double annualIncome = Double.parseDouble(annualIncomeText);
            double monthlyDebts = Double.parseDouble(monthlyDebtsText);
            double downPayment = Double.parseDouble(downPaymentText);
            double interestRate = Double.parseDouble(interestRateText);

            // Validate inputs
            if (annualIncome <= 0) {
                showError("Annual income must be greater than 0");
                return;
            }

            if (monthlyDebts < 0) {
                showError("Monthly debts cannot be negative");
                return;
            }

            if (downPayment <= 0) {
                showError("Down payment must be greater than 0");
                return;
            }

            if (interestRate <= 0 || interestRate > 30) {
                showError("Interest rate must be between 0% and 30%");
                return;
            }

            // Calculate affordability
            double monthlyIncome = annualIncome / 12;
            
            double maxHomePrice = MortgageCalculatorService.calculateAffordability(
                monthlyIncome, monthlyDebts, downPayment, interestRate, 30, selectedDTI);

            // Create mortgage calculation for the affordable home price
            MortgageCalculation calculation = MortgageCalculatorService.calculateMortgage(
                maxHomePrice, downPayment, interestRate, 30);

            // Create scenario for analysis
            currentScenario = new MortgageScenario("Affordability Analysis", calculation);
            currentScenario.setMonthlyIncome(monthlyIncome);
            currentScenario.setMonthlyDebts(monthlyDebts);

            // Display results
            displayAffordabilityResults(maxHomePrice, calculation, monthlyIncome);
            resultsSection.setVisibility(View.VISIBLE);

        } catch (NumberFormatException e) {
            showError("Please enter valid numbers");
        } catch (Exception e) {
            showError("Error calculating affordability: " + e.getMessage());
        }
    }

    private void displayAffordabilityResults(double maxHomePrice, MortgageCalculation calculation, double monthlyIncome) {
        if (calculation == null || currentScenario == null) return;

        // Display main results
        maxHomePriceResult.setText(currencyFormat.format(maxHomePrice));
        affordabilitySubtext.setText("Based on " + String.format("%.0f%%", selectedDTI) + " debt-to-income ratio");
        
        monthlyPaymentResult.setText(currencyFormat.format(calculation.getMonthlyPayment()));
        loanAmountResult.setText(currencyFormat.format(calculation.getLoanAmount()));

        // Calculate and display financial health score
        MortgageAnalyticsService.FinancialHealthScore healthScore = 
            MortgageAnalyticsService.analyzeFinancialHealth(currentScenario);
            
        financialHealthGrade.setText(healthScore.grade);
        financialHealthDescription.setText(healthScore.description);
        
        // Update grade color based on score
        int gradeColor;
        if (healthScore.score >= 80) {
            gradeColor = R.color.success;
        } else if (healthScore.score >= 60) {
            gradeColor = R.color.warning;
        } else {
            gradeColor = R.color.error;
        }
        financialHealthGrade.setTextColor(getResources().getColor(gradeColor, null));
        // Set background color based on grade
        int backgroundColorResource = R.color.success_light;
        if (healthScore.score >= 80) {
            backgroundColorResource = R.color.success_light;
        } else if (healthScore.score >= 60) {
            backgroundColorResource = R.color.warning_light;
        } else {
            backgroundColorResource = R.color.gray_100;
        }
        financialHealthGrade.setBackgroundTintList(getResources().getColorStateList(backgroundColorResource, null));

        // Display recommendations
        StringBuilder recommendations = new StringBuilder();
        for (String strength : healthScore.strengths) {
            recommendations.append("✓ ").append(strength).append("\n");
        }
        for (String improvement : healthScore.improvements) {
            recommendations.append("• ").append(improvement).append("\n");
        }
        financialRecommendations.setText(recommendations.toString().trim());

        // Display detailed breakdown
        displayAffordabilityBreakdown(calculation, monthlyIncome, maxHomePrice);
    }

    private void displayAffordabilityBreakdown(MortgageCalculation calculation, double monthlyIncome, double maxHomePrice) {
        double annualIncome = monthlyIncome * 12;
        double monthlyDebts = Double.parseDouble(monthlyDebtsInput.getText().toString());
        
        StringBuilder breakdown = new StringBuilder();
        breakdown.append("Annual Income: ").append(currencyFormat.format(annualIncome)).append("\n");
        breakdown.append("Monthly Income: ").append(currencyFormat.format(monthlyIncome)).append("\n");
        breakdown.append("Monthly Debts: ").append(currencyFormat.format(monthlyDebts)).append("\n");
        breakdown.append("Debt-to-Income Ratio: ").append(String.format("%.0f%%", selectedDTI)).append("\n\n");
        
        breakdown.append("Maximum Housing Payment: ").append(currencyFormat.format(calculation.getMonthlyPayment())).append("\n");
        breakdown.append("Down Payment: ").append(currencyFormat.format(calculation.getDownPayment())).append("\n");
        breakdown.append("Loan Amount: ").append(currencyFormat.format(calculation.getLoanAmount())).append("\n\n");
        
        double minPrice = maxHomePrice * 0.75; // 75% of max as minimum recommended
        breakdown.append("Recommended Price Range: ").append(currencyFormat.format(minPrice))
                .append(" - ").append(currencyFormat.format(maxHomePrice));
        
        affordabilityBreakdown.setText(breakdown.toString());
    }

    private void performStressTest() {
        if (currentScenario == null || currentScenario.getMortgageCalculation() == null) {
            showError("Please calculate affordability first");
            return;
        }

        try {
            MortgageAnalyticsService.StressTestResult stressTest = 
                MortgageAnalyticsService.performCanadianStressTest(
                    currentScenario.getMortgageCalculation(),
                    currentScenario.getMonthlyIncome(),
                    currentScenario.getMonthlyDebts()
                );

            // Show stress test results in a toast for now
            // In a full implementation, this would open a dialog or new fragment
            String message = String.format("Stress Test: %s\nRate: %.2f%%\nPayment: %s\nResult: %s",
                stressTest.passesStressTest ? "PASSED" : "FAILED",
                stressTest.stressTestRate,
                currencyFormat.format(stressTest.stressTestPayment),
                stressTest.riskLevel);

            Toast.makeText(getContext(), message, Toast.LENGTH_LONG).show();

        } catch (Exception e) {
            showError("Error performing stress test");
        }
    }

    private void shareResults() {
        if (currentScenario == null || currentScenario.getMortgageCalculation() == null) {
            showError("Please calculate affordability first");
            return;
        }

        try {
            MortgageCalculation calc = currentScenario.getMortgageCalculation();
            
            String shareText = "Home Affordability Analysis:\n\n" +
                "Annual Income: " + currencyFormat.format(currentScenario.getMonthlyIncome() * 12) + "\n" +
                "Monthly Debts: " + currencyFormat.format(currentScenario.getMonthlyDebts()) + "\n" +
                "Down Payment: " + currencyFormat.format(calc.getDownPayment()) + "\n" +
                "Interest Rate: " + String.format("%.2f%%", calc.getInterestRate()) + "\n" +
                "DTI Ratio: " + String.format("%.0f%%", selectedDTI) + "\n\n" +
                "Maximum Home Price: " + currencyFormat.format(calc.getHomePrice()) + "\n" +
                "Monthly Payment: " + currencyFormat.format(calc.getMonthlyPayment()) + "\n" +
                "Loan Amount: " + currencyFormat.format(calc.getLoanAmount()) + "\n\n" +
                "Calculated with RoomFinder Affordability Calculator";

            Intent shareIntent = new Intent(Intent.ACTION_SEND);
            shareIntent.setType("text/plain");
            shareIntent.putExtra(Intent.EXTRA_TEXT, shareText);
            startActivity(Intent.createChooser(shareIntent, "Share Affordability Results"));

        } catch (Exception e) {
            showError("Error sharing results");
        }
    }

    private void showError(String message) {
        if (getContext() != null) {
            Toast.makeText(getContext(), message, Toast.LENGTH_SHORT).show();
        }
    }
}