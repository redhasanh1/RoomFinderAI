// Android Link Navigation Fix
console.log('🔧 Android link navigation fix loading...');

// Simple and direct link fix for Android
document.addEventListener('DOMContentLoaded', function() {
    console.log('🔧 Applying Android link fixes...');
    
    // Function to make links work properly
    function fixAndroidLinks() {
        // Get all links in the mobile menu
        const menuLinks = document.querySelectorAll('.mobile-section-content a, .mobile-menu-item');
        
        console.log(`📱 Found ${menuLinks.length} menu links to fix`);
        
        menuLinks.forEach((link, index) => {
            if (link.tagName === 'A' && link.href) {
                console.log(`🔗 Fixing link ${index}: ${link.textContent.trim()} → ${link.href}`);
                
                // Store the href
                const targetUrl = link.href;
                
                // Clear any existing handlers
                link.onclick = null;
                link.removeAttribute('onclick');
                
                // Add a simple click handler
                link.addEventListener('click', function(e) {
                    e.preventDefault();
                    e.stopPropagation();
                    
                    console.log(`📱 Link clicked: ${this.textContent.trim()}`);
                    console.log(`📍 Navigating to: ${targetUrl}`);
                    
                    // Visual feedback
                    this.style.backgroundColor = 'rgba(102, 126, 234, 0.3)';
                    
                    // Navigate after a short delay
                    setTimeout(() => {
                        window.location.href = targetUrl;
                    }, 100);
                });
                
                // Also handle touch events
                link.addEventListener('touchend', function(e) {
                    e.preventDefault();
                    e.stopPropagation();
                    
                    console.log(`📱 Link touched: ${this.textContent.trim()}`);
                    
                    // Trigger click
                    this.click();
                });
                
                // Make sure link is interactive
                link.style.pointerEvents = 'auto';
                link.style.cursor = 'pointer';
                link.style.display = 'block';
                link.style.position = 'relative';
                link.style.zIndex = '9999';
            }
        });
    }
    
    // Fix links immediately
    fixAndroidLinks();
    
    // Fix links again after menu opens (in case of dynamic content)
    const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            if (mutation.target.classList && mutation.target.classList.contains('mobile-menu')) {
                console.log('📱 Mobile menu state changed, re-fixing links...');
                setTimeout(fixAndroidLinks, 100);
            }
        });
    });
    
    // Observe the mobile menu for changes
    const mobileMenu = document.getElementById('mobile-menu');
    if (mobileMenu) {
        observer.observe(mobileMenu, {
            attributes: true,
            attributeFilter: ['class']
        });
    }
    
    // Also fix when sections expand
    document.addEventListener('click', function(e) {
        if (e.target.classList.contains('mobile-section-header')) {
            console.log('📱 Section expanded, fixing links...');
            setTimeout(fixAndroidLinks, 300);
        }
    });
    
    console.log('✅ Android link navigation fix applied');
});

// Also add a global function to manually fix links
window.fixAndroidLinks = function() {
    const menuLinks = document.querySelectorAll('.mobile-section-content a, .mobile-menu-item');
    
    menuLinks.forEach(link => {
        if (link.tagName === 'A' && link.href) {
            link.style.pointerEvents = 'auto';
            link.style.cursor = 'pointer';
            link.onclick = function(e) {
                e.preventDefault();
                console.log('Manual fix: Navigating to', this.href);
                window.location.href = this.href;
            };
        }
    });
    
    console.log('✅ Manual Android link fix applied');
};