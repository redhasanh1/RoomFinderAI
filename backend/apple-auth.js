/**
 * Verification for Sign in with Apple identity tokens.
 *
 * The previous handler decoded the JWT payload and trusted it. A JWT payload is
 * base64, not a signature — anyone could send
 *   { "iss": "https://appleid.apple.com", "email": "<victim>", "exp": <future> }
 * and be signed in as that person, with no Apple account involved. This module
 * checks the signature against Apple's published keys before anything else.
 *
 * Deliberately dependency-free: Node's crypto can import a JWK directly, so
 * this needs neither `jsonwebtoken` nor `jwks-rsa`.
 */

const crypto = require('crypto');

const APPLE_ISSUER = 'https://appleid.apple.com';
const APPLE_KEYS_URL = 'https://appleid.apple.com/auth/keys';

// Apple rotates these rarely. Cached for an hour so a burst of sign-ins does
// not mean a burst of outbound requests, and refreshed early on an unknown kid.
const KEY_CACHE_TTL_MS = 60 * 60 * 1000;
let keyCache = { keys: null, fetchedAt: 0 };

function base64UrlDecode(segment) {
    return Buffer.from(segment.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
}

async function fetchAppleKeys(force = false) {
    const fresh = keyCache.keys && Date.now() - keyCache.fetchedAt < KEY_CACHE_TTL_MS;
    if (fresh && !force) return keyCache.keys;

    const response = await fetch(APPLE_KEYS_URL);
    if (!response.ok) {
        throw new Error(`Could not fetch Apple signing keys (${response.status})`);
    }
    const body = await response.json();
    keyCache = { keys: body.keys || [], fetchedAt: Date.now() };
    return keyCache.keys;
}

async function findKey(kid) {
    let keys = await fetchAppleKeys();
    let match = keys.find((k) => k.kid === kid);
    if (match) return match;

    // Unknown kid usually means Apple rotated while our cache was warm.
    keys = await fetchAppleKeys(true);
    return keys.find((k) => k.kid === kid);
}

/**
 * @param {string} identityToken  The JWT from Apple.
 * @param {string[]} allowedAudiences  Bundle IDs (native) and Services IDs (web).
 * @returns {Promise<object>} The verified payload.
 * @throws {Error} If the token is malformed, unsigned by Apple, expired, or
 *                 issued for a different app.
 */
async function verifyAppleIdentityToken(identityToken, allowedAudiences = []) {
    if (typeof identityToken !== 'string') {
        throw new Error('Identity token missing');
    }

    const parts = identityToken.split('.');
    if (parts.length !== 3) {
        throw new Error('Malformed identity token');
    }

    const [headerB64, payloadB64, signatureB64] = parts;

    let header;
    let payload;
    try {
        header = JSON.parse(base64UrlDecode(headerB64).toString('utf8'));
        payload = JSON.parse(base64UrlDecode(payloadB64).toString('utf8'));
    } catch (e) {
        throw new Error('Malformed identity token');
    }

    // Apple signs with RS256. Refusing anything else also refuses the classic
    // `alg: none` forgery.
    if (header.alg !== 'RS256') {
        throw new Error(`Unexpected token algorithm: ${header.alg}`);
    }

    const jwk = await findKey(header.kid);
    if (!jwk) {
        throw new Error('Token signed with an unrecognised Apple key');
    }

    const publicKey = crypto.createPublicKey({ key: jwk, format: 'jwk' });
    const verified = crypto.verify(
        'RSA-SHA256',
        Buffer.from(`${headerB64}.${payloadB64}`),
        publicKey,
        base64UrlDecode(signatureB64)
    );

    if (!verified) {
        throw new Error('Identity token signature is not valid');
    }

    if (payload.iss !== APPLE_ISSUER) {
        throw new Error('Identity token was not issued by Apple');
    }

    const now = Math.floor(Date.now() / 1000);
    if (typeof payload.exp !== 'number' || payload.exp <= now) {
        throw new Error('Identity token has expired');
    }

    // `aud` binds the token to our app. Without this check, a valid Apple token
    // minted for any other developer's app would be accepted here.
    const audiences = allowedAudiences.filter(Boolean);
    if (audiences.length && !audiences.includes(payload.aud)) {
        throw new Error('Identity token was issued for a different application');
    }

    return payload;
}

module.exports = { verifyAppleIdentityToken };
