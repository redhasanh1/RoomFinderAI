package com.roomfinder.android.models;

import com.google.gson.annotations.SerializedName;
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
    
    @SerializedName("bedrooms")
    private int bedrooms;
    
    @SerializedName("bathrooms")
    private int bathrooms;
    
    @SerializedName("city")
    private String city;
    
    @SerializedName("street")
    private String street;
    
    @SerializedName("postalCode")
    private String postalCode;
    
    @SerializedName("house_type")
    private String houseType;
    
    @SerializedName("utilities")
    private String utilities;
    
    @SerializedName("media")
    private List<MediaFile> media;
    
    @SerializedName("created_at")
    private String createdAt;
    
    @SerializedName("user_email")
    private String userEmail;
    
    // Local field for favorites
    private boolean isFavorite;
    
    // Constructors
    public Listing() {}
    
    public Listing(String id, String title, String description, double price, int bedrooms, 
                   int bathrooms, String city, String street, String postalCode, 
                   String houseType, String utilities, List<MediaFile> media, 
                   String createdAt, String userEmail) {
        this.id = id;
        this.title = title;
        this.description = description;
        this.price = price;
        this.bedrooms = bedrooms;
        this.bathrooms = bathrooms;
        this.city = city;
        this.street = street;
        this.postalCode = postalCode;
        this.houseType = houseType;
        this.utilities = utilities;
        this.media = media;
        this.createdAt = createdAt;
        this.userEmail = userEmail;
    }
    
    // Getters and Setters
    public String getId() {
        return id;
    }
    
    public void setId(String id) {
        this.id = id;
    }
    
    public String getTitle() {
        return title;
    }
    
    public void setTitle(String title) {
        this.title = title;
    }
    
    public String getDescription() {
        return description;
    }
    
    public void setDescription(String description) {
        this.description = description;
    }
    
    public double getPrice() {
        return price;
    }
    
    public void setPrice(double price) {
        this.price = price;
    }
    
    public int getBedrooms() {
        return bedrooms;
    }
    
    public void setBedrooms(int bedrooms) {
        this.bedrooms = bedrooms;
    }
    
    public int getBathrooms() {
        return bathrooms;
    }
    
    public void setBathrooms(int bathrooms) {
        this.bathrooms = bathrooms;
    }
    
    public String getCity() {
        return city;
    }
    
    public void setCity(String city) {
        this.city = city;
    }
    
    public String getStreet() {
        return street;
    }
    
    public void setStreet(String street) {
        this.street = street;
    }
    
    public String getPostalCode() {
        return postalCode;
    }
    
    public void setPostalCode(String postalCode) {
        this.postalCode = postalCode;
    }
    
    public String getHouseType() {
        return houseType;
    }
    
    public void setHouseType(String houseType) {
        this.houseType = houseType;
    }
    
    public String getUtilities() {
        return utilities;
    }
    
    public void setUtilities(String utilities) {
        this.utilities = utilities;
    }
    
    public List<MediaFile> getMedia() {
        return media;
    }
    
    public void setMedia(List<MediaFile> media) {
        this.media = media;
    }
    
    public String getCreatedAt() {
        return createdAt;
    }
    
    public void setCreatedAt(String createdAt) {
        this.createdAt = createdAt;
    }
    
    public String getUserEmail() {
        return userEmail;
    }
    
    public void setUserEmail(String userEmail) {
        this.userEmail = userEmail;
    }
    
    public boolean isFavorite() {
        return isFavorite;
    }
    
    public void setFavorite(boolean favorite) {
        isFavorite = favorite;
    }
    
    // Helper methods
    public String getLocation() {
        if (street != null && city != null && postalCode != null) {
            return street + ", " + city + ", " + postalCode;
        } else if (city != null) {
            return city;
        }
        return "Location not available";
    }
    
    public String getFirstImageUrl() {
        if (media != null && !media.isEmpty()) {
            for (MediaFile file : media) {
                if (file.getType() != null && file.getType().startsWith("image/")) {
                    return file.getUrl();
                }
            }
        }
        return null;
    }
    
    public boolean hasImages() {
        if (media == null || media.isEmpty()) {
            return false;
        }
        for (MediaFile file : media) {
            if (file.getType() != null && file.getType().startsWith("image/")) {
                return true;
            }
        }
        return false;
    }
    
    // Inner class for media files
    public static class MediaFile {
        @SerializedName("url")
        private String url;
        
        @SerializedName("type")
        private String type;
        
        @SerializedName("name")
        private String name;
        
        public MediaFile() {}
        
        public MediaFile(String url, String type, String name) {
            this.url = url;
            this.type = type;
            this.name = name;
        }
        
        public String getUrl() {
            return url;
        }
        
        public void setUrl(String url) {
            this.url = url;
        }
        
        public String getType() {
            return type;
        }
        
        public void setType(String type) {
            this.type = type;
        }
        
        public String getName() {
            return name;
        }
        
        public void setName(String name) {
            this.name = name;
        }
    }
}