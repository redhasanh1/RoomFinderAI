const fs = require('fs');
const path = require('path');

const INJECT_MARKER = 'platform-status-banner.js';

function injectPlatformStatusAssets(html) {
    if (!html || html.includes(INJECT_MARKER)) {
        return html;
    }

    const injection = [
        '<link rel="stylesheet" href="/css/platform-status.css">',
        '<script src="/js/platform-status-banner.js" defer></script>'
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
    res.send(injectPlatformStatusAssets(html));
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
            console.error('Failed to inject platform status into HTML:', filePath, error);
            next(error);
        }
    };
}

module.exports = {
    injectPlatformStatusAssets,
    sendInjectedHtml,
    createHtmlInjectionMiddleware
};
