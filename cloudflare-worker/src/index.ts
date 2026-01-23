/**
 * RoomFinderAI Vision Worker
 * Analyzes property photos using Cloudflare Workers AI (Llama 3.2 Vision)
 * FREE: ~50 images/day on free tier
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
  condition: number; // 1-5 quality rating
}

// Location multipliers for major US metro areas (by zip code prefix)
const locationMultipliers: Record<string, number> = {
  // San Francisco Bay Area
  "941": 2.5, "940": 2.3, "945": 2.2, "943": 2.0,
  // New York City
  "100": 2.8, "101": 2.6, "102": 2.5, "103": 2.4, "104": 2.3, "110": 2.2, "111": 2.1,
  // Los Angeles
  "900": 2.2, "901": 2.1, "902": 2.0, "903": 1.9, "904": 1.8,
  // Seattle
  "981": 2.0, "980": 1.9, "982": 1.8,
  // Boston
  "021": 2.1, "022": 2.0, "020": 1.9,
  // Miami
  "331": 1.8, "330": 1.7, "332": 1.6,
  // Austin
  "787": 1.7, "786": 1.6,
  // Denver
  "802": 1.6, "800": 1.5,
  // Chicago
  "606": 1.5, "605": 1.4, "604": 1.3,
  // Default
  "default": 1.0
};

function getLocationMultiplier(zip: string | undefined): number {
  if (!zip) return 1.0;
  const prefix = zip.substring(0, 3);
  return locationMultipliers[prefix] || locationMultipliers["default"];
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
      const body = await request.json() as {
        image: number[];
        location?: {
          city?: string;
          state?: string;
          zip?: string;
          country?: string;
        };
      };
      const image = body.image;
      const location = body.location;

      if (!image || !Array.isArray(image)) {
        return new Response(JSON.stringify({ success: false, error: "No image" }), {
          status: 400,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
        });
      }

      // Chain-of-Thought prompt for better analysis
      const prompt = `Analyze this property photo step by step:

STEP 1 - Property Type: Is this a house exterior, apartment interior, condo, or townhouse? Look for: yard/driveway = house, lobby/corridor = apartment, balcony with shared walls = condo.

STEP 2 - Bedrooms: Estimate number of bedrooms. If exterior: small house = 2-3, medium = 3-4, large/two-story = 4-6. If interior: count visible doors, room sizes.

STEP 3 - Condition (1-5):
1 = Needs major work (visible damage, outdated)
2 = Fair (functional but dated)
3 = Good (well-maintained, average)
4 = Very Good (modern updates, nice finishes)
5 = Luxury (high-end finishes, exceptional quality)

STEP 4 - Features: List visible features like garage, yard, pool, hardwood floors, fireplace, modern kitchen, etc.

STEP 5 - Overall: Brief description of the property.

Provide your analysis clearly.`;

      // Use Llama 3.2 11B Vision - much better than LLaVA!
      const response = await env.AI.run("@cf/meta/llama-3.2-11b-vision-instruct", {
        image: image,
        prompt: prompt,
        max_tokens: 500
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

      // Detect condition rating (1-5)
      let condition = 3;
      const conditionMatch = rawText.match(/condition[:\s]*(\d)/i) || rawText.match(/(\d)\s*(?:out of\s*)?(?:\/\s*)?5/i);
      if (conditionMatch) {
        condition = Math.min(5, Math.max(1, parseInt(conditionMatch[1])));
      } else if (textLower.includes("luxury") || textLower.includes("exceptional") || textLower.includes("high-end")) {
        condition = 5;
      } else if (textLower.includes("very good") || textLower.includes("modern") || textLower.includes("updated") || textLower.includes("renovated")) {
        condition = 4;
      } else if (textLower.includes("well-maintained") || textLower.includes("good condition") || textLower.includes("average")) {
        condition = 3;
      } else if (textLower.includes("dated") || textLower.includes("fair") || textLower.includes("needs updating")) {
        condition = 2;
      } else if (textLower.includes("needs work") || textLower.includes("fixer") || textLower.includes("damaged")) {
        condition = 1;
      }

      // Quality descriptors based on condition
      const qualityDescriptors: Record<number, string> = {
        1: "fixer-upper",
        2: "charming",
        3: "well-maintained",
        4: "modern",
        5: "luxurious"
      };
      let quality = qualityDescriptors[condition] || "well-maintained";

      // Base price from condition
      const basePrices: Record<number, number> = {
        1: 1200,
        2: 1500,
        3: 1800,
        4: 2400,
        5: 3200
      };
      let suggestedPrice = basePrices[condition] || 1800;

      // Adjust by bedrooms
      suggestedPrice += (bedrooms - 2) * 300;

      // Adjust by property type
      if (house_type === "House") {
        suggestedPrice *= 1.2;
      } else if (house_type === "Condo") {
        suggestedPrice *= 1.1;
      } else if (house_type === "Townhouse") {
        suggestedPrice *= 1.15;
      }

      // Apply location multiplier if location data provided
      const locationMultiplier = getLocationMultiplier(location?.zip);
      suggestedPrice = Math.round(suggestedPrice * locationMultiplier);

      // Cap and round
      suggestedPrice = Math.round(suggestedPrice / 50) * 50; // Round to nearest 50

      // Extract features mentioned
      const features: string[] = [];
      const featureMap: Record<string, string> = {
        "garage": "Garage",
        "brick": "Brick exterior",
        "driveway": "Driveway",
        "parking": "Parking available",
        "yard": "Yard",
        "patio": "Patio",
        "fireplace": "Fireplace",
        "hardwood": "Hardwood floors",
        "pool": "Pool",
        "garden": "Garden",
        "balcony": "Balcony",
        "basement": "Basement",
        "attic": "Attic"
      };

      for (const [keyword, label] of Object.entries(featureMap)) {
        if (textLower.includes(keyword)) features.push(label);
      }
      if (features.length === 0) features.push("See photos for details");

      // Detect listing type (sale vs rent) - default to rent but check for sale keywords
      let listingType = "Rent";
      if (textLower.includes("sale") || textLower.includes("selling") || textLower.includes("buy")) {
        listingType = "Sale";
      }

      // Generate a nice formatted description
      const bedroomText = bedrooms === 1 ? "1 bedroom" : bedrooms + " bedrooms";
      const featureList = features.slice(0, 4).join(", ");

      const niceDescription = `Beautiful ${quality} ${house_type.toLowerCase()} available for ${listingType.toLowerCase()}. This ${bedroomText} property features ${featureList.toLowerCase() || "modern amenities"}. ${rawText.slice(0, 300)}`;

      // Calculate confidence based on how much info we extracted
      let confidence = 0.6; // Base confidence for Llama 3.2 Vision
      if (bedroomMatch) confidence += 0.1;
      if (features.length > 2) confidence += 0.1;
      if (conditionMatch) confidence += 0.1;
      if (location?.city) confidence += 0.1; // Boost confidence if we have location
      confidence = Math.min(0.95, confidence);

      // Build location string for title
      const locationStr = location?.city ? ` in ${location.city}` : "";

      const analysis: AnalysisResult & { location?: typeof location } = {
        title: quality.charAt(0).toUpperCase() + quality.slice(1) + " " + bedrooms + "-Bedroom " + house_type + " for " + listingType + locationStr,
        house_type: house_type,
        bedrooms: bedrooms,
        description: niceDescription.slice(0, 600),
        suggestedPrice: suggestedPrice,
        features: features.slice(0, 6),
        confidence: confidence,
        condition: condition,
        ...(location && { location })
      };

      return new Response(JSON.stringify({ success: true, analysis: analysis }), {
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });

    } catch (err) {
      const error = err instanceof Error ? err.message : "Vision analysis failed";
      return new Response(JSON.stringify({ success: false, error: error }), {
        status: 500,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    }
  }
};
