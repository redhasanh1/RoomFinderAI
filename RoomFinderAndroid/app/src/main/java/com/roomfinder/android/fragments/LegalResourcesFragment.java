package com.roomfinder.android.fragments;

import android.os.AsyncTask;
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
import com.google.android.material.card.MaterialCardView;
import com.google.android.material.textfield.TextInputEditText;
import com.google.android.material.textfield.TextInputLayout;
import com.roomfinder.android.R;
import com.roomfinder.android.utils.LegalCalculators;
import com.roomfinder.android.utils.LegalCalculators.SecurityDepositResult;
import com.roomfinder.android.utils.LegalCalculators.ProratedRentResult;
import com.roomfinder.android.utils.LegalCalculators.LateFeeResult;
import java.text.NumberFormat;
import java.util.Locale;

public class LegalResourcesFragment extends Fragment {

    // UI Components
    private TextInputEditText searchInput;
    
    // Calculator cards
    private MaterialCardView securityDepositCalculatorCard;
    private MaterialCardView proratedRentCalculatorCard;
    private MaterialCardView lateFeeCalculatorCard;
    
    // Calculator section
    private LinearLayout calculatorSection;
    private TextView calculatorTitle;
    private TextInputEditText calculatorInput1;
    private TextInputLayout calculatorInput2Layout;
    private TextInputEditText calculatorInput2;
    private MaterialButton calculateButton;
    
    // Results section
    private LinearLayout calculatorResultsSection;
    private TextView calculatorResult;
    private TextView calculatorExplanation;
    private MaterialButton backToResourcesButton;
    
    // Forms section
    private LinearLayout formsSection;
    
    // State
    private enum CalculatorType { SECURITY_DEPOSIT, PRORATED_RENT, LATE_FEE }
    private CalculatorType currentCalculatorType;
    private NumberFormat currencyFormat;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_legal_resources, container, false);
        
        initializeViews(view);
        setupButtonListeners();
        setupSearchFunctionality();
        
        currencyFormat = NumberFormat.getCurrencyInstance(Locale.US);
        
        return view;
    }

    private void initializeViews(View view) {
        searchInput = view.findViewById(R.id.searchInput);
        
        // Calculator cards
        securityDepositCalculatorCard = view.findViewById(R.id.securityDepositCalculatorCard);
        proratedRentCalculatorCard = view.findViewById(R.id.proratedRentCalculatorCard);
        lateFeeCalculatorCard = view.findViewById(R.id.lateFeeCalculatorCard);
        
        // Calculator section
        calculatorSection = view.findViewById(R.id.calculatorSection);
        calculatorTitle = view.findViewById(R.id.calculatorTitle);
        calculatorInput1 = view.findViewById(R.id.calculatorInput1);
        calculatorInput2Layout = view.findViewById(R.id.calculatorInput2Layout);
        calculatorInput2 = view.findViewById(R.id.calculatorInput2);
        calculateButton = view.findViewById(R.id.calculateButton);
        
        // Results section
        calculatorResultsSection = view.findViewById(R.id.calculatorResultsSection);
        calculatorResult = view.findViewById(R.id.calculatorResult);
        calculatorExplanation = view.findViewById(R.id.calculatorExplanation);
        backToResourcesButton = view.findViewById(R.id.backToResourcesButton);
        
        // Forms section
        formsSection = view.findViewById(R.id.formsSection);
    }

    private void setupButtonListeners() {
        // Calculator cards
        securityDepositCalculatorCard.setOnClickListener(v -> 
            showCalculator(CalculatorType.SECURITY_DEPOSIT));
        
        proratedRentCalculatorCard.setOnClickListener(v -> 
            showCalculator(CalculatorType.PRORATED_RENT));
        
        lateFeeCalculatorCard.setOnClickListener(v -> 
            showCalculator(CalculatorType.LATE_FEE));
        
        // Calculator actions
        calculateButton.setOnClickListener(v -> performCalculation());
        backToResourcesButton.setOnClickListener(v -> showResourcesOverview());
    }

    private void setupSearchFunctionality() {
        searchInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {}

            @Override
            public void afterTextChanged(Editable s) {
                filterResources(s.toString());
            }
        });
    }

    private void showCalculator(CalculatorType type) {
        currentCalculatorType = type;
        
        // Configure calculator UI based on type
        switch (type) {
            case SECURITY_DEPOSIT:
                calculatorTitle.setText("Security Deposit Calculator");
                calculatorInput1.setHint("Monthly Rent");
                calculatorInput2Layout.setHint("State");
                calculatorInput2.setText("California");
                break;
                
            case PRORATED_RENT:
                calculatorTitle.setText("Prorated Rent Calculator");
                calculatorInput1.setHint("Monthly Rent");
                calculatorInput2Layout.setHint("Days Occupied");
                calculatorInput2.setText("15");
                break;
                
            case LATE_FEE:
                calculatorTitle.setText("Late Fee Calculator");
                calculatorInput1.setHint("Monthly Rent");
                calculatorInput2Layout.setHint("State");
                calculatorInput2.setText("California");
                break;
        }
        
        // Clear previous results
        calculatorResultsSection.setVisibility(View.GONE);
        calculatorInput1.setText("");
        
        // Show calculator, hide overview
        formsSection.setVisibility(View.GONE);
        calculatorSection.setVisibility(View.VISIBLE);
    }

    private void performCalculation() {
        String input1Text = calculatorInput1.getText().toString().trim();
        String input2Text = calculatorInput2.getText().toString().trim();
        
        if (input1Text.isEmpty()) {
            showError("Please enter the monthly rent");
            return;
        }
        
        try {
            double monthlyRent = Double.parseDouble(input1Text);
            if (monthlyRent <= 0) {
                showError("Monthly rent must be greater than 0");
                return;
            }
            
            // Perform calculation in background to avoid ANR
            new CalculationTask().execute(monthlyRent, input2Text);
            
        } catch (NumberFormatException e) {
            showError("Please enter a valid number for rent");
        }
    }

    private class CalculationTask extends AsyncTask<Object, Void, Object> {
        private String errorMessage;
        
        @Override
        protected Object doInBackground(Object... params) {
            try {
                double monthlyRent = (Double) params[0];
                String secondParam = (String) params[1];
                
                switch (currentCalculatorType) {
                    case SECURITY_DEPOSIT:
                        return LegalCalculators.calculateSecurityDeposit(monthlyRent, secondParam, false);
                        
                    case PRORATED_RENT:
                        int daysOccupied = Integer.parseInt(secondParam);
                        int daysInMonth = LegalCalculators.getDaysInCurrentMonth();
                        return LegalCalculators.calculateProratedRent(monthlyRent, daysInMonth, daysOccupied);
                        
                    case LATE_FEE:
                        return LegalCalculators.calculateLateFee(monthlyRent, secondParam, 5); // Assume 5 days late
                        
                    default:
                        return null;
                }
                
            } catch (Exception e) {
                errorMessage = "Calculation error: " + e.getMessage();
                return null;
            }
        }
        
        @Override
        protected void onPostExecute(Object result) {
            if (result == null) {
                showError(errorMessage != null ? errorMessage : "Calculation failed");
                return;
            }
            
            displayCalculationResult(result);
        }
    }

    private void displayCalculationResult(Object result) {
        String resultText;
        String explanation;
        
        switch (currentCalculatorType) {
            case SECURITY_DEPOSIT:
                SecurityDepositResult depositResult = (SecurityDepositResult) result;
                resultText = currencyFormat.format(depositResult.getMaxDeposit());
                explanation = depositResult.getExplanation();
                break;
                
            case PRORATED_RENT:
                ProratedRentResult rentResult = (ProratedRentResult) result;
                resultText = currencyFormat.format(rentResult.getProratedAmount());
                explanation = rentResult.getExplanation();
                break;
                
            case LATE_FEE:
                LateFeeResult feeResult = (LateFeeResult) result;
                resultText = currencyFormat.format(feeResult.getMaxLateFee());
                explanation = feeResult.getExplanation();
                break;
                
            default:
                resultText = "Error";
                explanation = "Unknown calculation type";
                break;
        }
        
        calculatorResult.setText(resultText);
        calculatorExplanation.setText(explanation);
        calculatorResultsSection.setVisibility(View.VISIBLE);
    }

    private void showResourcesOverview() {
        // Hide calculator, show overview
        calculatorSection.setVisibility(View.GONE);
        formsSection.setVisibility(View.VISIBLE);
    }

    private void filterResources(String query) {
        // Simple search implementation - in a real app, this would filter actual resources
        if (query.length() > 2) {
            // Could filter cards or show search results
            if (getContext() != null) {
                Toast.makeText(getContext(), 
                    "Searching for: " + query, 
                    Toast.LENGTH_SHORT).show();
            }
        }
    }

    private void showError(String message) {
        if (getContext() != null) {
            Toast.makeText(getContext(), message, Toast.LENGTH_SHORT).show();
        }
    }
    
    @Override
    public void onDestroy() {
        super.onDestroy();
        // Clean up any running tasks to prevent memory leaks
    }
}