const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!supabaseUrl || !serviceRoleKey) {
  console.error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the environment before running this script.');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function testGetFavorites() {
    try {
        // First add a favorite to test with
        const { data: listings } = await supabase.from('listings').select('id, title').limit(1);
        const { data: profiles } = await supabase.from('profiles').select('email').limit(1);
        
        const testListing = listings[0];
        const testUser = profiles[0];
        
        // Add favorite
        await supabase
            .from('favorites')
            .insert({
                user_email: testUser.email,
                listing_id: testListing.id,
                created_at: new Date().toISOString()
            });
            
        console.log('✅ Added test favorite');
        
        // Now test the GET logic (simulating backend logic)
        console.log('🔍 Testing GET favorites logic...');
        
        const { data: favoritesData, error: favError } = await supabase
            .from('favorites')
            .select('*')
            .eq('user_email', testUser.email)
            .order('created_at', { ascending: false });

        if (favError) {
            console.log('❌ Error:', favError.message);
            return;
        }

        // Get listing details for each favorite
        const favorites = [];
        for (const favorite of favoritesData) {
            const { data: listing, error: listingError } = await supabase
                .from('listings')
                .select('*')
                .eq('id', favorite.listing_id)
                .single();
                
            if (!listingError && listing) {
                favorites.push({
                    ...listing,
                    favorited_at: favorite.created_at
                });
            }
        }
        
        console.log(`✅ GET favorites working: found ${favorites.length} favorites with full listing data`);
        console.log('📄 Sample favorite listing:', {
            title: favorites[0]?.title,
            price: favorites[0]?.price,
            favorited_at: favorites[0]?.favorited_at
        });
        
        // Cleanup
        await supabase
            .from('favorites')
            .delete()
            .eq('user_email', testUser.email);
            
        console.log('🧹 Cleaned up test data');
        
    } catch (error) {
        console.error('❌ Error:', error);
    }
}

testGetFavorites();