package com.roomfinder.android.services;

import com.roomfinder.android.models.LegalResource;
import java.util.ArrayList;
import java.util.List;

public class LegalResourceService {
    
    public static List<LegalResource> getAllResources() {
        return LegalResource.getPopularResources();
    }
    
    public static List<LegalResource> getResourcesByCategory(LegalResource.ResourceCategory category) {
        return LegalResource.getResourcesByCategory(category);
    }
    
    public static List<LegalResource> getResourcesByType(LegalResource.ResourceType type) {
        List<LegalResource> allResources = getAllResources();
        List<LegalResource> filtered = new ArrayList<>();
        
        for (LegalResource resource : allResources) {
            if (resource.getType() == type) {
                filtered.add(resource);
            }
        }
        
        return filtered;
    }
    
    public static List<LegalResource> getFeaturedResources() {
        List<LegalResource> allResources = getAllResources();
        List<LegalResource> featured = new ArrayList<>();
        
        for (LegalResource resource : allResources) {
            if (resource.isFeatured() || resource.isRecommended()) {
                featured.add(resource);
            }
        }
        
        // If no featured resources, return top-rated ones
        if (featured.isEmpty()) {
            allResources.sort((r1, r2) -> Double.compare(r2.getRating(), r1.getRating()));
            return allResources.subList(0, Math.min(5, allResources.size()));
        }
        
        return featured;
    }
    
    public static List<LegalResource> searchResources(String query) {
        List<LegalResource> allResources = getAllResources();
        List<LegalResource> filtered = new ArrayList<>();
        
        String lowerQuery = query.toLowerCase();
        
        for (LegalResource resource : allResources) {
            if (resource.getTitle().toLowerCase().contains(lowerQuery) ||
                resource.getDescription().toLowerCase().contains(lowerQuery) ||
                containsInTags(resource.getTags(), lowerQuery)) {
                filtered.add(resource);
            }
        }
        
        return filtered;
    }
    
    private static boolean containsInTags(List<String> tags, String query) {
        for (String tag : tags) {
            if (tag.toLowerCase().contains(query)) {
                return true;
            }
        }
        return false;
    }
    
    public static void downloadResource(LegalResource resource) {
        resource.incrementDownloadCount();
        // In a real implementation, this would handle actual file download
    }
    
    public static void rateResource(LegalResource resource, double rating) {
        if (rating >= 1.0 && rating <= 5.0) {
            resource.addRating(rating);
        }
    }
    
    public static List<String> getResourceCategories() {
        List<String> categories = new ArrayList<>();
        for (LegalResource.ResourceCategory category : LegalResource.ResourceCategory.values()) {
            categories.add(category.getDisplayName());
        }
        return categories;
    }
    
    public static List<String> getResourceTypes() {
        List<String> types = new ArrayList<>();
        for (LegalResource.ResourceType type : LegalResource.ResourceType.values()) {
            types.add(type.getDisplayName());
        }
        return types;
    }
}