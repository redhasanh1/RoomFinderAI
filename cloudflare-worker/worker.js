export default {
  async fetch(request, env) {
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
      var body = await request.json();
      var image = body.image;
      var location = body.location;

      if (!Array.isArray(image)) {
        return new Response(JSON.stringify({ success: false, error: "Invalid image" }), {
          status: 400,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
        });
      }

      var prompt = "You are a ruthless real estate appraiser. Analyze this property photo. PROPERTY TYPE: House, Apartment, Condo, or Townhouse? BEDROOMS: Estimate 1-10. LUXURY SCORE 1-10: Rate the finishes. MONEY FEATURES: List premium features like granite, stainless steel, hardwood, high ceilings, exposed brick, fireplace, pool, garage, balcony, yard. FLAWS: List issues like old thermostat, dated lighting, popcorn ceiling, old appliances, worn carpet. STAGING ISSUES: List any mess or clutter. VIBE: What demographic would love this? LOCATION ESTIMATE: Based on architectural style, vegetation, weather, building materials, and design - estimate the most likely US city and state. Consider: Spanish/Mediterranean style = California/Florida/Arizona. Brownstone = NYC/Boston. Modern glass = Seattle/SF. Brick colonial = Northeast. Ranch style = Texas/Midwest. Give your best guess city and state. Be detailed.";

      var result = await env.AI.run("@cf/meta/llama-3.2-11b-vision-instruct", {
        image: image,
        prompt: prompt,
        max_tokens: 800
      });

      var text = result.description || result.response || "";
      if (!text) throw new Error("Empty response");

      var lower = text.toLowerCase();

      var house_type = "Apartment";
      if (lower.includes("house") || lower.includes("garage") || lower.includes("yard") || lower.includes("driveway")) {
        house_type = "House";
      } else if (lower.includes("condo")) {
        house_type = "Condo";
      } else if (lower.includes("townhouse")) {
        house_type = "Townhouse";
      }

      var bedrooms = 2;
      var bedMatch = text.match(/(\d+)\s*(bed|bedroom|br)/i);
      if (bedMatch) bedrooms = Math.min(10, Math.max(1, parseInt(bedMatch[1])));

      var luxuryScore = 5;
      var luxuryWords = ["granite", "stainless", "hardwood", "luxury", "marble", "quartz", "modern", "renovated", "updated", "new"];
      var budgetWords = ["laminate", "dated", "old", "basic", "worn", "outdated", "cheap"];
      for (var i = 0; i < luxuryWords.length; i++) {
        if (lower.includes(luxuryWords[i])) luxuryScore++;
      }
      for (var j = 0; j < budgetWords.length; j++) {
        if (lower.includes(budgetWords[j])) luxuryScore--;
      }
      luxuryScore = Math.min(10, Math.max(1, luxuryScore));

      var unitGrade = "B";
      if (luxuryScore >= 9) unitGrade = "A+";
      else if (luxuryScore >= 8) unitGrade = "A";
      else if (luxuryScore >= 7) unitGrade = "A-";
      else if (luxuryScore >= 6) unitGrade = "B+";
      else if (luxuryScore >= 5) unitGrade = "B";
      else if (luxuryScore >= 4) unitGrade = "B-";
      else if (luxuryScore >= 3) unitGrade = "C+";
      else unitGrade = "C";

      var moneyFeatures = [];
      var featureList = [
        { name: "granite", value: 100 },
        { name: "stainless", value: 75 },
        { name: "hardwood", value: 100 },
        { name: "high ceiling", value: 100 },
        { name: "exposed brick", value: 150 },
        { name: "modern kitchen", value: 150 },
        { name: "fireplace", value: 100 },
        { name: "pool", value: 200 },
        { name: "garage", value: 150 },
        { name: "balcony", value: 100 },
        { name: "patio", value: 75 },
        { name: "yard", value: 100 },
        { name: "natural light", value: 75 }
      ];
      for (var k = 0; k < featureList.length; k++) {
        if (lower.includes(featureList[k].name)) {
          moneyFeatures.push({
            feature: featureList[k].name.charAt(0).toUpperCase() + featureList[k].name.slice(1),
            value: featureList[k].value
          });
        }
      }

      var flaws = [];
      var flawList = [
        { name: "old thermostat", fix: "Replace with Nest", gain: 50 },
        { name: "dated lighting", fix: "Install recessed lighting", gain: 75 },
        { name: "popcorn ceiling", fix: "Remove popcorn texture", gain: 100 },
        { name: "old appliances", fix: "Upgrade to stainless", gain: 100 },
        { name: "worn carpet", fix: "Replace with LVP", gain: 150 }
      ];
      for (var m = 0; m < flawList.length; m++) {
        if (lower.includes(flawList[m].name)) {
          flaws.push({
            issue: flawList[m].name.charAt(0).toUpperCase() + flawList[m].name.slice(1),
            fix: flawList[m].fix,
            potentialGain: flawList[m].gain
          });
        }
      }

      var stagingIssues = [];
      var stagingWords = ["clutter", "mess", "dirty", "trash", "laundry", "dishes", "unmade bed"];
      for (var n = 0; n < stagingWords.length; n++) {
        if (lower.includes(stagingWords[n])) {
          stagingIssues.push(stagingWords[n].charAt(0).toUpperCase() + stagingWords[n].slice(1));
        }
      }
      var needsStaging = stagingIssues.length > 0;

      var targetDemo = "General Renters";
      var vibeKeywords = ["Comfortable", "Convenient"];
      if (lower.includes("exposed brick") || lower.includes("industrial") || lower.includes("loft")) {
        targetDemo = "Young Professionals";
        vibeKeywords = ["Industrial Chic", "Urban", "Artisan"];
      } else if (lower.includes("modern") || lower.includes("sleek") || lower.includes("smart")) {
        targetDemo = "Tech Professionals";
        vibeKeywords = ["Modern", "Sleek", "High-Speed Ready"];
      } else if (lower.includes("family") || lower.includes("cozy") || lower.includes("safe")) {
        targetDemo = "Families";
        vibeKeywords = ["Safe", "Cozy", "Family-Friendly"];
      }

      // === LOCATION ESTIMATION (AI guess if no EXIF) ===
      var estimatedLocation = null;
      var cityZipMap = {
        "new york": { city: "New York", state: "NY", zip: "10001", country: "USA" },
        "nyc": { city: "New York", state: "NY", zip: "10001", country: "USA" },
        "manhattan": { city: "New York", state: "NY", zip: "10001", country: "USA" },
        "brooklyn": { city: "Brooklyn", state: "NY", zip: "11201", country: "USA" },
        "los angeles": { city: "Los Angeles", state: "CA", zip: "90001", country: "USA" },
        "la": { city: "Los Angeles", state: "CA", zip: "90001", country: "USA" },
        "san francisco": { city: "San Francisco", state: "CA", zip: "94102", country: "USA" },
        "sf": { city: "San Francisco", state: "CA", zip: "94102", country: "USA" },
        "seattle": { city: "Seattle", state: "WA", zip: "98101", country: "USA" },
        "boston": { city: "Boston", state: "MA", zip: "02101", country: "USA" },
        "miami": { city: "Miami", state: "FL", zip: "33101", country: "USA" },
        "austin": { city: "Austin", state: "TX", zip: "78701", country: "USA" },
        "denver": { city: "Denver", state: "CO", zip: "80201", country: "USA" },
        "chicago": { city: "Chicago", state: "IL", zip: "60601", country: "USA" },
        "phoenix": { city: "Phoenix", state: "AZ", zip: "85001", country: "USA" },
        "portland": { city: "Portland", state: "OR", zip: "97201", country: "USA" },
        "san diego": { city: "San Diego", state: "CA", zip: "92101", country: "USA" },
        "dallas": { city: "Dallas", state: "TX", zip: "75201", country: "USA" },
        "houston": { city: "Houston", state: "TX", zip: "77001", country: "USA" },
        "atlanta": { city: "Atlanta", state: "GA", zip: "30301", country: "USA" },
        "philadelphia": { city: "Philadelphia", state: "PA", zip: "19101", country: "USA" },
        "washington": { city: "Washington", state: "DC", zip: "20001", country: "USA" },
        "dc": { city: "Washington", state: "DC", zip: "20001", country: "USA" },
        "california": { city: "Los Angeles", state: "CA", zip: "90001", country: "USA" },
        "texas": { city: "Austin", state: "TX", zip: "78701", country: "USA" },
        "florida": { city: "Miami", state: "FL", zip: "33101", country: "USA" },
        "arizona": { city: "Phoenix", state: "AZ", zip: "85001", country: "USA" }
      };

      // Check if AI mentioned a city/state
      for (var cityKey in cityZipMap) {
        if (lower.includes(cityKey)) {
          estimatedLocation = cityZipMap[cityKey];
          estimatedLocation.source = "ai_estimate";
          break;
        }
      }

      // Fallback: guess based on architectural style if no city mentioned
      if (!estimatedLocation) {
        if (lower.includes("spanish") || lower.includes("mediterranean") || lower.includes("stucco") || lower.includes("palm")) {
          estimatedLocation = { city: "Los Angeles", state: "CA", zip: "90001", country: "USA", source: "ai_estimate" };
        } else if (lower.includes("brownstone") || lower.includes("row house")) {
          estimatedLocation = { city: "New York", state: "NY", zip: "10001", country: "USA", source: "ai_estimate" };
        } else if (lower.includes("victorian") || lower.includes("painted ladies")) {
          estimatedLocation = { city: "San Francisco", state: "CA", zip: "94102", country: "USA", source: "ai_estimate" };
        } else if (lower.includes("colonial") || lower.includes("brick")) {
          estimatedLocation = { city: "Boston", state: "MA", zip: "02101", country: "USA", source: "ai_estimate" };
        } else if (lower.includes("modern") || lower.includes("glass") || lower.includes("contemporary")) {
          estimatedLocation = { city: "Seattle", state: "WA", zip: "98101", country: "USA", source: "ai_estimate" };
        } else if (lower.includes("ranch") || lower.includes("suburban")) {
          estimatedLocation = { city: "Dallas", state: "TX", zip: "75201", country: "USA", source: "ai_estimate" };
        } else {
          // Default fallback
          estimatedLocation = { city: "Chicago", state: "IL", zip: "60601", country: "USA", source: "ai_estimate" };
        }
      }

      // Use EXIF location if provided, otherwise use AI estimate
      var finalLocation = (location && location.city) ? location : estimatedLocation;
      if (location && location.city) {
        finalLocation.source = "gps";
      }

      var baseRents = { "Apartment": 1600, "Condo": 1900, "Townhouse": 2100, "House": 2400 };
      var basePrice = baseRents[house_type] || 1800;

      var zipMult = { "941": 2.5, "940": 2.3, "100": 2.8, "101": 2.6, "900": 2.2, "981": 2.0, "021": 2.1, "331": 1.8, "787": 1.7, "802": 1.6, "606": 1.5, "850": 1.3, "972": 1.4, "921": 1.6, "752": 1.4, "770": 1.3, "303": 1.5, "191": 1.6, "200": 1.8 };
      var zipPrefix = "";
      if (finalLocation && finalLocation.zip) zipPrefix = finalLocation.zip.substring(0, 3);
      var locationMult = zipMult[zipPrefix] || 1.0;

      var featureBonus = 0;
      for (var p = 0; p < moneyFeatures.length; p++) {
        featureBonus += moneyFeatures[p].value;
      }
      var luxuryBonus = Math.max(0, (luxuryScore - 5) * 75);
      var bedroomBonus = (bedrooms - 2) * 300;

      var suggestedPrice = (basePrice + featureBonus + luxuryBonus + bedroomBonus) * locationMult;
      suggestedPrice = Math.round(suggestedPrice / 25) * 25;

      var avgPrice = basePrice * locationMult;
      var premiumAboveAvg = Math.round(suggestedPrice - avgPrice);

      var fomoLines = [];
      if (luxuryScore >= 7) {
        fomoLines.push("Top 10% finishes in the area - won't last 48 hours");
      } else {
        fomoLines.push("Priced to move - serious inquiries only");
      }
      if (lower.includes("renovated") || lower.includes("updated")) {
        fomoLines.push("Just renovated - first tenant gets it pristine");
      }

      var label = "Value";
      if (luxuryScore >= 8) label = "Premium";
      else if (luxuryScore >= 6) label = "Quality";

      var featureNames = [];
      for (var q = 0; q < moneyFeatures.length && q < 3; q++) {
        featureNames.push(moneyFeatures[q].feature.toLowerCase());
      }
      var featureText = featureNames.length > 0 ? featureNames.join(", ") : "modern amenities";

      var locStr = "";
      if (finalLocation && finalLocation.city) locStr = " in " + finalLocation.city;

      var title = label + " " + bedrooms + "-Bedroom " + house_type + locStr;
      var description = vibeKeywords[0] + " " + house_type.toLowerCase() + " perfect for " + targetDemo.toLowerCase() + ". This " + bedrooms + "-bedroom property features " + featureText + ". " + fomoLines[0];

      var confidence = 0.65 + (moneyFeatures.length * 0.05) + (luxuryScore > 5 ? 0.1 : 0);
      if (confidence > 0.95) confidence = 0.95;

      var allFeatures = [];
      for (var r = 0; r < moneyFeatures.length && r < 6; r++) {
        allFeatures.push(moneyFeatures[r].feature);
      }

      var analysis = {
        title: title,
        house_type: house_type,
        bedrooms: bedrooms,
        description: description,
        luxuryScore: luxuryScore,
        unitGrade: unitGrade,
        moneyFeatures: moneyFeatures.slice(0, 5),
        flaws: flaws.slice(0, 5),
        basePrice: Math.round(avgPrice),
        suggestedPrice: suggestedPrice,
        premiumAboveAvg: premiumAboveAvg,
        targetDemo: targetDemo,
        vibeKeywords: vibeKeywords,
        fomoLines: fomoLines,
        features: allFeatures,
        confidence: confidence,
        needsStaging: needsStaging,
        stagingIssues: stagingIssues,
        location: finalLocation
      };

      return new Response(JSON.stringify({ success: true, analysis: analysis }), {
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });

    } catch (err) {
      return new Response(JSON.stringify({ success: false, error: err.message || "Failed" }), {
        status: 500,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    }
  }
};
