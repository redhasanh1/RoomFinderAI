/**
 * RoomFinderAI Vision Worker
 * Analyzes property photos using Cloudflare Workers AI (LLaVA)
 * FREE: 10,000 neurons/day
 */

export interface Env {
    AI: Ai;
}

interface AnalysisResult {
    title: string;
    house_type: 'Apartment' | 'House' | 'Condo' | 'Townhouse';
    bedrooms: number;
    description: string;
    suggestedPrice: number;
    features: string[];
    confidence: number;
}

export default {
    async fetch(request: Request, env: Env): Promise<Response> {
        // CORS preflight
        if (request.method === 'OPTIONS') {
            return new Response(null, {
                headers: {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Max-Age': '86400',
                }
            });
        }

        // Only accept POST requests
        if (request.method !== 'POST') {
            return new Response(JSON.stringify({
                success: false,
                error: 'Method not allowed'
            }), {
                status: 405,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                }
            });
        }

        try {
            const { image } = await request.json() as { image: number[] };

            if (!image || !Array.isArray(image)) {
                return new Response(JSON.stringify({
                    success: false,
                    error: 'Invalid image data. Expected base64-encoded image as array of bytes.'
                }), {
                    status: 400,
                    headers: {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    }
                });
            }

            // Run LLaVA vision model
            const response = await env.AI.run('@cf/llava-hf/llava-1.5-7b-hf', {
                prompt: `Look at this property photo carefully. Describe what you see, then return JSON.

IMPORTANT: Actually analyze the image. Do NOT use placeholder values. Do NOT copy example values.

What type of property is this? Look for:
- House exterior with yard/driveway = "House"
- Apartment interior or apartment building = "Apartment"
- Condo-style building or unit = "Condo"
- Attached multi-unit rowhouse = "Townhouse"

How many bedrooms? Count beds visible, or estimate from room sizes and layout.

What is the condition and quality level? This affects price:
- Budget/basic condition: $800-1200/month
- Average/decent condition: $1300-1800/month
- Nice/updated finishes: $1900-2500/month
- Luxury/high-end: $2600+/month

Return ONLY this JSON (no other text):
{
"title": "<write a specific title describing what you see in this image>",
"house_type": "<House OR Apartment OR Condo OR Townhouse based on what you see>",
"bedrooms": <your bedroom count estimate as a number>,
"description": "<describe the actual room/property visible: flooring, walls, windows, furniture, lighting, condition>",
"suggestedPrice": <your price estimate as a number based on quality you observe>,
"features": ["<actual feature 1 you see>", "<actual feature 2 you see>"],
"confidence": <0.5 if image is unclear, 0.7 if decent view, 0.9 if clear full view>
}`,
                image: image
            }) as { response?: string };

            // Parse the AI response
            let analysis: AnalysisResult;

            try {
                // Try to extract JSON from the response
                const responseText = response.response || '';

                // Find JSON in the response (handle cases where AI adds extra text)
                const jsonMatch = responseText.match(/\{[\s\S]*\}/);
                if (jsonMatch) {
                    analysis = JSON.parse(jsonMatch[0]);
                } else {
                    throw new Error('No JSON found in response');
                }

                // Validate and sanitize the response
                analysis = {
                    title: String(analysis.title || 'Beautiful Property for Rent').slice(0, 60),
                    house_type: ['Apartment', 'House', 'Condo', 'Townhouse'].includes(analysis.house_type)
                        ? analysis.house_type
                        : 'Apartment',
                    bedrooms: Math.max(1, Math.min(10, parseInt(String(analysis.bedrooms)) || 1)),
                    description: String(analysis.description || 'A wonderful property awaiting your personal touch.').slice(0, 1000),
                    suggestedPrice: Math.max(500, Math.min(10000, parseInt(String(analysis.suggestedPrice)) || 1500)),
                    features: Array.isArray(analysis.features)
                        ? analysis.features.slice(0, 10).map(f => String(f).slice(0, 50))
                        : ['Modern interior'],
                    confidence: Math.max(0, Math.min(1, parseFloat(String(analysis.confidence)) || 0.7))
                };

            } catch (parseError) {
                console.error('Failed to parse AI response:', parseError);
                console.error('Raw response:', response);
                return new Response(JSON.stringify({
                    success: false,
                    error: 'LLaVA returned invalid response. Try a clearer photo.'
                }), {
                    status: 500,
                    headers: {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    }
                });
            }

            return new Response(JSON.stringify({
                success: true,
                analysis
            }), {
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                }
            });

        } catch (error) {
            console.error('Worker error:', error);

            return new Response(JSON.stringify({
                success: false,
                error: error instanceof Error ? error.message : 'LLaVA analysis failed'
            }), {
                status: 500,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                }
            });
        }
    }
};
