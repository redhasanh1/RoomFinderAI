const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://fkktwhjybuflxqzopaex.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQ5ODk3NCwiZXhwIjoyMDYzMDc0OTc0fQ.fvQAO_ZBC1QM9hVCedQ5UEoXmqlXTub12jCF5vfRq78';

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