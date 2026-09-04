package com.roomfinder.android.models;

import com.google.gson.annotations.SerializedName;

import java.io.Serializable;
import java.util.List;
import java.util.Locale;

/**
 * A sublease post: either someone seeking a short-term place, or someone
 * offering theirs. Shape follows /api/sublease/search.
 */
public class SubleaseRequest implements Serializable {

    @SerializedName("id")
    private String id;

    @SerializedName("type")
    private String type;

    @SerializedName("status")
    private String status;

    @SerializedName("city")
    private String city;

    @SerializedName("state")
    private String state;

    @SerializedName("address")
    private String address;

    @SerializedName("rent_amount")
    private Integer rentAmount;

    @SerializedName("min_budget")
    private Integer minBudget;

    @SerializedName("max_budget")
    private Integer maxBudget;

    @SerializedName("preferred_move_in")
    private String preferredMoveIn;

    @SerializedName("preferred_move_out")
    private String preferredMoveOut;

    @SerializedName("available_from")
    private String availableFrom;

    @SerializedName("available_until")
    private String availableUntil;

    @SerializedName("duration_months")
    private Integer durationMonths;

    @SerializedName("property_type")
    private String propertyType;

    @SerializedName("bedrooms")
    private Integer bedrooms;

    @SerializedName("bathrooms")
    private Integer bathrooms;

    @SerializedName("furnished")
    private Boolean furnished;

    @SerializedName("amenities")
    private List<String> amenities;

    @SerializedName("description")
    private String description;

    @SerializedName("user_email")
    private String userEmail;

    public String getId() {
        return id;
    }

    public boolean isOffering() {
        return type != null && (type.equalsIgnoreCase("offering") || type.equalsIgnoreCase("offer"));
    }

    public String getTypeLabel() {
        return isOffering() ? "Offering a sublease" : "Looking for a sublease";
    }

    public boolean isActive() {
        return status == null || status.equalsIgnoreCase("active");
    }

    public String getLocationText() {
        if (city != null && !city.trim().isEmpty()) {
            if (state != null && !state.trim().isEmpty()) {
                return city.trim() + ", " + state.trim();
            }
            return city.trim();
        }
        if (address != null && !address.trim().isEmpty()) {
            return address.trim();
        }
        return "Location not set";
    }

    /** "$1,200/mo" when offering, otherwise the seeker's budget range. */
    public String getPriceText() {
        if (rentAmount != null && rentAmount > 0) {
            return String.format(Locale.US, "$%,d/mo", rentAmount);
        }
        if (minBudget != null && maxBudget != null && maxBudget > 0) {
            return String.format(Locale.US, "$%,d - $%,d/mo", minBudget, maxBudget);
        }
        if (maxBudget != null && maxBudget > 0) {
            return String.format(Locale.US, "Up to $%,d/mo", maxBudget);
        }
        return "Price on request";
    }

    /** "Jul 3 - Nov 14 - 6 months", skipping whatever is missing. */
    public String getDatesText() {
        String start = shortDate(isOffering() ? availableFrom : preferredMoveIn);
        String end = shortDate(isOffering() ? availableUntil : preferredMoveOut);

        StringBuilder text = new StringBuilder();
        if (start != null && end != null) {
            text.append(start).append(" – ").append(end);
        } else if (start != null) {
            text.append("From ").append(start);
        } else if (end != null) {
            text.append("Until ").append(end);
        }
        if (durationMonths != null && durationMonths > 0) {
            if (text.length() > 0) {
                text.append("  ·  ");
            }
            text.append(durationMonths).append(durationMonths == 1 ? " month" : " months");
        }
        return text.length() == 0 ? "Dates flexible" : text.toString();
    }

    /** "Apartment · 2 bd · Furnished", omitting anything the row does not carry. */
    public String getSummaryLine() {
        StringBuilder line = new StringBuilder();
        if (propertyType != null && !propertyType.trim().isEmpty()) {
            String type = propertyType.trim();
            line.append(Character.toUpperCase(type.charAt(0))).append(type.substring(1));
        }
        if (bedrooms != null && bedrooms > 0) {
            appendSeparator(line);
            line.append(bedrooms).append(" bd");
        }
        if (bathrooms != null && bathrooms > 0) {
            appendSeparator(line);
            line.append(bathrooms).append(" ba");
        }
        if (furnished != null && furnished) {
            appendSeparator(line);
            line.append("Furnished");
        }
        return line.toString();
    }

    public String getDescription() {
        return description == null ? "" : description.trim();
    }

    public String getUserEmail() {
        return userEmail;
    }

    public List<String> getAmenities() {
        return amenities;
    }

    private static void appendSeparator(StringBuilder line) {
        if (line.length() > 0) {
            line.append(" · ");
        }
    }

    /** "2026-08-22" or a full timestamp becomes "Aug 22". */
    private static String shortDate(String raw) {
        if (raw == null || raw.length() < 10) {
            return null;
        }
        String[] months = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
        try {
            int month = Integer.parseInt(raw.substring(5, 7));
            int day = Integer.parseInt(raw.substring(8, 10));
            if (month < 1 || month > 12) {
                return null;
            }
            return months[month - 1] + " " + day;
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
