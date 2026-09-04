package com.roomfinder.android.fragments;

import android.content.Intent;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
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

import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.roomfinder.android.R;
import com.roomfinder.android.activities.IndividualChatActivity;
import com.roomfinder.android.activities.ListingDetailActivity;
import com.roomfinder.android.activities.LoginActivity;
import com.roomfinder.android.adapters.HomeFeedAdapter;
import com.roomfinder.android.adapters.ListingsAdapter;
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
    private HomeFeedAdapter adapter;
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
        setupQuickTools();
        loadListings();
    }
    
    @Override
    public void onDestroyView() {
        super.onDestroyView();
        // Cancel any pending search operations
        cancelPendingSearch();
        binding = null;
    }
    
    /**
     * Pads the app bar by the status bar height so its opaque background fills
     * that strip. Without it the gradient banner scrolled up through the clock
     * and the battery icon. Read from the real inset rather than a hardcoded
     * 24dp, which is wrong on punch-hole and notched devices.
     */
    private void applyStatusBarInset() {
        if (binding == null || binding.appBar == null) {
            return;
        }
        androidx.core.view.ViewCompat.setOnApplyWindowInsetsListener(binding.appBar, (view, insets) -> {
            int top = insets.getInsets(androidx.core.view.WindowInsetsCompat.Type.statusBars()).top;
            view.setPadding(view.getPaddingLeft(), top, view.getPaddingRight(), view.getPaddingBottom());
            return insets;
        });
    }

    private void setupQuickTools() {
        if (binding == null || binding.heroBanner == null) {
            return;
        }

        // iOS: tapping "Let the AI negotiate" selects the Messages tab, which is
        // where the negotiator lives. The three neon tool tiles that used to sit
        // here have no counterpart on iOS.
        binding.heroBanner.setOnClickListener(v -> {
            if (getActivity() instanceof com.roomfinder.android.MainActivity) {
                ((com.roomfinder.android.MainActivity) getActivity())
                        .navigateToTab(R.id.navigation_chat);
            }
        });
    }

    private void setupRecyclerView() {
        if (binding == null || binding.recyclerView == null) {
            return;
        }
        
        // One vertical feed of sections, the way the iOS home screen is built:
        // shelves on top, then the full "All rooms" list. A two-column grid of
        // small tiles was the other half of why the apps looked unrelated.
        adapter = new HomeFeedAdapter(listings, this);

        androidx.recyclerview.widget.LinearLayoutManager layoutManager =
                new androidx.recyclerview.widget.LinearLayoutManager(requireContext());
        binding.recyclerView.setLayoutManager(layoutManager);
        binding.recyclerView.setAdapter(adapter);

        binding.recyclerView.setNestedScrollingEnabled(true);
        
        // Optimize performance
        // Rows vary in height (headers, shelves, cards), so this cannot be fixed.
        binding.recyclerView.setHasFixedSize(false);
        binding.recyclerView.setItemViewCacheSize(30); // Larger cache
        
        // Create shared recycled view pool for better memory management
        androidx.recyclerview.widget.RecyclerView.RecycledViewPool recycledViewPool = 
            new androidx.recyclerview.widget.RecyclerView.RecycledViewPool();
        recycledViewPool.setMaxRecycledViews(0, 20); // Cache up to 20 views
        binding.recyclerView.setRecycledViewPool(recycledViewPool);
        
        Log.d(TAG, "📱 [DEBUG] RecyclerView setup completed with the sectioned feed adapter");
        
        // Removed setupSkeletonLoading() to fix crash
    }
    
    
    private void setupSwipeRefresh() {
        if (binding == null || binding.swipeRefresh == null) {
            return;
        }
        
        binding.swipeRefresh.setOnRefreshListener(() -> {
            // Force refresh (bypass cache)
            supabaseService.refreshListings(new SupabaseService.ListingsCallback() {
                @Override
                public void onSuccess(List<Listing> newListings) {
                    if (binding != null && binding.swipeRefresh != null) {
                        binding.swipeRefresh.setRefreshing(false);
                    }
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
                    if (binding != null && binding.swipeRefresh != null) {
                        binding.swipeRefresh.setRefreshing(false);
                    }
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
            
            // Set selected chip - Material Chips handle appearance
            if (v instanceof com.google.android.material.chip.Chip) {
                ((com.google.android.material.chip.Chip) v).setChecked(true);
            }
            
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
        
        // Add null checks for chips
        if (binding.chipStudio != null) {
            binding.chipStudio.setOnClickListener(chipClickListener);
        }
        
        // Set initial selection - Material Chips handle their own appearance
        binding.chipAll.setChecked(true);
    }
    
    private void setupSortAndClearButtons() {
        // Setup sort button
        if (binding.sortButton != null) {
            binding.sortButton.setOnClickListener(v -> showSortMenu());
        }
        
        // Clear all filters functionality removed - simplified design
        
        // Add debug button temporarily (remove this later)
        if (binding.sortButton != null) {
            binding.sortButton.setOnLongClickListener(v -> {
                clearCacheAndReload();
                return true;
            });
        }
        
        updateFilterButtonsVisibility();
    }
    
    /**
     * Sort, in a bottom sheet.
     *
     * A PopupMenu anchored to the small Sort button gave no indication of which
     * option was already active, and there is nowhere for price and bedroom
     * filters to go later. The sheet marks the current choice with a tick.
     */
    private void showSortMenu() {
        com.google.android.material.bottomsheet.BottomSheetDialog sheet =
                new com.google.android.material.bottomsheet.BottomSheetDialog(requireContext());
        View view = getLayoutInflater().inflate(R.layout.sheet_sort, null);
        sheet.setContentView(view);

        android.widget.TextView[] rows = {
                view.findViewById(R.id.sortPriceLow),
                view.findViewById(R.id.sortPriceHigh),
                view.findViewById(R.id.sortNewest),
                view.findViewById(R.id.sortOldest)
        };
        // The values the filtering code already understands.
        String[] options = {"Price: Low → High", "Price: High → Low", "Newest First", "Oldest First"};

        for (int i = 0; i < rows.length; i++) {
            final String option = options[i];
            android.widget.TextView row = rows[i];
            boolean active = option.equals(currentSortOption);
            row.setCompoundDrawablesRelativeWithIntrinsicBounds(
                    0, 0, active ? R.drawable.ic_check : 0, 0);
            row.setOnClickListener(v -> {
                currentSortOption = option;
                applyFiltersWithAnimation();
                sheet.dismiss();
            });
        }

        sheet.show();
    }

    private void clearAllFilters() {
        // Clear search
        cancelPendingSearch();
        binding.searchInput.setText("");
        currentSearchQuery = "";
        
        // Reset filter to "All"
        currentFilter = "All";
        resetChipSelection();
        binding.chipAll.setChecked(true);
        
        // Reset sort to default
        currentSortOption = "Price: Low → High";
        binding.sortButton.setText("Sort");
        
        // Apply changes with animation
        applyFiltersWithAnimation();
        updateFilterButtonsVisibility();
    }
    
    private void updateFilterButtonsVisibility() {
        // Simplified design - no clear filters button needed
    }
    
    private void clearCacheAndReload() {
        Log.d(TAG, "🧹 [DEBUG] Force clearing cache and reloading...");
        Toast.makeText(requireContext(), "Force reloading all data...", Toast.LENGTH_SHORT).show();
        
        // Clear all cached data
        allListings.clear();
        listings.clear();
        adapter.submit();
        
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
        binding.chipAll.setChecked(false);
        binding.chipApartment.setChecked(false);
        binding.chipHouse.setChecked(false);
        binding.chipCondo.setChecked(false);
        
        // Reset chips with null checks
        if (binding.chipStudio != null) {
            binding.chipStudio.setChecked(false);
        }
        
        // Material Chips handle their own appearance automatically
    }
    
    // Material Chips handle their own appearance - method removed
    
    // Material Chips handle their own animations - method removed
    
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
        adapter.setLoading(false);
        // The footer offers a way back to everything, but only when something
        // is actually narrowing the list.
        boolean narrowed = !currentSearchQuery.isEmpty() || !"All".equals(currentFilter);
        adapter.setFiltered(narrowed, this::clearAllFilters);
        // Once someone narrows the list, the curated shelves are in the way:
        // they asked for particular rooms, and a "Featured" carousel above them
        // answers a question nobody asked. Same rule as the iOS screen.
        adapter.setShowsSections(currentSearchQuery.isEmpty() && "All".equals(currentFilter));
        adapter.submit();
        
        Log.d(TAG, "🔍 [DEBUG] Final result: " + listings.size() + " listings displayed to user");
        Log.d(TAG, "Applied filters - Search: '" + currentSearchQuery + "', Filter: '" + currentFilter + "', Results: " + listings.size());
        
        if (listings.isEmpty() && !allListings.isEmpty()) {
            Log.d(TAG, "⚠️ [DEBUG] Showing empty state (filtered out all listings)");
            showEmptyState();
        } else {
            if (binding != null && binding.emptyLayout != null) {
                binding.emptyLayout.setVisibility(View.GONE);
            }
        }
    }
    
    /**
     * Apply filters without sorting - preserves append order for progressive loading
     */
    private void applyFiltersProgressive() {
        Log.d(TAG, "🔍 [DEBUG] applyFiltersProgressive() called - preserving append order");
        Log.d(TAG, "🔍 [DEBUG] Input: allListings.size() = " + allListings.size());
        
        List<Listing> filteredListings = new ArrayList<>();
        
        for (Listing listing : allListings) {
            boolean matchesSearch = matchesSmartSearch(listing, currentSearchQuery);
            boolean matchesFilter = matchesFilterCriteria(listing, currentFilter);
            
            if (matchesSearch && matchesFilter) {
                filteredListings.add(listing);
            }
        }
        
        Log.d(TAG, "🔍 [DEBUG] Progressive filter result: " + filteredListings.size() + " listings (no sorting applied)");
        
        listings.clear();
        listings.addAll(filteredListings);
        
        if (listings.isEmpty() && !allListings.isEmpty()) {
            showEmptyState();
        } else {
            if (binding != null && binding.emptyLayout != null) {
                binding.emptyLayout.setVisibility(View.GONE);
            }
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
    
    /** Rooms from {@code incoming} whose ids are not already on screen. */
    private List<Listing> withoutDuplicates(List<Listing> incoming) {
        java.util.Set<String> seen = new java.util.HashSet<>();
        for (Listing existing : allListings) {
            if (existing != null && existing.getId() != null) {
                seen.add(existing.getId());
            }
        }
        List<Listing> fresh = new ArrayList<>();
        if (incoming != null) {
            for (Listing candidate : incoming) {
                if (candidate != null && candidate.getId() != null && seen.add(candidate.getId())) {
                    fresh.add(candidate);
                }
            }
        }
        return fresh;
    }

    private void loadListings() {
        // Hide error states immediately
        binding.errorLayout.setVisibility(View.GONE);
        binding.emptyLayout.setVisibility(View.GONE);
        
        // Placeholder cards rather than a spinner: the page keeps its shape and
        // the filter chips stay put, so it does not look like it is rebuilding
        // itself every time it loads.
        if (allListings.isEmpty()) {
            adapter.setLoading(true);
            adapter.submit();
        }
        
        Log.d(TAG, "🔄 [DEBUG] Starting progressive loadListings()");
        Log.d(TAG, "🔄 [DEBUG] Current allListings.size() = " + allListings.size());
        
        supabaseService.getAllListingsProgressively(new SupabaseService.ProgressiveLoadingCallback() {
            @Override
            public void onInitialLoad(List<Listing> newListings) {
                Log.d(TAG, "📱 [DEBUG] Initial load: clearing and showing " + (newListings != null ? newListings.size() : 0) + " listings");
                
                if (newListings == null) {
                    Log.e(TAG, "❌ [DEBUG] Initial listings is NULL!");
                    showError("Received null data from server");
                    return;
                }
                
                // Clear and set initial content
                allListings.clear();
                allListings.addAll(newListings);
                
                // Hide progress bar after first batch
                if (binding != null && binding.progressBar != null) {
                    binding.progressBar.setVisibility(View.GONE);
                }
                if (binding != null && binding.swipeRefresh != null) {
                    binding.swipeRefresh.setRefreshing(false);
                }
                
                // Apply filters and update UI
                applyFilters();
                
                if (listings.isEmpty()) {
                    showEmptyState();
                } else {
                    Log.d(TAG, "✅ [DEBUG] Initial load complete: showing " + listings.size() + " listings");
                }
            }
            
            @Override
            public void onMoreLoaded(List<Listing> moreListings) {
                Log.d(TAG, "➕ [DEBUG] More content loaded: adding " + (moreListings != null ? moreListings.size() : 0) + " listings");
                
                if (moreListings == null || moreListings.isEmpty()) {
                    Log.d(TAG, "⚠️ [DEBUG] No more listings to add");
                    return;
                }
                
                // Append only rooms we do not already hold. The progressive
                // loader asks for "the first 5", then "more from 5", then "more
                // from 20", and the web API answers every one of those with the
                // whole set - so a straight addAll showed 18 rooms when the API
                // only has 15, and the same room appeared twice in All rooms.
                allListings.addAll(withoutDuplicates(moreListings));

                // Apply progressive filters (no sorting - preserves append order)
                applyFiltersProgressive();

                // Rebuild the feed rather than announcing an insert.
                //
                // This used to call notifyItemRangeInserted(previousFilteredSize,
                // newFilteredItems) - counted in *listings*. The adapter is not
                // indexed by listing: a row is a header, a shelf, a card or the
                // summary, and arriving rooms can add a whole shelf, move the
                // "All rooms" header and push the summary down. Telling
                // RecyclerView that N items appeared at a listing index was a
                // lie about the structure, its bookkeeping stopped matching
                // getItemCount(), and the next layout died with "Inconsistency
                // detected. Invalid view holder adapter position". It killed the
                // app on launch on a tablet-sized screen, where enough rows are
                // attached to hit it every time.
                //
                // Only the adapter knows how listings map to rows, so let it
                // work that out. The cost is the insert animation on the second
                // batch, which nobody sees anyway - it lands within a second of
                // the first.
                if (adapter != null) {
                    adapter.submit();
                }
            }
            
            @Override
            public void onSuccess(List<Listing> listings) {
                // This shouldn't be called in progressive loading, but handle it as initial load
                onInitialLoad(listings);
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "❌ [DEBUG] Progressive loading error: " + error);
                // Hide progress bar
                if (binding != null && binding.progressBar != null) {
                    binding.progressBar.setVisibility(View.GONE);
                }
                if (binding != null && binding.swipeRefresh != null) {
                    binding.swipeRefresh.setRefreshing(false);
                }
                showError("Error loading listings: " + error);
            }
        });
    }
    
    private void showError(String message) {
        if (binding != null && binding.errorLayout != null) {
            binding.errorLayout.setVisibility(View.VISIBLE);
        }
        if (binding != null && binding.errorText != null) {
            binding.errorText.setText(message);
        }
        if (binding != null && binding.retryButton != null) {
            binding.retryButton.setOnClickListener(v -> loadListings());
        }
    }
    
    private void showEmptyState() {
        if (binding != null && binding.emptyLayout != null) {
            binding.emptyLayout.setVisibility(View.VISIBLE);
        }
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
        // This used to flip the heart locally and leave a TODO where the save
        // should have been, so Saved rooms could never fill up. The heart now
        // follows what the server stored, not the tap.
        AuthManager authManager = AuthManager.getInstance(requireContext());
        if (!authManager.isUserAuthenticated()) {
            // Gate at the action, not at the tab: browsing stays open, saving
            // needs somewhere to save it to.
            Toast.makeText(requireContext(), "Sign in to save rooms", Toast.LENGTH_SHORT).show();
            startActivity(new Intent(requireContext(),
                    com.roomfinder.android.activities.LoginActivity.class));
            return;
        }

        com.roomfinder.android.network.FavoritesService.get().toggle(
                authManager.getUserEmail(), listing,
                new com.roomfinder.android.network.FavoritesService.ChangeCallback() {
                    @Override
                    public void onDone(boolean isFavoriteNow) {
                        if (!isAdded()) {
                            return;
                        }
                        listing.setFavorite(isFavoriteNow);
                        adapter.submit();
                        Toast.makeText(requireContext(),
                                isFavoriteNow ? "Saved" : "Removed from saved",
                                Toast.LENGTH_SHORT).show();
                    }

                    @Override
                    public void onError(String message) {
                        if (!isAdded()) {
                            return;
                        }
                        Toast.makeText(requireContext(), message, Toast.LENGTH_SHORT).show();
                    }
                });
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