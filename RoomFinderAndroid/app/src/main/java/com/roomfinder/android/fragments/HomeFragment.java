package com.roomfinder.android.fragments;

import android.os.Bundle;
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
import com.roomfinder.android.models.ApiResponse;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.network.ApiClient;
import com.roomfinder.android.network.ApiService;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;
import java.util.ArrayList;
import java.util.List;

public class HomeFragment extends Fragment implements ListingsAdapter.OnListingClickListener {
    
    private FragmentHomeBinding binding;
    private ListingsAdapter adapter;
    private List<Listing> listings = new ArrayList<>();
    private ApiService apiService;
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentHomeBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        apiService = ApiClient.getInstance().getApiService();
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
        
        apiService.getListings().enqueue(new Callback<ApiResponse<List<Listing>>>() {
            @Override
            public void onResponse(Call<ApiResponse<List<Listing>>> call, Response<ApiResponse<List<Listing>>> response) {
                binding.progressBar.setVisibility(View.GONE);
                binding.swipeRefresh.setRefreshing(false);
                
                if (response.isSuccessful() && response.body() != null && response.body().isSuccess()) {
                    listings.clear();
                    List<Listing> newListings = response.body().getData();
                    if (newListings != null) {
                        listings.addAll(newListings);
                    }
                    adapter.notifyDataSetChanged();
                    
                    if (listings.isEmpty()) {
                        showEmptyState();
                    }
                } else {
                    showError("Failed to load listings");
                }
            }
            
            @Override
            public void onFailure(Call<ApiResponse<List<Listing>>> call, Throwable t) {
                binding.progressBar.setVisibility(View.GONE);
                binding.swipeRefresh.setRefreshing(false);
                showError("Network error: " + t.getMessage());
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