const fs = require('fs');
const path = require('path');

const SITE_SHELL_MARKER = 'site-bootstrap.js';

function injectSiteShell(html) {
    if (!html || html.includes(SITE_SHELL_MARKER)) {
        return html;
    }

    const injection = [
        '<link rel="stylesheet" href="/css/platform-status.css">',
        '<link rel="stylesheet" href="/modules/css/main.css">',
        '<script src="/js/platform-status-banner.js" defer></script>',
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
