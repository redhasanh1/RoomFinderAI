package com.roomfinder.android.models;

public class HousingOption {
    private String title;
    private String description;
    private String priceRange;
    private String distanceFromCampus;
    private int iconResource;
    private String category; // "dorm", "apartment", "shared_house"
    private boolean isAvailable;
    private int imageResource;

    public HousingOption() {
        // Default constructor for Firebase/Supabase
    }

    public HousingOption(String title, String description, String priceRange, 
                        String distanceFromCampus, int iconResource, String category) {
        this.title = title;
        this.description = description;
        this.priceRange = priceRange;
        this.distanceFromCampus = distanceFromCampus;
        this.iconResource = iconResource;
        this.category = category;
        this.isAvailable = true;
    }

    // Getters
    public String getTitle() {
        return title;
    }

    public String getDescription() {
        return description;
    }

    public String getPriceRange() {
        return priceRange;
    }

    public String getDistanceFromCampus() {
        return distanceFromCampus;
    }

    public int getIconResource() {
        return iconResource;
    }

    public String getCategory() {
        return category;
    }

    public boolean isAvailable() {
        return isAvailable;
    }

    public int getImageResource() {
        return imageResource;
    }

    // Setters
    public void setTitle(String title) {
        this.title = title;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public void setPriceRange(String priceRange) {
        this.priceRange = priceRange;
    }

    public void setDistanceFromCampus(String distanceFromCampus) {
        this.distanceFromCampus = distanceFromCampus;
    }

    public void setIconResource(int iconResource) {
        this.iconResource = iconResource;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public void setAvailable(boolean available) {
        isAvailable = available;
    }

    public void setImageResource(int imageResource) {
        this.imageResource = imageResource;
    }
}