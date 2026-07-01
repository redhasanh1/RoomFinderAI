/**
 * Shared reliability middleware for Express server.
 */

const IS_PRODUCTION = process.env.NODE_ENV === 'production';
const ALLOW_DEBUG_ROUTES = process.env.ENABLE_DEBUG_ROUTES === 'true' && !IS_PRODUCTION;

function blockInProduction(req, res, next) {
    if (IS_PRODUCTION && !ALLOW_DEBUG_ROUTES) {
        return res.status(404).json({ error: 'Not found' });
    }
    next();
}

function createIpRateLimiter({ windowMs, max, keyPrefix = 'rl' }) {
    const store = new Map();

    return function ipRateLimitMiddleware(req, res, next) {
        const ip = req.ip || 'unknown';
        const key = `${keyPrefix}:${ip}`;
        const now = Date.now();
        const entry = store.get(key);

        if (!entry || now > entry.resetAt) {
            store.set(key, { count: 1, resetAt: now + windowMs });
            return next();
        }

        if (entry.count >= max) {
            return res.status(429).json({
                error: 'Too many requests',
                message: 'Please wait before trying again.',
                retryAfterMs: entry.resetAt - now
            });
        }

        entry.count += 1;
        next();
    };
}

const authRateLimitMiddleware = createIpRateLimiter({
    windowMs: 60 * 1000,
    max: 10,
    keyPrefix: 'auth'
});

function registerProcessHandlers() {
    process.on('unhandledRejection', (reason) => {
        console.error('unhandledRejection:', reason);
    });

    process.on('uncaughtException', (error) => {
        console.error('uncaughtException:', error);
    });
}

function registerErrorHandler(app, multer) {
    app.use((err, req, res, next) => {
        if (multer && err.name === 'MulterError') {
            return res.status(400).json({ error: err.message });
        }

        console.error('Request error:', err);
        if (res.headersSent) {
            return next(err);
        }

        res.status(500).json({
            error: 'Internal server error',
            message: IS_PRODUCTION ? 'Something went wrong. Please try again.' : err.message
        });
    });
}

function shouldUseDemoFallback() {
    return process.env.ENABLE_DEMO_MODE === 'true';
}

function getAdminKey() {
    const key = process.env.ADMIN_KEY?.trim();
    if (key) {
        return key;
    }
    if (IS_PRODUCTION) {
        return null;
    }
    return 'roomfinder-admin-dev-only';
}

module.exports = {
    IS_PRODUCTION,
    ALLOW_DEBUG_ROUTES,
    blockInProduction,
    authRateLimitMiddleware,
    registerProcessHandlers,
    registerErrorHandler,
    shouldUseDemoFallback,
    getAdminKey
};
