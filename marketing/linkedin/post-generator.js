// LinkedIn Post Generator for RoomFinder AI
// Targeting Landlords with AI-Powered Property Management Benefits

let recentPosts = [];
let currentPost = '';

// Main post generation function
function generatePost() {
    const postType = document.getElementById('postType').value;
    const tone = document.querySelector('input[name="tone"]:checked').value;
    const includeStats = document.getElementById('includeStats').checked;
    const includeEmojis = document.getElementById('includeEmojis').checked;
    const includeCTA = document.getElementById('includeCTA').checked;
    const targetMarket = document.getElementById('targetMarket').value;
    
    // Get appropriate template based on selections
    const template = getTemplate(postType, tone, targetMarket);
    
    // Enhance template with options
    let post = template;
    
    // Add statistics if requested
    if (includeStats) {
        post = addStatistics(post, postType);
    }
    
    // Add emojis if requested
    if (includeEmojis) {
        post = addEmojis(post, postType);
    }
    
    // Add call-to-action if requested
    if (includeCTA) {
        post = addCTA(post, targetMarket);
    }
    
    // Add hashtags
    const hashtags = generateHashtags(postType, targetMarket);
    
    // Update preview
    updatePreview(post, hashtags);
    
    // Save to recent posts
    saveRecentPost(post, postType);
    
    currentPost = post + '\n\n' + hashtags.join(' ');
}

// Get template based on type and tone
function getTemplate(postType, tone, targetMarket) {
    const templates = window.linkedInTemplates || getDefaultTemplates();
    const key = `${postType}_${tone}`;
    
    if (templates[key]) {
        // Randomize if multiple templates exist
        const templateOptions = Array.isArray(templates[key]) ? templates[key] : [templates[key]];
        const selected = templateOptions[Math.floor(Math.random() * templateOptions.length)];
        
        // Customize for target market
        return customizeForMarket(selected, targetMarket);
    }
    
    return getDefaultTemplate(postType, tone);
}

// Default templates fallback
function getDefaultTemplates() {
    return {
        'ai_advantage_professional': `Property management is evolving, and AI is leading the charge.

RoomFinder AI transforms how landlords connect with quality tenants through intelligent automation and smart negotiation capabilities.

Our platform handles tenant inquiries 24/7, screens applicants automatically, and even negotiates terms - all while you focus on growing your portfolio.

The best part? It's completely free for landlords.`,

        'time_saving_professional': `Time is your most valuable asset as a property owner.

What if you could reduce tenant screening from hours to minutes? RoomFinder AI makes it possible.

Our AI-powered platform automates:
• Initial tenant inquiries and responses
• Application screening and verification
• Rental negotiation conversations
• Scheduling and coordination

Reclaim your time. Let AI handle the repetitive tasks.`,

        'roi_focused_professional': `The numbers speak for themselves.

Landlords using RoomFinder AI report:
• 75% reduction in time spent on tenant screening
• 50% faster property filling
• 90% tenant satisfaction rate
• Zero platform costs

Smart property management isn't an expense - it's an investment in efficiency.`,

        'feature_highlight_friendly': `Hey landlords! 

Ever wished you had a 24/7 assistant to handle tenant inquiries?

Meet RoomFinder AI - your intelligent property management partner that never sleeps! 

It chats with potential tenants, answers their questions, schedules viewings, and even helps negotiate terms. All automatically.

And yes, it's FREE for property owners. Because we believe great tools should be accessible to everyone.`,

        'success_story_storytelling': `"I was skeptical about AI in real estate until I tried RoomFinder AI."

Sarah, a landlord with 12 rental units, was spending 20+ hours weekly on tenant communications.

After implementing RoomFinder AI:
• Automated 80% of initial inquiries
• Reduced vacancy periods by 45%
• Improved tenant quality through smart screening

"It's like having a full-time leasing agent, but better and free!"`,

        'industry_insight_professional': `The rental market is changing faster than ever.

Smart landlords are adopting AI not just for efficiency, but for competitive advantage.

RoomFinder AI represents the next evolution in property management:
• Instant response to every inquiry
• Data-driven tenant matching
• Automated negotiation within your parameters
• Complete transparency and control

The future of property management is here, and it's free for forward-thinking landlords.`,

        'educational_friendly': `Quick tip for landlords: 

Did you know that 78% of quality tenants expect immediate responses to rental inquiries?

With RoomFinder AI, every potential tenant gets an instant, personalized response - even at 2 AM!

Our AI doesn't just respond; it qualifies, engages, and nurtures leads until they're ready to commit.

Transform your rental process today. It costs nothing to try!`,

        'announcement_urgent': `EXCITING NEWS for property owners!

RoomFinder AI just launched new features specifically designed for multi-unit landlords:

✓ Bulk listing management
✓ Cross-property tenant matching
✓ Automated rent optimization suggestions
✓ Portfolio-wide analytics dashboard

Still 100% FREE for landlords. No hidden fees. No contracts.

Join thousands of smart property owners already saving time and maximizing returns.`,

        'testimonial_storytelling': `"RoomFinder AI paid for itself in the first week - except it's free!"

Mark manages 8 rental properties and was drowning in inquiries.

His RoomFinder AI results:
Week 1: 47 inquiries handled automatically
Week 2: 3 quality tenants secured
Week 3: 15 hours saved on communications
Week 4: First fully automated lease signed

"I can't imagine managing properties without it now."`,

        'problem_solution_professional': `The Problem: Quality tenants are hard to find and easy to lose to faster-responding landlords.

The Solution: RoomFinder AI ensures you never miss a lead.

How it works:
1. Tenant inquires about your property
2. AI instantly engages and qualifies them
3. Automated screening and verification
4. Smart negotiation within your parameters
5. You approve the final match

Simple. Effective. Free for landlords.`
    };
}

// Get default template if specific combination doesn't exist
function getDefaultTemplate(postType, tone) {
    const defaultTemplates = getDefaultTemplates();
    const key = `${postType}_professional`;
    return defaultTemplates[key] || defaultTemplates['ai_advantage_professional'];
}

// Customize template for specific market
function customizeForMarket(template, market) {
    const marketCustomizations = {
        'residential': template.replace(/landlords?/gi, 'residential property owners'),
        'commercial': template.replace(/landlords?|tenants?/gi, (match) => {
            return match.toLowerCase().includes('landlord') ? 'commercial property owners' : 'businesses';
        }),
        'multi_unit': template.replace(/property|properties/gi, 'portfolio'),
        'new_landlords': 'New to property management? ' + template
    };
    
    return marketCustomizations[market] || template;
}

// Add relevant statistics
function addStatistics(post, postType) {
    const stats = {
        'ai_advantage': '\n\n📊 Data: AI-powered screening reduces bad tenant risk by 67%',
        'time_saving': '\n\n⏱️ Fact: Average landlord saves 15 hours/month with automation',
        'roi_focused': '\n\n💰 ROI: Properties fill 50% faster with AI assistance',
        'feature_highlight': '\n\n🎯 Result: 90% of tenants prefer properties with instant response',
        'success_story': '\n\n📈 Growth: 3,000+ landlords already using RoomFinder AI',
        'industry_insight': '\n\n🔍 Trend: 82% of property managers plan to adopt AI by 2025',
        'educational': '\n\n📚 Study: Properties with AI tools have 30% higher tenant retention',
        'announcement': '\n\n🚀 Milestone: 50,000+ successful tenant matches made',
        'testimonial': '\n\n⭐ Rating: 4.8/5 average landlord satisfaction score',
        'problem_solution': '\n\n✅ Proven: 95% inquiry response rate vs 23% industry average'
    };
    
    return post + (stats[postType] || stats['ai_advantage']);
}

// Add appropriate emojis
function addEmojis(post, postType) {
    const emojiSets = {
        'ai_advantage': ['🤖', '🏠', '✨', '🎯', '💡'],
        'time_saving': ['⏰', '🚀', '⚡', '📱', '✅'],
        'roi_focused': ['💰', '📈', '🎯', '💎', '🏆'],
        'feature_highlight': ['🌟', '🔥', '🎉', '🛡️', '🔧'],
        'success_story': ['🎊', '🌟', '📸', '👏', '🏅'],
        'industry_insight': ['🔮', '📊', '🌐', '🔍', '💭'],
        'educational': ['📖', '💡', '🎓', '📝', '🔑'],
        'announcement': ['📢', '🎉', '🆕', '🔥', '🎊'],
        'testimonial': ['💬', '⭐', '👍', '😊', '🙌'],
        'problem_solution': ['❓', '💡', '✔️', '🎯', '🔓']
    };
    
    const emojis = emojiSets[postType] || emojiSets['ai_advantage'];
    
    // Add leading emoji
    post = emojis[0] + ' ' + post;
    
    // Add inline emojis sparingly
    const lines = post.split('\n');
    if (lines.length > 3) {
        lines[Math.floor(lines.length / 2)] = emojis[1] + ' ' + lines[Math.floor(lines.length / 2)];
    }
    
    return lines.join('\n');
}

// Add call-to-action
function addCTA(post, targetMarket) {
    const ctas = {
        'all': '\n\n👉 Start your FREE account today at roomfinderai.com',
        'residential': '\n\n🏠 Join thousands of residential landlords at roomfinderai.com',
        'commercial': '\n\n🏢 Optimize your commercial properties at roomfinderai.com',
        'multi_unit': '\n\n🏘️ Manage your entire portfolio smarter at roomfinderai.com',
        'new_landlords': '\n\n🚀 Get started with smart property management at roomfinderai.com'
    };
    
    return post + (ctas[targetMarket] || ctas['all']);
}

// Generate relevant hashtags
function generateHashtags(postType, targetMarket) {
    const baseHashtags = ['#RoomFinderAI', '#PropTech', '#PropertyManagement'];
    
    const typeHashtags = {
        'ai_advantage': ['#AIinRealEstate', '#SmartProperty'],
        'time_saving': ['#Automation', '#Efficiency'],
        'roi_focused': ['#RealEstateROI', '#InvestmentProperty'],
        'feature_highlight': ['#Innovation', '#TechForLandlords'],
        'success_story': ['#SuccessStory', '#ClientWin'],
        'industry_insight': ['#RealEstateTrends', '#FutureOfProperty'],
        'educational': ['#PropertyTips', '#LandlordEducation'],
        'announcement': ['#ProductUpdate', '#NewFeatures'],
        'testimonial': ['#CustomerSuccess', '#Testimonial'],
        'problem_solution': ['#Solution', '#PropertySolutions']
    };
    
    const marketHashtags = {
        'residential': ['#ResidentialRentals', '#HomeLandlords'],
        'commercial': ['#CommercialRealEstate', '#CRE'],
        'multi_unit': ['#MultiFamily', '#ApartmentOwners'],
        'new_landlords': ['#NewLandlord', '#FirstTimeInvestor']
    };
    
    let hashtags = [...baseHashtags];
    
    if (typeHashtags[postType]) {
        hashtags.push(...typeHashtags[postType]);
    }
    
    if (marketHashtags[targetMarket]) {
        hashtags.push(...marketHashtags[targetMarket]);
    }
    
    // Add trending hashtags
    const trending = ['#RealEstate2024', '#PropertyTech', '#LandlordLife'];
    hashtags.push(...trending.slice(0, 2));
    
    // Limit to 10 hashtags
    return hashtags.slice(0, 10);
}

// Update the preview
function updatePreview(post, hashtags) {
    const contentEl = document.getElementById('postContent');
    const hashtagEl = document.getElementById('hashtagContainer');
    const charCountEl = document.getElementById('charCount');
    const charBarEl = document.getElementById('charBar');
    
    contentEl.textContent = post;
    
    hashtagEl.innerHTML = hashtags.map(tag => 
        `<span class="text-blue-600 hover:underline cursor-pointer">${tag}</span>`
    ).join(' ');
    
    const totalLength = post.length + hashtags.join(' ').length + 2;
    charCountEl.textContent = `${totalLength} / 3,000`;
    
    const percentage = Math.min((totalLength / 3000) * 100, 100);
    charBarEl.style.width = `${percentage}%`;
    
    if (totalLength > 1300) {
        charBarEl.classList.add('bg-yellow-500');
        charBarEl.classList.remove('bg-blue-600', 'bg-red-500');
    } else if (totalLength > 3000) {
        charBarEl.classList.add('bg-red-500');
        charBarEl.classList.remove('bg-blue-600', 'bg-yellow-500');
    } else {
        charBarEl.classList.add('bg-blue-600');
        charBarEl.classList.remove('bg-yellow-500', 'bg-red-500');
    }
}

// Copy post to clipboard
function copyPost() {
    if (!currentPost) {
        alert('Please generate a post first!');
        return;
    }
    
    navigator.clipboard.writeText(currentPost).then(() => {
        const notification = document.getElementById('copyNotification');
        notification.classList.remove('hidden');
        setTimeout(() => {
            notification.classList.add('hidden');
        }, 3000);
    });
}

// Regenerate with same settings
function regeneratePost() {
    generatePost();
}

// Save to recent posts
function saveRecentPost(post, type) {
    const timestamp = new Date().toLocaleString();
    recentPosts.unshift({ post, type, timestamp });
    
    // Keep only last 10 posts
    if (recentPosts.length > 10) {
        recentPosts = recentPosts.slice(0, 10);
    }
    
    // Update recent posts display
    updateRecentPosts();
}

// Update recent posts display
function updateRecentPosts() {
    const container = document.getElementById('recentPosts');
    if (!container) return;
    
    container.innerHTML = recentPosts.slice(0, 3).map(item => `
        <div class="glass-card p-4 cursor-pointer hover:shadow-lg transition-all" onclick="loadRecentPost('${escape(item.post)}')">
            <div class="text-xs text-gray-500 mb-2">${item.timestamp}</div>
            <div class="text-sm font-medium mb-2 text-blue-600">${item.type.replace(/_/g, ' ').toUpperCase()}</div>
            <div class="text-sm text-gray-700 line-clamp-3">${item.post.substring(0, 150)}...</div>
        </div>
    `).join('');
}

// Load a recent post
function loadRecentPost(escapedPost) {
    const post = unescape(escapedPost);
    const hashtags = generateHashtags('ai_advantage', 'all');
    updatePreview(post, hashtags);
    currentPost = post + '\n\n' + hashtags.join(' ');
}

// Helper function to escape strings
function escape(str) {
    return str.replace(/'/g, "\\'").replace(/"/g, '\\"').replace(/\n/g, '\\n');
}

function unescape(str) {
    return str.replace(/\\'/g, "'").replace(/\\"/g, '"').replace(/\\n/g, '\n');
}

// Add hashtag click functionality
document.addEventListener('DOMContentLoaded', () => {
    // Add click handlers to suggested hashtags
    document.querySelectorAll('.hashtag').forEach(tag => {
        tag.addEventListener('click', function() {
            const hashtag = this.textContent;
            const currentHashtags = document.getElementById('hashtagContainer').textContent;
            if (!currentHashtags.includes(hashtag)) {
                document.getElementById('hashtagContainer').innerHTML += ` <span class="text-blue-600 hover:underline cursor-pointer">${hashtag}</span>`;
            }
        });
    });
    
    // Generate initial post on load
    generatePost();
});