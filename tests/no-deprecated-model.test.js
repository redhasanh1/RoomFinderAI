// Fails if any server source file still names a retired OpenAI model.
// gpt-3.5-turbo was deprecated by OpenAI; requests naming it are rejected.
// Run: npm test   (or: node --test tests/no-deprecated-model.test.js)
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

const SERVER_DIR = path.join(__dirname, '..', 'backend');
const BANNED = /gpt-3\.5/i;

function sourceFiles(dir) {
    return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
        if (entry.name === 'node_modules') return [];
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) return sourceFiles(full);
        return /\.(c|m)?js$/.test(entry.name) ? [full] : [];
    });
}

test('server code does not reference gpt-3.5', () => {
    const files = sourceFiles(SERVER_DIR);
    assert.ok(files.length > 0, 'no server files found to scan');

    const hits = [];
    for (const file of files) {
        fs.readFileSync(file, 'utf8').split('\n').forEach((line, i) => {
            if (BANNED.test(line)) hits.push(`${path.relative(process.cwd(), file)}:${i + 1}`);
        });
    }
    assert.deepStrictEqual(hits, [], `deprecated model referenced at:\n  ${hits.join('\n  ')}`);
});
