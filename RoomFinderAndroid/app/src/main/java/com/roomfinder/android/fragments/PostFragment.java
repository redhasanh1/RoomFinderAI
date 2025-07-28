package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import com.roomfinder.android.databinding.FragmentPostBinding;

public class PostFragment extends Fragment {
    
    private FragmentPostBinding binding;
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentPostBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        binding.postButton.setOnClickListener(v -> {
            // TODO: Implement posting logic
        });
        
        binding.addPhotosButton.setOnClickListener(v -> {
            // TODO: Implement photo picker
        });
    }
}