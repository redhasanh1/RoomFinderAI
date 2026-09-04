package com.roomfinder.android.fragments;

import android.content.Intent;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;

import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.roomfinder.android.R;
import com.roomfinder.android.activities.ListingDetailActivity;
import com.roomfinder.android.adapters.ListingsAdapter;
import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.databinding.FragmentFavoritesBinding;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.network.SupabaseService;

import java.util.ArrayList;
import java.util.List;

/**
 * The rooms this account has posted, with a way to take them down.
 *
 * Profile > "Manage my listings" used to raise a "My Listings - Coming Soon"
 * toast. That is a bad gap for a marketplace: someone who posts a room and then
 * rents it out has no way to remove it from the app, so the listing keeps
 * collecting messages about a room that is gone. The website has had this the
 * whole time - profile.html lists your posts with a Delete on each - and
 * DELETE /api/listings/:id already exists and checks ownership.
 *
 * It reuses the favourites layout and the listings adapter deliberately: this
 * is the same thing, a list of rooms, and giving it its own bespoke screen
 * would add a third card style to learn for no benefit.
 */
public class MyListingsFragment extends Fragment implements ListingsAdapter.OnListingClickListener {

    private FragmentFavoritesBinding binding;
    private ListingsAdapter adapter;
    private final List<Listing> myListings = new ArrayList<>();

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentFavoritesBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        binding.screenTitle.setText("My listings");
        // The empty state is inherited from Saved rooms, so its heart icon and
        // "tap the heart" line have to be re-pointed - otherwise this screen
        // tells people to favourite something in order to see their own posts.
        binding.emptyIcon.setImageResource(R.drawable.ic_home);
        binding.emptySubtitle.setText("Rooms you post show up here, and you can take them down from here too");
        com.roomfinder.android.utils.Insets.padTopForStatusBar(binding.screenTitle);
        binding.browseRoomsButton.setText("Post a room");
        binding.browseRoomsButton.setOnClickListener(v -> {
            if (getActivity() instanceof com.roomfinder.android.MainActivity) {
                ((com.roomfinder.android.MainActivity) getActivity())
                        .navigateToTab(R.id.navigation_post);
            }
        });

        adapter = new ListingsAdapter(myListings, this);
        binding.recyclerView.setLayoutManager(new LinearLayoutManager(requireContext()));
        binding.recyclerView.setAdapter(adapter);

        loadMyListings();
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }

    private void loadMyListings() {
        AuthManager authManager = AuthManager.getInstance(requireContext());
        if (!authManager.isUserAuthenticated()) {
            showEmpty("Sign in to see the rooms you've posted");
            return;
        }
        final String email = authManager.getUserEmail();

        SupabaseService.getInstance().getAllListings(new SupabaseService.ListingsCallback() {
            @Override
            public void onSuccess(List<Listing> listings) {
                if (binding == null) {
                    return;
                }
                myListings.clear();
                for (Listing listing : listings) {
                    if (email != null && email.equalsIgnoreCase(listing.getUserEmail())) {
                        myListings.add(listing);
                    }
                }
                adapter.notifyDataSetChanged();
                if (myListings.isEmpty()) {
                    showEmpty("You haven't posted a room yet");
                } else {
                    binding.emptyLayout.setVisibility(View.GONE);
                }
            }

            @Override
            public void onError(String error) {
                if (binding == null) {
                    return;
                }
                showEmpty("Couldn't load your listings. Pull to try again.");
            }
        });
    }

    private void showEmpty(String message) {
        if (binding == null) {
            return;
        }
        binding.emptyLayout.setVisibility(View.VISIBLE);
        if (binding.emptyTitle != null) {
            binding.emptyTitle.setText(message);
        }
    }

    @Override
    public void onListingClick(Listing listing) {
        Intent intent = new Intent(requireContext(), ListingDetailActivity.class);
        intent.putExtra("listing", listing);
        startActivity(intent);
    }

    /**
     * On this screen the heart slot is the way to take a listing down, because
     * favouriting your own room is meaningless and deleting it is the thing
     * people come here to do.
     */
    @Override
    public void onFavoriteClick(Listing listing, int position) {
        new MaterialAlertDialogBuilder(requireContext())
                .setTitle("Delete this listing?")
                .setMessage("\"" + listing.getTitle() + "\" will be removed from RoomFinderAI "
                        + "for everyone. This cannot be undone.")
                .setPositiveButton("Delete", (dialog, which) -> deleteListing(listing, position))
                .setNegativeButton("Keep", null)
                .show();
    }

    private void deleteListing(Listing listing, int position) {
        AuthManager authManager = AuthManager.getInstance(requireContext());
        SupabaseService.getInstance().deleteListing(
                listing.getId(), authManager.getUserEmail(),
                new SupabaseService.SimpleCallback() {
                    @Override
                    public void onSuccess() {
                        if (binding == null) {
                            return;
                        }
                        int index = myListings.indexOf(listing);
                        if (index >= 0) {
                            myListings.remove(index);
                            adapter.notifyItemRemoved(index);
                        }
                        Toast.makeText(requireContext(), "Listing deleted", Toast.LENGTH_SHORT).show();
                        if (myListings.isEmpty()) {
                            showEmpty("You haven't posted a room yet");
                        }
                    }

                    @Override
                    public void onError(String error) {
                        if (binding == null) {
                            return;
                        }
                        // Nothing is removed from the list here: the listing is
                        // still live, and hiding it would be the same lie the
                        // rest of this screen used to tell.
                        Toast.makeText(requireContext(), error, Toast.LENGTH_LONG).show();
                    }
                });
    }

    @Override
    public void onChatClick(Listing listing) {
        Toast.makeText(requireContext(), "This is your own listing", Toast.LENGTH_SHORT).show();
    }
}
