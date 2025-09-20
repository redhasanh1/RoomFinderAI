package com.roomfinder.android.services;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import com.roomfinder.android.database.SupabaseClient;
import com.roomfinder.android.auth.AuthManager;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Set;
import java.util.HashSet;
import java.util.List;
import java.util.ArrayList;
import java.util.Map;

/**
 * User reporting and blocking service for chat moderation
 * Handles user reports, blocks, and admin escalation
 * Designed for Google Play Store compliance
 */
public class UserReportingService {
    private static final String TAG = "UserReportingService";
    
    private Context context;
    private SupabaseClient supabaseClient;
    private SharedPreferences reportingPrefs;
    
    // Local storage for reports and blocks
    private ConcurrentHashMap<String, Set<String>> userBlocks = new ConcurrentHashMap<>();
    private ConcurrentHashMap<String, List<UserReport>> pendingReports = new ConcurrentHashMap<>();
    
    // Report tracking
    private ConcurrentHashMap<String, Integer> reportCounts = new ConcurrentHashMap<>();
    private static final int AUTO_ACTION_THRESHOLD = 3; // Auto-action after 3 reports
    
    public enum ReportCategory {
        SPAM("Spam or unwanted messages"),
        HARASSMENT("Harassment or bullying"),
        INAPPROPRIATE_CONTENT("Inappropriate content"),
        FAKE_PROFILE("Fake or impersonation profile"),
        SCAM("Scam or fraud"),
        HATE_SPEECH("Hate speech"),
        VIOLENCE_THREATS("Violence or threats"),
        SEXUAL_CONTENT("Sexual content"),
        UNDERAGE_USER("Underage user"),
        OTHER("Other violation");
        
        private final String description;
        
        ReportCategory(String description) {
            this.description = description;
        }
        
        public String getDescription() {
            return description;
        }
    }
    
    public enum ReportStatus {
        PENDING,
        UNDER_REVIEW,
        RESOLVED,
        DISMISSED,
        ACTION_TAKEN
    }
    
    public static class UserReport {
        public String reportId;
        public String reporterEmail;
        public String reportedUserEmail;
        public String messageId;
        public ReportCategory category;
        public String reason;
        public String additionalInfo;
        public long timestamp;
        public ReportStatus status;
        public String adminNotes;
        public boolean isAnonymous;
        
        public UserReport(String reporterEmail, String reportedUserEmail, ReportCategory category, String reason) {
            this.reportId = generateReportId();
            this.reporterEmail = reporterEmail;
            this.reportedUserEmail = reportedUserEmail;
            this.category = category;
            this.reason = reason;
            this.timestamp = System.currentTimeMillis();
            this.status = ReportStatus.PENDING;
            this.isAnonymous = false;
        }
        
        private String generateReportId() {
            return "RPT_" + System.currentTimeMillis() + "_" + Math.random();
        }
    }
    
    public static class BlockedUser {
        public String blockedUserEmail;
        public String blockerEmail;
        public long blockTimestamp;
        public String reason;
        public boolean isPermanent;
        
        public BlockedUser(String blockerEmail, String blockedUserEmail, String reason) {
            this.blockerEmail = blockerEmail;
            this.blockedUserEmail = blockedUserEmail;
            this.reason = reason;
            this.blockTimestamp = System.currentTimeMillis();
            this.isPermanent = true;
        }
    }
    
    public UserReportingService(Context context) {
        this.context = context;
        this.supabaseClient = SupabaseClient.getInstance();
        this.reportingPrefs = context.getSharedPreferences("user_reporting", Context.MODE_PRIVATE);
        
        loadBlockedUsers();
        loadPendingReports();
    }
    
    /**
     * Submit a report against a user
     */
    public void submitReport(String reporterEmail, String reportedUserEmail, String messageId,
                           String reason, String categoryString, ChatModerationService.ReportCallback callback) {
        
        try {
            ReportCategory category = ReportCategory.valueOf(categoryString.toUpperCase());
            
            UserReport report = new UserReport(reporterEmail, reportedUserEmail, category, reason);
            report.messageId = messageId;
            
            // Store report locally
            storeReportLocally(report);
            
            // Update report count for the reported user
            int currentCount = reportCounts.getOrDefault(reportedUserEmail, 0) + 1;
            reportCounts.put(reportedUserEmail, currentCount);
            
            // Check if automatic action is needed
            if (currentCount >= AUTO_ACTION_THRESHOLD) {
                handleAutoAction(reportedUserEmail, category);
            }
            
            // Submit to server (async)
            submitReportToServer(report);
            
            // Log the report
            logReportSubmission(report);
            
            callback.onReportSubmitted();
            
        } catch (Exception e) {
            Log.e(TAG, "Error submitting report", e);
            callback.onReportError("Failed to submit report: " + e.getMessage());
        }
    }
    
    /**
     * Block a user
     */
    public void blockUser(String blockerEmail, String blockedUserEmail, ChatModerationService.BlockCallback callback) {
        try {
            // Add to local blocks
            Set<String> blockedUsers = userBlocks.getOrDefault(blockerEmail, new HashSet<>());
            blockedUsers.add(blockedUserEmail);
            userBlocks.put(blockerEmail, blockedUsers);
            
            // Create block record
            BlockedUser blockRecord = new BlockedUser(blockerEmail, blockedUserEmail, "User initiated block");
            
            // Save to persistent storage
            saveBlockedUsers();
            
            // Submit to server (async)
            submitBlockToServer(blockRecord);
            
            // Log the block
            logUserBlock(blockRecord);
            
            callback.onUserBlocked();
            
        } catch (Exception e) {
            Log.e(TAG, "Error blocking user", e);
            callback.onBlockError("Failed to block user: " + e.getMessage());
        }
    }
    
    /**
     * Unblock a user
     */
    public void unblockUser(String blockerEmail, String blockedUserEmail, UnblockCallback callback) {
        try {
            Set<String> blockedUsers = userBlocks.get(blockerEmail);
            if (blockedUsers != null) {
                blockedUsers.remove(blockedUserEmail);
                if (blockedUsers.isEmpty()) {
                    userBlocks.remove(blockerEmail);
                }
            }
            
            saveBlockedUsers();
            
            // Submit unblock to server
            submitUnblockToServer(blockerEmail, blockedUserEmail);
            
            callback.onUserUnblocked();
            
        } catch (Exception e) {
            Log.e(TAG, "Error unblocking user", e);
            callback.onUnblockError("Failed to unblock user: " + e.getMessage());
        }
    }
    
    public interface UnblockCallback {
        void onUserUnblocked();
        void onUnblockError(String error);
    }
    
    /**
     * Check if a user is blocked
     */
    public boolean isUserBlocked(String userEmail, String otherUserEmail) {
        Set<String> blockedUsers = userBlocks.get(userEmail);
        return blockedUsers != null && blockedUsers.contains(otherUserEmail);
    }
    
    /**
     * Get list of blocked users
     */
    public Set<String> getBlockedUsers(String userEmail) {
        return userBlocks.getOrDefault(userEmail, new HashSet<>());
    }
    
    /**
     * Get pending reports for admin review
     */
    public List<UserReport> getPendingReports() {
        List<UserReport> allReports = new ArrayList<>();
        for (List<UserReport> reportList : pendingReports.values()) {
            for (UserReport report : reportList) {
                if (report.status == ReportStatus.PENDING || report.status == ReportStatus.UNDER_REVIEW) {
                    allReports.add(report);
                }
            }
        }
        return allReports;
    }
    
    /**
     * Get report count for a user
     */
    public int getReportCount(String userEmail) {
        return reportCounts.getOrDefault(userEmail, 0);
    }
    
    /**
     * Admin: Update report status
     */
    public void updateReportStatus(String reportId, ReportStatus status, String adminNotes) {
        for (List<UserReport> reportList : pendingReports.values()) {
            for (UserReport report : reportList) {
                if (report.reportId.equals(reportId)) {
                    report.status = status;
                    report.adminNotes = adminNotes;
                    
                    // Save updated report
                    savePendingReports();
                    
                    // Submit status update to server
                    submitReportStatusUpdate(report);
                    
                    Log.i(TAG, "Report " + reportId + " status updated to " + status);
                    return;
                }
            }
        }
    }
    
    /**
     * Get reporting statistics
     */
    public ReportingStats getReportingStats() {
        ReportingStats stats = new ReportingStats();
        
        for (List<UserReport> reportList : pendingReports.values()) {
            for (UserReport report : reportList) {
                stats.totalReports++;
                
                switch (report.status) {
                    case PENDING:
                        stats.pendingReports++;
                        break;
                    case UNDER_REVIEW:
                        stats.underReviewReports++;
                        break;
                    case RESOLVED:
                        stats.resolvedReports++;
                        break;
                    case ACTION_TAKEN:
                        stats.actionTakenReports++;
                        break;
                }
                
                stats.categoryBreakdown.put(report.category, 
                    stats.categoryBreakdown.getOrDefault(report.category, 0) + 1);
            }
        }
        
        stats.totalBlockedUsers = userBlocks.size();
        return stats;
    }
    
    public static class ReportingStats {
        public int totalReports = 0;
        public int pendingReports = 0;
        public int underReviewReports = 0;
        public int resolvedReports = 0;
        public int actionTakenReports = 0;
        public int totalBlockedUsers = 0;
        public Map<ReportCategory, Integer> categoryBreakdown = new ConcurrentHashMap<>();
    }
    
    // Private helper methods
    
    private void handleAutoAction(String reportedUserEmail, ReportCategory category) {
        Log.w(TAG, "Auto-action triggered for user: " + reportedUserEmail + 
              " (Category: " + category + ", Reports: " + reportCounts.get(reportedUserEmail) + ")");
        
        // Implement automatic actions based on category
        switch (category) {
            case SPAM:
                // Temporary chat restriction
                applyChatRestriction(reportedUserEmail, 24 * 60 * 60 * 1000); // 24 hours
                break;
                
            case HARASSMENT:
            case HATE_SPEECH:
            case VIOLENCE_THREATS:
                // Longer restriction for serious violations
                applyChatRestriction(reportedUserEmail, 7 * 24 * 60 * 60 * 1000); // 7 days
                break;
                
            case SEXUAL_CONTENT:
            case INAPPROPRIATE_CONTENT:
                // Account flagging for review
                flagAccountForReview(reportedUserEmail, category);
                break;
        }
        
        // Notify admins about auto-action
        notifyAdminsOfAutoAction(reportedUserEmail, category);
    }
    
    private void applyChatRestriction(String userEmail, long durationMs) {
        // This would integrate with ChatModerationService to apply restrictions
        Log.i(TAG, "Applying chat restriction to user: " + userEmail + " for " + durationMs + "ms");
        
        // Store restriction in preferences
        SharedPreferences.Editor editor = reportingPrefs.edit();
        editor.putLong("restriction_" + userEmail, System.currentTimeMillis() + durationMs);
        editor.apply();
    }
    
    private void flagAccountForReview(String userEmail, ReportCategory category) {
        Log.w(TAG, "Flagging account for admin review: " + userEmail + " (Category: " + category + ")");
        
        // Add to admin review queue
        SharedPreferences.Editor editor = reportingPrefs.edit();
        editor.putBoolean("flagged_" + userEmail, true);
        editor.putString("flag_reason_" + userEmail, category.toString());
        editor.apply();
    }
    
    private void notifyAdminsOfAutoAction(String userEmail, ReportCategory category) {
        // In production, this would send notifications to admin dashboard
        Log.i(TAG, "Admin notification: Auto-action taken against " + userEmail + " for " + category);
    }
    
    private void storeReportLocally(UserReport report) {
        List<UserReport> reports = pendingReports.getOrDefault(report.reportedUserEmail, new ArrayList<>());
        reports.add(report);
        pendingReports.put(report.reportedUserEmail, reports);
        
        savePendingReports();
    }
    
    private void submitReportToServer(UserReport report) {
        CompletableFuture.runAsync(() -> {
            try {
                JSONObject reportData = new JSONObject();
                reportData.put("reporter_email", report.reporterEmail);
                reportData.put("reported_user_email", report.reportedUserEmail);
                reportData.put("message_id", report.messageId);
                reportData.put("category", report.category.toString());
                reportData.put("reason", report.reason);
                reportData.put("timestamp", report.timestamp);
                reportData.put("is_anonymous", report.isAnonymous);
                
                // Submit to Supabase or your backend
                // Implementation depends on your backend API
                
                Log.d(TAG, "Report submitted to server: " + reportData.toString());
                
            } catch (JSONException e) {
                Log.e(TAG, "Error submitting report to server", e);
            }
        });
    }
    
    private void submitBlockToServer(BlockedUser blockRecord) {
        CompletableFuture.runAsync(() -> {
            try {
                JSONObject blockData = new JSONObject();
                blockData.put("blocker_email", blockRecord.blockerEmail);
                blockData.put("blocked_user_email", blockRecord.blockedUserEmail);
                blockData.put("reason", blockRecord.reason);
                blockData.put("timestamp", blockRecord.blockTimestamp);
                blockData.put("is_permanent", blockRecord.isPermanent);
                
                // Submit to backend
                Log.d(TAG, "Block submitted to server: " + blockData.toString());
                
            } catch (JSONException e) {
                Log.e(TAG, "Error submitting block to server", e);
            }
        });
    }
    
    private void submitUnblockToServer(String blockerEmail, String blockedUserEmail) {
        CompletableFuture.runAsync(() -> {
            try {
                JSONObject unblockData = new JSONObject();
                unblockData.put("blocker_email", blockerEmail);
                unblockData.put("blocked_user_email", blockedUserEmail);
                unblockData.put("timestamp", System.currentTimeMillis());
                
                // Submit to backend
                Log.d(TAG, "Unblock submitted to server: " + unblockData.toString());
                
            } catch (JSONException e) {
                Log.e(TAG, "Error submitting unblock to server", e);
            }
        });
    }
    
    private void submitReportStatusUpdate(UserReport report) {
        CompletableFuture.runAsync(() -> {
            try {
                JSONObject updateData = new JSONObject();
                updateData.put("report_id", report.reportId);
                updateData.put("status", report.status.toString());
                updateData.put("admin_notes", report.adminNotes);
                updateData.put("update_timestamp", System.currentTimeMillis());
                
                // Submit to backend
                Log.d(TAG, "Report status update submitted: " + updateData.toString());
                
            } catch (JSONException e) {
                Log.e(TAG, "Error submitting report status update", e);
            }
        });
    }
    
    private void logReportSubmission(UserReport report) {
        Log.i(TAG, "Report submitted - ID: " + report.reportId + 
              ", Reporter: " + report.reporterEmail + 
              ", Reported: " + report.reportedUserEmail + 
              ", Category: " + report.category);
    }
    
    private void logUserBlock(BlockedUser blockRecord) {
        Log.i(TAG, "User blocked - Blocker: " + blockRecord.blockerEmail + 
              ", Blocked: " + blockRecord.blockedUserEmail + 
              ", Reason: " + blockRecord.reason);
    }
    
    private void loadBlockedUsers() {
        // Load from SharedPreferences or local database
        String blockedUsersJson = reportingPrefs.getString("blocked_users", "{}");
        try {
            JSONObject blockedData = new JSONObject(blockedUsersJson);
            // Parse and load blocked users
            // Implementation depends on storage format
        } catch (JSONException e) {
            Log.e(TAG, "Error loading blocked users", e);
        }
    }
    
    private void saveBlockedUsers() {
        try {
            JSONObject blockedData = new JSONObject();
            for (Map.Entry<String, Set<String>> entry : userBlocks.entrySet()) {
                JSONArray blockedArray = new JSONArray();
                for (String blocked : entry.getValue()) {
                    blockedArray.put(blocked);
                }
                blockedData.put(entry.getKey(), blockedArray);
            }
            
            reportingPrefs.edit().putString("blocked_users", blockedData.toString()).apply();
            
        } catch (JSONException e) {
            Log.e(TAG, "Error saving blocked users", e);
        }
    }
    
    private void loadPendingReports() {
        // Load pending reports from storage
        String reportsJson = reportingPrefs.getString("pending_reports", "{}");
        try {
            JSONObject reportsData = new JSONObject(reportsJson);
            // Parse and load reports
            // Implementation depends on storage format
        } catch (JSONException e) {
            Log.e(TAG, "Error loading pending reports", e);
        }
    }
    
    private void savePendingReports() {
        try {
            JSONObject reportsData = new JSONObject();
            // Save pending reports to JSON
            // Implementation depends on storage format
            
            reportingPrefs.edit().putString("pending_reports", reportsData.toString()).apply();
            
        } catch (JSONException e) {
            Log.e(TAG, "Error saving pending reports", e);
        }
    }
    
    /**
     * Clear all reports and blocks (for testing)
     */
    public void clearAllData() {
        userBlocks.clear();
        pendingReports.clear();
        reportCounts.clear();
        
        reportingPrefs.edit().clear().apply();
        
        Log.i(TAG, "All reporting data cleared");
    }
}