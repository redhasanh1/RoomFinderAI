package com.roomfinder.android.services;

import com.roomfinder.android.models.TenantRights;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class TenantRightsService {
    
    public static List<TenantRights> getAllRights(String state) {
        List<TenantRights> rights = new ArrayList<>();
        
        for (TenantRights.RightCategory category : TenantRights.RightCategory.values()) {
            rights.add(new TenantRights(state, category));
        }
        
        return rights;
    }
    
    public static TenantRights getRightsByCategory(String state, TenantRights.RightCategory category) {
        return new TenantRights(state, category);
    }
    
    public static List<TenantRights> searchRights(String state, String query) {
        List<TenantRights> allRights = getAllRights(state);
        List<TenantRights> filtered = new ArrayList<>();
        
        String lowerQuery = query.toLowerCase();
        
        for (TenantRights right : allRights) {
            if (right.getTitle().toLowerCase().contains(lowerQuery) ||
                right.getDescription().toLowerCase().contains(lowerQuery) ||
                containsInKeyPoints(right.getKeyPoints(), lowerQuery)) {
                filtered.add(right);
            }
        }
        
        return filtered;
    }
    
    private static boolean containsInKeyPoints(List<String> keyPoints, String query) {
        for (String point : keyPoints) {
            if (point.toLowerCase().contains(query)) {
                return true;
            }
        }
        return false;
    }
    
    public static List<String> getSupportedStates() {
        return Arrays.asList(
            "Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado", 
            "Connecticut", "Delaware", "Florida", "Georgia", "Hawaii", "Idaho", 
            "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky", "Louisiana", 
            "Maine", "Maryland", "Massachusetts", "Michigan", "Minnesota", 
            "Mississippi", "Missouri", "Montana", "Nebraska", "Nevada", 
            "New Hampshire", "New Jersey", "New Mexico", "New York", 
            "North Carolina", "North Dakota", "Ohio", "Oklahoma", "Oregon", 
            "Pennsylvania", "Rhode Island", "South Carolina", "South Dakota", 
            "Tennessee", "Texas", "Utah", "Vermont", "Virginia", "Washington", 
            "West Virginia", "Wisconsin", "Wyoming"
        );
    }
    
    public static List<String> getQuickRightsTips() {
        List<String> tips = new ArrayList<>();
        
        tips.add("Document everything in writing - photos, emails, texts");
        tips.add("Know your state's notice requirements for landlord entry");
        tips.add("Understand your security deposit rights");
        tips.add("Keep records of all rent payments");
        tips.add("Report maintenance issues promptly in writing");
        tips.add("Know the difference between normal wear and damage");
        tips.add("Understand your privacy rights");
        tips.add("Know the proper eviction process in your state");
        
        return tips;
    }
}