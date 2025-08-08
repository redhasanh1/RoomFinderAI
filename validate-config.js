#!/usr/bin/env node

/**
 * Configuration Validator for RoomFinderAI
 * Checks environment variables and service connectivity without exposing sensitive data
 */

require('dotenv').config();
const axios = require('axios');
const { createClient } = require('@supabase/supabase-js');

const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m'
};

class ConfigValidator {
    constructor() {
        this.results = {
            valid: [],
            invalid: [],
            warnings: []
        };
    }

    log(message, type = 'info') {
        const prefix = {
            success: `${colors.green}✓${colors.reset}`,
            error: `${colors.red}✗${colors.reset}`,
            warning: `${colors.yellow}⚠${colors.reset}`,
            info: `${colors.blue}ℹ${colors.reset}`,
            check: `${colors.cyan}◉${colors.reset}`
        };
        console.log(`${prefix[type] || prefix.info} ${message}`);
    }

    checkEnvVar(name, required = false, validator = null) {
        const value = process.env[name];
        const exists = value && value.trim() !== '';
        const isDefault = value && (
            value.includes('your-') || 
            value.includes('your_') || 
            value === 'sk-your-openai-api-key-here'
        );

        if (!exists) {
            if (required) {
                this.log(`${name}: Missing (REQUIRED)`, 'error');
                this.results.invalid.push(`${name} (required)`);
            } else {
                this.log(`${name}: Not set (optional)`, 'warning');
                this.results.warnings.push(`${name} (optional)`);
            }
            return false;
        }

        if (isDefault) {
            this.log(`${name}: Default value detected - needs to be updated`, 'warning');
            this.results.warnings.push(`${name} (default value)`);
            return false;
        }

        if (validator && !validator(value)) {
            this.log(`${name}: Invalid format`, 'error');
            this.results.invalid.push(`${name} (invalid format)`);
            return false;
        }

        const maskedValue = value.substring(0, 10) + '...' + (value.length > 10 ? ` (${value.length} chars)` : '');
        this.log(`${name}: Set [${maskedValue}]`, 'success');
        this.results.valid.push(name);
        return true;
    }

    async testSupabase() {
        const url = process.env.SUPABASE_URL;
        const key = process.env.SUPABASE_ANON_KEY;

        if (!url || !key || url.includes('your-project')) {
            this.log('Supabase: Not configured', 'warning');
            return false;
        }

        try {
            const supabase = createClient(url, key);
            const { data, error } = await supabase.from('listings').select('id').limit(1);
            
            if (error && error.message.includes('relation "public.listings" does not exist')) {
                this.log('Supabase: Connected but listings table not found', 'warning');
                this.results.warnings.push('Supabase tables need setup');
                return true;
            }
            
            if (error) {
                this.log(`Supabase: Connection failed - ${error.message}`, 'error');
                return false;
            }
            
            this.log('Supabase: Connection successful', 'success');
            return true;
        } catch (err) {
            this.log(`Supabase: Test failed - ${err.message}`, 'error');
            return false;
        }
    }

    async testOpenAI() {
        const key = process.env.OPENAI_API_KEY;
        
        if (!key || key === 'sk-your-openai-api-key-here') {
            this.log('OpenAI: Not configured', 'warning');
            return false;
        }

        try {
            const response = await axios.get('https://api.openai.com/v1/models', {
                headers: {
                    'Authorization': `Bearer ${key}`
                },
                timeout: 5000
            });
            
            this.log('OpenAI: API key valid', 'success');
            return true;
        } catch (err) {
            if (err.response?.status === 401) {
                this.log('OpenAI: Invalid API key', 'error');
            } else {
                this.log(`OpenAI: Test failed - ${err.message}`, 'error');
            }
            return false;
        }
    }

    async testStripe() {
        const key = process.env.STRIPE_SECRET_KEY;
        
        if (!key || key.includes('your-stripe')) {
            this.log('Stripe: Not configured', 'warning');
            return false;
        }

        try {
            const stripe = require('stripe')(key);
            await stripe.customers.list({ limit: 1 });
            this.log('Stripe: API key valid', 'success');
            return true;
        } catch (err) {
            if (err.type === 'StripeAuthenticationError') {
                this.log('Stripe: Invalid API key', 'error');
            } else {
                this.log(`Stripe: Test failed - ${err.message}`, 'error');
            }
            return false;
        }
    }

    async run() {
        console.log('\n' + colors.cyan + '========================================' + colors.reset);
        console.log(colors.cyan + '  RoomFinderAI Configuration Validator' + colors.reset);
        console.log(colors.cyan + '========================================' + colors.reset + '\n');

        // Check required environment variables
        console.log(colors.blue + '\n📋 Checking Environment Variables:' + colors.reset);
        console.log('─'.repeat(40));
        
        // Core requirements
        this.checkEnvVar('SUPABASE_URL', true, (v) => v.includes('supabase.co'));
        this.checkEnvVar('SUPABASE_ANON_KEY', true, (v) => v.startsWith('eyJ'));
        this.checkEnvVar('OPENAI_API_KEY', false, (v) => v.startsWith('sk-'));
        
        // Optional services
        this.checkEnvVar('STRIPE_SECRET_KEY', false, (v) => v.startsWith('sk_'));
        this.checkEnvVar('STRIPE_PUBLISHABLE_KEY', false, (v) => v.startsWith('pk_'));
        this.checkEnvVar('GOOGLE_API_KEY', false);
        this.checkEnvVar('BREVO_API_KEY', false);
        
        // Azure services
        this.checkEnvVar('AZURE_DOCUMENT_INTELLIGENCE_KEY', false);
        this.checkEnvVar('AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT', false, (v) => v.includes('azure.com'));
        this.checkEnvVar('AZURE_FACE_KEY', false);
        this.checkEnvVar('AZURE_FACE_ENDPOINT', false, (v) => v.includes('azure.com'));
        
        // Server config
        this.checkEnvVar('PORT', false);
        this.checkEnvVar('NODE_ENV', false);
        
        // Feature flags
        this.checkEnvVar('ENABLE_DEMO_MODE', false);
        this.checkEnvVar('ENABLE_ANONYMOUS_BROWSING', false);

        // Test service connections
        console.log(colors.blue + '\n🔌 Testing Service Connections:' + colors.reset);
        console.log('─'.repeat(40));
        
        await this.testSupabase();
        await this.testOpenAI();
        await this.testStripe();

        // Summary
        console.log('\n' + colors.cyan + '========================================' + colors.reset);
        console.log(colors.cyan + '  Configuration Summary' + colors.reset);
        console.log(colors.cyan + '========================================' + colors.reset + '\n');
        
        if (this.results.valid.length > 0) {
            console.log(colors.green + `✓ Valid configurations: ${this.results.valid.length}` + colors.reset);
        }
        
        if (this.results.warnings.length > 0) {
            console.log(colors.yellow + `⚠ Warnings: ${this.results.warnings.length}` + colors.reset);
            this.results.warnings.forEach(w => console.log(`  - ${w}`));
        }
        
        if (this.results.invalid.length > 0) {
            console.log(colors.red + `✗ Invalid/Missing: ${this.results.invalid.length}` + colors.reset);
            this.results.invalid.forEach(i => console.log(`  - ${i}`));
        }

        console.log('\n' + colors.blue + 'Next Steps:' + colors.reset);
        if (this.results.invalid.length > 0 || this.results.warnings.length > 0) {
            console.log('1. Copy .env.example to .env');
            console.log('2. Fill in the missing/invalid values');
            console.log('3. Run this validator again: node validate-config.js');
            console.log('4. Start the server: npm start');
        } else {
            console.log('✅ Configuration looks good! You can start the server with: npm start');
        }
        
        console.log('\n');
        process.exit(this.results.invalid.length > 0 ? 1 : 0);
    }
}

// Run validator
const validator = new ConfigValidator();
validator.run().catch(err => {
    console.error('Validator error:', err);
    process.exit(1);
});