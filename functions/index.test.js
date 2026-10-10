// The five HTTP functions are public at the platform level (invoker: 'public')
// and that is safe only because each handler checks its own credential. This
// reads index.js as text (it needs firebase-admin to load), so the option cannot
// be dropped by accident and nothing else gets it.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const src = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const https = ['sepayIpn', 'sepayBankWebhook', 'phaleCreateOrder', 'phaleOrderStatus', 'phaleCancelOrder'];

test('every HTTP function is onRequest with invoker public', () => {
  for (const name of https) {
    const m = src.match(new RegExp(`exports\\.${name} = onRequest\\(\\s*\\{([^}]*)\\}`));
    assert.ok(m, `${name} is not an onRequest`);
    assert.match(m[1], /invoker:\s*'public'/, `${name} lacks invoker public`);
  }
});

test('only the five HTTP functions are public; scheduled and triggers are not', () => {
  assert.equal((src.match(/invoker:\s*'public'/g) || []).length, https.length);
});

test('the handlers still check their credentials', () => {
  const sepay = fs.readFileSync(path.join(__dirname, 'sepay.js'), 'utf8');
  const http = fs.readFileSync(path.join(__dirname, 'topup_http.js'), 'utf8');
  assert.match(sepay, /Apikey|apikey/i);
  assert.match(http, /401/);
  assert.match(http, /verify/);
});