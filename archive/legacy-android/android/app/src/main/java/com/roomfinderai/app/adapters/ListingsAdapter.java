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
import com.google.android.material.card.MaterialCardView;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.roomfinderai.app.R;
import com.roomfinderai.app.models.Listing;
import java.text.NumberFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.TimeUnit;

public class ListingsAdapter extends RecyclerView.Adapter<ListingsAdapter.ListingViewHolder> {

    private List<Listing> listings;
    private Context context;
    private NumberFormat currencyFormat;

    public ListingsAdapter(List<Listing> listings, Context context) {
        this.listings = listings;
        this.context = context;
        this.currencyFormat = NumberFormat.getCurrencyInstance(Locale.US);
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
        
        // Set price
        holder.price.setText(currencyFormat.format(listing.getPrice()) + "/month");
        
        // Set title
        holder.title.setText(listing.getTitle());
        
        // Set location
        String location = listing.getLocation() != null ? listing.getLocation() : 
                         (listing.getAddress() != null ? listing.getAddress() : "Location not specified");
        holder.location.setText(location);
        
        // Set property type
        String propertyType = listing.getPropertyType() != null ? listing.getPropertyType() : "Property";
        holder.propertyType.setText(propertyType);
        
        // Set bedrooms
        holder.bedrooms.setText(listing.getBedrooms() + " Bed" + (listing.getBedrooms() != 1 ? "s" : ""));
        
        // Set bathrooms
        holder.bathrooms.setText(listing.getBathrooms() + " Bath" + (listing.getBathrooms() != 1 ? "s" : ""));
        
        // For now, we'll hide area since it's not in the model
        holder.area.setVisibility(View.GONE);
        
        // Set posted date
        String postedText = getRelativeTimeSpan(listing.getCreatedAt());
        holder.postedDate.setText(postedText);
        
        // Load image using Glide
        if (listing.getImageUrl() != null && !listing.getImageUrl().isEmpty()) {
            Glide.with(context)
                    .load(listing.getImageUrl())
                    .centerCrop()
                    .placeholder(R.drawable.placeholder_image)
                    .error(R.drawable.placeholder_image)
                    .into(holder.propertyImage);
        } else {
            holder.propertyImage.setImageResource(R.drawable.placeholder_image);
        }
    }

    @Override
    public int getItemCount() {
        return listings != null ? listings.size() : 0;
    }
    
    private String getRelativeTimeSpan(String dateString) {
        if (dateString == null || dateString.isEmpty()) {
            return "Recently posted";
        }
        
        try {
            SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US);
            Date date = sdf.parse(dateString);
            long time = date.getTime();
            long now = System.currentTimeMillis();
            long diff = now - time;
            
            if (diff < TimeUnit.MINUTES.toMillis(1)) {
                return "Just now";
            } else if (diff < TimeUnit.HOURS.toMillis(1)) {
                long minutes = TimeUnit.MILLISECONDS.toMinutes(diff);
                return "Posted " + minutes + " minute" + (minutes != 1 ? "s" : "") + " ago";
            } else if (diff < TimeUnit.DAYS.toMillis(1)) {
                long hours = TimeUnit.MILLISECONDS.toHours(diff);
                return "Posted " + hours + " hour" + (hours != 1 ? "s" : "") + " ago";
            } else if (diff < TimeUnit.DAYS.toMillis(7)) {
                long days = TimeUnit.MILLISECONDS.toDays(diff);
                return "Posted " + days + " day" + (days != 1 ? "s" : "") + " ago";
            } else {
                SimpleDateFormat outputFormat = new SimpleDateFormat("MMM d, yyyy", Locale.US);
                return "Posted on " + outputFormat.format(date);
            }
        } catch (ParseException e) {
            return "Recently posted";
        }
    }
    
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