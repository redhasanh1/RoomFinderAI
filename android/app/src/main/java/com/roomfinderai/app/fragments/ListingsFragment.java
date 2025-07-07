package com.roomfinderai.app.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;
import com.roomfinderai.app.R;
import com.roomfinderai.app.adapters.ListingsAdapter;
import java.util.ArrayList;
import java.util.List;

public class ListingsFragment extends Fragment {

    private RecyclerView recyclerView;
    private SwipeRefreshLayout swipeRefreshLayout;
    private ListingsAdapter adapter;
    private List<Object> listings = new ArrayList<>();

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_listings, container, false);
        
        recyclerView = view.findViewById(R.id.recyclerView);
        swipeRefreshLayout = view.findViewById(R.id.swipeRefresh);
        
        setupRecyclerView();
        setupSwipeRefresh();
        loadListings();
        
        return view;
    }

    private void setupRecyclerView() {
        adapter = new ListingsAdapter(listings, getContext());
        recyclerView.setLayoutManager(new LinearLayoutManager(getContext()));
        recyclerView.setAdapter(adapter);
    }

    private void setupSwipeRefresh() {
        swipeRefreshLayout.setColorSchemeResources(
            R.color.purple_primary,
            R.color.purple_secondary,
            R.color.accent_blue
        );
        
        swipeRefreshLayout.setOnRefreshListener(() -> {
            refreshListings();
        });
    }

    private void loadListings() {
        // Load initial listings
        swipeRefreshLayout.setRefreshing(false);
    }

    private void refreshListings() {
        // Refresh listings
        swipeRefreshLayout.postDelayed(() -> {
            swipeRefreshLayout.setRefreshing(false);
        }, 2000);
    }

    public void searchListings(String query) {
        // Implement search functionality
    }
}