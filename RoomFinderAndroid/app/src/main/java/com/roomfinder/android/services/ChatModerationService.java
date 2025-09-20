package com.roomfinder.android.services;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;
import com.roomfinder.android.models.ChatMessage;
import com.roomfinder.android.database.SupabaseClient;
import com.roomfinder.android.auth.AuthManager;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import org.tensorflow.lite.Interpreter;
import java.util.Arrays;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.List;
import java.util.ArrayList;
import java.util.Map;

/**
 * Core chat moderation service for Google Play Store compliance
 * Handles content filtering, user reports, and policy enforcement
 */
public class ChatModerationService {
    private static final String TAG = "ChatModerationService";
    private static ChatModerationService instance;
    
    private Context context;
    private ContentFilter contentFilter;
    private UserReportingService reportingService;
    private SpamDetectionService spamDetectionService;
    private SupabaseClient supabaseClient;
    private SharedPreferences moderationPrefs;
    private NudityDetectionModel nudityDetectionModel;
    
    // Moderation result cache
    private ConcurrentHashMap<String, ModerationResult> moderationCache = new ConcurrentHashMap<>();
    private static final long CACHE_DURATION = 5 * 60 * 1000; // 5 minutes
    
    // User restrictions tracking
    private ConcurrentHashMap<String, UserRestrictions> userRestrictions = new ConcurrentHashMap<>();
    
    // Moderation statistics
    private ModerationStats stats = new ModerationStats();
    
    public enum ModerationAction {
        ALLOW,           // Message is clean, allow through
        BLOCK,           // Block message entirely
        FLAG_FOR_REVIEW, // Allow but flag for manual review
        WARN_USER,       // Show warning to user
        RATE_LIMIT       // Apply rate limiting
    }
    
    public enum ViolationType {
        PROFANITY,
        INAPPROPRIATE_CONTENT,
        SPAM,
        HARASSMENT,
        PERSONAL_INFO,
        COMMERCIAL_CONTENT,
        HATE_SPEECH,
        VIOLENCE_THREATS,
        SEXUAL_CONTENT,
        UNDERAGE_INAPPROPRIATE
    }
    
    public static class ModerationResult {
        public ModerationAction action;
        public ViolationType violationType;
        public String reason;
        public int confidence; // 0-100
        public long timestamp;
        public boolean requiresHumanReview;
        
        public ModerationResult(ModerationAction action, String reason) {
            this.action = action;
            this.reason = reason;
            this.timestamp = System.currentTimeMillis();
            this.confidence = 100;
            this.requiresHumanReview = false;
        }
        
        public ModerationResult(ModerationAction action, ViolationType violationType, String reason, int confidence) {
            this.action = action;
            this.violationType = violationType;
            this.reason = reason;
            this.confidence = confidence;
            this.timestamp = System.currentTimeMillis();
            this.requiresHumanReview = confidence < 80; // Low confidence requires review
        }
        
        public boolean isExpired() {
            return System.currentTimeMillis() - timestamp > CACHE_DURATION;
        }
    }
    
    public static class UserRestrictions {
        public boolean isChatRestricted;
        public boolean isFileUploadRestricted;
        public long restrictionEndTime;
        public int warningCount;
        public int violationCount;
        public List<String> violationHistory;
        
        public UserRestrictions() {
            this.violationHistory = new ArrayList<>();
        }
        
        public boolean isRestricted() {
            return isChatRestricted && System.currentTimeMillis() < restrictionEndTime;
        }
    }
    
    public static class ModerationStats {
        public int totalMessagesProcessed = 0;
        public int messagesBlocked = 0;
        public int messagesFlagged = 0;
        public int warningsIssued = 0;
        public Map<ViolationType, Integer> violationCounts = new ConcurrentHashMap<>();
        
        public void recordViolation(ViolationType type) {
            violationCounts.put(type, violationCounts.getOrDefault(type, 0) + 1);
        }
    }
    
    public interface ModerationCallback {
        void onModerationComplete(ModerationResult result);
        void onModerationError(String error);
    }
    
    private ChatModerationService(Context context) {
        this.context = context.getApplicationContext();
        this.supabaseClient = SupabaseClient.getInstance();
        this.moderationPrefs = context.getSharedPreferences("chat_moderation", Context.MODE_PRIVATE);
        
        // Initialize sub-services
        this.contentFilter = new ContentFilter(context);
        this.reportingService = new UserReportingService(context);
        this.spamDetectionService = new SpamDetectionService(context);
        this.nudityDetectionModel = new NudityDetectionModel(context);
        
        loadUserRestrictions();
    }
    
    public static synchronized ChatModerationService getInstance(Context context) {
        if (instance == null) {
            instance = new ChatModerationService(context);
        }
        return instance;
    }
    
    /**
     * Main moderation entry point - validates message before sending
     */
    public void moderateMessage(ChatMessage message, ModerationCallback callback) {
        stats.totalMessagesProcessed++;
        
        // Check cache first
        String cacheKey = generateCacheKey(message);
        ModerationResult cached = moderationCache.get(cacheKey);
        if (cached != null && !cached.isExpired()) {
            callback.onModerationComplete(cached);
            return;
        }
        
        // Check user restrictions
        UserRestrictions restrictions = getUserRestrictions(message.getSenderEmail());
        if (restrictions.isRestricted()) {
            ModerationResult result = new ModerationResult(ModerationAction.BLOCK, "User is currently restricted from sending messages");
            callback.onModerationComplete(result);
            return;
        }
        
        // Perform comprehensive moderation check
        CompletableFuture.supplyAsync(() -> {
            try {
                return performModerationChecks(message);
            } catch (Exception e) {
                Log.e(TAG, "Error during moderation", e);
                return new ModerationResult(ModerationAction.ALLOW, "Moderation error - allowing message");
            }
        }).thenAccept(result -> {
            // Cache result
            moderationCache.put(cacheKey, result);
            
            // Update statistics
            updateStatistics(result);
            
            // Log moderation action
            logModerationAction(message, result);
            
            // Handle violations
            if (result.action != ModerationAction.ALLOW) {
                handleViolation(message.getSenderEmail(), result);
            }
            
            callback.onModerationComplete(result);
        }).exceptionally(throwable -> {
            Log.e(TAG, "Moderation error", throwable);
            callback.onModerationError("Moderation service error");
            return null;
        });
    }
    
    /**
     * Moderate file attachments with enhanced image nudity detection
     */
    public void moderateFile(String filePath, String fileName, String fileType, String userEmail, ModerationCallback callback) {
        CompletableFuture.supplyAsync(() -> {
            try {
                // Check file type restrictions
                if (!isAllowedFileType(fileType)) {
                    return new ModerationResult(ModerationAction.BLOCK, ViolationType.INAPPROPRIATE_CONTENT, 
                        "File type not allowed", 100);
                }
                
                // Check file size
                if (!isAllowedFileSize(filePath)) {
                    return new ModerationResult(ModerationAction.BLOCK, ViolationType.SPAM, 
                        "File size exceeds limit", 100);
                }
                
                // Enhanced image content analysis for nudity detection
                if (isImageFile(fileType)) {
                    NudityDetectionResult nudityResult = nudityDetectionModel.analyzeImage(filePath);
                    
                    if (nudityResult.hasNudity) {
                        return new ModerationResult(ModerationAction.BLOCK, ViolationType.SEXUAL_CONTENT,
                            "Nudity detected in image - confidence: " + nudityResult.confidence + "%", 
                            nudityResult.confidence);
                    }
                    
                    // Check for inappropriate poses or suggestive content
                    if (nudityResult.isSuggestive && nudityResult.confidence > 70) {
                        return new ModerationResult(ModerationAction.FLAG_FOR_REVIEW, ViolationType.SEXUAL_CONTENT,
                            "Suggestive content detected in image", nudityResult.confidence);
                    }
                    
                    Log.i(TAG, "Image passed nudity detection - confidence: " + nudityResult.confidence + "%");
                }
                
                // File passed all moderation checks
                return new ModerationResult(ModerationAction.ALLOW, "File passed all moderation checks");
                
            } catch (Exception e) {
                Log.e(TAG, "File moderation error", e);
                // Block file if moderation fails for safety
                return new ModerationResult(ModerationAction.BLOCK, "File moderation error - blocking for safety");
            }
        }).thenAccept(callback::onModerationComplete);
    }
    
    /**
     * Report a message or user
     */
    public void reportContent(String reporterEmail, String reportedUserEmail, String messageId, 
                            String reason, String category, ReportCallback callback) {
        reportingService.submitReport(reporterEmail, reportedUserEmail, messageId, reason, category, callback);
    }
    
    /**
     * Block a user
     */
    public void blockUser(String blockerEmail, String blockedUserEmail, BlockCallback callback) {
        reportingService.blockUser(blockerEmail, blockedUserEmail, callback);
    }
    
    /**
     * Check if a user is blocked
     */
    public boolean isUserBlocked(String userEmail, String otherUserEmail) {
        return reportingService.isUserBlocked(userEmail, otherUserEmail);
    }
    
    // Interface definitions
    public interface ReportCallback {
        void onReportSubmitted();
        void onReportError(String error);
    }
    
    public interface BlockCallback {
        void onUserBlocked();
        void onBlockError(String error);
    }
    
    /**
     * Get moderation statistics
     */
    public ModerationStats getModerationStats() {
        return stats;
    }
    
    /**
     * Get user restrictions
     */
    public UserRestrictions getUserRestrictions(String userEmail) {
        return userRestrictions.getOrDefault(userEmail, new UserRestrictions());
    }
    
    // Private methods
    
    private ModerationResult performModerationChecks(ChatMessage message) {
        String content = message.getContent();
        String senderEmail = message.getSenderEmail();
        
        // 1. Content filtering
        ContentFilter.FilterResult contentResult = contentFilter.filterContent(content);
        if (contentResult.isViolation()) {
            return new ModerationResult(
                contentResult.isHighSeverity() ? ModerationAction.BLOCK : ModerationAction.FLAG_FOR_REVIEW,
                contentResult.getViolationType(),
                contentResult.getReason(),
                contentResult.getConfidence()
            );
        }
        
        // 2. Spam detection
        if (spamDetectionService.isSpam(message)) {
            return new ModerationResult(ModerationAction.RATE_LIMIT, ViolationType.SPAM, 
                "Message flagged as spam", 90);
        }
        
        // 3. Rate limiting check
        if (spamDetectionService.isRateLimited(senderEmail)) {
            return new ModerationResult(ModerationAction.RATE_LIMIT, ViolationType.SPAM, 
                "User is sending messages too quickly", 100);
        }
        
        // 4. Personal information detection
        if (contentFilter.containsPersonalInfo(content)) {
            return new ModerationResult(ModerationAction.WARN_USER, ViolationType.PERSONAL_INFO, 
                "Message may contain personal information", 70);
        }
        
        // Message passed all checks
        return new ModerationResult(ModerationAction.ALLOW, "Message passed moderation checks");
    }
    
    private void handleViolation(String userEmail, ModerationResult result) {
        UserRestrictions restrictions = getUserRestrictions(userEmail);
        restrictions.violationCount++;
        restrictions.violationHistory.add(result.violationType + ": " + result.reason);
        
        // Progressive punishment system
        if (restrictions.violationCount >= 3) {
            // Temporary chat restriction
            restrictions.isChatRestricted = true;
            restrictions.restrictionEndTime = System.currentTimeMillis() + (24 * 60 * 60 * 1000); // 24 hours
        } else if (restrictions.violationCount >= 2) {
            restrictions.warningCount++;
        }
        
        userRestrictions.put(userEmail, restrictions);
        saveUserRestrictions();
        
        // Log violation for admin review
        logViolationForReview(userEmail, result);
    }
    
    private void updateStatistics(ModerationResult result) {
        switch (result.action) {
            case BLOCK:
                stats.messagesBlocked++;
                break;
            case FLAG_FOR_REVIEW:
                stats.messagesFlagged++;
                break;
            case WARN_USER:
                stats.warningsIssued++;
                break;
        }
        
        if (result.violationType != null) {
            stats.recordViolation(result.violationType);
        }
    }
    
    private void logModerationAction(ChatMessage message, ModerationResult result) {
        try {
            JSONObject logEntry = new JSONObject();
            logEntry.put("message_id", message.getId());
            logEntry.put("sender_email", message.getSenderEmail());
            logEntry.put("action", result.action.toString());
            logEntry.put("reason", result.reason);
            logEntry.put("confidence", result.confidence);
            logEntry.put("timestamp", System.currentTimeMillis());
            
            // Log to local storage and optionally to server
            Log.i(TAG, "Moderation action: " + logEntry.toString());
            
        } catch (JSONException e) {
            Log.e(TAG, "Error logging moderation action", e);
        }
    }
    
    private void logViolationForReview(String userEmail, ModerationResult result) {
        if (result.requiresHumanReview) {
            // In a production app, this would send to admin review system
            Log.w(TAG, "Violation requires human review - User: " + userEmail + ", Reason: " + result.reason);
        }
    }
    
    private String generateCacheKey(ChatMessage message) {
        // Simple hash of content for caching
        return String.valueOf(message.getContent().hashCode());
    }
    
    private boolean isAllowedFileType(String fileType) {
        // Define allowed file types for Google Play compliance
        String[] allowedTypes = {
            "image/jpeg", "image/png", "image/gif", "image/webp",
            "application/pdf", "text/plain",
            "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        };
        
        if (fileType == null) return false;
        
        for (String allowed : allowedTypes) {
            if (fileType.toLowerCase().contains(allowed.toLowerCase())) {
                return true;
            }
        }
        return false;
    }
    
    private boolean isAllowedFileSize(String filePath) {
        // Check file size limit (e.g., 10MB)
        try {
            java.io.File file = new java.io.File(filePath);
            long sizeInMB = file.length() / (1024 * 1024);
            return sizeInMB <= 10; // 10MB limit
        } catch (Exception e) {
            Log.e(TAG, "Error checking file size", e);
            return false;
        }
    }
    
    private boolean isImageFile(String fileType) {
        if (fileType == null) return false;
        return fileType.toLowerCase().startsWith("image/");
    }
    
    private void loadUserRestrictions() {
        // Load user restrictions from persistent storage
        // Implementation would depend on your storage preference
    }
    
    private void saveUserRestrictions() {
        // Save user restrictions to persistent storage
        // Implementation would depend on your storage preference
    }
    
    /**
     * Enable/disable strict moderation mode
     */
    public void setStrictMode(boolean enabled) {
        moderationPrefs.edit().putBoolean("strict_mode", enabled).apply();
        contentFilter.setStrictMode(enabled);
    }
    
    public boolean isStrictModeEnabled() {
        return moderationPrefs.getBoolean("strict_mode", false);
    }
    
    /**
     * Clear moderation cache
     */
    public void clearCache() {
        moderationCache.clear();
    }
    
    /**
     * Check if moderation service is healthy
     */
    public boolean isHealthy() {
        return contentFilter != null && reportingService != null && 
               spamDetectionService != null && nudityDetectionModel != null;
    }
    
    /**
     * Inner class for ML-based nudity detection
     */
    private static class NudityDetectionModel {
        private static final String TAG = "NudityDetectionModel";
        private static final int IMAGE_SIZE = 224; // Standard image classification size
        private static final float NUDITY_THRESHOLD = 0.8f; // 80% confidence threshold
        private static final float SUGGESTIVE_THRESHOLD = 0.7f; // 70% confidence for suggestive content
        
        private Context context;
        private boolean modelLoaded = false;
        
        public NudityDetectionModel(Context context) {
            this.context = context;
            // In a production app, you would load a pre-trained TensorFlow Lite model here
            // For now, we'll use heuristic analysis
            this.modelLoaded = true;
            Log.d(TAG, "Nudity detection model initialized");
        }
        
        public NudityDetectionResult analyzeImage(String imagePath) {
            try {
                if (!modelLoaded) {
                    Log.w(TAG, "Model not loaded, using fallback detection");
                    return performFallbackAnalysis(imagePath);
                }
                
                // Load and preprocess image
                Bitmap bitmap = loadAndPreprocessImage(imagePath);
                if (bitmap == null) {
                    return new NudityDetectionResult(false, false, 0);
                }
                
                // Perform heuristic analysis (in production, use ML model)
                return performHeuristicAnalysis(bitmap);
                
            } catch (Exception e) {
                Log.e(TAG, "Error analyzing image", e);
                // Return safe result on error
                return new NudityDetectionResult(false, false, 0);
            }
        }
        
        private Bitmap loadAndPreprocessImage(String imagePath) {
            try {
                BitmapFactory.Options options = new BitmapFactory.Options();
                options.inJustDecodeBounds = true;
                BitmapFactory.decodeFile(imagePath, options);
                
                // Calculate sample size to resize image efficiently
                int sampleSize = 1;
                while (options.outWidth / sampleSize > IMAGE_SIZE || options.outHeight / sampleSize > IMAGE_SIZE) {
                    sampleSize *= 2;
                }
                
                options.inJustDecodeBounds = false;
                options.inSampleSize = sampleSize;
                
                Bitmap bitmap = BitmapFactory.decodeFile(imagePath, options);
                if (bitmap != null) {
                    // Resize to standard size for analysis
                    return Bitmap.createScaledBitmap(bitmap, IMAGE_SIZE, IMAGE_SIZE, true);
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error loading image", e);
            }
            return null;
        }
        
        private NudityDetectionResult performHeuristicAnalysis(Bitmap bitmap) {
            // Heuristic analysis based on skin tone detection and content analysis
            // In production, replace with proper ML model inference
            
            int width = bitmap.getWidth();
            int height = bitmap.getHeight();
            int totalPixels = width * height;
            int skinPixels = 0;
            int darkPixels = 0;
            
            // Analyze pixel colors for skin tones and inappropriate content indicators
            for (int x = 0; x < width; x += 4) { // Sample every 4th pixel for efficiency
                for (int y = 0; y < height; y += 4) {
                    int pixel = bitmap.getPixel(x, y);
                    
                    int red = (pixel >> 16) & 0xFF;
                    int green = (pixel >> 8) & 0xFF;
                    int blue = pixel & 0xFF;
                    
                    // Basic skin tone detection heuristic
                    if (isSkinTone(red, green, blue)) {
                        skinPixels++;
                    }
                    
                    // Check for very dark areas (could indicate inappropriate poses)
                    if (red < 30 && green < 30 && blue < 30) {
                        darkPixels++;
                    }
                }
            }
            
            // Calculate skin percentage
            float skinPercentage = (float) skinPixels / (totalPixels / 16) * 100; // Adjust for sampling
            float darkPercentage = (float) darkPixels / (totalPixels / 16) * 100;
            
            // Determine nudity likelihood based on heuristics
            boolean hasNudity = skinPercentage > 60; // More than 60% skin tone
            boolean isSuggestive = skinPercentage > 40 || (skinPercentage > 25 && darkPercentage > 30);
            
            int confidence = Math.min(95, (int) (skinPercentage * 1.5));
            
            Log.d(TAG, String.format("Image analysis: skin=%.1f%%, dark=%.1f%%, nudity=%s, suggestive=%s, confidence=%d",
                    skinPercentage, darkPercentage, hasNudity, isSuggestive, confidence));
            
            return new NudityDetectionResult(hasNudity, isSuggestive, confidence);
        }
        
        private boolean isSkinTone(int red, int green, int blue) {
            // Simple skin tone detection heuristic
            // Skin tones typically have: R > G > B, with specific ranges
            return red > 95 && green > 40 && blue > 20 &&
                   red > green && green > blue &&
                   red - green > 15 && red - blue > 15;
        }
        
        private NudityDetectionResult performFallbackAnalysis(String imagePath) {
            // Fallback when ML model is not available
            // Check file size and basic metadata
            try {
                File file = new File(imagePath);
                long fileSize = file.length();
                
                // Very large images might be more likely to be inappropriate
                // This is a very basic heuristic
                if (fileSize > 5 * 1024 * 1024) { // > 5MB
                    return new NudityDetectionResult(false, true, 30); // Flag as suggestive for review
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Fallback analysis error", e);
            }
            
            return new NudityDetectionResult(false, false, 0);
        }
    }
    
    /**
     * Result class for nudity detection
     */
    private static class NudityDetectionResult {
        public final boolean hasNudity;
        public final boolean isSuggestive;
        public final int confidence; // 0-100
        
        public NudityDetectionResult(boolean hasNudity, boolean isSuggestive, int confidence) {
            this.hasNudity = hasNudity;
            this.isSuggestive = isSuggestive;
            this.confidence = Math.max(0, Math.min(100, confidence)); // Clamp to 0-100
        }
    }
}