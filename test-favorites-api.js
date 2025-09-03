const { createClient } = require('@supabase/supabase-js');
const fetch = require('node-fetch');

async function testFavoritesAPI() {
    try {
        console.log('🧪 Testing Favorites API endpoints...');
        
        // Test data
        const testEmail = 'qejlnfkjebf@gmail.com';
        const testListingId = 'a46626d6-62e3-462a-b150-bcf7f06b5f2e';
        
        // Start the server if not running (check port first)
        console.log('🔍 Checking if server is running...');
        
        try {
            const healthCheck = await fetch('http://localhost:3000/health');
            console.log('✅ Server is running');
        } catch (err) {
            console.log('❌ Server not running. Please start the server first with: node backend/server.js');
            return;
        }
        
        // Test 1: Add to favorites
        console.log('\n➕ Testing POST /api/favorites...');
        const addResponse = await fetch('http://localhost:3000/api/favorites', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                listingId: testListingId,
                userEmail: testEmail
            })
        });
        
        const addResult = await addResponse.json();
        console.log('Add response:', addResponse.status, addResult);
        
        // Test 2: Get favorites
        console.log('\n📋 Testing GET /api/favorites...');
        const getResponse = await fetch(`http://localhost:3000/api/favorites?userEmail=${encodeURIComponent(testEmail)}`);
        const favorites = await getResponse.json();
        console.log('Get response:', getResponse.status, `Found ${favorites?.length || 0} favorites`);
        
        if (favorites?.length > 0) {
            console.log('📄 Sample favorite:', {
                title: favorites[0].title,
                price: favorites[0].price,
                favorited_at: favorites[0].favorited_at
            });
        }
        
        // Test 3: Check favorites
        console.log('\n🔍 Testing POST /api/favorites/check...');
        const checkResponse = await fetch('http://localhost:3000/api/favorites/check', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                listingIds: [testListingId],
                userEmail: testEmail
            })
        });
        
        const checkResult = await checkResponse.json();
        console.log('Check response:', checkResponse.status, checkResult);
        
        // Test 4: Remove from favorites
        console.log('\n➖ Testing DELETE /api/favorites...');
        const deleteResponse = await fetch(`http://localhost:3000/api/favorites/${testListingId}?userEmail=${encodeURIComponent(testEmail)}`, {
            method: 'DELETE'
        });
        
        const deleteResult = await deleteResponse.json();
        console.log('Delete response:', deleteResponse.status, deleteResult);
        
        console.log('\n🎉 All favorites API tests complete!');
        
    } catch (error) {
        console.error('❌ API test error:', error);
    }
}

testFavoritesAPI();