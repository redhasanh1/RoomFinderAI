package com.roomfinderai.app.config;

import com.roomfinderai.app.BuildConfig;

public class ApiConfig {
    
    // Private constructor to prevent instantiation
    private ApiConfig() {
        throw new UnsupportedOperationException("This is a utility class and cannot be instantiated");
    }
    
    // Local development configuration values
    private static final String LOCAL_API_BASE_URL = "http://10.0.2.2:3000/";
    private static final String LOCAL_OPENAI_API_KEY = System.getenv("OPENAI_API_KEY");
    private static final String LOCAL_SUPABASE_URL = "https://fkktwhjybuflxqzopaex.supabase.co/";
    private static final String LOCAL_SUPABASE_ANON_KEY = System.getenv("SUPABASE_ANON_KEY");
    private static final String LOCAL_GOOGLE_API_KEY = System.getenv("GOOGLE_API_KEY");
    private static final String LOCAL_STRIPE_PUBLISHABLE_KEY = System.getenv("STRIPE_PUBLISHABLE_KEY");
    private static final String LOCAL_BREVO_API_KEY = System.getenv("BREVO_API_KEY");
    
    // Helper method to determine if we should use local config
    private static boolean useLocalConfig() {
        return BuildConfig.USE_LOCAL_CONFIG;
    }
    
    // OpenAI Configuration
    public static String getOpenAiApiKey() {
        return useLocalConfig() ? LOCAL_OPENAI_API_KEY : BuildConfig.OPENAI_API_KEY;
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
    
    // API Base URL Configuration
    public static String getApiBaseUrl() {
        if (useLocalConfig()) {
            return LOCAL_API_BASE_URL;
        }
        // Check if API_BASE_URL is defined in BuildConfig
        try {
            return BuildConfig.class.getField("API_BASE_URL").get(null).toString();
        } catch (Exception e) {
            // Fallback to your production URL
            return "https://www.roomfinderai.com/";
        }
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
    
    // Debug method to check which config is being used
    public static String getConfigSource() {
        return useLocalConfig() ? "Local Development" : "Railway Production";
    }
}