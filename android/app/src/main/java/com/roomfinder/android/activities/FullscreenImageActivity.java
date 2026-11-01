package com.roomfinder.android.activities;

import android.content.Intent;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.view.animation.AccelerateDecelerateInterpolator;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.viewpager2.widget.ViewPager2;
import com.roomfinder.android.R;
import com.roomfinder.android.adapters.FullscreenImageAdapter;
import com.roomfinder.android.databinding.ActivityFullscreenImageBinding;
import java.util.ArrayList;
import java.util.List;

public class FullscreenImageActivity extends AppCompatActivity {
    
    private static final String TAG = "FullscreenImageActivity";
    public static final String EXTRA_IMAGE_URLS = "image_urls";
    public static final String EXTRA_CURRENT_POSITION = "current_position";
    public static final String EXTRA_PROPERTY_TITLE = "property_title";
    
    private ActivityFullscreenImageBinding binding;
    private FullscreenImageAdapter imageAdapter;
    private List<String> imageUrls;
    private int currentPosition = 0;
    private boolean isControlsVisible = true;
    private Handler hideControlsHandler;
    private Runnable hideControlsRunnable;
    private GestureDetector gestureDetector;
    
    // Static method to start this activity
    public static void start(AppCompatActivity context, List<String> imageUrls, int position, String propertyTitle) {
        Intent intent = new Intent(context, FullscreenImageActivity.class);
        intent.putStringArrayListExtra(EXTRA_IMAGE_URLS, new ArrayList<>(imageUrls));
        intent.putExtra(EXTRA_CURRENT_POSITION, position);
        intent.putExtra(EXTRA_PROPERTY_TITLE, propertyTitle);
        context.startActivity(intent);
        // Custom transition
        context.overridePendingTransition(R.anim.fade_in, R.anim.fade_out);
    }
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        binding = ActivityFullscreenImageBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        
        // Get intent data
        getIntentData();
        
        if (imageUrls == null || imageUrls.isEmpty()) {
            finish();
            return;
        }
        
        // Setup fullscreen immersive mode AFTER setContentView
        setupImmersiveMode();
        
        setupUI();
        setupImageViewer();
        setupGestureDetection();
        setupAutoHideControls();
        
        // Start with controls visible
        showControls();
    }
    
    private void setupImmersiveMode() {
        try {
            // Enable edge-to-edge
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+
                getWindow().setDecorFitsSystemWindows(false);
                WindowInsetsController insetsController = getWindow().getInsetsController();
                if (insetsController != null) {
                    insetsController.hide(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars());
                    insetsController.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
                }
            } else {
                // Android 10 and below
                View decorView = getWindow().getDecorView();
                if (decorView != null) {
                    decorView.setSystemUiVisibility(
                        View.SYSTEM_UI_FLAG_FULLSCREEN |
                        View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
                        View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY |
                        View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
                        View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION |
                        View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    );
                }
            }
            
            // Set window flags for optimal fullscreen experience
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            getWindow().setStatusBarColor(Color.TRANSPARENT);
            getWindow().setNavigationBarColor(Color.TRANSPARENT);
        } catch (Exception e) {
            // Fallback to basic fullscreen if immersive mode fails
            try {
                getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
                getWindow().setStatusBarColor(Color.TRANSPARENT);
                getWindow().setNavigationBarColor(Color.TRANSPARENT);
            } catch (Exception fallbackException) {
                // If all else fails, just continue without immersive mode
            }
        }
    }
    
    private void getIntentData() {
        try {
            Intent intent = getIntent();
            if (intent != null) {
                imageUrls = intent.getStringArrayListExtra(EXTRA_IMAGE_URLS);
                currentPosition = intent.getIntExtra(EXTRA_CURRENT_POSITION, 0);
                String propertyTitle = intent.getStringExtra(EXTRA_PROPERTY_TITLE);
                
                // Validate imageUrls
                if (imageUrls == null) {
                    imageUrls = new ArrayList<>();
                }
                
                // Remove any null or empty URLs
                imageUrls.removeIf(url -> url == null || url.trim().isEmpty());
                
                // Ensure valid position
                if (currentPosition >= imageUrls.size() || currentPosition < 0) {
                    currentPosition = 0;
                }
                
                // Set toolbar title if provided
                if (propertyTitle != null && !propertyTitle.trim().isEmpty()) {
                    binding.toolbarTitle.setText(propertyTitle);
                } else {
                    binding.toolbarTitle.setText("Property Photos");
                }
            } else {
                // No intent data - should not happen, but handle gracefully
                imageUrls = new ArrayList<>();
                currentPosition = 0;
                binding.toolbarTitle.setText("Property Photos");
            }
        } catch (Exception e) {
            // Safety fallback
            imageUrls = new ArrayList<>();
            currentPosition = 0;
            if (binding != null && binding.toolbarTitle != null) {
                binding.toolbarTitle.setText("Property Photos");
            }
        }
    }
    
    private void setupUI() {
        // Handle window insets for edge-to-edge
        ViewCompat.setOnApplyWindowInsetsListener(binding.getRoot(), (v, insets) -> {
            int topInset = insets.getInsets(WindowInsetsCompat.Type.statusBars()).top;
            int bottomInset = insets.getInsets(WindowInsetsCompat.Type.navigationBars()).bottom;
            
            // Apply top margin to toolbar
            ViewGroup.MarginLayoutParams toolbarParams = (ViewGroup.MarginLayoutParams) binding.toolbar.getLayoutParams();
            toolbarParams.topMargin = topInset;
            
            // Apply bottom margin to page indicator
            ViewGroup.MarginLayoutParams indicatorParams = (ViewGroup.MarginLayoutParams) binding.pageIndicator.getLayoutParams();
            indicatorParams.bottomMargin = bottomInset + 32; // 32dp base margin
            
            return insets;
        });
        
        // Setup toolbar
        binding.backButton.setOnClickListener(v -> finish());
        binding.shareButton.setOnClickListener(v -> shareCurrentImage());
        
        // Update image counter
        updateImageCounter();
    }
    
    private void setupImageViewer() {
        try {
            // Create adapter
            imageAdapter = new FullscreenImageAdapter(imageUrls, new FullscreenImageAdapter.OnImageInteractionListener() {
                @Override
                public void onImageSingleTap() {
                    toggleControls();
                }
                
                @Override
                public void onImageLongPress() {
                    // Could add options menu here
                }
                
                @Override
                public void onSwipeToExit(float translationY) {
                    // Handle swipe-to-dismiss
                    if (Math.abs(translationY) > 200) {
                        finish();
                    } else {
                        // Reset position
                        if (binding != null && binding.imageViewPager != null) {
                            binding.imageViewPager.animate()
                                    .translationY(0f)
                                    .setDuration(200)
                                    .start();
                        }
                    }
                }
            });
            
            if (binding != null && binding.imageViewPager != null) {
                binding.imageViewPager.setAdapter(imageAdapter);
                
                // Set current position
                if (currentPosition < imageUrls.size() && currentPosition >= 0) {
                    binding.imageViewPager.setCurrentItem(currentPosition, false);
                }
                
                // Setup page change listener
                binding.imageViewPager.registerOnPageChangeCallback(new ViewPager2.OnPageChangeCallback() {
                    @Override
                    public void onPageSelected(int position) {
                        currentPosition = position;
                        updateImageCounter();
                        resetAutoHideTimer();
                    }
                });
                
                // Smooth page transformations
                binding.imageViewPager.setPageTransformer((page, position) -> {
                    // Subtle fade effect during transitions
                    page.setAlpha(1f - Math.abs(position) * 0.3f);
                });
            }
        } catch (Exception e) {
            // If setup fails, just finish the activity
            finish();
        }
    }
    
    private void setupGestureDetection() {
        gestureDetector = new GestureDetector(this, new GestureDetector.SimpleOnGestureListener() {
            @Override
            public boolean onSingleTapConfirmed(MotionEvent e) {
                toggleControls();
                return true;
            }
            
            @Override
            public boolean onDoubleTap(MotionEvent e) {
                // Let the PhotoView handle double-tap zoom
                return false;
            }
        });
        
        binding.getRoot().setOnTouchListener((v, event) -> {
            gestureDetector.onTouchEvent(event);
            return false; // Allow other touch events to be processed
        });
    }
    
    private void setupAutoHideControls() {
        hideControlsHandler = new Handler(Looper.getMainLooper());
        hideControlsRunnable = this::hideControls;
    }
    
    private void updateImageCounter() {
        if (imageUrls != null && imageUrls.size() > 1) {
            binding.imageCounter.setText(String.format("%d / %d", currentPosition + 1, imageUrls.size()));
            binding.imageCounter.setVisibility(View.VISIBLE);
        } else {
            binding.imageCounter.setVisibility(View.GONE);
        }
    }
    
    private void toggleControls() {
        if (isControlsVisible) {
            hideControls();
        } else {
            showControls();
        }
    }
    
    private void showControls() {
        if (!isControlsVisible) {
            isControlsVisible = true;
            
            // Animate toolbar in
            binding.toolbar.setVisibility(View.VISIBLE);
            binding.toolbar.setAlpha(0f);
            binding.toolbar.setTranslationY(-binding.toolbar.getHeight());
            binding.toolbar.animate()
                    .alpha(1f)
                    .translationY(0f)
                    .setDuration(300)
                    .setInterpolator(new AccelerateDecelerateInterpolator())
                    .start();
            
            // Animate page indicator in
            binding.pageIndicator.setVisibility(View.VISIBLE);
            binding.pageIndicator.setAlpha(0f);
            binding.pageIndicator.setTranslationY(100f);
            binding.pageIndicator.animate()
                    .alpha(1f)
                    .translationY(0f)
                    .setDuration(300)
                    .setInterpolator(new AccelerateDecelerateInterpolator())
                    .start();
        }
        
        resetAutoHideTimer();
    }
    
    private void hideControls() {
        if (isControlsVisible) {
            isControlsVisible = false;
            
            // Animate toolbar out
            binding.toolbar.animate()
                    .alpha(0f)
                    .translationY(-binding.toolbar.getHeight())
                    .setDuration(300)
                    .setInterpolator(new AccelerateDecelerateInterpolator())
                    .withEndAction(() -> binding.toolbar.setVisibility(View.GONE))
                    .start();
            
            // Animate page indicator out
            binding.pageIndicator.animate()
                    .alpha(0f)
                    .translationY(100f)
                    .setDuration(300)
                    .setInterpolator(new AccelerateDecelerateInterpolator())
                    .withEndAction(() -> binding.pageIndicator.setVisibility(View.GONE))
                    .start();
        }
        
        // Cancel auto-hide timer
        hideControlsHandler.removeCallbacks(hideControlsRunnable);
    }
    
    private void resetAutoHideTimer() {
        hideControlsHandler.removeCallbacks(hideControlsRunnable);
        hideControlsHandler.postDelayed(hideControlsRunnable, 3000); // Hide after 3 seconds
    }
    
    private void shareCurrentImage() {
        if (imageUrls != null && currentPosition < imageUrls.size()) {
            String currentImageUrl = imageUrls.get(currentPosition);
            
            Intent shareIntent = new Intent(Intent.ACTION_SEND);
            shareIntent.setType("text/plain");
            shareIntent.putExtra(Intent.EXTRA_TEXT, 
                "Check out this property photo: " + currentImageUrl + "\n\nShared from RoomFinder");
            
            startActivity(Intent.createChooser(shareIntent, "Share Photo"));
        }
    }
    
    @Override
    public void onBackPressed() {
        // Smooth exit animation
        binding.getRoot().animate()
                .alpha(0f)
                .setDuration(200)
                .withEndAction(() -> {
                    super.onBackPressed();
                    overridePendingTransition(R.anim.fade_in, R.anim.fade_out);
                })
                .start();
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        resetAutoHideTimer();
    }
    
    @Override
    protected void onPause() {
        super.onPause();
        hideControlsHandler.removeCallbacks(hideControlsRunnable);
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (hideControlsHandler != null) {
            hideControlsHandler.removeCallbacks(hideControlsRunnable);
        }
    }
}