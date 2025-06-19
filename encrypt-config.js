const crypto = require('crypto');
const fs = require('fs');

const password = 'nibsaregood';
const algorithm = 'aes-256-cbc';

function encrypt(text) {
    const key = crypto.scryptSync(password, 'salt', 32);
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipher(algorithm, key);
    let encrypted = cipher.update(text, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    return iv.toString('hex') + ':' + encrypted;
}

function decrypt(encryptedData) {
    const key = crypto.scryptSync(password, 'salt', 32);
    const [ivHex, encrypted] = encryptedData.split(':');
    const iv = Buffer.from(ivHex, 'hex');
    const decipher = crypto.createDecipher(algorithm, key);
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
}

// Read and encrypt config.js
const configContent = fs.readFileSync('/app/config.js', 'utf8');
const encryptedConfig = encrypt(configContent);
fs.writeFileSync('/app/config.js.encrypted', encryptedConfig);

// Read and encrypt config.mjs
const configMjsContent = fs.readFileSync('/app/config.mjs', 'utf8');
const encryptedConfigMjs = encrypt(configMjsContent);
fs.writeFileSync('/app/config.mjs.encrypted', encryptedConfigMjs);

console.log('Config files encrypted successfully!');
console.log('Password: nibsaregood');
console.log('Files created: config.js.encrypted, config.mjs.encrypted');

// Export decrypt function for use in other files
module.exports = { decrypt };