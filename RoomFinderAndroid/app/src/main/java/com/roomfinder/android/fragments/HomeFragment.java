package com.roomfinder.android.fragments;

import android.content.Intent;
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
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.roomfinder.android.R;
import com.roomfinder.android.activities.IndividualChatActivity;
import com.roomfinder.android.activities.ListingDetailActivity;
import com.roomfinder.android.activities.LoginActivity;
import com.roomfinder.android.adapters.ListingsAdapter;
import com.roomfinder.android.adapters.SkeletonAdapter;
import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.databinding.FragmentHomeBinding;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.network.SupabaseService;
import android.view.animation.AnimationUtils;
import android.widget.PopupMenu;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

public class HomeFragment extends Fragment implements ListingsAdapter.OnListingClickListener {
    
    private static final String TAG = "HomeFragment";
    private FragmentHomeBinding binding;
    private ListingsAdapter adapter;
    private SkeletonAdapter skeletonAdapter;
    private List<Listing> listings = new ArrayList<>();
    private List<Listing> allListings = new ArrayList<>();
    private SupabaseService supabaseService;
    private String currentFilter = "All";
    private String currentSearchQuery = "";
    private String currentSortOption = "Price: Low → High";
    private int activeFilterCount = 0;
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentHomeBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        supabaseService = SupabaseService.getInstance();
        supabaseService.init(requireContext()); // Initialize with context for caching
        setupRecyclerView();
        setupSwipeRefresh();
        setupSearchAndFilters();
        setupSortAndClearButtons();
        loadListings();
    }
    
    @Override
    public void onDestroyView() {
        super.onDestroyView();
        // Cancel any pending search operations
        cancelPendingSearch();
        binding = null;
    }
    
    private void setupRecyclerView() {
        adapter = new ListingsAdapter(listings, this);
        
        GridLayoutManager layoutManager = new GridLayoutManager(requireContext(), 2);
        binding.recyclerView.setLayoutManager(layoutManager);
        binding.recyclerView.setAdapter(adapter);
        
        // Enable nested scrolling for NestedScrollView compatibility
        binding.recyclerView.setNestedScrollingEnabled(true);
        
        // Improve performance
        binding.recyclerView.setHasFixedSize(false); // Allow dynamic sizing
        binding.recyclerView.setItemViewCacheSize(20);
        
        Log.d(TAG, "📱 [DEBUG] RecyclerView setup completed with GridLayoutManager(spanCount=2)");
        
        // Setup skeleton loading
        setupSkeletonLoading();
    }
    
    private void setupSkeletonLoading() {
        skeletonAdapter = new SkeletonAdapter(8); // Show 8 skeleton items (4 rows x 2 columns)
        GridLayoutManager skeletonLayoutManager = new GridLayoutManager(requireContext(), 2);
        binding.skeletonRecyclerView.setLayoutManager(skeletonLayoutManager);
        binding.skeletonRecyclerView.setAdapter(skeletonAdapter);
        binding.skeletonRecyclerView.setNestedScrollingEnabled(true);
        
        Log.d(TAG, "💀 [DEBUG] Skeleton RecyclerView setup with 8 items");
    }
    
    private void setupSwipeRefresh() {
        binding.swipeRefresh.setOnRefreshListener(() -> {
            // Force refresh (bypass cache)
            supabaseService.refreshListings(new SupabaseService.ListingsCallback() {
                @Override
                public void onSuccess(List<Listing> newListings) {
                    binding.swipeRefresh.setRefreshing(false);
                    Log.d(TAG, "Refresh: Successfully loaded " + newListings.size() + " listings");
                    
                    allListings.clear();
                    allListings.addAll(newListings);
                    applyFilters();
                    
                    if (listings.isEmpty()) {
                        showEmptyState();
                    }
                }
                
                @Override
                public void onError(String error) {
                    binding.swipeRefresh.setRefreshing(false);
                    Log.e(TAG, "Refresh error: " + error);
                    showError("Refresh failed: " + error);
                }
            });
        });
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
                    // Improved debouncing with longer delay and better cancellation
                    cancelPendingSearch();
                    if (!query.trim().isEmpty()) {
                        binding.searchInput.postDelayed(searchRunnable, 500); // Increased to 500ms
                    } else {
                        // If search is empty, apply immediately
                        performSearch(query);
                    }
                }
            }
        });
        
        // Clear search button click listener
        if (binding.clearSearchButton != null) {
            binding.clearSearchButton.setOnClickListener(v -> {
                cancelPendingSearch(); // Cancel any pending search
                binding.searchInput.setText("");
                binding.searchInput.clearFocus();
                hidePopularSearches();
                // Immediately apply empty search
                currentSearchQuery = "";
                performSearch("");
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
        cancelPendingSearch(); // Cancel any pending search
        binding.searchInput.setText(suggestion);
        binding.searchInput.clearFocus();
        currentSearchQuery = suggestion;
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
    
    private void cancelPendingSearch() {
        binding.searchInput.removeCallbacks(searchRunnable);
    }
    
    private void setupFilterChips() {
        View.OnClickListener chipClickListener = v -> {
            // Reset all chips
            resetChipSelection();
            
            // Set selected chip with animation
            v.setSelected(true);
            updateChipAppearanceWithAnimation((TextView) v, true);
            
            // Update filter
            String filterText = ((TextView) v).getText().toString();
            currentFilter = filterText;
            applyFiltersWithAnimation();
            updateFilterButtonsVisibility();
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
        updateChipAppearanceWithAnimation(binding.chipAll, true);
    }
    
    private void setupSortAndClearButtons() {
        // Setup sort button
        if (binding.sortButton != null) {
            binding.sortButton.setOnClickListener(v -> showSortMenu());
        }
        
        // Setup clear all filters button  
        if (binding.clearAllFiltersButton != null) {
            binding.clearAllFiltersButton.setOnClickListener(v -> clearAllFilters());
        }
        
        // Add debug button temporarily (remove this later)
        if (binding.sortButton != null) {
            binding.sortButton.setOnLongClickListener(v -> {
                clearCacheAndReload();
                return true;
            });
        }
        
        updateFilterButtonsVisibility();
    }
    
    private void showSortMenu() {
        PopupMenu popup = new PopupMenu(requireContext(), binding.sortButton);
        popup.getMenuInflater().inflate(R.menu.sort_menu, popup.getMenu());
        
        popup.setOnMenuItemClickListener(item -> {
            String sortOption = item.getTitle().toString();
            if (!sortOption.equals(currentSortOption)) {
                currentSortOption = sortOption;
                binding.sortButton.setText("Sort: " + sortOption + " ▼");
                applyFiltersWithAnimation();
            }
            return true;
        });
        
        popup.show();
    }
    
    private void clearAllFilters() {
        // Clear search
        cancelPendingSearch();
        binding.searchInput.setText("");
        currentSearchQuery = "";
        
        // Reset filter to "All"
        currentFilter = "All";
        resetChipSelection();
        binding.chipAll.setSelected(true);
        updateChipAppearanceWithAnimation(binding.chipAll, true);
        
        // Reset sort to default
        currentSortOption = "Price: Low → High";
        binding.sortButton.setText("Sort ▼");
        
        // Apply changes with animation
        applyFiltersWithAnimation();
        updateFilterButtonsVisibility();
    }
    
    private void updateFilterButtonsVisibility() {
        boolean hasActiveFilters = !currentSearchQuery.isEmpty() || 
                                 !currentFilter.equals("All") || 
                                 !currentSortOption.equals("Price: Low → High");
        
        if (binding.clearAllFiltersButton != null) {
            if (hasActiveFilters && binding.clearAllFiltersButton.getVisibility() == View.GONE) {
                binding.clearAllFiltersButton.setVisibility(View.VISIBLE);
                binding.clearAllFiltersButton.startAnimation(AnimationUtils.loadAnimation(requireContext(), R.anim.fade_in));
            } else if (!hasActiveFilters && binding.clearAllFiltersButton.getVisibility() == View.VISIBLE) {
                binding.clearAllFiltersButton.startAnimation(AnimationUtils.loadAnimation(requireContext(), R.anim.fade_out));
                binding.clearAllFiltersButton.setVisibility(View.GONE);
            }
        }
    }
    
    private void clearCacheAndReload() {
        Log.d(TAG, "🧹 [DEBUG] Force clearing cache and reloading...");
        Toast.makeText(requireContext(), "Force reloading all data...", Toast.LENGTH_SHORT).show();
        
        // Clear all cached data
        allListings.clear();
        listings.clear();
        adapter.notifyDataSetChanged();
        
        // Force refresh (bypasses cache)  
        supabaseService.refreshListings(new SupabaseService.ListingsCallback() {
            @Override
            public void onSuccess(List<Listing> newListings) {
                Log.d(TAG, "🧹 [DEBUG] Force refresh successful: " + newListings.size() + " listings");
                allListings.clear();
                allListings.addAll(newListings);
                applyFilters();
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "🧹 [DEBUG] Force refresh failed: " + error);
                Toast.makeText(requireContext(), "Failed to reload: " + error, Toast.LENGTH_LONG).show();
            }
        });
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
            chip.setBackgroundResource(R.drawable.filter_chip_selected);
        } else {
            chip.setTextColor(getResources().getColor(R.color.text_secondary, null));
            chip.setBackgroundResource(R.drawable.filter_chip_unselected);
        }
    }
    
    private void updateChipAppearanceWithAnimation(TextView chip, boolean selected) {
        // Start fade animation
        chip.startAnimation(AnimationUtils.loadAnimation(requireContext(), R.anim.fade_out));
        
        // Apply new appearance after fade out
        chip.postDelayed(() -> {
            updateChipAppearance(chip, selected);
            chip.startAnimation(AnimationUtils.loadAnimation(requireContext(), R.anim.fade_in));
        }, 100);
    }
    
    private void applyFiltersWithAnimation() {
        // Show brief loading state
        binding.recyclerView.startAnimation(AnimationUtils.loadAnimation(requireContext(), R.anim.fade_out));
        
        binding.recyclerView.postDelayed(() -> {
            applyFilters();
            binding.recyclerView.startAnimation(AnimationUtils.loadAnimation(requireContext(), R.anim.slide_in_up));
        }, 150);
    }
    
    private void performSearch(String query) {
        currentSearchQuery = query;
        applyFiltersWithAnimation();
        updateFilterButtonsVisibility();
    }
    
    private void applyFilters() {
        Log.d(TAG, "🔍 [DEBUG] applyFilters() called");
        Log.d(TAG, "🔍 [DEBUG] Input: allListings.size() = " + allListings.size());
        Log.d(TAG, "🔍 [DEBUG] Current search query: '" + currentSearchQuery + "'");
        Log.d(TAG, "🔍 [DEBUG] Current filter: '" + currentFilter + "'");
        Log.d(TAG, "🔍 [DEBUG] Current sort: '" + currentSortOption + "'");
        
        List<Listing> filteredListings = new ArrayList<>();
        
        for (int i = 0; i < allListings.size(); i++) {
            Listing listing = allListings.get(i);
            boolean matchesSearch = matchesSmartSearch(listing, currentSearchQuery);
            boolean matchesFilter = matchesFilterCriteria(listing, currentFilter);
            
            Log.d(TAG, "🔍 [DEBUG] Listing " + (i+1) + "/" + allListings.size() + 
                  ": '" + (listing.getTitle() != null ? listing.getTitle().substring(0, Math.min(20, listing.getTitle().length())) : "null") + "'" +
                  " | Search: " + matchesSearch + " | Filter: " + matchesFilter);
            
            if (matchesSearch && matchesFilter) {
                filteredListings.add(listing);
            }
        }
        
        Log.d(TAG, "🔍 [DEBUG] After filtering: " + filteredListings.size() + " listings remain");
        
        // Apply sorting
        applySorting(filteredListings);
        Log.d(TAG, "🔍 [DEBUG] After sorting: " + filteredListings.size() + " listings");
        
        listings.clear();
        listings.addAll(filteredListings);
        adapter.notifyDataSetChanged();
        
        Log.d(TAG, "🔍 [DEBUG] Final result: " + listings.size() + " listings displayed to user");
        Log.d(TAG, "Applied filters - Search: '" + currentSearchQuery + "', Filter: '" + currentFilter + "', Results: " + listings.size());
        
        if (listings.isEmpty() && !allListings.isEmpty()) {
            Log.d(TAG, "⚠️ [DEBUG] Showing empty state (filtered out all listings)");
            showEmptyState();
        } else {
            binding.emptyLayout.setVisibility(View.GONE);
        }
    }
    
    private void applySorting(List<Listing> listings) {
        switch (currentSortOption) {
            case "Price: Low → High":
                Collections.sort(listings, Comparator.comparingDouble(Listing::getPrice));
                break;
            case "Price: High → Low":
                Collections.sort(listings, Comparator.comparingDouble(Listing::getPrice).reversed());
                break;
            case "Newest First":
                Collections.sort(listings, (a, b) -> {
                    // Sort by created_at desc (newest first)
                    if (a.getCreatedAt() == null) return 1;
                    if (b.getCreatedAt() == null) return -1;
                    return b.getCreatedAt().compareTo(a.getCreatedAt());
                });
                break;
            case "Oldest First":
                Collections.sort(listings, (a, b) -> {
                    // Sort by created_at asc (oldest first)
                    if (a.getCreatedAt() == null) return 1;
                    if (b.getCreatedAt() == null) return -1;
                    return a.getCreatedAt().compareTo(b.getCreatedAt());
                });
                break;
            default:
                // Default to price low to high
                Collections.sort(listings, Comparator.comparingDouble(Listing::getPrice));
                break;
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
        // Show skeleton loading instead of progress bar
        showSkeletonLoading();
        binding.errorLayout.setVisibility(View.GONE);
        binding.emptyLayout.setVisibility(View.GONE);
        
        Log.d(TAG, "🔄 [DEBUG] Starting loadListings()");
        Log.d(TAG, "🔄 [DEBUG] Current allListings.size() = " + allListings.size());
        Log.d(TAG, "🔄 [DEBUG] Current listings.size() = " + listings.size());
        
        supabaseService.getAllListings(new SupabaseService.ListingsCallback() {
            @Override
            public void onSuccess(List<Listing> newListings) {
                Log.d(TAG, "✅ [DEBUG] onSuccess called with " + (newListings != null ? newListings.size() : 0) + " listings");
                
                hideSkeletonLoading();
                binding.swipeRefresh.setRefreshing(false);
                
                if (newListings == null) {
                    Log.e(TAG, "❌ [DEBUG] newListings is NULL!");
                    showError("Received null data from server");
                    return;
                }
                
                Log.d(TAG, "📊 [DEBUG] Processing " + newListings.size() + " new listings");
                
                // Clear and populate allListings
                allListings.clear();
                allListings.addAll(newListings);
                Log.d(TAG, "📊 [DEBUG] allListings now contains " + allListings.size() + " items");
                
                // Apply filters which updates the displayed listings
                Log.d(TAG, "🔍 [DEBUG] Applying filters...");
                applyFilters();
                
                Log.d(TAG, "📊 [DEBUG] After applyFilters, listings.size() = " + listings.size());
                
                if (listings.isEmpty()) {
                    Log.d(TAG, "⚠️ [DEBUG] No listings after filtering - showing empty state");
                    showEmptyState();
                } else {
                    Log.d(TAG, "✅ [DEBUG] Successfully showing " + listings.size() + " listings to user");
                }
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "❌ [DEBUG] onError called: " + error);
                hideSkeletonLoading();
                binding.swipeRefresh.setRefreshing(false);
                showError("Error loading listings: " + error);
            }
        });
    }
    
    private void showSkeletonLoading() {
        Log.d(TAG, "💀 [DEBUG] showSkeletonLoading() called");
        binding.skeletonScrollView.setVisibility(View.VISIBLE);
        binding.progressBar.setVisibility(View.GONE);
        // Hide other states
        binding.errorLayout.setVisibility(View.GONE);
        binding.emptyLayout.setVisibility(View.GONE);
    }
    
    private void hideSkeletonLoading() {
        Log.d(TAG, "💀 [DEBUG] hideSkeletonLoading() called");
        binding.skeletonScrollView.setVisibility(View.GONE);
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
        // Navigate to listing detail activity
        Intent intent = new Intent(requireContext(), ListingDetailActivity.class);
        intent.putExtra("listing", listing);
        startActivity(intent);
    }
    
    @Override
    public void onFavoriteClick(Listing listing, int position) {
        listing.setFavorite(!listing.isFavorite());
        adapter.notifyItemChanged(position);
        // TODO: Save to local storage
    }
    
    @Override
    public void onChatClick(Listing listing) {
        AuthManager authManager = AuthManager.getInstance(requireContext());
        
        if (authManager.isUserAuthenticated()) {
            // Get current user email
            String currentUserEmail = authManager.getUserEmail();
            
            // Start chat activity
            Intent intent = new Intent(requireContext(), IndividualChatActivity.class);
            intent.putExtra("listing_id", listing.getId());
            intent.putExtra("listing_title", listing.getTitle());
            intent.putExtra("owner_email", listing.getUserEmail());
            intent.putExtra("current_user_email", currentUserEmail);
            startActivity(intent);
        } else {
            // Show login required dialog
            new MaterialAlertDialogBuilder(requireContext())
                    .setTitle("Login Required")
                    .setMessage("You need to sign in to chat with property owners.")
                    .setPositiveButton("Sign In", (dialog, which) -> {
                        Intent loginIntent = new Intent(requireContext(), LoginActivity.class);
                        startActivity(loginIntent);
                    })
                    .setNegativeButton("Cancel", null)
                    .setIcon(R.drawable.ic_chat)
                    .show();
        }
    }
}