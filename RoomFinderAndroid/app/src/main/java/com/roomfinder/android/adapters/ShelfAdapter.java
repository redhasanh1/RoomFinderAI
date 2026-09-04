package com.roomfinder.android.adapters;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.bumptech.glide.Glide;
import com.roomfinder.android.R;
import com.roomfinder.android.models.Listing;

import java.util.List;

/**
 * The rooms inside one horizontal shelf. Mirrors the iOS ShelfCard: a narrower,
 * photo-led card so a room can still be judged at a glance.
 */
public class ShelfAdapter extends RecyclerView.Adapter<ShelfAdapter.ShelfHolder> {

    private final List<Listing> listings;
    private final ListingsAdapter.OnListingClickListener listener;

    public ShelfAdapter(List<Listing> listings, ListingsAdapter.OnListingClickListener listener) {
        this.listings = listings;
        this.listener = listener;
    }

    @NonNull
    @Override
    public ShelfHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_listing_shelf, parent, false);
        return new ShelfHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull ShelfHolder holder, int position) {
        holder.bind(listings.get(position));
    }

    @Override
    public int getItemCount() {
        return listings == null ? 0 : listings.size();
    }

    class ShelfHolder extends RecyclerView.ViewHolder {
        private final ImageView image;
        private final ImageView verified;
        private final TextView title;
        private final TextView location;
        private final TextView price;

        ShelfHolder(@NonNull View itemView) {
            super(itemView);
            image = itemView.findViewById(R.id.shelfImage);
            verified = itemView.findViewById(R.id.shelfVerified);
            title = itemView.findViewById(R.id.shelfTitle);
            location = itemView.findViewById(R.id.shelfLocation);
            price = itemView.findViewById(R.id.shelfPrice);
        }

        void bind(Listing listing) {
            title.setText(listing.getTitle());
            location.setText(listing.getLocation());
            price.setText(listing.getPriceText());
            verified.setVisibility(listing.isUserVerified() ? View.VISIBLE : View.GONE);

            String url = listing.getFirstImageUrl();
            if (url != null && !url.isEmpty()) {
                Glide.with(image.getContext())
                        .load(url)
                        .placeholder(R.drawable.placeholder_image)
                        .error(R.drawable.placeholder_image)
                        .centerCrop()
                        .override(520, 320)
                        .into(image);
            } else {
                image.setImageResource(R.drawable.placeholder_image);
            }

            itemView.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onListingClick(listing);
                }
            });
        }
    }
}
