package com.roomfinder.android.models;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * What the tenant wants out of a negotiation, and how hard to push for it.
 *
 * Mirrors NegotiationGoals in the iOS app (ios/RoomFinderAI/Models/Negotiation.swift)
 * field for field, including the wording sent to /api/negotiate/reply, so the
 * two apps argue the same case for the same person. Android had none of this:
 * every negotiation ran at one fixed setting with no budget, no target and no
 * sense of who the tenant was, whatever they actually wanted.
 *
 * Two gates are worth understanding before changing anything here.
 *
 * isUsable is the least the AI needs to argue at all - without a maximum rent
 * there is no position to hold, only chat.
 *
 * isConfirmed is stronger and deliberate. Nothing goes to a landlord on
 * unconfirmed goals. The website calls the same gate "lock in". It matters more
 * on mobile, because a campaign contacts several landlords at once, so a wrong
 * budget would go out several times before anyone noticed it was wrong.
 *
 * Stored per signed-in address, not globally: a shared phone must not negotiate
 * for one person using the last person's budget.
 */
public class NegotiationGoals {

    private static final String TAG = "NegotiationGoals";
    private static final String PREFS = "negotiation_goals";

    /** How hard the negotiator pushes. */
    public enum Assertiveness {
        GENTLE("gentle", "Gentle",
                "Asks politely, accepts a small discount, keeps things warm.",
                "polite and easygoing"),
        FIRM("firm", "Firm",
                "Holds your number, pushes back once or twice.",
                "firm but polite"),
        AGGRESSIVE("aggressive", "Aggressive",
                "Pushes hard, walks away from bad offers.",
                "very assertive, pushes hard on price");

        public final String key;
        public final String label;
        public final String explanation;
        /** The exact wording /api/negotiate/reply expects - do not paraphrase. */
        public final String apiValue;

        Assertiveness(String key, String label, String explanation, String apiValue) {
            this.key = key;
            this.label = label;
            this.explanation = explanation;
            this.apiValue = apiValue;
        }

        public static Assertiveness fromKey(String key) {
            for (Assertiveness a : values()) {
                if (a.key.equalsIgnoreCase(key)) {
                    return a;
                }
            }
            return FIRM;
        }
    }

    /** How the messages read. */
    public enum Tone {
        FRIENDLY("friendly", "Friendly"),
        NEUTRAL("neutral", "Neutral"),
        PROFESSIONAL("professional", "Professional");

        public final String key;
        public final String label;

        Tone(String key, String label) {
            this.key = key;
            this.label = label;
        }

        public static Tone fromKey(String key) {
            for (Tone t : values()) {
                if (t.key.equalsIgnoreCase(key)) {
                    return t;
                }
            }
            return FRIENDLY;
        }
    }

    // What they want. Null means not stated, which is different from zero.
    public Double maxRent;
    public Double targetRent;
    public String city = "";
    public String moveInDate = "";
    public Integer leaseMonths;

    public boolean petFriendly;
    public boolean parkingNeeded;
    public boolean furnished;
    public boolean utilitiesIncluded;
    public String notes = "";

    public Assertiveness assertiveness = Assertiveness.FIRM;
    public Tone tone = Tone.FRIENDLY;

    // Their side of the case: what makes them worth a discount.
    public String employment = "";
    public String occupants = "";
    public String pets = "";
    public boolean nonSmoker;

    // Worth asking for when the rent itself will not move. A smaller deposit is
    // often easier for a landlord to agree to than a lower monthly figure.
    public boolean askLowerDeposit;
    public boolean askFirstMonthFree;

    /** When the tenant last confirmed these, or 0 if they never have. */
    public long confirmedAt;

    public boolean isConfirmed() {
        return confirmedAt > 0;
    }

    /** The least the tenant has to say before the AI can argue for them. */
    public boolean isUsable() {
        return maxRent != null && maxRent > 0;
    }

    /**
     * A short line for the banner, so the numbers can be checked without
     * reopening the form.
     */
    public String summary() {
        List<String> parts = new ArrayList<>();
        if (maxRent != null) {
            parts.add(String.format(Locale.CANADA, "up to $%d/mo", Math.round(maxRent)));
        }
        if (targetRent != null) {
            parts.add(String.format(Locale.CANADA, "aiming for $%d", Math.round(targetRent)));
        }
        if (city != null && !city.isEmpty()) {
            parts.add(city);
        }
        if (leaseMonths != null) {
            parts.add(leaseMonths + " months");
        }
        if (moveInDate != null && !moveInDate.isEmpty()) {
            parts.add("from " + moveInDate);
        }
        parts.add(assertiveness.label.toLowerCase(Locale.CANADA));
        return parts.isEmpty() ? "No goals set yet" : android.text.TextUtils.join(" · ", parts);
    }

    // ---------------------------------------------------------------- storage

    private static String keyFor(String email) {
        String who = (email == null || email.isEmpty()) ? "anonymous" : email.toLowerCase(Locale.ROOT);
        return "goals." + who;
    }

    public static NegotiationGoals load(Context context, String email) {
        NegotiationGoals goals = new NegotiationGoals();
        if (context == null) {
            return goals;
        }
        try {
            SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            String raw = prefs.getString(keyFor(email), null);
            if (raw == null) {
                return goals;
            }
            JSONObject o = new JSONObject(raw);
            if (o.has("maxRent")) goals.maxRent = o.getDouble("maxRent");
            if (o.has("targetRent")) goals.targetRent = o.getDouble("targetRent");
            if (o.has("leaseMonths")) goals.leaseMonths = o.getInt("leaseMonths");
            goals.city = o.optString("city", "");
            goals.moveInDate = o.optString("moveInDate", "");
            goals.petFriendly = o.optBoolean("petFriendly");
            goals.parkingNeeded = o.optBoolean("parkingNeeded");
            goals.furnished = o.optBoolean("furnished");
            goals.utilitiesIncluded = o.optBoolean("utilitiesIncluded");
            goals.notes = o.optString("notes", "");
            goals.assertiveness = Assertiveness.fromKey(o.optString("assertiveness", "firm"));
            goals.tone = Tone.fromKey(o.optString("tone", "friendly"));
            goals.employment = o.optString("employment", "");
            goals.occupants = o.optString("occupants", "");
            goals.pets = o.optString("pets", "");
            goals.nonSmoker = o.optBoolean("nonSmoker");
            goals.askLowerDeposit = o.optBoolean("askLowerDeposit");
            goals.askFirstMonthFree = o.optBoolean("askFirstMonthFree");
            goals.confirmedAt = o.optLong("confirmedAt", 0);
        } catch (Exception e) {
            // A goals blob that will not parse must not stop somebody
            // negotiating; they get empty goals and are asked to fill them in.
            Log.w(TAG, "Stored goals could not be read; starting fresh", e);
            return new NegotiationGoals();
        }
        return goals;
    }

    public void save(Context context, String email) {
        if (context == null) {
            return;
        }
        try {
            JSONObject o = new JSONObject();
            if (maxRent != null) o.put("maxRent", (double) maxRent);
            if (targetRent != null) o.put("targetRent", (double) targetRent);
            if (leaseMonths != null) o.put("leaseMonths", (int) leaseMonths);
            o.put("city", city == null ? "" : city);
            o.put("moveInDate", moveInDate == null ? "" : moveInDate);
            o.put("petFriendly", petFriendly);
            o.put("parkingNeeded", parkingNeeded);
            o.put("furnished", furnished);
            o.put("utilitiesIncluded", utilitiesIncluded);
            o.put("notes", notes == null ? "" : notes);
            o.put("assertiveness", assertiveness.key);
            o.put("tone", tone.key);
            o.put("employment", employment == null ? "" : employment);
            o.put("occupants", occupants == null ? "" : occupants);
            o.put("pets", pets == null ? "" : pets);
            o.put("nonSmoker", nonSmoker);
            o.put("askLowerDeposit", askLowerDeposit);
            o.put("askFirstMonthFree", askFirstMonthFree);
            o.put("confirmedAt", confirmedAt);

            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putString(keyFor(email), o.toString())
                    .apply();
        } catch (Exception e) {
            Log.e(TAG, "Could not save goals", e);
        }
    }

    /**
     * Only the fields actually filled in.
     *
     * Sending empty values would have the negotiator argue for a budget of zero
     * or a move-in date of nothing, which reads as nonsense to the landlord and
     * weakens every other point in the message.
     */
    public JSONObject toApiPayload() throws org.json.JSONException {
        JSONObject o = new JSONObject();
        if (maxRent != null && maxRent > 0) o.put("maxRent", (double) maxRent);
        if (targetRent != null && targetRent > 0) o.put("targetRent", (double) targetRent);
        if (city != null && !city.isEmpty()) o.put("city", city);
        if (moveInDate != null && !moveInDate.isEmpty()) o.put("moveInDate", moveInDate);
        if (leaseMonths != null && leaseMonths > 0) o.put("leaseMonths", (int) leaseMonths);
        if (petFriendly) o.put("petFriendly", true);
        if (parkingNeeded) o.put("parkingNeeded", true);
        if (furnished) o.put("furnished", true);
        if (utilitiesIncluded) o.put("utilitiesIncluded", true);
        if (notes != null && !notes.isEmpty()) o.put("notes", notes);
        if (employment != null && !employment.isEmpty()) o.put("employment", employment);
        if (occupants != null && !occupants.isEmpty()) o.put("occupants", occupants);
        if (pets != null && !pets.isEmpty()) o.put("pets", pets);
        if (nonSmoker) o.put("nonSmoker", true);
        if (askLowerDeposit) o.put("askLowerDeposit", true);
        if (askFirstMonthFree) o.put("askFirstMonthFree", true);
        o.put("assertiveness", assertiveness.apiValue);
        o.put("tone", tone.key);
        return o;
    }
}
