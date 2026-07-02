/**
 * Multi-provider AI chat with automatic failover.
 *
 * Priority chain (when AI_PROVIDER is unset / "auto" / "openai"):
 *   1. OpenAI            (primary — highest quality)
 *   2. Groq llama-3.1-8b-instant   (fast, free-tier fallback)
 *   3. Groq llama-3.3-70b-versatile (higher-quality Groq fallback)
 *
 * Set AI_PROVIDER=groq to make Groq primary (OpenAI becomes last-resort).
 * Groq's API is OpenAI-compatible: https://console.groq.com/docs/openai
 */

const GROQ_PRIMARY_MODEL = 'llama-3.1-8b-instant';
const GROQ_FALLBACK_MODEL = 'llama-3.3-70b-versatile';
const OPENAI_DEFAULT_MODEL = 'gpt-4o-mini';

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

/**
 * Build the ordered list of providers to try. Each entry is fully
 * self-contained (carries its own model), so callAI just iterates in order.
 */
function getConfiguredProviders(config) {
    const preferred = (process.env.AI_PROVIDER || 'auto').toLowerCase();
    const hasOpenAI = !!(config.OPENAI_API_KEY && config.OPENAI_API_KEY.startsWith('sk-'));
    const hasGroq = !!config.GROQ_API_KEY;

    const openai = hasOpenAI
        ? {
              name: 'openai',
              apiKey: config.OPENAI_API_KEY,
              baseUrl: 'https://api.openai.com/v1',
              model: config.OPENAI_MODEL || OPENAI_DEFAULT_MODEL,
              orgId: config.OPENAI_ORG_ID
          }
        : null;

    const groqInstant = hasGroq
        ? {
              name: 'groq',
              apiKey: config.GROQ_API_KEY,
              baseUrl: 'https://api.groq.com/openai/v1',
              model: config.GROQ_MODEL || GROQ_PRIMARY_MODEL
          }
        : null;

    const groqVersatile = hasGroq
        ? {
              name: 'groq',
              apiKey: config.GROQ_API_KEY,
              baseUrl: 'https://api.groq.com/openai/v1',
              model: config.GROQ_FALLBACK_MODEL || GROQ_FALLBACK_MODEL
          }
        : null;

    // Default: OpenAI primary, then the two Groq fallbacks (llama instant, then versatile).
    // AI_PROVIDER=groq flips Groq to the front and demotes OpenAI to last-resort.
    const ordered =
        preferred === 'groq'
            ? [groqInstant, groqVersatile, openai]
            : [openai, groqInstant, groqVersatile];

    // Drop unconfigured providers and de-duplicate identical name+model pairs.
    const seen = new Set();
    return ordered.filter((p) => {
        if (!p) return false;
        const key = `${p.name}:${p.model}`;
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
    });
}

/**
 * Call the AI with automatic failover across the configured provider chain.
 * The legacy `model` argument is accepted for backward compatibility but each
 * provider now uses its own configured model.
 */
async function callAI(config, { messages, model, maxTokens = 300, temperature = 0.7 }) {
    const providers = getConfiguredProviders(config);

    if (providers.length === 0) {
        throw new Error(
            'No AI provider configured. Set OPENAI_API_KEY (primary) or GROQ_API_KEY (fallback).'
        );
    }

    let lastError;
    for (const provider of providers) {
        try {
            const result = await chatCompletion({
                apiKey: provider.apiKey,
                baseUrl: provider.baseUrl,
                model: provider.model,
                messages,
                maxTokens,
                temperature,
                orgId: provider.orgId
            });
            return { ...result, provider: provider.name };
        } catch (error) {
            console.warn(`AI provider ${provider.name} (${provider.model}) failed: ${error.message}`);
            lastError = error;
        }
    }

    throw lastError || new Error('All AI providers failed');
}

function getAIStatus(config) {
    const providers = getConfiguredProviders(config);
    return {
        openai: !!(config.OPENAI_API_KEY && config.OPENAI_API_KEY.startsWith('sk-')),
        groq: !!config.GROQ_API_KEY,
        preferred: process.env.AI_PROVIDER || 'auto',
        chain: providers.map((p) => `${p.name}:${p.model}`),
        available: [...new Set(providers.map((p) => p.name))]
    };
}

module.exports = {
    callAI,
    getAIStatus,
    getConfiguredProviders
};
