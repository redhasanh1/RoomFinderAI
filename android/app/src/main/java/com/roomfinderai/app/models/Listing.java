package com.roomfinderai.app.models;

import com.google.gson.annotations.SerializedName;
import java.util.ArrayList;
import java.util.List;

public class Listing {
    @SerializedName("id")
    private String id;
    
    @SerializedName("title")
    private String title;
    
    @SerializedName("description")
    private String description;
    
    @SerializedName("price")
    private double price;
    
    @SerializedName("location")
    private String location;
    
    @SerializedName("bedrooms")
    private int bedrooms;
    
    @SerializedName("bathrooms")
    private double bathrooms;
    
    @SerializedName("media")
    private List<MediaItem> media;
    
    @SerializedName("user_id")
    private String userId;
    
    @SerializedName("created_at")
    private String createdAt;
    
    @SerializedName("updated_at")
    private String updatedAt;
    
    @SerializedName("house_type")
    private String houseType;
    
    @SerializedName("utilities")
    private String utilities;
    
    @SerializedName("city")
    private String city;
    
    @SerializedName("postalCode")
    private String postalCode;
    
    @SerializedName("street")
    private String street;
    
    @SerializedName("country")
    private String country;
    
    @SerializedName("user_email")
    private String userEmail;

    // Default constructor
    public Listing() {}

    // Constructor
    public Listing(String title, String description, double price, String location, 
                   int bedrooms, double bathrooms, List<MediaItem> media) {
        this.title = title;
        this.description = description;
        this.price = price;
        this.location = location;
        this.bedrooms = bedrooms;
        this.bathrooms = bathrooms;
        this.media = media;
    }

    // Getters and Setters
    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public double getPrice() { return price; }
    public void setPrice(double price) { this.price = price; }

    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }

    public int getBedrooms() { return bedrooms; }
    public void setBedrooms(int bedrooms) { this.bedrooms = bedrooms; }

    public double getBathrooms() { return bathrooms; }
    public void setBathrooms(double bathrooms) { this.bathrooms = bathrooms; }

    public List<MediaItem> getMedia() { return media; }
    public void setMedia(List<MediaItem> media) { this.media = media; }
    
    // Legacy methods for compatibility - extract URLs from MediaItems
    public List<String> getImages() { 
        if (media == null) return new ArrayList<>();
        List<String> urls = new ArrayList<>();
        for (MediaItem item : media) {
            if (item != null && item.hasValidUrl()) {
                urls.add(item.getUrl());
            }
        }
        return urls;
    }
    
    public void setImages(List<String> imageUrls) { 
        if (imageUrls == null) {
            this.media = new ArrayList<>();
            return;
        }
        this.media = new ArrayList<>();
        for (String url : imageUrls) {
            if (url != null && !url.isEmpty()) {
                this.media.add(new MediaItem("image", "image/jpeg", url));
            }
        }
    }
    
    // Helper method to get the first image URL for display
    public String getFirstImageUrl() {
        if (media != null && !media.isEmpty()) {
            MediaItem firstItem = media.get(0);
            if (firstItem != null && firstItem.hasValidUrl()) {
                return firstItem.getUrl();
            }
        }
        return null;
    }

    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    public String getCreatedAt() { return createdAt; }
    public void setCreatedAt(String createdAt) { this.createdAt = createdAt; }

    public String getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(String updatedAt) { this.updatedAt = updatedAt; }

    public String getHouseType() { return houseType; }
    public void setHouseType(String houseType) { this.houseType = houseType; }
    
    // Legacy method for compatibility
    public String getPropertyType() { return houseType; }
    public void setPropertyType(String propertyType) { this.houseType = propertyType; }

    public String getUtilities() { return utilities; }
    public void setUtilities(String utilities) { this.utilities = utilities; }

    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }

    public String getPostalCode() { return postalCode; }
    public void setPostalCode(String postalCode) { this.postalCode = postalCode; }

    public String getStreet() { return street; }
    public void setStreet(String street) { this.street = street; }

    public String getCountry() { return country; }
    public void setCountry(String country) { this.country = country; }

    public String getUserEmail() { return userEmail; }
    public void setUserEmail(String userEmail) { this.userEmail = userEmail; }
}