package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import com.roomfinder.android.R;

public class LegalResourcesFragment extends Fragment {

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = LayoutInflater.from(getContext()).inflate(R.layout.fragment_refinance_analyzer, container, false);
        
        if (getContext() != null) {
            Toast.makeText(getContext(), 
                "Legal Resources - Access free legal forms, guides, calculators, and educational materials!", 
                Toast.LENGTH_LONG).show();
        }
        
        return view;
    }
}