// Android Navigation Fix - Simple and Direct
console.log('🔧 Android Navigation Fix loading...');

document.addEventListener('DOMContentLoaded', function() {
    console.log('🔧 Applying simple Android navigation fix...');
    
    // Function to fix navigation links
    function fixNavigationLinks() {
        // Get all navigation links in mobile menu
        const navLinks = document.querySelectorAll('.mobile-section-content a[href]');
        
        console.log(`📱 Found ${navLinks.length} navigation links to fix`);
        
        navLinks.forEach((link, index) => {
            const href = link.getAttribute('href');
            const text = link.textContent.trim();
            
            console.log(`🔗 Fixing link ${index}: "${text}" → ${href}`);
            
            // Remove any existing event listeners
            const newLink = link.cloneNode(true);
            link.parentNode.replaceChild(newLink, link);
            
            // Add simple click handler
            newLink.addEventListener('click', function(e) {
                e.stopPropagation(); // Prevent parent event handlers
                
                console.log(`📱 Navigation link clicked: "${text}"`);
                console.log(`🚀 Navigating to: ${href}`);
                
                // Visual feedback
                this.style.backgroundColor = 'rgba(102, 126, 234, 0.2)';
                
                // Navigate immediately
                window.location.href = href;
            }, { passive: false });
            
            // Add touch handler for Android
            newLink.addEventListener('touchend', function(e) {
                e.preventDefault();
                e.stopPropagation();
                
                console.log(`📱 Touch navigation: "${text}"`);
                
                // Trigger navigation
                window.location.href = href;
            }, { passive: false });
            
            // Ensure the link is interactive
            newLink.style.cursor = 'pointer';
            newLink.style.touchAction = 'manipulation';
            newLink.style.pointerEvents = 'auto';
            newLink.style.display = 'block';
            
            console.log(`✅ Fixed: "${text}"`);
        });
    }
    
    // Fix links immediately
    fixNavigationLinks();
    
    // Fix links again when sections expand
    document.addEventListener('click', function(e) {
        if (e.target.classList.contains('mobile-section-header')) {
            console.log('📱 Section expanding, will fix links...');
            setTimeout(fixNavigationLinks, 100);
        }
    });
    
    // Also observe for DOM changes
    const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            if (mutation.type === 'attributes' && 
                mutation.target.classList && 
                mutation.target.classList.contains('mobile-section-content')) {
                
                if (mutation.target.classList.contains('expanded')) {
                    console.log('📱 Section expanded via mutation, fixing links...');
                    setTimeout(fixNavigationLinks, 50);
                }
            }
        });
    });
    
    // Observe all mobile section content areas
    const sections = document.querySelectorAll('.mobile-section-content');
    sections.forEach(section => {
        observer.observe(section, {
            attributes: true,
            attributeFilter: ['class']
        });
    });
    
    console.log('✅ Android navigation fix applied');
});

// Global function for manual fixes
window.fixAndroidNavigation = function() {
    console.log('🔧 Manual Android navigation fix triggered');
    
    const navLinks = document.querySelectorAll('.mobile-section-content a[href]');
    navLinks.forEach(link => {
        link.onclick = function(e) {
            e.preventDefault();
            e.stopPropagation();
            console.log('Manual click:', this.href);
            window.location.href = this.href;
        };
        
        link.style.pointerEvents = 'auto';
        link.style.cursor = 'pointer';
    });
    
    console.log('✅ Manual fix applied to', navLinks.length, 'links');
};