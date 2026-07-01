package com.roomfinder.android.services;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Content filtering service for chat moderation
 * Filters profanity, inappropriate content, and personal information
 * Designed for Google Play Store compliance
 */
public class ContentFilter {
    private static final String TAG = "ContentFilter";
    
    private Context context;
    private SharedPreferences filterPrefs;
    private boolean strictMode = false;
    
    // Profanity word lists (censored for code review)
    private static final Set<String> PROFANITY_WORDS = new HashSet<>(Arrays.asList(
        // Basic profanity (replace with actual words in production)
        "badword1", "badword2", "badword3",
        // Add comprehensive profanity list here
        "damn", "hell", "crap", "stupid", "idiot"
    ));
    
    private static final Set<String> SEVERE_PROFANITY = new HashSet<>(Arrays.asList(
        // Severe profanity that should always be blocked
        "severebad1", "severebad2"
        // Add severe profanity list here
    ));
    
    // Inappropriate content patterns
    private static final Set<String> SEXUAL_CONTENT_WORDS = new HashSet<>(Arrays.asList(
        "sexual", "explicit", "adult", "porn", "xxx", "nude", "naked", "sex", "erotic", "intimate"
    ));
    
    // Comprehensive nudity detection - zero tolerance for Google Play compliance
    private static final Set<String> NUDITY_WORDS = new HashSet<>(Arrays.asList(
        // Direct nudity terms
        "nude", "naked", "nudity", "topless", "bottomless", "undressed", "unclothed",
        "bare", "exposed", "revealing", "uncovered", "strip", "stripping", "stripped",
        
        // Body parts (explicit)
        "breast", "boob", "tit", "nipple", "chest", "butt", "ass", "penis", "vagina",
        "genitals", "private", "intimate", "body", "curves", "assets",
        
        // Suggestive/coded language
        "show me", "send pics", "picture", "photo", "selfie", "mirror", "bathroom",
        "bedroom", "shower", "bathing", "undressing", "changing", "lingerie",
        
        // Common slang and euphemisms
        "nudes", "pics", "pix", "snapchat", "snap", "dm", "private message",
        "secret", "hidden", "special", "just for you", "between us", "dont tell",
        
        // Sexual solicitation
        "hookup", "hook up", "meet up", "come over", "your place", "my place",
        "alone", "private", "horny", "turned on", "sexy", "hot", "want you"
    ));
    
    private static final Set<String> VIOLENCE_WORDS = new HashSet<>(Arrays.asList(
        "kill", "murder", "violence", "hurt", "harm", "attack", "threat", "weapon"
    ));
    
    private static final Set<String> HATE_SPEECH_WORDS = new HashSet<>(Arrays.asList(
        "hate", "racist", "discrimination", "prejudice"
        // Add comprehensive hate speech detection
    ));
    
    private static final Set<String> DRUG_CONTENT_WORDS = new HashSet<>(Arrays.asList(
        "drugs", "cocaine", "marijuana", "weed", "pills", "addiction"
    ));
    
    // Personal information patterns
    private static final Pattern PHONE_PATTERN = Pattern.compile(
        "\\b(?:\\+?1[-.]?)?\\(?([0-9]{3})\\)?[-.]?([0-9]{3})[-.]?([0-9]{4})\\b"
    );
    
    private static final Pattern EMAIL_PATTERN = Pattern.compile(
        "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b"
    );
    
    private static final Pattern SSN_PATTERN = Pattern.compile(
        "\\b\\d{3}-?\\d{2}-?\\d{4}\\b"
    );
    
    private static final Pattern CREDIT_CARD_PATTERN = Pattern.compile(
        "\\b(?:\\d{4}[-\\s]?){3}\\d{4}\\b"
    );
    
    // Commercial/spam patterns
    private static final Pattern URL_PATTERN = Pattern.compile(
        "https?://[-A-Za-z0-9+&@#/%?=~_|!:,.;]*[-A-Za-z0-9+&@#/%=~_|]"
    );
    
    private static final Set<String> COMMERCIAL_WORDS = new HashSet<>(Arrays.asList(
        "buy", "sell", "purchase", "discount", "deal", "offer", "promotion", "sale",
        "money", "cash", "payment", "business", "advertising", "marketing"
    ));
    
    public static class FilterResult {
        private boolean isViolation;
        private ChatModerationService.ViolationType violationType;
        private String reason;
        private int confidence;
        private boolean isHighSeverity;
        private List<String> detectedWords;
        
        public FilterResult(boolean isViolation, String reason) {
            this.isViolation = isViolation;
            this.reason = reason;
            this.confidence = 100;
            this.detectedWords = new ArrayList<>();
        }
        
        public FilterResult(boolean isViolation, ChatModerationService.ViolationType violationType, 
                          String reason, int confidence, boolean isHighSeverity) {
            this.isViolation = isViolation;
            this.violationType = violationType;
            this.reason = reason;
            this.confidence = confidence;
            this.isHighSeverity = isHighSeverity;
            this.detectedWords = new ArrayList<>();
        }
        
        // Getters
        public boolean isViolation() { return isViolation; }
        public ChatModerationService.ViolationType getViolationType() { return violationType; }
        public String getReason() { return reason; }
        public int getConfidence() { return confidence; }
        public boolean isHighSeverity() { return isHighSeverity; }
        public List<String> getDetectedWords() { return detectedWords; }
        
        public void addDetectedWord(String word) {
            detectedWords.add(word);
        }
    }
    
    public ContentFilter(Context context) {
        this.context = context;
        this.filterPrefs = context.getSharedPreferences("content_filter", Context.MODE_PRIVATE);
        this.strictMode = filterPrefs.getBoolean("strict_mode", false);
    }
    
    /**
     * Main content filtering method
     */
    public FilterResult filterContent(String content) {
        if (content == null || content.trim().isEmpty()) {
            return new FilterResult(false, "Empty content");
        }
        
        String normalizedContent = normalizeContent(content);
        
        // Check for severe violations first
        FilterResult severeCheck = checkSevereViolations(normalizedContent);
        if (severeCheck.isViolation()) {
            return severeCheck;
        }
        
        // Check for profanity
        FilterResult profanityCheck = checkProfanity(normalizedContent);
        if (profanityCheck.isViolation()) {
            return profanityCheck;
        }
        
        // Check for inappropriate content
        FilterResult inappropriateCheck = checkInappropriateContent(normalizedContent);
        if (inappropriateCheck.isViolation()) {
            return inappropriateCheck;
        }
        
        // Check for commercial content (in strict mode)
        if (strictMode) {
            FilterResult commercialCheck = checkCommercialContent(normalizedContent);
            if (commercialCheck.isViolation()) {
                return commercialCheck;
            }
        }
        
        return new FilterResult(false, "Content passed filter");
    }
    
    /**
     * Check if content contains personal information
     */
    public boolean containsPersonalInfo(String content) {
        if (content == null) return false;
        
        return PHONE_PATTERN.matcher(content).find() ||
               EMAIL_PATTERN.matcher(content).find() ||
               SSN_PATTERN.matcher(content).find() ||
               CREDIT_CARD_PATTERN.matcher(content).find();
    }
    
    /**
     * Get personal info detection details
     */
    public FilterResult checkPersonalInfo(String content) {
        if (content == null) {
            return new FilterResult(false, "No content to check");
        }
        
        List<String> foundTypes = new ArrayList<>();
        
        if (PHONE_PATTERN.matcher(content).find()) {
            foundTypes.add("phone number");
        }
        if (EMAIL_PATTERN.matcher(content).find()) {
            foundTypes.add("email address");
        }
        if (SSN_PATTERN.matcher(content).find()) {
            foundTypes.add("social security number");
        }
        if (CREDIT_CARD_PATTERN.matcher(content).find()) {
            foundTypes.add("credit card number");
        }
        
        if (!foundTypes.isEmpty()) {
            String reason = "Personal information detected: " + String.join(", ", foundTypes);
            return new FilterResult(true, ChatModerationService.ViolationType.PERSONAL_INFO, 
                                  reason, 90, false);
        }
        
        return new FilterResult(false, "No personal information detected");
    }
    
    /**
     * Set strict filtering mode
     */
    public void setStrictMode(boolean enabled) {
        this.strictMode = enabled;
        filterPrefs.edit().putBoolean("strict_mode", enabled).apply();
    }
    
    public boolean isStrictMode() {
        return strictMode;
    }
    
    // Private helper methods
    
    private String normalizeContent(String content) {
        return content.toLowerCase()
                     .replaceAll("[^a-zA-Z0-9\\s]", " ") // Remove special chars
                     .replaceAll("\\s+", " ") // Normalize whitespace
                     .trim();
    }
    
    private FilterResult checkSevereViolations(String content) {
        // Check for nudity first - highest priority
        for (String word : NUDITY_WORDS) {
            if (content.contains(word)) {
                FilterResult result = new FilterResult(true, ChatModerationService.ViolationType.SEXUAL_CONTENT,
                                                     "Nudity content detected - immediate block", 98, true);
                result.addDetectedWord(word);
                return result;
            }
        }
        
        // Check for severe profanity
        for (String word : SEVERE_PROFANITY) {
            if (content.contains(word)) {
                FilterResult result = new FilterResult(true, ChatModerationService.ViolationType.PROFANITY,
                                                     "Severe profanity detected", 95, true);
                result.addDetectedWord(word);
                return result;
            }
        }
        
        // Check for hate speech
        int hateWords = 0;
        for (String word : HATE_SPEECH_WORDS) {
            if (content.contains(word)) {
                hateWords++;
            }
        }
        
        if (hateWords >= 2) {
            return new FilterResult(true, ChatModerationService.ViolationType.HATE_SPEECH,
                                  "Hate speech detected", 90, true);
        }
        
        // Check for violence/threats
        int violenceWords = 0;
        for (String word : VIOLENCE_WORDS) {
            if (content.contains(word)) {
                violenceWords++;
            }
        }
        
        if (violenceWords >= 2) {
            return new FilterResult(true, ChatModerationService.ViolationType.VIOLENCE_THREATS,
                                  "Violence or threats detected", 85, true);
        }
        
        return new FilterResult(false, "No severe violations");
    }
    
    private FilterResult checkProfanity(String content) {
        List<String> foundProfanity = new ArrayList<>();
        
        for (String word : PROFANITY_WORDS) {
            if (content.contains(word)) {
                foundProfanity.add(word);
            }
        }
        
        if (!foundProfanity.isEmpty()) {
            String reason = "Profanity detected: " + foundProfanity.size() + " word(s)";
            boolean isHighSeverity = foundProfanity.size() >= 3;
            
            FilterResult result = new FilterResult(true, ChatModerationService.ViolationType.PROFANITY,
                                                 reason, 85, isHighSeverity);
            foundProfanity.forEach(result::addDetectedWord);
            return result;
        }
        
        return new FilterResult(false, "No profanity detected");
    }
    
    private FilterResult checkInappropriateContent(String content) {
        // Check for nudity - ZERO TOLERANCE (immediate block on single detection)
        List<String> foundNudityWords = new ArrayList<>();
        for (String word : NUDITY_WORDS) {
            if (content.contains(word)) {
                foundNudityWords.add(word);
            }
        }
        
        if (!foundNudityWords.isEmpty()) {
            String reason = "Nudity/inappropriate content detected: " + foundNudityWords.size() + " violation(s)";
            FilterResult result = new FilterResult(true, ChatModerationService.ViolationType.SEXUAL_CONTENT,
                                                 reason, 95, true); // High severity, immediate block
            foundNudityWords.forEach(result::addDetectedWord);
            return result;
        }
        
        // Check general sexual content (requires multiple words)
        int sexualWords = 0;
        for (String word : SEXUAL_CONTENT_WORDS) {
            if (content.contains(word)) {
                sexualWords++;
            }
        }
        
        if (sexualWords >= 2) {
            return new FilterResult(true, ChatModerationService.ViolationType.SEXUAL_CONTENT,
                                  "Sexual content detected", 80, true);
        }
        
        // Check drug content
        int drugWords = 0;
        for (String word : DRUG_CONTENT_WORDS) {
            if (content.contains(word)) {
                drugWords++;
            }
        }
        
        if (drugWords >= 1) {
            return new FilterResult(true, ChatModerationService.ViolationType.INAPPROPRIATE_CONTENT,
                                  "Drug-related content detected", 75, false);
        }
        
        return new FilterResult(false, "No inappropriate content detected");
    }
    
    private FilterResult checkCommercialContent(String content) {
        int commercialWords = 0;
        boolean hasUrl = URL_PATTERN.matcher(content).find();
        
        for (String word : COMMERCIAL_WORDS) {
            if (content.contains(word)) {
                commercialWords++;
            }
        }
        
        // Flag as commercial if multiple commercial words + URL
        if (commercialWords >= 3 || (hasUrl && commercialWords >= 2)) {
            return new FilterResult(true, ChatModerationService.ViolationType.COMMERCIAL_CONTENT,
                                  "Commercial/advertising content detected", 70, false);
        }
        
        return new FilterResult(false, "No commercial content detected");
    }
    
    /**
     * Update word lists (for admin use)
     */
    public void addProfanityWord(String word) {
        PROFANITY_WORDS.add(word.toLowerCase());
    }
    
    public void removeProfanityWord(String word) {
        PROFANITY_WORDS.remove(word.toLowerCase());
    }
    
    /**
     * Check specifically for nudity content - public method for external use
     */
    public boolean containsNudityContent(String content) {
        if (content == null) return false;
        
        String normalizedContent = normalizeContent(content);
        for (String word : NUDITY_WORDS) {
            if (normalizedContent.contains(word)) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * Get nudity detection details
     */
    public FilterResult checkNudityContent(String content) {
        if (content == null) {
            return new FilterResult(false, "No content to check");
        }
        
        String normalizedContent = normalizeContent(content);
        List<String> foundWords = new ArrayList<>();
        
        for (String word : NUDITY_WORDS) {
            if (normalizedContent.contains(word)) {
                foundWords.add(word);
            }
        }
        
        if (!foundWords.isEmpty()) {
            String reason = "Nudity content detected - zero tolerance policy violation";
            FilterResult result = new FilterResult(true, ChatModerationService.ViolationType.SEXUAL_CONTENT, 
                                                 reason, 98, true); // Highest confidence and severity
            foundWords.forEach(result::addDetectedWord);
            return result;
        }
        
        return new FilterResult(false, "No nudity content detected");
    }
    
    /**
     * Get filter statistics
     */
    public FilterStats getFilterStats() {
        FilterStats stats = new FilterStats();
        stats.totalProfanityWords = PROFANITY_WORDS.size();
        stats.totalSexualContentWords = SEXUAL_CONTENT_WORDS.size();
        stats.totalNudityWords = NUDITY_WORDS.size();
        stats.totalViolenceWords = VIOLENCE_WORDS.size();
        stats.totalHateSpeechWords = HATE_SPEECH_WORDS.size();
        stats.isStrictModeEnabled = strictMode;
        return stats;
    }
    
    public static class FilterStats {
        public int totalProfanityWords;
        public int totalSexualContentWords;
        public int totalNudityWords;
        public int totalViolenceWords;
        public int totalHateSpeechWords;
        public boolean isStrictModeEnabled;
    }
    
    /**
     * Test filter with sample content
     */
    public void runFilterTest() {
        Log.d(TAG, "Running content filter test...");
        
        String[] testCases = {
            "Hello, how are you?", // Should pass
            "This contains badword1", // Should be flagged
            "Call me at 555-123-4567", // Should detect personal info
            "Visit my website at http://example.com for deals", // Should detect commercial
            "Send me a nude pic", // Should be blocked immediately
            "Want to see me naked?", // Should be blocked immediately
            "Show me your body", // Should be blocked immediately
        };
        
        for (String test : testCases) {
            FilterResult result = filterContent(test);
            Log.d(TAG, "Test: '" + test + "' -> " + 
                  (result.isViolation() ? "VIOLATION: " + result.getReason() : "PASSED"));
        }
    }
}