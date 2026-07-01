package com.roomfinder.android.adapters;

import android.view.LayoutInflater;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import com.bumptech.glide.Glide;
import com.bumptech.glide.load.engine.DiskCacheStrategy;
import com.roomfinder.android.R;
import com.roomfinder.android.databinding.ItemImageCarouselBinding;
import java.util.List;

public class ImageCarouselAdapter extends RecyclerView.Adapter<ImageCarouselAdapter.ImageViewHolder> {
    
    private final List<String> imageUrls;
    private final OnImageClickListener listener;
    
    public interface OnImageClickListener {
        void onImageClick(int position);
    }
    
    public ImageCarouselAdapter(List<String> imageUrls, OnImageClickListener listener) {
        this.imageUrls = imageUrls;
        this.listener = listener;
    }
    
    @NonNull
    @Override
    public ImageViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        ItemImageCarouselBinding binding = ItemImageCarouselBinding.inflate(
            LayoutInflater.from(parent.getContext()), parent, false
        );
        return new ImageViewHolder(binding);
    }
    
    @Override
    public void onBindViewHolder(@NonNull ImageViewHolder holder, int position) {
        holder.bind(imageUrls.get(position), position);
    }
    
    @Override
    public int getItemCount() {
        return imageUrls.size();
    }
    
    class ImageViewHolder extends RecyclerView.ViewHolder {
        private final ItemImageCarouselBinding binding;
        
        ImageViewHolder(ItemImageCarouselBinding binding) {
            super(binding.getRoot());
            this.binding = binding;
        }
        
        void bind(String imageUrl, int position) {
            // Load image with error handling
            if (imageUrl != null && !imageUrl.trim().isEmpty()) {
                Glide.with(binding.imageView.getContext())
                    .load(imageUrl)
                    .placeholder(R.drawable.property_placeholder)
                    .error(R.drawable.property_placeholder)
                    .centerCrop()
                    .diskCacheStrategy(DiskCacheStrategy.ALL)
                    .into(binding.imageView);
            } else {
                // Show placeholder for empty URL
                binding.imageView.setImageResource(R.drawable.property_placeholder);
            }
            
            // Set click listener
            binding.imageView.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onImageClick(position);
                }
            });
            
            // Add scale animation on touch
            binding.imageView.setOnTouchListener((v, event) -> {
                switch (event.getAction()) {
                    case android.view.MotionEvent.ACTION_DOWN:
                        v.animate().scaleX(0.95f).scaleY(0.95f).setDuration(100).start();
                        break;
                    case android.view.MotionEvent.ACTION_UP:
                    case android.view.MotionEvent.ACTION_CANCEL:
                        v.animate().scaleX(1f).scaleY(1f).setDuration(100).start();
                        break;
                }
                return false; // Allow click event to be processed
            });
        }
    }
}