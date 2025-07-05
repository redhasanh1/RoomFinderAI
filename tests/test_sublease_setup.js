// Test script to set up sublease matching tables
// Run with: node test_sublease_setup.js

const { createClient } = require('@supabase/supabase-js');

// Load configuration
let config = {};
try {
    config = require('./config.js');
} catch (error) {
    console.log('⚠️ Config file not found, using environment variables');
    config = {
        SUPABASE_URL: process.env.SUPABASE_URL,
        SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY
    };
}

if (!config.SUPABASE_URL || !config.SUPABASE_ANON_KEY) {
    console.error('❌ SUPABASE_URL and SUPABASE_ANON_KEY are required');
    process.exit(1);
}

const supabase = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);

async function setupSubleaseDB() {
    console.log('🔧 Setting up sublease matching database...');
    
    try {
        // Test connection
        const { data: testData, error: testError } = await supabase
            .from('users')
            .select('count(*)')
            .limit(1);
            
        if (testError && !testError.message.includes('does not exist')) {
            console.error('❌ Database connection failed:', testError);
            return;
        }
        
        console.log('✅ Database connection successful');
        
        // Try to create a simple test request
        const testRequest = {
            user_email: 'test@example.com',
            type: 'transfer',
            title: 'Test Transfer Request',
            description: 'This is a test request',
            city: 'Test City',
            state: 'Test State',
            rent_amount: 1000,
            available_from: new Date().toISOString().split('T')[0],
            available_until: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
        };
        
        const { data, error } = await supabase
            .from('sublease_requests')
            .insert([testRequest])
            .select()
            .single();
            
        if (error) {
            console.error('❌ Table creation test failed:', error);
            console.log('');
            console.log('📋 Please run the setup SQL manually:');
            console.log('1. Go to your Supabase dashboard');
            console.log('2. Navigate to SQL Editor');
            console.log('3. Run the contents of setup_sublease_db.sql');
            console.log('');
        } else {
            console.log('✅ Sublease tables are working correctly');
            
            // Clean up test data
            await supabase
                .from('sublease_requests')
                .delete()
                .eq('id', data.id);
                
            console.log('✅ Test data cleaned up');
        }
        
    } catch (error) {
        console.error('❌ Setup failed:', error);
    }
}

setupSubleaseDB();