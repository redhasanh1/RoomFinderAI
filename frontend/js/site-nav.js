/**
 * Shared navigation — one implementation for all pages.
 */
(function () {
    'use strict';

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

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initHeaderScroll);
    } else {
        initHeaderScroll();
    }
})();
