package com.roomfinder.android.fragments;

import android.content.Intent;
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
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import com.roomfinder.android.R;
import com.roomfinder.android.activities.IndividualChatActivity;
import com.roomfinder.android.activities.ListingDetailActivity;
import com.roomfinder.android.activities.LoginActivity;
import com.roomfinder.android.adapters.ListingsAdapter;
import com.roomfinder.android.auth.AuthManager;
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

        // An empty state that says "start browsing" with no way to browse is a
        // dead end, and this screen is reached from Profile, not from a tab.
        binding.browseRoomsButton.setOnClickListener(v -> {
            if (getActivity() instanceof com.roomfinder.android.MainActivity) {
                ((com.roomfinder.android.MainActivity) getActivity())
                        .navigateToTab(R.id.navigation_home);
            }
        });
        
        com.roomfinder.android.utils.Insets.padTopForStatusBar(binding.screenTitle);

        prefs = requireContext().getSharedPreferences("roomfinder_prefs", Context.MODE_PRIVATE);
        setupRecyclerView();
        loadFavorites();
    }
    
    private void setupRecyclerView() {
        adapter = new ListingsAdapter(favoriteListings, this);
        binding.recyclerView.setLayoutManager(new GridLayoutManager(requireContext(), 2));
        binding.recyclerView.setAdapter(adapter);
    }
    
    /**
     * Loads the saved rooms from the server.
     *
     * This used to read a SharedPreferences key, "favorite_listings", that no
     * code anywhere ever wrote to - the heart buttons both carried a
     * "TODO: Save to local storage" instead. So this screen was guaranteed to
     * be empty for everyone, forever. Favourites live on the account now, which
     * also means they match what the website shows.
     */
    private void loadFavorites() {
        AuthManager authManager = AuthManager.getInstance(requireContext());
        if (!authManager.isUserAuthenticated()) {
            showEmpty("Sign in to see the rooms you've saved");
            return;
        }

        com.roomfinder.android.network.FavoritesService.get().loadFavorites(
                authManager.getUserEmail(),
                new com.roomfinder.android.network.FavoritesService.ListCallback() {
                    @Override
                    public void onLoaded(List<Listing> favorites) {
                        if (binding == null) {
                            return;
                        }
                        favoriteListings.clear();
                        favoriteListings.addAll(favorites);
                        adapter.notifyDataSetChanged();
                        if (favoriteListings.isEmpty()) {
                            showEmpty(null);
                        } else {
                            binding.emptyLayout.setVisibility(View.GONE);
                        }
                    }

                    @Override
                    public void onError(String message) {
                        if (binding == null) {
                            return;
                        }
                        // Say what went wrong rather than showing an empty
                        // shelf, which reads as "you have saved nothing".
                        showEmpty(message);
                    }
                });
    }

    private void showEmpty(String message) {
        if (binding == null) {
            return;
        }
        binding.emptyLayout.setVisibility(View.VISIBLE);
        if (message != null && binding.emptyTitle != null) {
            binding.emptyTitle.setText(message);
        }
    }
    
    @Override
    public void onListingClick(Listing listing) {
        Intent intent = new Intent(requireContext(), ListingDetailActivity.class);
        intent.putExtra("listing", listing);
        startActivity(intent);
    }
    
    @Override
    public void onFavoriteClick(Listing listing, int position) {
        AuthManager authManager = AuthManager.getInstance(requireContext());
        if (!authManager.isUserAuthenticated()) {
            return;
        }
        // Remove on the server first; only drop the row once it is really gone,
        // otherwise it reappears on the next visit and looks like a bug.
        com.roomfinder.android.network.FavoritesService.get().toggle(
                authManager.getUserEmail(), listing,
                new com.roomfinder.android.network.FavoritesService.ChangeCallback() {
                    @Override
                    public void onDone(boolean isFavoriteNow) {
                        if (binding == null || isFavoriteNow) {
                            return;
                        }
                        int index = favoriteListings.indexOf(listing);
                        if (index >= 0) {
                            favoriteListings.remove(index);
                            adapter.notifyItemRemoved(index);
                        }
                        if (favoriteListings.isEmpty()) {
                            showEmpty(null);
                        }
                    }

                    @Override
                    public void onError(String message) {
                        if (binding != null) {
                            android.widget.Toast.makeText(requireContext(), message,
                                    android.widget.Toast.LENGTH_SHORT).show();
                        }
                    }
                });
    }
    
    @Override
    public void onChatClick(Listing listing) {
        AuthManager authManager = AuthManager.getInstance(requireContext());
        
        if (authManager.isUserAuthenticated()) {
            String currentUserEmail = authManager.getUserEmail();
            
            Intent intent = new Intent(requireContext(), IndividualChatActivity.class);
            intent.putExtra("listing_id", listing.getId());
            intent.putExtra("listing_title", listing.getTitle());
            intent.putExtra("owner_email", listing.getUserEmail());
            intent.putExtra("current_user_email", currentUserEmail);
            startActivity(intent);
        } else {
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