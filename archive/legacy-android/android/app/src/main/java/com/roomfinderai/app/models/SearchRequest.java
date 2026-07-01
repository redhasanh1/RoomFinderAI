package com.roomfinderai.app.models;

public class SearchRequest {
    private String query;
    private String location;
    private Integer minPrice;
    private Integer maxPrice;
    private Integer bedrooms;
    
    public SearchRequest() {}
    
    public SearchRequest(String query, String location, Integer minPrice, Integer maxPrice, Integer bedrooms) {
        this.query = query;
        this.location = location;
        this.minPrice = minPrice;
        this.maxPrice = maxPrice;
        this.bedrooms = bedrooms;
    }
    
    public String getQuery() { return query; }
    public void setQuery(String query) { this.query = query; }
    
    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }
    
    public Integer getMinPrice() { return minPrice; }
    public void setMinPrice(Integer minPrice) { this.minPrice = minPrice; }
    
    public Integer getMaxPrice() { return maxPrice; }
    public void setMaxPrice(Integer maxPrice) { this.maxPrice = maxPrice; }
    
    public Integer getBedrooms() { return bedrooms; }
    public void setBedrooms(Integer bedrooms) { this.bedrooms = bedrooms; }
}