const axios = require('axios');

async function testRegistration() {
    try {
        console.log('🧪 Testing registration endpoint...');
        
        const response = await axios.post('http://localhost:3000/api/send-verification', {
            firstName: 'Test',
            lastName: 'User',
            email: 'test@example.com',
            password: 'testpassword123'
        }, {
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        console.log('✅ Success:', response.data);
    } catch (error) {
        if (error.response) {
            console.log('❌ API Error:', error.response.status, error.response.data);
        } else {
            console.log('❌ Network Error:', error.message);
        }
    }
}

testRegistration();