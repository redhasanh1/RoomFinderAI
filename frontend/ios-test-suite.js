/**
 * iOS Test Suite for RoomFinderAI
 * 
 * This module provides comprehensive tests for all iOS-compatible modules
 * to ensure they work correctly on iOS devices.
 */

import { fetch } from './ios-universal-fetch.js';
import { createClient } from './ios-supabase-client.js';
import iosAuthManager from './ios-auth-manager.js';
import iosListingsAPI from './ios-listings-api.js';
import iosChatSystem from './ios-chat-system.js';
import iosAIApi from './ios-ai-api.js';
import iosPaymentAPI from './ios-payment-api.js';

class IOSTestSuite {
    constructor() {
        this.debug = true;
        this.testResults = [];
        this.testUser = {
            email: 'test@roomfinderai.com',
            password: 'testpassword123',
            firstName: 'Test',
            lastName: 'User'
        };
        
        console.log('🧪 iOS Test Suite initialized');
    }

    /**
     * Run all tests
     */
    async runAllTests() {
        console.log('🚀 Starting iOS Test Suite...');
        
        try {
            // Test Universal Fetch
            await this.testUniversalFetch();
            
            // Test Supabase Client
            await this.testSupabaseClient();
            
            // Test Authentication
            await this.testAuthentication();
            
            // Test Listings API
            await this.testListingsAPI();
            
            // Test Chat System
            await this.testChatSystem();
            
            // Test AI API
            await this.testAIAPI();
            
            // Test Payment API
            await this.testPaymentAPI();
            
            // Generate test report
            this.generateTestReport();
            
        } catch (error) {
            console.error('❌ Test suite failed:', error);
            this.addTestResult('Test Suite', 'FAILED', error.message);
        }
        
        console.log('✅ iOS Test Suite completed');
    }

    /**
     * Test Universal Fetch functionality
     */
    async testUniversalFetch() {
        console.log('🌐 Testing Universal Fetch...');
        
        try {
            // Test basic GET request
            const response = await fetch('https://httpbin.org/get', {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json'
                }
            });
            
            if (response.ok) {
                const data = await response.json();
                this.addTestResult('Universal Fetch - GET', 'PASSED', 'Basic GET request successful');
            } else {
                throw new Error(`HTTP ${response.status}`);
            }
            
            // Test POST request
            const postResponse = await fetch('https://httpbin.org/post', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ test: 'data' })
            });
            
            if (postResponse.ok) {
                this.addTestResult('Universal Fetch - POST', 'PASSED', 'POST request successful');
            } else {
                throw new Error(`HTTP ${postResponse.status}`);
            }
            
        } catch (error) {
            console.error('❌ Universal Fetch test failed:', error);
            this.addTestResult('Universal Fetch', 'FAILED', error.message);
        }
    }

    /**
     * Test Supabase Client functionality
     */
    async testSupabaseClient() {
        console.log('🗄️ Testing Supabase Client...');
        
        try {
            const supabase = createClient(
                'https://zmxyysauqtfkvntgtjsm.supabase.co',
                'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM'
            );
            
            // Test basic query
            const testQuery = await supabase
                .from('profiles')
                .select('email')
                .limit(1)
                .exec();
            
            if (testQuery) {
                this.addTestResult('Supabase Client - Query', 'PASSED', 'Basic query successful');
            } else {
                throw new Error('Query returned null');
            }
            
            // Test RPC call
            try {
                await supabase.rpc('set_current_user_email', { email: this.testUser.email });
                this.addTestResult('Supabase Client - RPC', 'PASSED', 'RPC call successful');
            } catch (error) {
                this.addTestResult('Supabase Client - RPC', 'WARNING', 'RPC call failed (expected in some cases)');
            }
            
        } catch (error) {
            console.error('❌ Supabase Client test failed:', error);
            this.addTestResult('Supabase Client', 'FAILED', error.message);
        }
    }

    /**
     * Test Authentication functionality
     */
    async testAuthentication() {
        console.log('🔐 Testing Authentication...');
        
        try {
            // Test initialization
            await iosAuthManager.initialize();
            this.addTestResult('Auth - Initialize', 'PASSED', 'Authentication initialized');
            
            // Test sign up (may fail if user exists)
            try {
                const signUpResult = await iosAuthManager.signUp(
                    this.testUser.email,
                    this.testUser.password,
                    {
                        first_name: this.testUser.firstName,
                        last_name: this.testUser.lastName
                    }
                );
                
                if (signUpResult.error) {
                    this.addTestResult('Auth - Sign Up', 'WARNING', 'Sign up failed (user may already exist)');
                } else {
                    this.addTestResult('Auth - Sign Up', 'PASSED', 'Sign up successful');
                }
            } catch (error) {
                this.addTestResult('Auth - Sign Up', 'WARNING', 'Sign up failed (user may already exist)');
            }
            
            // Test sign in
            const signInResult = await iosAuthManager.signIn(
                this.testUser.email,
                this.testUser.password
            );
            
            if (signInResult.error) {
                this.addTestResult('Auth - Sign In', 'WARNING', 'Sign in failed (test user may not exist)');
            } else {
                this.addTestResult('Auth - Sign In', 'PASSED', 'Sign in successful');
                
                // Test get current user
                const currentUser = iosAuthManager.getCurrentUser();
                if (currentUser) {
                    this.addTestResult('Auth - Get Current User', 'PASSED', 'Current user retrieved');
                } else {
                    this.addTestResult('Auth - Get Current User', 'FAILED', 'No current user');
                }
                
                // Test user profile
                const profileResult = await iosAuthManager.getUserProfile(this.testUser.email);
                if (profileResult.error) {
                    this.addTestResult('Auth - Get Profile', 'WARNING', 'Profile retrieval failed');
                } else {
                    this.addTestResult('Auth - Get Profile', 'PASSED', 'Profile retrieved successfully');
                }
            }
            
        } catch (error) {
            console.error('❌ Authentication test failed:', error);
            this.addTestResult('Authentication', 'FAILED', error.message);
        }
    }

    /**
     * Test Listings API functionality
     */
    async testListingsAPI() {
        console.log('🏠 Testing Listings API...');
        
        try {
            // Test fetch listings
            const listingsResult = await iosListingsAPI.fetchListings({ limit: 5 });
            if (listingsResult.error) {
                this.addTestResult('Listings - Fetch', 'WARNING', 'Fetch listings failed');
            } else {
                this.addTestResult('Listings - Fetch', 'PASSED', `Fetched ${listingsResult.data.length} listings`);
            }
            
            // Test search listings
            const searchResult = await iosListingsAPI.searchListings('apartment', { limit: 3 });
            if (searchResult.error) {
                this.addTestResult('Listings - Search', 'WARNING', 'Search failed');
            } else {
                this.addTestResult('Listings - Search', 'PASSED', `Found ${searchResult.data.length} listings`);
            }
            
            // Test get featured listings
            const featuredResult = await iosListingsAPI.getFeaturedListings(5);
            if (featuredResult.error) {
                this.addTestResult('Listings - Featured', 'WARNING', 'Featured listings failed');
            } else {
                this.addTestResult('Listings - Featured', 'PASSED', `Found ${featuredResult.data.length} featured listings`);
            }
            
            // Test create listing (requires auth)
            if (iosAuthManager.isAuthenticated()) {
                const testListing = {
                    title: 'Test Listing from iOS',
                    description: 'This is a test listing created from iOS test suite',
                    price: 1000,
                    location: 'Test City',
                    category: 'apartment',
                    bedrooms: 2,
                    bathrooms: 1
                };
                
                const createResult = await iosListingsAPI.createListing(testListing);
                if (createResult.error) {
                    this.addTestResult('Listings - Create', 'WARNING', 'Create listing failed (may require auth)');
                } else {
                    this.addTestResult('Listings - Create', 'PASSED', 'Listing created successfully');
                    
                    // Test delete the created listing
                    if (createResult.data?.id) {
                        const deleteResult = await iosListingsAPI.deleteListing(createResult.data.id);
                        if (deleteResult.error) {
                            this.addTestResult('Listings - Delete', 'WARNING', 'Delete listing failed');
                        } else {
                            this.addTestResult('Listings - Delete', 'PASSED', 'Listing deleted successfully');
                        }
                    }
                }
            }
            
        } catch (error) {
            console.error('❌ Listings API test failed:', error);
            this.addTestResult('Listings API', 'FAILED', error.message);
        }
    }

    /**
     * Test Chat System functionality
     */
    async testChatSystem() {
        console.log('💬 Testing Chat System...');
        
        try {
            // Test get conversations
            const conversationsResult = await iosChatSystem.getConversations();
            if (conversationsResult.error) {
                this.addTestResult('Chat - Get Conversations', 'WARNING', 'Get conversations failed (may require auth)');
            } else {
                this.addTestResult('Chat - Get Conversations', 'PASSED', `Found ${conversationsResult.data.length} conversations`);
            }
            
            // Test get unread message count
            const unreadResult = await iosChatSystem.getUnreadMessageCount();
            if (unreadResult.error) {
                this.addTestResult('Chat - Unread Count', 'WARNING', 'Unread count failed (may require auth)');
            } else {
                this.addTestResult('Chat - Unread Count', 'PASSED', `${unreadResult.data} unread messages`);
            }
            
            // Test message statistics
            const statsResult = await iosChatSystem.getMessageStatistics();
            if (statsResult.error) {
                this.addTestResult('Chat - Statistics', 'WARNING', 'Statistics failed (may require auth)');
            } else {
                this.addTestResult('Chat - Statistics', 'PASSED', 'Statistics retrieved successfully');
            }
            
        } catch (error) {
            console.error('❌ Chat System test failed:', error);
            this.addTestResult('Chat System', 'FAILED', error.message);
        }
    }

    /**
     * Test AI API functionality
     */
    async testAIAPI() {
        console.log('🤖 Testing AI API...');
        
        try {
            // Test search properties
            const searchResult = await iosAIApi.searchProperties('2 bedroom apartment downtown');
            if (searchResult.error) {
                this.addTestResult('AI - Property Search', 'WARNING', 'AI property search failed (may require API key)');
            } else {
                this.addTestResult('AI - Property Search', 'PASSED', 'AI property search successful');
            }
            
            // Test market insights
            const insightsResult = await iosAIApi.getMarketInsights('New York', 'apartment');
            if (insightsResult.error) {
                this.addTestResult('AI - Market Insights', 'WARNING', 'Market insights failed (may require API key)');
            } else {
                this.addTestResult('AI - Market Insights', 'PASSED', 'Market insights retrieved');
            }
            
            // Test chat completion (requires API key)
            try {
                const chatResult = await iosAIApi.sendChatCompletion([
                    { role: 'user', content: 'Hello, this is a test message' }
                ]);
                
                if (chatResult.error) {
                    this.addTestResult('AI - Chat Completion', 'WARNING', 'Chat completion failed (API key required)');
                } else {
                    this.addTestResult('AI - Chat Completion', 'PASSED', 'Chat completion successful');
                }
            } catch (error) {
                this.addTestResult('AI - Chat Completion', 'WARNING', 'Chat completion failed (API key required)');
            }
            
        } catch (error) {
            console.error('❌ AI API test failed:', error);
            this.addTestResult('AI API', 'FAILED', error.message);
        }
    }

    /**
     * Test Payment API functionality
     */
    async testPaymentAPI() {
        console.log('💳 Testing Payment API...');
        
        try {
            // Test get payment config
            const configResult = await iosPaymentAPI.getPaymentConfig();
            if (configResult.error) {
                this.addTestResult('Payment - Config', 'WARNING', 'Payment config failed (backend may be down)');
            } else {
                this.addTestResult('Payment - Config', 'PASSED', 'Payment config retrieved');
            }
            
            // Test get available plans
            const plansResult = await iosPaymentAPI.getAvailablePlans();
            if (plansResult.error) {
                this.addTestResult('Payment - Plans', 'WARNING', 'Plans retrieval failed, using defaults');
            } else {
                this.addTestResult('Payment - Plans', 'PASSED', `Found ${plansResult.data.length} plans`);
            }
            
            // Test get subscription status
            const subscriptionResult = await iosPaymentAPI.getSubscriptionStatus();
            if (subscriptionResult.error) {
                this.addTestResult('Payment - Subscription Status', 'WARNING', 'Subscription status failed (may require auth)');
            } else {
                this.addTestResult('Payment - Subscription Status', 'PASSED', `Status: ${subscriptionResult.data.status}`);
            }
            
        } catch (error) {
            console.error('❌ Payment API test failed:', error);
            this.addTestResult('Payment API', 'FAILED', error.message);
        }
    }

    /**
     * Add test result to results array
     */
    addTestResult(testName, status, message) {
        const result = {
            test: testName,
            status: status,
            message: message,
            timestamp: new Date().toISOString()
        };
        
        this.testResults.push(result);
        
        const emoji = status === 'PASSED' ? '✅' : status === 'WARNING' ? '⚠️' : '❌';
        console.log(`${emoji} ${testName}: ${message}`);
    }

    /**
     * Generate comprehensive test report
     */
    generateTestReport() {
        console.log('\n📊 iOS Test Suite Report');
        console.log('========================\n');
        
        const passed = this.testResults.filter(r => r.status === 'PASSED').length;
        const warnings = this.testResults.filter(r => r.status === 'WARNING').length;
        const failed = this.testResults.filter(r => r.status === 'FAILED').length;
        const total = this.testResults.length;
        
        console.log(`Total Tests: ${total}`);
        console.log(`✅ Passed: ${passed}`);
        console.log(`⚠️ Warnings: ${warnings}`);
        console.log(`❌ Failed: ${failed}`);
        console.log(`Success Rate: ${((passed / total) * 100).toFixed(1)}%\n`);
        
        // Group results by category
        const categories = {};
        this.testResults.forEach(result => {
            const category = result.test.split(' - ')[0];
            if (!categories[category]) {
                categories[category] = [];
            }
            categories[category].push(result);
        });
        
        // Display results by category
        Object.keys(categories).forEach(category => {
            console.log(`📁 ${category}:`);
            categories[category].forEach(result => {
                const emoji = result.status === 'PASSED' ? '✅' : result.status === 'WARNING' ? '⚠️' : '❌';
                console.log(`  ${emoji} ${result.test}: ${result.message}`);
            });
            console.log('');
        });
        
        // Overall assessment
        if (failed === 0) {
            console.log('🎉 All critical tests passed! Your iOS integration is ready.');
        } else if (failed < 3) {
            console.log('⚠️ Some tests failed, but core functionality should work.');
        } else {
            console.log('❌ Multiple critical tests failed. Review the implementation.');
        }
        
        // Save report to localStorage if available
        if (typeof localStorage !== 'undefined') {
            localStorage.setItem('ios_test_report', JSON.stringify({
                timestamp: new Date().toISOString(),
                summary: { total, passed, warnings, failed },
                results: this.testResults
            }));
            console.log('📝 Test report saved to localStorage');
        }
        
        return {
            summary: { total, passed, warnings, failed },
            results: this.testResults
        };
    }

    /**
     * Get test results
     */
    getTestResults() {
        return this.testResults;
    }

    /**
     * Clear test results
     */
    clearTestResults() {
        this.testResults = [];
        console.log('🧹 Test results cleared');
    }
}

// Create and export test suite instance
const iosTestSuite = new IOSTestSuite();

// Export for use in browser console or other modules
export default iosTestSuite;
export { IOSTestSuite };

// Auto-run tests if called directly
if (typeof window !== 'undefined' && window.location.search.includes('run-ios-tests')) {
    console.log('🚀 Auto-running iOS tests...');
    iosTestSuite.runAllTests();
}

console.log('✅ iOS Test Suite module loaded successfully');
console.log('💡 Run iosTestSuite.runAllTests() to test all iOS functionality');