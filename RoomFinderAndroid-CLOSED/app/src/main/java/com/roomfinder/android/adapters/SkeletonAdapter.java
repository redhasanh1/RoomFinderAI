package com.roomfinder.android.adapters;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import com.roomfinder.android.R;

public class SkeletonAdapter extends RecyclerView.Adapter<SkeletonAdapter.SkeletonViewHolder> {
    
    private final int itemCount;
    
    public SkeletonAdapter(int itemCount) {
        this.itemCount = itemCount;
    }
    
    @NonNull
    @Override
    public SkeletonViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_listing_skeleton, parent, false);
        return new SkeletonViewHolder(view);
    }
    
    @Override
    public void onBindViewHolder(@NonNull SkeletonViewHolder holder, int position) {
        // Start shimmer animation
        holder.startShimmerAnimation();
    }
    
    @Override
    public int getItemCount() {
        return itemCount;
    }
    
    public static class SkeletonViewHolder extends RecyclerView.ViewHolder {
        
        public SkeletonViewHolder(@NonNull View itemView) {
            super(itemView);
        }
        
        public void startShimmerAnimation() {
            // For now, just show static skeleton (no animation to avoid build issues)
            // TODO: Add shimmer animation later
        }
    }
}