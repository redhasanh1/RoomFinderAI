const fs = require('fs');
const path = require('path');

const SITE_SHELL_MARKER = 'src="/js/site-bootstrap.js"';

function injectSiteShell(html) {
    if (!html || html.includes(SITE_SHELL_MARKER)) {
        return html;
    }

    // The platform-status banner used to be injected here, announcing that the
    // Android and iOS apps were closed. The iOS app is being released, so the
    // notice is no longer true — and it was appearing inside the iOS app
    // itself, telling its own users the app did not exist.
    const injection = [
        '<link rel="stylesheet" href="/modules/css/main.css">',
        '<script src="/js/site-nav.js" defer></script>',
        '<script src="/js/site-bootstrap.js" defer></script>'
    ].join('\n');

    if (html.includes('</head>')) {
        return html.replace('</head>', `${injection}\n</head>`);
    }

    return `${injection}\n${html}`;
}

function sendInjectedHtml(res, filePath) {
    const html = fs.readFileSync(filePath, 'utf8');
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    res.send(injectSiteShell(html));
}

function createHtmlInjectionMiddleware(frontendPath) {
    return (req, res, next) => {
        if (req.method !== 'GET') {
            return next();
        }

        let relativePath = req.path;
        if (relativePath === '/' || relativePath === '') {
            relativePath = 'index.html';
        } else if (!relativePath.endsWith('.html')) {
            return next();
        } else {
            relativePath = relativePath.replace(/^\//, '');
        }

        const filePath = path.join(frontendPath, relativePath);
        if (!fs.existsSync(filePath)) {
            return next();
        }

        try {
            sendInjectedHtml(res, filePath);
        } catch (error) {
            console.error('Failed to inject site shell into HTML:', filePath, error);
            next(error);
        }
    };
}

module.exports = {
    injectSiteShell,
    sendInjectedHtml,
    createHtmlInjectionMiddleware
};
