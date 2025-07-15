package com.roomfinderai.app.fragments;

import android.os.Bundle;
import android.text.method.ScrollingMovementMethod;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;
import androidx.fragment.app.Fragment;
import com.roomfinderai.app.R;
import com.roomfinderai.app.models.*;
import com.roomfinderai.app.services.Repository;
import com.roomfinderai.app.services.ApiClient;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public class TestApiFragment extends Fragment {
    
    private static final String TAG = "TestApiFragment";
    private TextView resultTextView;
    private ProgressBar progressBar;
    private Repository repository;
    private StringBuilder resultBuilder;
    
    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        Log.d(TAG, "🧪🧪🧪 TestApiFragment onCreateView() called! 🧪🧪🧪");
        Log.d(TAG, "📱 Inflating layout: R.layout.fragment_test_api");
        
        View view = inflater.inflate(R.layout.fragment_test_api, container, false);
        Log.d(TAG, "✅ Layout inflated successfully");
        
        repository = new Repository();
        resultBuilder = new StringBuilder();
        Log.d(TAG, "📡 Repository and StringBuilder initialized");
        
        initializeViews(view);
        setupButtons(view);
        
        Log.d(TAG, "🎯 TestApiFragment setup complete - buttons should be visible!");
        return view;
    }
    
    private void initializeViews(View view) {
        Log.d(TAG, "🔍 Finding views by ID...");
        
        resultTextView = view.findViewById(R.id.resultTextView);
        progressBar = view.findViewById(R.id.progressBar);
        
        Log.d(TAG, "📺 resultTextView found: " + (resultTextView != null));
        Log.d(TAG, "⏳ progressBar found: " + (progressBar != null));
        
        if (resultTextView != null) {
            // Make result text scrollable
            resultTextView.setMovementMethod(new ScrollingMovementMethod());
            Log.d(TAG, "✅ ResultTextView configured for scrolling");
        } else {
            Log.e(TAG, "❌ resultTextView is NULL!");
        }
    }
    
    private void setupButtons(View view) {
        Log.d(TAG, "🔘 Setting up test buttons...");
        
        // Test Listings API
        Button testListingsButton = view.findViewById(R.id.testListingsButton);
        Log.d(TAG, "🔘 testListingsButton found: " + (testListingsButton != null));
        if (testListingsButton != null) {
            testListingsButton.setOnClickListener(v -> {
                Log.d(TAG, "🔘 TEST LISTINGS BUTTON CLICKED!");
                testListingsApi();
            });
        }
        
        // Test Create Listing
        Button testCreateListingButton = view.findViewById(R.id.testCreateListingButton);
        Log.d(TAG, "🔘 testCreateListingButton found: " + (testCreateListingButton != null));
        if (testCreateListingButton != null) {
            testCreateListingButton.setOnClickListener(v -> {
                Log.d(TAG, "🔘 TEST CREATE LISTING BUTTON CLICKED!");
                testCreateListingApi();
            });
        }
        
        // Test AI Chat
        Button testAIChatButton = view.findViewById(R.id.testAIChatButton);
        Log.d(TAG, "🔘 testAIChatButton found: " + (testAIChatButton != null));
        if (testAIChatButton != null) {
            testAIChatButton.setOnClickListener(v -> {
                Log.d(TAG, "🔘 TEST AI CHAT BUTTON CLICKED!");
                testAIChatApi();
            });
        }
        
        // Test Config
        Button testConfigButton = view.findViewById(R.id.testConfigButton);
        Log.d(TAG, "🔘 testConfigButton found: " + (testConfigButton != null));
        if (testConfigButton != null) {
            testConfigButton.setOnClickListener(v -> {
                Log.d(TAG, "🔘 TEST CONFIG BUTTON CLICKED!");
                testConfigApi();
            });
        }
        
        // Test Search
        Button testSearchButton = view.findViewById(R.id.testSearchButton);
        Log.d(TAG, "🔘 testSearchButton found: " + (testSearchButton != null));
        if (testSearchButton != null) {
            testSearchButton.setOnClickListener(v -> {
                Log.d(TAG, "🔘 TEST SEARCH BUTTON CLICKED!");
                testSearchApi();
            });
        }
        
        Log.d(TAG, "✅ All buttons setup complete!");
    }
    
    private void showLoading(boolean show) {
        if (getActivity() != null) {
            getActivity().runOnUiThread(() -> {
                progressBar.setVisibility(show ? View.VISIBLE : View.GONE);
            });
        }
    }
    
    private void appendResult(String text) {
        if (getActivity() != null) {
            getActivity().runOnUiThread(() -> {
                resultBuilder.append(text).append("\n");
                resultTextView.setText(resultBuilder.toString());
                
                // Auto-scroll to bottom
                int scrollAmount = resultTextView.getLayout().getLineTop(resultTextView.getLineCount()) - resultTextView.getHeight();
                if (scrollAmount > 0) {
                    resultTextView.scrollTo(0, scrollAmount);
                }
            });
        }
    }
    
    private void clearResults() {
        resultBuilder.delete(0, resultBuilder.length());
        resultTextView.setText("");
    }
    
    // Test GET Listings
    private void testListingsApi() {
        clearResults();
        appendResult("=== Testing GET Listings (Supabase) ===");
        appendResult("Config Status: " + (ApiClient.isLocalConfigured() ? "Local APIs" : "Production Build"));
        appendResult("Supabase configured: " + com.roomfinderai.app.config.ApiConfig.isConfigValid());
        showLoading(true);
        
        repository.getListings(new Repository.ApiCallback<List<Listing>>() {
            @Override
            public void onSuccess(List<Listing> result) {
                showLoading(false);
                appendResult("✅ SUCCESS!");
                appendResult("Total listings: " + (result != null ? result.size() : 0));
                
                if (result != null && !result.isEmpty()) {
                    appendResult("\nFirst listing:");
                    Listing first = result.get(0);
                    appendResult("- Title: " + first.getTitle());
                    appendResult("- Price: $" + first.getPrice());
                    appendResult("- Location: " + first.getLocation());
                    appendResult("- Bedrooms: " + first.getBedrooms());
                }
                
                Log.d(TAG, "Listings API test successful: " + result.size() + " listings");
            }
            
            @Override
            public void onError(String error) {
                showLoading(false);
                appendResult("❌ ERROR: " + error);
                Log.e(TAG, "Listings API test failed: " + error);
            }
        });
    }
    
    // Test POST Listing
    private void testCreateListingApi() {
        clearResults();
        appendResult("=== Testing POST /api/listings ===");
        showLoading(true);
        
        // Create test listing
        Listing testListing = new Listing(
            "API Test Listing " + System.currentTimeMillis(),
            "This is a test listing created from Android app",
            1200.0,
            null, // location will be split into city/street
            2,
            1.5,
            new ArrayList<>() // Empty MediaItem list
        );
        testListing.setHouseType("Apartment");
        testListing.setUtilities("Included");
        testListing.setCity("Test City");
        testListing.setStreet("123 Test Street");
        testListing.setPostalCode("12345");
        testListing.setCountry("US");
        testListing.setUserEmail("test@roomfinder.ai");
        
        appendResult("Creating test listing...");
        appendResult("Title: " + testListing.getTitle());
        
        repository.createListing(testListing, new Repository.ApiCallback<Listing>() {
            @Override
            public void onSuccess(Listing result) {
                showLoading(false);
                appendResult("✅ SUCCESS!");
                appendResult("Created listing ID: " + result.getId());
                appendResult("Response title: " + result.getTitle());
                Log.d(TAG, "Create listing API test successful");
            }
            
            @Override
            public void onError(String error) {
                showLoading(false);
                appendResult("❌ ERROR: " + error);
                Log.e(TAG, "Create listing API test failed: " + error);
            }
        });
    }
    
    // Test AI Chat
    private void testAIChatApi() {
        clearResults();
        appendResult("=== Testing AI Chat (Direct OpenAI Only) ===");
        appendResult("OpenAI configured: " + com.roomfinderai.app.config.ApiConfig.isConfigValid());
        showLoading(true);
        
        String testMessage = "Hello AI! Can you help me find a 2 bedroom apartment under $1500?";
        String sessionId = UUID.randomUUID().toString();
        
        appendResult("Sending message: " + testMessage);
        appendResult("Session ID: " + sessionId);
        appendResult("Using Direct OpenAI API (NO Railway backend)...");
        
        repository.sendMessage(testMessage, "test-user", sessionId, new Repository.ApiCallback<ChatMessage>() {
            @Override
            public void onSuccess(ChatMessage result) {
                showLoading(false);
                appendResult("✅ SUCCESS! (Direct OpenAI)");
                appendResult("AI Response: " + (result != null ? result.getMessage() : "No message"));
                Log.d(TAG, "AI Chat API test successful");
            }
            
            @Override
            public void onError(String error) {
                showLoading(false);
                appendResult("❌ ERROR: " + error);
                Log.e(TAG, "AI Chat API test failed: " + error);
            }
        });
    }
    
    // Test Config
    private void testConfigApi() {
        clearResults();
        appendResult("=== Testing GET /api/config ===");
        showLoading(true);
        
        repository.getConfig(new Repository.ApiCallback<Map<String, String>>() {
            @Override
            public void onSuccess(Map<String, String> result) {
                showLoading(false);
                appendResult("✅ SUCCESS!");
                
                if (result != null) {
                    appendResult("Configuration loaded:");
                    for (Map.Entry<String, String> entry : result.entrySet()) {
                        String value = entry.getValue();
                        if (entry.getKey().contains("KEY") && value != null && value.length() > 10) {
                            // Mask sensitive keys
                            value = value.substring(0, 5) + "..." + value.substring(value.length() - 3);
                        }
                        appendResult("- " + entry.getKey() + ": " + value);
                    }
                }
                
                Log.d(TAG, "Config API test successful");
            }
            
            @Override
            public void onError(String error) {
                showLoading(false);
                appendResult("❌ ERROR: " + error);
                Log.e(TAG, "Config API test failed: " + error);
            }
        });
    }
    
    // Test Search
    private void testSearchApi() {
        clearResults();
        appendResult("=== Testing Search Listings ===");
        showLoading(true);
        
        Map<String, String> filters = new HashMap<>();
        filters.put("search", "apartment");
        
        appendResult("Searching for: apartment");
        
        repository.getListings(filters, new Repository.ApiCallback<List<Listing>>() {
            @Override
            public void onSuccess(List<Listing> result) {
                showLoading(false);
                appendResult("✅ SUCCESS!");
                appendResult("Search results: " + (result != null ? result.size() : 0) + " listings");
                
                if (result != null && !result.isEmpty()) {
                    appendResult("\nFirst result:");
                    Listing first = result.get(0);
                    appendResult("- Title: " + first.getTitle());
                    appendResult("- Location: " + first.getLocation());
                }
                
                Log.d(TAG, "Search API test successful");
            }
            
            @Override
            public void onError(String error) {
                showLoading(false);
                appendResult("❌ ERROR: " + error);
                Log.e(TAG, "Search API test failed: " + error);
            }
        });
    }
}