package com.roomfinderai.app.adapters;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import com.bumptech.glide.Glide;
import com.bumptech.glide.load.engine.DiskCacheStrategy;
import com.bumptech.glide.request.RequestOptions;
import com.google.android.material.card.MaterialCardView;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.roomfinderai.app.R;
import com.roomfinderai.app.models.Listing;
import com.roomfinderai.app.models.MediaItem;
import java.util.List;
import java.util.Locale;

public class ListingsAdapter extends RecyclerView.Adapter<ListingsAdapter.ListingViewHolder> {

    private List<Listing> listings;
    private Context context;

    public ListingsAdapter(List<Listing> listings, Context context) {
        this.listings = listings;
        this.context = context;
    }

    @NonNull
    @Override
    public ListingViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_listing_card, parent, false);
        return new ListingViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull ListingViewHolder holder, int position) {
        Listing listing = listings.get(position);
        
        // Bind actual listing data to views
        holder.price.setText(String.format(Locale.US, "$%.0f/month", listing.getPrice()));
        holder.title.setText(listing.getTitle() != null ? listing.getTitle() : "No title");
        holder.location.setText(listing.getLocation() != null ? listing.getLocation() : "Location not specified");
        
        // Property type
        String propertyType = listing.getPropertyType();
        if (propertyType == null || propertyType.isEmpty()) {
            propertyType = "Property";
        }
        holder.propertyType.setText(propertyType);
        
        // Bedrooms and bathrooms
        holder.bedrooms.setText(listing.getBedrooms() + " Beds");
        holder.bathrooms.setText(String.format(Locale.US, "%.1f Bath", listing.getBathrooms()));
        
        // Area - this would need to be added to the Listing model
        holder.area.setText("N/A sqft");
        
        // Posted date - use created_at if available
        String postedDate = "Recently posted";
        if (listing.getCreatedAt() != null) {
            // In a real app, you'd format this date properly
            postedDate = "Posted recently";
        }
        holder.postedDate.setText(postedDate);
        
        // Load property image from Supabase media bucket (matching website implementation)
        loadPropertyImage(holder.propertyImage, listing);
        
        // Handle favorite button click
        holder.favoriteButton.setOnClickListener(v -> {
            // TODO: Implement favorite functionality
        });
    }
    
    /**
     * Load property image from Supabase media bucket (matches website implementation)
     * Uses Glide for efficient loading, caching, and error handling
     */
    private void loadPropertyImage(ImageView imageView, Listing listing) {
        String imageUrl = null;
        
        // Get first available image from media array
        if (listing.getMedia() != null && !listing.getMedia().isEmpty()) {
            for (MediaItem mediaItem : listing.getMedia()) {
                if (mediaItem != null && mediaItem.isImage() && mediaItem.hasValidUrl()) {
                    imageUrl = mediaItem.getPublicUrl(); // Uses proper Supabase URL construction
                    break;
                }
            }
        }
        
        // Configure Glide with performance optimizations (matching website)
        RequestOptions options = new RequestOptions()
                .centerCrop()
                .diskCacheStrategy(DiskCacheStrategy.ALL) // Cache both original & resized
                .placeholder(R.drawable.ic_home) // Placeholder while loading
                .error(R.drawable.ic_home) // Fallback for broken images
                .override(400, 300); // Resize to reasonable size for performance
        
        if (imageUrl != null && !imageUrl.isEmpty()) {
            // Load image from Supabase storage
            Glide.with(imageView.getContext())
                    .load(imageUrl)
                    .apply(options)
                    .into(imageView);
        } else {
            // No valid image available, show placeholder
            Glide.with(imageView.getContext())
                    .load(R.drawable.ic_home)
                    .apply(options)
                    .into(imageView);
        }
    }

    @Override
    public int getItemCount() {
        return listings.size();
    }

    static class ListingViewHolder extends RecyclerView.ViewHolder {
        MaterialCardView cardView;
        ImageView propertyImage;
        FloatingActionButton favoriteButton;
        TextView price, title, location, propertyType;
        TextView bedrooms, bathrooms, area, postedDate;

        ListingViewHolder(@NonNull View itemView) {
            super(itemView);
            cardView = (MaterialCardView) itemView;
            propertyImage = itemView.findViewById(R.id.propertyImage);
            favoriteButton = itemView.findViewById(R.id.favoriteButton);
            price = itemView.findViewById(R.id.price);
            title = itemView.findViewById(R.id.title);
            location = itemView.findViewById(R.id.location);
            propertyType = itemView.findViewById(R.id.propertyType);
            bedrooms = itemView.findViewById(R.id.bedrooms);
            bathrooms = itemView.findViewById(R.id.bathrooms);
            area = itemView.findViewById(R.id.area);
            postedDate = itemView.findViewById(R.id.postedDate);
        }
    }
}