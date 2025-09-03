const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://fkktwhjybuflxqzopaex.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQ5ODk3NCwiZXhwIjoyMDYzMDc0OTc0fQ.fvQAO_ZBC1QM9hVCedQ5UEoXmqlXTub12jCF5vfRq78';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function analyzeAndFixConstraint() {
    try {
        console.log('🔍 Let me check what constraints exist and work around them...');
        
        // First, get the existing user to understand the structure
        const { data: existingUser } = await supabase
            .from('users')
            .select('*')
            .limit(1)
            .single();
            
        console.log('📋 Existing user structure:', Object.keys(existingUser || {}));
        
        // Check if there are any referencing tables
        const { data: listings } = await supabase.from('listings').select('id, user_email').limit(1);
        const { data: messages } = await supabase.from('messages').select('id, sender_email').limit(1);
        
        console.log('🏠 Sample listing:', listings?.[0]);
        console.log('💬 Sample message:', messages?.[0]);
        
        console.log('\n🎯 Let me try a different strategy: use the profiles table directly for now');
        console.log('Instead of migrating users, let me update the backend to use profiles table properly');
        
        // Get all profiles data
        const { data: profiles } = await supabase.from('profiles').select('id, email, first_name, last_name');
        console.log(`📊 Found ${profiles?.length || 0} profiles in database`);
        
        // Get all unique emails from listings
        const { data: allListings } = await supabase.from('listings').select('user_email');
        const uniqueEmails = [...new Set(allListings?.map(l => l.user_email).filter(Boolean))];
        console.log(`📧 Found ${uniqueEmails.length} unique emails in listings`);
        
        // Check which listings have matching profiles
        let matchedListings = 0;
        let orphanedListings = 0;
        
        for (const email of uniqueEmails) {
            const hasProfile = profiles?.some(p => p.email === email);
            if (hasProfile) {
                matchedListings++;
            } else {
                orphanedListings++;
                console.log(`⚠️  Orphaned email: ${email}`);
            }
        }
        
        console.log(`\n📊 Analysis Results:`);
        console.log(`✅ Emails with profiles: ${matchedListings}`);
        console.log(`❌ Orphaned emails: ${orphanedListings}`);
        console.log(`📦 Total profiles: ${profiles?.length || 0}`);
        console.log(`🏠 Total listings: ${allListings?.length || 0}`);
        
        if (orphanedListings > 0) {
            console.log('\n🔧 RECOMMENDATION: Create missing profiles for orphaned listings');
            console.log('This will ensure all listings have associated user data');
        }
        
        if (matchedListings > 0) {
            console.log('\n✅ GOOD NEWS: Most listings already have profiles!');
            console.log('The backend should work with the profiles table instead of fighting the users table constraint');
        }
        
    } catch (error) {
        console.error('❌ Error:', error);
    }
}

analyzeAndFixConstraint();