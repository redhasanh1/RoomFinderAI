#!/usr/bin/env node

// Test script to validate OpenAI API connectivity
const config = require('./config.js');

async function testOpenAIAPI() {
    console.log('🧪 Testing OpenAI API Connectivity...\n');
    
    // Check if API key is configured
    if (!config.OPENAI_API_KEY) {
        console.error('❌ OPENAI_API_KEY not found in environment variables');
        console.error('Please set the OPENAI_API_KEY environment variable');
        process.exit(1);
    }
    
    console.log('🔑 API Key found:', config.OPENAI_API_KEY.substring(0, 10) + '...');
    console.log('🏢 Organization ID:', config.OPENAI_ORG_ID || 'Not set');
    console.log('🤖 Model:', config.OPENAI_MODEL || 'gpt-3.5-turbo');
    console.log();
    
    try {
        console.log('📡 Making test request to OpenAI API...');
        
        const response = await fetch('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${config.OPENAI_API_KEY}`,
                'OpenAI-Organization': config.OPENAI_ORG_ID
            },
            body: JSON.stringify({
                model: config.OPENAI_MODEL || 'gpt-3.5-turbo',
                messages: [
                    {
                        role: 'user',
                        content: 'Reply with just "API connection test successful"'
                    }
                ],
                max_tokens: 20,
                temperature: 0
            })
        });
        
        if (response.ok) {
            const data = await response.json();
            const content = data.choices[0]?.message?.content;
            console.log('✅ OpenAI API connection successful!');
            console.log('📄 Response:', content);
            console.log('💰 Usage:', data.usage);
        } else {
            const errorText = await response.text();
            console.error('❌ OpenAI API Error:');
            console.error('Status:', response.status, response.statusText);
            console.error('Error:', errorText);
            
            if (response.status === 401) {
                console.error('\n🔍 Troubleshooting 401 Authentication Error:');
                console.error('1. Check if your API key is valid and active');
                console.error('2. Ensure the API key has the correct permissions');
                console.error('3. If using organization ID, verify it\'s correct');
                console.error('4. Check if your OpenAI account has sufficient credits');
            }
        }
        
    } catch (error) {
        console.error('❌ Network error:', error.message);
        console.error('This could indicate connectivity issues or invalid API endpoint');
    }
}

// Run the test
testOpenAIAPI();