// Test the kimfiedlschuster1999@gmail.com registration
const fetch = require('node-fetch');

async function testRegistration() {
    try {
        console.log('🧪 Testing registration for kimfiedlschuster1999@gmail.com');
        
        // First check if server is running
        const healthCheck = await fetch('http://localhost:3000/health');
        if (!healthCheck.ok) {
            console.log('❌ Server not running. Please start: node backend/server.js');
            return;
        }
        
        // Try to send verification code (first step of registration)
        const response = await fetch('http://localhost:3000/api/send-verification-code', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email: 'kimfiedlschuster1999@gmail.com',
                firstName: 'Kim',
                lastName: 'Schuster',
                password: 'TestPass123'
            })
        });
        
        const result = await response.text();
        console.log('Response:', response.status, result);
        
        if (response.status === 400 && result.includes('already')) {
            console.log('❌ Email still marked as "already used" - localStorage issue confirmed');
        } else {
            console.log('✅ Registration should work now');
        }
        
    } catch (error) {
        console.error('❌ Test error:', error.message);
    }
}

testRegistration();