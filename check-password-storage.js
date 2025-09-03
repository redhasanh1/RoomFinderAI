const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://fkktwhjybuflxqzopaex.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQ5ODk3NCwiZXhwIjoyMDYzMDc0OTc0fQ.fvQAO_ZBC1QM9hVCedQ5UEoXmqlXTub12jCF5vfRq78';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkPasswordStorage() {
    try {
        console.log('🔍 Checking password storage in Supabase...');
        
        // Check profiles table for password field
        const { data: profiles, error: profileError } = await supabase
            .from('profiles')
            .select('email, password')
            .limit(3);
            
        if (profileError) {
            console.log('❌ Profiles table error:', profileError.message);
        } else {
            console.log('📋 Profiles table password field check:');
            profiles?.forEach(profile => {
                if (profile.password) {
                    console.log(`  ${profile.email}: HAS PASSWORD (${profile.password.substring(0, 20)}...)`);
                } else {
                    console.log(`  ${profile.email}: NO PASSWORD`);
                }
            });
        }
        
        // Check users table for password field  
        const { data: users, error: userError } = await supabase
            .from('users')
            .select('email, password')
            .limit(3);
            
        if (userError) {
            console.log('❌ Users table error:', userError.message);
        } else {
            console.log('\n📋 Users table password field check:');
            users?.forEach(user => {
                if (user.password) {
                    console.log(`  ${user.email}: HAS PASSWORD (${user.password.substring(0, 20)}...)`);
                } else {
                    console.log(`  ${user.email}: NO PASSWORD`);
                }
            });
        }
        
        // Check auth.users (Supabase's built-in auth table)
        console.log('\n🔐 Checking Supabase Auth table...');
        try {
            const { data: authUsers, error: authError } = await supabase.auth.admin.listUsers();
            
            if (authError) {
                console.log('❌ Auth users error:', authError.message);
            } else {
                console.log(`📊 Found ${authUsers?.users?.length || 0} users in Supabase Auth:`);
                authUsers?.users?.slice(0, 3).forEach(user => {
                    console.log(`  ${user.email}: ID ${user.id} (created: ${user.created_at})`);
                });
            }
        } catch (authErr) {
            console.log('❌ Cannot access auth.users:', authErr.message);
        }
        
        console.log('\n💡 EXPLANATION:');
        console.log('🔒 Supabase stores passwords securely in the built-in auth.users table');
        console.log('📋 Your profiles table should NOT store passwords (security risk)');
        console.log('🔄 Authentication flow: Supabase Auth → Get profile data from profiles table');
        
    } catch (error) {
        console.error('❌ Error:', error);
    }
}

checkPasswordStorage();