package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import com.google.android.material.button.MaterialButton;
import com.roomfinder.android.R;

public class RefinanceAnalyzerFragment extends Fragment {

    private MaterialButton notifyMeButton;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_refinance_analyzer, container, false);
        
        initializeViews(view);
        setupButtonListeners();
        
        return view;
    }

    private void initializeViews(View view) {
        notifyMeButton = view.findViewById(R.id.notifyMeButton);
    }

    private void setupButtonListeners() {
        notifyMeButton.setOnClickListener(v -> {
            if (getContext() != null) {
                Toast.makeText(getContext(), 
                    "We'll notify you when the Refinance Analyzer is available!", 
                    Toast.LENGTH_SHORT).show();
            }
        });
    }
}