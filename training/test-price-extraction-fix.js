// Test script to verify Chat #004 price extraction fixes

console.log('🧪 Testing Price Extraction Fixes');

// Simulate the problematic scenario from Chat #004
const testNegotiation = {
    messages: [
        {
            content: "I am very interested in the Indiana house listing in Indianapolis. As a qualified tenant ready to move quickly, I am impressed with the property. However, considering the listing price is at the market average and my budget, would you be willing to consider a slight adjustment to make it more feasible for both parties?",
            timestamp: new Date()
        },
        {
            content: "yes ill consider as slight adjustment but not to much",
            timestamp: new Date()
        }
    ],
    userBudget: 1200,
    originalPrice: 1500,
    listingId: 'test-123'
};

// Mock a basic AINegotiationEngine to test the extractLastOfferedPrice function
class TestAINegotiationEngine {
    extractLastOfferedPrice(negotiation) {
        try {
            console.log('🔍 Extracting last offered price from negotiation...');
            
            // First, check if there's an explicitly stored final price
            if (negotiation.finalPrice) {
                console.log('✅ Found stored final price:', negotiation.finalPrice);
                return negotiation.finalPrice;
            }
            
            // Look through all recent messages (AI and landlord) for price mentions
            const recentMessages = negotiation.messages?.slice(-5) || [];
            
            for (let i = recentMessages.length - 1; i >= 0; i--) {
                const message = recentMessages[i].content;
                
                // Enhanced price matching patterns
                const priceMatches = [
                    /\$(\d+)\/month/gi,
                    /\$(\d+)\s*per\s*month/gi,
                    /\$(\d+)\s*monthly/gi,
                    /(\d+)\/month/gi,
                    /(\d+)\s*per\s*month/gi,
                    /(\d+)\s*monthly/gi,
                    // Also match simple number patterns when context is about price
                    /(?:accept|agreed?|deal|works?|sounds?\s+good).*?(\d{3,4})(?!\d)/gi,
                    /(\d{3,4})(?!\d).*?(?:accept|agreed?|deal|works?|sounds?\s+good)/gi
                ];
                
                for (const pattern of priceMatches) {
                    const matches = [...message.matchAll(pattern)];
                    if (matches.length > 0) {
                        const price = parseInt(matches[0][1]);
                        if (price >= 100 && price <= 5000) { // Reasonable rent range
                            console.log(`✅ Found price ${price} in message: "${message.substring(0, 50)}..."`);
                            return price;
                        }
                    }
                }
            }
            
            // Fallback to user budget if no specific price found
            const fallbackPrice = negotiation.userBudget || negotiation.originalPrice || 1500;
            console.log('⚠️ No price found, using fallback:', fallbackPrice);
            return fallbackPrice;
        } catch (error) {
            console.error('Error extracting last offered price:', error);
            const fallbackPrice = negotiation.userBudget || negotiation.originalPrice || 1500;
            console.log('✅ Error fallback price:', fallbackPrice);
            return fallbackPrice;
        }
    }

    generateVariedAcceptanceResponse(finalPrice, negotiationId, roundNumber) {
        // CRITICAL: Ensure finalPrice is never null/undefined/0
        if (!finalPrice || finalPrice <= 0) {
            console.error('❌ CRITICAL: Invalid finalPrice detected:', finalPrice);
            finalPrice = 1200; // Test fallback
            console.log('✅ Using fallback price:', finalPrice);
        }
        
        const template = "Perfect! $${price}/month is exactly what I was hoping for.";
        const baseResponse = template.replace('${price}', finalPrice);
        const confirmation = `Excellent! To make sure we're on the same page - $${finalPrice}/month works for both of us?`;
        
        return `${baseResponse} ${confirmation}`;
    }

    // Test vague response detection
    analyzeVagueResponse(replyContent) {
        const vageResponsePatterns = /\b(sure but|maybe|i guess|i mean|kinda|sorta|a little|somewhat|perhaps|slight adjustment|small adjustment|little adjustment|minor change)\b/i;
        return vageResponsePatterns.test(replyContent);
    }
}

// Run the tests
const testEngine = new TestAINegotiationEngine();

console.log('\n📋 Test 1: Price Extraction');
const extractedPrice = testEngine.extractLastOfferedPrice(testNegotiation);
console.log('Result:', extractedPrice);
console.log('Expected: Should be 1200 (userBudget) since no price in messages');

console.log('\n📋 Test 2: Response Generation with Extracted Price');
const response = testEngine.generateVariedAcceptanceResponse(extractedPrice, 'test-123', 1);
console.log('Result:', response);
console.log('Expected: Should contain valid price, not $null or $0');

console.log('\n📋 Test 3: Vague Response Detection');
const isVague = testEngine.analyzeVagueResponse("yes ill consider as slight adjustment but not to much");
console.log('Result:', isVague);
console.log('Expected: true (should detect "slight adjustment" as vague)');

console.log('\n📋 Test 4: Null Price Handling');
const nullResponse = testEngine.generateVariedAcceptanceResponse(null, 'test-123', 1);
console.log('Result:', nullResponse);
console.log('Expected: Should use fallback price, not $null');

console.log('\n✅ All tests completed!');