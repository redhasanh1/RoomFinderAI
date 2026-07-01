const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://fkktwhjybuflxqzopaex.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQ5ODk3NCwiZXhwIjoyMDYzMDc0OTc0fQ.fvQAO_ZBC1QM9hVCedQ5UEoXmqlXTub12jCF5vfRq78';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function migrateUsers() {
    try {
        console.log('🚀 Starting final user migration approach...');
        
        // Get all profiles
        const { data: profiles, error: profileError } = await supabase
            .from('profiles')
            .select('*');
            
        if (profileError) throw profileError;
        
        console.log(`📋 Found ${profiles.length} profiles to process`);
        
        // Since the users table has a foreign key constraint that's blocking us,
        // let's use a different approach: bulk upsert using merge conflict resolution
        
        const usersToInsert = [];
        
        for (const profile of profiles) {
            if (!profile.email) continue;
            
            // Check if user already exists
            const { data: existingUser } = await supabase
                .from('users')
                .select('id, email')
                .eq('email', profile.email)
                .maybeSingle();
                
            if (!existingUser) {
                usersToInsert.push({
                    email: profile.email,
                    first_name: profile.first_name || profile.email.split('@')[0],
                    last_name: profile.last_name || '',
                    city: profile.city,
                    postalcode: profile.postalcode, 
                    street: profile.street,
                    bio: profile.bio,
                    profile_image_url: profile.profile_image_url,
                    phone: profile.phone,
                    created_at: profile.created_at || new Date().toISOString(),
                    is_verified: false
                });
            }
        }
        
        console.log(`📝 Attempting to create ${usersToInsert.length} new users...`);
        
        // Try batch insert first
        if (usersToInsert.length > 0) {
            const { data, error } = await supabase
                .from('users')
                .insert(usersToInsert);
                
            if (error) {
                console.log('❌ Batch insert failed:', error.message);
                console.log('🔄 Trying individual inserts...');
                
                // Try individual inserts
                let success = 0;
                for (const user of usersToInsert) {
                    const { error: singleError } = await supabase
                        .from('users')
                        .insert(user);
                        
                    if (singleError) {
                        console.log(`❌ ${user.email}: ${singleError.message}`);
                    } else {
                        console.log(`✅ ${user.email}: created successfully`);
                        success++;
                    }
                }
                console.log(`🎯 Successfully created ${success}/${usersToInsert.length} users`);
            } else {
                console.log(`✅ Successfully created all ${usersToInsert.length} users in batch!`);
            }
        }
        
        // Now update listings and messages
        console.log('🔗 Linking listings to users...');
        const { data: allUsers } = await supabase.from('users').select('id, email');
        const { data: allListings } = await supabase.from('listings').select('id, user_email');
        
        let listingsLinked = 0;
        for (const listing of allListings || []) {
            if (listing.user_email) {
                const matchingUser = allUsers.find(u => u.email === listing.user_email);
                if (matchingUser) {
                    const { error } = await supabase
                        .from('listings')
                        .update({ user_id: matchingUser.id })
                        .eq('id', listing.id);
                        
                    if (!error) listingsLinked++;
                }
            }
        }
        
        console.log(`✅ Linked ${listingsLinked} listings to users`);
        
        // Final status
        const { data: finalUsers } = await supabase.from('users').select('email');
        const { data: connectedListings } = await supabase.from('listings').select('id').not('user_id', 'is', null);
        
        console.log('\n🎉 FINAL RESULTS:');
        console.log(`👥 Total users: ${finalUsers?.length || 0}`);
        console.log(`🏠 Listings connected: ${connectedListings?.length || 0}/${allListings?.length || 0}`);
        
        if (finalUsers?.length === profiles.length) {
            console.log('✅ SUCCESS: All profiles migrated to users!');
        } else {
            console.log(`⚠️  PARTIAL: ${finalUsers?.length || 0}/${profiles.length} profiles migrated`);
        }
        
    } catch (error) {
        console.error('❌ Migration error:', error);
    }
}

migrateUsers();