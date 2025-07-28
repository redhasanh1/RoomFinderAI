package com.roomfinder.android.fragments;

import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
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
    private SupabaseService supabaseService;
    
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
                
                listings.clear();
                listings.addAll(newListings);
                adapter.notifyDataSetChanged();
                
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