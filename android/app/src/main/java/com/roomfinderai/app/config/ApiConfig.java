package com.roomfinderai.app.config;

import com.roomfinderai.app.BuildConfig;

public class ApiConfig {
    
    // Private constructor to prevent instantiation
    private ApiConfig() {
        throw new UnsupportedOperationException("This is a utility class and cannot be instantiated");
    }
    
    // Local development configuration values
    private static final String LOCAL_OPENAI_API_KEY = "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";
    private static final String LOCAL_OPENAI_MODEL = "gpt-3.5-turbo";
    private static final String LOCAL_OPENAI_ORG_ID = "org-EPHQ1A3u0XIUZml6JABMgZzg";
    private static final String LOCAL_SUPABASE_URL = "https://fkktwhjybuflxqzopaex.supabase.co/";
   private static final String LOCAL_SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs";
    private static final String LOCAL_GOOGLE_API_KEY = "AIzaSyBzE8cPfeO5YkmpJFc8SLtVsz_eGB-wYYM";
    private static final String LOCAL_STRIPE_PUBLISHABLE_KEY = "pk_test_51Rb76iEAbICBlW3MMGkAX58TJHxCWd3MoBD4PXwzdFnXi2EsFrf0iWUDvRVtoOfNzFMnd0cCkGMb2MAcAx4JIPTB00kPkbVXTV";
    private static final String LOCAL_STRIPE_SECRET_KEY = "sk_test_51Rb76iEAbICBlW3Mgdi3NWT4Xh7HBxohdq4Rs9N4LjhT1i4XtgQQvrG2k9sJQBWtmM2Bndjkhb99BBoUY7KlB5RI00nJTMPBfV";
    private static final String LOCAL_BREVO_API_KEY = "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";
    
    // Azure APIs
    private static final String LOCAL_AZURE_DOC_INTELLIGENCE_ENDPOINT = "https://roomfinder-document-intelligence.cognitiveservices.azure.com/";
    private static final String LOCAL_AZURE_DOC_INTELLIGENCE_KEY = "3e4UdQa89vVlUe2iswrEYObX4R3QepgprHQq8x6Wo324sifT9fCHJQQJ99BFACYeBjFXJ3w3AAALACOGBtbQ";
    private static final String LOCAL_AZURE_FACE_ENDPOINT = "https://roomfinder-face-api.cognitiveservices.azure.com/";
    private static final String LOCAL_AZURE_FACE_KEY = "17b0sARArOlfLsarJUXtBBsqu70hyCfXpVTNjD6W9qSZl4TXm8vXJQQJ99BFACYeBjFXJ3w3AAAKACOGJYtV";
    
    // Additional APIs
    private static final String LOCAL_RENTCAST_KEY = "3bc616ab43604dbb94000590c342b1a4";
    private static final String LOCAL_TURNSTILE_SITE_KEY = "0x4AAAAAABjjAXWppygcnbuz";
    private static final String LOCAL_TURNSTILE_SECRET_KEY = "0x4AAAAAABjjAf8v14eqofaYT7SrJ0cNDmA";
    // Helper method to determine if we should use local config
    private static boolean useLocalConfig() {
        return BuildConfig.USE_LOCAL_CONFIG;
    }
    
    // OpenAI Configuration
    public static String getOpenAiApiKey() {
        return useLocalConfig() ? LOCAL_OPENAI_API_KEY : BuildConfig.OPENAI_API_KEY;
    }
    
    public static String getOpenAiModel() {
        return LOCAL_OPENAI_MODEL; // Always use local for now
    }
    
    public static String getOpenAiOrgId() {
        return LOCAL_OPENAI_ORG_ID; // Always use local for now
    }
    
    // Supabase Configuration
    public static String getSupabaseUrl() {
        return useLocalConfig() ? LOCAL_SUPABASE_URL : BuildConfig.SUPABASE_URL;
    }
    
    public static String getSupabaseAnonKey() {
        return useLocalConfig() ? LOCAL_SUPABASE_ANON_KEY : BuildConfig.SUPABASE_ANON_KEY;
    }
    
    // Google Maps Configuration
    public static String getGoogleApiKey() {
        return useLocalConfig() ? LOCAL_GOOGLE_API_KEY : BuildConfig.GOOGLE_API_KEY;
    }
    
    // Stripe Configuration
    public static String getStripePublishableKey() {
        return useLocalConfig() ? LOCAL_STRIPE_PUBLISHABLE_KEY : BuildConfig.STRIPE_PUBLISHABLE_KEY;
    }
    
    // Brevo Configuration
    public static String getBrevoApiKey() {
        return useLocalConfig() ? LOCAL_BREVO_API_KEY : BuildConfig.BREVO_API_KEY;
    }
    
    // Validation methods
    public static boolean isConfigValid() {
        return !getOpenAiApiKey().isEmpty() && 
               !getSupabaseUrl().isEmpty() && 
               !getSupabaseAnonKey().isEmpty();
    }
    
    public static boolean isGoogleMapsConfigured() {
        return !getGoogleApiKey().isEmpty();
    }
    
    public static boolean isStripeConfigured() {
        return !getStripePublishableKey().isEmpty();
    }
    
    public static String getStripeSecretKey() {
        return LOCAL_STRIPE_SECRET_KEY; // Always use local for now
    }
    
    // Azure Configuration (always use local for now)
    public static String getAzureDocIntelligenceEndpoint() {
        return LOCAL_AZURE_DOC_INTELLIGENCE_ENDPOINT;
    }
    
    public static String getAzureDocIntelligenceKey() {
        return LOCAL_AZURE_DOC_INTELLIGENCE_KEY;
    }
    
    public static String getAzureFaceEndpoint() {
        return LOCAL_AZURE_FACE_ENDPOINT;
    }
    
    public static String getAzureFaceKey() {
        return LOCAL_AZURE_FACE_KEY;
    }
    
    // Additional API Configuration (always use local for now)
    public static String getRentcastKey() {
        return LOCAL_RENTCAST_KEY;
    }
    
    public static String getTurnstileSiteKey() {
        return LOCAL_TURNSTILE_SITE_KEY;
    }
    
    public static String getTurnstileSecretKey() {
        return LOCAL_TURNSTILE_SECRET_KEY;
    }
    
    // Extended validation methods
    public static boolean isAzureDocIntelligenceConfigured() {
        return !getAzureDocIntelligenceEndpoint().isEmpty() && !getAzureDocIntelligenceKey().isEmpty();
    }
    
    public static boolean isAzureFaceConfigured() {
        return !getAzureFaceEndpoint().isEmpty() && !getAzureFaceKey().isEmpty();
    }
    
    public static boolean isRentcastConfigured() {
        return !getRentcastKey().isEmpty();
    }
    
    public static boolean isTurnstileConfigured() {
        return !getTurnstileSiteKey().isEmpty() && !getTurnstileSecretKey().isEmpty();
    }
    
    // Debug method to check which config is being used
    public static String getConfigSource() {
        return useLocalConfig() ? "Local Development" : "Production Build";
    }
    
    // Additional helper methods for direct API access
    public static String getSupabaseRestUrl() {
        return getSupabaseUrl() + "rest/v1";
    }
    
    public static String getSupabaseAuthUrl() {
        return getSupabaseUrl() + "auth/v1";
    }
    
    public static String getSupabaseStorageUrl() {
        return getSupabaseUrl() + "storage/v1";
    }
    
    public static String getOpenAIBaseUrl() {
        return "https://api.openai.com/v1";
    }
    
    // Supabase Storage helper methods (matching website implementation)
    public static String getListingMediaBucketUrl() {
        return getSupabaseStorageUrl() + "/object/public/listing-media";
    }
    
    public static String getListingMediaPhotoUrl(String fileName) {
        if (fileName == null || fileName.isEmpty()) {
            return null;
        }
        return getListingMediaBucketUrl() + "/Photos/" + fileName;
    }
    
    public static String constructMediaUrl(String relativeUrl) {
        if (relativeUrl == null || relativeUrl.isEmpty()) {
            return null;
        }
        
        // If already a full URL, return as is
        if (relativeUrl.startsWith("http")) {
            return relativeUrl;
        }
        
        // If it's a relative path starting with /, remove it
        if (relativeUrl.startsWith("/")) {
            relativeUrl = relativeUrl.substring(1);
        }
        
        // Construct full Supabase storage URL
        return getSupabaseStorageUrl() + "/object/public/" + relativeUrl;
    }
    
    // Authorization headers
    public static String getSupabaseAuthHeader() {
        return "Bearer " + getSupabaseAnonKey();
    }
    
    public static String getOpenAIAuthHeader() {
        return "Bearer " + getOpenAiApiKey();
    }
    
    // Azure authorization headers
    public static String getAzureDocIntelligenceAuthHeader() {
        return "Ocp-Apim-Subscription-Key: " + getAzureDocIntelligenceKey();
    }
    
    public static String getAzureFaceAuthHeader() {
        return "Ocp-Apim-Subscription-Key: " + getAzureFaceKey();
    }
}