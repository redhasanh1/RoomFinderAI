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
        
        // Text change listener for real-time search and clear button visibility
        binding.searchInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            
            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                // Show/hide clear button based on text content
                if (binding.clearSearchButton != null) {
                    binding.clearSearchButton.setVisibility(s.length() > 0 ? View.VISIBLE : View.GONE);
                }
            }
            
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
        
        // Clear search button click listener
        if (binding.clearSearchButton != null) {
            binding.clearSearchButton.setOnClickListener(v -> {
                binding.searchInput.setText("");
                binding.searchInput.clearFocus();
                hidePopularSearches();
            });
        }
        
        // Show popular searches when search input is focused and empty
        binding.searchInput.setOnFocusChangeListener((v, hasFocus) -> {
            if (hasFocus && binding.searchInput.getText().toString().trim().isEmpty()) {
                showPopularSearches();
            } else if (!hasFocus) {
                hidePopularSearches();
            }
        });
        
        // Setup popular search suggestions
        setupPopularSearches();
        
        // Filter chips click listeners
        setupFilterChips();
    }
    
    private void setupPopularSearches() {
        // Popular search chip click listeners with null checks
        if (binding.chipDowntown != null) {
            binding.chipDowntown.setOnClickListener(v -> {
                performSearchFromSuggestion("downtown");
            });
        }
        
        if (binding.chip2Bedroom != null) {
            binding.chip2Bedroom.setOnClickListener(v -> {
                performSearchFromSuggestion("2 bedroom");
            });
        }
        
        if (binding.chipUnder1500 != null) {
            binding.chipUnder1500.setOnClickListener(v -> {
                performSearchFromSuggestion("under $1500");
            });
        }
        
        if (binding.chipPetFriendly != null) {
            binding.chipPetFriendly.setOnClickListener(v -> {
                performSearchFromSuggestion("pet friendly");
            });
        }
    }
    
    private void performSearchFromSuggestion(String suggestion) {
        binding.searchInput.setText(suggestion);
        binding.searchInput.clearFocus();
        performSearch(suggestion);
        hidePopularSearches();
    }
    
    private void showPopularSearches() {
        if (binding.popularSearchesLayout != null) {
            binding.popularSearchesLayout.setVisibility(View.VISIBLE);
        }
    }
    
    private void hidePopularSearches() {
        if (binding.popularSearchesLayout != null) {
            binding.popularSearchesLayout.setVisibility(View.GONE);
        }
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
        
        // Add null checks for new chips
        if (binding.chipStudio != null) {
            binding.chipStudio.setOnClickListener(chipClickListener);
        }
        if (binding.chipUnder1000 != null) {
            binding.chipUnder1000.setOnClickListener(chipClickListener);
        }
        if (binding.chip1000to1500 != null) {
            binding.chip1000to1500.setOnClickListener(chipClickListener);
        }
        if (binding.chipOver1500 != null) {
            binding.chipOver1500.setOnClickListener(chipClickListener);
        }
        
        // Set initial selection
        binding.chipAll.setSelected(true);
        updateChipAppearance(binding.chipAll, true);
    }
    
    private void resetChipSelection() {
        binding.chipAll.setSelected(false);
        binding.chipApartment.setSelected(false);
        binding.chipHouse.setSelected(false);
        binding.chipCondo.setSelected(false);
        
        // Reset new chips with null checks
        if (binding.chipStudio != null) {
            binding.chipStudio.setSelected(false);
        }
        if (binding.chipUnder1000 != null) {
            binding.chipUnder1000.setSelected(false);
        }
        if (binding.chip1000to1500 != null) {
            binding.chip1000to1500.setSelected(false);
        }
        if (binding.chipOver1500 != null) {
            binding.chipOver1500.setSelected(false);
        }
        
        updateChipAppearance(binding.chipAll, false);
        updateChipAppearance(binding.chipApartment, false);
        updateChipAppearance(binding.chipHouse, false);
        updateChipAppearance(binding.chipCondo, false);
        
        // Update new chip appearances with null checks
        if (binding.chipStudio != null) {
            updateChipAppearance(binding.chipStudio, false);
        }
        if (binding.chipUnder1000 != null) {
            updateChipAppearance(binding.chipUnder1000, false);
        }
        if (binding.chip1000to1500 != null) {
            updateChipAppearance(binding.chip1000to1500, false);
        }
        if (binding.chipOver1500 != null) {
            updateChipAppearance(binding.chipOver1500, false);
        }
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
            boolean matchesSearch = matchesSmartSearch(listing, currentSearchQuery);
            boolean matchesFilter = matchesFilterCriteria(listing, currentFilter);
            
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
    
    private boolean matchesSmartSearch(Listing listing, String query) {
        if (query.isEmpty()) return true;
        
        String lowerQuery = query.toLowerCase().trim();
        
        // Basic text search
        boolean basicMatch = listing.getTitle().toLowerCase().contains(lowerQuery) ||
                listing.getCity().toLowerCase().contains(lowerQuery) ||
                listing.getStreet().toLowerCase().contains(lowerQuery);
        
        // Smart price search
        if (lowerQuery.contains("under") && lowerQuery.contains("$")) {
            try {
                String priceStr = lowerQuery.replaceAll("[^0-9]", "");
                if (!priceStr.isEmpty()) {
                    double maxPrice = Double.parseDouble(priceStr);
                    return listing.getPrice() <= maxPrice;
                }
            } catch (NumberFormatException e) {}
        }
        
        if (lowerQuery.contains("over") && lowerQuery.contains("$")) {
            try {
                String priceStr = lowerQuery.replaceAll("[^0-9]", "");
                if (!priceStr.isEmpty()) {
                    double minPrice = Double.parseDouble(priceStr);
                    return listing.getPrice() >= minPrice;
                }
            } catch (NumberFormatException e) {}
        }
        
        // Price range search (e.g., "1000-1500")
        if (lowerQuery.matches(".*\\d+-\\d+.*")) {
            try {
                String[] parts = lowerQuery.replaceAll("[^0-9-]", "").split("-");
                if (parts.length == 2) {
                    double minPrice = Double.parseDouble(parts[0]);
                    double maxPrice = Double.parseDouble(parts[1]);
                    return listing.getPrice() >= minPrice && listing.getPrice() <= maxPrice;
                }
            } catch (NumberFormatException e) {}
        }
        
        // Bedroom search
        if (lowerQuery.contains("bedroom") || lowerQuery.contains("bed")) {
            try {
                String bedStr = lowerQuery.replaceAll("[^0-9]", "");
                if (!bedStr.isEmpty()) {
                    int bedrooms = Integer.parseInt(bedStr);
                    return listing.getBedrooms() == bedrooms;
                }
            } catch (NumberFormatException e) {}
        }
        
        // Studio search
        if (lowerQuery.contains("studio")) {
            return listing.getHouseType().toLowerCase().contains("studio") ||
                   listing.getBedrooms() == 0;
        }
        
        return basicMatch;
    }
    
    private boolean matchesFilterCriteria(Listing listing, String filter) {
        if (filter.equals("All")) return true;
        
        // Property type filters
        if (filter.equals("Apartment") || filter.equals("House") || 
            filter.equals("Condo") || filter.equals("Studio")) {
            return listing.getHouseType().toLowerCase().contains(filter.toLowerCase()) ||
                   (filter.equals("Studio") && listing.getBedrooms() == 0);
        }
        
        // Price filters
        if (filter.equals("Under $1000")) {
            return listing.getPrice() < 1000;
        }
        if (filter.equals("$1000-1500")) {
            return listing.getPrice() >= 1000 && listing.getPrice() <= 1500;
        }
        if (filter.equals("Over $1500")) {
            return listing.getPrice() > 1500;
        }
        
        return listing.getHouseType().toLowerCase().contains(filter.toLowerCase());
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