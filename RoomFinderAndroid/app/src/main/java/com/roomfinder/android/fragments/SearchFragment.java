package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.GridLayoutManager;
import com.google.android.material.chip.Chip;
import com.roomfinder.android.adapters.ListingsAdapter;
import com.roomfinder.android.databinding.FragmentSearchBinding;
import com.roomfinder.android.models.ApiResponse;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.network.ApiClient;
import com.roomfinder.android.network.ApiService;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;
import java.util.ArrayList;
import java.util.List;

public class SearchFragment extends Fragment implements ListingsAdapter.OnListingClickListener {
    
    private FragmentSearchBinding binding;
    private ListingsAdapter adapter;
    private List<Listing> listings = new ArrayList<>();
    private ApiService apiService;
    
    // Filter values
    private Double minPrice = null;
    private Double maxPrice = null;
    private Integer selectedBedrooms = null;
    private String selectedLocation = null;
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentSearchBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        apiService = ApiClient.getInstance().getApiService();
        setupViews();
        setupFilters();
    }
    
    private void setupViews() {
        // Setup RecyclerView
        adapter = new ListingsAdapter(listings, this);
        binding.recyclerView.setLayoutManager(new GridLayoutManager(requireContext(), 2));
        binding.recyclerView.setAdapter(adapter);
        
        // Setup search
        binding.searchButton.setOnClickListener(v -> performSearch());
        binding.searchInput.setOnEditorActionListener((v, actionId, event) -> {
            performSearch();
            return true;
        });
        
        // Clear filters button
        binding.clearFiltersButton.setOnClickListener(v -> clearFilters());
    }
    
    private void setupFilters() {
        // Price range chips
        binding.priceChipGroup.setOnCheckedStateChangeListener((group, checkedIds) -> {
            if (checkedIds.isEmpty()) {
                minPrice = null;
                maxPrice = null;
            } else {
                int checkedId = checkedIds.get(0);
                if (checkedId == binding.priceUnder1000.getId()) {
                    minPrice = 0.0;
                    maxPrice = 1000.0;
                } else if (checkedId == binding.price1000to1500.getId()) {
                    minPrice = 1000.0;
                    maxPrice = 1500.0;
                } else if (checkedId == binding.price1500to2000.getId()) {
                    minPrice = 1500.0;
                    maxPrice = 2000.0;
                } else if (checkedId == binding.priceOver2000.getId()) {
                    minPrice = 2000.0;
                    maxPrice = null;
                }
            }
        });
        
        // Bedroom chips
        binding.bedroomsChipGroup.setOnCheckedStateChangeListener((group, checkedIds) -> {
            if (checkedIds.isEmpty()) {
                selectedBedrooms = null;
            } else {
                int checkedId = checkedIds.get(0);
                if (checkedId == binding.bedroom1.getId()) {
                    selectedBedrooms = 1;
                } else if (checkedId == binding.bedroom2.getId()) {
                    selectedBedrooms = 2;
                } else if (checkedId == binding.bedroom3.getId()) {
                    selectedBedrooms = 3;
                } else if (checkedId == binding.bedroom4Plus.getId()) {
                    selectedBedrooms = 4;
                }
            }
        });
    }
    
    private void performSearch() {
        String query = binding.searchInput.getText().toString();
        
        binding.progressBar.setVisibility(View.VISIBLE);
        binding.emptyLayout.setVisibility(View.GONE);
        
        apiService.searchListings(query, minPrice, maxPrice, selectedBedrooms, selectedLocation)
            .enqueue(new Callback<ApiResponse<List<Listing>>>() {
                @Override
                public void onResponse(Call<ApiResponse<List<Listing>>> call, Response<ApiResponse<List<Listing>>> response) {
                    binding.progressBar.setVisibility(View.GONE);
                    
                    if (response.isSuccessful() && response.body() != null && response.body().isSuccess()) {
                        listings.clear();
                        List<Listing> results = response.body().getData();
                        if (results != null) {
                            listings.addAll(results);
                        }
                        adapter.notifyDataSetChanged();
                        
                        if (listings.isEmpty()) {
                            binding.emptyLayout.setVisibility(View.VISIBLE);
                        }
                    }
                }
                
                @Override
                public void onFailure(Call<ApiResponse<List<Listing>>> call, Throwable t) {
                    binding.progressBar.setVisibility(View.GONE);
                    // Handle error
                }
            });
    }
    
    private void clearFilters() {
        binding.priceChipGroup.clearCheck();
        binding.bedroomsChipGroup.clearCheck();
        minPrice = null;
        maxPrice = null;
        selectedBedrooms = null;
        selectedLocation = null;
        listings.clear();
        adapter.notifyDataSetChanged();
    }
    
    @Override
    public void onListingClick(Listing listing) {
        // TODO: Navigate to detail
    }
    
    @Override
    public void onFavoriteClick(Listing listing, int position) {
        listing.setFavorite(!listing.isFavorite());
        adapter.notifyItemChanged(position);
    }
}