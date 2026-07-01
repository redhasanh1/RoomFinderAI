const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://fkktwhjybuflxqzopaex.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQ5ODk3NCwiZXhwIjoyMDYzMDc0OTc0fQ.fvQAO_ZBC1QM9hVCedQ5UEoXmqlXTub12jCF5vfRq78';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function fixForeignKeyIssue() {
    try {
        console.log('🔍 Checking foreign key constraints on users table...');
        
        // Check what foreign key constraints exist
        const constraintQuery = `
            SELECT 
                tc.constraint_name, 
                tc.table_name, 
                kcu.column_name, 
                ccu.table_name AS foreign_table_name,
                ccu.column_name AS foreign_column_name 
            FROM 
                information_schema.table_constraints AS tc 
                JOIN information_schema.key_column_usage AS kcu
                    ON tc.constraint_name = kcu.constraint_name
                    AND tc.table_schema = kcu.table_schema
                JOIN information_schema.constraint_column_usage AS ccu
                    ON ccu.constraint_name = tc.constraint_name
                    AND ccu.table_schema = tc.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY' 
                AND tc.table_name='users';
        `;
        
        const { data: constraints, error: constraintError } = await supabase.rpc('exec_sql', { sql: constraintQuery });
        if (constraintError) {
            // Try direct query instead
            const { data, error } = await supabase
                .from('information_schema.table_constraints')
                .select('*')
                .eq('table_name', 'users')
                .eq('constraint_type', 'FOREIGN KEY');
            console.log('Constraints check result:', data, error);
        }
        
        console.log('🔧 Dropping problematic foreign key constraint...');
        
        // Drop the users_id_fkey constraint that's causing issues
        const dropConstraintQuery = `
            ALTER TABLE users DROP CONSTRAINT IF EXISTS users_id_fkey;
            ALTER TABLE users DROP CONSTRAINT IF EXISTS users_auth_id_fkey;
        `;
        
        const { error: dropError } = await supabase.rpc('exec_sql', { sql: dropConstraintQuery });
        if (dropError) {
            console.log('⚠️  Could not drop constraint via RPC, trying alternative approach...');
            
            // Try direct table operations
            const profiles = await supabase.from('profiles').select('*');
            console.log(`Found ${profiles.data?.length || 0} profiles to migrate`);
            
            // Manual insertion without foreign key issues
            for (const profile of profiles.data || []) {
                if (!profile.email) continue;
                
                // Check if user exists first
                const { data: existingUser } = await supabase
                    .from('users')
                    .select('id')
                    .eq('email', profile.email)
                    .maybeSingle();
                    
                if (!existingUser) {
                    // Generate new UUID for user
                    const newUserId = crypto.randomUUID();
                    
                    const { error: insertError } = await supabase
                        .from('users')
                        .insert({
                            id: newUserId,
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
                        
                    if (insertError) {
                        console.log(`❌ Failed to create user ${profile.email}:`, insertError.message);
                    } else {
                        console.log(`✅ Created user: ${profile.email}`);
                    }
                }
            }
        }
        
        // Final check
        const { data: finalUsers } = await supabase.from('users').select('email');
        console.log(`🎉 Final result: ${finalUsers?.length || 0} users in database`);
        
    } catch (error) {
        console.error('❌ Error:', error);
    }
}

fixForeignKeyIssue();