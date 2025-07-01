// Integration test for the enhanced AI negotiation system
console.log('🧪 Testing Enhanced AI Negotiation Integration');

// Mock the environment for testing
if (typeof window === 'undefined') {
    global.window = {};
    global.fetch = require('node-fetch');
}

// Test the manual extraction fallback
function testManualExtractionFallback() {
    console.log('\n📋 Test: Manual Extraction Fallback');
    
    // Mock AIChatHandler with the manual extraction method
    class MockAIChatHandler {
        constructor() {
            this.config = { OPENAI_API_KEY: null }; // No API key to force fallback
        }
        
        // This is the manual extraction method from ai-chat.js
        extractManually(message) {
            console.log('Using manual extraction for:', message);
            const result = {};
            
            // Extract price - improved regex to catch more patterns
            const priceMatch = message.match(/(?:under|below|max|up to|for|at|around)?\s*\$?(\d{1,5})/i);
            if (priceMatch) {
                const extractedPrice = Number(priceMatch[1]);
                if (extractedPrice > 100) {
                    result.price = extractedPrice;
                    console.log('💰 Extracted price:', extractedPrice);
                }
            }
            
            // Extract city
            const cityMatch = message.match(/\b(karachi|paris|tehran|toronto|moscow|sydney|vancouver|montreal|calgary|ottawa|islamabad|lahore|rawalpindi)\b/i);
            if (cityMatch) {
                result.city = cityMatch[1].toLowerCase().trim();
                console.log('🏙️ Extracted city:', result.city);
            }
            
            // Set intent
            if (message.toLowerCase().includes('looking for') || 
                message.toLowerCase().includes('need') || 
                message.toLowerCase().includes('want') ||
                message.toLowerCase().includes('find') ||
                message.toLowerCase().includes('search')) {
                result.intent = 'search';
            }
            
            return result;
        }
        
        async extractWithOpenAI(message) {
            throw new Error('OpenAI API key not configured');
        }
        
        async extractRentalInfo(message) {
            console.log('🔍 Extracting rental info from:', message);
            
            try {
                // Try OpenAI first
                const openAIResult = await this.extractWithOpenAI(message);
                console.log('🎯 OpenAI extracted:', openAIResult);
                return openAIResult;
            } catch (error) {
                console.log('⚠️ OpenAI extraction failed:', error.message);
                console.log('🔄 Falling back to manual extraction...');
                
                try {
                    const manualResult = this.extractManually(message);
                    console.log('🎯 Manual extraction result:', manualResult);
                    return manualResult;
                } catch (manualError) {
                    console.error('❌ Both OpenAI and manual extraction failed:', manualError);
                    throw new Error(`Extraction failed: ${error.message}`);
                }
            }
        }
    }
    
    const handler = new MockAIChatHandler();
    
    const testMessages = [
        "I need a 2-bedroom apartment under $1500 in Toronto",
        "Looking for a house in Calgary under $1200",
        "I want something in Paris for $1000"
    ];
    
    testMessages.forEach(async (message, i) => {
        console.log(`\n--- Test Case ${i + 1}: "${message}" ---`);
        try {
            const result = await handler.extractRentalInfo(message);
            console.log('✅ Extraction successful:', result);
        } catch (error) {
            console.log('❌ Extraction failed:', error.message);
        }
    });
}

// Test price validation
function testPriceValidation() {
    console.log('\n📋 Test: Price Validation');
    
    const testPrices = [null, undefined, 0, -100, 1500, '1200'];
    
    testPrices.forEach(price => {
        const isValid = price && price > 0;
        const safePrice = isValid ? price : 1500;
        const priceDisplay = isValid ? `$${price}/month` : 'price available on request';
        
        console.log(`Price: ${price} → Valid: ${isValid} → Display: "${priceDisplay}" → Safe: ${safePrice}`);
    });
}

// Run tests
testManualExtractionFallback();
testPriceValidation();

console.log('\n✅ Integration tests completed!');