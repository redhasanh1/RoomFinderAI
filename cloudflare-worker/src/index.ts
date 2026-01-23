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
                prompt: `You are a real estate listing assistant. Analyze this property photo carefully and extract details for a rental listing.

IMPORTANT: Return ONLY valid JSON with NO additional text or explanation. The response must be parseable JSON.

Analyze the image and return this exact JSON structure:
{
    "title": "A compelling, descriptive title for this property (max 60 characters)",
    "house_type": "One of: Apartment, House, Condo, or Townhouse",
    "bedrooms": <estimated number of bedrooms as integer, use 1 if unsure>,
    "description": "A compelling 100-200 word description highlighting the property's best features, natural lighting, space, and appeal to potential renters",
    "suggestedPrice": <estimated monthly rent in USD as integer based on visible quality and features>,
    "features": ["list", "of", "detected", "features", "like hardwood floors", "natural light", "modern kitchen"],
    "confidence": <0.0 to 1.0 confidence score for overall analysis>
}

Focus on:
- Room type visible (living room, bedroom, kitchen, etc.)
- Visible amenities and features
- Overall condition and style
- Natural lighting
- Space and layout`,
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
