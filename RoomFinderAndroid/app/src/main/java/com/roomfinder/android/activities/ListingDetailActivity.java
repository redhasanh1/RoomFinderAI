package com.roomfinder.android.activities;

import android.animation.ObjectAnimator;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.viewpager2.widget.ViewPager2;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.android.material.tabs.TabLayoutMediator;
import com.roomfinder.android.R;
import com.roomfinder.android.adapters.ImageCarouselAdapter;
import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.databinding.ActivityListingDetailBinding;
import com.roomfinder.android.models.Listing;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class ListingDetailActivity extends AppCompatActivity {
    
    private static final String TAG = "ListingDetailActivity";
    private static final String EXTRA_LISTING_ID = "listing_id";
    private static final String EXTRA_LISTING = "listing";

    /** True while a room is being fetched for an id that arrived in a link. */
    private boolean awaitingRemoteLoad = false;
    
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

        // A link carries an id, not a room, so the fetch is still in flight
        // here. The null check below used to fire first and close the screen,
        // which is why every shared link opened and immediately disappeared.
        if (listing == null) {
            if (!awaitingRemoteLoad) {
                Toast.makeText(this, "That room could not be loaded", Toast.LENGTH_SHORT).show();
                finish();
            }
            return;
        }

        bindEverything();
    }

    /** Everything that needs a listing in hand. */
    private void bindEverything() {
        setupUI();
        setupImageCarousel();
        applyContactBarInset();
        setupClickListeners();
        populateData();
        animateEnter();
    }
    
    private void getListingData() {
        Intent intent = getIntent();
        
        // Try to get listing object first
        if (intent.hasExtra(EXTRA_LISTING)) {
            listing = (Listing) intent.getSerializableExtra(EXTRA_LISTING);
        }
        // By id: from another screen, or from a shared roomfinderai.com link.
        else {
            String listingId = intent.hasExtra(EXTRA_LISTING_ID)
                    ? intent.getStringExtra(EXTRA_LISTING_ID)
                    : listingIdFromLink(intent);
            if (listingId == null) {
                finish();
                return;
            }
            awaitingRemoteLoad = true;
            loadListingById(listingId);
        }
    }

    /** The public page for this room - the same URL the website serves. */
    private String listingUrl() {
        return "https://www.roomfinderai.com/listing_details.html?id=" + listing.getId();
    }

    /** Pulls ?id=<uuid> out of a tapped link. */
    private String listingIdFromLink(Intent intent) {
        android.net.Uri data = intent.getData();
        if (data == null) {
            return null;
        }
        String id = data.getQueryParameter("id");
        return (id == null || id.trim().isEmpty()) ? null : id.trim();
    }

    /**
     * Fetches a room that arrived as an id rather than an object. This used to
     * say "not yet implemented" and close the screen, which made every shared
     * link a dead end.
     */
    private void loadListingById(String listingId) {
        new Thread(() -> {
            Listing loaded = com.roomfinder.android.network.WebApiListingsSource
                    .getInstance().getListingById(listingId);
            runOnUiThread(() -> {
                if (loaded == null) {
                    Toast.makeText(this, "That room is no longer available", Toast.LENGTH_LONG).show();
                    finish();
                    return;
                }
                listing = loaded;
                awaitingRemoteLoad = false;
                bindEverything();
            });
        }).start();
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
        // Covers every source: cover image, the web API's imageUrls gallery, and
        // legacy media entries. Previously this read media only, so listings that
        // came from the web API showed a placeholder instead of their photos.
        if (listing == null) {
            return new ArrayList<>();
        }
        return listing.getAllImageUrls();
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
    
    /**
     * Lifts the contact bar clear of the gesture bar. Android 15 draws this
     * activity edge to edge, so without the inset "Message owner" sits on the
     * navigation handle.
     */
    private void applyContactBarInset() {
        if (binding == null || binding.contactBar == null) {
            return;
        }
        final int basePadding = binding.contactBar.getPaddingBottom();
        androidx.core.view.ViewCompat.setOnApplyWindowInsetsListener(binding.contactBar, (view, insets) -> {
            int bottom = insets.getInsets(androidx.core.view.WindowInsetsCompat.Type.systemBars()).bottom;
            view.setPadding(view.getPaddingLeft(), view.getPaddingTop(),
                    view.getPaddingRight(), basePadding + bottom);
            return insets;
        });
    }

    private void setupClickListeners() {
        // Favorite button
        binding.favoriteButton.setOnClickListener(v -> toggleFavorite());
        applyToolbarInset();

        
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
    
    /** "Posted today" / "Posted 3 days ago" from an ISO timestamp. */
    private String postedLabel(String createdAt) {
        if (createdAt == null || createdAt.length() < 10) {
            return "";
        }
        try {
            java.text.SimpleDateFormat parser =
                    new java.text.SimpleDateFormat("yyyy-MM-dd", Locale.US);
            java.util.Date posted = parser.parse(createdAt.substring(0, 10));
            if (posted == null) {
                return "";
            }
            long days = (System.currentTimeMillis() - posted.getTime()) / (24L * 60 * 60 * 1000);
            if (days <= 0) {
                return "Posted today";
            }
            if (days == 1) {
                return "Posted yesterday";
            }
            if (days < 30) {
                return "Posted " + days + " days ago";
            }
            return "Posted " + (days / 30) + (days / 30 == 1 ? " month ago" : " months ago");
        } catch (Exception e) {
            return "";
        }
    }

    /**
     * Opens the negotiator with this room already in hand, so the first message
     * is about the rent in front of you rather than a blank prompt.
     */
    private void openNegotiator() {
        Intent intent = new Intent(this, com.roomfinder.android.MainActivity.class);
        intent.putExtra("open_negotiator", true);
        intent.putExtra("negotiate_listing_title", listing.getTitle());
        intent.putExtra("negotiate_listing_price", listing.getSafePrice());
        intent.putExtra("negotiate_listing_location", listing.getLocation());
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        startActivity(intent);
    }

    private void populateData() {
        // Basic info
        binding.titleText.setText(listing.getTitle());
        binding.priceText.setText(listing.getPriceText());

        // Trust signals sit with the price: they are what decides whether
        // somebody bothers to message at all.
        binding.verifiedChip.setVisibility(listing.isUserVerified() ? View.VISIBLE : View.GONE);
        binding.postedText.setText(postedLabel(listing.getCreatedAt()));

        // The negotiator, offered against this specific room.
        binding.negotiateCard.setOnClickListener(v -> openNegotiator());
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
        
        // Prefer what the favourites cache knows over the flag that travelled
        // in the Intent, which is stale as soon as it is put there.
        com.roomfinder.android.network.FavoritesService favorites =
                com.roomfinder.android.network.FavoritesService.get();
        isFavorite = favorites.hasLoadedIds()
                ? favorites.isFavorite(listing.getId())
                : listing.isFavorite();
        listing.setFavorite(isFavorite);
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
    
    /**
     * Pushes the toolbar below the status bar.
     *
     * Measured on a 1080x2400 device: back/favourite/share occupied y=42..168
     * while the status bar owned everything above roughly y=110, so a tap
     * anywhere in the top two thirds of those buttons went to the system
     * instead of the app. The heart appeared not to work at all unless you hit
     * its bottom edge. Read the inset rather than hardcoding a height, since it
     * differs on notched and punch-hole screens.
     */
    private void applyToolbarInset() {
        View toolbar = findViewById(R.id.detailToolbar);
        if (toolbar == null) {
            return;
        }
        final int left = toolbar.getPaddingLeft();
        final int right = toolbar.getPaddingRight();
        final int bottom = toolbar.getPaddingBottom();
        final int top = toolbar.getPaddingTop();
        androidx.core.view.ViewCompat.setOnApplyWindowInsetsListener(toolbar, (view, insets) -> {
            int statusBar = insets.getInsets(
                    androidx.core.view.WindowInsetsCompat.Type.statusBars()).top;
            view.setPadding(left, top + statusBar, right, bottom);
            return insets;
        });
    }

    private void toggleFavorite() {
        // The old version flipped a local boolean, animated, toasted "Added to
        // favorites" and left a TODO where the save belonged. Nothing was ever
        // stored, so Saved rooms stayed empty. Now the server decides and the
        // heart follows it.
        com.roomfinder.android.auth.AuthManager authManager =
                com.roomfinder.android.auth.AuthManager.getInstance(this);
        if (!authManager.isUserAuthenticated()) {
            Toast.makeText(this, "Sign in to save rooms", Toast.LENGTH_SHORT).show();
            startActivity(new android.content.Intent(this,
                    com.roomfinder.android.activities.LoginActivity.class));
            return;
        }

        // Animate immediately - the tap should feel answered even though the
        // state it settles on comes from the server a moment later.
        ObjectAnimator scaleX = ObjectAnimator.ofFloat(binding.favoriteButton, "scaleX", 1f, 1.3f, 1f);
        ObjectAnimator scaleY = ObjectAnimator.ofFloat(binding.favoriteButton, "scaleY", 1f, 1.3f, 1f);
        scaleX.setDuration(300);
        scaleY.setDuration(300);
        scaleX.setInterpolator(new AccelerateDecelerateInterpolator());
        scaleY.setInterpolator(new AccelerateDecelerateInterpolator());
        scaleX.start();
        scaleY.start();

        binding.favoriteButton.setEnabled(false);
        com.roomfinder.android.network.FavoritesService.get().toggle(
                authManager.getUserEmail(), listing,
                new com.roomfinder.android.network.FavoritesService.ChangeCallback() {
                    @Override
                    public void onDone(boolean isFavoriteNow) {
                        binding.favoriteButton.setEnabled(true);
                        isFavorite = isFavoriteNow;
                        listing.setFavorite(isFavoriteNow);
                        updateFavoriteButton();
                        Toast.makeText(ListingDetailActivity.this,
                                isFavoriteNow ? "Saved" : "Removed from saved",
                                Toast.LENGTH_SHORT).show();
                    }

                    @Override
                    public void onError(String message) {
                        binding.favoriteButton.setEnabled(true);
                        // Leave the heart as it was: nothing changed on the server.
                        updateFavoriteButton();
                        Toast.makeText(ListingDetailActivity.this, message, Toast.LENGTH_SHORT).show();
                    }
                });
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
        // A share with no link is a dead end - marketplaces spread by pasted
        // URLs, and this one has a page per listing.
        shareIntent.putExtra(Intent.EXTRA_TEXT,
                listing.getTitle() + System.lineSeparator()
                        + listing.getPriceText() + "  ·  " + listing.getLocation()
                        + System.lineSeparator() + System.lineSeparator()
                        + listingUrl());

        startActivity(Intent.createChooser(shareIntent, "Share this room"));
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