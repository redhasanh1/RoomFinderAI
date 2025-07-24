package com.roomfinderai.app.fragments;

import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;
import com.google.android.material.progressindicator.LinearProgressIndicator;
import com.roomfinderai.app.R;
import com.roomfinderai.app.adapters.ListingsAdapter;
import com.roomfinderai.app.api.ApiClient;
import com.roomfinderai.app.api.ApiService;
import com.roomfinderai.app.models.ApiResponse;
import com.roomfinderai.app.models.Listing;
import com.roomfinderai.app.models.SearchRequest;
import java.util.ArrayList;
import java.util.List;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

public class ListingsFragment extends Fragment {
    private static final String TAG = "ListingsFragment";
    
    private RecyclerView recyclerView;
    private SwipeRefreshLayout swipeRefreshLayout;
    private LinearProgressIndicator progressIndicator;
    private TextView emptyStateText;
    private ListingsAdapter adapter;
    private List<Listing> listings = new ArrayList<>();
    private ApiService apiService;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_listings, container, false);
        
        // Initialize views
        recyclerView = view.findViewById(R.id.recyclerView);
        swipeRefreshLayout = view.findViewById(R.id.swipeRefresh);
        progressIndicator = view.findViewById(R.id.progressIndicator);
        emptyStateText = view.findViewById(R.id.emptyStateText);
        
        // Initialize API service
        apiService = ApiClient.getInstance().getApiService();
        
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
        // Show loading indicator
        if (progressIndicator != null) {
            progressIndicator.setVisibility(View.VISIBLE);
        }
        if (emptyStateText != null) {
            emptyStateText.setVisibility(View.GONE);
        }
        
        // Make API call to get listings
        Call<ApiResponse<List<Listing>>> call = apiService.getListings();
        call.enqueue(new Callback<ApiResponse<List<Listing>>>() {
            @Override
            public void onResponse(Call<ApiResponse<List<Listing>>> call, Response<ApiResponse<List<Listing>>> response) {
                if (progressIndicator != null) {
                    progressIndicator.setVisibility(View.GONE);
                }
                swipeRefreshLayout.setRefreshing(false);
                
                if (response.isSuccessful() && response.body() != null) {
                    ApiResponse<List<Listing>> apiResponse = response.body();
                    if (apiResponse.isSuccess() && apiResponse.getData() != null) {
                        listings.clear();
                        listings.addAll(apiResponse.getData());
                        adapter.updateListings(listings);
                        
                        // Show empty state if no listings
                        if (listings.isEmpty() && emptyStateText != null) {
                            emptyStateText.setVisibility(View.VISIBLE);
                            emptyStateText.setText("No listings available");
                        }
                        
                        Log.d(TAG, "Loaded " + listings.size() + " listings");
                    } else {
                        showError("Failed to load listings: " + apiResponse.getMessage());
                    }
                } else {
                    showError("Failed to load listings: " + response.message());
                }
            }
            
            @Override
            public void onFailure(Call<ApiResponse<List<Listing>>> call, Throwable t) {
                if (progressIndicator != null) {
                    progressIndicator.setVisibility(View.GONE);
                }
                swipeRefreshLayout.setRefreshing(false);
                showError("Network error: " + t.getMessage());
                Log.e(TAG, "Error loading listings", t);
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
        
        // Show loading
        if (progressIndicator != null) {
            progressIndicator.setVisibility(View.VISIBLE);
        }
        
        SearchRequest searchRequest = new SearchRequest();
        searchRequest.setQuery(query);
        
        Call<ApiResponse<List<Listing>>> call = apiService.searchListings(searchRequest);
        call.enqueue(new Callback<ApiResponse<List<Listing>>>() {
            @Override
            public void onResponse(Call<ApiResponse<List<Listing>>> call, Response<ApiResponse<List<Listing>>> response) {
                if (progressIndicator != null) {
                    progressIndicator.setVisibility(View.GONE);
                }
                
                if (response.isSuccessful() && response.body() != null) {
                    ApiResponse<List<Listing>> apiResponse = response.body();
                    if (apiResponse.isSuccess() && apiResponse.getData() != null) {
                        listings.clear();
                        listings.addAll(apiResponse.getData());
                        adapter.updateListings(listings);
                        
                        if (listings.isEmpty() && emptyStateText != null) {
                            emptyStateText.setVisibility(View.VISIBLE);
                            emptyStateText.setText("No listings found for '" + query + "'");
                        } else if (emptyStateText != null) {
                            emptyStateText.setVisibility(View.GONE);
                        }
                    } else {
                        showError("Search failed: " + apiResponse.getMessage());
                    }
                } else {
                    showError("Search failed: " + response.message());
                }
            }
            
            @Override
            public void onFailure(Call<ApiResponse<List<Listing>>> call, Throwable t) {
                if (progressIndicator != null) {
                    progressIndicator.setVisibility(View.GONE);
                }
                showError("Search error: " + t.getMessage());
            }
        });
    }
    
    private void showError(String message) {
        if (getContext() != null) {
            Toast.makeText(getContext(), message, Toast.LENGTH_LONG).show();
        }
        
        if (listings.isEmpty() && emptyStateText != null) {
            emptyStateText.setVisibility(View.VISIBLE);
            emptyStateText.setText("Error loading listings. Pull to refresh.");
        }
    }
}