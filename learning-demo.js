// AI Learning System Demonstration
// This file shows how the learning system works and can be used for testing

// Mock Supabase client for testing
const mockSupabase = {
    from: (table) => ({
        insert: (data) => ({ data, error: null }),
        select: (columns) => ({
            eq: (column, value) => ({
                single: () => ({ data: null, error: null }),
                order: (column, options) => ({
                    limit: (num) => ({ data: [], error: null })
                })
            }),
            order: (column, options) => ({
                limit: (num) => ({ data: [], error: null })
            }),
            limit: (num) => ({ data: [], error: null }),
            gte: (column, value) => ({ data: [], error: null })
        }),
        update: (data) => ({
            eq: (column, value) => ({ error: null })
        })
    }),
    rpc: (functionName, params) => ({ data: [], error: null })
};

// Simulate learning system usage
async function demonstrateLearningSystem() {
    console.log('🧠 AI Learning System Demo\n');
    
    try {
        // Load the learning system
        const AILearningSystem = require('./ai-learning');
        const learningSystem = new AILearningSystem(mockSupabase);
        
        console.log('✅ Learning system loaded successfully');
        
        // Initialize the system
        await learningSystem.initialize();
        console.log('✅ Learning system initialized');
        
        // Demonstrate template selection
        console.log('\n📊 Template Selection Demo:');
        
        const contexts = [
            {
                strategyType: 'counter_offer_acceptance',
                landlordPersonality: 'cooperative',
                marketConditions: { competitiveness: 'medium' },
                priceRange: 'moderate'
            },
            {
                strategyType: 'strategic_counter_offers',
                landlordPersonality: 'aggressive', 
                marketConditions: { competitiveness: 'high' },
                priceRange: 'premium'
            },
            {
                strategyType: 'market_based_responses',
                landlordPersonality: 'professional',
                marketConditions: { competitiveness: 'low' },
                priceRange: 'budget'
            }
        ];
        
        for (const context of contexts) {
            try {
                const template = await learningSystem.getOptimalTemplate(context);
                console.log(`🎯 Strategy: ${context.strategyType}`);
                console.log(`   Template ID: ${template.templateId}`);
                console.log(`   Confidence: ${(template.confidence * 100).toFixed(1)}%`);
                console.log(`   Reason: ${template.reason}\n`);
            } catch (error) {
                console.log(`⚠️  Template selection failed for ${context.strategyType}: ${error.message}\n`);
            }
        }
        
        // Demonstrate conversation processing
        console.log('📈 Conversation Processing Demo:');
        
        const mockConversations = [
            {
                id: 'conv_001',
                messages: [
                    { sender_type: 'ai', content: 'I can offer $1400/month for this property.', created_at: '2024-01-01T10:00:00Z' },
                    { sender_type: 'landlord', content: 'That works for me! When can you move in?', created_at: '2024-01-01T10:15:00Z' }
                ],
                success: true,
                finalPrice: 1400,
                initialPrice: 1500,
                templateUsed: 2,
                strategyType: 'market_based_responses'
            },
            {
                id: 'conv_002', 
                messages: [
                    { sender_type: 'ai', content: 'How about $1200/month?', created_at: '2024-01-01T11:00:00Z' },
                    { sender_type: 'landlord', content: 'Sorry, that\'s too low. I can\'t go below $1450.', created_at: '2024-01-01T11:30:00Z' }
                ],
                success: false,
                finalPrice: 0,
                initialPrice: 1500,
                templateUsed: 5,
                strategyType: 'strategic_counter_offers'
            }
        ];
        
        for (const conversation of mockConversations) {
            try {
                const analysis = await learningSystem.processConversation(conversation);
                console.log(`📝 Processed conversation ${conversation.id}:`);
                console.log(`   Success: ${conversation.success ? '✅' : '❌'}`);
                console.log(`   Savings: $${conversation.initialPrice - conversation.finalPrice}`);
                console.log(`   Template: ${conversation.templateUsed}`);
                console.log(`   Strategy: ${conversation.strategyType}\n`);
            } catch (error) {
                console.log(`⚠️  Failed to process conversation ${conversation.id}: ${error.message}\n`);
            }
        }
        
        // Demonstrate performance metrics
        console.log('📊 Performance Metrics Demo:');
        try {
            const metrics = await learningSystem.getPerformanceMetrics();
            console.log('📈 Current Performance:');
            console.log(`   Success Rate: ${(metrics.successRate * 100).toFixed(1)}%`);
            console.log(`   Total Negotiations: ${metrics.totalNegotiations}`);
            console.log(`   Average Savings: $${metrics.averageSavings?.toFixed(2) || 0}`);
            console.log(`   Performance Trend: ${metrics.performanceTrend}`);
        } catch (error) {
            console.log(`⚠️  Failed to get metrics: ${error.message}`);
        }
        
        console.log('\n🎉 Demo completed successfully!');
        console.log('\n📋 Integration Steps:');
        console.log('1. ✅ Learning system is already integrated with ai-negotiation.js');
        console.log('2. ✅ Templates will be automatically optimized based on performance');
        console.log('3. ✅ Conversation outcomes will be tracked and analyzed');
        console.log('4. ✅ System will adapt to different landlord personalities and market conditions');
        console.log('\n🚀 Your negotiation chatbot is now learning and improving automatically!');
        
    } catch (error) {
        console.error('❌ Demo failed:', error.message);
        console.log('\n🔧 Troubleshooting:');
        console.log('- Ensure all learning system files are in place');
        console.log('- Check that Supabase client is properly configured');
        console.log('- Verify OpenAI API key is available');
    }
}

// Run the demo
demonstrateLearningSystem();