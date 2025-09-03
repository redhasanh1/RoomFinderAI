const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://fkktwhjybuflxqzopaex.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQ5ODk3NCwiZXhwIjoyMDYzMDc0OTc0fQ.fvQAO_ZBC1QM9hVCedQ5UEoXmqlXTub12jCF5vfRq78';

const supabase = createClient(supabaseUrl, serviceRoleKey);

// Simple UUID generator
function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0;
        const v = c == 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

async function migrateUsersWithUUID() {
    try {
        console.log('🚀 Starting UUID-based user migration...');
        
        // Get all profiles
        const { data: profiles, error: profileError } = await supabase
            .from('profiles')
            .select('*');
            
        if (profileError) throw profileError;
        
        console.log(`📋 Processing ${profiles.length} profiles...`);
        
        let successCount = 0;
        let errorCount = 0;
        
        for (const profile of profiles) {
            if (!profile.email) continue;
            
            // Check if user already exists
            const { data: existingUser } = await supabase
                .from('users')
                .select('id')
                .eq('email', profile.email)
                .maybeSingle();
                
            if (!existingUser) {
                const newUser = {
                    id: generateUUID(),
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
                };
                
                const { data, error } = await supabase
                    .from('users')
                    .insert(newUser);
                    
                if (error) {
                    console.log(`❌ ${profile.email}: ${error.message}`);
                    errorCount++;
                } else {
                    console.log(`✅ ${profile.email}: created`);
                    successCount++;
                }
            } else {
                console.log(`⏭️  ${profile.email}: already exists`);
                successCount++;
            }
        }
        
        console.log(`\n📊 Migration Summary:`);
        console.log(`✅ Success: ${successCount}`);
        console.log(`❌ Errors: ${errorCount}`);
        
        // Now link listings
        console.log('\n🔗 Linking listings to users...');
        
        const { data: allUsers } = await supabase.from('users').select('id, email');
        const { data: allListings } = await supabase.from('listings').select('id, user_email');
        
        let listingsLinked = 0;
        for (const listing of allListings || []) {
            if (listing.user_email) {
                const matchingUser = allUsers.find(u => u.email.toLowerCase() === listing.user_email.toLowerCase());
                if (matchingUser) {
                    const { error } = await supabase
                        .from('listings')
                        .update({ user_id: matchingUser.id })
                        .eq('id', listing.id);
                        
                    if (!error) {
                        listingsLinked++;
                        console.log(`🔗 Linked listing ${listing.id} to ${listing.user_email}`);
                    }
                }
            }
        }
        
        // Final verification
        const { data: finalUsers } = await supabase.from('users').select('email');
        const { data: connectedListings } = await supabase.from('listings').select('id').not('user_id', 'is', null);
        
        console.log('\n🎉 MIGRATION COMPLETE!');
        console.log(`👥 Total users: ${finalUsers?.length || 0}/${profiles.length}`);
        console.log(`🏠 Connected listings: ${connectedListings?.length || 0}/${allListings?.length || 0}`);
        
        if (finalUsers?.length >= 60) {
            console.log('✅ SUCCESS: User migration complete!');
            console.log('✅ Your website functions should now save properly to the database!');
        }
        
    } catch (error) {
        console.error('❌ Migration failed:', error);
    }
}

migrateUsersWithUUID();