#!/usr/bin/env node
/**
 * Fails when a secret-looking string or a secret file is committed.
 *
 *   node scripts/check-secrets.js           scan every tracked file
 *   node scripts/check-secrets.js --staged  scan staged content (pre-commit hook)
 *
 * Reports file, line and the kind of secret. Never prints the matched value.
 * Values that look like placeholders ("your-key-here", "sk-...", "<...>") are ignored.
 */
'use strict';

const { execFileSync } = require('child_process');

const PATTERNS = [
    ['jwt', /eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/g],
    ['openai_key', /sk-(?:proj-)?[A-Za-z0-9_-]{20,}/g],
    ['stripe_secret_key', /(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{10,}/g],
    ['stripe_webhook_secret', /whsec_[A-Za-z0-9]{10,}/g],
    ['groq_key', /gsk_[A-Za-z0-9]{20,}/g],
    ['google_api_key', /AIza[0-9A-Za-z_-]{35}/g],
    ['google_oauth_secret', /GOCSPX-[A-Za-z0-9_-]{10,}/g],
    ['aws_access_key', /AKIA[0-9A-Z]{16}/g],
    ['github_token', /gh[pousr]_[A-Za-z0-9]{30,}/g],
    ['slack_token', /xox[baprs]-[A-Za-z0-9-]{10,}/g],
    ['brevo_key', /xkeysib-[a-f0-9]{20,}/g],
    ['supabase_secret', /sb_secret_[A-Za-z0-9_-]{10,}/g],
    ['private_key', /-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----/g]
];

// Files that should never be committed, whatever they contain.
const FORBIDDEN_FILES = [
    ['env_file', /(^|\/)\.env(\.(?!example$|template$)[^/]+)?$/],
    ['keystore', /\.(jks|keystore)$/],
    ['keystore_properties', /(^|\/)keystore\.properties$/],
    ['gradle_cache', /(^|\/)\.gradle\//],
    ['apple_push_key', /\.p8$/]
];

const PLACEHOLDER = /your|xxxx|example|placeholder|changeme|dummy|<|\.\.\./i;
const SKIP = /(^|\/)node_modules\//;

function scanText(file, text) {
    const findings = [];
    for (const [kind, rx] of FORBIDDEN_FILES) {
        if (rx.test(file)) findings.push({ file, line: 0, kind });
    }
    const lines = text.split('\n');
    for (let i = 0; i < lines.length; i++) {
        for (const [kind, rx] of PATTERNS) {
            rx.lastIndex = 0;
            let m;
            while ((m = rx.exec(lines[i])) !== null) {
                if (!PLACEHOLDER.test(m[0])) findings.push({ file, line: i + 1, kind });
            }
        }
    }
    return findings;
}

function git(args) {
    return execFileSync('git', args, { maxBuffer: 256 * 1024 * 1024 });
}

function listFiles(staged) {
    const out = staged
        ? git(['diff', '--cached', '--name-only', '-z', '--diff-filter=ACMR'])
        : git(['ls-files', '-z']);
    return out.toString('utf8').split('\0').filter((f) => f && !SKIP.test(f));
}

// latin1 keeps binary files scannable (secrets were found in a Gradle .bin cache).
function readStaged(file) {
    // The index copy is what will actually be committed.
    try { return git(['show', `:${file}`]).toString('latin1'); } catch (_) { return ''; }
}

function readWorking(file) {
    try { return require('fs').readFileSync(file).toString('latin1'); } catch (_) { return ''; }
}

function scanRepo({ staged = false } = {}) {
    const findings = [];
    for (const file of listFiles(staged)) {
        findings.push(...scanText(file, staged ? readStaged(file) : readWorking(file)));
    }
    return findings;
}

module.exports = { scanText, scanRepo };

if (require.main === module) {
    const staged = process.argv.includes('--staged');
    const findings = scanRepo({ staged });
    if (findings.length) {
        console.error(`Secret check failed: ${findings.length} finding(s). Values are not shown.`);
        for (const f of findings) console.error(`  ${f.file}${f.line ? `:${f.line}` : ''}  ${f.kind}`);
        console.error('Move the value to an environment variable (see .env.example) and remove it from the file.');
        process.exit(1);
    }
    console.log(`Secret check passed (${staged ? 'staged files' : 'tracked files'}).`);
}
