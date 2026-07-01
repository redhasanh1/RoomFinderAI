(function () {
    'use strict';

    var STORAGE_KEY = 'rf-platform-banner-dismissed';
    var STATUS_PAGE = '/platform-status.html';

    var PLATFORM_NOTICE = {
        webActive: true,
        androidClosed: true,
        iosClosed: true,
        message:
            'Web is the only active platform right now. Android and iOS apps are temporarily closed.'
    };

    function shouldShowBanner() {
        if (window.location.pathname.endsWith('/platform-status.html') ||
            window.location.pathname === '/platform-status') {
            return false;
        }
        try {
            return sessionStorage.getItem(STORAGE_KEY) !== '1';
        } catch (e) {
            return true;
        }
    }

    function applyLayoutOffset(banner) {
        var offset = banner.offsetHeight || 44;
        document.documentElement.style.setProperty('--rf-platform-banner-offset', offset + 'px');
        document.body.classList.add('rf-platform-banner-visible');
    }

    function renderBanner() {
        if (!shouldShowBanner()) {
            return;
        }

        if (document.getElementById('rf-platform-status-banner')) {
            return;
        }

        var banner = document.createElement('div');
        banner.id = 'rf-platform-status-banner';
        banner.setAttribute('role', 'status');
        banner.setAttribute('aria-live', 'polite');
        banner.innerHTML =
            '<div class="rf-platform-status-inner">' +
            '<span><strong>Platform update:</strong> ' + PLATFORM_NOTICE.message +
            ' <a href="' + STATUS_PAGE + '">Learn more</a></span>' +
            '<button type="button" class="rf-platform-status-dismiss" aria-label="Dismiss for this session">Dismiss</button>' +
            '</div>';

        document.body.insertBefore(banner, document.body.firstChild);
        applyLayoutOffset(banner);

        banner.querySelector('.rf-platform-status-dismiss').addEventListener('click', function () {
            try {
                sessionStorage.setItem(STORAGE_KEY, '1');
            } catch (e) {
                /* ignore */
            }
            banner.remove();
            document.body.classList.remove('rf-platform-banner-visible');
            document.documentElement.style.removeProperty('--rf-platform-banner-offset');
        });

        window.addEventListener('resize', function () {
            applyLayoutOffset(banner);
        }, { passive: true });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', renderBanner);
    } else {
        renderBanner();
    }
})();
