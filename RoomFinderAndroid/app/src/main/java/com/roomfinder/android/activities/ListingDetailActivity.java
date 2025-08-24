package com.roomfinder.android.activities;

import android.animation.ObjectAnimator;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.text.method.LinkMovementMethod;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.PagerSnapHelper;
import androidx.recyclerview.widget.RecyclerView;
import androidx.viewpager2.widget.ViewPager2;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.android.material.tabs.TabLayoutMediator;
import com.roomfinder.android.R;
import com.roomfinder.android.adapters.ImageCarouselAdapter;
import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.databinding.ActivityListingDetailBinding;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.network.SupabaseService;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class ListingDetailActivity extends AppCompatActivity {
    
    private static final String TAG = "ListingDetailActivity";
    private static final String EXTRA_LISTING_ID = "listing_id";
    private static final String EXTRA_LISTING = "listing";
    
    private ActivityListingDetailBinding binding;
    private Listing listing;
    private ImageCarouselAdapter imageAdapter;
    private boolean isDescriptionExpanded = false;
    private boolean isFavorite = false;
    
    // Static method to start this activity
    public static void start(AppCompatActivity context, Listing listing) {
        Intent intent = new Intent(context, ListingDetailActivity.class);
        intent.putExtra(EXTRA_LISTING, listing);
        context.startActivity(intent);
    }
    
    public static void startWithId(AppCompatActivity context, String listingId) {
        Intent intent = new Intent(context, ListingDetailActivity.class);
        intent.putExtra(EXTRA_LISTING_ID, listingId);
        context.startActivity(intent);
    }
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Setup edge-to-edge display
        getWindow().setStatusBarColor(Color.TRANSPARENT);
        getWindow().setNavigationBarColor(Color.TRANSPARENT);
        
        binding = ActivityListingDetailBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        
        // Handle window insets for edge-to-edge - simplified version
        // ViewCompat.setOnApplyWindowInsetsListener(binding.getRoot(), (v, insets) -> {
        //     int topInset = insets.getInsets(WindowInsetsCompat.Type.statusBars()).top;
        //     return insets;
        // });
        
        // Get listing data from intent
        getListingData();
        
        if (listing == null) {
            Toast.makeText(this, "Error loading listing", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }
        
        setupUI();
        setupImageCarousel();
        setupClickListeners();
        populateData();
        
        // Add entrance animation
        animateEnter();
    }
    
    private void getListingData() {
        Intent intent = getIntent();
        
        // Try to get listing object first
        if (intent.hasExtra(EXTRA_LISTING)) {
            listing = (Listing) intent.getSerializableExtra(EXTRA_LISTING);
        }
        // Fallback: load by ID (you could implement this to fetch from API)
        else if (intent.hasExtra(EXTRA_LISTING_ID)) {
            String listingId = intent.getStringExtra(EXTRA_LISTING_ID);
            // TODO: Implement loading listing by ID from SupabaseService
            Toast.makeText(this, "Loading listing by ID not yet implemented", Toast.LENGTH_SHORT).show();
            finish();
        }
    }
    
    private void setupUI() {
        // Setup back button navigation
        binding.backButton.setOnClickListener(v -> onBackPressed());
        
        // Simplified - removed complex scroll behavior
    }
    
    private void setupImageCarousel() {
        // Setup image carousel
        List<String> imageUrlsForDisplay = getImageUrlsForDisplay();
        imageAdapter = new ImageCarouselAdapter(imageUrlsForDisplay, new ImageCarouselAdapter.OnImageClickListener() {
            @Override
            public void onImageClick(int position) {
                // Open fullscreen image viewer
                openImageViewer(position);
            }
        });
        
        binding.imageViewPager.setAdapter(imageAdapter);
        
        // Setup page indicator
        if (imageUrlsForDisplay.size() > 1) {
            binding.pageIndicator.setVisibility(View.VISIBLE);
            new TabLayoutMediator(binding.pageIndicator, binding.imageViewPager,
                    (tab, position) -> {
                        // Tab configuration - dots only, no text needed
                    }
            ).attach();
        } else {
            binding.pageIndicator.setVisibility(View.GONE);
        }
        
        // Add image counter
        updateImageCounter(0, imageUrlsForDisplay.size());
        binding.imageViewPager.registerOnPageChangeCallback(new ViewPager2.OnPageChangeCallback() {
            @Override
            public void onPageSelected(int position) {
                updateImageCounter(position, imageUrlsForDisplay.size());
            }
        });
    }
    
    private List<String> getImageUrls() {
        List<String> urls = new ArrayList<>();
        
        if (listing.getMedia() != null && !listing.getMedia().isEmpty()) {
            for (Listing.MediaFile media : listing.getMedia()) {
                if (media.getType() != null && media.getType().startsWith("image/") && 
                    media.getUrl() != null && !media.getUrl().trim().isEmpty()) {
                    urls.add(media.getUrl());
                }
            }
        }
        
        return urls;
    }
    
    private List<String> getImageUrlsForDisplay() {
        List<String> urls = getImageUrls();
        
        // Add placeholder if no real images
        if (urls.isEmpty()) {
            urls.add(""); // Empty URL will trigger placeholder in adapter
        }
        
        return urls;
    }
    
    private void updateImageCounter(int current, int total) {
        if (total > 1) {
            binding.imageCounter.setVisibility(View.VISIBLE);
            binding.imageCounter.setText(String.format(Locale.US, "%d / %d", current + 1, total));
        } else {
            binding.imageCounter.setVisibility(View.GONE);
        }
    }
    
    private void setupClickListeners() {
        // Favorite button
        binding.favoriteButton.setOnClickListener(v -> toggleFavorite());
        
        // Share button
        binding.shareButton.setOnClickListener(v -> shareListing());
        
        // Call button
        binding.callButton.setOnClickListener(v -> callOwner());
        
        // Message button
        binding.messageButton.setOnClickListener(v -> messageOwner());
        
        // Chat button
        binding.chatButton.setOnClickListener(v -> openChat());
        
        // Description expand/collapse
        binding.descriptionContainer.setOnClickListener(v -> toggleDescription());
        
        // Location card click
        binding.locationCard.setOnClickListener(v -> openMaps());
    }
    
    private void populateData() {
        // Basic info
        binding.titleText.setText(listing.getTitle());
        binding.priceText.setText(String.format(Locale.US, "$%.0f", listing.getPrice()));
        // binding.priceSubtext.setText("per month"); // Removed for simplified layout
        
        // Location
        binding.locationText.setText(listing.getLocation());
        binding.addressText.setText(listing.getStreet() + ", " + listing.getCity());
        if (listing.getPostalCode() != null) {
            binding.postalCodeText.setText(listing.getPostalCode());
            binding.postalCodeText.setVisibility(View.VISIBLE);
        } else {
            binding.postalCodeText.setVisibility(View.GONE);
        }
        
        // Property details
        binding.bedroomCount.setText(String.valueOf(listing.getBedrooms()));
        binding.bathroomCount.setText(String.valueOf(listing.getBathrooms()));
        binding.propertyType.setText(listing.getHouseType() != null ? listing.getHouseType() : "Property");
        
        // Utilities
        if (listing.getUtilities() != null && !listing.getUtilities().trim().isEmpty()) {
            binding.utilitiesText.setText(listing.getUtilities());
            binding.utilitiesCard.setVisibility(View.VISIBLE);
        } else {
            binding.utilitiesCard.setVisibility(View.GONE);
        }
        
        // Description
        if (listing.getDescription() != null && !listing.getDescription().trim().isEmpty()) {
            binding.descriptionText.setText(listing.getDescription());
            binding.descriptionContainer.setVisibility(View.VISIBLE);
            
            // Check if description is long enough to need expanding
            if (listing.getDescription().length() > 200) {
                binding.descriptionText.setMaxLines(3);
                // binding.expandIcon.setVisibility(View.VISIBLE); // Removed for simplified layout
            } else {
                // binding.expandIcon.setVisibility(View.GONE); // Removed for simplified layout
            }
        } else {
            binding.descriptionContainer.setVisibility(View.GONE);
        }
        
        // Contact info
        if (listing.getUserEmail() != null) {
            String ownerName = extractNameFromEmail(listing.getUserEmail());
            binding.ownerNameText.setText(ownerName);
            binding.ownerEmailText.setText(listing.getUserEmail());
        }
        
        // Set initial favorite state
        isFavorite = listing.isFavorite();
        updateFavoriteButton();
    }
    
    private String extractNameFromEmail(String email) {
        if (email == null) return "Property Owner";
        
        int atIndex = email.indexOf('@');
        if (atIndex > 0) {
            String name = email.substring(0, atIndex);
            // Capitalize first letter
            return name.substring(0, 1).toUpperCase() + name.substring(1);
        }
        return "Property Owner";
    }
    
    private void toggleFavorite() {
        isFavorite = !isFavorite;
        listing.setFavorite(isFavorite);
        
        // Animate button
        ObjectAnimator scaleX = ObjectAnimator.ofFloat(binding.favoriteButton, "scaleX", 1f, 1.3f, 1f);
        ObjectAnimator scaleY = ObjectAnimator.ofFloat(binding.favoriteButton, "scaleY", 1f, 1.3f, 1f);
        scaleX.setDuration(300);
        scaleY.setDuration(300);
        scaleX.setInterpolator(new AccelerateDecelerateInterpolator());
        scaleY.setInterpolator(new AccelerateDecelerateInterpolator());
        
        scaleX.start();
        scaleY.start();
        
        updateFavoriteButton();
        
        // TODO: Save to local storage/preferences
        String message = isFavorite ? "Added to favorites" : "Removed from favorites";
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }
    
    private void updateFavoriteButton() {
        binding.favoriteButton.setSelected(isFavorite);
    }
    
    private void toggleDescription() {
        isDescriptionExpanded = !isDescriptionExpanded;
        
        if (isDescriptionExpanded) {
            binding.descriptionText.setMaxLines(Integer.MAX_VALUE);
            // binding.expandIcon.animate().rotation(180f).setDuration(200).start(); // Removed for simplified layout
        } else {
            binding.descriptionText.setMaxLines(3);
            // binding.expandIcon.animate().rotation(0f).setDuration(200).start(); // Removed for simplified layout
        }
    }
    
    private void shareListing() {
        Intent shareIntent = new Intent(Intent.ACTION_SEND);
        shareIntent.setType("text/plain");
        shareIntent.putExtra(Intent.EXTRA_SUBJECT, listing.getTitle());
        shareIntent.putExtra(Intent.EXTRA_TEXT, 
            String.format("Check out this property: %s\n\n$%.0f/month\n%s\n\nShared from RoomFinder", 
                listing.getTitle(), listing.getPrice(), listing.getLocation()));
        
        startActivity(Intent.createChooser(shareIntent, "Share Property"));
    }
    
    private void callOwner() {
        // Since we don't have phone number in the model, show email instead
        if (listing.getUserEmail() != null) {
            new MaterialAlertDialogBuilder(this)
                .setTitle("Contact Owner")
                .setMessage("Phone number not available. Would you like to send an email instead?")
                .setPositiveButton("Send Email", (dialog, which) -> emailOwner())
                .setNegativeButton("Chat", (dialog, which) -> openChat())
                .setNeutralButton("Cancel", null)
                .show();
        } else {
            Toast.makeText(this, "Contact information not available", Toast.LENGTH_SHORT).show();
        }
    }
    
    private void messageOwner() {
        // Show options dialog
        String[] options = {"Send Email", "Open Chat", "SMS (if available)"};
        
        new MaterialAlertDialogBuilder(this)
                .setTitle("Contact " + extractNameFromEmail(listing.getUserEmail()))
                .setItems(options, (dialog, which) -> {
                    switch (which) {
                        case 0:
                            emailOwner();
                            break;
                        case 1:
                            openChat();
                            break;
                        case 2:
                            // SMS would require phone number
                            Toast.makeText(this, "SMS requires phone number (not available)", Toast.LENGTH_SHORT).show();
                            break;
                    }
                })
                .setNegativeButton("Cancel", null)
                .show();
    }
    
    private void emailOwner() {
        if (listing.getUserEmail() != null) {
            Intent emailIntent = new Intent(Intent.ACTION_SENDTO);
            emailIntent.setData(Uri.parse("mailto:" + listing.getUserEmail()));
            emailIntent.putExtra(Intent.EXTRA_SUBJECT, "Inquiry about: " + listing.getTitle());
            emailIntent.putExtra(Intent.EXTRA_TEXT, 
                String.format("Hi,\n\nI'm interested in your property listing:\n%s\n$%.0f/month\n%s\n\nCould you please provide more information?\n\nBest regards", 
                    listing.getTitle(), listing.getPrice(), listing.getLocation()));
            
            if (emailIntent.resolveActivity(getPackageManager()) != null) {
                startActivity(emailIntent);
            } else {
                Toast.makeText(this, "No email app available", Toast.LENGTH_SHORT).show();
            }
        }
    }
    
    private void openChat() {
        AuthManager authManager = AuthManager.getInstance(this);
        
        if (authManager.isUserAuthenticated()) {
            // Start chat activity (same as in HomeFragment)
            Intent intent = new Intent(this, IndividualChatActivity.class);
            intent.putExtra("listing_id", listing.getId());
            intent.putExtra("listing_title", listing.getTitle());
            intent.putExtra("owner_email", listing.getUserEmail());
            intent.putExtra("current_user_email", authManager.getUserEmail());
            startActivity(intent);
        } else {
            // Show login required dialog
            new MaterialAlertDialogBuilder(this)
                    .setTitle("Login Required")
                    .setMessage("You need to sign in to chat with property owners.")
                    .setPositiveButton("Sign In", (dialog, which) -> {
                        Intent loginIntent = new Intent(this, LoginActivity.class);
                        startActivity(loginIntent);
                    })
                    .setNegativeButton("Cancel", null)
                    .setIcon(R.drawable.ic_chat)
                    .show();
        }
    }
    
    private void openMaps() {
        String address = listing.getLocation();
        Uri gmmIntentUri = Uri.parse("geo:0,0?q=" + Uri.encode(address));
        Intent mapIntent = new Intent(Intent.ACTION_VIEW, gmmIntentUri);
        mapIntent.setPackage("com.google.android.apps.maps");
        
        if (mapIntent.resolveActivity(getPackageManager()) != null) {
            startActivity(mapIntent);
        } else {
            // Fallback to browser
            Uri webUri = Uri.parse("https://www.google.com/maps/search/" + Uri.encode(address));
            Intent webIntent = new Intent(Intent.ACTION_VIEW, webUri);
            if (webIntent.resolveActivity(getPackageManager()) != null) {
                startActivity(webIntent);
            } else {
                Toast.makeText(this, "No map app available", Toast.LENGTH_SHORT).show();
            }
        }
    }
    
    private void openImageViewer(int position) {
        List<String> realImageUrls = getImageUrls();
        if (!realImageUrls.isEmpty()) {
            // Use the real images for fullscreen viewer
            FullscreenImageActivity.start(this, realImageUrls, position, listing.getTitle());
        } else {
            // No real images available, just show a message
            Toast.makeText(this, "No high-resolution images available", Toast.LENGTH_SHORT).show();
        }
    }
    
    private void animateEnter() {
        // Simplified animation - removed complex content container animation
        // binding.contentContainer.setAlpha(0f);
        // binding.contentContainer.setTranslationY(100f);
        
        // binding.contentContainer.animate()
        //         .alpha(1f)
        //         .translationY(0f)
        //         .setDuration(500)
        //         .setInterpolator(new AccelerateDecelerateInterpolator())
        //         .start();
        
        // Stagger animation for FABs
        binding.chatButton.setScaleX(0f);
        binding.chatButton.setScaleY(0f);
        binding.chatButton.animate()
                .scaleX(1f)
                .scaleY(1f)
                .setDuration(400)
                .setStartDelay(300)
                .setInterpolator(new AccelerateDecelerateInterpolator())
                .start();
                
        binding.messageButton.setScaleX(0f);
        binding.messageButton.setScaleY(0f);
        binding.messageButton.animate()
                .scaleX(1f)
                .scaleY(1f)
                .setDuration(400)
                .setStartDelay(400)
                .setInterpolator(new AccelerateDecelerateInterpolator())
                .start();
                
        binding.callButton.setScaleX(0f);
        binding.callButton.setScaleY(0f);
        binding.callButton.animate()
                .scaleX(1f)
                .scaleY(1f)
                .setDuration(400)
                .setStartDelay(500)
                .setInterpolator(new AccelerateDecelerateInterpolator())
                .start();
    }
    
    @Override
    public void onBackPressed() {
        // Simplified exit - removed complex animation
        super.onBackPressed();
        overridePendingTransition(0, 0); // No transition
    }
}