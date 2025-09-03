const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://fkktwhjybuflxqzopaex.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQ5ODk3NCwiZXhwIjoyMDYzMDc0OTc0fQ.fvQAO_ZBC1QM9hVCedQ5UEoXmqlXTub12jCF5vfRq78';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function testFavorites() {
    try {
        console.log('🔍 Testing favorites functionality...');
        
        // Get a sample listing and profile to test with
        const { data: listings } = await supabase.from('listings').select('id, title').limit(1);
        const { data: profiles } = await supabase.from('profiles').select('email').limit(1);
        
        if (!listings?.length || !profiles?.length) {
            console.log('❌ No test data available');
            return;
        }
        
        const testListing = listings[0];
        const testUser = profiles[0];
        
        console.log(`📄 Testing with listing: ${testListing.title} (${testListing.id})`);
        console.log(`👤 Testing with user: ${testUser.email}`);
        
        // Test 1: Add to favorites
        console.log('\n➕ Testing add to favorites...');
        const { data: addData, error: addError } = await supabase
            .from('favorites')
            .insert({
                user_email: testUser.email,
                listing_id: testListing.id,
                created_at: new Date().toISOString()
            })
            .select();
            
        if (addError) {
            console.log('❌ Add failed:', addError.message);
        } else {
            console.log('✅ Added to favorites successfully:', addData[0]);
        }
        
        // Test 2: Check if exists
        console.log('\n🔍 Testing favorites check...');
        const { data: checkData, error: checkError } = await supabase
            .from('favorites')
            .select('*')
            .eq('user_email', testUser.email)
            .eq('listing_id', testListing.id);
            
        if (checkError) {
            console.log('❌ Check failed:', checkError.message);
        } else {
            console.log('✅ Favorite found:', checkData?.length > 0 ? 'YES' : 'NO');
        }
        
        // Test 3: Get all user favorites
        console.log('\n📋 Testing get all favorites...');
        const { data: allFavorites, error: getAllError } = await supabase
            .from('favorites')
            .select(`
                *,
                listings (
                    id, title, price, location, bedrooms, bathrooms
                )
            `)
            .eq('user_email', testUser.email);
            
        if (getAllError) {
            console.log('❌ Get all failed:', getAllError.message);
        } else {
            console.log(`✅ Found ${allFavorites?.length || 0} total favorites for user`);
            if (allFavorites?.length > 0) {
                console.log('📄 Sample favorite with listing:', allFavorites[0]);
            }
        }
        
        // Test 4: Remove from favorites
        console.log('\n➖ Testing remove from favorites...');
        const { data: removeData, error: removeError } = await supabase
            .from('favorites')
            .delete()
            .eq('user_email', testUser.email)
            .eq('listing_id', testListing.id)
            .select();
            
        if (removeError) {
            console.log('❌ Remove failed:', removeError.message);
        } else {
            console.log('✅ Removed from favorites successfully');
        }
        
        console.log('\n🎉 Favorites testing complete!');
        
    } catch (error) {
        console.error('❌ Test error:', error);
    }
}

testFavorites();