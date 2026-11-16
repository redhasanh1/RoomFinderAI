const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!supabaseUrl || !serviceRoleKey) {
  console.error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the environment before running this script.');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkDeletedEmail() {
    try {
        const targetEmail = 'kimfiedlschuster1999@gmail.com';
        console.log(`🔍 Checking if ${targetEmail} is completely deleted...`);
        
        // Check Supabase Auth
        const { data: authUsers, error: authError } = await supabase.auth.admin.listUsers();
        if (authError) {
            console.log('❌ Error checking auth:', authError.message);
        } else {
            const authUser = authUsers.users?.find(u => u.email === targetEmail);
            if (authUser) {
                console.log(`❌ Still found in Supabase Auth: ${authUser.id}`);
                console.log(`   Status: ${authUser.email_confirmed_at ? 'confirmed' : 'unconfirmed'}`);
                
                // Try to delete it
                console.log('🗑️ Attempting to delete from Auth...');
                const { error: deleteError } = await supabase.auth.admin.deleteUser(authUser.id);
                if (deleteError) {
                    console.log('❌ Delete failed:', deleteError.message);
                } else {
                    console.log('✅ Deleted from Auth');
                }
            } else {
                console.log('✅ NOT found in Supabase Auth');
            }
        }
        
        // Check profiles table
        const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('*')
            .eq('email', targetEmail)
            .maybeSingle();
            
        if (profileError) {
            console.log('❌ Error checking profiles:', profileError.message);
        } else if (profile) {
            console.log(`❌ Still found in profiles table: ${profile.id}`);
            
            // Delete from profiles
            console.log('🗑️ Deleting from profiles table...');
            const { error: delProfileError } = await supabase
                .from('profiles')
                .delete()
                .eq('email', targetEmail);
                
            if (delProfileError) {
                console.log('❌ Profile delete failed:', delProfileError.message);
            } else {
                console.log('✅ Deleted from profiles');
            }
        } else {
            console.log('✅ NOT found in profiles table');
        }
        
        console.log(`\n🎯 ${targetEmail} should now be completely clear for registration`);
        
    } catch (error) {
        console.error('❌ Error:', error);
    }
}

checkDeletedEmail();