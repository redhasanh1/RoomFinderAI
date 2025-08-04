package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;
import com.roomfinder.android.adapters.ListingsAdapter;
import com.roomfinder.android.databinding.FragmentHomeBinding;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.network.SupabaseService;
import java.util.ArrayList;
import java.util.List;

public class HomeFragment extends Fragment implements ListingsAdapter.OnListingClickListener {
    
    private static final String TAG = "HomeFragment";
    private FragmentHomeBinding binding;
    private ListingsAdapter adapter;
    private List<Listing> listings = new ArrayList<>();
    private List<Listing> allListings = new ArrayList<>();
    private SupabaseService supabaseService;
    private String currentFilter = "All";
    private String currentSearchQuery = "";
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentHomeBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        supabaseService = SupabaseService.getInstance();
        setupRecyclerView();
        setupSwipeRefresh();
        setupSearchAndFilters();
        loadListings();
    }
    
    private void setupRecyclerView() {
        adapter = new ListingsAdapter(listings, this);
        binding.recyclerView.setLayoutManager(new GridLayoutManager(requireContext(), 2));
        binding.recyclerView.setAdapter(adapter);
    }
    
    private void setupSwipeRefresh() {
        binding.swipeRefresh.setOnRefreshListener(this::loadListings);
    }
    
    private void setupSearchAndFilters() {
        // Search input listener
        binding.searchInput.setOnEditorActionListener((v, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_SEARCH) {
                performSearch(binding.searchInput.getText().toString().trim());
                return true;
            }
            return false;
        });
        
        // Text change listener for real-time search
        binding.searchInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            
            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {}
            
            @Override
            public void afterTextChanged(Editable s) {
                String query = s.toString().trim();
                if (!query.equals(currentSearchQuery)) {
                    currentSearchQuery = query;
                    // Delay search to avoid too many calls
                    binding.searchInput.removeCallbacks(searchRunnable);
                    binding.searchInput.postDelayed(searchRunnable, 300);
                }
            }
        });
        
        // Filter chips click listeners
        setupFilterChips();
    }
    
    private final Runnable searchRunnable = () -> performSearch(currentSearchQuery);
    
    private void setupFilterChips() {
        View.OnClickListener chipClickListener = v -> {
            // Reset all chips
            resetChipSelection();
            
            // Set selected chip
            v.setSelected(true);
            updateChipAppearance((TextView) v, true);
            
            // Update filter
            String filterText = ((TextView) v).getText().toString();
            currentFilter = filterText;
            applyFilters();
        };
        
        binding.chipAll.setOnClickListener(chipClickListener);
        binding.chipApartment.setOnClickListener(chipClickListener);
        binding.chipHouse.setOnClickListener(chipClickListener);
        binding.chipCondo.setOnClickListener(chipClickListener);
        
        // Set initial selection
        binding.chipAll.setSelected(true);
        updateChipAppearance(binding.chipAll, true);
    }
    
    private void resetChipSelection() {
        binding.chipAll.setSelected(false);
        binding.chipApartment.setSelected(false);
        binding.chipHouse.setSelected(false);
        binding.chipCondo.setSelected(false);
        
        updateChipAppearance(binding.chipAll, false);
        updateChipAppearance(binding.chipApartment, false);
        updateChipAppearance(binding.chipHouse, false);
        updateChipAppearance(binding.chipCondo, false);
    }
    
    private void updateChipAppearance(TextView chip, boolean selected) {
        if (selected) {
            chip.setTextColor(getResources().getColor(android.R.color.white, null));
        } else {
            chip.setTextColor(getResources().getColor(com.roomfinder.android.R.color.text_secondary, null));
        }
    }
    
    private void performSearch(String query) {
        currentSearchQuery = query;
        applyFilters();
    }
    
    private void applyFilters() {
        List<Listing> filteredListings = new ArrayList<>();
        
        for (Listing listing : allListings) {
            boolean matchesSearch = currentSearchQuery.isEmpty() ||
                    listing.getTitle().toLowerCase().contains(currentSearchQuery.toLowerCase()) ||
                    listing.getCity().toLowerCase().contains(currentSearchQuery.toLowerCase()) ||
                    listing.getStreet().toLowerCase().contains(currentSearchQuery.toLowerCase());
            
            boolean matchesFilter = currentFilter.equals("All") ||
                    listing.getHouseType().toLowerCase().contains(currentFilter.toLowerCase());
            
            if (matchesSearch && matchesFilter) {
                filteredListings.add(listing);
            }
        }
        
        listings.clear();
        listings.addAll(filteredListings);
        adapter.notifyDataSetChanged();
        
        Log.d(TAG, "Applied filters - Search: '" + currentSearchQuery + "', Filter: '" + currentFilter + "', Results: " + listings.size());
        
        if (listings.isEmpty() && !allListings.isEmpty()) {
            showEmptyState();
        } else {
            binding.emptyLayout.setVisibility(View.GONE);
        }
    }
    
    private void loadListings() {
        binding.progressBar.setVisibility(View.VISIBLE);
        binding.errorLayout.setVisibility(View.GONE);
        binding.emptyLayout.setVisibility(View.GONE);
        
        Log.d(TAG, "Loading listings from Supabase...");
        
        supabaseService.getAllListings(new SupabaseService.ListingsCallback() {
            @Override
            public void onSuccess(List<Listing> newListings) {
                binding.progressBar.setVisibility(View.GONE);
                binding.swipeRefresh.setRefreshing(false);
                
                Log.d(TAG, "Successfully loaded " + newListings.size() + " listings");
                
                allListings.clear();
                allListings.addAll(newListings);
                applyFilters(); // This will update the displayed listings
                
                if (listings.isEmpty()) {
                    showEmptyState();
                }
            }
            
            @Override
            public void onError(String error) {
                binding.progressBar.setVisibility(View.GONE);
                binding.swipeRefresh.setRefreshing(false);
                
                Log.e(TAG, "Error loading listings: " + error);
                showError("Error loading listings: " + error);
            }
        });
    }
    
    private void showError(String message) {
        binding.errorLayout.setVisibility(View.VISIBLE);
        binding.errorText.setText(message);
        binding.retryButton.setOnClickListener(v -> loadListings());
    }
    
    private void showEmptyState() {
        binding.emptyLayout.setVisibility(View.VISIBLE);
    }
    
    @Override
    public void onListingClick(Listing listing) {
        // TODO: Navigate to property detail
        Toast.makeText(requireContext(), "Opening: " + listing.getTitle(), Toast.LENGTH_SHORT).show();
    }
    
    @Override
    public void onFavoriteClick(Listing listing, int position) {
        listing.setFavorite(!listing.isFavorite());
        adapter.notifyItemChanged(position);
        // TODO: Save to local storage
    }
}