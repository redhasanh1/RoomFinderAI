package com.roomfinder.android.adapters;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import com.bumptech.glide.Glide;
import com.roomfinder.android.R;
import com.roomfinder.android.databinding.ItemListingCardBinding;
import com.roomfinder.android.models.Listing;
import java.util.List;
import java.util.Locale;

public class ListingsAdapter extends RecyclerView.Adapter<ListingsAdapter.ListingViewHolder> {
    
    private final List<Listing> listings;
    private final OnListingClickListener listener;
    
    public interface OnListingClickListener {
        void onListingClick(Listing listing);
        void onFavoriteClick(Listing listing, int position);
    }
    
    public ListingsAdapter(List<Listing> listings, OnListingClickListener listener) {
        this.listings = listings;
        this.listener = listener;
    }
    
    @NonNull
    @Override
    public ListingViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        ItemListingCardBinding binding = ItemListingCardBinding.inflate(
            LayoutInflater.from(parent.getContext()), parent, false
        );
        return new ListingViewHolder(binding);
    }
    
    @Override
    public void onBindViewHolder(@NonNull ListingViewHolder holder, int position) {
        holder.bind(listings.get(position), position);
    }
    
    @Override
    public int getItemCount() {
        return listings.size();
    }
    
    class ListingViewHolder extends RecyclerView.ViewHolder {
        private final ItemListingCardBinding binding;
        
        ListingViewHolder(ItemListingCardBinding binding) {
            super(binding.getRoot());
            this.binding = binding;
        }
        
        void bind(Listing listing, int position) {
            // Load image
            String imageUrl = listing.getFirstImage();
            if (imageUrl != null && !imageUrl.isEmpty()) {
                Glide.with(binding.listingImage.getContext())
                    .load(imageUrl)
                    .placeholder(R.drawable.placeholder_image)
                    .error(R.drawable.placeholder_image)
                    .centerCrop()
                    .into(binding.listingImage);
            } else {
                binding.listingImage.setImageResource(R.drawable.placeholder_image);
            }
            
            // Set text data
            binding.titleText.setText(listing.getTitle());
            binding.locationText.setText(listing.getLocation());
            binding.priceText.setText(String.format(Locale.US, "$%.0f/mo", listing.getPrice()));
            binding.bedBathText.setText(String.format(Locale.US, "%d bed • %d bath", 
                listing.getBedrooms(), listing.getBathrooms()));
            
            // Set favorite icon
            binding.favoriteButton.setImageResource(
                listing.isFavorite() ? R.drawable.ic_favorite_filled : R.drawable.ic_favorite_border
            );
            
            // Set availability badge
            if (listing.isAvailable()) {
                binding.availableBadge.setVisibility(View.VISIBLE);
            } else {
                binding.availableBadge.setVisibility(View.GONE);
            }
            
            // Click listeners
            binding.getRoot().setOnClickListener(v -> {
                if (listener != null) {
                    listener.onListingClick(listing);
                }
            });
            
            binding.favoriteButton.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onFavoriteClick(listing, position);
                }
            });
        }
    }
}