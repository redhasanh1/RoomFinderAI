/**
 * RoomFinderAI "GOD MODE" Vision Worker
 * The "Slumlord to Landlord" Engine
 * Analyzes, Judges, and Maximizes Rent in Real-Time
 */

export interface Env {
  AI: Ai;
}

interface MoneyFeature {
  feature: string;
  value: number; // Dollar value added to rent
}

interface Flaw {
  issue: string;
  fix: string;
  potentialGain: number; // How much more rent if fixed
}

interface GodModeAnalysis {
  // Basic Info
  title: string;
  house_type: "Apartment" | "House" | "Condo" | "Townhouse";
  bedrooms: number;
  description: string;

  // GOD MODE: The Wealth Detector
  luxuryScore: number; // 1-10
  unitGrade: string; // A+, A, A-, B+, etc.

  // GOD MODE: Money Features (things that ADD value)
  moneyFeatures: MoneyFeature[];

  // GOD MODE: Flaws (things to FIX to charge more)
  flaws: Flaw[];

  // GOD MODE: Predatory Pricing
  basePrice: number;
  suggestedPrice: number;
  premiumAboveAvg: number; // How much above area average

  // GOD MODE: Target Demographic
  targetDemo: string;
  vibeKeywords: string[];

  // GOD MODE: FOMO Copy
  fomoLines: string[];

  // Meta
  features: string[];
  confidence: number;
  needsStaging: boolean; // Should we call MarkRemoverAI?
  stagingIssues: string[]; // What to remove
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

// Base rent by property type
const baseRentByType: Record<string, number> = {
  "Apartment": 1600,
  "Condo": 1900,
  "Townhouse": 2100,
  "House": 2400
};

function getLocationMultiplier(zip: string | undefined): number {
  if (!zip) return 1.0;
  const prefix = zip.substring(0, 3);
  return locationMultipliers[prefix] || locationMultipliers["default"];
}

function calculateGrade(luxuryScore: number): string {
  if (luxuryScore >= 9) return "A+";
  if (luxuryScore >= 8) return "A";
  if (luxuryScore >= 7) return "A-";
  if (luxuryScore >= 6) return "B+";
  if (luxuryScore >= 5) return "B";
  if (luxuryScore >= 4) return "B-";
  if (luxuryScore >= 3) return "C+";
  if (luxuryScore >= 2) return "C";
  return "C-";
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

      // GOD MODE PROMPT - The "Wealth Detector" + "Judge"
      const prompt = `You are a ruthless real estate appraiser. Analyze this property photo and JUDGE it for maximum rent extraction.

PROPERTY TYPE: House, Apartment, Condo, or Townhouse?

BEDROOMS: Estimate count (1-10)

LUXURY SCORE (1-10): Rate the finishes and quality.
- 1-3: Budget/dated (laminate, white appliances, builder-grade)
- 4-6: Average (decent but nothing special)
- 7-8: Upscale (granite, stainless steel, hardwood)
- 9-10: Luxury (high-end finishes, designer touches)

MONEY FEATURES (things that ADD rent value):
List premium features you see: granite countertops, stainless appliances, hardwood floors, large windows, high ceilings, modern fixtures, exposed brick, updated kitchen, walk-in closet, natural light, bay windows, recessed lighting, etc.

FLAWS (things that HURT rent value):
List issues: old thermostat, dated lighting (boob lights), carpet stains, small windows, popcorn ceiling, old appliances, clutter, mess, poor staging, etc.

STAGING ISSUES (things to REMOVE from photo):
List any: clutter, mess, trash cans, toilet seats up, personal items, dirty dishes, unmade beds, etc.

VIBE CHECK: What demographic would love this?
- Exposed brick/industrial = Hipsters ("Industrial chic, loft vibes")
- White/beige/neutral = Families ("Safe, quiet, cozy")
- Modern/LED/sleek = Tech bros ("Modern, high-speed ready")
- Traditional/crown molding = Professionals ("Classic, elegant")

Provide detailed analysis.`;

      // Use Llama 3.2 11B Vision for GOD MODE analysis
      const response = await env.AI.run("@cf/meta/llama-3.2-11b-vision-instruct", {
        image: image,
        prompt: prompt,
        max_tokens: 800
      }) as { description?: string; response?: string };

      const rawText = response.description || response.response || "";

      if (!rawText) {
        return new Response(JSON.stringify({ success: false, error: "Empty response" }), {
          status: 500,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
        });
      }

      const textLower = rawText.toLowerCase();

      // ========== PROPERTY TYPE ==========
      let house_type: GodModeAnalysis["house_type"] = "Apartment";
      if (textLower.includes("house") || textLower.includes("garage") || textLower.includes("yard") || textLower.includes("driveway")) {
        house_type = "House";
      } else if (textLower.includes("condo")) {
        house_type = "Condo";
      } else if (textLower.includes("townhouse") || textLower.includes("town house")) {
        house_type = "Townhouse";
      }

      // ========== BEDROOMS ==========
      let bedrooms = 2;
      const bedroomMatch = rawText.match(/(\d+)\s*(?:bed|bedroom|br)/i);
      if (bedroomMatch) {
        bedrooms = Math.min(10, Math.max(1, parseInt(bedroomMatch[1])));
      } else if (textLower.includes("large") || textLower.includes("two-story") || textLower.includes("spacious")) {
        bedrooms = 4;
      }

      // ========== LUXURY SCORE (1-10) ==========
      let luxuryScore = 5;
      const luxuryMatch = rawText.match(/luxury\s*score[:\s]*(\d+)/i) || rawText.match(/(\d+)\s*(?:out of\s*)?(?:\/\s*)?10/i);
      if (luxuryMatch) {
        luxuryScore = Math.min(10, Math.max(1, parseInt(luxuryMatch[1])));
      } else {
        // Infer from keywords
        const luxuryIndicators = ["granite", "stainless", "hardwood", "high-end", "luxury", "designer", "marble", "quartz", "premium", "upscale", "renovated", "modern"];
        const budgetIndicators = ["laminate", "dated", "old", "basic", "builder-grade", "carpet", "worn", "faded", "outdated"];

        let luxuryPoints = 5;
        luxuryIndicators.forEach(ind => { if (textLower.includes(ind)) luxuryPoints += 1; });
        budgetIndicators.forEach(ind => { if (textLower.includes(ind)) luxuryPoints -= 1; });
        luxuryScore = Math.min(10, Math.max(1, luxuryPoints));
      }

      const unitGrade = calculateGrade(luxuryScore);

      // ========== MONEY FEATURES (Premium Additions) ==========
      const moneyFeatures: MoneyFeature[] = [];
      const moneyFeatureMap: Record<string, number> = {
        "granite": 100, "granite countertop": 100,
        "stainless steel": 75, "stainless appliances": 75,
        "hardwood": 100, "hardwood floor": 100,
        "large window": 75, "bay window": 150, "floor-to-ceiling": 200,
        "high ceiling": 100, "vaulted ceiling": 125,
        "modern fixture": 50, "recessed lighting": 50,
        "exposed brick": 150,
        "updated kitchen": 150, "modern kitchen": 150,
        "walk-in closet": 75,
        "natural light": 75,
        "fireplace": 100,
        "pool": 200,
        "garage": 150,
        "balcony": 100,
        "patio": 75,
        "yard": 100,
        "waterfall island": 175,
        "quartz": 125,
        "marble": 150,
        "smart home": 100,
        "nest": 50,
        "central air": 75
      };

      for (const [feature, value] of Object.entries(moneyFeatureMap)) {
        if (textLower.includes(feature)) {
          moneyFeatures.push({ feature: feature.charAt(0).toUpperCase() + feature.slice(1), value });
        }
      }

      // ========== FLAWS (Things to Fix) ==========
      const flaws: Flaw[] = [];
      const flawMap: Record<string, { fix: string; gain: number }> = {
        "old thermostat": { fix: "Replace with Nest/smart thermostat", gain: 50 },
        "dated lighting": { fix: "Install recessed lighting", gain: 75 },
        "boob light": { fix: "Replace with modern fixtures", gain: 50 },
        "yellow lighting": { fix: "Switch to 5000K daylight bulbs", gain: 25 },
        "popcorn ceiling": { fix: "Remove popcorn texture", gain: 100 },
        "old appliances": { fix: "Upgrade to stainless steel", gain: 100 },
        "carpet stain": { fix: "Deep clean or replace carpet", gain: 75 },
        "worn carpet": { fix: "Replace with LVP flooring", gain: 150 },
        "small window": { fix: "Add mirrors to increase light perception", gain: 25 },
        "dated cabinet": { fix: "Paint cabinets white/gray", gain: 100 },
        "brass fixture": { fix: "Replace with brushed nickel", gain: 50 },
        "laminate counter": { fix: "Upgrade to granite/quartz", gain: 125 },
        "linoleum": { fix: "Replace with tile or LVP", gain: 100 }
      };

      for (const [issue, fixData] of Object.entries(flawMap)) {
        if (textLower.includes(issue)) {
          flaws.push({ issue: issue.charAt(0).toUpperCase() + issue.slice(1), fix: fixData.fix, potentialGain: fixData.gain });
        }
      }

      // ========== STAGING ISSUES (Things to Remove from Photo) ==========
      const stagingIssues: string[] = [];
      const stagingKeywords = ["clutter", "mess", "messy", "trash", "trash can", "toilet seat", "personal item", "dirty", "dishes", "unmade bed", "laundry", "clothes on floor", "toys scattered"];
      for (const keyword of stagingKeywords) {
        if (textLower.includes(keyword)) {
          stagingIssues.push(keyword.charAt(0).toUpperCase() + keyword.slice(1));
        }
      }
      const needsStaging = stagingIssues.length > 0;

      // ========== TARGET DEMOGRAPHIC & VIBE ==========
      let targetDemo = "General Renters";
      let vibeKeywords: string[] = [];

      if (textLower.includes("exposed brick") || textLower.includes("industrial") || textLower.includes("loft")) {
        targetDemo = "Young Professionals / Hipsters";
        vibeKeywords = ["Industrial Chic", "Loft Vibes", "Artisan", "Urban"];
      } else if (textLower.includes("white") && (textLower.includes("neutral") || textLower.includes("beige") || textLower.includes("family"))) {
        targetDemo = "Families";
        vibeKeywords = ["Safe", "Quiet", "Cozy", "Family-Friendly"];
      } else if (textLower.includes("led") || textLower.includes("sleek") || textLower.includes("smart") || textLower.includes("modern")) {
        targetDemo = "Tech Professionals";
        vibeKeywords = ["Modern", "High-Speed Ready", "Smart Home", "Sleek"];
      } else if (textLower.includes("traditional") || textLower.includes("crown molding") || textLower.includes("classic")) {
        targetDemo = "Established Professionals";
        vibeKeywords = ["Classic", "Elegant", "Timeless", "Sophisticated"];
      } else if (luxuryScore >= 7) {
        targetDemo = "High-Income Renters";
        vibeKeywords = ["Premium", "Upscale", "Executive"];
      } else {
        vibeKeywords = ["Comfortable", "Convenient", "Well-Located"];
      }

      // ========== PREDATORY PRICING ==========
      const basePrice = baseRentByType[house_type] || 1800;

      // Calculate money feature bonus
      const featureBonus = moneyFeatures.reduce((sum, f) => sum + f.value, 0);

      // Calculate flaw penalty (but cap it)
      const flawPenalty = Math.min(200, flaws.length * 30);

      // Luxury score bonus: $50 per point above 5
      const luxuryBonus = Math.max(0, (luxuryScore - 5) * 75);

      // Bedroom adjustment
      const bedroomBonus = (bedrooms - 2) * 300;

      // Location multiplier
      const locationMult = getLocationMultiplier(location?.zip);

      // Calculate final price
      let suggestedPrice = (basePrice + featureBonus + luxuryBonus + bedroomBonus - flawPenalty) * locationMult;
      suggestedPrice = Math.round(suggestedPrice / 25) * 25; // Round to nearest $25

      // Premium above average
      const avgPrice = basePrice * locationMult;
      const premiumAboveAvg = suggestedPrice - avgPrice;

      // ========== FOMO LINES ==========
      const fomoLines: string[] = [];
      if (moneyFeatures.some(f => f.feature.toLowerCase().includes("window"))) {
        fomoLines.push("Only unit in the building with premium window views");
      }
      if (luxuryScore >= 7) {
        fomoLines.push("Top 10% finishes in the area - won't last 48 hours");
      }
      if (textLower.includes("renovated") || textLower.includes("updated")) {
        fomoLines.push("Just renovated - first tenant gets it pristine");
      }
      if (moneyFeatures.length >= 3) {
        fomoLines.push(`${moneyFeatures.length} premium upgrades rarely seen at this price point`);
      }
      if (fomoLines.length === 0) {
        fomoLines.push("Priced to move - serious inquiries only");
      }

      // ========== FEATURES LIST ==========
      const features = moneyFeatures.map(f => f.feature).slice(0, 6);
      if (features.length === 0) features.push("See photos for details");

      // ========== DESCRIPTION ==========
      const locationStr = location?.city ? ` in ${location.city}` : "";
      const gradeEmoji = luxuryScore >= 8 ? "Premium" : luxuryScore >= 6 ? "Quality" : "Value";
      const title = `${gradeEmoji} ${bedrooms}-Bedroom ${house_type}${locationStr}`;

      const niceDescription = `${vibeKeywords[0] || "Beautiful"} ${house_type.toLowerCase()} perfect for ${targetDemo.toLowerCase()}. This ${bedrooms}-bedroom property features ${features.slice(0, 3).join(", ").toLowerCase() || "modern amenities"}. ${fomoLines[0]}`;

      // ========== CONFIDENCE ==========
      let confidence = 0.65;
      if (bedroomMatch) confidence += 0.1;
      if (moneyFeatures.length > 2) confidence += 0.1;
      if (luxuryMatch) confidence += 0.1;
      if (location?.city) confidence += 0.05;
      confidence = Math.min(0.95, confidence);

      // ========== BUILD RESPONSE ==========
      const analysis: GodModeAnalysis & { location?: typeof location; rawAnalysis?: string } = {
        title,
        house_type,
        bedrooms,
        description: niceDescription.slice(0, 600),

        // GOD MODE
        luxuryScore,
        unitGrade,
        moneyFeatures: moneyFeatures.slice(0, 5),
        flaws: flaws.slice(0, 5),

        // Pricing
        basePrice: Math.round(basePrice * locationMult),
        suggestedPrice,
        premiumAboveAvg: Math.round(premiumAboveAvg),

        // Demographics
        targetDemo,
        vibeKeywords,

        // FOMO
        fomoLines: fomoLines.slice(0, 3),

        // Staging
        needsStaging,
        stagingIssues,

        // Standard
        features,
        confidence,

        // Include location and raw for debugging
        ...(location && { location }),
        rawAnalysis: rawText.slice(0, 500)
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
