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
  house_type: "Apartment" | "House" | "Condo" | "Townhouse";
  bedrooms: number;
  description: string;
  suggestedPrice: number;
  features: string[];
  confidence: number;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type"
        }
      });
    }

    if (request.method !== "POST") {
      return new Response(JSON.stringify({ success: false, error: "POST only" }), {
        status: 405,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    }

    try {
      const body = await request.json() as { image: number[] };
      const image = body.image;

      if (!image || !Array.isArray(image)) {
        return new Response(JSON.stringify({ success: false, error: "No image" }), {
          status: 400,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
        });
      }

      // Call LLaVA - returns "description" field, NOT "response"
      const response = await env.AI.run("@cf/llava-hf/llava-1.5-7b-hf", {
        image: image,
        prompt: "Describe this property. What type house or apartment? How many bedrooms? What features?"
      }) as { description?: string; response?: string };

      const rawText = response.description || response.response || "";

      if (!rawText) {
        return new Response(JSON.stringify({ success: false, error: "Empty response" }), {
          status: 500,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
        });
      }

      const textLower = rawText.toLowerCase();

      // Detect property type from description
      let house_type: AnalysisResult["house_type"] = "Apartment";
      if (textLower.includes("house") || textLower.includes("garage") || textLower.includes("yard")) {
        house_type = "House";
      } else if (textLower.includes("condo")) {
        house_type = "Condo";
      } else if (textLower.includes("townhouse")) {
        house_type = "Townhouse";
      }

      // Detect bedrooms
      let bedrooms = 2;
      const bedroomMatch = rawText.match(/(\d+)\s*bed/i);
      if (bedroomMatch) {
        bedrooms = Math.min(10, Math.max(1, parseInt(bedroomMatch[1])));
      } else if (textLower.includes("large") || textLower.includes("two-story")) {
        bedrooms = 3;
      }

      // Detect quality for pricing
      let suggestedPrice = 1800;
      if (textLower.includes("luxury") || textLower.includes("large") || textLower.includes("spacious")) {
        suggestedPrice = 2800;
      } else if (textLower.includes("well-maintained") || textLower.includes("modern")) {
        suggestedPrice = 2200;
      }

      // Extract features mentioned
      const features: string[] = [];
      const keywords = ["garage", "brick", "driveway", "parking", "yard", "patio", "fireplace", "hardwood"];
      for (const keyword of keywords) {
        if (textLower.includes(keyword)) features.push(keyword);
      }
      if (features.length === 0) features.push("See photos");

      const analysis: AnalysisResult = {
        title: house_type + " for Rent",
        house_type: house_type,
        bedrooms: bedrooms,
        description: rawText.slice(0, 500),
        suggestedPrice: suggestedPrice,
        features: features.slice(0, 6),
        confidence: 0.75
      };

      return new Response(JSON.stringify({ success: true, analysis: analysis }), {
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });

    } catch (err) {
      const error = err instanceof Error ? err.message : "LLaVA analysis failed";
      return new Response(JSON.stringify({ success: false, error: error }), {
        status: 500,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    }
  }
};
