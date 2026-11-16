const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!supabaseUrl || !serviceRoleKey) {
  console.error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the environment before running this script.');
  process.exit(1);
}

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