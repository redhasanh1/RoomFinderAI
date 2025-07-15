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
import com.bumptech.glide.Priority;
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
        // Enable stable IDs for better RecyclerView performance
        setHasStableIds(true);
    }
    
    @Override
    public long getItemId(int position) {
        // Use listing ID as stable ID for better recycling
        Listing listing = listings.get(position);
        return listing.getId() != null ? listing.getId().hashCode() : position;
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
        
        // Clear any pending Glide requests for this ImageView to prevent loading wrong images
        Glide.with(holder.propertyImage.getContext()).clear(holder.propertyImage);
        
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
        
        // Bedrooms (bathrooms not available in current database schema)
        holder.bedrooms.setText(listing.getBedrooms() + " Beds");
        holder.bathrooms.setText("N/A Bath"); // Bathrooms field not in database
        
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
     * Load property image from Supabase media bucket with optimized performance
     * Uses Glide for efficient loading, caching, and error handling
     */
    private void loadPropertyImage(ImageView imageView, Listing listing) {
        // Clear any previous image to prevent flickering during recycling
        imageView.setImageDrawable(null);
        
        String imageUrl = null;
        
        // Get first available image from media array (optimized search)
        if (listing.getMedia() != null && !listing.getMedia().isEmpty()) {
            MediaItem firstMedia = listing.getMedia().get(0); // Just get first item for performance
            if (firstMedia != null && firstMedia.isImage() && firstMedia.hasValidUrl()) {
                imageUrl = firstMedia.getPublicUrl();
            }
        }
        
        // Configure Glide with RecyclerView optimizations
        RequestOptions options = new RequestOptions()
                .centerCrop()
                .diskCacheStrategy(DiskCacheStrategy.AUTOMATIC) // Let Glide decide optimal caching
                .placeholder(R.drawable.ic_home) // Placeholder while loading
                .error(R.drawable.ic_home) // Fallback for broken images
                .override(150, 100) // Even smaller for better performance
                .skipMemoryCache(false) // Use memory cache
                .priority(Priority.NORMAL) // Normal priority for better balance
                .dontTransform(); // Skip unnecessary transformations
        
        if (imageUrl != null && !imageUrl.isEmpty()) {
            // Load image with proper error handling
            Glide.with(imageView.getContext())
                    .load(imageUrl)
                    .apply(options)
                    .thumbnail(0.25f) // Larger thumbnail for better UX
                    .into(imageView);
        } else {
            // No valid image available, show placeholder immediately
            imageView.setImageResource(R.drawable.ic_home);
        }
    }

    @Override
    public int getItemCount() {
        return listings.size();
    }
    
    /**
     * Update listings data efficiently
     */
    public void updateListings(List<Listing> newListings) {
        this.listings = newListings;
        notifyDataSetChanged();
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