/**
 * Automated Translation Script for RoomPal
 * Uses free translation services to generate translations for all supported languages
 *
 * Services used (in order of preference):
 * 1. DeepL API (free tier: 500K chars/month) - highest quality
 * 2. LibreTranslate (self-hosted, unlimited) - good quality, free
 * 3. Google Cloud Translate (free $300 credits) - fallback
 *
 * Usage:
 *   node scripts/translate.js
 *   node scripts/translate.js --service=deepl
 *   node scripts/translate.js --service=libretranslate --url=http://localhost:5000
 *   node scripts/translate.js --lang=es,fr,de (translate specific languages only)
 *
 * @version 1.0.0
 */

const fs = require('fs');
const path = require('path');

// Configuration
const config = {
    sourceLanguage: 'en',
    targetLanguages: ['es', 'zh', 'fr', 'de', 'ar', 'hi', 'ja', 'ko', 'he'],
    sourceFile: path.join(__dirname, '../locales/en.json'),
    outputDir: path.join(__dirname, '../locales'),

    // Translation service settings
    services: {
        libretranslate: {
            url: process.env.LIBRETRANSLATE_URL || 'http://localhost:5000',
            apiKey: process.env.LIBRETRANSLATE_API_KEY || null
        },
        deepl: {
            apiKey: process.env.DEEPL_API_KEY || null,
            url: 'https://api-free.deepl.com/v2/translate'
        },
        google: {
            apiKey: process.env.GOOGLE_TRANSLATE_API_KEY || null,
            url: 'https://translation.googleapis.com/language/translate/v2'
        }
    },

    // Default service (libretranslate is free and unlimited)
    defaultService: 'libretranslate'
};

// Language code mappings for different services
const languageCodeMap = {
    'zh': { deepl: 'zh', libretranslate: 'zh', google: 'zh-CN' },
    'he': { deepl: 'he', libretranslate: 'he', google: 'iw' }
};

/**
 * Translate text using LibreTranslate (Free, Open-Source)
 */
async function translateWithLibreTranslate(text, targetLang) {
    const fetch = (await import('node-fetch')).default;

    const { url, apiKey } = config.services.libretranslate;

    const body = {
        q: text,
        source: config.sourceLanguage,
        target: targetLang,
        format: 'text'
    };

    if (apiKey) {
        body.api_key = apiKey;
    }

    try {
        const response = await fetch(`${url}/translate`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body)
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${await response.text()}`);
        }

        const data = await response.json();
        return data.translatedText;
    } catch (error) {
        console.error(`❌ LibreTranslate error for ${targetLang}:`, error.message);
        return null;
    }
}

/**
 * Translate text using DeepL API (Free tier: 500K chars/month)
 */
async function translateWithDeepL(text, targetLang) {
    const fetch = (await import('node-fetch')).default;

    const { apiKey, url } = config.services.deepl;

    if (!apiKey) {
        console.log('⚠️  DeepL API key not found. Skipping DeepL.');
        return null;
    }

    const mappedLang = languageCodeMap[targetLang]?.deepl || targetLang;

    try {
        const params = new URLSearchParams({
            auth_key: apiKey,
            text: text,
            source_lang: config.sourceLanguage.toUpperCase(),
            target_lang: mappedLang.toUpperCase()
        });

        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: params
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const data = await response.json();
        return data.translations[0].text;
    } catch (error) {
        console.error(`❌ DeepL error for ${targetLang}:`, error.message);
        return null;
    }
}

/**
 * Translate text using Google Cloud Translate
 */
async function translateWithGoogle(text, targetLang) {
    const fetch = (await import('node-fetch')).default;

    const { apiKey, url } = config.services.google;

    if (!apiKey) {
        console.log('⚠️  Google API key not found. Skipping Google Translate.');
        return null;
    }

    const mappedLang = languageCodeMap[targetLang]?.google || targetLang;

    try {
        const params = new URLSearchParams({
            key: apiKey,
            q: text,
            source: config.sourceLanguage,
            target: mappedLang,
            format: 'text'
        });

        const response = await fetch(`${url}?${params}`);

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const data = await response.json();
        return data.data.translations[0].translatedText;
    } catch (error) {
        console.error(`❌ Google Translate error for ${targetLang}:`, error.message);
        return null;
    }
}

/**
 * Translate text with fallback between services
 */
async function translateText(text, targetLang, preferredService = config.defaultService) {
    let translation = null;

    // Try preferred service first
    if (preferredService === 'deepl') {
        translation = await translateWithDeepL(text, targetLang);
    } else if (preferredService === 'google') {
        translation = await translateWithGoogle(text, targetLang);
    } else {
        translation = await translateWithLibreTranslate(text, targetLang);
    }

    // Fallback chain
    if (!translation && preferredService !== 'libretranslate') {
        translation = await translateWithLibreTranslate(text, targetLang);
    }

    if (!translation && preferredService !== 'deepl') {
        translation = await translateWithDeepL(text, targetLang);
    }

    if (!translation && preferredService !== 'google') {
        translation = await translateWithGoogle(text, targetLang);
    }

    // Last resort: return original text
    if (!translation) {
        console.warn(`⚠️  Failed to translate "${text.substring(0, 50)}..." to ${targetLang}`);
        return text;
    }

    return translation;
}

/**
 * Recursively translate nested JSON object
 */
async function translateObject(obj, targetLang, service, depth = 0) {
    const translated = {};

    for (const [key, value] of Object.entries(obj)) {
        if (typeof value === 'string') {
            // Skip if value contains only placeholders or special characters
            if (/^[\{\}]/.test(value) || value.trim().length === 0) {
                translated[key] = value;
                continue;
            }

            // Translate the string
            console.log(`   ${'  '.repeat(depth)}Translating: ${key}`);
            translated[key] = await translateText(value, targetLang, service);

            // Add small delay to respect rate limits
            await new Promise(resolve => setTimeout(resolve, 100));
        } else if (typeof value === 'object' && value !== null) {
            // Recursively translate nested objects
            translated[key] = await translateObject(value, targetLang, service, depth + 1);
        } else {
            // Keep non-string values as-is
            translated[key] = value;
        }
    }

    return translated;
}

/**
 * Translate to a single language
 */
async function translateToLanguage(targetLang, service) {
    console.log(`\n🌍 Translating to ${targetLang.toUpperCase()}...`);

    // Load source file
    const sourceData = JSON.parse(fs.readFileSync(config.sourceFile, 'utf8'));

    // Check if translation already exists
    const outputFile = path.join(config.outputDir, `${targetLang}.json`);
    if (fs.existsSync(outputFile)) {
        console.log(`⚠️  ${targetLang}.json already exists. Overwrite? (delete file and run again)`);
        return;
    }

    // Translate
    const startTime = Date.now();
    const translated = await translateObject(sourceData, targetLang, service);
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);

    // Save to file
    fs.writeFileSync(outputFile, JSON.stringify(translated, null, 2), 'utf8');

    console.log(`✅ Saved ${outputFile}`);
    console.log(`⏱️  Completed in ${duration}s\n`);
}

/**
 * Main function
 */
async function main() {
    console.log('🚀 RoomPal Translation Generator');
    console.log('================================\n');

    // Parse command line arguments
    const args = process.argv.slice(2);
    let service = config.defaultService;
    let languages = config.targetLanguages;

    args.forEach(arg => {
        if (arg.startsWith('--service=')) {
            service = arg.split('=')[1];
        } else if (arg.startsWith('--lang=')) {
            languages = arg.split('=')[1].split(',');
        } else if (arg.startsWith('--url=')) {
            config.services.libretranslate.url = arg.split('=')[1];
        }
    });

    console.log(`📝 Source: ${config.sourceFile}`);
    console.log(`🎯 Target languages: ${languages.join(', ')}`);
    console.log(`🔧 Using service: ${service}\n`);

    // Check if source file exists
    if (!fs.existsSync(config.sourceFile)) {
        console.error(`❌ Source file not found: ${config.sourceFile}`);
        process.exit(1);
    }

    // Create output directory if it doesn't exist
    if (!fs.existsSync(config.outputDir)) {
        fs.mkdirSync(config.outputDir, { recursive: true });
    }

    // Translate to each language
    for (const lang of languages) {
        try {
            await translateToLanguage(lang, service);
        } catch (error) {
            console.error(`❌ Error translating to ${lang}:`, error);
        }
    }

    console.log('\n✅ Translation complete!');
    console.log('\n📋 Next steps:');
    console.log('   1. Review translations for accuracy');
    console.log('   2. Get native speakers to verify translations');
    console.log('   3. Submit corrections via translation_suggestions table');
    console.log('   4. Mark verified translations as "community_verified"');
}

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { translateText, translateObject, translateToLanguage };
