package com.roomfinderai.app.config;

import com.roomfinderai.app.BuildConfig;

public class ApiConfig {
    
    // Private constructor to prevent instantiation
    private ApiConfig() {
        throw new UnsupportedOperationException("This is a utility class and cannot be instantiated");
    }
    
    // Local development configuration values
    private static final String LOCAL_API_BASE_URL = "http://10.0.2.2:3000/";
    private static final String LOCAL_OPENAI_API_KEY = "sk-proj-CbQtehx5UM0V9mXWrdZnM-hP3l98a0ZVguNWb51K7G63M0dfChAziWYeIO_AOPE2cEnVGOcwyT3BlbkFJliQDGy85OmZ3UGhQS7RSltE9YKO_5qrdLaLEweqkbxs-dDtMy3FMf6Msuot00O58p9L9XQBucA";
    private static final String LOCAL_SUPABASE_URL = "https://fkktwhjybuflxqzopaex.supabase.co/";
    private static final String LOCAL_SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs";
    private static final String LOCAL_GOOGLE_API_KEY = "AIzaSyBzE8cPfeO5YkmpJFc8SLtVsz_eGB-wYYM";
    private static final String LOCAL_STRIPE_PUBLISHABLE_KEY = "pk_test_51Rb76iEAbICBlW3MMGkAX58TJHxCWd3MoBD4PXwzdFnXi2EsFrf0iWUDvRVtoOfNzFMnd0cCkGMb2MAcAx4JIPTB00kPkbVXTV";
    private static final String LOCAL_BREVO_API_KEY = "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";
    
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
            return "https://roomfinderai-production.up.railway.app/";
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