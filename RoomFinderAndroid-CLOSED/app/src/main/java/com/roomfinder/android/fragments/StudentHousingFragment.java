package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import android.widget.GridLayout;
import android.widget.ImageView;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.card.MaterialCardView;
import com.roomfinder.android.R;
import com.roomfinder.android.models.HousingOption;
import java.util.ArrayList;
import java.util.List;

public class StudentHousingFragment extends Fragment {

    private EditText budgetInput;
    private EditText universitySearch;
    private MaterialCardView budgetResultCard;
    private TextView budgetResultText;
    private GridLayout housingOptionsGrid;
    
    private MaterialButton budget500, budget800, budget1200;
    private MaterialButton startBudgetCalculator, createRoommateAgreement;
    private MaterialCardView profileMinimal, profileComfortable, profilePremium;
    
    private List<HousingOption> housingOptions;
    private int currentBudget = 0;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_student_housing, container, false);
        
        initializeViews(view);
        setupHousingOptions();
        setupClickListeners();
        populateHousingGrid();
        
        return view;
    }

    private void initializeViews(View view) {
        budgetInput = view.findViewById(R.id.budgetInput);
        universitySearch = view.findViewById(R.id.universitySearch);
        budgetResultCard = view.findViewById(R.id.budgetResultCard);
        budgetResultText = view.findViewById(R.id.budgetResultText);
        housingOptionsGrid = view.findViewById(R.id.housingOptionsGrid);
        
        budget500 = view.findViewById(R.id.budget500);
        budget800 = view.findViewById(R.id.budget800);
        budget1200 = view.findViewById(R.id.budget1200);
        
        startBudgetCalculator = view.findViewById(R.id.startBudgetCalculator);
        createRoommateAgreement = view.findViewById(R.id.createRoommateAgreement);
        
        profileMinimal = view.findViewById(R.id.profileMinimal);
        profileComfortable = view.findViewById(R.id.profileComfortable);
        profilePremium = view.findViewById(R.id.profilePremium);
    }

    private void setupHousingOptions() {
        housingOptions = new ArrayList<>();
        
        // Add housing options matching the web design
        housingOptions.add(new HousingOption(
            "Dorm Room",
            "Shared or private rooms\nin university dormitories",
            "$400-800/mo",
            "On campus",
            R.drawable.ic_home,
            "dorm"
        ));
        
        housingOptions.add(new HousingOption(
            "Apartment",
            "Private apartments near\nor off campus",
            "$600-1200/mo", 
            "0.5-2 miles",
            R.drawable.apartment_3d_tower,
            "apartment"
        ));
        
        housingOptions.add(new HousingOption(
            "Shared House",
            "Share a house with\nother students",
            "$500-900/mo",
            "1-3 miles",
            R.drawable.house_3d_modern,
            "shared_house"
        ));
        
        housingOptions.add(new HousingOption(
            "Studio",
            "Compact independent\nliving space",
            "$700-1000/mo",
            "0.5-1.5 miles", 
            R.drawable.condo_3d_modern,
            "studio"
        ));
    }

    private void setupClickListeners() {
        // Budget preset buttons
        budget500.setOnClickListener(v -> setBudget(500));
        budget800.setOnClickListener(v -> setBudget(800));
        budget1200.setOnClickListener(v -> setBudget(1200));
        
        // Budget input text watcher
        budgetInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                if (!s.toString().isEmpty()) {
                    try {
                        int budget = Integer.parseInt(s.toString());
                        updateBudgetResult(budget);
                    } catch (NumberFormatException e) {
                        hideBudgetResult();
                    }
                } else {
                    hideBudgetResult();
                }
            }

            @Override
            public void afterTextChanged(Editable s) {}
        });
        
        // Profile selection cards
        profileMinimal.setOnClickListener(v -> selectProfile("minimal"));
        profileComfortable.setOnClickListener(v -> selectProfile("comfortable"));
        profilePremium.setOnClickListener(v -> selectProfile("premium"));
        
        // CTA buttons
        startBudgetCalculator.setOnClickListener(v -> {
            // Scroll to budget section or open budget calculator
            // For now, just set focus on budget input
            budgetInput.requestFocus();
        });
        
        createRoommateAgreement.setOnClickListener(v -> {
            // Navigate to roommate finder or show coming soon
            // This would typically open another fragment or activity
        });
    }

    private void setBudget(int amount) {
        budgetInput.setText(String.valueOf(amount));
        updateBudgetResult(amount);
        
        // Update button states
        resetBudgetButtonStyles();
        MaterialButton selectedButton = null;
        
        switch (amount) {
            case 500:
                selectedButton = budget500;
                break;
            case 800:
                selectedButton = budget800;
                break;
            case 1200:
                selectedButton = budget1200;
                break;
        }
        
        if (selectedButton != null) {
            selectedButton.setBackgroundTintList(
                getContext().getColorStateList(R.color.purple_light)
            );
            selectedButton.setTextColor(getContext().getColor(R.color.purple_primary));
        }
    }

    private void resetBudgetButtonStyles() {
        int defaultColor = getContext().getColor(R.color.gray_100);
        int defaultTextColor = getContext().getColor(R.color.text_primary);
        
        budget500.setBackgroundTintList(getContext().getColorStateList(R.color.gray_100));
        budget500.setTextColor(defaultTextColor);
        
        budget800.setBackgroundTintList(getContext().getColorStateList(R.color.gray_100));
        budget800.setTextColor(defaultTextColor);
        
        budget1200.setBackgroundTintList(getContext().getColorStateList(R.color.gray_100));
        budget1200.setTextColor(defaultTextColor);
    }

    private void updateBudgetResult(int budget) {
        currentBudget = budget;
        budgetResultText.setText("Great! We'll show you options under $" + budget + "/month");
        budgetResultCard.setVisibility(View.VISIBLE);
        
        // Filter housing options based on budget (optional enhancement)
        filterHousingOptionsByBudget(budget);
    }

    private void hideBudgetResult() {
        budgetResultCard.setVisibility(View.GONE);
    }

    private void filterHousingOptionsByBudget(int budget) {
        // This method could filter and update the housing grid based on budget
        // For now, we'll just keep it simple and show all options
    }

    private void selectProfile(String profileType) {
        // Reset all profile card styles
        resetProfileStyles();
        
        // Highlight selected profile
        MaterialCardView selectedCard = null;
        switch (profileType) {
            case "minimal":
                selectedCard = profileMinimal;
                setBudget(500); // Set appropriate budget for minimal profile
                break;
            case "comfortable":
                selectedCard = profileComfortable;
                setBudget(800); // Set appropriate budget for comfortable profile
                break;
            case "premium":
                selectedCard = profilePremium;
                setBudget(1200); // Set appropriate budget for premium profile
                break;
        }
        
        if (selectedCard != null) {
            selectedCard.setCardBackgroundColor(getContext().getColor(R.color.purple_light));
        }
    }

    private void resetProfileStyles() {
        int defaultColor = getContext().getColor(R.color.white);
        profileMinimal.setCardBackgroundColor(defaultColor);
        profileComfortable.setCardBackgroundColor(defaultColor);
        profilePremium.setCardBackgroundColor(defaultColor);
    }

    private void populateHousingGrid() {
        housingOptionsGrid.removeAllViews();
        
        for (HousingOption option : housingOptions) {
            View cardView = createHousingOptionCard(option);
            
            // Set grid layout parameters
            GridLayout.LayoutParams params = new GridLayout.LayoutParams();
            params.width = 0;
            params.height = GridLayout.LayoutParams.WRAP_CONTENT;
            params.columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f);
            params.setMargins(8, 8, 8, 8);
            
            cardView.setLayoutParams(params);
            housingOptionsGrid.addView(cardView);
        }
    }

    private View createHousingOptionCard(HousingOption option) {
        View cardView = LayoutInflater.from(getContext())
            .inflate(R.layout.item_housing_option, housingOptionsGrid, false);
        
        ImageView icon = cardView.findViewById(R.id.housingIcon);
        TextView title = cardView.findViewById(R.id.housingTitle);
        TextView description = cardView.findViewById(R.id.housingDescription);
        TextView priceRange = cardView.findViewById(R.id.priceRange);
        TextView distance = cardView.findViewById(R.id.distanceFromCampus);
        
        icon.setImageResource(option.getIconResource());
        title.setText(option.getTitle());
        description.setText(option.getDescription());
        priceRange.setText(option.getPriceRange());
        distance.setText(option.getDistanceFromCampus());
        
        // Add click listener for housing option selection
        cardView.setOnClickListener(v -> {
            // Handle housing option selection
            // This could open a detailed view or filter results
        });
        
        return cardView;
    }
}