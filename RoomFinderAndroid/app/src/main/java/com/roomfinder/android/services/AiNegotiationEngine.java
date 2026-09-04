package com.roomfinder.android.services;

import android.util.Log;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.utils.ApiKeys;

import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONArray;

import java.io.IOException;
import java.util.*;
import java.util.concurrent.TimeUnit;

import okhttp3.*;

/**
 * AI Negotiation Engine for Android - matches web ai-negotiation.js functionality
 * Handles landlord communication, negotiation strategies, and deal closing
 */
public class AiNegotiationEngine {
    private static final String TAG = "AiNegotiationEngine";
    private static final String OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";
    private static final MediaType JSON = MediaType.parse("application/json; charset=utf-8");
    
    private OkHttpClient client;
    private Map<String, Negotiation> activeNegotiations;
    private Map<String, NegotiationStrategy> negotiationStrategies;
    private List<Negotiation> negotiationHistory;
    
    public AiNegotiationEngine() {
        this.client = new OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(60, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .build();
        this.activeNegotiations = new HashMap<>();
        this.negotiationStrategies = new HashMap<>();
        this.negotiationHistory = new ArrayList<>();
        
        initializeStrategies();
        Log.d(TAG, "🤝 AI Negotiation Engine initialized");
    }
    
    // Data classes for negotiation
    public static class Negotiation {
        public String id;
        public String propertyId;
        public Listing property;
        public Map<String, Object> userPreferences;
        public List<String> goals;
        public NegotiationStrategy strategy;
        public String status; // "active", "completed", "failed"
        public String createdAt;
        public List<NegotiationMessage> messages;
        public List<String> milestones;
        public MarketAnalysis marketAnalysis;
        public String outcome;
        public Map<String, Object> finalTerms;
        
        public Negotiation() {
            this.messages = new ArrayList<>();
            this.milestones = new ArrayList<>();
            this.userPreferences = new HashMap<>();
            this.finalTerms = new HashMap<>();
        }
    }
    
    public static class NegotiationStrategy {
        public String name;
        public String description;
        public List<String> tactics;
        public double successRate;
        public String type;
        public String priority;
        public List<String> arguments;
        public double targetReduction;
        public List<String> requests;
        
        public NegotiationStrategy() {
            this.tactics = new ArrayList<>();
            this.arguments = new ArrayList<>();
            this.requests = new ArrayList<>();
        }
    }
    
    public static class MarketAnalysis {
        public double averageRentInArea;
        public String marketTrend;
        public int comparableProperties;
        public int daysOnMarket;
        public double seasonalFactor;
        public double negotiationPotential;
    }
    
    public static class NegotiationMessage {
        public String id;
        public String type; // "ai_analysis", "landlord_message", "ai_response", "outcome"
        public String content;
        public long timestamp;
        public Map<String, Object> metadata;
        
        public NegotiationMessage() {
            this.metadata = new HashMap<>();
        }
    }
    
    // Initialize negotiation strategies (matching web version)
    private void initializeStrategies() {
        // Price reduction strategy
        NegotiationStrategy priceReduction = new NegotiationStrategy();
        priceReduction.name = "Price Reduction";
        priceReduction.description = "Negotiate lower rent based on market analysis";
        priceReduction.tactics = Arrays.asList(
            "Market comparison analysis",
            "Highlight tenant strengths", 
            "Propose longer lease for discount",
            "Point out property limitations"
        );
        priceReduction.successRate = 0.65;
        negotiationStrategies.put("price_reduction", priceReduction);
        
        // Lease terms strategy
        NegotiationStrategy leaseTerms = new NegotiationStrategy();
        leaseTerms.name = "Lease Terms";
        leaseTerms.description = "Negotiate better lease conditions";
        leaseTerms.tactics = Arrays.asList(
            "Pet policy adjustments",
            "Utilities inclusion",
            "Parking space inclusion", 
            "Early termination clause"
        );
        leaseTerms.successRate = 0.75;
        negotiationStrategies.put("lease_terms", leaseTerms);
        
        // Move-in benefits strategy
        NegotiationStrategy moveInBenefits = new NegotiationStrategy();
        moveInBenefits.name = "Move-in Benefits";
        moveInBenefits.description = "Request move-in incentives";
        moveInBenefits.tactics = Arrays.asList(
            "Waived security deposit",
            "First month rent discount",
            "Free utilities for initial period",
            "Property improvements"
        );
        moveInBenefits.successRate = 0.55;
        negotiationStrategies.put("move_in_benefits", moveInBenefits);
        
        Log.d(TAG, "✅ Negotiation strategies initialized");
    }
    
    // Start a new negotiation process (matching web version)
    public Negotiation startNegotiation(Listing property, Map<String, Object> userPreferences, List<String> negotiationGoals) {
        try {
            Log.d(TAG, "🎯 Starting negotiation for property: " + property.getId());
            
            // Analyze market data for this property
            MarketAnalysis marketAnalysis = analyzeMarketData(property);
            
            // Generate negotiation strategy
            NegotiationStrategy strategy = generateNegotiationStrategy(property, userPreferences, marketAnalysis);
            
            // Create negotiation record
            String negotiationId = "neg_" + System.currentTimeMillis() + "_" + property.getId();
            Negotiation negotiation = new Negotiation();
            negotiation.id = negotiationId;
            negotiation.propertyId = property.getId();
            negotiation.property = property;
            negotiation.userPreferences = userPreferences;
            negotiation.goals = negotiationGoals;
            negotiation.strategy = strategy;
            negotiation.marketAnalysis = marketAnalysis;
            negotiation.status = "active";
            negotiation.createdAt = new Date().toString();
            
            activeNegotiations.put(negotiationId, negotiation);
            
            Log.d(TAG, "✅ Negotiation started successfully: " + negotiationId);
            return negotiation;
            
        } catch (Exception e) {
            Log.e(TAG, "❌ Error starting negotiation: " + e.getMessage(), e);
            return null;
        }
    }
    
    // Analyze market data for property (matching web version logic)
    private MarketAnalysis analyzeMarketData(Listing property) {
        MarketAnalysis analysis = new MarketAnalysis();
        
        try {
            // Validate property price
            double basePrice = property.getPrice();
            if (basePrice <= 0) {
                Log.w(TAG, "Invalid property price: " + basePrice + ", using default");
                basePrice = 1000.0; // Default fallback price
            }
            
            // Simulate market analysis - in real implementation, this would
            // query market data APIs and local rental database
            analysis.averageRentInArea = basePrice * (0.9 + Math.random() * 0.2);
            analysis.marketTrend = Math.random() > 0.5 ? "increasing" : "stable";
            analysis.comparableProperties = (int)(Math.random() * 10) + 5;
            analysis.daysOnMarket = (int)(Math.random() * 30) + 7;
            analysis.seasonalFactor = getSeasonalFactor();
            analysis.negotiationPotential = Math.random() * 0.4 + 0.1; // 10-50% potential savings
            
            Log.d(TAG, "📊 Market analysis completed for property");
            Log.d(TAG, "  Base price: $" + Math.round(basePrice));
            Log.d(TAG, "  Average rent in area: $" + Math.round(analysis.averageRentInArea));
            Log.d(TAG, "  Market trend: " + analysis.marketTrend);
            Log.d(TAG, "  Days on market: " + analysis.daysOnMarket);
            Log.d(TAG, "  Negotiation potential: " + Math.round(analysis.negotiationPotential * 100) + "%");
            
        } catch (Exception e) {
            Log.e(TAG, "Error in market analysis: " + e.getMessage(), e);
            // Provide fallback values
            analysis.averageRentInArea = 1000.0;
            analysis.marketTrend = "stable";
            analysis.comparableProperties = 5;
            analysis.daysOnMarket = 15;
            analysis.seasonalFactor = 1.0;
            analysis.negotiationPotential = 0.15;
        }
        
        return analysis;
    }
    
    // Get seasonal factor for rental market (matching web version)
    private double getSeasonalFactor() {
        Calendar cal = Calendar.getInstance();
        int month = cal.get(Calendar.MONTH);
        
        double[] seasonalFactors = {
            0.85, // January - Low demand
            0.90, // February
            0.95, // March - Spring pickup
            1.00, // April
            1.05, // May - Peak season
            1.10, // June - Peak season  
            1.05, // July
            1.00, // August
            0.95, // September
            0.90, // October
            0.85, // November - Low demand
            0.80  // December - Lowest demand
        };
        
        return seasonalFactors[month];
    }
    
    // Generate negotiation strategy based on property and market data
    private NegotiationStrategy generateNegotiationStrategy(Listing property, Map<String, Object> userPreferences, MarketAnalysis marketAnalysis) {
        NegotiationStrategy strategy = new NegotiationStrategy();
        
        // Price negotiation strategy
        if (marketAnalysis.negotiationPotential > 0.2) {
            strategy.type = "price_reduction";
            strategy.priority = "high";
            strategy.arguments = Arrays.asList(
                "Market analysis shows similar properties average $" + Math.round(marketAnalysis.averageRentInArea) + "/month",
                "Property has been on market for " + marketAnalysis.daysOnMarket + " days",
                "Seasonal factor suggests " + Math.round((1 - marketAnalysis.seasonalFactor) * 100) + "% lower demand"
            );
            strategy.targetReduction = property.getPrice() * marketAnalysis.negotiationPotential;
        } else {
            // Focus on lease terms if price negotiation potential is low
            strategy.type = "lease_terms";
            strategy.priority = "medium";
            strategy.requests = Arrays.asList(
                "Include utilities in rent",
                "Allow pets with reduced deposit", 
                "Flexible lease start date"
            );
        }
        
        return strategy;
    }
    
    // Generate AI negotiation message using OpenAI
    public void generateNegotiationMessage(Negotiation negotiation, String context, NegotiationCallback callback) {
        if (ApiKeys.OPENAI_API_KEY == null || ApiKeys.OPENAI_API_KEY.isEmpty()) {
            callback.onError("OpenAI API key not configured");
            return;
        }
        
        try {
            String systemPrompt = buildNegotiationSystemPrompt(negotiation);
            String userPrompt = buildNegotiationUserPrompt(negotiation, context);
            
            JSONObject requestBody = new JSONObject();
            requestBody.put("model", ApiKeys.OPENAI_MODEL);
            requestBody.put("max_tokens", 300);
            requestBody.put("temperature", 0.7);
            
            JSONArray messages = new JSONArray();
            
            JSONObject systemMessage = new JSONObject();
            systemMessage.put("role", "system");
            systemMessage.put("content", systemPrompt);
            messages.put(systemMessage);
            
            JSONObject userMessage = new JSONObject();
            userMessage.put("role", "user");
            userMessage.put("content", userPrompt);
            messages.put(userMessage);
            
            requestBody.put("messages", messages);
            
            Request request = new Request.Builder()
                    .url(OPENAI_API_URL)
                    .addHeader("Authorization", "Bearer " + ApiKeys.OPENAI_API_KEY)
                    .addHeader("Content-Type", "application/json")
                    .post(RequestBody.create(requestBody.toString(), JSON))
                    .build();
            
            client.newCall(request).enqueue(new Callback() {
                @Override
                public void onFailure(Call call, IOException e) {
                    Log.e(TAG, "OpenAI API call failed", e);
                    callback.onError("Network error: " + e.getMessage());
                }
                
                @Override
                public void onResponse(Call call, Response response) throws IOException {
                    try {
                        if (!response.isSuccessful()) {
                            callback.onError("API error: " + response.code());
                            return;
                        }
                        
                        String responseBody = response.body().string();
                        JSONObject jsonResponse = new JSONObject(responseBody);
                        
                        JSONArray choices = jsonResponse.getJSONArray("choices");
                        if (choices.length() > 0) {
                            JSONObject firstChoice = choices.getJSONObject(0);
                            JSONObject message = firstChoice.getJSONObject("message");
                            String aiMessage = message.getString("content");
                            
                            // Add message to negotiation history
                            NegotiationMessage negMessage = new NegotiationMessage();
                            negMessage.id = "msg_" + System.currentTimeMillis();
                            negMessage.type = "ai_response";
                            negMessage.content = aiMessage;
                            negMessage.timestamp = System.currentTimeMillis();
                            negotiation.messages.add(negMessage);
                            
                            callback.onSuccess(aiMessage);
                        } else {
                            callback.onError("No response from AI");
                        }
                        
                    } catch (JSONException e) {
                        Log.e(TAG, "Error parsing OpenAI response", e);
                        callback.onError("Error parsing AI response");
                    }
                }
            });
            
        } catch (JSONException e) {
            Log.e(TAG, "Error building OpenAI request", e);
            callback.onError("Error building request");
        }
    }
    
    // Build system prompt for negotiation AI
    private String buildNegotiationSystemPrompt(Negotiation negotiation) {
        return "You are an expert real estate negotiation AI assistant. Your role is to:\n\n" +
               "1. Analyze rental market data and property details\n" +
               "2. Develop strategic negotiation approaches for the user\n" +
               "3. Communicate professionally with landlords on behalf of tenants\n" +
               "4. Provide realistic market-based negotiation advice\n\n" +
               "Current negotiation context:\n" +
               "- Property: " + negotiation.property.getTitle() + " in " + negotiation.property.getLocation() + "\n" +
               "- Listed Price: $" + negotiation.property.getPrice() + "/month\n" +
               "- Market Average: $" + Math.round(negotiation.marketAnalysis.averageRentInArea) + "/month\n" +
               "- Days on Market: " + negotiation.marketAnalysis.daysOnMarket + " days\n" +
               "- Negotiation Potential: " + Math.round(negotiation.marketAnalysis.negotiationPotential * 100) + "%\n" +
               "- Strategy Type: " + negotiation.strategy.type + "\n\n" +
               "Be professional, data-driven, and focus on win-win outcomes.";
    }
    
    // Build user prompt for specific negotiation context
    private String buildNegotiationUserPrompt(Negotiation negotiation, String context) {
        return "Based on the market analysis and negotiation strategy, please:\n\n" + context + 
               "\n\nUse the following strategy arguments:\n" + String.join("\n", negotiation.strategy.arguments) +
               "\n\nProvide a professional, persuasive response that advances the negotiation while maintaining a positive relationship with the landlord.";
    }
    
    // Callback interface for negotiation operations
    public interface NegotiationCallback {
        void onSuccess(String message);
        void onError(String error);
    }
    
    // Get negotiation by ID
    public Negotiation getNegotiation(String negotiationId) {
        return activeNegotiations.get(negotiationId);
    }
    
    // Update negotiation status
    public void updateNegotiationStatus(String negotiationId, String status, String notes) {
        Negotiation negotiation = activeNegotiations.get(negotiationId);
        if (negotiation != null) {
            negotiation.status = status;
            if (notes != null && !notes.isEmpty()) {
                negotiation.milestones.add(new Date() + ": " + notes);
            }
            Log.d(TAG, "📝 Updated negotiation " + negotiationId + " status to: " + status);
        }
    }
    
    // End negotiation with outcome
    public void endNegotiation(String negotiationId, String outcome, Map<String, Object> finalTerms) {
        Negotiation negotiation = activeNegotiations.get(negotiationId);
        if (negotiation != null) {
            negotiation.status = "completed";
            negotiation.outcome = outcome;
            if (finalTerms != null) {
                negotiation.finalTerms = finalTerms;
            }
            
            // Move to history
            negotiationHistory.add(negotiation);
            activeNegotiations.remove(negotiationId);
            
            Log.d(TAG, "🏁 Negotiation " + negotiationId + " completed with outcome: " + outcome);
        }
    }
    
    // Get all active negotiations
    public List<Negotiation> getActiveNegotiations() {
        return new ArrayList<>(activeNegotiations.values());
    }
}