package com.roomfinder.android.services;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import com.roomfinder.android.models.ChatMessage;

import java.util.concurrent.ConcurrentHashMap;
import java.util.List;
import java.util.ArrayList;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Spam detection service for chat moderation
 * Detects and prevents spam, flooding, and suspicious messaging patterns
 * Designed for Google Play Store compliance
 */
public class SpamDetectionService {
    private static final String TAG = "SpamDetectionService";
    
    private Context context;
    private SharedPreferences spamPrefs;
    
    // Rate limiting settings
    private static final int MAX_MESSAGES_PER_MINUTE = 10;
    private static final int MAX_MESSAGES_PER_HOUR = 60;
    private static final long RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute
    private static final long HOURLY_WINDOW_MS = 60 * 60 * 1000; // 1 hour
    
    // Spam detection thresholds
    private static final int MAX_DUPLICATE_MESSAGES = 3;
    private static final int MAX_IDENTICAL_CHARS = 50; // Max consecutive identical characters
    private static final double MIN_SIMILARITY_THRESHOLD = 0.8; // 80% similarity = spam
    private static final int MAX_URLS_PER_MESSAGE = 2;
    private static final int MIN_MESSAGE_INTERVAL_MS = 2000; // 2 seconds between messages
    
    // User message tracking
    private ConcurrentHashMap<String, List<MessageTracker>> userMessageHistory = new ConcurrentHashMap<>();
    private ConcurrentHashMap<String, Long> lastMessageTime = new ConcurrentHashMap<>();
    private ConcurrentHashMap<String, Integer> minuteMessageCounts = new ConcurrentHashMap<>();
    private ConcurrentHashMap<String, Integer> hourlyMessageCounts = new ConcurrentHashMap<>();
    private ConcurrentHashMap<String, Long> rateLimitExpiryTime = new ConcurrentHashMap<>();
    
    // Pattern matching for spam detection
    private static final Pattern URL_PATTERN = Pattern.compile(
        "https?://[-A-Za-z0-9+&@#/%?=~_|!:,.;]*[-A-Za-z0-9+&@#/%=~_|]"
    );
    
    private static final Pattern PHONE_PATTERN = Pattern.compile(
        "\\b(?:\\+?1[-.]?)?\\(?([0-9]{3})\\)?[-.]?([0-9]{3})[-.]?([0-9]{4})\\b"
    );
    
    private static final Pattern EMAIL_PATTERN = Pattern.compile(
        "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b"
    );
    
    private static final Pattern EXCESSIVE_CAPS_PATTERN = Pattern.compile(
        "[A-Z]{10,}"
    );
    
    private static final Pattern EXCESSIVE_PUNCTUATION = Pattern.compile(
        "[!?.]{5,}"
    );
    
    private static class MessageTracker {
        public String content;
        public long timestamp;
        public String hash;
        
        public MessageTracker(String content, long timestamp) {
            this.content = content;
            this.timestamp = timestamp;
            this.hash = String.valueOf(content.hashCode());
        }
        
        public boolean isExpired(long windowMs) {
            return System.currentTimeMillis() - timestamp > windowMs;
        }
    }
    
    public static class SpamDetectionResult {
        public boolean isSpam;
        public SpamType spamType;
        public String reason;
        public int confidence; // 0-100
        public boolean requiresRateLimit;
        public long rateLimitDuration; // in milliseconds
        
        public SpamDetectionResult(boolean isSpam, String reason) {
            this.isSpam = isSpam;
            this.reason = reason;
            this.confidence = 100;
            this.requiresRateLimit = false;
        }
        
        public SpamDetectionResult(boolean isSpam, SpamType spamType, String reason, int confidence) {
            this.isSpam = isSpam;
            this.spamType = spamType;
            this.reason = reason;
            this.confidence = confidence;
            this.requiresRateLimit = isSpam;
            this.rateLimitDuration = calculateRateLimitDuration(spamType);
        }
        
        private long calculateRateLimitDuration(SpamType type) {
            switch (type) {
                case RATE_LIMIT_EXCEEDED:
                    return 5 * 60 * 1000; // 5 minutes
                case DUPLICATE_MESSAGES:
                    return 2 * 60 * 1000; // 2 minutes
                case EXCESSIVE_URLS:
                case EXCESSIVE_CAPS:
                    return 1 * 60 * 1000; // 1 minute
                case FLOODING:
                    return 10 * 60 * 1000; // 10 minutes
                default:
                    return 1 * 60 * 1000; // 1 minute default
            }
        }
    }
    
    public enum SpamType {
        RATE_LIMIT_EXCEEDED,
        DUPLICATE_MESSAGES,
        EXCESSIVE_URLS,
        EXCESSIVE_CAPS,
        EXCESSIVE_PUNCTUATION,
        GIBBERISH_TEXT,
        FLOODING,
        SUSPICIOUS_PATTERNS,
        CONTACT_INFO_SPAM
    }
    
    public SpamDetectionService(Context context) {
        this.context = context;
        this.spamPrefs = context.getSharedPreferences("spam_detection", Context.MODE_PRIVATE);
        
        // Clean up expired tracking data periodically
        startCleanupTimer();
    }
    
    /**
     * Main spam detection method
     */
    public boolean isSpam(ChatMessage message) {
        SpamDetectionResult result = detectSpam(message);
        return result.isSpam;
    }
    
    /**
     * Detailed spam detection with result information
     */
    public SpamDetectionResult detectSpam(ChatMessage message) {
        String userEmail = message.getSenderEmail();
        String content = message.getContent();
        long currentTime = System.currentTimeMillis();
        
        // Check if user is currently rate limited
        if (isRateLimited(userEmail)) {
            return new SpamDetectionResult(true, SpamType.RATE_LIMIT_EXCEEDED, 
                "User is currently rate limited", 100);
        }
        
        // Check rate limits
        SpamDetectionResult rateLimitCheck = checkRateLimits(userEmail, currentTime);
        if (rateLimitCheck.isSpam) {
            applyRateLimit(userEmail, rateLimitCheck.rateLimitDuration);
            return rateLimitCheck;
        }
        
        // Check for duplicate messages
        SpamDetectionResult duplicateCheck = checkDuplicateMessages(userEmail, content, currentTime);
        if (duplicateCheck.isSpam) {
            return duplicateCheck;
        }
        
        // Check message content for spam patterns
        SpamDetectionResult contentCheck = checkContentForSpam(content);
        if (contentCheck.isSpam) {
            return contentCheck;
        }
        
        // Check message timing
        SpamDetectionResult timingCheck = checkMessageTiming(userEmail, currentTime);
        if (timingCheck.isSpam) {
            return timingCheck;
        }
        
        // Track this message
        trackMessage(userEmail, content, currentTime);
        
        return new SpamDetectionResult(false, "Message passed spam detection");
    }
    
    /**
     * Check if user is currently rate limited
     */
    public boolean isRateLimited(String userEmail) {
        Long expiryTime = rateLimitExpiryTime.get(userEmail);
        if (expiryTime != null && System.currentTimeMillis() < expiryTime) {
            return true;
        }
        
        // Clean up expired rate limit
        if (expiryTime != null) {
            rateLimitExpiryTime.remove(userEmail);
        }
        
        return false;
    }
    
    /**
     * Apply rate limit to user
     */
    public void applyRateLimit(String userEmail, long durationMs) {
        long expiryTime = System.currentTimeMillis() + durationMs;
        rateLimitExpiryTime.put(userEmail, expiryTime);
        
        Log.w(TAG, "Rate limit applied to user: " + userEmail + " for " + durationMs + "ms");
        
        // Save to persistent storage
        spamPrefs.edit().putLong("rate_limit_" + userEmail, expiryTime).apply();
    }
    
    /**
     * Get remaining rate limit time
     */
    public long getRemainingRateLimitTime(String userEmail) {
        Long expiryTime = rateLimitExpiryTime.get(userEmail);
        if (expiryTime != null) {
            long remaining = expiryTime - System.currentTimeMillis();
            return Math.max(0, remaining);
        }
        return 0;
    }
    
    /**
     * Get spam detection statistics
     */
    public SpamStats getSpamStats() {
        SpamStats stats = new SpamStats();
        
        for (List<MessageTracker> messages : userMessageHistory.values()) {
            stats.totalMessagesTracked += messages.size();
        }
        
        stats.usersCurrentlyRateLimited = rateLimitExpiryTime.size();
        stats.totalUsersTracked = userMessageHistory.size();
        
        return stats;
    }
    
    public static class SpamStats {
        public int totalMessagesTracked = 0;
        public int usersCurrentlyRateLimited = 0;
        public int totalUsersTracked = 0;
        public Map<SpamType, Integer> spamTypeBreakdown = new ConcurrentHashMap<>();
    }
    
    // Private helper methods
    
    private SpamDetectionResult checkRateLimits(String userEmail, long currentTime) {
        // Check per-minute rate limit
        Integer minuteCount = minuteMessageCounts.get(userEmail);
        if (minuteCount != null && minuteCount >= MAX_MESSAGES_PER_MINUTE) {
            return new SpamDetectionResult(true, SpamType.RATE_LIMIT_EXCEEDED, 
                "Too many messages per minute", 100);
        }
        
        // Check per-hour rate limit
        Integer hourlyCount = hourlyMessageCounts.get(userEmail);
        if (hourlyCount != null && hourlyCount >= MAX_MESSAGES_PER_HOUR) {
            return new SpamDetectionResult(true, SpamType.RATE_LIMIT_EXCEEDED, 
                "Too many messages per hour", 100);
        }
        
        // Update counters
        updateMessageCounters(userEmail, currentTime);
        
        return new SpamDetectionResult(false, "Rate limits not exceeded");
    }
    
    private SpamDetectionResult checkDuplicateMessages(String userEmail, String content, long currentTime) {
        List<MessageTracker> userMessages = userMessageHistory.get(userEmail);
        if (userMessages == null) {
            return new SpamDetectionResult(false, "No message history");
        }
        
        // Remove expired messages
        userMessages.removeIf(msg -> msg.isExpired(RATE_LIMIT_WINDOW_MS));
        
        // Count identical messages
        int duplicateCount = 0;
        String contentHash = String.valueOf(content.hashCode());
        
        for (MessageTracker tracker : userMessages) {
            if (tracker.hash.equals(contentHash) || 
                calculateSimilarity(tracker.content, content) > MIN_SIMILARITY_THRESHOLD) {
                duplicateCount++;
            }
        }
        
        if (duplicateCount >= MAX_DUPLICATE_MESSAGES) {
            return new SpamDetectionResult(true, SpamType.DUPLICATE_MESSAGES, 
                "Too many similar messages", 90);
        }
        
        return new SpamDetectionResult(false, "No duplicate messages detected");
    }
    
    private SpamDetectionResult checkContentForSpam(String content) {
        if (content == null || content.trim().isEmpty()) {
            return new SpamDetectionResult(false, "Empty content");
        }
        
        // Check for excessive URLs
        long urlCount = URL_PATTERN.matcher(content).results().count();
        if (urlCount > MAX_URLS_PER_MESSAGE) {
            return new SpamDetectionResult(true, SpamType.EXCESSIVE_URLS, 
                "Too many URLs in message", 85);
        }
        
        // Check for excessive capital letters
        if (EXCESSIVE_CAPS_PATTERN.matcher(content).find()) {
            return new SpamDetectionResult(true, SpamType.EXCESSIVE_CAPS, 
                "Excessive capital letters", 70);
        }
        
        // Check for excessive punctuation
        if (EXCESSIVE_PUNCTUATION.matcher(content).find()) {
            return new SpamDetectionResult(true, SpamType.EXCESSIVE_PUNCTUATION, 
                "Excessive punctuation", 65);
        }
        
        // Check for contact info spam
        long contactInfoCount = PHONE_PATTERN.matcher(content).results().count() + 
                               EMAIL_PATTERN.matcher(content).results().count();
        if (contactInfoCount > 1) {
            return new SpamDetectionResult(true, SpamType.CONTACT_INFO_SPAM, 
                "Multiple contact information items", 80);
        }
        
        // Check for gibberish (repeated characters)
        if (hasExcessiveRepeatedChars(content)) {
            return new SpamDetectionResult(true, SpamType.GIBBERISH_TEXT, 
                "Excessive repeated characters", 75);
        }
        
        // Check for suspicious patterns
        if (hasSuspiciousPatterns(content)) {
            return new SpamDetectionResult(true, SpamType.SUSPICIOUS_PATTERNS, 
                "Suspicious text patterns detected", 60);
        }
        
        return new SpamDetectionResult(false, "Content passed spam checks");
    }
    
    private SpamDetectionResult checkMessageTiming(String userEmail, long currentTime) {
        Long lastTime = lastMessageTime.get(userEmail);
        if (lastTime != null) {
            long timeSinceLastMessage = currentTime - lastTime;
            if (timeSinceLastMessage < MIN_MESSAGE_INTERVAL_MS) {
                return new SpamDetectionResult(true, SpamType.FLOODING, 
                    "Messages sent too quickly", 90);
            }
        }
        
        lastMessageTime.put(userEmail, currentTime);
        return new SpamDetectionResult(false, "Message timing is acceptable");
    }
    
    private void trackMessage(String userEmail, String content, long timestamp) {
        List<MessageTracker> userMessages = userMessageHistory.computeIfAbsent(userEmail, 
            k -> new ArrayList<>());
        
        userMessages.add(new MessageTracker(content, timestamp));
        
        // Keep only recent messages (last hour)
        userMessages.removeIf(msg -> msg.isExpired(HOURLY_WINDOW_MS));
    }
    
    private void updateMessageCounters(String userEmail, long currentTime) {
        // Update minute counter
        minuteMessageCounts.put(userEmail, 
            minuteMessageCounts.getOrDefault(userEmail, 0) + 1);
        
        // Update hourly counter
        hourlyMessageCounts.put(userEmail, 
            hourlyMessageCounts.getOrDefault(userEmail, 0) + 1);
        
        // Schedule counter reset
        scheduleCounterReset(userEmail, currentTime);
    }
    
    private void scheduleCounterReset(String userEmail, long currentTime) {
        // Reset minute counter after 1 minute
        new android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(() -> {
            minuteMessageCounts.remove(userEmail);
        }, RATE_LIMIT_WINDOW_MS);
        
        // Reset hourly counter after 1 hour
        new android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(() -> {
            hourlyMessageCounts.remove(userEmail);
        }, HOURLY_WINDOW_MS);
    }
    
    private double calculateSimilarity(String str1, String str2) {
        if (str1 == null || str2 == null) return 0;
        
        // Simple similarity calculation using Levenshtein distance
        int[][] dp = new int[str1.length() + 1][str2.length() + 1];
        
        for (int i = 0; i <= str1.length(); i++) {
            for (int j = 0; j <= str2.length(); j++) {
                if (i == 0) {
                    dp[i][j] = j;
                } else if (j == 0) {
                    dp[i][j] = i;
                } else {
                    dp[i][j] = Math.min(Math.min(
                        dp[i - 1][j] + 1,
                        dp[i][j - 1] + 1),
                        dp[i - 1][j - 1] + (str1.charAt(i - 1) == str2.charAt(j - 1) ? 0 : 1)
                    );
                }
            }
        }
        
        int maxLen = Math.max(str1.length(), str2.length());
        return 1.0 - (double) dp[str1.length()][str2.length()] / maxLen;
    }
    
    private boolean hasExcessiveRepeatedChars(String content) {
        char lastChar = 0;
        int consecutiveCount = 0;
        
        for (char c : content.toCharArray()) {
            if (c == lastChar) {
                consecutiveCount++;
                if (consecutiveCount >= MAX_IDENTICAL_CHARS) {
                    return true;
                }
            } else {
                consecutiveCount = 1;
                lastChar = c;
            }
        }
        
        return false;
    }
    
    private boolean hasSuspiciousPatterns(String content) {
        String lowerContent = content.toLowerCase();
        
        // Check for common spam phrases
        String[] spamPhrases = {
            "click here", "free money", "guaranteed", "limited time",
            "act now", "call now", "urgent", "winner", "congratulations"
        };
        
        int spamPhraseCount = 0;
        for (String phrase : spamPhrases) {
            if (lowerContent.contains(phrase)) {
                spamPhraseCount++;
            }
        }
        
        return spamPhraseCount >= 2;
    }
    
    private void startCleanupTimer() {
        // Clean up expired data every 5 minutes
        android.os.Handler handler = new android.os.Handler(android.os.Looper.getMainLooper());
        handler.postDelayed(new Runnable() {
            @Override
            public void run() {
                cleanupExpiredData();
                handler.postDelayed(this, 5 * 60 * 1000); // 5 minutes
            }
        }, 5 * 60 * 1000);
    }
    
    private void cleanupExpiredData() {
        long currentTime = System.currentTimeMillis();
        
        // Clean up message history
        for (List<MessageTracker> messages : userMessageHistory.values()) {
            messages.removeIf(msg -> msg.isExpired(HOURLY_WINDOW_MS));
        }
        
        // Remove empty message lists
        userMessageHistory.entrySet().removeIf(entry -> entry.getValue().isEmpty());
        
        // Clean up expired rate limits
        rateLimitExpiryTime.entrySet().removeIf(entry -> entry.getValue() < currentTime);
        
        Log.d(TAG, "Cleanup completed - Tracking " + userMessageHistory.size() + " users");
    }
    
    /**
     * Reset all spam tracking for a user (admin function)
     */
    public void resetUserTracking(String userEmail) {
        userMessageHistory.remove(userEmail);
        lastMessageTime.remove(userEmail);
        minuteMessageCounts.remove(userEmail);
        hourlyMessageCounts.remove(userEmail);
        rateLimitExpiryTime.remove(userEmail);
        
        Log.i(TAG, "Reset spam tracking for user: " + userEmail);
    }
    
    /**
     * Clear all spam detection data
     */
    public void clearAllData() {
        userMessageHistory.clear();
        lastMessageTime.clear();
        minuteMessageCounts.clear();
        hourlyMessageCounts.clear();
        rateLimitExpiryTime.clear();
        
        spamPrefs.edit().clear().apply();
        
        Log.i(TAG, "All spam detection data cleared");
    }
}