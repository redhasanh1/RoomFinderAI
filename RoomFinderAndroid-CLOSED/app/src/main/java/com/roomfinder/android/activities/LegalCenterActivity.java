package com.roomfinder.android.activities;

import android.os.Bundle;

import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;
import com.google.android.material.appbar.MaterialToolbar;
import com.google.android.material.card.MaterialCardView;
import com.roomfinder.android.R;
import com.roomfinder.android.fragments.DocumentGeneratorFragment;
import com.roomfinder.android.fragments.TenantRightsFragment;
import com.roomfinder.android.fragments.LegalResourcesFragment;
import com.roomfinder.android.fragments.IssueAnalyzerFragment;

public class LegalCenterActivity extends AppCompatActivity {
    
    private MaterialToolbar toolbar;
    private MaterialCardView documentGeneratorCard;
    private MaterialCardView tenantRightsCard;
    private MaterialCardView legalResourcesCard;
    private MaterialCardView issueAnalyzerCard;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_legal_center);
        
        initializeViews();
        setupToolbar();
        setupClickListeners();
    }

    private void initializeViews() {
        toolbar = findViewById(R.id.toolbar);
        documentGeneratorCard = findViewById(R.id.documentGeneratorCard);
        tenantRightsCard = findViewById(R.id.tenantRightsCard);
        legalResourcesCard = findViewById(R.id.legalResourcesCard);
        issueAnalyzerCard = findViewById(R.id.issueAnalyzerCard);
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
        documentGeneratorCard.setOnClickListener(v -> {
            navigateToFragment(new DocumentGeneratorFragment(), "Document Generator");
        });
        
        tenantRightsCard.setOnClickListener(v -> {
            navigateToFragment(new TenantRightsFragment(), "Know Your Rights");
        });
        
        legalResourcesCard.setOnClickListener(v -> {
            navigateToFragment(new LegalResourcesFragment(), "Legal Resources");
        });
        
        issueAnalyzerCard.setOnClickListener(v -> {
            navigateToFragment(new IssueAnalyzerFragment(), "Issue Analyzer");
        });
    }

    private void navigateToFragment(Fragment fragment, String title) {
        getSupportFragmentManager()
            .beginTransaction()
            .replace(android.R.id.content, fragment)
            .addToBackStack(title)
            .commit();
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