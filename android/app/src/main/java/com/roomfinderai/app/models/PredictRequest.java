package com.roomfinderai.app.models;

public class PredictRequest {
    private String location;
    private String price;
    private String size;
    private String amenities;
    
    public PredictRequest(String location, String price, String size, String amenities) {
        this.location = location;
        this.price = price;
        this.size = size;
        this.amenities = amenities;
    }
    
    public String getLocation() { return location; }
    public String getPrice() { return price; }
    public String getSize() { return size; }
    public String getAmenities() { return amenities; }
}