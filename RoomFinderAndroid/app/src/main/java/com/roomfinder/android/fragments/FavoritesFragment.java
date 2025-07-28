package com.roomfinder.android.fragments;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import android.content.Context;
import androidx.recyclerview.widget.GridLayoutManager;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import com.roomfinder.android.adapters.ListingsAdapter;
import com.roomfinder.android.databinding.FragmentFavoritesBinding;
import com.roomfinder.android.models.Listing;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;

public class FavoritesFragment extends Fragment implements ListingsAdapter.OnListingClickListener {
    
    private FragmentFavoritesBinding binding;
    private ListingsAdapter adapter;
    private List<Listing> favoriteListings = new ArrayList<>();
    private SharedPreferences prefs;
    private Gson gson = new Gson();
    
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentFavoritesBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }
    
    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        
        prefs = requireContext().getSharedPreferences("roomfinder_prefs", Context.MODE_PRIVATE);
        setupRecyclerView();
        loadFavorites();
    }
    
    private void setupRecyclerView() {
        adapter = new ListingsAdapter(favoriteListings, this);
        binding.recyclerView.setLayoutManager(new GridLayoutManager(requireContext(), 2));
        binding.recyclerView.setAdapter(adapter);
    }
    
    private void loadFavorites() {
        String favoritesJson = prefs.getString("favorite_listings", "[]");
        Type listType = new TypeToken<List<Listing>>(){}.getType();
        List<Listing> savedFavorites = gson.fromJson(favoritesJson, listType);
        
        favoriteListings.clear();
        if (savedFavorites != null) {
            favoriteListings.addAll(savedFavorites);
        }
        
        adapter.notifyDataSetChanged();
        
        if (favoriteListings.isEmpty()) {
            binding.emptyLayout.setVisibility(View.VISIBLE);
        } else {
            binding.emptyLayout.setVisibility(View.GONE);
        }
    }
    
    private void saveFavorites() {
        String favoritesJson = gson.toJson(favoriteListings);
        prefs.edit().putString("favorite_listings", favoritesJson).apply();
    }
    
    @Override
    public void onListingClick(Listing listing) {
        // TODO: Navigate to detail
    }
    
    @Override
    public void onFavoriteClick(Listing listing, int position) {
        // Remove from favorites
        favoriteListings.remove(position);
        adapter.notifyItemRemoved(position);
        saveFavorites();
        
        if (favoriteListings.isEmpty()) {
            binding.emptyLayout.setVisibility(View.VISIBLE);
        }
    }
}