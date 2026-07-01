/**
 * Test script to verify listing user information is saved correctly
 * Run this in your browser console on the listings page
 */

async function testListingUserInfo() {
    console.log('🔍 Testing listing user information...');
    
    try {
        // Test 1: Check if ListingsAPI is available
        if (!window.ListingsAPI) {
            console.error('❌ ListingsAPI not available');
            return;
        }
        
        // Test 2: Fetch recent listings and check user info
        console.log('📋 Fetching listings...');
        const result = await window.ListingsAPI.fetchListings({}, { page: 1, limit: 5 });
        
        if (!result.data || result.data.length === 0) {
            console.warn('⚠️ No listings found');
            return;
        }
        
        console.log(`✅ Found ${result.data.length} listings`);
        
        // Test 3: Analyze each listing for user information
        let listingsWithUserInfo = 0;
        let listingsWithoutUserInfo = 0;
        
        result.data.forEach((listing, index) => {
            const hasUserId = !!listing.user_id;
            const hasUserEmail = !!listing.user_email;
            const hasId = !!listing.id;
            
            console.log(`\n📝 Listing ${index + 1}:`);
            console.log(`  Title: ${listing.title}`);
            console.log(`  ID: ${hasId ? '✅' : '❌'} ${listing.id || 'MISSING'}`);
            console.log(`  User ID: ${hasUserId ? '✅' : '❌'} ${listing.user_id || 'MISSING'}`);
            console.log(`  User Email: ${hasUserEmail ? '✅' : '❌'} ${listing.user_email || 'MISSING'}`);
            console.log(`  Created: ${listing.created_at || 'MISSING'}`);
            
            if (hasUserId && hasUserEmail && hasId) {
                listingsWithUserInfo++;
            } else {
                listingsWithoutUserInfo++;
            }
        });
        
        // Test 4: Summary
        console.log('\n📊 SUMMARY:');
        console.log(`✅ Listings with complete user info: ${listingsWithUserInfo}`);
        console.log(`❌ Listings missing user info: ${listingsWithoutUserInfo}`);
        
        if (listingsWithoutUserInfo === 0) {
            console.log('🎉 ALL LISTINGS HAVE PROPER USER INFORMATION!');
        } else {
            console.log('⚠️ Some listings are missing user information. These might be old listings created before the fix.');
        }
        
        // Test 5: Test individual listing fetch
        if (result.data.length > 0) {
            const firstListing = result.data[0];
            console.log(`\n🔍 Testing individual listing fetch for: ${firstListing.title}`);
            
            const detailedListing = await window.ListingsAPI.getListingById(firstListing.id);
            console.log('📋 Detailed listing user info:');
            console.log(`  User ID: ${detailedListing.user_id || 'MISSING'}`);
            console.log(`  User Email: ${detailedListing.user_email || 'MISSING'}`);
        }
        
    } catch (error) {
        console.error('❌ Error testing listings:', error);
    }
}

// Test if current user is authenticated
async function testUserAuthentication() {
    console.log('\n👤 Testing user authentication...');
    
    try {
        if (window.ClientConfig && window.ClientConfig.getSupabaseClient) {
            const supabase = window.ClientConfig.getSupabaseClient();
            const { data: { user }, error } = await supabase.auth.getUser();
            
            if (error) {
                console.error('❌ Auth error:', error);
                return;
            }
            
            if (user) {
                console.log('✅ User authenticated:');
                console.log(`  ID: ${user.id}`);
                console.log(`  Email: ${user.email}`);
            } else {
                console.log('❌ No authenticated user');
            }
        } else {
            console.error('❌ Supabase client not available');
        }
    } catch (error) {
        console.error('❌ Error checking authentication:', error);
    }
}

// Run both tests
console.log('🚀 Starting listing user information tests...');
testUserAuthentication();
testListingUserInfo();