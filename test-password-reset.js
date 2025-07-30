#!/usr/bin/env node

// Test script for password reset functionality
const axios = require('axios');

const SERVER_URL = process.env.SERVER_URL || 'http://localhost:3000';
const TEST_EMAIL = process.env.TEST_EMAIL || 'test@example.com';

async function testPasswordReset() {
    console.log('🧪 Testing Password Reset Flow');
    console.log('================================');
    console.log('Server URL:', SERVER_URL);
    console.log('Test Email:', TEST_EMAIL);
    console.log('');

    try {
        // Test 1: Send reset code
        console.log('📧 Test 1: Sending password reset code...');
        const resetResponse = await axios.post(`${SERVER_URL}/api/send-reset-code`, {
            email: TEST_EMAIL
        });

        if (resetResponse.status === 200) {
            console.log('✅ Reset code sent successfully!');
            console.log('Response:', resetResponse.data);
        } else {
            console.log('❌ Failed to send reset code');
            console.log('Status:', resetResponse.status);
            console.log('Response:', resetResponse.data);
        }

        // Test 2: Test email endpoint
        console.log('\n📧 Test 2: Testing email functionality directly...');
        const testEmailResponse = await axios.post(`${SERVER_URL}/api/test-email`, {
            email: TEST_EMAIL
        });

        if (testEmailResponse.status === 200) {
            console.log('✅ Test email sent successfully!');
            console.log('Response:', testEmailResponse.data);
        } else {
            console.log('❌ Failed to send test email');
            console.log('Status:', testEmailResponse.status);
            console.log('Response:', testEmailResponse.data);
        }

    } catch (error) {
        console.error('❌ Error during testing:');
        if (error.response) {
            console.error('Status:', error.response.status);
            console.error('Data:', error.response.data);
        } else {
            console.error('Message:', error.message);
        }
    }
}

// Run the test
testPasswordReset();