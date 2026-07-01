/**
 * Multi-provider AI chat — OpenAI primary, Groq free-tier fallback.
 * Groq API is OpenAI-compatible: https://console.groq.com/docs/openai
 */

const GROQ_DEFAULT_MODEL = 'llama-3.1-8b-instant';
const OPENAI_DEFAULT_MODEL = 'gpt-3.5-turbo';

async function chatCompletion({ apiKey, baseUrl, model, messages, maxTokens, temperature, orgId }) {
    const response = await fetch(`${baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
            ...(orgId && { 'OpenAI-Organization': orgId })
        },
        body: JSON.stringify({
            model,
            messages,
            max_tokens: maxTokens,
            temperature,
            presence_penalty: 0.1,
            frequency_penalty: 0.1
        })
    });

    if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        const message = errorData.error?.message || `HTTP ${response.status}`;
        throw new Error(message);
    }

    const data = await response.json();
    return {
        content: data.choices[0].message.content.trim(),
        tokensUsed: data.usage?.total_tokens || 0,
        model: data.model || model
    };
}

function getConfiguredProviders(config) {
    const providers = [];

    const preferred = (process.env.AI_PROVIDER || 'auto').toLowerCase();

    if (config.GROQ_API_KEY && (preferred === 'auto' || preferred === 'groq')) {
        providers.push({
            name: 'groq',
            apiKey: config.GROQ_API_KEY,
            baseUrl: 'https://api.groq.com/openai/v1',
            model: config.GROQ_MODEL || GROQ_DEFAULT_MODEL
        });
    }

    if (config.OPENAI_API_KEY?.startsWith('sk-') && (preferred === 'auto' || preferred === 'openai')) {
        providers.push({
            name: 'openai',
            apiKey: config.OPENAI_API_KEY,
            baseUrl: 'https://api.openai.com/v1',
            model: config.OPENAI_MODEL || OPENAI_DEFAULT_MODEL,
            orgId: config.OPENAI_ORG_ID
        });
    }

    if (preferred === 'groq' && providers.length === 0 && config.OPENAI_API_KEY?.startsWith('sk-')) {
        providers.push({
            name: 'openai',
            apiKey: config.OPENAI_API_KEY,
            baseUrl: 'https://api.openai.com/v1',
            model: config.OPENAI_MODEL || OPENAI_DEFAULT_MODEL,
            orgId: config.OPENAI_ORG_ID
        });
    }

    if (preferred === 'openai' && providers.length === 0 && config.GROQ_API_KEY) {
        providers.unshift({
            name: 'groq',
            apiKey: config.GROQ_API_KEY,
            baseUrl: 'https://api.groq.com/openai/v1',
            model: config.GROQ_MODEL || GROQ_DEFAULT_MODEL
        });
    }

    return providers;
}

async function callAI(config, { messages, model, maxTokens = 300, temperature = 0.7 }) {
    const providers = getConfiguredProviders(config);

    if (providers.length === 0) {
        throw new Error('No AI provider configured. Set OPENAI_API_KEY or GROQ_API_KEY on Railway.');
    }

    let lastError;

    for (const provider of providers) {
        const useModel =
            provider.name === 'openai' && model === 'gpt-4'
                ? provider.model
                : provider.name === 'groq'
                  ? provider.model
                  : model === 'gpt-4'
                    ? provider.model
                    : provider.model;

        try {
            const result = await chatCompletion({
                apiKey: provider.apiKey,
                baseUrl: provider.baseUrl,
                model: useModel,
                messages,
                maxTokens,
                temperature,
                orgId: provider.orgId
            });
            return { ...result, provider: provider.name };
        } catch (error) {
            console.warn(`AI provider ${provider.name} failed:`, error.message);
            lastError = error;
        }
    }

    throw lastError || new Error('All AI providers failed');
}

function getAIStatus(config) {
    return {
        openai: !!(config.OPENAI_API_KEY && config.OPENAI_API_KEY.startsWith('sk-')),
        groq: !!config.GROQ_API_KEY,
        preferred: process.env.AI_PROVIDER || 'auto',
        available: getConfiguredProviders(config).map((p) => p.name)
    };
}

module.exports = {
    callAI,
    getAIStatus,
    getConfiguredProviders
};
