# AI Negotiator Prompt Comparison: Web vs iOS

## Executive Summary
After comparing the AI prompts between the web implementation (`ai-negotiation.js`) and iOS implementation (`AINegotiatorService.swift`), I've identified several key differences that need to be addressed for full parity.

## Key Differences Found

### 1. Market Data Prompts

**Web Implementation (Line 178-195):**
```javascript
You are a real estate market analyst. Provide realistic rental market data for:
- Location: ${location || 'General area'}
- Property Type: ${houseType || 'Any'}
- Bedrooms: ${bedrooms || 'Any'}

Based on current market conditions, provide realistic estimates in this JSON format:
{
    "average": 1200,
    "median": 1150,
    "min": 900,
    "max": 1500,
    "analysis": "Brief market analysis explaining the pricing",
    "negotiationTips": "Tips for negotiating in this market"
}

Focus on realistic prices for the specified location and property type.
```

**iOS Implementation (Line 134-164):**
```swift
Generate realistic rental market statistics in JSON format for:
Location: {location}
Property Type: {houseType}
Bedrooms: {bedrooms}

Return ONLY valid JSON with this exact structure:
{
  "average": 1500.0,
  "median": 1450.0,
  "min": 1000.0,
  "max": 2500.0,
  "count": 25,
  "analysis": "Brief market analysis",
  "negotiationTips": ["tip1", "tip2", "tip3"]
}

Base estimates on realistic market data. Include 3-5 practical negotiation tips.
```

**Differences:**
- Web version has `negotiationTips` as a string, iOS has it as an array
- iOS includes `count` field in the response
- Different example values (web: $1200 avg, iOS: $1500 avg)
- iOS explicitly asks for "3-5 practical negotiation tips"

### 2. First Negotiation Message Prompts

**Web Implementation (Line 253-288):**
```javascript
You are an expert rental negotiator. Generate a professional negotiation message for this rental:

LISTING DETAILS:
- Title: ${listing.title}
- Current Price: $${listing.price}/month
- Type: ${listing.house_type}
- Bedrooms: ${listing.bedrooms}
- Location: ${listing.city || 'Not specified'}
- Utilities: ${listing.utilities}

USER REQUIREMENTS:
- Budget: $${userBudget}
- Looking for: ${listing.house_type}

MARKET DATA:
- Average market price: $${marketData.average}
- Market range: $${marketData.min} - $${marketData.max}
- Data source: ${marketData.source}
- Analysis: ${marketData.analysis || 'Standard market conditions'}

NEGOTIATION STRATEGY:
1. Be professional and respectful
2. Express genuine interest in the property
3. Mention you're a qualified tenant ready to move quickly
4. If listing price is above market average or user budget, suggest a lower price with justification
5. Offer quick decision-making and reliable tenancy
6. Keep message concise (2-3 sentences max)

PRICING LOGIC:
- If listing price > market average: Suggest price closer to market average
- If listing price > user budget: Suggest price within budget
- If listing price is fair: Express interest and ask about flexibility

Generate ONLY the message content (no "Dear" or signatures):
```

**iOS Implementation (Line 182-220):**
```swift
Write a professional negotiation message for this rental listing:

Property: {listing.displayTitle}
Listed Price: {listing.displayPrice}
Location: {listing.displayLocation}
Budget: ${userBudget}
Bedrooms: {bedrooms}

Market Data:
- Average rent: ${average}
- Median rent: ${median}
- Sample size: {count} listings
- Market analysis: {analysis}

Write a persuasive but respectful negotiation message (2-3 sentences max).
Use market data to justify a fair offer. Be professional and polite.
DO NOT include subject lines, signatures, or formatting - just the message content.
```

**Differences:**
- Web version is much more detailed with explicit strategy and pricing logic
- Web includes utilities information
- Web has numbered negotiation strategy points
- Web includes data source and market range
- iOS version is more concise but less instructive

### 3. Reply Analysis Prompts

**Web Implementation (Line 591-626):**
```javascript
Analyze this landlord reply in a rental negotiation:

LANDLORD REPLY: "${replyContent}"

NEGOTIATION CONTEXT:
- Original listing price: $${listing.price}
- Last AI offer/message: "${lastAIMessage?.content || 'Initial contact'}"
- User budget: $${negotiation.userBudget}
- Current negotiation status: ${negotiation.status}
- Conversation history: ${negotiation.messages.slice(-3).map(m => `${m.sender}: ${m.content}`).join(' | ')}

Analyze the reply and return JSON:
{
    "sentiment": "positive/neutral/negative",
    "priceOffered": null or number,
    "acceptsOffer": true/false,
    "makesCounterOffer": true/false,
    "shouldRespond": true/false,
    "isFinalized": true/false,
    "agreedPrice": null or number,
    "responseStrategy": "accept/counter/negotiate/thank/clarify",
    "suggestedResponse": "brief response if shouldRespond is true",
    "negotiationPhase": "initial/bargaining/closing/rejected"
}

ANALYSIS RULES:
- "sure", "yes", "ok", "sounds good" = acceptance of last offer
- If they accept: isFinalized=true, agreedPrice=last offered price
- If they counter with price: extract exact number, shouldRespond=true
- If they say "market price isn't $X": shouldRespond=true with market data
- If outright rejection: shouldRespond=true for one final attempt
- Simple positive words like "sure" mean agreement to last proposal
- Extract prices carefully: look for $XXX or XXX/month patterns
```

**iOS Implementation (Line 313-338):**
```swift
Analyze this landlord reply and return ONLY valid JSON:

Reply: "{replyContent}"

Property: {listing.displayTitle}
Listed Price: {listing.displayPrice}
Current Negotiation State: {currentState.displayName}

Return this exact JSON structure:
{
  "sentiment": "positive/neutral/negative",
  "price_offered": 1400.0,
  "accepts_offer": false,
  "makes_counter_offer": true,
  "should_respond": true,
  "is_finalized": false,
  "agreed_price": null,
  "response_strategy": "counter/acceptance/clarification",
  "suggested_response": "Professional response message",
  "negotiation_phase": "negotiating/counter_offer/finalized"
}

Extract any prices mentioned. Determine if landlord accepts, counters, or rejects.
```

**Differences:**
- Web uses camelCase for JSON keys, iOS uses snake_case
- Web includes detailed "ANALYSIS RULES" section
- Web includes conversation history and last AI offer
- Web has more response strategies (accept/counter/negotiate/thank/clarify vs counter/acceptance/clarification)
- Web has more negotiation phases (initial/bargaining/closing/rejected vs negotiating/counter_offer/finalized)

### 4. Temperature and Model Settings

**Web Implementation:**
- Temperature: 0.3 for market data, 0.7 for negotiation messages, 0.1 for reply analysis
- Model: `gpt-3.5-turbo` (default)
- Max tokens: 300 for market data, 150 for messages, 250 for analysis

**iOS Implementation:**
- Temperature: 0.7 (consistent across all requests)
- Model: `gpt-4o-mini` (default)
- Max tokens: 1000 (consistent across all requests)

### 5. Counter-Response Generation

**Web Implementation (Line 1053-1076):**
- Has detailed "NEGOTIATION CONTEXT" with final attempt tracking
- Includes "RESPONSE STRATEGY" with 6 numbered points
- Has "PRICING LOGIC" section with specific conditions
- Uses GPT-4 model for this specific function

**iOS Implementation (Line 342-361):**
- Much simpler prompt structure
- No detailed strategy or pricing logic
- No tracking of final attempts
- Uses the default model configuration

## Recommended Fixes for Full Parity

1. **Standardize JSON Response Formats:**
   - Use consistent key naming (camelCase vs snake_case)
   - Ensure `negotiationTips` is an array in both implementations
   - Add `count` field to web implementation's market data

2. **Align Prompt Instructions:**
   - Add detailed negotiation strategy and pricing logic to iOS
   - Include conversation history in iOS reply analysis
   - Add analysis rules section to iOS implementation

3. **Temperature and Model Settings:**
   - Consider using variable temperature based on the type of request
   - Standardize on either GPT-3.5-turbo or GPT-4o-mini
   - Adjust max tokens per request type

4. **Add Missing Context:**
   - Include utilities information in iOS
   - Add data source tracking in iOS
   - Include final attempt tracking in iOS

5. **Response Strategy Options:**
   - Expand iOS response strategies to match web (add negotiate/thank options)
   - Align negotiation phases between implementations

## Critical Differences That May Affect Behavior

1. The web implementation has much more detailed prompt engineering with specific rules and logic
2. The iOS implementation uses different temperature settings which may result in more creative responses
3. The JSON contract differences could cause parsing issues if responses are shared between platforms
4. The web implementation tracks conversation history more comprehensively

These differences should be resolved to ensure consistent AI behavior across both platforms.