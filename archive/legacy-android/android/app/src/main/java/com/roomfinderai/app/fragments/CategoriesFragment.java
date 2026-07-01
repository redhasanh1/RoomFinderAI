package com.roomfinderai.app.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.roomfinderai.app.R;

public class CategoriesFragment extends Fragment {

    private RecyclerView categoriesGrid;
    private RecyclerView allCategoriesList;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_categories, container, false);
        
        categoriesGrid = view.findViewById(R.id.categoriesGrid);
        allCategoriesList = view.findViewById(R.id.allCategoriesList);
        
        setupCategoriesGrid();
        setupAllCategoriesList();
        
        return view;
    }

    private void setupCategoriesGrid() {
        categoriesGrid.setLayoutManager(new GridLayoutManager(getContext(), 3));
        // Set adapter with popular categories
    }

    private void setupAllCategoriesList() {
        allCategoriesList.setLayoutManager(new LinearLayoutManager(getContext()));
        // Set adapter with all categories
    }
}