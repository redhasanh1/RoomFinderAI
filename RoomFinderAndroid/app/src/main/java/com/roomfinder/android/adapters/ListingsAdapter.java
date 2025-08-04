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
            String imageUrl = listing.getFirstImageUrl();
            if (imageUrl != null && !imageUrl.isEmpty()) {
                Glide.with(binding.listingImage.getContext())
                    .load(imageUrl)
                    .placeholder(R.drawable.property_placeholder)
                    .error(R.drawable.property_placeholder)
                    .centerCrop()
                    .into(binding.listingImage);
            } else {
                binding.listingImage.setImageResource(R.drawable.property_placeholder);
            }
            
            // Set text data
            binding.titleText.setText(listing.getTitle());
            binding.locationText.setText(listing.getLocation());
            binding.priceText.setText(String.format(Locale.US, "$%.0f/mo", listing.getPrice()));
            
            // Update to include house type and utilities if available
            String detailsText = String.format(Locale.US, "%d bed • %d bath", 
                listing.getBedrooms(), listing.getBathrooms());
            if (listing.getHouseType() != null && !listing.getHouseType().isEmpty()) {
                detailsText += " • " + listing.getHouseType();
            }
            binding.bedBathText.setText(detailsText);
            
            // Set favorite state (selected state will trigger the selector)
            binding.favoriteButton.setSelected(listing.isFavorite());
            
            // Set availability status
            binding.availableStatus.setText("Available Now");
            
            // Set property type badge
            String propertyType = listing.getHouseType();
            if (propertyType != null && !propertyType.isEmpty()) {
                binding.propertyTypeBadge.setText(propertyType);
                binding.propertyTypeBadge.setVisibility(View.VISIBLE);
            } else {
                binding.propertyTypeBadge.setText("Property");
                binding.propertyTypeBadge.setVisibility(View.VISIBLE);
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