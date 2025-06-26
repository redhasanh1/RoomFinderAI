// Simple Railway-compatible server
const express = require('express');
const cors = require('cors');

const app = express();
const port = process.env.PORT || 3000;

console.log('🚀 Starting Railway server...');

// Basic middleware
app.use(cors());
app.use(express.json());
app.use(express.static('.'));

// Health check endpoint
app.get('/', (req, res) => {
    res.json({ 
        status: 'Server running successfully',
        timestamp: new Date().toISOString(),
        port: port
    });
});

// Test endpoint
app.get('/api/test', (req, res) => {
    res.json({ message: 'API is working' });
});

// Start server
app.listen(port, () => {
    console.log(`✅ Railway server running on port ${port}`);
    console.log(`🌐 Server accessible at: http://localhost:${port}`);
});