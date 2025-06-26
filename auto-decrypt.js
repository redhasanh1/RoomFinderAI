// Auto-decrypt config.js from encrypted file for Railway deployment
const fs = require('fs');
const path = require('path');

function autoDecryptConfig() {
    const configPath = path.join(__dirname, 'config.js');
    const encryptedConfigPath = path.join(__dirname, 'config.js.encrypted');
    
    // Check if config.js already exists (local development)
    if (fs.existsSync(configPath)) {
        console.log('✅ config.js found, using existing configuration');
        return;
    }
    
    // Check if encrypted config exists
    if (!fs.existsSync(encryptedConfigPath)) {
        console.error('❌ Neither config.js nor config.js.encrypted found');
        process.exit(1);
    }
    
    try {
        console.log('🔓 Decrypting config.js.encrypted for Railway deployment...');
        
        // Simple XOR decryption (matching your encrypt_config.py)
        const password = process.env.CONFIG_PASSWORD || 'nibsaregood';
        const encryptedData = fs.readFileSync(encryptedConfigPath);
        
        // XOR decrypt
        const decryptedData = Buffer.alloc(encryptedData.length);
        for (let i = 0; i < encryptedData.length; i++) {
            decryptedData[i] = encryptedData[i] ^ password.charCodeAt(i % password.length);
        }
        
        // Write decrypted config
        fs.writeFileSync(configPath, decryptedData);
        console.log('✅ config.js decrypted successfully');
        
    } catch (error) {
        console.error('❌ Failed to decrypt config.js:', error.message);
        process.exit(1);
    }
}

module.exports = autoDecryptConfig;