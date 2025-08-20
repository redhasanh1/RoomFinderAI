package com.roomfinder.android.adapters;

import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import com.bumptech.glide.Glide;
import com.bumptech.glide.load.engine.DiskCacheStrategy;
import com.bumptech.glide.load.resource.bitmap.CenterInside;
import com.bumptech.glide.load.resource.bitmap.FitCenter;
import com.github.chrisbanes.photoview.PhotoView;
import com.github.chrisbanes.photoview.OnPhotoTapListener;
import com.github.chrisbanes.photoview.OnScaleChangedListener;
import android.widget.ImageView;
import com.roomfinder.android.R;
import com.roomfinder.android.databinding.ItemFullscreenImageBinding;
import java.util.List;

public class FullscreenImageAdapter extends RecyclerView.Adapter<FullscreenImageAdapter.ImageViewHolder> {
    
    private final List<String> imageUrls;
    private final OnImageInteractionListener listener;
    
    public interface OnImageInteractionListener {
        void onImageSingleTap();
        void onImageLongPress();
        void onSwipeToExit(float translationY);
    }
    
    public FullscreenImageAdapter(List<String> imageUrls, OnImageInteractionListener listener) {
        this.imageUrls = imageUrls;
        this.listener = listener;
    }
    
    @NonNull
    @Override
    public ImageViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        ItemFullscreenImageBinding binding = ItemFullscreenImageBinding.inflate(
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
        private final ItemFullscreenImageBinding binding;
        private boolean isDragging = false;
        private float initialY = 0f;
        
        ImageViewHolder(ItemFullscreenImageBinding binding) {
            super(binding.getRoot());
            this.binding = binding;
        }
        
        void bind(String imageUrl, int position) {
            // Configure PhotoView for zoom and pan
            binding.photoView.setZoomable(true);
            binding.photoView.setMaximumScale(5.0f);
            binding.photoView.setMediumScale(2.0f);
            binding.photoView.setMinimumScale(1.0f);
            
            // Load image with Glide
            if (imageUrl != null && !imageUrl.trim().isEmpty()) {
                // Show loading indicator
                binding.loadingIndicator.setVisibility(View.VISIBLE);
                
                Glide.with(binding.photoView.getContext())
                    .load(imageUrl)
                    .placeholder(R.drawable.property_placeholder)
                    .error(R.drawable.property_placeholder)
                    .diskCacheStrategy(DiskCacheStrategy.ALL)
                    .fitCenter()
                    .into(binding.photoView);
                
                // Hide loading when image is ready
                binding.photoView.setOnMatrixChangeListener(rect -> {
                    binding.loadingIndicator.setVisibility(View.GONE);
                });
            } else {
                // Show placeholder for empty URL
                binding.loadingIndicator.setVisibility(View.GONE);
                binding.photoView.setImageResource(R.drawable.property_placeholder);
            }
            
            // Setup gesture listeners
            setupGestureListeners();
        }
        
        private void setupGestureListeners() {
            // Photo tap listener (single tap to toggle controls)
            binding.photoView.setOnPhotoTapListener(new OnPhotoTapListener() {
                @Override
                public void onPhotoTap(ImageView view, float x, float y) {
                    if (listener != null) {
                        listener.onImageSingleTap();
                    }
                }
            });
            
            // Long press listener
            binding.photoView.setOnLongClickListener(v -> {
                if (listener != null) {
                    listener.onImageLongPress();
                }
                return true;
            });
            
            // Scale change listener to reset swipe-to-dismiss when zoomed
            binding.photoView.setOnScaleChangeListener(new OnScaleChangedListener() {
                @Override
                public void onScaleChange(float scaleFactor, float focusX, float focusY) {
                    // Disable swipe-to-dismiss when zoomed in
                    isDragging = binding.photoView.getScale() <= 1.0f;
                }
            });
            
            // Custom touch listener for swipe-to-dismiss
            binding.photoView.setOnTouchListener(new View.OnTouchListener() {
                private float startY = 0f;
                private float startX = 0f;
                private boolean isVerticalSwipe = false;
                
                @Override
                public boolean onTouch(View v, MotionEvent event) {
                    // Only handle swipe-to-dismiss when not zoomed
                    if (binding.photoView.getScale() > 1.0f) {
                        return false; // Let PhotoView handle zoomed interactions
                    }
                    
                    switch (event.getAction()) {
                        case MotionEvent.ACTION_DOWN:
                            startY = event.getRawY();
                            startX = event.getRawX();
                            isVerticalSwipe = false;
                            return false; // Let PhotoView handle the touch
                            
                        case MotionEvent.ACTION_MOVE:
                            float deltaY = event.getRawY() - startY;
                            float deltaX = event.getRawX() - startX;
                            
                            // Determine if this is a vertical swipe
                            if (!isVerticalSwipe && Math.abs(deltaY) > Math.abs(deltaX) && Math.abs(deltaY) > 50) {
                                isVerticalSwipe = true;
                                isDragging = true;
                            }
                            
                            // Handle vertical swipe-to-dismiss
                            if (isVerticalSwipe && isDragging) {
                                float translationY = deltaY * 0.7f; // Reduce sensitivity
                                binding.getRoot().setTranslationY(translationY);
                                
                                // Fade background based on swipe distance
                                float alpha = Math.max(0.3f, 1f - Math.abs(translationY) / 500f);
                                binding.getRoot().setAlpha(alpha);
                                
                                return true; // Consume the event
                            }
                            break;
                            
                        case MotionEvent.ACTION_UP:
                        case MotionEvent.ACTION_CANCEL:
                            if (isDragging && isVerticalSwipe) {
                                float finalTranslationY = binding.getRoot().getTranslationY();
                                
                                if (listener != null) {
                                    listener.onSwipeToExit(finalTranslationY);
                                }
                                
                                // Reset if not dismissing
                                if (Math.abs(finalTranslationY) <= 200) {
                                    binding.getRoot().animate()
                                            .translationY(0f)
                                            .alpha(1f)
                                            .setDuration(200)
                                            .start();
                                }
                                
                                isDragging = false;
                                isVerticalSwipe = false;
                                return true;
                            }
                            break;
                    }
                    
                    return false; // Let PhotoView handle other gestures
                }
            });
        }
    }
}