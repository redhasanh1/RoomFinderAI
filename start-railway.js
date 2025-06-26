// Railway startup script with auto-config decryption
const fs = require('fs');
const path = require('path');

console.log('🚂 Railway deployment starting...');
console.log('Node version:', process.version);
console.log('Working directory:', __dirname);
console.log('Environment PORT:', process.env.PORT);

// List all files for debugging
console.log('📂 Available files:', fs.readdirSync(__dirname).sort());

// Auto-decrypt configuration
function decryptConfig() {
    const configPath = path.join(__dirname, 'config.js');
    const encryptedConfigPath = path.join(__dirname, 'config.js.encrypted');
    
    console.log('📁 Config paths:');
    console.log('  - config.js:', configPath);
    console.log('  - config.js.encrypted:', encryptedConfigPath);
    
    // Check if config.js already exists
    if (fs.existsSync(configPath)) {
        console.log('✅ config.js already exists');
        return true;
    }
    
    // Check if encrypted config exists
    if (!fs.existsSync(encryptedConfigPath)) {
        console.error('❌ config.js.encrypted not found');
        return false;
    }
    
    try {
        console.log('🔓 Decrypting configuration...');
        
        const password = process.env.CONFIG_PASSWORD || 'nibsaregood';
        const encryptedData = fs.readFileSync(encryptedConfigPath);
        console.log(`📦 Encrypted data size: ${encryptedData.length} bytes`);
        
        // XOR decryption
        const decryptedData = Buffer.alloc(encryptedData.length);
        for (let i = 0; i < encryptedData.length; i++) {
            decryptedData[i] = encryptedData[i] ^ password.charCodeAt(i % password.length);
        }
        
        fs.writeFileSync(configPath, decryptedData);
        console.log('✅ Configuration decrypted successfully');
        return true;
        
    } catch (error) {
        console.error('❌ Decryption error:', error.message);
        return false;
    }
}

// Check backend directory
const backendPath = path.join(__dirname, 'backend');
console.log('🔍 Backend directory exists:', fs.existsSync(backendPath));
if (fs.existsSync(backendPath)) {
    console.log('📂 Backend files:', fs.readdirSync(backendPath));
}

// Decrypt config
console.log('🔄 Starting configuration...');
if (!decryptConfig()) {
    console.error('❌ Configuration failed, but continuing...');
}

// Start server
console.log('🚀 Starting server...');
try {
    const serverPath = path.join(__dirname, 'backend', 'server.js');
    console.log('📄 Server path:', serverPath);
    console.log('📄 Server exists:', fs.existsSync(serverPath));
    
    require('./backend/server.js');
    console.log('✅ Server started successfully');
} catch (error) {
    console.error('❌ Server startup failed:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
}