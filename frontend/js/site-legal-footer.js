/**
 * The legal footer, on every page that has the site header.
 *
 * The privacy policy was linked from six pages out of twenty-six — the legal
 * pages themselves, and the home page. Anywhere else, someone who wanted to
 * know what happens to their government ID had to guess the URL. Apple opens
 * this link during review and expects it to be reachable, and so does anyone
 * who has just been asked to upload a passport.
 *
 * Injected rather than pasted into each page so it cannot drift between them,
 * and skipped where a page already carries these links itself.
 */
(function () {
    'use strict';

    var LINKS = [
        { href: 'privacy-policy.html',  text: 'Privacy Policy' },
        { href: 'terms-of-service.html', text: 'Terms of Service' },
        { href: 'acceptable-use-policy.html', text: 'Acceptable Use' },
        { href: 'cookie-policy.html',   text: 'Cookie Policy' },
        { href: 'accessibility.html',   text: 'Accessibility' },
        { href: 'support.html',         text: 'Support' }
    ];

    function alreadyLinked() {
        // A page that already offers the policy in its own footer does not need
        // a second copy underneath it.
        return !!document.querySelector('footer a[href*="privacy-policy"]');
    }

    function build() {
        if (document.getElementById('rf-legal-footer') || alreadyLinked()) return;

        var style = document.createElement('style');
        style.textContent = [
            '#rf-legal-footer{border-top:1px solid #e5e7eb;background:#fafbfd;',
            '  padding:1.4rem 1.25rem 2rem;margin-top:3rem;',
            '  font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}',
            '#rf-legal-footer .rf-lf-inner{max-width:1100px;margin:0 auto;text-align:center}',
            '#rf-legal-footer nav{display:flex;flex-wrap:wrap;gap:.4rem 1.25rem;justify-content:center}',
            '#rf-legal-footer a{color:#4b5563;font-size:.82rem;text-decoration:none}',
            '#rf-legal-footer a:hover{color:#4f46e5;text-decoration:underline}',
            '#rf-legal-footer p{margin:.9rem 0 0;font-size:.75rem;color:#9ca3af}'
        ].join('');
        document.head.appendChild(style);

        var footer = document.createElement('footer');
        footer.id = 'rf-legal-footer';
        footer.innerHTML =
            '<div class="rf-lf-inner"><nav aria-label="Legal">' +
            LINKS.map(function (l) {
                return '<a href="' + l.href + '">' + l.text + '</a>';
            }).join('') +
            '</nav><p>&copy; ' + new Date().getFullYear() + ' RoomFinderAI</p></div>';

        document.body.appendChild(footer);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', build);
    } else {
        build();
    }
})();
