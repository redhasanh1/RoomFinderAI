const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://fkktwhjybuflxqzopaex.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQ5ODk3NCwiZXhwIjoyMDYzMDc0OTc0fQ.fvQAO_ZBC1QM9hVCedQ5UEoXmqlXTub12jCF5vfRq78';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkFavorites() {
    try {
        console.log('🔍 Checking favorites table and data...');
        
        // Check if user_favorites table exists and has data
        const { data: favorites, error: favError } = await supabase
            .from('user_favorites')
            .select('*')
            .limit(5);
            
        if (favError) {
            console.log('❌ user_favorites table error:', favError.message);
            
            // Check if favorites table exists instead
            const { data: altFavorites, error: altError } = await supabase
                .from('favorites')
                .select('*')
                .limit(5);
                
            if (altError) {
                console.log('❌ favorites table error:', altError.message);
                console.log('📋 No favorites table found - needs to be created');
            } else {
                console.log('✅ Found favorites table with', altFavorites?.length || 0, 'sample records');
                console.log('📄 Sample favorites:', altFavorites?.[0]);
            }
        } else {
            console.log('✅ Found user_favorites table with', favorites?.length || 0, 'records');
            console.log('📄 Sample favorite:', favorites?.[0]);
        }
        
        // Check what listings exist
        const { data: listings } = await supabase
            .from('listings')
            .select('id, title, user_email')
            .limit(3);
            
        console.log('\n🏠 Sample listings for testing favorites:');
        listings?.forEach((listing, i) => {
            console.log(`${i + 1}. ${listing.title} (${listing.id}) - ${listing.user_email}`);
        });
        
        // Check what profiles exist for testing
        const { data: profiles } = await supabase
            .from('profiles')
            .select('email, first_name')
            .limit(3);
            
        console.log('\n👥 Sample profiles for testing:');
        profiles?.forEach((profile, i) => {
            console.log(`${i + 1}. ${profile.first_name} (${profile.email})`);
        });
        
    } catch (error) {
        console.error('❌ Error:', error);
    }
}

checkFavorites();