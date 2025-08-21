package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import com.google.android.material.card.MaterialCardView;
import com.roomfinder.android.MainActivity;
import com.roomfinder.android.R;

public class ToolsFragment extends Fragment {

    private MaterialCardView studentHousingCard;
    private MaterialCardView legalCenterCard;
    private MaterialCardView mortgageToolsCard;
    private MaterialCardView quickPostCard;
    private MaterialCardView quickSearchCard;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_tools, container, false);
        
        initializeViews(view);
        setupClickListeners();
        
        return view;
    }

    private void initializeViews(View view) {
        studentHousingCard = view.findViewById(R.id.studentHousingCard);
        legalCenterCard = view.findViewById(R.id.legalCenterCard);
        mortgageToolsCard = view.findViewById(R.id.mortgageToolsCard);
        quickPostCard = view.findViewById(R.id.quickPostCard);
        quickSearchCard = view.findViewById(R.id.quickSearchCard);
    }

    private void setupClickListeners() {
        // Student Housing - Navigate to Student Housing Fragment
        studentHousingCard.setOnClickListener(v -> navigateToStudentHousing());
        
        // Legal Center - Show coming soon message
        legalCenterCard.setOnClickListener(v -> showComingSoon("Legal Center"));
        
        // Mortgage Tools - Show coming soon message
        mortgageToolsCard.setOnClickListener(v -> showComingSoon("Mortgage Tools"));
        
        // Quick Post - Navigate to Post Fragment
        quickPostCard.setOnClickListener(v -> navigateToPost());
        
        // Quick Search - Navigate to Search Fragment
        quickSearchCard.setOnClickListener(v -> navigateToSearch());
    }

    private void navigateToStudentHousing() {
        if (getActivity() instanceof MainActivity) {
            MainActivity mainActivity = (MainActivity) getActivity();
            // Load Student Housing Fragment
            getParentFragmentManager()
                .beginTransaction()
                .replace(R.id.fragmentContainer, new StudentHousingFragment())
                .addToBackStack("StudentHousing")
                .commit();
        }
    }

    private void navigateToPost() {
        if (getActivity() instanceof MainActivity) {
            MainActivity mainActivity = (MainActivity) getActivity();
            // Navigate to Post tab in bottom navigation
            mainActivity.findViewById(R.id.bottomNavigation);
            // You could also load the fragment directly:
            getParentFragmentManager()
                .beginTransaction()
                .replace(R.id.fragmentContainer, new PostFragment())
                .addToBackStack("Post")
                .commit();
        }
    }

    private void navigateToSearch() {
        if (getActivity() instanceof MainActivity) {
            MainActivity mainActivity = (MainActivity) getActivity();
            // Navigate to Search fragment
            getParentFragmentManager()
                .beginTransaction()
                .replace(R.id.fragmentContainer, new SearchFragment())
                .addToBackStack("Search")
                .commit();
        }
    }

    private void showComingSoon(String featureName) {
        // You can show a toast, snackbar, or dialog
        if (getContext() != null) {
            android.widget.Toast.makeText(getContext(), 
                featureName + " coming soon! Stay tuned for updates.", 
                android.widget.Toast.LENGTH_SHORT).show();
        }
    }
}