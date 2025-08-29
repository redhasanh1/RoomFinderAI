package com.roomfinder.android.models;

import com.google.gson.annotations.SerializedName;
import com.google.gson.JsonDeserializationContext;
import com.google.gson.JsonDeserializer;
import com.google.gson.JsonElement;
import com.google.gson.JsonParseException;
import com.google.gson.TypeAdapter;
import com.google.gson.annotations.JsonAdapter;
import com.google.gson.stream.JsonReader;
import com.google.gson.stream.JsonWriter;
import java.io.IOException;
import java.io.Serializable;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;

public class Listing implements Serializable {
    @SerializedName("id")
    private String id;
    
    @SerializedName("title")
    private String title;
    
    @SerializedName("description")
    private String description;
    
    @SerializedName("price")
    @JsonAdapter(FlexibleDoubleTypeAdapter.class)
    private double price;
    
    @SerializedName("bedrooms")
    private int bedrooms;
    
    // Note: bathrooms field not supported by database yet - excluded from serialization by SupabaseClient
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
        // Add safety check for price value
        if (Double.isNaN(price) || Double.isInfinite(price) || price < 0) {
            android.util.Log.w("Listing", "Invalid price value detected: " + price + ", returning 0");
            return 0.0;
        }
        return price;
    }
    
    // Safe price getter with detailed logging
    public double getSafePrice() {
        try {
            double safePrice = getPrice();
            android.util.Log.d("Listing", "Safe price accessed: $" + safePrice + " for property: " + (title != null ? title : "unknown"));
            return safePrice;
        } catch (Exception e) {
            android.util.Log.e("Listing", "Error accessing price for property: " + (title != null ? title : "unknown") + ", error: " + e.getMessage(), e);
            return 0.0;
        }
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
    
    // Validation helper methods
    public boolean isValidForNegotiation() {
        try {
            if (title == null || title.trim().isEmpty()) {
                android.util.Log.w("Listing", "Invalid listing: missing title");
                return false;
            }
            if (userEmail == null || userEmail.trim().isEmpty()) {
                android.util.Log.w("Listing", "Invalid listing: missing owner email");
                return false;
            }
            double priceCheck = getSafePrice();
            if (priceCheck <= 0) {
                android.util.Log.w("Listing", "Invalid listing: invalid price $" + priceCheck);
                return false;
            }
            return true;
        } catch (Exception e) {
            android.util.Log.e("Listing", "Error validating listing: " + e.getMessage(), e);
            return false;
        }
    }
    
    public String getValidationErrors() {
        List<String> errors = new ArrayList<>();
        
        if (title == null || title.trim().isEmpty()) {
            errors.add("Missing property title");
        }
        if (userEmail == null || userEmail.trim().isEmpty()) {
            errors.add("Missing landlord contact");
        }
        
        try {
            double priceCheck = getSafePrice();
            if (priceCheck <= 0) {
                errors.add("Invalid price: $" + priceCheck);
            }
        } catch (Exception e) {
            errors.add("Price access error: " + e.getMessage());
        }
        
        return errors.isEmpty() ? null : String.join(", ", errors);
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
    public static class MediaFile implements Serializable {
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
    
    // Custom TypeAdapter to handle various numeric types for price field (both serialization and deserialization)
    public static class FlexibleDoubleTypeAdapter extends TypeAdapter<Double> {
        @Override
        public void write(JsonWriter out, Double value) throws IOException {
            if (value == null) {
                out.value(0);
            } else {
                // Write as integer for database compatibility (database expects integer type)
                out.value(value.intValue());
            }
        }

        @Override
        public Double read(JsonReader in) throws IOException {
            try {
                switch (in.peek()) {
                    case NULL:
                        in.nextNull();
                        return 0.0;
                    case NUMBER:
                        return in.nextDouble();
                    case STRING:
                        String str = in.nextString();
                        if (str.isEmpty()) {
                            return 0.0;
                        }
                        return Double.parseDouble(str);
                    default:
                        in.skipValue();
                        return 0.0;
                }
            } catch (NumberFormatException e) {
                android.util.Log.e("Listing", "Error parsing price: " + e.getMessage());
                return 0.0;
            } catch (Exception e) {
                android.util.Log.e("Listing", "Unexpected error parsing price: " + e.getMessage());
                return 0.0;
            }
        }
    }
    
    // Keeping old deserializer for backward compatibility (deprecated)
    @Deprecated
    public static class FlexibleDoubleDeserializer implements JsonDeserializer<Double> {
        @Override
        public Double deserialize(JsonElement json, Type typeOfT, JsonDeserializationContext context) throws JsonParseException {
            try {
                if (json.isJsonNull()) {
                    return 0.0;
                }
                
                if (json.isJsonPrimitive()) {
                    if (json.getAsJsonPrimitive().isNumber()) {
                        // Handle any numeric type (int, long, float, double)
                        return json.getAsDouble();
                    } else if (json.getAsJsonPrimitive().isString()) {
                        // Handle string representation of numbers
                        String str = json.getAsString();
                        if (str.isEmpty()) {
                            return 0.0;
                        }
                        return Double.parseDouble(str);
                    }
                }
                
                // Default fallback
                return 0.0;
                
            } catch (NumberFormatException e) {
                android.util.Log.e("Listing", "Error parsing price: " + json.toString() + ", error: " + e.getMessage());
                return 0.0;
            } catch (Exception e) {
                android.util.Log.e("Listing", "Unexpected error parsing price: " + json.toString() + ", error: " + e.getMessage());
                return 0.0;
            }
        }
    }
}