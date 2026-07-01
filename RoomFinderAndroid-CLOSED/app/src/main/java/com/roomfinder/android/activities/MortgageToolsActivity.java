package com.roomfinder.android.activities;

import android.os.Bundle;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;
import com.google.android.material.appbar.MaterialToolbar;
import com.google.android.material.card.MaterialCardView;
import com.roomfinder.android.R;
import com.roomfinder.android.fragments.AffordabilityCalculatorFragment;
import com.roomfinder.android.fragments.MortgageCalculatorFragment;
import com.roomfinder.android.fragments.RefinanceAnalyzerFragment;
import com.roomfinder.android.models.MortgageRate;
import com.roomfinder.android.services.MortgageRateService;

public class MortgageToolsActivity extends AppCompatActivity {
    
    private MaterialToolbar toolbar;
    private MaterialCardView basicCalculatorCard;
    private MaterialCardView affordabilityCalculatorCard;
    private MaterialCardView refinanceAnalyzerCard;
    
    private TextView currentRateText;
    private TextView rate30Year;
    private TextView rate15Year;
    private TextView rateFHA;
    private TextView rateTrendText;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_mortgage_tools);
        
        initializeViews();
        setupToolbar();
        setupClickListeners();
        loadCurrentRates();
    }

    private void initializeViews() {
        toolbar = findViewById(R.id.toolbar);
        basicCalculatorCard = findViewById(R.id.basicCalculatorCard);
        affordabilityCalculatorCard = findViewById(R.id.affordabilityCalculatorCard);
        refinanceAnalyzerCard = findViewById(R.id.refinanceAnalyzerCard);
        
        currentRateText = findViewById(R.id.currentRateText);
        rate30Year = findViewById(R.id.rate30Year);
        rate15Year = findViewById(R.id.rate15Year);
        rateFHA = findViewById(R.id.rateFHA);
        rateTrendText = findViewById(R.id.rateTrendText);
    }

    private void setupToolbar() {
        setSupportActionBar(toolbar);
        if (getSupportActionBar() != null) {
            getSupportActionBar().setDisplayHomeAsUpEnabled(true);
            getSupportActionBar().setDisplayShowHomeEnabled(true);
        }
        
        toolbar.setNavigationOnClickListener(v -> onBackPressed());
    }

    private void setupClickListeners() {
        basicCalculatorCard.setOnClickListener(v -> {
            navigateToFragment(new MortgageCalculatorFragment(), "Mortgage Calculator");
        });
        
        affordabilityCalculatorCard.setOnClickListener(v -> {
            navigateToFragment(new AffordabilityCalculatorFragment(), "Affordability Calculator");
        });
        
        refinanceAnalyzerCard.setOnClickListener(v -> {
            navigateToFragment(new RefinanceAnalyzerFragment(), "Refinance Analyzer");
        });
    }

    private void navigateToFragment(Fragment fragment, String title) {
        getSupportFragmentManager()
            .beginTransaction()
            .replace(android.R.id.content, fragment)
            .addToBackStack(title)
            .commit();
    }

    private void loadCurrentRates() {
        try {
            // Load current market rates
            MortgageRate rate30 = MortgageRateService.getRateForLoanType(MortgageRate.LoanType.CONVENTIONAL_30_YEAR);
            MortgageRate rate15 = MortgageRateService.getRateForLoanType(MortgageRate.LoanType.CONVENTIONAL_15_YEAR);
            MortgageRate rateFha = MortgageRateService.getRateForLoanType(MortgageRate.LoanType.FHA_30_YEAR);
            
            // Update UI with current rates
            if (rate30 != null) {
                String rateText = String.format("%.2f%%", rate30.getRate());
                currentRateText.setText(rateText);
                rate30Year.setText(rateText);
            }
            
            if (rate15 != null) {
                rate15Year.setText(String.format("%.2f%%", rate15.getRate()));
            }
            
            if (rateFha != null) {
                rateFHA.setText(String.format("%.2f%%", rateFha.getRate()));
            }
            
            // Update trend text
            String trend = MortgageRateService.getRateTrend();
            rateTrendText.setText(trend);
            
        } catch (Exception e) {
            // Handle rate loading errors gracefully
            currentRateText.setText("7.25%");
            rate30Year.setText("7.25%");
            rate15Year.setText("6.75%");
            rateFHA.setText("7.15%");
            rateTrendText.setText("Rates updated daily");
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        // Refresh rates when returning to activity
        loadCurrentRates();
    }

    @Override
    public void onBackPressed() {
        if (getSupportFragmentManager().getBackStackEntryCount() > 0) {
            getSupportFragmentManager().popBackStack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    public boolean onSupportNavigateUp() {
        onBackPressed();
        return true;
    }
}