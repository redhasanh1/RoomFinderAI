/**
 * Unified site bootstrap — Supabase config, auth UI, and shared styles on every page.
 */
(function () {
    'use strict';

    var BOOTSTRAP_MARKER = 'data-site-bootstrap';

    function loadScript(src) {
        if (document.querySelector('script[src="' + src + '"]')) {
            return Promise.resolve();
        }
        return new Promise(function (resolve, reject) {
            var s = document.createElement('script');
            s.src = src;
            s.defer = true;
            s.onload = resolve;
            s.onerror = reject;
            document.head.appendChild(s);
        });
    }

    function ensureStylesheet(href) {
        if (document.querySelector('link[href="' + href + '"]')) return;
        var link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = href;
        document.head.appendChild(link);
    }

    function initAuthUI() {
        if (typeof window.initUniversalAuth === 'function') {
            window.initUniversalAuth({ allowAnonymous: true });
            return;
        }
        if (window.UniversalAuth && typeof window.UniversalAuth.init === 'function') {
            window.UniversalAuth.init({ allowAnonymous: true, requireSupabase: false });
        }
    }

    async function bootstrap() {
        if (document.documentElement.getAttribute(BOOTSTRAP_MARKER)) return;
        document.documentElement.setAttribute(BOOTSTRAP_MARKER, '1');

        ensureStylesheet('/modules/css/main.css');

        if (!window.supabase) {
            await loadScript('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js');
        }
        await loadScript('/js/supabase-config-init.js');
        await loadScript('/universal-auth-manager.js');

        function onReady() {
            if (document.getElementById('header') || document.querySelector('.premium-header')) {
                document.body.classList.add('site-has-header');
            }
            initAuthUI();
        }

        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', onReady);
        } else {
            onReady();
        }
    }

    bootstrap().catch(function (err) {
        console.warn('Site bootstrap partial load:', err.message);
    });
})();
