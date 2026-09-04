package com.roomfinder.android.models;

import com.google.gson.annotations.SerializedName;

import java.io.Serializable;
import java.util.List;
import java.util.Locale;

/**
 * Someone on the roommate marketplace: either looking for a room, or with a
 * room to share. Mirrors the iOS RoommateProfile, including the seed-row marker
 * that must never be shown to a real person.
 */
public class RoommateProfile implements Serializable {

    public static final String KIND_SEEKING = "seeking";
    public static final String KIND_HAS_SPOT = "has_spot";

    @SerializedName("id")
    private String id;

    @SerializedName("name")
    private String name;

    @SerializedName("user_type")
    private String userType;

    @SerializedName("budget_min")
    private Integer budgetMin;

    @SerializedName("budget_max")
    private Integer budgetMax;

    @SerializedName("preferred_areas")
    private List<String> preferredAreas;

    @SerializedName("move_in_date")
    private String moveInDate;

    @SerializedName("bio")
    private String bio;

    @SerializedName("avatar_url")
    private String avatarUrl;

    @SerializedName("room_rent")
    private Integer roomRent;

    @SerializedName("room_location")
    private String roomLocation;

    @SerializedName("room_description")
    private String roomDescription;

    @SerializedName("room_photos")
    private List<String> roomPhotos;

    public String getId() {
        return id;
    }

    public String getKind() {
        return KIND_HAS_SPOT.equals(userType) ? KIND_HAS_SPOT : KIND_SEEKING;
    }

    public boolean hasSpot() {
        return KIND_HAS_SPOT.equals(getKind());
    }

    public String getKindLabel() {
        return hasSpot() ? "Has a room" : "Looking for a room";
    }

    public String getDisplayName() {
        return (name == null || name.trim().isEmpty()) ? "Someone" : name.trim();
    }

    /** Seed rows carry a marker; they are not real people and are filtered out. */
    public boolean isSeed() {
        String haystack = ((name == null ? "" : name) + " " + (bio == null ? "" : bio)).toLowerCase();
        return haystack.contains("[seed]");
    }

    public String getInitials() {
        String display = getDisplayName();
        StringBuilder initials = new StringBuilder();
        for (String part : display.split("\\s+")) {
            if (!part.isEmpty() && initials.length() < 2) {
                initials.append(Character.toUpperCase(part.charAt(0)));
            }
        }
        return initials.length() == 0 ? "?" : initials.toString();
    }

    public String getLocationText() {
        if (hasSpot() && roomLocation != null && !roomLocation.trim().isEmpty()) {
            return roomLocation.trim();
        }
        if (preferredAreas != null) {
            for (String area : preferredAreas) {
                if (area != null && !area.trim().isEmpty()) {
                    return capitalise(area.trim());
                }
            }
        }
        return "Anywhere";
    }

    /** "$700 - $1,000/mo", "$900/mo", or "Budget not set". */
    public String getBudgetText() {
        if (hasSpot() && roomRent != null && roomRent > 0) {
            return String.format(Locale.US, "$%,d/mo", roomRent);
        }
        if (budgetMin != null && budgetMax != null && budgetMax > 0) {
            return String.format(Locale.US, "$%,d - $%,d/mo", budgetMin, budgetMax);
        }
        if (budgetMax != null && budgetMax > 0) {
            return String.format(Locale.US, "Up to $%,d/mo", budgetMax);
        }
        if (budgetMin != null && budgetMin > 0) {
            return String.format(Locale.US, "From $%,d/mo", budgetMin);
        }
        return "Budget not set";
    }

    public String getBio() {
        if (hasSpot() && roomDescription != null && !roomDescription.trim().isEmpty()) {
            return roomDescription.trim();
        }
        return bio == null ? "" : bio.trim();
    }

    public String getAvatarUrl() {
        return avatarUrl;
    }

    public String getMoveInDate() {
        return moveInDate;
    }

    public List<String> getRoomPhotos() {
        return roomPhotos;
    }

    private static String capitalise(String value) {
        if (value.isEmpty()) {
            return value;
        }
        return Character.toUpperCase(value.charAt(0)) + value.substring(1);
    }
}
