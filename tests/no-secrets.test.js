// Fails if a tracked file contains a secret-looking string or is a secret file.
// Run: npm test   (or: node --test tests/no-secrets.test.js)
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const path = require('path');
const { scanText, scanRepo } = require('../scripts/check-secrets');

process.chdir(path.join(__dirname, '..'));

// Fake values are assembled at runtime so this file never contains a literal secret.
const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
const fakeJwt = [b64({ alg: 'HS256', typ: 'JWT' }), b64({ role: 'service_role', ref: 'abc' }), 'S'.repeat(43)].join('.');
const fakeOpenAi = 'sk' + '-' + 'A1b2C3d4'.repeat(4);
const fakeStripe = 'sk' + '_live_' + 'Z9'.repeat(12);

test('no tracked file contains a secret', () => {
    const findings = scanRepo();
    const report = findings.map((f) => `${f.file}${f.line ? ':' + f.line : ''} ${f.kind}`).join('\n  ');
    assert.deepStrictEqual(findings, [], `secrets found (values hidden):\n  ${report}`);
});

test('detects a JWT and known key formats', () => {
    const kinds = scanText('x.js', `const a = '${fakeJwt}';\nconst b = "${fakeOpenAi}";\nconst c = "${fakeStripe}";`).map((f) => f.kind);
    assert.deepStrictEqual(kinds, ['jwt', 'openai_key', 'stripe_secret_key']);
});

test('ignores placeholders', () => {
    assert.deepStrictEqual(scanText('.env.example', 'OPENAI_API_KEY=sk-your-openai-api-key-here\nSTRIPE_SECRET_KEY=\n'), []);
});

test('flags secret files by name', () => {
    for (const file of ['.env', 'backend/.env.production', 'android/release.jks', 'android/keystore.properties', 'android/.gradle/8.13/x.bin']) {
        assert.ok(scanText(file, '').length > 0, `${file} should be flagged`);
    }
    for (const file of ['.env.example', '.env.template', 'android/keystore.properties.template']) {
        assert.deepStrictEqual(scanText(file, ''), [], `${file} should be allowed`);
    }
});
