// Grand UI JavaScript - Advanced Animations and Interactions

// Initialize on DOM Load
document.addEventListener('DOMContentLoaded', function() {
    initializeGrandUI();
});

function initializeGrandUI() {
    // Initialize all components
    initParallaxEffects();
    initMagneticButtons();
    initSmoothScroll();
    initCursorEffects();
    initScrollAnimations();
    initPageTransitions();
    initInteractiveElements();
    init3DCards();
    initTypeWriter();
    initCounterAnimations();
}

// Parallax Effects
function initParallaxEffects() {
    const parallaxElements = document.querySelectorAll('.parallax-element');
    
    window.addEventListener('scroll', () => {
        const scrolled = window.pageYOffset;
        
        parallaxElements.forEach(element => {
            const speed = element.dataset.speed || 0.5;
            const yPos = -(scrolled * speed);
            element.style.transform = `translateY(${yPos}px)`;
        });
    });
}

// Magnetic Button Effects
function initMagneticButtons() {
    const magneticButtons = document.querySelectorAll('.magnetic-button, .btn-grand');
    
    magneticButtons.forEach(button => {
        button.addEventListener('mousemove', (e) => {
            const rect = button.getBoundingClientRect();
            const x = e.clientX - rect.left - rect.width / 2;
            const y = e.clientY - rect.top - rect.height / 2;
            
            button.style.transform = `translate(${x * 0.3}px, ${y * 0.3}px)`;
        });
        
        button.addEventListener('mouseleave', () => {
            button.style.transform = 'translate(0, 0)';
        });
    });
}

// Enhanced Smooth Scroll
function initSmoothScroll() {
    const links = document.querySelectorAll('a[href^="#"]');
    
    links.forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const target = document.querySelector(link.getAttribute('href'));
            
            if (target) {
                const headerOffset = 100;
                const elementPosition = target.getBoundingClientRect().top;
                const offsetPosition = elementPosition + window.pageYOffset - headerOffset;
                
                window.scrollTo({
                    top: offsetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });
}

// Custom Cursor Effects
function initCursorEffects() {
    const cursor = document.createElement('div');
    cursor.className = 'custom-cursor';
    document.body.appendChild(cursor);
    
    const cursorFollower = document.createElement('div');
    cursorFollower.className = 'cursor-follower';
    document.body.appendChild(cursorFollower);
    
    let mouseX = 0, mouseY = 0;
    let followerX = 0, followerY = 0;
    
    document.addEventListener('mousemove', (e) => {
        mouseX = e.clientX;
        mouseY = e.clientY;
        
        cursor.style.left = mouseX + 'px';
        cursor.style.top = mouseY + 'px';
    });
    
    // Smooth follower animation
    setInterval(() => {
        followerX += (mouseX - followerX) * 0.1;
        followerY += (mouseY - followerY) * 0.1;
        
        cursorFollower.style.left = followerX + 'px';
        cursorFollower.style.top = followerY + 'px';
    }, 20);
    
    // Add hover effects
    const hoverElements = document.querySelectorAll('a, button, .interactive');
    hoverElements.forEach(element => {
        element.addEventListener('mouseenter', () => {
            cursor.classList.add('cursor-hover');
            cursorFollower.classList.add('follower-hover');
        });
        
        element.addEventListener('mouseleave', () => {
            cursor.classList.remove('cursor-hover');
            cursorFollower.classList.remove('follower-hover');
        });
    });
}

// Scroll-triggered Animations
function initScrollAnimations() {
    const animatedElements = document.querySelectorAll('.animate-on-scroll');
    
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -100px 0px'
    };
    
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('animated');
                
                // Stagger animations for child elements
                const children = entry.target.querySelectorAll('.stagger-item');
                children.forEach((child, index) => {
                    setTimeout(() => {
                        child.classList.add('animated');
                    }, index * 100);
                });
            }
        });
    }, observerOptions);
    
    animatedElements.forEach(element => {
        observer.observe(element);
    });
}

// Page Transitions
function initPageTransitions() {
    const pageLinks = document.querySelectorAll('a[href^="/"]:not([href^="#"])');
    
    pageLinks.forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const href = link.getAttribute('href');
            
            // Add transition effect
            document.body.classList.add('page-transition');
            
            setTimeout(() => {
                window.location.href = href;
            }, 500);
        });
    });
}

// Interactive Elements
function initInteractiveElements() {
    // Ripple Effect
    const rippleElements = document.querySelectorAll('.ripple');
    
    rippleElements.forEach(element => {
        element.addEventListener('click', (e) => {
            const ripple = document.createElement('span');
            ripple.className = 'ripple-effect';
            
            const rect = element.getBoundingClientRect();
            const size = Math.max(rect.width, rect.height);
            const x = e.clientX - rect.left - size / 2;
            const y = e.clientY - rect.top - size / 2;
            
            ripple.style.width = ripple.style.height = size + 'px';
            ripple.style.left = x + 'px';
            ripple.style.top = y + 'px';
            
            element.appendChild(ripple);
            
            setTimeout(() => {
                ripple.remove();
            }, 600);
        });
    });
}

// 3D Card Effects
function init3DCards() {
    const cards = document.querySelectorAll('.card-3d');
    
    cards.forEach(card => {
        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            
            const centerX = rect.width / 2;
            const centerY = rect.height / 2;
            
            const rotateX = (y - centerY) / 10;
            const rotateY = (centerX - x) / 10;
            
            card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale(1.05)`;
        });
        
        card.addEventListener('mouseleave', () => {
            card.style.transform = 'perspective(1000px) rotateX(0) rotateY(0) scale(1)';
        });
    });
}

// TypeWriter Effect
function initTypeWriter() {
    const typewriterElements = document.querySelectorAll('.typewriter');
    
    typewriterElements.forEach(element => {
        const text = element.dataset.text || element.textContent;
        const speed = parseInt(element.dataset.speed) || 100;
        element.textContent = '';
        
        let index = 0;
        
        function type() {
            if (index < text.length) {
                element.textContent += text.charAt(index);
                index++;
                setTimeout(type, speed);
            }
        }
        
        // Start typing when element is in view
        const observer = new IntersectionObserver((entries) => {
            if (entries[0].isIntersecting) {
                type();
                observer.disconnect();
            }
        });
        
        observer.observe(element);
    });
}

// Counter Animations
function initCounterAnimations() {
    const counters = document.querySelectorAll('.counter');
    
    counters.forEach(counter => {
        const target = parseInt(counter.dataset.target);
        const speed = parseInt(counter.dataset.speed) || 2000;
        const increment = target / (speed / 16);
        
        let current = 0;
        
        const updateCounter = () => {
            current += increment;
            
            if (current < target) {
                counter.textContent = Math.floor(current).toLocaleString();
                requestAnimationFrame(updateCounter);
            } else {
                counter.textContent = target.toLocaleString();
                
                // Add suffix if exists
                const suffix = counter.dataset.suffix;
                if (suffix) {
                    counter.textContent += suffix;
                }
            }
        };
        
        // Start animation when in view
        const observer = new IntersectionObserver((entries) => {
            if (entries[0].isIntersecting) {
                updateCounter();
                observer.disconnect();
            }
        });
        
        observer.observe(counter);
    });
}

// Utility Functions
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

function throttle(func, limit) {
    let inThrottle;
    return function(...args) {
        if (!inThrottle) {
            func.apply(this, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
        }
    };
}

// Export functions for use in other scripts
window.GrandUI = {
    initParallaxEffects,
    initMagneticButtons,
    initSmoothScroll,
    initCursorEffects,
    initScrollAnimations,
    initPageTransitions,
    initInteractiveElements,
    init3DCards,
    initTypeWriter,
    initCounterAnimations,
    debounce,
    throttle
};

// Add custom cursor styles
const cursorStyles = `
    .custom-cursor {
        width: 20px;
        height: 20px;
        border: 2px solid var(--purple-primary);
        border-radius: 50%;
        position: fixed;
        pointer-events: none;
        transition: all 0.1s ease;
        z-index: 9999;
        mix-blend-mode: difference;
    }
    
    .cursor-follower {
        width: 40px;
        height: 40px;
        background: rgba(102, 126, 234, 0.1);
        border-radius: 50%;
        position: fixed;
        pointer-events: none;
        z-index: 9998;
    }
    
    .cursor-hover {
        transform: scale(1.5);
        background: var(--purple-primary);
    }
    
    .follower-hover {
        transform: scale(1.2);
        background: rgba(102, 126, 234, 0.2);
    }
    
    .ripple-effect {
        position: absolute;
        border-radius: 50%;
        background: rgba(102, 126, 234, 0.5);
        animation: ripple-animation 0.6s ease-out;
        pointer-events: none;
    }
    
    @keyframes ripple-animation {
        to {
            transform: scale(4);
            opacity: 0;
        }
    }
    
    .page-transition {
        animation: fadeOut 0.5s ease-out forwards;
    }
    
    @keyframes fadeOut {
        to {
            opacity: 0;
            transform: scale(0.95);
        }
    }
`;

// Inject cursor styles
const styleSheet = document.createElement('style');
styleSheet.textContent = cursorStyles;
document.head.appendChild(styleSheet);