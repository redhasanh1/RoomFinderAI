package com.roomfinder.android.utils;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.util.Log;
import okhttp3.*;
import org.json.JSONException;
import org.json.JSONObject;
import java.io.IOException;
import java.util.concurrent.TimeUnit;

public class NetworkUtils {
    private static final String TAG = "NetworkUtils";
    private static final int TIMEOUT_SECONDS = 30;
    
    private static OkHttpClient client;
    
    static {
        client = new OkHttpClient.Builder()
                .connectTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
                .readTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
                .writeTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
                .build();
    }
    
    public interface NetworkCallback<T> {
        void onSuccess(T result);
        void onError(String error);
    }
    
    // Check if network is available
    public static boolean isNetworkAvailable(Context context) {
        ConnectivityManager connectivityManager = 
                (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        
        if (connectivityManager != null) {
            NetworkInfo activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
            return activeNetworkInfo != null && activeNetworkInfo.isConnected();
        }
        return false;
    }
    
    // Make GET request
    public static void makeGetRequest(String url, NetworkCallback<String> callback) {
        Request request = new Request.Builder()
                .url(url)
                .build();
        
        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                Log.e(TAG, "GET request failed: " + url, e);
                String errorMessage = getDetailedErrorMessage(e);
                callback.onError(errorMessage);
            }
            
            @Override
            public void onResponse(Call call, Response response) throws IOException {
                try {
                    if (response.isSuccessful()) {
                        String responseBody = response.body() != null ? response.body().string() : "";
                        callback.onSuccess(responseBody);
                    } else {
                        String errorBody = response.body() != null ? response.body().string() : "Unknown error";
                        Log.e(TAG, "GET request error: " + response.code() + " - " + errorBody);
                        callback.onError("HTTP " + response.code() + ": " + response.message());
                    }
                } finally {
                    response.close();
                }
            }
        });
    }
    
    // Make POST request with JSON body
    public static void makePostRequest(String url, JSONObject jsonBody, NetworkCallback<String> callback) {
        makePostRequest(url, jsonBody, null, callback);
    }
    
    // Make POST request with JSON body and custom headers
    public static void makePostRequest(String url, JSONObject jsonBody, Headers customHeaders, NetworkCallback<String> callback) {
        MediaType JSON = MediaType.parse("application/json; charset=utf-8");
        RequestBody body = RequestBody.create(jsonBody.toString(), JSON);
        
        Request.Builder requestBuilder = new Request.Builder()
                .url(url)
                .post(body);
        
        // Add custom headers if provided
        if (customHeaders != null) {
            requestBuilder.headers(customHeaders);
        }
        
        Request request = requestBuilder.build();
        
        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                Log.e(TAG, "POST request failed: " + url, e);
                String errorMessage = getDetailedErrorMessage(e);
                callback.onError(errorMessage);
            }
            
            @Override
            public void onResponse(Call call, Response response) throws IOException {
                try {
                    String responseBody = response.body() != null ? response.body().string() : "";
                    
                    if (response.isSuccessful()) {
                        callback.onSuccess(responseBody);
                    } else {
                        Log.e(TAG, "POST request error: " + response.code() + " - " + responseBody);
                        callback.onError("HTTP " + response.code() + ": " + response.message());
                    }
                } finally {
                    response.close();
                }
            }
        });
    }
    
    // Make authenticated request to Supabase
    public static void makeSupabaseRequest(String endpoint, String method, JSONObject body, NetworkCallback<String> callback) {
        Headers.Builder headersBuilder = new Headers.Builder()
                .add("apikey", ApiKeys.SUPABASE_ANON_KEY)
                .add("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                .add("Content-Type", "application/json")
                .add("Prefer", "return=representation");
        
        // Fix double slash issue if SUPABASE_URL already ends with slash
        String url;
        if (ApiKeys.SUPABASE_URL.endsWith("/")) {
            url = ApiKeys.SUPABASE_URL + "rest/v1/" + endpoint;
        } else {
            url = ApiKeys.SUPABASE_URL + "/rest/v1/" + endpoint;
        }
        
        Request.Builder requestBuilder = new Request.Builder()
                .url(url)
                .headers(headersBuilder.build());
        
        if ("POST".equals(method) && body != null) {
            MediaType JSON = MediaType.parse("application/json; charset=utf-8");
            RequestBody requestBody = RequestBody.create(body.toString(), JSON);
            requestBuilder.post(requestBody);
        } else if ("GET".equals(method)) {
            requestBuilder.get();
        }
        
        Request request = requestBuilder.build();
        
        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                Log.e(TAG, "Supabase request failed: " + url, e);
                callback.onError("Database connection error: " + e.getMessage());
            }
            
            @Override
            public void onResponse(Call call, Response response) throws IOException {
                try {
                    String responseBody = response.body() != null ? response.body().string() : "";
                    
                    if (response.isSuccessful()) {
                        callback.onSuccess(responseBody);
                    } else {
                        Log.e(TAG, "Supabase request error: " + response.code() + " - " + responseBody);
                        callback.onError("Database error: HTTP " + response.code());
                    }
                } finally {
                    response.close();
                }
            }
        });
    }
    
    // Helper to create Headers for OpenAI requests
    public static Headers createOpenAIHeaders() {
        return new Headers.Builder()
                .add("Authorization", "Bearer " + ApiKeys.OPENAI_API_KEY)
                .add("Content-Type", "application/json")
                .build();
    }
    
    // Helper to parse JSON response safely
    public static JSONObject parseJsonResponse(String response) {
        try {
            return new JSONObject(response);
        } catch (JSONException e) {
            Log.e(TAG, "Error parsing JSON response", e);
            return null;
        }
    }
    
    // Cancel all pending requests (useful for cleanup)
    public static void cancelAllRequests() {
        client.dispatcher().cancelAll();
    }
    
    // Create a new client instance with custom timeout
    public static OkHttpClient createCustomClient(int timeoutSeconds) {
        return new OkHttpClient.Builder()
                .connectTimeout(timeoutSeconds, TimeUnit.SECONDS)
                .readTimeout(timeoutSeconds, TimeUnit.SECONDS)
                .writeTimeout(timeoutSeconds, TimeUnit.SECONDS)
                .build();
    }
    
    // Get detailed error message based on exception type
    private static String getDetailedErrorMessage(IOException e) {
        if (e instanceof java.net.UnknownHostException) {
            return "Cannot connect to server. Please check your internet connection.";
        } else if (e instanceof java.net.SocketTimeoutException) {
            return "Connection timed out. Please try again.";
        } else if (e instanceof java.net.ConnectException) {
            return "Failed to connect to server. Please check your network settings.";
        } else if (e instanceof javax.net.ssl.SSLException) {
            return "Secure connection failed. Please check your network security settings.";
        } else if (e instanceof java.net.ProtocolException) {
            return "Network protocol error. Please try again.";
        } else if (e.getMessage() != null && e.getMessage().contains("Canceled")) {
            return "Request was cancelled.";
        } else if (e.getMessage() != null) {
            return "Network error: " + e.getMessage();
        } else {
            return "Network error occurred. Please check your connection and try again.";
        }
    }
}