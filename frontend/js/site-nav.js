/**
 * Shared navigation — one canonical header on every page.
 * Injected by site-bootstrap after DOM ready; replaces per-page nav markup.
 */
(function () {
    'use strict';

    var NAV_RENDERED = 'data-site-nav-rendered';

    function toggleMobileMenu() {
        var menu = document.getElementById('mobile-menu');
        if (!menu) return;
        menu.classList.toggle('active');
        menu.classList.toggle('show');
        var btn = document.querySelector('.mobile-menu-btn');
        if (btn) btn.classList.toggle('active');
        document.body.classList.toggle('mobile-menu-open', menu.classList.contains('active') || menu.classList.contains('show'));
    }

    function closeMobileMenu() {
        var menu = document.getElementById('mobile-menu');
        if (!menu) return;
        menu.classList.remove('active', 'show');
        var btn = document.querySelector('.mobile-menu-btn');
        if (btn) btn.classList.remove('active');
        document.body.classList.remove('mobile-menu-open');
    }

    function toggleDropdown(name) {
        var menu = document.getElementById(name + '-dropdown');
        if (!menu) return;
        document.querySelectorAll('.dropdown-menu.active, .dropdown-menu.show').forEach(function (el) {
            if (el !== menu) el.classList.remove('active', 'show');
        });
        menu.classList.toggle('active');
        menu.classList.toggle('show');
    }

    function toggleMobileSection(sectionId) {
        var section = document.getElementById(sectionId + '-section');
        var arrow = document.getElementById(sectionId + '-arrow');
        if (!section) return;
        section.classList.toggle('expanded');
        section.classList.toggle('active');
        section.classList.toggle('show');
        if (arrow) {
            var open = section.classList.contains('expanded') || section.classList.contains('active') || section.classList.contains('show');
            arrow.style.transform = open ? 'rotate(180deg)' : 'rotate(0deg)';
        }
    }

    function initHeaderScroll() {
        var header = document.getElementById('header') || document.querySelector('.premium-header');
        if (!header) return;
        var onScroll = function () {
            if (window.scrollY > 50) header.classList.add('scrolled');
            else header.classList.remove('scrolled');
        };
        onScroll();
        window.addEventListener('scroll', onScroll, { passive: true });
    }

    function buildCanonicalNavHtml() {
        return (
            '<header id="header" class="site-fixed-header premium-header z-50">' +
            '<nav class="site-nav-inner">' +
            '<div class="site-nav-brand-row">' +
            '<a href="index.html" class="brand-logo site-brand-link">RoomFinderAI</a>' +
            '<button type="button" class="mobile-menu-btn site-show-mobile" onclick="toggleMobileMenu()" aria-label="Toggle navigation menu">' +
            '<span class="hamburger-line"></span><span class="hamburger-line"></span><span class="hamburger-line"></span>' +
            '</button></div>' +
            '<div class="desktop-nav site-show-desktop">' +
            '<a href="index.html" class="nav-item">Home</a>' +
            '<a href="roommate-matching.html" class="nav-item">RoomPal</a>' +
            '<a href="listings.html" class="nav-item">Listings</a>' +
            '<div class="dropdown">' +
            '<button type="button" class="nav-item dropdown-trigger" onclick="toggleDropdown(\'browse\')">Browse <span class="dropdown-arrow">▼</span></button>' +
            '<div class="dropdown-menu" id="browse-dropdown">' +
            '<a href="listings.html" class="dropdown-item">Browse Listings</a>' +
            '<a href="student-housing.html" class="dropdown-item">Student Housing</a>' +
            '<a href="sublease.html" class="dropdown-item">Sublease</a>' +
            '</div></div>' +
            '<div class="dropdown">' +
            '<button type="button" class="nav-item dropdown-trigger" onclick="toggleDropdown(\'tools\')">Tools <span class="dropdown-arrow">▼</span></button>' +
            '<div class="dropdown-menu" id="tools-dropdown">' +
            '<a href="ai-negotiator.html" class="dropdown-item">AI Negotiator</a>' +
            '<a href="legal.html" class="dropdown-item">Legal Help</a>' +
            '</div></div>' +
            '<div class="dropdown">' +
            '<button type="button" class="nav-item dropdown-trigger" onclick="toggleDropdown(\'about\')">More <span class="dropdown-arrow">▼</span></button>' +
            '<div class="dropdown-menu" id="about-dropdown">' +
            '<a href="index.html#about" class="dropdown-item">About Us</a>' +
            '<a href="pricing.html" class="dropdown-item">Pricing</a>' +
            '<a href="index.html#contact" class="dropdown-item">Contact</a>' +
            '<a href="support.html" class="dropdown-item">Support</a>' +
            '</div></div></div>' +
            '<div class="desktop-auth site-show-desktop">' +
            '<div id="authSection">' +
            '<a href="login.html" class="auth-link login-register-btn">Login/Register</a>' +
            '</div></div></nav>' +
            '<div class="mobile-menu" id="mobile-menu">' +
            '<div class="mobile-menu-overlay" onclick="closeMobileMenu()"></div>' +
            '<div class="mobile-menu-content">' +
            '<div class="mobile-menu-header">' +
            '<div class="text-lg font-bold gradient-text">RoomFinderAI</div>' +
            '<button type="button" class="mobile-menu-close" onclick="closeMobileMenu()" aria-label="Close menu">✕</button>' +
            '</div><div class="mobile-menu-items">' +
            '<a href="index.html" class="mobile-menu-item" onclick="closeMobileMenu()">Home</a>' +
            '<a href="roommate-matching.html" class="mobile-menu-item" onclick="closeMobileMenu()">RoomPal</a>' +
            '<a href="listings.html" class="mobile-menu-item" onclick="closeMobileMenu()">Listings</a>' +
            '<div class="mobile-section">' +
            '<button type="button" class="mobile-section-header" onclick="toggleMobileSection(\'profile\')">Profile <span class="mobile-arrow" id="profile-arrow">▼</span></button>' +
            '<div class="mobile-section-content" id="profile-section">' +
            '<a href="profile.html" class="mobile-menu-item" onclick="closeMobileMenu()">My Profile</a>' +
            '<a href="profile.html#my-listings" class="mobile-menu-item" onclick="closeMobileMenu()">My Listings</a>' +
            '<a href="favorites.html" class="mobile-menu-item" onclick="closeMobileMenu()">Favorites</a>' +
            '</div></div>' +
            '<div class="mobile-section">' +
            '<button type="button" class="mobile-section-header" onclick="toggleMobileSection(\'browse\')">Browse <span class="mobile-arrow" id="browse-arrow">▼</span></button>' +
            '<div class="mobile-section-content" id="browse-section">' +
            '<a href="listings.html" class="mobile-menu-item" onclick="closeMobileMenu()">Browse Listings</a>' +
            '<a href="student-housing.html" class="mobile-menu-item" onclick="closeMobileMenu()">Student Housing</a>' +
            '<a href="sublease.html" class="mobile-menu-item" onclick="closeMobileMenu()">Sublease</a>' +
            '</div></div>' +
            '<div class="mobile-section">' +
            '<button type="button" class="mobile-section-header" onclick="toggleMobileSection(\'tools\')">Tools <span class="mobile-arrow" id="tools-arrow">▼</span></button>' +
            '<div class="mobile-section-content" id="tools-section">' +
            '<a href="ai-negotiator.html" class="mobile-menu-item" onclick="closeMobileMenu()">AI Negotiator</a>' +
            '<a href="legal.html" class="mobile-menu-item" onclick="closeMobileMenu()">Legal Help</a>' +
            '</div></div>' +
            '<div class="mobile-section">' +
            '<button type="button" class="mobile-section-header" onclick="toggleMobileSection(\'about\')">More <span class="mobile-arrow" id="about-arrow">▼</span></button>' +
            '<div class="mobile-section-content" id="about-section">' +
            '<a href="index.html#about" class="mobile-menu-item" onclick="closeMobileMenu()">About Us</a>' +
            '<a href="pricing.html" class="mobile-menu-item" onclick="closeMobileMenu()">Pricing</a>' +
            '<a href="index.html#contact" class="mobile-menu-item" onclick="closeMobileMenu()">Contact</a>' +
            '<a href="support.html" class="mobile-menu-item" onclick="closeMobileMenu()">Support</a>' +
            '</div></div>' +
            '<div id="mobileAuthSection">' +
            '<a href="login.html" class="mobile-menu-item auth-item" onclick="closeMobileMenu()">Login/Register</a>' +
            '</div></div></div></div></header>'
        );
    }

    function renderCanonicalSiteNav() {
        if (document.documentElement.getAttribute(NAV_RENDERED)) return;
        var path = (window.location.pathname || '').toLowerCase();
        if (path.indexOf('login.html') !== -1) {
            document.documentElement.setAttribute(NAV_RENDERED, 'skip-login');
            return;
        }

        var html = buildCanonicalNavHtml();
        var existing = document.getElementById('header') || document.querySelector('header.premium-header, header.modern-header, .premium-header');
        if (existing && existing.tagName) {
            existing.outerHTML = html;
        } else {
            document.body.insertAdjacentHTML('afterbegin', html);
        }

        document.body.classList.add('site-has-header');
        document.documentElement.setAttribute(NAV_RENDERED, '1');
        initHeaderScroll();
    }

    document.addEventListener('click', function (e) {
        if (!e.target.closest('.dropdown')) {
            document.querySelectorAll('.dropdown-menu.active, .dropdown-menu.show').forEach(function (m) {
                m.classList.remove('active', 'show');
            });
        }
    });

    window.toggleMobileMenu = toggleMobileMenu;
    window.closeMobileMenu = closeMobileMenu;
    window.toggleDropdown = toggleDropdown;
    window.toggleMobileSection = toggleMobileSection;
    window.renderCanonicalSiteNav = renderCanonicalSiteNav;
})();
