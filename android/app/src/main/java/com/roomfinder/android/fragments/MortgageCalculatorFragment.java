package com.roomfinder.android.fragments;

import android.content.Intent;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
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
import com.roomfinder.android.services.MortgageCalculatorService;
import java.text.NumberFormat;
import java.util.Locale;

public class MortgageCalculatorFragment extends Fragment {

    private TextInputEditText homePriceInput;
    private TextInputEditText downPaymentInput;
    private TextInputEditText interestRateInput;
    private MaterialButton term15Years;
    private MaterialButton term30Years;
    private MaterialButton calculateButton;
    
    private LinearLayout resultsSection;
    private TextView monthlyPaymentResult;
    private TextView totalInterestResult;
    private TextView totalPaymentResult;
    private TextView paymentBreakdown;
    
    private MaterialButton viewAmortizationButton;
    private MaterialButton shareResultsButton;
    
    private MortgageCalculation currentCalculation;
    private int selectedTerm = 30;
    private NumberFormat currencyFormat;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_mortgage_calculator, container, false);
        
        initializeViews(view);
        setupInputListeners();
        setupButtonListeners();
        
        currencyFormat = NumberFormat.getCurrencyInstance(Locale.US);
        
        return view;
    }

    private void initializeViews(View view) {
        homePriceInput = view.findViewById(R.id.homePriceInput);
        downPaymentInput = view.findViewById(R.id.downPaymentInput);
        interestRateInput = view.findViewById(R.id.interestRateInput);
        term15Years = view.findViewById(R.id.term15Years);
        term30Years = view.findViewById(R.id.term30Years);
        calculateButton = view.findViewById(R.id.calculateButton);
        
        resultsSection = view.findViewById(R.id.resultsSection);
        monthlyPaymentResult = view.findViewById(R.id.monthlyPaymentResult);
        totalInterestResult = view.findViewById(R.id.totalInterestResult);
        totalPaymentResult = view.findViewById(R.id.totalPaymentResult);
        paymentBreakdown = view.findViewById(R.id.paymentBreakdown);
        
        viewAmortizationButton = view.findViewById(R.id.viewAmortizationButton);
        shareResultsButton = view.findViewById(R.id.shareResultsButton);
    }

    private void setupInputListeners() {
        TextWatcher inputWatcher = new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {}

            @Override
            public void afterTextChanged(Editable s) {
                // Auto-calculate when inputs change (optional)
                // calculateMortgage();
            }
        };

        homePriceInput.addTextChangedListener(inputWatcher);
        downPaymentInput.addTextChangedListener(inputWatcher);
        interestRateInput.addTextChangedListener(inputWatcher);
    }

    private void setupButtonListeners() {
        term15Years.setOnClickListener(v -> {
            selectedTerm = 15;
            updateTermButtons();
        });

        term30Years.setOnClickListener(v -> {
            selectedTerm = 30;
            updateTermButtons();
        });

        calculateButton.setOnClickListener(v -> calculateMortgage());
        
        viewAmortizationButton.setOnClickListener(v -> showAmortizationSchedule());
        
        shareResultsButton.setOnClickListener(v -> shareResults());
    }

    private void updateTermButtons() {
        if (selectedTerm == 15) {
            term15Years.setBackgroundTintList(getResources().getColorStateList(R.color.purple_primary, null));
            term15Years.setTextColor(getResources().getColor(R.color.white, null));
            term30Years.setBackgroundTintList(getResources().getColorStateList(R.color.gray_100, null));
            term30Years.setTextColor(getResources().getColor(R.color.text_primary, null));
        } else {
            term30Years.setBackgroundTintList(getResources().getColorStateList(R.color.purple_primary, null));
            term30Years.setTextColor(getResources().getColor(R.color.white, null));
            term15Years.setBackgroundTintList(getResources().getColorStateList(R.color.gray_100, null));
            term15Years.setTextColor(getResources().getColor(R.color.text_primary, null));
        }
    }

    private void calculateMortgage() {
        try {
            // Get input values
            String homePriceText = homePriceInput.getText().toString().trim();
            String downPaymentText = downPaymentInput.getText().toString().trim();
            String interestRateText = interestRateInput.getText().toString().trim();

            if (homePriceText.isEmpty() || downPaymentText.isEmpty() || interestRateText.isEmpty()) {
                showError("Please fill in all fields");
                return;
            }

            double homePrice = Double.parseDouble(homePriceText);
            double downPayment = Double.parseDouble(downPaymentText);
            double interestRate = Double.parseDouble(interestRateText);

            // Validate inputs
            if (homePrice <= 0) {
                showError("Home price must be greater than 0");
                return;
            }

            if (downPayment < 0 || downPayment >= homePrice) {
                showError("Down payment must be between 0 and home price");
                return;
            }

            if (interestRate < 0 || interestRate > 30) {
                showError("Interest rate must be between 0% and 30%");
                return;
            }

            // Calculate mortgage
            currentCalculation = MortgageCalculatorService.calculateMortgage(
                homePrice, downPayment, interestRate, selectedTerm);

            // Display results
            displayResults();
            resultsSection.setVisibility(View.VISIBLE);

        } catch (NumberFormatException e) {
            showError("Please enter valid numbers");
        } catch (Exception e) {
            showError("Error calculating mortgage: " + e.getMessage());
        }
    }

    private void displayResults() {
        if (currentCalculation == null) return;

        // Format and display main results
        monthlyPaymentResult.setText(currencyFormat.format(currentCalculation.getMonthlyPayment()));
        totalInterestResult.setText(currencyFormat.format(currentCalculation.getTotalInterest()));
        totalPaymentResult.setText(currencyFormat.format(currentCalculation.getTotalAmount()));

        // Display payment breakdown
        String breakdown = MortgageCalculatorService.getPaymentBreakdown(currentCalculation);
        paymentBreakdown.setText(breakdown);

        // Add helpful insights
        addInsights();
    }

    private void addInsights() {
        if (currentCalculation == null) return;

        String insights = "";
        
        // Down payment percentage insight
        double downPaymentPercent = currentCalculation.getDownPaymentPercentage();
        if (downPaymentPercent < 20) {
            insights += "• PMI required with " + String.format("%.1f%%", downPaymentPercent) + " down payment\n";
        } else {
            insights += "• No PMI required with " + String.format("%.1f%%", downPaymentPercent) + " down payment\n";
        }

        // Interest vs principal insight
        double interestPercent = (currentCalculation.getTotalInterest() / currentCalculation.getTotalAmount()) * 100;
        insights += "• " + String.format("%.1f%%", interestPercent) + " of total payments go to interest\n";

        // Compare 15 vs 30 year
        if (selectedTerm == 30) {
            MortgageCalculation calc15Year = new MortgageCalculation(
                currentCalculation.getLoanAmount(), 
                currentCalculation.getInterestRate() - 0.5, 
                15
            );
            double interestSavings = currentCalculation.getTotalInterest() - calc15Year.getTotalInterest();
            double paymentIncrease = calc15Year.getMonthlyPayment() - currentCalculation.getMonthlyPayment();
            insights += "• 15-year loan saves " + currencyFormat.format(interestSavings) + 
                       " but increases payment by " + currencyFormat.format(paymentIncrease);
        }

        // Update breakdown text with insights
        String currentBreakdown = paymentBreakdown.getText().toString();
        paymentBreakdown.setText(currentBreakdown + "\n\nInsights:\n" + insights);
    }

    private void showAmortizationSchedule() {
        if (currentCalculation == null) {
            showError("Please calculate mortgage first");
            return;
        }

        // For now, show a simple toast. In a full implementation, 
        // this would open a new activity or dialog with the amortization table
        Toast.makeText(getContext(), "Amortization schedule feature coming soon!", Toast.LENGTH_SHORT).show();
    }

    private void shareResults() {
        if (currentCalculation == null) {
            showError("Please calculate mortgage first");
            return;
        }

        try {
            String shareText = "Mortgage Calculation Results:\n\n" +
                "Home Price: " + currencyFormat.format(currentCalculation.getHomePrice()) + "\n" +
                "Down Payment: " + currencyFormat.format(currentCalculation.getDownPayment()) + 
                " (" + String.format("%.1f%%", currentCalculation.getDownPaymentPercentage()) + ")\n" +
                "Interest Rate: " + String.format("%.2f%%", currentCalculation.getInterestRate()) + "\n" +
                "Loan Term: " + selectedTerm + " years\n\n" +
                "Monthly Payment: " + currencyFormat.format(currentCalculation.getMonthlyPayment()) + "\n" +
                "Total Interest: " + currencyFormat.format(currentCalculation.getTotalInterest()) + "\n" +
                "Total Payment: " + currencyFormat.format(currentCalculation.getTotalAmount()) + "\n\n" +
                "Calculated with RoomFinder Mortgage Tools";

            Intent shareIntent = new Intent(Intent.ACTION_SEND);
            shareIntent.setType("text/plain");
            shareIntent.putExtra(Intent.EXTRA_TEXT, shareText);
            startActivity(Intent.createChooser(shareIntent, "Share Mortgage Results"));

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