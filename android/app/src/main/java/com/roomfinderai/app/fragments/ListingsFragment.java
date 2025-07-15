package com.roomfinderai.app.fragments;

import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;
import com.roomfinderai.app.R;
import com.roomfinderai.app.adapters.ListingsAdapter;
import com.roomfinderai.app.models.Listing;
import com.roomfinderai.app.services.Repository;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class ListingsFragment extends Fragment {

    private static final String TAG = "ListingsFragment";
    private RecyclerView recyclerView;
    private SwipeRefreshLayout swipeRefreshLayout;
    private ListingsAdapter adapter;
    private List<Listing> listings = new ArrayList<>();
    private Repository repository;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_listings, container, false);
        
        recyclerView = view.findViewById(R.id.recyclerView);
        swipeRefreshLayout = view.findViewById(R.id.swipeRefresh);
        
        repository = new Repository();
        
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
        swipeRefreshLayout.setRefreshing(true);
        
        repository.getListings(new Repository.ApiCallback<List<Listing>>() {
            @Override
            public void onSuccess(List<Listing> result) {
                if (getActivity() != null) {
                    getActivity().runOnUiThread(() -> {
                        listings.clear();
                        if (result != null) {
                            listings.addAll(result);
                        }
                        adapter.notifyDataSetChanged();
                        swipeRefreshLayout.setRefreshing(false);
                        
                        Log.d(TAG, "Loaded " + listings.size() + " listings");
                        
                        if (listings.isEmpty()) {
                            Toast.makeText(getContext(), "No listings found", Toast.LENGTH_SHORT).show();
                        }
                    });
                }
            }

            @Override
            public void onError(String error) {
                if (getActivity() != null) {
                    getActivity().runOnUiThread(() -> {
                        swipeRefreshLayout.setRefreshing(false);
                        Log.e(TAG, "Error loading listings: " + error);
                        Toast.makeText(getContext(), "Error loading listings: " + error, Toast.LENGTH_LONG).show();
                    });
                }
            }
        });
    }

    private void refreshListings() {
        loadListings();
    }

    public void searchListings(String query) {
        if (query == null || query.trim().isEmpty()) {
            loadListings();
            return;
        }
        
        swipeRefreshLayout.setRefreshing(true);
        
        Map<String, String> filters = new HashMap<>();
        filters.put("search", query.trim());
        
        repository.getListings(filters, new Repository.ApiCallback<List<Listing>>() {
            @Override
            public void onSuccess(List<Listing> result) {
                if (getActivity() != null) {
                    getActivity().runOnUiThread(() -> {
                        listings.clear();
                        if (result != null) {
                            listings.addAll(result);
                        }
                        adapter.notifyDataSetChanged();
                        swipeRefreshLayout.setRefreshing(false);
                        
                        Log.d(TAG, "Search found " + listings.size() + " listings");
                        
                        if (listings.isEmpty()) {
                            Toast.makeText(getContext(), "No listings match your search", Toast.LENGTH_SHORT).show();
                        }
                    });
                }
            }

            @Override
            public void onError(String error) {
                if (getActivity() != null) {
                    getActivity().runOnUiThread(() -> {
                        swipeRefreshLayout.setRefreshing(false);
                        Log.e(TAG, "Error searching listings: " + error);
                        Toast.makeText(getContext(), "Search error: " + error, Toast.LENGTH_LONG).show();
                    });
                }
            }
        });
    }
}