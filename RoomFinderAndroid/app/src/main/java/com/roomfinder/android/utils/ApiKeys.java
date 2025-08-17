package com.roomfinder.android.utils;

import com.roomfinder.android.BuildConfig;

public class ApiKeys {
    
    // Supabase Configuration
    public static final String SUPABASE_URL = "https://fkktwhjybuflxqzopaex.supabase.co/";
    public static final String SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs";
    
    // Azure Services
    public static final String AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT = "https://roomfinder-document-intelligence.cognitiveservices.azure.com/";
    public static final String AZURE_DOCUMENT_INTELLIGENCE_KEY = "3e4UdQa89vVlUe2iswrEYObX4R3QepgprHQq8x6Wo324sifT9fCHJQQJ99BFACYeBjFXJ3w3AAALACOGBtbQ";
    
    public static final String AZURE_FACE_ENDPOINT = "https://roomfinder-face-api.cognitiveservices.azure.com/";
    public static final String AZURE_FACE_KEY = "17b0sARArOlfLsarJUXtBBsqu70hyCfXpVTNjD6W9qSZl4TXm8vXJQQJ99BFACYeBjFXJ3w3AAAKACOGJYtV";
    
    // Third Party APIs
    public static final String BREVO_API_KEY = "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";
    public static final String GOOGLE_API_KEY = "AIzaSyBzE8cPfeO5YkmpJFc8SLtVsz_eGB-wYYM";
    public static final String GOOGLE_OAUTH_CLIENT_ID = "971569749460-a8c7vqutq3eqjf1q6jtit28gqnos268v.apps.googleusercontent.com";
    
    // OpenAI - Load from build config or environment variables
    public static final String OPENAI_API_KEY = BuildConfig.OPENAI_API_KEY;
    public static final String OPENAI_MODEL = "gpt-3.5-turbo";
    public static final String OPENAI_ORG_ID = BuildConfig.OPENAI_ORG_ID;
    
    // Payment & Analytics
    public static final String RENTCAST_KEY = "3bc616ab43604dbb94000590c342b1a4";
    public static final String STRIPE_PUBLISHABLE_KEY = "pk_test_51Rb76iEAbICBlW3MMGkAX58TJHxCWd3MoBD4PXwzdFnXi2EsFrf0iWUDvRVtoOfNzFMnd0cCkGMb2MAcAx4JIPTB00kPkbVXTV";
    public static final String STRIPE_SECRET_KEY = "sk_test_51Rb76iEAbICBlW3Mgdi3NWT4Xh7HBxohdq4Rs9N4LjhT1i4XtgQQvrG2k9sJQBWtmM2Bndjkhb99BBoUY7KlB5RI00nJTMPBfV";
    
    // Security
    public static final String TURNSTILE_SECRET_KEY = "0x4AAAAAABjjAf8v14eqofaYT7SrJ0cNDmA";
    public static final String TURNSTILE_SITE_KEY = "0x4AAAAAABjjAXWppygcnbuz";
    
    private ApiKeys() {
        // Private constructor to prevent instantiation
    }
}