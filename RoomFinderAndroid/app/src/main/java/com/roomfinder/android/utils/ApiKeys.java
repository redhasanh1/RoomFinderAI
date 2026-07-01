package com.roomfinder.android.utils;

import com.roomfinder.android.BuildConfig;

public class ApiKeys {

    private static String orConfigured(String buildConfigValue, String fallback) {
        if (buildConfigValue != null
                && !buildConfigValue.isEmpty()
                && !"API_KEY_NOT_CONFIGURED".equals(buildConfigValue)) {
            return buildConfigValue;
        }
        return fallback;
    }

    public static final String SUPABASE_URL = orConfigured(
            BuildConfig.SUPABASE_URL,
            "https://fkktwhjybuflxqzopaex.supabase.co/"
    );
    public static final String SUPABASE_ANON_KEY = orConfigured(
            BuildConfig.SUPABASE_ANON_KEY,
            ""
    );

    public static final String AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT = BuildConfig.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT;
    public static final String AZURE_DOCUMENT_INTELLIGENCE_KEY = BuildConfig.AZURE_DOCUMENT_INTELLIGENCE_KEY;
    public static final String AZURE_FACE_ENDPOINT = BuildConfig.AZURE_FACE_ENDPOINT;
    public static final String AZURE_FACE_KEY = BuildConfig.AZURE_FACE_KEY;

    public static final String BREVO_API_KEY = BuildConfig.BREVO_API_KEY;
    public static final String GOOGLE_API_KEY = BuildConfig.GOOGLE_API_KEY;
    public static final String GOOGLE_OAUTH_CLIENT_ID = BuildConfig.GOOGLE_OAUTH_CLIENT_ID;

    public static final String OPENAI_API_KEY = BuildConfig.OPENAI_API_KEY;
    public static final String OPENAI_MODEL = orConfigured(BuildConfig.OPENAI_MODEL, "gpt-3.5-turbo");
    public static final String OPENAI_ORG_ID = BuildConfig.OPENAI_ORG_ID;

    public static final String RENTCAST_KEY = BuildConfig.RENTCAST_KEY;
    public static final String STRIPE_PUBLISHABLE_KEY = BuildConfig.STRIPE_PUBLISHABLE_KEY;
    public static final String STRIPE_SECRET_KEY = BuildConfig.STRIPE_SECRET_KEY;

    public static final String TURNSTILE_SECRET_KEY = BuildConfig.TURNSTILE_SECRET_KEY;
    public static final String TURNSTILE_SITE_KEY = BuildConfig.TURNSTILE_SITE_KEY;

    private ApiKeys() {
    }
}
