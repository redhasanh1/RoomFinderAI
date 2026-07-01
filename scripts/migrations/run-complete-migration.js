const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const supabaseUrl = 'https://fkktwhjybuflxqzopaex.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQ5ODk3NCwiZXhwIjoyMDYzMDc0OTc0fQ.fvQAO_ZBC1QM9hVCedQ5UEoXmqlXTub12jCF5vfRq78';

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function runCompleteMigration() {
    try {
        console.log('🔄 Starting complete user migration...');
        
        // Step 1: Check current state
        const { data: profiles, error: profileError } = await supabase
            .from('profiles')
            .select('email')
            .not('email', 'is', null);
            
        const { data: users, error: userError } = await supabase
            .from('users')  
            .select('email');
            
        if (profileError) throw profileError;
        if (userError) throw userError;
        
        console.log(`📊 Found ${profiles.length} profiles and ${users.length} users`);
        
        // Step 2: Add missing columns to users table
        console.log('📝 Adding missing columns to users table...');
        const alterTableQuery = `
            ALTER TABLE users 
            ADD COLUMN IF NOT EXISTS city VARCHAR(100),
            ADD COLUMN IF NOT EXISTS postalcode VARCHAR(20),
            ADD COLUMN IF NOT EXISTS street VARCHAR(200),
            ADD COLUMN IF NOT EXISTS bio TEXT,
            ADD COLUMN IF NOT EXISTS profile_image TEXT,
            ADD COLUMN IF NOT EXISTS profile_image_url TEXT,
            ADD COLUMN IF NOT EXISTS has_custom_profile_image BOOLEAN DEFAULT FALSE,
            ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
            ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
            
            ALTER TABLE users ALTER COLUMN first_name DROP NOT NULL;
            ALTER TABLE users ALTER COLUMN last_name DROP NOT NULL;
        `;
        
        const { error: alterError } = await supabase.rpc('exec_sql', { sql: alterTableQuery });
        if (alterError && !alterError.message.includes('already exists')) {
            console.log('⚠️  Column addition error (might be expected):', alterError.message);
        }
        
        // Step 3: Get profiles that need to become users
        const { data: profilesToMigrate, error: profilesError } = await supabase
            .from('profiles')
            .select('*')
            .not('email', 'is', null);
            
        if (profilesError) throw profilesError;
        
        console.log(`🔄 Migrating ${profilesToMigrate.length} profiles to users...`);
        
        // Step 4: Migrate each profile individually
        let successCount = 0;
        let skipCount = 0;
        
        for (const profile of profilesToMigrate) {
            try {
                // Check if user already exists
                const { data: existingUser } = await supabase
                    .from('users')
                    .select('id')
                    .eq('email', profile.email)
                    .single();
                    
                if (existingUser) {
                    // Update existing user
                    const { error: updateError } = await supabase
                        .from('users')
                        .update({
                            first_name: profile.first_name || profile.email.split('@')[0],
                            last_name: profile.last_name || '',
                            city: profile.city,
                            postalcode: profile.postalcode,
                            street: profile.street,
                            bio: profile.bio,
                            profile_image: profile.profile_image,
                            profile_image_url: profile.profile_image_url,
                            has_custom_profile_image: !!(profile.profile_image_url || (profile.profile_image && profile.profile_image !== 'https://via.placeholder.com/40')),
                            phone: profile.phone,
                            updated_at: new Date().toISOString()
                        })
                        .eq('email', profile.email);
                        
                    if (updateError) {
                        console.log(`⚠️  Failed to update user ${profile.email}:`, updateError.message);
                        skipCount++;
                    } else {
                        successCount++;
                    }
                } else {
                    // Create new user
                    const { error: insertError } = await supabase
                        .from('users')
                        .insert({
                            id: profile.id || crypto.randomUUID(),
                            email: profile.email,
                            first_name: profile.first_name || profile.email.split('@')[0],
                            last_name: profile.last_name || '',
                            city: profile.city,
                            postalcode: profile.postalcode,
                            street: profile.street,
                            bio: profile.bio,
                            profile_image: profile.profile_image,
                            profile_image_url: profile.profile_image_url,
                            has_custom_profile_image: !!(profile.profile_image_url || (profile.profile_image && profile.profile_image !== 'https://via.placeholder.com/40')),
                            phone: profile.phone,
                            created_at: profile.created_at || new Date().toISOString(),
                            updated_at: new Date().toISOString(),
                            is_verified: false
                        });
                        
                    if (insertError) {
                        console.log(`⚠️  Failed to create user ${profile.email}:`, insertError.message);
                        skipCount++;
                    } else {
                        successCount++;
                    }
                }
            } catch (error) {
                console.log(`❌ Error processing ${profile.email}:`, error.message);
                skipCount++;
            }
        }
        
        console.log(`✅ Migration complete: ${successCount} users processed, ${skipCount} skipped`);
        
        // Step 5: Update foreign key references
        console.log('🔗 Updating listings to reference users...');
        
        const { data: listings, error: listingsError } = await supabase
            .from('listings')
            .select('id, user_email');
            
        if (listingsError) throw listingsError;
        
        let listingsUpdated = 0;
        for (const listing of listings) {
            if (listing.user_email) {
                const { data: user } = await supabase
                    .from('users')
                    .select('id')
                    .eq('email', listing.user_email)
                    .single();
                    
                if (user) {
                    const { error: updateError } = await supabase
                        .from('listings')
                        .update({ user_id: user.id })
                        .eq('id', listing.id);
                        
                    if (!updateError) listingsUpdated++;
                }
            }
        }
        
        console.log(`✅ Updated ${listingsUpdated} listings with user IDs`);
        
        // Step 6: Update messages
        console.log('💬 Updating messages to reference users...');
        
        const { data: messages, error: messagesError } = await supabase
            .from('messages')
            .select('id, sender_email');
            
        if (messagesError) throw messagesError;
        
        let messagesUpdated = 0;
        for (const message of messages) {
            if (message.sender_email) {
                const { data: user } = await supabase
                    .from('users')
                    .select('id')
                    .eq('email', message.sender_email)
                    .single();
                    
                if (user) {
                    const { error: updateError } = await supabase
                        .from('messages')
                        .update({ user_id: user.id })
                        .eq('id', message.id);
                        
                    if (!updateError) messagesUpdated++;
                }
            }
        }
        
        console.log(`✅ Updated ${messagesUpdated} messages with user IDs`);
        
        // Final verification
        const { data: finalUsers, error: finalUserError } = await supabase
            .from('users')
            .select('email');
            
        const { data: connectedListings, error: connectedError } = await supabase
            .from('listings')
            .select('id')
            .not('user_id', 'is', null);
            
        if (finalUserError) throw finalUserError;
        if (connectedError) throw connectedError;
        
        console.log('\n🎉 MIGRATION COMPLETE!');
        console.log(`📊 Total users: ${finalUsers.length}`);
        console.log(`🏠 Listings connected to users: ${connectedListings.length}`);
        console.log('✅ All website functions should now save properly to the database!');
        
    } catch (error) {
        console.error('❌ Migration failed:', error);
    }
}

runCompleteMigration();