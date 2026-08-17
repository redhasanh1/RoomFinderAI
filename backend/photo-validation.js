/**
 * Checks that an uploaded photo is actually a property, by looking at the
 * photo.
 *
 * The previous check asked a text model whether the *generated analysis* looked
 * like a property listing. That could never fail: the analysis is assembled
 * from a template with defaults, so it always reads like a listing no matter
 * what was uploaded. A company logo came back as "Premium 2-Bedroom House in
 * Los Angeles, granite, stainless, hardwood".
 *
 * This looks at the image itself and runs BEFORE the listing is generated, so
 * nothing is written from a photo that is not a room.
 */

const axios = require('axios');

const VISION_MODEL = 'gpt-4o-mini';

/**
 * @param {Buffer} imageBuffer
 * @param {object} config  needs OPENAI_API_KEY
 * @returns {Promise<{checked: boolean, isProperty: boolean, reason: string}>}
 *
 * `checked: false` means the check could not run (no key, model unreachable).
 * Callers decide what to do with that; failing open is deliberate, because
 * blocking every upload when the validator is down is worse than the
 * occasional bad photo.
 */
async function validatePropertyPhoto(imageBuffer, config) {
    if (!config?.OPENAI_API_KEY) {
        return { checked: false, isProperty: true, reason: 'No vision key configured' };
    }
    if (!Buffer.isBuffer(imageBuffer) || imageBuffer.length === 0) {
        return { checked: true, isProperty: false, reason: 'The image could not be read.' };
    }

    const dataUri = `data:image/jpeg;base64,${imageBuffer.toString('base64')}`;

    try {
        const response = await axios.post(
            'https://api.openai.com/v1/chat/completions',
            {
                model: VISION_MODEL,
                max_tokens: 120,
                temperature: 0,
                messages: [
                    {
                        role: 'system',
                        content: [
                            'You check photos submitted to a rental listing site.',
                            'Answer ONLY with JSON: {"isProperty": true|false, "reason": "one short sentence"}.',
                            'isProperty is true ONLY for a photograph of a real room, building, or outdoor space of a home.',
                            'It is false for logos, icons, illustrations, screenshots, memes, text, blank or solid-colour images, people, pets, food, and objects.',
                            'A drawing or rendering of a house is NOT a property photo.'
                        ].join(' ')
                    },
                    {
                        role: 'user',
                        content: [
                            { type: 'text', text: 'Is this a photograph of a real rental property?' },
                            { type: 'image_url', image_url: { url: dataUri, detail: 'low' } }
                        ]
                    }
                ]
            },
            {
                headers: {
                    Authorization: `Bearer ${config.OPENAI_API_KEY}`,
                    'Content-Type': 'application/json'
                },
                timeout: 25000
            }
        );

        const raw = response.data?.choices?.[0]?.message?.content || '';
        const match = raw.match(/\{[\s\S]*\}/);
        if (!match) {
            return { checked: false, isProperty: true, reason: 'Validator returned no verdict' };
        }

        const verdict = JSON.parse(match[0]);
        return {
            checked: true,
            isProperty: verdict.isProperty !== false,
            reason: verdict.reason || 'That photo does not look like a rental property.'
        };
    } catch (error) {
        // Fail open, but say so in the logs — a silent skip would make this
        // look like it was checking when it was not.
        console.warn('Property photo validation could not run:', error.message);
        return { checked: false, isProperty: true, reason: 'Validator unavailable' };
    }
}

module.exports = { validatePropertyPhoto };
