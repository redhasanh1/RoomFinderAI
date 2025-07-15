package com.roomfinderai.app.adapters;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import com.google.android.material.card.MaterialCardView;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.roomfinderai.app.R;
import java.util.List;

public class ListingsAdapter extends RecyclerView.Adapter<ListingsAdapter.ListingViewHolder> {

    private List<Object> listings;
    private Context context;

    public ListingsAdapter(List<Object> listings, Context context) {
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
        // Bind data to views
        holder.price.setText("$1,500/month");
        holder.title.setText("Beautiful Downtown Apartment");
        holder.location.setText("Downtown, Toronto");
        holder.propertyType.setText("Apartment");
        holder.bedrooms.setText("2 Beds");
        holder.bathrooms.setText("1 Bath");
        holder.area.setText("850 sqft");
        holder.postedDate.setText("Posted 2 hours ago");
    }

    @Override
    public int getItemCount() {
        return listings.size() > 0 ? listings.size() : 10; // Show 10 demo items
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