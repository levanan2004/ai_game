// The five HTTP functions are public at the platform level (invoker: 'public')
// and that is safe only because each handler checks its own credential. This
// reads index.js as text (it needs firebase-admin to load), so the option cannot
// be dropped by accident and nothing else gets it.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const src = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const https = ['sepayIpn', 'sepayBankWebhook', 'phaleCreateOrder', 'phaleOrderStatus', 'phaleCancelOrder', 'appleNotifications'];
const callables = ['chatFrameEquip', 'deleteAccount', 'phaleApplePurchase'];

test('every HTTP function is onRequest with invoker public', () => {
  for (const name of https) {
    const m = src.match(new RegExp(`exports\\.${name} = onRequest\\(\\s*\\{([^}]*)\\}`));
    assert.ok(m, `${name} is not an onRequest`);
    assert.match(m[1], /invoker:\s*'public'/, `${name} lacks invoker public`);
  }
});

test('only the HTTP functions and the two callables are public; scheduled and triggers are not', () => {
  // + 6: walletCallable(), chatCallable(), frameCallable(), titleCallable(),
  // vipCallable() and seasonPassCallable(), each one onCall shared by several
  // exports (wallet functions; worldChatSend and worldChatReport;
  // avatarFrameList and avatarFrameEquip; titlePin and titleRelease;
  // vipRecompute and vipHallHide; seasonPassClaim and seasonPassBuyPremium).
  assert.equal((src.match(/invoker:\s*'public'/g) || []).length, https.length + callables.length + 6);
  for (const name of callables) {
    const m = src.match(new RegExp(`exports\\.${name} = onCall\\(\\s*\\{([^}]*)\\}`));
    assert.ok(m, `${name} is not an onCall`);
    assert.match(m[1], /invoker:\s*'public'/);
    assert.match(m[1], /region:\s*REGION/);
  }
});

test('phaleApplePurchase refuses a call without auth and credits request.auth.uid only', () => {
  const start = src.indexOf('exports.phaleApplePurchase');
  const body = src.slice(start, src.indexOf('exports.', start + 10));
  assert.match(body, /!request\.auth \|\| !request\.auth\.uid/);
  assert.match(body, /unauthenticated/);
  assert.match(body, /uid: request\.auth\.uid/);
  assert.doesNotMatch(body, /request\.data\.uid/);
});

test('appleNotifications only acts on a payload verified with Apple', () => {
  const start = src.indexOf('exports.appleNotifications');
  const body = src.slice(start, src.indexOf(');', start));
  assert.match(body, /region:\s*REGION/);
  assert.match(body, /verify:\s*verifyNotification/);
});

test('deleteAccount refuses a call without auth and only touches request.auth.uid', () => {
  const start = src.indexOf('exports.deleteAccount');
  const body = src.slice(start, src.indexOf('// Pha lê wallet', start));
  assert.match(body, /!request\.auth/);
  assert.match(body, /unauthenticated/);
  assert.match(body, /uid: request\.auth\.uid/);
  assert.doesNotMatch(body, /request\.data/);
});

test('the player HTTP functions refuse the ID token of a deleted or revoked user', () => {
  assert.match(src, /verifyIdToken\(token, true\)/);
});

test('the handlers still check their credentials', () => {
  const sepay = fs.readFileSync(path.join(__dirname, 'sepay.js'), 'utf8');
  const http = fs.readFileSync(path.join(__dirname, 'topup_http.js'), 'utf8');
  assert.match(sepay, /Apikey|apikey/i);
  assert.match(http, /401/);
  assert.match(http, /verify/);
});
test('the wallet callables refuse a call without auth and use request.auth.uid only', () => {
  const start = src.indexOf('function walletCallable');
  const body = src.slice(start, src.indexOf('exports.walletSync', start));
  assert.match(body, /onCall\(\s*\{[^}]*invoker:\s*'public'[^}]*\}/);
  assert.match(body, /region:\s*REGION/);
  assert.match(body, /!request\.auth \|\| !request\.auth\.uid/);
  assert.match(body, /unauthenticated/);
  assert.match(body, /const uid = request\.auth\.uid;/);
  assert.doesNotMatch(body, /request\.data\.uid/);
  for (const name of ['walletSync', 'walletClaimMail', 'walletEarn', 'phaleBuy', 'phaleExchange', 'gachaBuyCards', 'gachaSpin']) {
    assert.match(src, new RegExp(`exports\\.${name} = walletCallable\\(wallet\\.`), name);
  }
});

test('the title callables refuse a call without auth and use request.auth.uid only', () => {
  const start = src.indexOf('function titleCallable');
  const body = src.slice(start, src.indexOf('exports.titlePin', start));
  assert.match(body, /!request\.auth \|\| !request\.auth\.uid/);
  assert.match(body, /uid: request\.auth\.uid/);
  assert.doesNotMatch(body, /request\.data\.uid/);
  assert.match(src, /exports\.titlePin = titleCallable\(titles\.pin\)/);
  assert.match(src, /exports\.titleRelease = titleCallable\(titles\.release\)/);
});
