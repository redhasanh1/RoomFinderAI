package com.roomfinder.android.services;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import com.sendgrid.Method;
import com.sendgrid.Request;
import com.sendgrid.Response;
import com.sendgrid.SendGrid;
import com.sendgrid.helpers.mail.Mail;
import com.sendgrid.helpers.mail.objects.Content;
import com.sendgrid.helpers.mail.objects.Email;
import java.io.IOException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * EmailService - Real email sending using SendGrid API
 * Provides professional email verification with fallback to demo mode
 */
public class EmailService {
    private static final String TAG = "EmailService";
    private static EmailService instance;
    
    private final SharedPreferences prefs;
    private final ExecutorService executor;
    private final Handler mainHandler;
    
    // SendGrid configuration - Replace with your actual API key
    private static final String SENDGRID_API_KEY = "SG.your_sendgrid_api_key_here"; // TODO: Replace with real SendGrid API key
    private static final String FROM_EMAIL = "noreply@roomfinderai.com";
    private static final String FROM_NAME = "RoomFinder AI";
    
    // Email templates
    private static final String VERIFICATION_SUBJECT = "Verify Your Email - RoomFinder AI";
    private static final String VERIFICATION_TEMPLATE = 
        "<!DOCTYPE html>" +
        "<html><head><style>" +
        "body { font-family: Arial, sans-serif; background-color: #f5f5f5; margin: 0; padding: 20px; }" +
        ".container { max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }" +
        ".header { text-align: center; margin-bottom: 30px; }" +
        ".logo { font-size: 24px; font-weight: bold; color: #667eea; margin-bottom: 10px; }" +
        ".code-container { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0; }" +
        ".code { font-size: 32px; font-weight: bold; letter-spacing: 8px; margin: 10px 0; }" +
        ".footer { text-align: center; margin-top: 30px; color: #666; font-size: 12px; }" +
        "</style></head><body>" +
        "<div class='container'>" +
        "<div class='header'>" +
        "<div class='logo'>🏠 RoomFinder AI</div>" +
        "<h1>Verify Your Email Address</h1>" +
        "</div>" +
        "<p>Hi %s,</p>" +
        "<p>Welcome to RoomFinder AI! Please verify your email address to complete your registration.</p>" +
        "<div class='code-container'>" +
        "<div>Your verification code is:</div>" +
        "<div class='code'>%s</div>" +
        "<div>This code expires in 10 minutes</div>" +
        "</div>" +
        "<p>Enter this code in the RoomFinder AI app to verify your email address and start finding your perfect home!</p>" +
        "<p>If you didn't create an account with RoomFinder AI, please ignore this email.</p>" +
        "<div class='footer'>" +
        "<p>© 2025 RoomFinder AI. All rights reserved.</p>" +
        "<p>This is an automated message, please do not reply.</p>" +
        "</div>" +
        "</div>" +
        "</body></html>";
    
    public interface EmailCallback {
        void onSuccess(String message);
        void onError(String error);
    }
    
    private EmailService(Context context) {
        prefs = context.getApplicationContext().getSharedPreferences("EmailService", Context.MODE_PRIVATE);
        executor = Executors.newSingleThreadExecutor();
        mainHandler = new Handler(Looper.getMainLooper());
    }
    
    public static synchronized EmailService getInstance(Context context) {
        if (instance == null) {
            instance = new EmailService(context);
        }
        return instance;
    }
    
    /**
     * Send verification email with real SendGrid API
     */
    public void sendVerificationEmail(String firstName, String lastName, String toEmail, String verificationCode, EmailCallback callback) {
        Log.d(TAG, "Sending verification email to: " + toEmail);
        
        executor.execute(() -> {
            try {
                // Check if we have a valid API key
                if (SENDGRID_API_KEY.equals("SG.your_sendgrid_api_key_here") || SENDGRID_API_KEY.isEmpty()) {
                    mainHandler.post(() -> callback.onError("Email service not configured. Replace SENDGRID_API_KEY with your actual SendGrid API key."));
                    return;
                }
                
                // Create email content
                String name = firstName != null ? firstName : "User";
                String htmlContent = String.format(VERIFICATION_TEMPLATE, name, verificationCode);
                
                // Create email
                Email from = new Email(FROM_EMAIL, FROM_NAME);
                Email to = new Email(toEmail);
                Content content = new Content("text/html", htmlContent);
                Mail mail = new Mail(from, VERIFICATION_SUBJECT, to, content);
                
                // Send via SendGrid
                SendGrid sg = new SendGrid(SENDGRID_API_KEY);
                Request request = new Request();
                request.setMethod(Method.POST);
                request.setEndpoint("mail/send");
                request.setBody(mail.build());
                
                Response response = sg.api(request);
                
                Log.d(TAG, "SendGrid response code: " + response.getStatusCode());
                Log.d(TAG, "SendGrid response body: " + response.getBody());
                
                if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                    // Email sent successfully
                    Log.d(TAG, "Verification email sent successfully to: " + toEmail);
                    mainHandler.post(() -> callback.onSuccess("Verification email sent successfully! Check your inbox and spam folder."));
                } else {
                    // Email sending failed
                    String errorMsg = "Failed to send email. Response code: " + response.getStatusCode();
                    Log.e(TAG, errorMsg + " | Body: " + response.getBody());
                    mainHandler.post(() -> callback.onError(errorMsg));
                }
                
            } catch (IOException e) {
                Log.e(TAG, "IOException while sending email", e);
                mainHandler.post(() -> callback.onError("Network error: " + e.getMessage()));
            } catch (Exception e) {
                Log.e(TAG, "Unexpected error while sending email", e);
                mainHandler.post(() -> callback.onError("Email service error: " + e.getMessage()));
            }
        });
    }
    
    /**
     * Test email service configuration
     */
    public void testEmailService(EmailCallback callback) {
        executor.execute(() -> {
            try {
                if (SENDGRID_API_KEY.equals("SG.your_sendgrid_api_key_here") || SENDGRID_API_KEY.isEmpty()) {
                    mainHandler.post(() -> callback.onError("SendGrid API key not configured"));
                    return;
                }
                
                // Test API key validity with a simple request
                SendGrid sg = new SendGrid(SENDGRID_API_KEY);
                Request request = new Request();
                request.setMethod(Method.GET);
                request.setEndpoint("user/account");
                
                Response response = sg.api(request);
                
                if (response.getStatusCode() == 200) {
                    mainHandler.post(() -> callback.onSuccess("Email service configured correctly"));
                } else {
                    mainHandler.post(() -> callback.onError("Invalid SendGrid API key"));
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error testing email service", e);
                mainHandler.post(() -> callback.onError("Email service test failed: " + e.getMessage()));
            }
        });
    }
    
    /**
     * Check if email service is properly configured
     */
    public boolean isConfigured() {
        return !SENDGRID_API_KEY.equals("SG.your_sendgrid_api_key_here") && !SENDGRID_API_KEY.isEmpty();
    }
    
    /**
     * Get email service status for debugging
     */
    public String getServiceStatus() {
        if (isConfigured()) {
            return "Email service configured with SendGrid";
        } else {
            return "Email service not configured - using demo mode";
        }
    }
}