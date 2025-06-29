// Training Parameters for AI Negotiation
// Keep main ai-negotiation.js clean by storing training data here

export const TrainingParameters = {
    // Security deposit detection patterns (enhanced)
    securityDepositPatterns: [
        /\b(security deposit|deposit|first month|payment|money|transfer|funds|rent upfront)\b/i,
        /\b(i need|need|require|want).*(deposit|payment|money)\b/i,
        /\b(deposit|payment).*(required|needed|necessary)\b/i
    ],

    // Landlord request patterns (for direction detection)
    landlordIncreasePatterns: [
        /\b(i want|want|need|require)\s*\$?(\d+)/i,
        /\b(can you|could you|would you).*(raise|increase|go up|higher)/i,
        /\b(too low|not enough|raise it|increase it|go higher)/i,
        /\b(my minimum|at least|no less than)\s*\$?(\d+)/i
    ],

    // Price negotiation direction logic
    negotiationDirection: {
        // When landlord asks for MORE money, tenant should consider going UP
        whenLandlordWantsHigher: {
            strategy: 'increase',
            maxIncrease: 0.03, // Max 3% increase per round
            description: 'Landlord asking for higher price - tenant should increase offer'
        },
        
        // When landlord says price is too high, tenant should go DOWN  
        whenLandlordSaysTooHigh: {
            strategy: 'decrease',
            maxDecrease: 0.05, // Max 5% decrease per round
            description: 'Landlord says too high - tenant should lower offer'
        }
    },

    // Response continuation patterns
    responsePatterns: {
        alwaysRespond: [
            /\b(can you|could you|would you|will you)/i,
            /\b(what about|how about|what if)/i,
            /\b(raise|increase|lower|decrease)/i,
            /\b(deposit|payment|money)/i,
            /\b(when|where|how|why)/i
        ]
    },

    // Context detection
    contextPatterns: {
        landlordPerspective: [
            /\b(i want|i need|my minimum|my price)/i,
            /\b(too low|not enough|raise it)/i,
            /\b(deposit|payment).*(required|needed)/i
        ],
        
        tenantPerspective: [
            /\b(my budget|i can afford|my max)/i,
            /\b(too high|too expensive|lower)/i,
            /\b(can you do|would you accept)/i
        ]
    }
};

// Helper functions for training
export const TrainingHelpers = {
    // Detect if message is asking for price increase
    isRequestingIncrease(message) {
        return TrainingParameters.landlordIncreasePatterns.some(pattern => 
            pattern.test(message)
        );
    },

    // Detect security deposit mention with enhanced patterns
    isSecurityDepositMention(message) {
        return TrainingParameters.securityDepositPatterns.some(pattern =>
            pattern.test(message)
        );
    },

    // Calculate negotiation direction
    calculateDirection(lastOffer, landlordRequest, context) {
        const requestedPrice = this.extractPrice(landlordRequest);
        
        if (requestedPrice && requestedPrice > lastOffer) {
            // Landlord wants more - tenant should consider going up
            const maxIncrease = lastOffer * TrainingParameters.negotiationDirection.whenLandlordWantsHigher.maxIncrease;
            return Math.min(requestedPrice, lastOffer + maxIncrease);
        }
        
        return lastOffer; // No change needed
    },

    // Extract price from message
    extractPrice(message) {
        const priceMatch = message.match(/\$?(\d+)/);
        return priceMatch ? parseInt(priceMatch[1]) : null;
    }
};

// Export for use in main AI files
if (typeof window !== 'undefined') {
    window.TrainingParameters = TrainingParameters;
    window.TrainingHelpers = TrainingHelpers;
}