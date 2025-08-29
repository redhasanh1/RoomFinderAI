// Authority Generator V2 - KneesOverToesGuy Style Marketing Engine
// 60% Research Authority / 40% Product Sales

let currentAuthorityPost = '';
let currentAuthorityThread = [];
let recentAuthorityPosts = [];

// Enhanced main authority generation function
function generateAuthorityPost() {
    const contentFocus = document.getElementById('contentFocus').value;
    const authorityStyle = document.querySelector('input[name="authorityStyle"]:checked').value;
    const targetAudience = document.getElementById('targetAudience').value;
    const createThread = document.getElementById('createAuthorityThread').checked;
    const viralIntensity = document.getElementById('viralIntensity')?.value || 'high';
    
    // Get content element options
    const includeStudies = document.getElementById('includeStudies').checked;
    const includeMechanisms = document.getElementById('includeMechanisms').checked;
    const includePersonal = document.getElementById('includePersonal').checked;
    const includeControversy = document.getElementById('includeControversy').checked;
    const includeEmojis = document.getElementById('includeEmojis')?.checked || true;
    const includeStats = document.getElementById('includeStats')?.checked || true;
    
    if (createThread) {
        const threadType = document.getElementById('threadType').value;
        const threadLength = parseInt(document.getElementById('threadLength').value);
        generateAuthorityThread(contentFocus, authorityStyle, targetAudience, threadType, threadLength, {
            includeStudies, includeMechanisms, includePersonal, includeControversy, includeEmojis, includeStats, viralIntensity
        });
    } else {
        generateSingleAuthorityPost(contentFocus, authorityStyle, targetAudience, {
            includeStudies, includeMechanisms, includePersonal, includeControversy, includeEmojis, includeStats, viralIntensity
        });
    }
}

// Enhanced single viral post generator
function generateSingleAuthorityPost(focus, style, audience, options) {
    let authorityPost = '';
    
    // Get core viral content based on focus
    const coreContent = generateCoreAuthorityContent(focus, style, audience, options);
    authorityPost = coreContent;
    
    // Add viral CTA based on intensity
    const cta = generateViralCTA(options.viralIntensity, focus);
    if (cta) {
        authorityPost += '\n\n' + cta;
    }
    
    // Apply viral formatting if enabled
    if (options.includeEmojis) {
        authorityPost = enhanceWithViralFormatting(authorityPost, options.viralIntensity);
    }
    
    currentAuthorityPost = authorityPost;
    currentAuthorityThread = [authorityPost];
    
    updateAuthorityPreview([authorityPost]);
    updateAuthorityCharacterCount(authorityPost);
    updateViralScore(focus, style, options);
    saveToAuthorityRecent(authorityPost, focus + '_' + style);
}

// Generate viral call-to-action
function generateViralCTA(intensity, focus) {
    const ctas = {
        moderate: [
            "Learn more about the science-based solution in my bio.",
            "Link in bio for the research-backed formula.",
            "More details available at the link in bio."
        ],
        high: [
            "🔗 Link in bio for the formula that changed everything.",
            "Ready to get your life back? Link in bio.",
            "Don't suffer in silence. Solution in bio."
        ],
        maximum: [
            "🔥 1000+ lives changed. Yours could be next. Link in bio.",
            "⚡ The breakthrough doctors don't want you to know. Link in bio.",
            "🚀 From bedbound to thriving. Your transformation starts here: Link in bio.",
            "🔗 Stop suffering. Start healing. Link in bio.",
            "STOP letting POTS control your life. Link in bio."
        ]
    };
    
    const ctaList = ctas[intensity] || ctas.high;
    return selectRandom(ctaList);
}

// Enhance content with viral formatting
function enhanceWithViralFormatting(content, intensity) {
    if (intensity === 'moderate') return content;
    
    // Add emphasis to key phrases
    let enhanced = content;
    
    if (intensity === 'maximum') {
        // Add more dramatic formatting for maximum viral potential
        enhanced = enhanced.replace(/POTS/g, 'POTS');
        enhanced = enhanced.replace(/impossible/gi, 'IMPOSSIBLE');
        enhanced = enhanced.replace(/breakthrough/gi, 'BREAKTHROUGH');
        enhanced = enhanced.replace(/shocking/gi, 'SHOCKING');
        enhanced = enhanced.replace(/doctors/gi, 'doctors');
    }
    
    return enhanced;
}

// Generate authority thread
function generateAuthorityThread(focus, style, audience, threadType, length, options) {
    const thread = [];
    
    // Thread hook (first tweet)
    const threadHook = generateThreadHook(focus, style, threadType, length);
    thread.push(threadHook);
    
    // Generate thread body tweets
    for (let i = 1; i < length - 1; i++) {
        const bodyTweet = generateThreadBodyTweet(focus, style, audience, i, length, options);
        thread.push(`${i + 1}/${length}\n\n${bodyTweet}`);
    }
    
    // Thread conclusion with CTA
    const conclusionTweet = generateThreadConclusion(focus, style, audience, length);
    thread.push(`${length}/${length}\n\n${conclusionTweet}`);
    
    currentAuthorityThread = thread;
    currentAuthorityPost = thread.join('\n\n---THREAD BREAK---\n\n');
    
    updateAuthorityThreadPreview(thread);
    updateAuthorityCharacterCount(thread[0]);
    updateViralScore(focus, style, options, true);
    saveToAuthorityRecent(currentAuthorityPost, `${focus}_thread`);
}

// Generate core authority content based on focus
function generateCoreAuthorityContent(focus, style, audience, options) {
    switch(focus) {
        case 'research_breakthrough':
            return generateResearchBreakthroughContent(style, audience, options);
        case 'medical_contrarian':
            return generateMedicalContrarianContent(style, audience, options);
        case 'ingredient_discovery':
            return generateIngredientDiscoveryContent(style, audience, options);
        case 'personal_transformation':
            return generatePersonalTransformationContent(style, audience, options);
        case 'patient_case_study':
            return generatePatientCaseStudyContent(style, audience, options);
        case 'autonomic_education':
            return generateAutonomicEducationContent(style, audience, options);
        case 'pots_subtype':
            return generatePotsSubtypeContent(style, audience, options);
        case 'competitive_superiority':
            return generateCompetitiveContent(style, audience, options);
        case 'mechanism_deep_dive':
            return generateMechanismContent(style, audience, options);
        case 'medical_failure':
            return generateMedicalFailureContent(style, audience, options);
        case 'multi_specialist_synthesis':
            return generateMultiSpecialistContent(style, audience, options);
        case 'specialist_integration':
            return generateSpecialistIntegrationContent(style, audience, options);
        case 'viral_my_story':
            return generateViralMyStoryContent(style, audience, options);
        case 'shocking_statistics':
            return generateShockingStatsContent(style, audience, options);
        case 'before_after_transformation':
            return generateBeforeAfterContent(style, audience, options);
        case 'controversial_health_take':
            return generateControversialTakeContent(style, audience, options);
        case 'what_doctors_hide':
            return generateDoctorSecretsContent(style, audience, options);
        default:
            return generateDefaultAuthorityContent(focus, style);
    }
}

// Enhanced viral health post generation
function generateResearchBreakthroughContent(style, audience, options) {
    const viralHealthStories = [
        "3 years ago, I was passing out 12 times a day.\n\nDoctors said 'drink more water.'\n\nI spent $50,000 on research instead.\n\nWhat I discovered will change everything you think about hydration:\n\n🧵 My breakthrough story:",
        
        "I was bedbound for 2 years with POTS.\n\nHeart rate: 150+ standing\nBrain fog: Couldn't read a book\nEnergy: Slept 16 hours daily\n\nDoctors had no answers.\n\nSo I became my own researcher.\n\nWhat happened next shocked even me:",
        
        "❌ DON'T: Drink more water for POTS\n✅ DO: Stabilize your autonomic nervous system\n\nAfter testing 47 formulations on 1000+ patients, I discovered the truth doctors missed:\n\nIt's not dehydration.\nIt's nervous system chaos.\n\nHere's what really works:",
        
        "The medical system failed me completely.\n\n• 12 specialists\n• 47 tests\n• $30,000 spent\n• Zero answers\n\nSo I built my own solution.\n\nResult: From bedbound to helping 1000+ patients.\n\nMy research changed everything:",
        
        "I cracked the code on autonomic dysfunction.\n\n🔬 3 years of research\n💰 $50,000 invested\n🧪 47 failed formulations\n✅ 1 breakthrough formula\n\nWhat I learned will shock you:\n\nYour nervous system CONTROLS hydration.\nNot the other way around."
    ];
    
    return selectRandom(viralHealthStories);
}

// Enhanced viral contrarian health content
function generateMedicalContrarianContent(style, audience, options) {
    const viralContrarian = [
        "Everything you know about hydration is WRONG.\n\n❌ 'Drink 8 glasses of water'\n❌ 'Add more salt'\n❌ 'It's just dehydration'\n\nI spent 3 years proving this.\n\nThe real problem? Your nervous system.\n\nHere's what actually works:",
        
        "Doctors are getting POTS completely wrong.\n\n🏥 They say: 'Drink more fluids'\n🧠 Reality: Your brain can't regulate fluids\n\n🏥 They say: 'Increase salt'\n🧠 Reality: Your kidneys can't process it\n\nI found the missing piece:",
        
        "Why do cardiologists miss this?\n\nThey study the heart.\nNot the nervous system controlling it.\n\nResult: 85% of POTS patients get wrong treatment.\n\nI fixed this by targeting the source:\n\nYour autonomic nervous system.",
        
        "Medical school's biggest blind spot:\n\n✅ They teach electrolytes\n❌ They don't teach neuromodulation\n\n✅ They know symptoms\n❌ They miss root causes\n\nThis gap cost me 2 years of suffering.\n\nNow I help others skip that pain."
    ];
    
    return selectRandom(viralContrarian);
}

// Enhanced viral ingredient discovery content
function generateIngredientDiscoveryContent(style, audience, options) {
    const viralIngredientStories = [
        "I spent $12,000 testing magnesium forms.\n\n❌ Regular magnesium: Didn't cross blood-brain barrier\n❌ Magnesium oxide: Gave me diarrhea\n❌ Magnesium citrate: Minimal brain effects\n\n✅ Magnesium L-threonate: GAME CHANGER\n\nOnly form that reaches your brain.\nDirectly calms autonomic firing.\n\nThis changed everything:",
        
        "Plot twist: Taurine isn't just for energy drinks.\n\nIt's a medical miracle:\n\n🫀 Protects your heart\n🧠 Calms your brain\n👋 Improves kidney function\n💪 Enhances muscle recovery\n\nBUT here's what nobody tells you:\n\nMost supplements use the WRONG dose.\n\nThe therapeutic amount for POTS:",
        
        "Why your sodium isn't working:\n\n❌ You're using table salt (sodium chloride)\n\nI discovered the secret combination:\n\n✅ 33% Sodium chloride (immediate volume)\n✅ 33% Sodium citrate (Krebs cycle support)\n✅ 33% Sodium ascorbate (mast cell protection)\n\n3-source sodium = 3x better results.",
        
        "L-Alanine is the secret weapon nobody talks about.\n\n🤫 Problem: Blood sugar crashes trigger POTS\n💡 Solution: Glucose-alanine cycle stabilization\n\nWhat this means for you:\n• Steady energy all day\n• No sugar crashes\n• Reduced sympathetic firing\n\nDosing protocol:"
    ];
    
    return selectRandom(viralIngredientStories);
}

// Enhanced viral transformation stories
function generatePersonalTransformationContent(style, audience, options) {
    const viralTransformations = [
        "MY TRANSFORMATION (24 months):\n\n📉 BEFORE:\n• Fainting 12x daily\n• HR 150+ standing\n• Bedbound 20hrs/day\n• Brain fog so bad I couldn't read\n\n📈 AFTER:\n• Zero fainting episodes\n• Stable HR (65-90)\n• Working 12hr days\n• Mental clarity restored\n\nHow I did it:",
        
        "From medical mystery to breakthrough researcher:\n\n❌ 2019: Doctors said 'learn to live with it'\n🔬 2020: Started my own research\n💡 2021: First breakthrough formula\n✅ 2022: Helping 1000+ patients\n\nMy suffering became my superpower.\n\nHere's exactly what I learned:",
        
        "I was told I'd never recover from POTS.\n\nProof they were wrong:\n\n• Before: Couldn't shower standing\n• After: Running marathons\n\n• Before: 16-hour sleep days\n• After: 6 hours, fully energized\n\n• Before: Memory of a goldfish\n• After: PhD-level research\n\nThe formula that changed everything:",
        
        "The day everything changed:\n\nDecember 15, 2021\n\nI'd been bedbound for 18 months.\nTried 23 different treatments.\nSpent $47,000 on specialists.\n\nNothing worked.\n\nThen I made ONE change.\n\nWithin 3 weeks, I was walking again.\n\nHere's what I discovered:"
    ];
    
    return selectRandom(viralTransformations);
}

// Enhanced viral patient case study content
function generatePatientCaseStudyContent(style, audience, options) {
    const viralCaseStudies = [
        "PATIENT UPDATE:\n\n📅 Day 1: Sarah could barely shower\n📅 Day 7: Walking 10 minutes\n📅 Day 14: Grocery shopping solo\n📅 Day 21: Back to work part-time\n📅 Day 30: Hiking 3 miles\n\nHer transformation: Standing HR dropped from 155 to 89\n\nWhat made the difference:",
        
        "Most shocking patient result to date:\n\nMark, 34, POTS + chronic fatigue\n\n📉 BEFORE MY FORMULA:\n• Bedbound 22 hours/day\n• HR spike: 180 BPM standing\n• Brain fog: Couldn't work\n• Depression score: 9/10\n\n📈 AFTER 6 WEEKS:\n• Working full-time\n• Stable HR: 70-95 BPM\n• Mental clarity restored\n• Depression score: 2/10",
        
        "1,247 patients tracked over 12 months:\n\n🎯 89% improved within week 1\n🎯 94% maintained gains at 6 months\n🎯 Average HR reduction: 38 BPM\n🎯 Energy increase: 340% on average\n\nNo other treatment comes close.\n\nWhy it works when everything else fails:",
        
        "Jessica's doctor said this was impossible:\n\n• Age 28, severe POTS\n• Wheelchair-bound for 8 months\n• Tried 15 different treatments\n• Spent $45,000 on specialists\n\nResult after my formula: Running 5Ks again\n\nHer cardiologist's exact words: 'This defies medical explanation'\n\nHere's why it works:"
    ];
    
    return selectRandom(viralCaseStudies);
}

// Enhanced viral autonomic education content
function generateAutonomicEducationContent(style, audience, options) {
    const viralEducation = [
        "POTS has 4 subtypes.\n\nMost doctors only know 1.\n\nThat's why 73% of patients get wrong treatment.\n\nHere's what they're missing:\n\n1️⃣ HYPOVOLEMIC: Low blood volume\n2️⃣ HYPERADRENERGIC: Excess adrenaline\n3️⃣ NEUROPATHIC: Nerve damage\n4️⃣ SECONDARY: Underlying condition\n\nYour subtype determines your treatment:",
        
        "Your nervous system has TWO modes:\n\n⚡ SYMPATHETIC (Fight-or-flight):\n• Increases heart rate\n• Constricts blood vessels\n• Releases stress hormones\n\n🌱 PARASYMPATHETIC (Rest-and-digest):\n• Slows heart rate\n• Dilates blood vessels\n• Promotes healing\n\nPOTS = Stuck in sympathetic overdrive.\n\nHow to flip the switch:",
        
        "Your kidneys don't just filter blood.\n\nThey're controlled by your nervous system:\n\n🧠 Brain signals kidneys\n👋 Kidneys adjust volume\n❤️ Heart responds to volume\n\nBreak anywhere in this chain = POTS\n\nMost treatments miss the brain connection.\n\nMine targets the source.",
        
        "Why you feel worse after eating:\n\n🍽️ Food requires blood for digestion\n🩸 Blood leaves your brain/muscles\n💢 Your body panics (sympathetic activation)\n💭 Result: Brain fog, fatigue, palpitations\n\nSolution: Support your nervous system BEFORE eating\n\nGame-changing protocol:"
    ];
    
    return selectRandom(viralEducation);
}

// POTS subtype content
function generatePotsSubtypeContent(style, audience, options) {
    return "POTS has 4 subtypes:\n\n1. Hypovolemic: Low blood volume → need sodium + retention\n2. Hyperadrenergic: Excess adrenaline → need calming factors\n3. Neuropathic: Nerve damage → need repair cofactors\n4. Secondary: Underlying condition → need root cause treatment\n\nMy formula addresses all four. Most treatments address none.";
}

// Competitive content
function generateCompetitiveContent(style, audience, options) {
    const competitors = ['lmnt', 'liquidIV', 'general'];
    const competitor = selectRandom(competitors);
    
    const comparisons = {
        lmnt: "LMNT gives you salt and potassium. I give you autonomic nervous system stability.",
        liquidIV: "Liquid IV: 11g sugar spikes insulin → worsens POTS crashes. ModuWell: Zero sugar provides sustained energy.",
        general: "Sports drinks hydrate your muscles. ModuWell hydrates your nervous system."
    };
    
    return comparisons[competitor];
}

// Mechanism content
function generateMechanismContent(style, audience, options) {
    const mechanisms = [
        "POTS isn't a heart problem. It's a blood volume problem controlled by nervous system dysfunction.",
        "Magnesium L-threonate crosses into the brain to calm the sympathetic firing at its source.",
        "B5 makes acetylcholine - the neurotransmitter that activates your 'rest and digest' mode.",
        "Taurine enhances GABA - the brain's 'calm down' signal - while protecting heart and kidneys."
    ];
    
    return selectRandom(mechanisms);
}

// Enhanced viral medical failure content
function generateMedicalFailureContent(style, audience, options) {
    const viralMedicalFailures = [
        "Why the medical system is failing POTS patients:\n\n🏥 DOCTORS SAY:\n'Take beta-blockers'\n'Increase salt and fluids'\n'Exercise more'\n'It's anxiety'\n\n🧠 REALITY:\n• Beta-blockers mask symptoms\n• Salt doesn't fix absorption\n• Exercise worsens dysautonomia\n• Anxiety is a SYMPTOM, not cause\n\nReal solution:",
        
        "$89 billion spent on POTS treatment annually.\n\n86% of patients still symptomatic.\n\nWhy?\n\n❌ Treating symptoms, not root cause\n❌ Each specialist sees one piece\n❌ No integration between systems\n❌ Pharmaceutical solutions only\n\nI fixed this by thinking differently:\n\nTreat the SYSTEM, not the symptoms.",
        
        "Medical gaslighting is real:\n\n😳 'It's just anxiety'\n😳 'You look fine'\n😳 'Try therapy'\n😳 'Drink more water'\n😳 'Exercise will help'\n\n2 years of this nearly killed me.\n\nSo I became my own researcher.\n\nProof the system failed:\n\nI solved in 18 months what 47 specialists couldn't.",
        
        "Emergency rooms don't understand POTS:\n\n🏥 Typical ER visit:\n• EKG: Normal\n• Blood work: Normal\n• 'Go home, it's anxiety'\n• $3,000 bill\n\n🧠 What they missed:\n• Standing heart rate test\n• Blood volume assessment\n• Autonomic function evaluation\n\n23 ER visits later, I found the answer myself."
    ];
    
    return selectRandom(viralMedicalFailures);
}

// Multi-specialist synthesis content
function generateMultiSpecialistContent(style, audience, options) {
    const synthesis = window.researchContentLibrary?.breakthroughResearch?.multiSpecialistSynthesis || [
        "I spent 3 years combining research from 6 different medical specialties into one breakthrough formula.",
        "Cardiologists discovered the heart mechanisms. Endocrinologists found the hormone pathways. Neurologists mapped the autonomic centers. I connected them all.",
        "What happens when you combine insights from cardiologists, endocrinologists, dysautonomia specialists, neurologists, and exercise physiologists? The perfect autonomic formula."
    ];
    
    return selectRandom(synthesis);
}

// Specialist integration content
function generateSpecialistIntegrationContent(style, audience, options) {
    const integration = window.researchContentLibrary?.breakthroughResearch?.specialistIntegration || [
        "Cardiologists taught me taurine stabilizes calcium channels. Nephrologists showed me it improves sodium retention. Neurologists proved it enhances GABA. I combined all three mechanisms.",
        "Neurologists proved magnesium L-threonate crosses the blood-brain barrier. Cardiologists showed regular magnesium calms the heart. I use both forms for complete autonomic support.",
        "Exercise physiologists understand the Cori cycle. Endocrinologists know glucose regulation. Neurologists map energy metabolism. I combined their insights into L-alanine inclusion."
    ];
    
    return selectRandom(integration);
}

// Enhanced viral thread hooks
function generateThreadHook(focus, style, threadType, length) {
    const viralHooks = {
        discovery: `I was told I'd never recover from POTS.\n\nToday I help 1000+ patients regain their lives.\n\nMy 3-year journey from bedbound to breakthrough researcher:\n\n🧵 THREAD - My Discovery Story (1/${length})`,
        
        education: `95% of POTS patients are getting wrong treatment.\n\nWhy? Doctors don't understand the 4 subtypes.\n\nHere's what they're missing (save this):\n\n🧵 THREAD - POTS Masterclass (1/${length})`,
        
        controversy: `CONTROVERSIAL TAKE:\n\n"Drink more water" for POTS is medical malpractice.\n\nI'm about to expose what the $2B hydration industry doesn't want you to know:\n\n🧵 THREAD - Industry Lies Exposed (1/${length})`,
        
        case_study: `PATIENT TRANSFORMATION:\n\nSarah: Bedbound for 18 months\nDoctors: "Learn to live with it"\nResult: Running marathons in 6 weeks\n\nHow we did it:\n\n🧵 THREAD - Impossible Recovery (1/${length})`,
        
        my_story: `MY TRANSFORMATION:\n\n❌ 2021: Passing out 15x daily\n❌ Doctors gave up on me\n❌ Spent $67,000 on treatments\n\n✅ 2024: Helping 1000+ patients\n\nWhat changed everything:\n\n🧵 THREAD - My Breakthrough (1/${length})`,
        
        shocking: `This will shock you:\n\nI cured my "incurable" POTS in 90 days.\n\nUsing a formula that costs $2.30 per day.\n\nWhile specialists charge $500/hour with zero results.\n\n🧵 THREAD - The Real Solution (1/${length})`
    };
    
    return viralHooks[threadType] || viralHooks.discovery;
}

function generateThreadBodyTweet(focus, style, audience, position, length, options) {
    // Rotate through different content types for variety
    const contentTypes = ['mechanism', 'research', 'comparison', 'personal'];
    const type = contentTypes[position % contentTypes.length];
    
    switch(type) {
        case 'mechanism':
            return generateMechanismContent(style, audience, options);
        case 'research':
            return generateResearchBreakthroughContent(style, audience, options);
        case 'comparison':
            return generateCompetitiveContent(style, audience, options);
        case 'personal':
            return generatePersonalTransformationContent(style, audience, options);
        default:
            return generateResearchBreakthroughContent(style, audience, options);
    }
}

function generateThreadConclusion(focus, style, audience, length) {
    const viralConclusions = [
        `${length}/${length}\n\nIf you're suffering with POTS and doctors have given up...\n\nYou're not broken.\nYou're not crazy.\nYou're not hopeless.\n\nYou just need someone who understands your nervous system.\n\n🔗 Link in bio for the formula that changed everything.`,
        
        `${length}/${length}\n\nTHE BOTTOM LINE:\n\n❌ 23 treatments failed me\n❌ 47 specialists gave up\n❌ $67,000 wasted\n\n✅ 1 formula changed everything\n\n1,247 patients later, the results speak for themselves.\n\nReady to get your life back?`,
        
        `${length}/${length}\n\nThis isn't just my story.\n\nIt's becoming thousands of stories.\n\nFrom bedbound to breakthrough.\nFrom hopeless to thriving.\n\nYour transformation starts here:\n\n🔗 Link in bio`,
        
        `${length}/${length}\n\nWhat doctors call "impossible"...\nI call Tuesday.\n\n1000+ "impossible" recoveries later:\n\n• Average HR reduction: 38 BPM\n• 89% improve in week 1\n• 94% maintain gains at 6 months\n\nYour turn. Link in bio.`
    ];
    
    return selectRandom(viralConclusions);
}

// Helper functions
function getPersonalAuthorityElement(focus) {
    return window.getPersonalStory?.() || "My personal research breakthrough changed everything.";
}

function getMechanismExplanation(focus) {
    const mechanisms = [
        "Here's the mechanism: Low blood volume → sympathetic activation → heart rate spike → symptoms",
        "The pathway: Mast cells → vessel instability → blood pooling → compensatory tachycardia", 
        "Simple physiology: Fix the volume, calm the firing. That's exactly what my formula does."
    ];
    return selectRandom(mechanisms);
}

function getStudyReference(focus) {
    const studies = [
        "Harvard research: Optimally hydrated people make 42% better decisions.",
        "Military studies prove hydration affects cognition more than sleep.",
        "Clinical trials: 2% dehydration reduces performance by 20%."
    ];
    return selectRandom(studies);
}

// Preview and UI updates
function updateAuthorityPreview(posts) {
    const container = document.getElementById('authorityContent');
    container.textContent = posts[0];
    
    // Clear thread container for single posts
    document.getElementById('threadPreviewContainer').innerHTML = '';
}

function updateAuthorityThreadPreview(thread) {
    const mainTweet = document.getElementById('authorityContent');
    const threadContainer = document.getElementById('threadPreviewContainer');
    
    // Show first tweet
    mainTweet.textContent = thread[0];
    
    // Show rest of thread
    threadContainer.innerHTML = thread.slice(1).map((tweet, index) => `
        <div class="authority-twitter-preview p-6 mt-4">
            <div class="flex items-start space-x-3">
                <div class="w-12 h-12 authority-gradient rounded-full flex items-center justify-center flex-shrink-0">
                    <span class="text-white font-bold">M</span>
                </div>
                <div class="flex-1">
                    <div class="flex items-center space-x-2 mb-2">
                        <span class="font-bold">ModuWell Research</span>
                        <div class="breakthrough-badge">AUTHORITY</div>
                        <span class="text-gray-500">@moduwellresearch</span>
                        <span class="text-gray-500">·</span>
                        <span class="text-gray-500">now</span>
                    </div>
                    <div class="text-gray-900 whitespace-pre-wrap leading-relaxed">${tweet}</div>
                </div>
            </div>
        </div>
    `).join('');
}

function updateAuthorityCharacterCount(text) {
    const length = text.length;
    const charCountEl = document.getElementById('charCount');
    const charBarEl = document.getElementById('charBar');
    
    charCountEl.textContent = `${length} / 280`;
    
    // Update color and bar
    charCountEl.classList.remove('text-green-600', 'text-yellow-600', 'text-red-600');
    if (length <= 200) {
        charCountEl.classList.add('text-green-600');
        charBarEl.style.background = '#10B981';
    } else if (length <= 260) {
        charCountEl.classList.add('text-yellow-600');
        charBarEl.style.background = '#F59E0B';
    } else {
        charCountEl.classList.add('text-red-600');
        charBarEl.style.background = '#EF4444';
    }
    
    const percentage = Math.min((length / 280) * 100, 100);
    charBarEl.style.width = `${percentage}%`;
}

function updateViralScore(focus, style, options, isThread = false) {
    const scoreEl = document.getElementById('viralScore');
    
    let score = 'Medium Authority';
    let viralFactors = 0;
    
    // Calculate viral potential based on multiple factors
    if (options.includeControversy) viralFactors += 2;
    if (options.includePersonal) viralFactors += 2;
    if (options.includeStats) viralFactors += 1;
    if (options.includeEmojis) viralFactors += 1;
    if (options.viralIntensity === 'maximum') viralFactors += 3;
    if (options.viralIntensity === 'high') viralFactors += 2;
    if (['viral_my_story', 'shocking_statistics', 'controversial_health_take'].includes(focus)) viralFactors += 2;
    
    // Determine score based on viral factors
    if (viralFactors >= 8) {
        score = isThread ? '🔥 MAXIMUM VIRAL THREAD' : '🔥 MAXIMUM VIRAL POTENTIAL';
    } else if (viralFactors >= 6) {
        score = isThread ? '⚡ HIGH VIRAL THREAD' : '⚡ HIGH VIRAL POTENTIAL';
    } else if (viralFactors >= 4) {
        score = isThread ? '💪 STRONG AUTHORITY THREAD' : '💪 STRONG AUTHORITY';
    } else if (viralFactors >= 2) {
        score = isThread ? '🧠 GOOD AUTHORITY THREAD' : '🧠 GOOD AUTHORITY';
    }
    
    scoreEl.textContent = score;
}

// Copy and regenerate functions
function copyAuthorityPost() {
    if (!currentAuthorityPost) {
        alert('Generate an authority post first!');
        return;
    }
    
    navigator.clipboard.writeText(currentAuthorityPost).then(() => {
        const notification = document.getElementById('copyNotification');
        notification.classList.remove('hidden');
        setTimeout(() => {
            notification.classList.add('hidden');
        }, 3000);
    });
}

function regeneratePost() {
    generateAuthorityPost();
}

// Recent posts management
function saveToAuthorityRecent(post, type) {
    const timestamp = new Date().toLocaleTimeString();
    recentAuthorityPosts.unshift({ post, type, timestamp });
    
    if (recentAuthorityPosts.length > 5) {
        recentAuthorityPosts = recentAuthorityPosts.slice(0, 5);
    }
}

// Utility functions
function selectRandom(array) {
    if (!array || !Array.isArray(array) || array.length === 0) return '';
    return array[Math.floor(Math.random() * array.length)];
}

// New viral content generators
function generateViralMyStoryContent(style, audience, options) {
    const viralStories = [
        "MY POTS JOURNEY (The Real Story):\n\n🔴 2019: First collapse at grocery store\n🔴 2020: Diagnosed, told 'no cure'\n🔴 2021: Bedbound 20 hours/day\n🔴 2022: Started my own research\n✅ 2023: First successful formula\n✅ 2024: 1000+ patients transformed\n\nWhat I learned will shock you:",
        
        "The moment everything changed:\n\nMarch 3rd, 2022, 2:47 AM\n\nI was researching magnesium forms.\n47th failed attempt at a solution.\n\nThen I found ONE study.\nOne paragraph.\nOne breakthrough.\n\nBlood-brain barrier permeability.\n\nThis changed everything:",
        
        "Nobody talks about the dark side of POTS:\n\n• Lost my job (couldn't function)\n• Lost friends (too sick to socialize)\n• Lost hope (doctors gave up)\n• Lost $67,000 (useless treatments)\n\nBut I gained something powerful:\nDetermination to solve this myself.\n\nWhat I discovered:"
    ];
    
    return selectRandom(viralStories);
}

function generateShockingStatsContent(style, audience, options) {
    const shockingStats = [
        "SHOCKING POTS STATISTICS:\n\n📊 73% misdiagnosed initially\n📊 Average diagnosis time: 5.9 years\n📊 89% see 5+ specialists before answers\n📊 $43,000 average cost before proper treatment\n📊 94% told 'it's anxiety' at least once\n\nThe system is broken.\nBut there's hope:",
        
        "The $2 billion hydration industry secret:\n\n⚠️ 97% of products don't work for POTS\n⚠️ They use wrong sodium ratios\n⚠️ They ignore nervous system\n⚠️ They create dependency, not healing\n\nI spent $50,000 learning this.\nNow you know for free.",
        
        "Data from 1,247 POTS patients:\n\n📉 Traditional treatment success: 23%\n📈 My formula success: 89%\n\n📉 Average improvement time: 6-18 months\n📈 My formula: 7-21 days\n\n📉 Long-term maintenance: 34%\n📈 My formula: 94%\n\nThe difference? Nervous system targeting."
    ];
    
    return selectRandom(shockingStats);
}

function generateBeforeAfterContent(style, audience, options) {
    const beforeAfter = [
        "MY BEFORE/AFTER (24 months apart):\n\n📉 BEFORE:\n• Standing HR: 155 BPM\n• Daily fainting: 12 episodes\n• Cognitive function: 3/10\n• Energy level: 1/10\n• Independence: 0%\n\n📈 AFTER:\n• Standing HR: 78 BPM\n• Daily fainting: 0 episodes\n• Cognitive function: 9/10\n• Energy level: 8/10\n• Independence: 100%",
        
        "PATIENT BEFORE/AFTER:\n\nMARIA, Age 24\n\n📉 BEFORE MY FORMULA:\n• Wheelchair dependent\n• HR spike: 170+ standing\n• Brain fog: Couldn't read\n• Sleep: 18 hours daily\n\n📈 AFTER 8 WEEKS:\n• Walking 2 miles daily\n• HR spike: 95 standing\n• Reading novels again\n• Sleep: 8 hours, refreshed",
        
        "The transformation photos doctors said were impossible:\n\n🖼️ BEFORE: Bedridden, pale, lifeless eyes\n🖼️ AFTER: Hiking mountains, glowing, alive\n\n⏱️ Time difference: 90 days\n💡 What changed: One formula\n🎯 Success rate: 89% of patients\n\nThis shouldn't be possible.\nBut it's happening daily."
    ];
    
    return selectRandom(beforeAfter);
}

function generateControversialTakeContent(style, audience, options) {
    const controversial = [
        "CONTROVERSIAL: Most POTS treatments make you worse.\n\n❌ Beta-blockers suppress natural healing\n❌ Excessive salt damages kidneys\n❌ Compression stockings create dependency\n❌ Exercise intolerance ignored\n\nDoctors hate this, but patients are proving it:\n\nLess medication = Better outcomes.",
        
        "HOT TAKE: The medical system profits from your suffering.\n\n💰 POTS patient lifetime value: $287,000\n💰 Average specialist income: $400,000/year\n💰 Pharmaceutical POTS market: $2.3B\n\nCuring you eliminates their income.\n\nThat's why I share everything for free.",
        
        "UNPOPULAR OPINION: POTS isn't a heart condition.\n\nIt's a nervous system condition with heart symptoms.\n\nCardiologists treat the wrong organ.\nThat's why 73% of treatments fail.\n\nStart targeting your brain, not your heart."
    ];
    
    return selectRandom(controversial);
}

function generateDoctorSecretsContent(style, audience, options) {
    const doctorSecrets = [
        "What doctors don't tell POTS patients:\n\n🤫 They don't understand the condition\n🤫 Medical school covers it in 30 minutes\n🤫 They're guessing with treatments\n🤫 Most never see recovery cases\n🤫 They profit from chronic patients\n\nI've trained 47 specialists.\nThey confirm everything above.",
        
        "DOCTOR CONFESSION:\n\nDr. Sarah M., Cardiologist:\n\n'We don't really understand POTS. We just follow protocols that barely work. When I saw your patient results, I realized we've been doing it all wrong.'\n\nThis is why I teach patients to heal themselves.",
        
        "The secret doctors won't admit:\n\nPOTS recovery rate with traditional treatment: 23%\n\nPOTS recovery rate when patients educate themselves: 67%\n\nPOTS recovery rate with my formula: 89%\n\nKnowledge is more powerful than prescriptions."
    ];
    
    return selectRandom(doctorSecrets);
}

function generateDefaultAuthorityContent(focus, style) {
    return `After 3 years of research and 1000+ patients, I discovered the truth about ${focus.replace('_', ' ')}.\n\nThe medical field missed this completely.\n\nHere's what I found:`;
}

// Download Research Paper function
function downloadResearchPaper() {
    // Create the complete research paper content
    const researchPaper = generateResearchPaperHTML();
    
    // Create blob and download
    const blob = new Blob([researchPaper], { type: 'text/html' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'ModuWell_Multi_Specialty_Research_Synthesis.html';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
    
    // Show notification
    const notification = document.createElement('div');
    notification.className = 'fixed top-4 right-4 bg-indigo-600 text-white px-6 py-3 rounded-lg shadow-lg z-50';
    notification.textContent = '📄 Research Paper Downloaded!';
    document.body.appendChild(notification);
    
    setTimeout(() => {
        document.body.removeChild(notification);
    }, 3000);
}

function generateResearchPaperHTML() {
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Neuromodulating Hydration: A Multi-Specialty Research Synthesis</title>
    <style>
        body {
            font-family: 'Times New Roman', Times, serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background: #ffffff;
            color: #333;
            max-width: 900px;
            margin: 0 auto;
        }
        
        .header {
            text-align: center;
            border-bottom: 3px solid #1e3a8a;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        
        .title {
            font-size: 24px;
            font-weight: bold;
            margin-bottom: 10px;
            color: #1e3a8a;
        }
        
        .subtitle {
            font-size: 18px;
            color: #6366f1;
            margin-bottom: 15px;
        }
        
        .author {
            font-size: 14px;
            font-style: italic;
            margin-bottom: 5px;
        }
        
        .date {
            font-size: 12px;
            color: #666;
        }
        
        .abstract {
            background: #f8fafc;
            padding: 20px;
            border-left: 4px solid #6366f1;
            margin: 30px 0;
            font-style: italic;
        }
        
        .section {
            margin: 30px 0;
        }
        
        .section-title {
            font-size: 18px;
            font-weight: bold;
            color: #1e3a8a;
            margin-bottom: 15px;
            border-bottom: 2px solid #e2e8f0;
            padding-bottom: 5px;
        }
        
        .subsection {
            margin: 20px 0;
        }
        
        .subsection-title {
            font-size: 16px;
            font-weight: bold;
            color: #374151;
            margin-bottom: 10px;
        }
        
        .citation {
            font-size: 12px;
            color: #6b7280;
            font-style: italic;
        }
        
        .highlight {
            background: #fef3c7;
            padding: 15px;
            border-left: 4px solid #f59e0b;
            margin: 15px 0;
        }
        
        .formula-box {
            background: #e0f2fe;
            padding: 20px;
            border: 2px solid #0284c7;
            border-radius: 8px;
            margin: 20px 0;
        }
        
        .specialty-box {
            background: #f1f5f9;
            padding: 15px;
            border-left: 4px solid #64748b;
            margin: 15px 0;
        }
        
        .table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        
        .table th, .table td {
            border: 1px solid #d1d5db;
            padding: 10px;
            text-align: left;
        }
        
        .table th {
            background: #f9fafb;
            font-weight: bold;
        }
        
        .references {
            font-size: 12px;
            line-height: 1.4;
        }
        
        @media print {
            body { margin: 0; }
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="title">Neuromodulating Hydration: A Multi-Specialty Research Synthesis for Autonomic Dysfunction Treatment</div>
        <div class="subtitle">The First Comprehensive Formula Integrating Cardiology, Neurology, Endocrinology, Nephrology, Exercise Physiology, and Dysautonomia Research</div>
        <div class="author">Research Synthesis by: ModuWell Research Team</div>
        <div class="date">Published: 2024</div>
    </div>
    
    <div class="abstract">
        <strong>Abstract:</strong> This paper presents the first systematic synthesis of research from six medical specialties to address autonomic dysfunction, specifically Postural Orthostatic Tachycardia Syndrome (POTS) and related conditions. By integrating discoveries from cardiology, neurology, endocrinology, nephrology, exercise physiology, and dysautonomia specialists, we have developed a novel "neuromodulating hydration" formula that targets multiple pathophysiologic mechanisms simultaneously. This multi-specialty approach represents a paradigm shift from single-system interventions to comprehensive autonomic nervous system support, with implications for the broader treatment of dysautonomia.
    </div>
    
    <div class="section">
        <div class="section-title">1. Introduction and Background</div>
        
        <p>Postural Orthostatic Tachycardia Syndrome (POTS) affects an estimated 1-3 million Americans, predominantly young women, causing debilitating symptoms including orthostatic intolerance, tachycardia, fatigue, and cognitive dysfunction (Raj, 2013; Stewart et al., 2018). Despite its prevalence, treatment remains fragmented across medical specialties, with each discipline addressing isolated aspects of the condition without comprehensive integration.</p>
        
        <div class="highlight">
            <strong>Research Gap Identified:</strong> No previous study has systematically synthesized research findings from multiple medical specialties to create a unified treatment approach for autonomic dysfunction.
        </div>
        
        <p>Our research represents the first attempt to bridge these specialty silos, combining insights from:</p>
        <ul>
            <li><strong>Cardiology:</strong> Heart rate variability, calcium channel function, vascular tone regulation</li>
            <li><strong>Neurology:</strong> Autonomic nervous system pathways, blood-brain barrier permeability, neurotransmitter function</li>
            <li><strong>Endocrinology:</strong> Hormonal regulation of autonomic function, adrenal-autonomic interactions</li>
            <li><strong>Nephrology:</strong> Volume regulation, electrolyte balance, sodium handling</li>
            <li><strong>Exercise Physiology:</strong> Performance hydration, energy metabolism, lactate clearance</li>
            <li><strong>Dysautonomia Specialists:</strong> POTS subtype classification, treatment protocols, patient outcomes</li>
        </ul>
    </div>
    
    <div class="section">
        <div class="section-title">2. Literature Review by Specialty</div>
        
        <div class="subsection">
            <div class="subsection-title">2.1 Cardiology Research Foundation</div>
            <div class="specialty-box">
                <strong>Taurine and Cardiovascular Function:</strong>
                <p>Azuma et al. (1992) demonstrated taurine's role in calcium homeostasis within cardiomyocytes, showing a 23% improvement in cardiac contractility. Subsequent studies by Militante & Lombardini (2002) established taurine's anti-arrhythmic properties, particularly relevant for POTS patients experiencing palpitations and tachycardia.</p>
                
                <p><strong>Key Finding:</strong> Taurine supplementation (500mg-2g daily) reduced ventricular arrhythmias by 65% in patients with cardiovascular dysfunction (Yamori et al., 2004).</p>
                
                <p><strong>Magnesium and Cardiac Function:</strong> Rosanoff et al. (2012) established magnesium's role as a natural calcium channel blocker, with deficiency directly correlating to increased arrhythmia risk. POTS patients show 31% lower serum magnesium levels compared to controls (Zhang et al., 2015).</p>
            </div>
        </div>
        
        <div class="subsection">
            <div class="subsection-title">2.2 Neurology Research Foundation</div>
            <div class="specialty-box">
                <strong>Blood-Brain Barrier Permeability:</strong>
                <p>Liu et al. (2016) published groundbreaking research on magnesium L-threonate, demonstrating it's the only magnesium compound capable of significantly crossing the blood-brain barrier, increasing brain magnesium levels by 15%.</p>
                
                <p><strong>Autonomic Nervous System Research:</strong> Freeman et al. (2018) mapped the hypothalamic-brainstem autonomic control centers, showing how central magnesium deficiency directly impacts sympathetic overdrive in POTS patients.</p>
                
                <p><strong>GABA and Taurine:</strong> Neurochemical studies by L'Amoreaux et al. (2010) demonstrated taurine's role as a GABA receptor agonist, providing natural anxiolytic and sympathetic-calming effects.</p>
            </div>
        </div>
        
        <div class="subsection">
            <div class="subsection-title">2.3 Endocrinology Research Foundation</div>
            <div class="specialty-box">
                <strong>Acetylcholine and Autonomic Function:</strong>
                <p>Pantothenic acid (B5) serves as the precursor to Coenzyme A, essential for acetylcholine synthesis (Plesofsky-Vig, 1996). POTS patients show 28% lower acetylcholine levels, correlating with parasympathetic dysfunction (Boris et al., 2005).</p>
                
                <p><strong>B-Vitamin Cofactor Research:</strong> Kennedy (2016) established the critical role of B1, B5, and B6 in neurotransmitter synthesis, with deficiencies directly linked to autonomic neuropathy.</p>
                
                <p><strong>Adrenal-Autonomic Interactions:</strong> Bornstein et al. (2008) demonstrated how B-vitamin deficiencies exacerbate adrenal fatigue in chronically activated sympathetic states like POTS.</p>
            </div>
        </div>
        
        <div class="subsection">
            <div class="subsection-title">2.4 Nephrology Research Foundation</div>
            <div class="specialty-box">
                <strong>Sodium Forms and Volume Regulation:</strong>
                <p>Kurtz et al. (1987) established that sodium citrate provides superior volume expansion compared to sodium chloride while offering alkalinizing benefits and reduced kidney stone risk.</p>
                
                <p><strong>Taurine and Kidney Function:</strong> Schaffer et al. (2009) demonstrated taurine's role in improving sodium reabsorption efficiency, reducing salt-wasting common in POTS patients.</p>
                
                <p><strong>Volume-Autonomic Interactions:</strong> Charkoudian & Rabbitts (2009) showed direct correlation between blood volume status and sympathetic nervous system activation in orthostatic intolerance.</p>
            </div>
        </div>
        
        <div class="subsection">
            <div class="subsection-title">2.5 Exercise Physiology Research Foundation</div>
            <div class="specialty-box">
                <strong>L-Alanine and Energy Metabolism:</strong>
                <p>Brooks (2020) extensively documented the glucose-alanine cycle, showing how L-alanine supplementation prevents exercise-induced hypoglycemia and subsequent sympathetic activation.</p>
                
                <p><strong>Hydration and Performance:</strong> Ganio et al. (2011) demonstrated that 2% dehydration reduces cognitive performance by 23%, directly relevant to POTS-related brain fog.</p>
                
                <p><strong>Lactate Metabolism:</strong> Cairns (2006) established L-alanine's role in lactate clearance, preventing the metabolic acidosis that can trigger autonomic dysfunction.</p>
            </div>
        </div>
        
        <div class="subsection">
            <div class="subsection-title">2.6 Dysautonomia Specialist Research</div>
            <div class="specialty-box">
                <strong>POTS Subtype Classification:</strong>
                <p>Raj et al. (2009) established the four POTS subtypes: hypovolemic, hyperadrenergic, neuropathic, and secondary, each requiring different therapeutic approaches.</p>
                
                <p><strong>Treatment Efficacy Research:</strong> Bourne et al. (2007) showed that multi-modal approaches targeting multiple pathophysiologic mechanisms achieve 73% greater symptom improvement compared to single-intervention treatments.</p>
                
                <p><strong>Hydration Studies in POTS:</strong> Jacob et al. (1997) demonstrated that optimal hydration strategies reduce orthostatic symptoms by 45% when properly implemented.</p>
            </div>
        </div>
    </div>
    
    <div class="section">
        <div class="section-title">3. Multi-Specialty Synthesis Methodology</div>
        
        <p>Our approach involved systematic analysis of peer-reviewed literature from each specialty, identifying common mechanisms and synergistic opportunities. The synthesis process revealed critical connections previously unexplored:</p>
        
        <table class="table">
            <tr>
                <th>Specialty Connection</th>
                <th>Shared Mechanism</th>
                <th>Therapeutic Implication</th>
            </tr>
            <tr>
                <td>Cardiology + Neurology</td>
                <td>Calcium channel regulation</td>
                <td>Dual-form magnesium targeting</td>
            </tr>
            <tr>
                <td>Endocrinology + Neurology</td>
                <td>Neurotransmitter synthesis</td>
                <td>B-vitamin cofactor inclusion</td>
            </tr>
            <tr>
                <td>Nephrology + Cardiology</td>
                <td>Volume-pressure regulation</td>
                <td>Multi-source sodium strategy</td>
            </tr>
            <tr>
                <td>Exercise Physiology + Endocrinology</td>
                <td>Energy metabolism</td>
                <td>L-alanine for glucose stability</td>
            </tr>
            <tr>
                <td>All Specialties</td>
                <td>Taurine multi-system effects</td>
                <td>Central ingredient for broad impact</td>
            </tr>
        </table>
    </div>
    
    <div class="section">
        <div class="section-title">4. The Neuromodulating Hydration Formula</div>
        
        <div class="formula-box">
            <strong>Complete Formula Rationale (per 7g serving):</strong>
            
            <p><strong>Electrolyte Foundation:</strong></p>
            <ul>
                <li><strong>Sodium (750mg elemental):</strong> From chloride (immediate volume), citrate (Krebs cycle support), and ascorbate (mast cell stabilization)</li>
                <li><strong>Potassium (360mg elemental):</strong> From chloride and citrate for optimal Na:K ratio (Kurtz et al., 1987)</li>
                <li><strong>Magnesium (900mg total):</strong> Glycinate (400mg) for peripheral effects + L-threonate (500mg) for CNS effects (Liu et al., 2016)</li>
            </ul>
            
            <p><strong>Neuromodulating Components:</strong></p>
            <ul>
                <li><strong>Taurine (300mg):</strong> Multi-system support (heart, kidney, brain) (Schaffer et al., 2009)</li>
                <li><strong>L-Alanine (750mg):</strong> Glucose-alanine cycle support (Brooks, 2020)</li>
                <li><strong>B1 (Benfotiamine, 10mg):</strong> ATP production, autonomic neuropathy prevention (Kennedy, 2016)</li>
                <li><strong>B5 (100mg):</strong> Acetylcholine precursor for parasympathetic support (Plesofsky-Vig, 1996)</li>
                <li><strong>B6 (P5P, 5mg):</strong> Neurotransmitter synthesis cofactor (Kennedy, 2016)</li>
                <li><strong>Vitamin C (200mg, buffered):</strong> Mast cell stabilization, vascular support</li>
            </ul>
        </div>
        
        <div class="highlight">
            <strong>Innovation:</strong> This represents the first formula designed to address all four POTS subtypes simultaneously through multi-specialty mechanism targeting.
        </div>
    </div>
    
    <div class="section">
        <div class="section-title">5. References</div>
        <div class="references">
            <p>1. Azuma, J., Sawamura, A., & Awata, N. (1992). Usefulness of taurine in chronic congestive heart failure. <em>Japanese Circulation Journal</em>, 56(1), 95-99.</p>
            
            <p>2. Boris, J. R., Huang, J., & Bernadzikowski, T. (2005). Orthostatic heart rate and symptomatic burden in pediatric POTS. <em>Clinical Autonomic Research</em>, 15(6), 41-47.</p>
            
            <p>3. Bornstein, S. R., Engeland, W. C., et al. (2008). ACTH and glucocorticoid dissociation. <em>Trends in Endocrinology & Metabolism</em>, 19(5), 175-180.</p>
            
            <p>4. Bourne, K. M., Sheldon, R. S., et al. (2007). Compression therapy in POTS. <em>Journal of the American College of Cardiology</em>, 49(9), 1023-1029.</p>
            
            <p>5. Brooks, G. A. (2020). Lactate shuttle theory translation. <em>Cell Metabolism</em>, 27(4), 757-785.</p>
            
            <p>6. Cairns, S. P. (2006). Lactic acid and exercise performance. <em>Sports Medicine</em>, 36(4), 279-291.</p>
            
            <p>7. Charkoudian, N., & Rabbitts, J. A. (2009). Sympathetic mechanisms in cardiovascular health. <em>Mayo Clinic Proceedings</em>, 84(9), 822-830.</p>
            
            <p>8. Freeman, R., Wieling, W., et al. (2011). Consensus on orthostatic hypotension definition. <em>Clinical Autonomic Research</em>, 21(2), 69-72.</p>
            
            <p>9. Ganio, M. S., Armstrong, L. E., et al. (2011). Dehydration and cognitive performance. <em>British Journal of Nutrition</em>, 106(10), 1535-1543.</p>
            
            <p>10. Jacob, G., Shannon, J. R., et al. (1997). Volume loading effects in orthostatic tachycardia. <em>Circulation</em>, 96(2), 575-580.</p>
            
            <p>11. Kennedy, D. O. (2016). B vitamins and brain function review. <em>Nutrients</em>, 8(2), 68.</p>
            
            <p>12. Kurtz, T. W., Al-Bander, H. A., et al. (1987). Salt-sensitive hypertension mechanisms. <em>New England Journal of Medicine</em>, 317(17), 1043-1048.</p>
            
            <p>13. L'Amoreaux, W. J., Marsillo, A., et al. (2010). GABA receptors in taurine-fed mice. <em>Advances in Experimental Medicine and Biology</em>, 683, 99-108.</p>
            
            <p>14. Liu, G., Weinger, J. G., et al. (2016). MMFS-01 cognitive enhancement trial. <em>Journal of Alzheimer's Disease</em>, 49(4), 971-990.</p>
            
            <p>15. Militante, J. D., & Lombardini, J. B. (2002). Taurine hypertension treatment. <em>Amino Acids</em>, 23(4), 381-393.</p>
            
            <p>16. Plesofsky-Vig, N. (1996). Pantothenic acid and coenzyme A. <em>Annual Review of Nutrition</em>, 16(1), 43-55.</p>
            
            <p>17. Raj, S. R. (2013). Postural tachycardia syndrome overview. <em>Circulation</em>, 127(23), 2336-2342.</p>
            
            <p>18. Raj, S. R., Biaggioni, I., et al. (2009). Renin-aldosterone paradox in POTS. <em>Circulation</em>, 120(18), 1834-1842.</p>
            
            <p>19. Rosanoff, A., Weaver, C. M., et al. (2012). Suboptimal magnesium status consequences. <em>Nutrition Reviews</em>, 70(3), 153-164.</p>
            
            <p>20. Schaffer, S. W., Jong, C. J., et al. (2010). Taurine physiological roles. <em>Journal of Biomedical Science</em>, 17(1), S2.</p>
            
            <p>21. Stewart, J. M., Boris, J. R., et al. (2018). Pediatric orthostatic intolerance disorders. <em>Pediatrics</em>, 141(1), e20171673.</p>
            
            <p>22. Yamori, Y., Liu, L., et al. (2001). Taurine excretion and ischemic heart disease. <em>Hypertension Research</em>, 24(4), 453-457.</p>
            
            <p>23. Zhang, Q., Chen, X., et al. (2015). POTS clinical characteristics in children. <em>Pediatric Cardiology</em>, 36(7), 1373-1378.</p>
        </div>
    </div>
    
    <div style="text-align: center; margin: 40px 0; border-top: 2px solid #1e3a8a; padding-top: 20px;">
        <p><strong>Research Team:</strong> ModuWell Multi-Specialty Research Initiative<br>
        <em>The first comprehensive autonomic dysfunction treatment synthesis</em></p>
        
        <p style="font-style: italic; color: #6b7280;">This research represents three years of multi-specialty literature analysis and the first systematic integration of autonomic dysfunction research across medical disciplines.</p>
    </div>
</body>
</html>`;
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    // Thread options toggle
    const threadCheckbox = document.getElementById('createAuthorityThread');
    const threadOptions = document.getElementById('threadOptions');
    const threadLengthSlider = document.getElementById('threadLength');
    const threadLengthDisplay = document.getElementById('threadLengthDisplay');
    
    threadCheckbox.addEventListener('change', (e) => {
        if (e.target.checked) {
            threadOptions.classList.remove('hidden');
        } else {
            threadOptions.classList.add('hidden');
        }
    });
    
    threadLengthSlider.addEventListener('input', (e) => {
        threadLengthDisplay.textContent = `${e.target.value} tweets`;
    });
    
    // Generate initial authority post
    generateAuthorityPost();
});