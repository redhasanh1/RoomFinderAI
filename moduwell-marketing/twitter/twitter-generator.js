// Twitter/X Post Generator for Moduwell Hydration
// Viral content generation following @exm7777 style

let currentPost = '';
let currentThread = [];
let recentPosts = [];

// Main generation function
function generatePost() {
    const postStyle = document.getElementById('postStyle').value;
    const hookType = document.querySelector('input[name="hook"]:checked').value;
    const audience = document.getElementById('audience').value;
    const createThread = document.getElementById('createThread').checked;
    
    if (createThread) {
        const threadLength = parseInt(document.getElementById('threadLength').value);
        generateThread(postStyle, hookType, audience, threadLength);
    } else {
        generateSinglePost(postStyle, hookType, audience);
    }
}

// Generate single tweet
function generateSinglePost(style, hook, audience) {
    const template = getTemplate(style, hook, audience);
    const enhancedPost = enhanceWithContent(template, audience);
    
    currentPost = enhancedPost;
    currentThread = [enhancedPost];
    
    updatePreview([enhancedPost]);
    updateCharacterCount(enhancedPost);
    updateEngagementScore(style, hook);
    saveToRecent(enhancedPost, style);
}

// Generate thread
function generateThread(style, hook, audience, length) {
    const thread = [];
    
    // Generate hook tweet
    const hookTweet = getHookTweet(style, hook, audience);
    thread.push(hookTweet);
    
    // Generate body tweets
    for (let i = 1; i < length - 1; i++) {
        const bodyTweet = getBodyTweet(style, audience, i, length);
        thread.push(bodyTweet);
    }
    
    // Generate CTA tweet
    const ctaTweet = getCTATweet(audience);
    thread.push(ctaTweet);
    
    // Add thread numbering
    const numberedThread = thread.map((tweet, index) => {
        if (index === 0) {
            return tweet + `\n\n🧵 Thread (1/${length})`;
        }
        return `${index + 1}/${length}\n\n` + tweet;
    });
    
    currentThread = numberedThread;
    currentPost = numberedThread.join('\n\n---\n\n');
    
    updateThreadPreview(numberedThread);
    updateCharacterCount(numberedThread[0]);
    updateEngagementScore(style, hook);
    saveToRecent(currentPost, `${style}_thread`);
}

// Get template based on style
function getTemplate(style, hook, audience) {
    const templates = window.twitterTemplates || {};
    const key = `${style}_${hook}_${audience}`;
    
    // Try exact match first
    if (templates[key]) {
        return selectRandom(templates[key]);
    }
    
    // Try style + hook
    const styleHookKey = `${style}_${hook}`;
    if (templates[styleHookKey]) {
        return selectRandom(templates[styleHookKey]);
    }
    
    // Try just style
    if (templates[style]) {
        return selectRandom(templates[style]);
    }
    
    // Fallback
    return getDefaultTemplate(style, hook);
}

// Get hook tweet for thread
function getHookTweet(style, hook, audience) {
    const hooks = window.moduwellContent?.hooks || {};
    const audienceHooks = hooks[audience] || hooks.general;
    
    if (hook === 'shocking') {
        return selectRandom(audienceHooks.shocking);
    } else if (hook === 'question') {
        return selectRandom(audienceHooks.questions);
    } else if (hook === 'statistic') {
        return selectRandom(audienceHooks.statistics);
    } else {
        return selectRandom(audienceHooks.personal);
    }
}

// Get body tweet for thread
function getBodyTweet(style, audience, position, totalLength) {
    const content = window.moduwellContent || {};
    const benefits = content.benefits?.[audience] || content.benefits?.general;
    
    // Mix different content types
    const contentTypes = ['benefit', 'science', 'comparison', 'tip'];
    const type = contentTypes[position % contentTypes.length];
    
    switch(type) {
        case 'benefit':
            return formatBenefit(selectRandom(benefits));
        case 'science':
            return formatScience(selectRandom(content.science || []));
        case 'comparison':
            return formatComparison(selectRandom(content.comparisons || []));
        case 'tip':
            return formatTip(selectRandom(content.tips || []));
        default:
            return selectRandom(benefits);
    }
}

// Get CTA tweet
function getCTATweet(audience) {
    const ctas = window.moduwellContent?.ctas || {};
    const audienceCTAs = ctas[audience] || ctas.general;
    return selectRandom(audienceCTAs);
}

// Format content types
function formatBenefit(benefit) {
    const formats = [
        `Here's what happens: ${benefit}`,
        `The result? ${benefit}`,
        `Benefit #1: ${benefit}`,
        `Why this matters: ${benefit}`,
        `${benefit}\n\n(This is game-changing)`
    ];
    return selectRandom(formats);
}

function formatScience(science) {
    return `Science fact:\n\n${science}\n\nBacked by research.`;
}

function formatComparison(comparison) {
    return `Before Moduwell: ${comparison.before}\n\nAfter Moduwell: ${comparison.after}\n\nThe difference is real.`;
}

function formatTip(tip) {
    return `Pro tip: ${tip}\n\nYour performance will thank you.`;
}

// Enhance post with dynamic content
function enhanceWithContent(template, audience) {
    const content = window.moduwellContent || {};
    
    // Replace placeholders
    let enhanced = template;
    
    // Add relevant stats
    enhanced = enhanced.replace(/{{STAT}}/g, () => {
        const stats = content.statistics || [];
        return selectRandom(stats);
    });
    
    // Add ingredients
    enhanced = enhanced.replace(/{{INGREDIENT}}/g, () => {
        const ingredients = content.ingredients || [];
        return selectRandom(ingredients);
    });
    
    // Add benefits
    enhanced = enhanced.replace(/{{BENEFIT}}/g, () => {
        const benefits = content.benefits?.[audience] || content.benefits?.general || [];
        return selectRandom(benefits);
    });
    
    return enhanced;
}

// Get default template
function getDefaultTemplate(style, hook) {
    const defaults = {
        'bold_claim': "Hydration is literally a superpower.\n\nMost people are walking around at 60% capacity.\n\nModuwell changes that.",
        'story': "I used to crash at 2pm every day.\n\nThen I discovered proper hydration.\n\nNow I'm more productive at 5pm than I used to be at 9am.",
        'contrarian': "Energy drinks are making you MORE tired.\n\nHere's what they don't tell you:\n\nProper hydration beats caffeine every time.",
        'problem_solution': "Problem: You're tired all the time\n\nRoot cause: Dehydration\n\nSolution: Moduwell\n\nResult: All-day energy",
        'list': "3 signs you're dehydrated:\n\n1. Afternoon crashes\n2. Brain fog\n3. Poor recovery\n\nOne solution fixes all three."
    };
    
    return defaults[style] || defaults['bold_claim'];
}

// Update preview
function updatePreview(posts) {
    const container = document.getElementById('postContent');
    container.textContent = posts[0];
    
    // Clear thread container
    document.getElementById('threadContainer').innerHTML = '';
}

// Update thread preview
function updateThreadPreview(thread) {
    const mainTweet = document.getElementById('postContent');
    const threadContainer = document.getElementById('threadContainer');
    
    // Show first tweet
    mainTweet.textContent = thread[0];
    
    // Show rest of thread
    threadContainer.innerHTML = thread.slice(1).map((tweet, index) => `
        <div class="twitter-preview p-4">
            <div class="flex items-start space-x-3">
                <div class="w-12 h-12 moduwell-gradient rounded-full flex items-center justify-center flex-shrink-0">
                    <span class="text-white font-bold">M</span>
                </div>
                <div class="flex-1">
                    <div class="flex items-center space-x-2">
                        <span class="font-bold">Moduwell</span>
                        <span class="text-gray-500">@moduwell</span>
                        <span class="text-gray-500">·</span>
                        <span class="text-gray-500">now</span>
                    </div>
                    <div class="mt-2 text-gray-900 whitespace-pre-wrap">${tweet}</div>
                </div>
            </div>
        </div>
    `).join('');
}

// Update character count
function updateCharacterCount(text) {
    const length = text.length;
    const charCountEl = document.getElementById('charCount');
    const charBarEl = document.getElementById('charBar');
    
    charCountEl.textContent = `${length} / 280`;
    
    // Update color based on length
    charCountEl.classList.remove('good', 'warning', 'danger');
    if (length <= 200) {
        charCountEl.classList.add('good');
        charBarEl.style.background = '#10B981';
    } else if (length <= 260) {
        charCountEl.classList.add('warning');
        charBarEl.style.background = '#F59E0B';
    } else {
        charCountEl.classList.add('danger');
        charBarEl.style.background = '#EF4444';
    }
    
    // Update bar width
    const percentage = Math.min((length / 280) * 100, 100);
    charBarEl.style.width = `${percentage}%`;
}

// Update engagement score
function updateEngagementScore(style, hook) {
    const scoreEl = document.getElementById('engagementScore');
    
    const highEngagement = ['bold_claim', 'contrarian', 'myth_buster'];
    const highHooks = ['shocking', 'statistic'];
    
    if (highEngagement.includes(style) && highHooks.includes(hook)) {
        scoreEl.textContent = '🔥 Viral Potential';
    } else if (highEngagement.includes(style) || highHooks.includes(hook)) {
        scoreEl.textContent = 'High Impact';
    } else {
        scoreEl.textContent = 'Good Engagement';
    }
}

// Copy to clipboard
function copyPost() {
    if (!currentPost) {
        alert('Generate a post first!');
        return;
    }
    
    const textToCopy = currentThread.join('\n\n---\n\n');
    
    navigator.clipboard.writeText(textToCopy).then(() => {
        const notification = document.getElementById('copyNotification');
        notification.classList.remove('hidden');
        setTimeout(() => {
            notification.classList.add('hidden');
        }, 3000);
    });
}

// Regenerate post
function regeneratePost() {
    generatePost();
}

// Save to recent
function saveToRecent(post, style) {
    const timestamp = new Date().toLocaleTimeString();
    recentPosts.unshift({ post, style, timestamp });
    
    if (recentPosts.length > 5) {
        recentPosts = recentPosts.slice(0, 5);
    }
    
    updateRecentPosts();
}

// Update recent posts display
function updateRecentPosts() {
    const container = document.getElementById('recentPosts');
    
    container.innerHTML = recentPosts.map(item => `
        <div class="p-3 bg-gray-50 rounded-lg cursor-pointer hover:bg-gray-100" onclick="loadRecent('${escape(item.post)}')">
            <div class="flex items-center justify-between mb-1">
                <span class="text-xs font-medium text-blue-600">${item.style.replace(/_/g, ' ').toUpperCase()}</span>
                <span class="text-xs text-gray-500">${item.timestamp}</span>
            </div>
            <div class="text-sm text-gray-700 line-clamp-2">${item.post.substring(0, 100)}...</div>
        </div>
    `).join('');
}

// Load recent post
function loadRecent(escapedPost) {
    const post = unescape(escapedPost);
    currentPost = post;
    
    // Check if it's a thread
    if (post.includes('---')) {
        currentThread = post.split('\n\n---\n\n');
        updateThreadPreview(currentThread);
    } else {
        currentThread = [post];
        updatePreview([post]);
    }
    
    updateCharacterCount(currentThread[0]);
}

// Helper functions
function selectRandom(array) {
    if (!array || !Array.isArray(array)) return '';
    return array[Math.floor(Math.random() * array.length)];
}

function escape(str) {
    return str.replace(/'/g, "\\'").replace(/"/g, '\\"').replace(/\n/g, '\\n');
}

function unescape(str) {
    return str.replace(/\\'/g, "'").replace(/\\"/g, '"').replace(/\\n/g, '\n');
}

// Thread options toggle
document.addEventListener('DOMContentLoaded', () => {
    const threadCheckbox = document.getElementById('createThread');
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
    
    // Generate initial post
    generatePost();
    
    // Add hashtag click functionality
    document.querySelectorAll('.px-3.py-1.bg-blue-50').forEach(tag => {
        tag.addEventListener('click', function() {
            const hashtag = this.textContent;
            const currentContent = document.getElementById('postContent').textContent;
            if (!currentContent.includes(hashtag)) {
                document.getElementById('postContent').textContent = currentContent + '\n\n' + hashtag;
                updateCharacterCount(document.getElementById('postContent').textContent);
            }
        });
    });
});