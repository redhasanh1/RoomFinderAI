package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.GridLayoutManager;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.inputmethod.EditorInfo;
import android.widget.ArrayAdapter;
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
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

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
    private List<String> selectedPropertyTypes = new ArrayList<>();
    private String currentSearchQuery = "";
    private boolean filtersVisible = false;
    
    // Search functionality
    private final Runnable searchRunnable = () -> performSearch();
    
    // Sorting options
    private enum SortOption {
        RELEVANCE("Relevance"),
        PRICE_LOW_HIGH("Price: Low to High"),
        PRICE_HIGH_LOW("Price: High to Low"),
        NEWEST("Newest First"),
        BEDROOMS("Most Bedrooms");
        
        private final String displayName;
        
        SortOption(String displayName) {
            this.displayName = displayName;
        }
        
        @Override
        public String toString() {
            return displayName;
        }
    }
    
    private SortOption currentSort = SortOption.RELEVANCE;
    
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
        // Setup RecyclerView with single column for better mobile experience
        adapter = new ListingsAdapter(listings, this);
        binding.recyclerView.setLayoutManager(new GridLayoutManager(requireContext(), 1));
        binding.recyclerView.setAdapter(adapter);
        
        // Setup enhanced search with real-time search
        setupEnhancedSearch();
        
        // Setup filters
        setupEnhancedFilters();
        
        // Setup sorting
        setupSorting();
        
        // Setup search suggestions
        setupSearchSuggestions();
        
        // Clear filters button
        if (binding.clearFiltersButton != null) {
            binding.clearFiltersButton.setOnClickListener(v -> clearFilters());
        }
        
        // Initialize UI state
        updateResultsCount(0);
        updateActiveFiltersDisplay();
    }
    
    private void setupEnhancedSearch() {
        // Real-time search with debouncing
        binding.searchInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            
            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                // Show/hide clear button
                if (binding.clearSearchButton != null) {
                    binding.clearSearchButton.setVisibility(s.length() > 0 ? View.VISIBLE : View.GONE);
                }
            }
            
            @Override
            public void afterTextChanged(Editable s) {
                currentSearchQuery = s.toString().trim();
                // Debounce search to avoid too many API calls
                binding.searchInput.removeCallbacks(searchRunnable);
                if (!currentSearchQuery.isEmpty()) {
                    binding.searchInput.postDelayed(searchRunnable, 300);
                } else {
                    clearResults();
                }
            }
        });
        
        // Search on enter key
        binding.searchInput.setOnEditorActionListener((v, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_SEARCH) {
                performSearch();
                return true;
            }
            return false;
        });
        
        // Clear search button
        if (binding.clearSearchButton != null) {
            binding.clearSearchButton.setOnClickListener(v -> {
                binding.searchInput.setText("");
                binding.searchInput.clearFocus();
            });
        }
        
        // Focus handling for suggestions
        binding.searchInput.setOnFocusChangeListener((v, hasFocus) -> {
            if (hasFocus && currentSearchQuery.isEmpty()) {
                showSearchSuggestions();
            } else if (!hasFocus) {
                hideSearchSuggestions();
            }
        });
    }
    
    private void setupEnhancedFilters() {
        // Toggle filters visibility
        if (binding.toggleFiltersButton != null) {
            binding.toggleFiltersButton.setOnClickListener(v -> toggleFilters());
        }
        
        // Clear all filters
        if (binding.clearAllFiltersButton != null) {
            binding.clearAllFiltersButton.setOnClickListener(v -> clearAllFilters());
        }
        
        // Property type filters
        if (binding.propertyTypeChipGroup != null) {
            binding.propertyTypeChipGroup.setOnCheckedStateChangeListener((group, checkedIds) -> {
                selectedPropertyTypes.clear();
                for (int id : checkedIds) {
                    Chip chip = group.findViewById(id);
                    if (chip != null) {
                        selectedPropertyTypes.add(chip.getText().toString());
                    }
                }
                updateActiveFiltersDisplay();
                performSearch();
            });
        }
    }
    
    private void setupSorting() {
        // Setup sort spinner
        if (binding.sortSpinner != null) {
            ArrayAdapter<SortOption> sortAdapter = new ArrayAdapter<>(requireContext(), 
                android.R.layout.simple_spinner_item, SortOption.values());
            sortAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
            binding.sortSpinner.setAdapter(sortAdapter);
            
            binding.sortSpinner.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener() {
                @Override
                public void onItemSelected(android.widget.AdapterView<?> parent, View view, int position, long id) {
                    currentSort = SortOption.values()[position];
                    sortResults();
                }
                
                @Override
                public void onNothingSelected(android.widget.AdapterView<?> parent) {}
            });
        }
    }
    
    private void setupSearchSuggestions() {
        if (binding.suggestionDowntown != null) {
            binding.suggestionDowntown.setOnClickListener(v -> performSearchFromSuggestion("downtown"));
        }
        if (binding.suggestionAffordable != null) {
            binding.suggestionAffordable.setOnClickListener(v -> performSearchFromSuggestion("under $1000"));
        }
        if (binding.suggestion2Bed != null) {
            binding.suggestion2Bed.setOnClickListener(v -> performSearchFromSuggestion("2 bedroom"));
        }
        if (binding.suggestionPetFriendly != null) {
            binding.suggestionPetFriendly.setOnClickListener(v -> performSearchFromSuggestion("pet friendly"));
        }
    }
    
    private void performSearchFromSuggestion(String suggestion) {
        binding.searchInput.setText(suggestion);
        binding.searchInput.clearFocus();
        hideSearchSuggestions();
    }
    
    private void showSearchSuggestions() {
        if (binding.searchSuggestionsContainer != null) {
            binding.searchSuggestionsContainer.setVisibility(View.VISIBLE);
        }
    }
    
    private void hideSearchSuggestions() {
        if (binding.searchSuggestionsContainer != null) {
            binding.searchSuggestionsContainer.setVisibility(View.GONE);
        }
    }
    
    private void toggleFilters() {
        filtersVisible = !filtersVisible;
        if (binding.filtersScrollView != null) {
            binding.filtersScrollView.setVisibility(filtersVisible ? View.VISIBLE : View.GONE);
        }
        if (binding.toggleFiltersButton != null) {
            binding.toggleFiltersButton.setText(filtersVisible ? "Hide Filters" : "Show Filters");
        }
    }
    
    private void updateActiveFiltersDisplay() {
        List<String> activeFilters = new ArrayList<>();
        
        if (minPrice != null || maxPrice != null) {
            if (minPrice != null && maxPrice != null) {
                activeFilters.add("$" + minPrice.intValue() + "-$" + maxPrice.intValue());
            } else if (minPrice != null) {
                activeFilters.add("Over $" + minPrice.intValue());
            } else {
                activeFilters.add("Under $" + maxPrice.intValue());
            }
        }
        
        if (selectedBedrooms != null) {
            activeFilters.add(selectedBedrooms + (selectedBedrooms == 1 ? " bedroom" : " bedrooms"));
        }
        
        if (!selectedPropertyTypes.isEmpty()) {
            activeFilters.addAll(selectedPropertyTypes);
        }
        
        if (binding.activeFiltersContainer != null && binding.activeFiltersText != null) {
            if (activeFilters.isEmpty()) {
                binding.activeFiltersContainer.setVisibility(View.GONE);
            } else {
                binding.activeFiltersContainer.setVisibility(View.VISIBLE);
                binding.activeFiltersText.setText(String.join(", ", activeFilters));
            }
        }
    }
    
    private void clearAllFilters() {
        minPrice = null;
        maxPrice = null;
        selectedBedrooms = null;
        selectedLocation = null;
        selectedPropertyTypes.clear();
        
        // Clear chip selections
        if (binding.priceChipGroup != null) {
            binding.priceChipGroup.clearCheck();
        }
        if (binding.bedroomsChipGroup != null) {
            binding.bedroomsChipGroup.clearCheck();
        }
        if (binding.propertyTypeChipGroup != null) {
            binding.propertyTypeChipGroup.clearCheck();
        }
        
        updateActiveFiltersDisplay();
        performSearch();
    }
    
    private void updateResultsCount(int count) {
        if (binding.resultsCountText != null) {
            String text = count == 0 ? "No properties found" : 
                         count == 1 ? "1 property found" : 
                         count + " properties found";
            binding.resultsCountText.setText(text);
        }
    }
    
    private void clearResults() {
        listings.clear();
        adapter.notifyDataSetChanged();
        updateResultsCount(0);
    }
    
    private void sortResults() {
        if (listings.isEmpty()) return;
        
        switch (currentSort) {
            case PRICE_LOW_HIGH:
                Collections.sort(listings, Comparator.comparing(Listing::getPrice));
                break;
            case PRICE_HIGH_LOW:
                Collections.sort(listings, (l1, l2) -> Double.compare(l2.getPrice(), l1.getPrice()));
                break;
            case BEDROOMS:
                Collections.sort(listings, (l1, l2) -> Integer.compare(l2.getBedrooms(), l1.getBedrooms()));
                break;
            case NEWEST:
                // Assuming listings have a creation date - if not, maintain current order
                break;
            case RELEVANCE:
            default:
                // Keep current order (server relevance)
                break;
        }
        
        adapter.notifyDataSetChanged();
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
        if (currentSearchQuery.trim().isEmpty() && minPrice == null && maxPrice == null && 
            selectedBedrooms == null && selectedPropertyTypes.isEmpty()) {
            clearResults();
            return;
        }
        
        binding.progressBar.setVisibility(View.VISIBLE);
        binding.emptyLayout.setVisibility(View.GONE);
        hideSearchSuggestions();
        
        apiService.searchListings(currentSearchQuery, minPrice, maxPrice, selectedBedrooms, selectedLocation)
            .enqueue(new Callback<ApiResponse<List<Listing>>>() {
                @Override
                public void onResponse(Call<ApiResponse<List<Listing>>> call, Response<ApiResponse<List<Listing>>> response) {
                    binding.progressBar.setVisibility(View.GONE);
                    
                    if (response.isSuccessful() && response.body() != null && response.body().isSuccess()) {
                        listings.clear();
                        List<Listing> results = response.body().getData();
                        if (results != null) {
                            // Apply client-side filters
                            List<Listing> filteredResults = applyClientSideFilters(results);
                            listings.addAll(filteredResults);
                        }
                        
                        sortResults();
                        adapter.notifyDataSetChanged();
                        updateResultsCount(listings.size());
                        
                        if (listings.isEmpty()) {
                            binding.emptyLayout.setVisibility(View.VISIBLE);
                        }
                    } else {
                        handleSearchError("Search failed");
                    }
                }
                
                @Override
                public void onFailure(Call<ApiResponse<List<Listing>>> call, Throwable t) {
                    binding.progressBar.setVisibility(View.GONE);
                    handleSearchError("Network error: " + t.getMessage());
                }
            });
    }
    
    private List<Listing> applyClientSideFilters(List<Listing> results) {
        return results.stream()
                .filter(listing -> {
                    // Property type filter
                    if (!selectedPropertyTypes.isEmpty()) {
                        boolean matchesType = selectedPropertyTypes.stream()
                                .anyMatch(type -> listing.getHouseType() != null && 
                                         listing.getHouseType().toLowerCase().contains(type.toLowerCase()));
                        if (!matchesType) return false;
                    }
                    
                    // Smart search matching (similar to HomeFragment logic)
                    if (!currentSearchQuery.isEmpty()) {
                        return matchesSmartSearch(listing, currentSearchQuery);
                    }
                    
                    return true;
                })
                .collect(Collectors.toList());
    }
    
    private boolean matchesSmartSearch(Listing listing, String query) {
        String lowerQuery = query.toLowerCase().trim();
        
        // Basic text search
        boolean basicMatch = listing.getTitle().toLowerCase().contains(lowerQuery) ||
                (listing.getCity() != null && listing.getCity().toLowerCase().contains(lowerQuery)) ||
                (listing.getStreet() != null && listing.getStreet().toLowerCase().contains(lowerQuery));
        
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
            return (listing.getHouseType() != null && listing.getHouseType().toLowerCase().contains("studio")) ||
                   listing.getBedrooms() == 0;
        }
        
        return basicMatch;
    }
    
    private void handleSearchError(String error) {
        updateResultsCount(0);
        // You could show a toast or error message here
        // Toast.makeText(requireContext(), error, Toast.LENGTH_SHORT).show();
    }
    
    private void clearFilters() {
        clearAllFilters();
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