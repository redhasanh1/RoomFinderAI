package com.roomfinderai.app.models;

import com.google.gson.annotations.SerializedName;
import com.roomfinderai.app.config.ApiConfig;

public class MediaItem {
    @SerializedName("name")
    private String name;
    
    @SerializedName("type")
    private String type;
    
    @SerializedName("url")
    private String url;
    
    @SerializedName("data")
    private String data; // Optional base64 preview data
    
    // Default constructor
    public MediaItem() {}
    
    // Constructor
    public MediaItem(String name, String type, String url) {
        this.name = name;
        this.type = type;
        this.url = url;
    }
    
    // Constructor with data
    public MediaItem(String name, String type, String url, String data) {
        this.name = name;
        this.type = type;
        this.url = url;
        this.data = data;
    }
    
    // Getters and Setters
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    
    public String getUrl() { return url; }
    public void setUrl(String url) { this.url = url; }
    
    public String getData() { return data; }
    public void setData(String data) { this.data = data; }
    
    // Utility methods
    public boolean isImage() {
        return type != null && type.startsWith("image/");
    }
    
    public boolean hasValidUrl() {
        return url != null && !url.isEmpty();
    }
    
    // Get Supabase public URL (matches website implementation)
    public String getPublicUrl() {
        if (url == null || url.isEmpty()) {
            return null;
        }
        
        // Use ApiConfig to construct proper Supabase storage URL
        return ApiConfig.constructMediaUrl(url);
    }
    
    @Override
    public String toString() {
        return "MediaItem{" +
                "name='" + name + '\'' +
                ", type='" + type + '\'' +
                ", url='" + url + '\'' +
                ", hasData=" + (data != null && !data.isEmpty()) +
                '}';
    }
}