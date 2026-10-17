'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const {
  creditApplePurchase, applyAppleRefund, appleNotificationHandler, appAccountTokenFor, AppleIapError,
} = require('./apple_iap');

const eco = { phaLeShop: require('../assets/data/economy.json').phaLeShop };
const TOKEN_VECTOR = '45cbd7d0-0f71-5c14-a789-00b6fc52d4b7';
const now = new Date('2026-10-16T12:00:00Z');

const tx = (over = {}) => ({
  productId: 'com.tiemhoasommai.game.phale.pack_50k',
  transactionId: '1000001',
  bundleId: 'com.tiemhoasommai.game',
  ...over,
});

test('apple purchase writes one Pha lê mail for the pack', async () => {
  const db = new FakeFirestore();
  const out = await creditApplePurchase({ db, eco, uid: 'u1', transaction: tx(), now });
  assert.equal(out.phaLe, 550);
  assert.equal(out.packId, 'pack_50k');
  assert.equal(out.mailId, 'phale_iap_1000001');
  const mail = db.read('mails/phale_iap_1000001');
  assert.equal(mail.target, 'u1');
  assert.deepEqual(mail.rewards.items, [{ kind: 'phaLe', amount: 550 }]);
});

test('the same App Store transaction does not pay twice', async () => {
  const db = new FakeFirestore();
  await creditApplePurchase({ db, eco, uid: 'u1', transaction: tx(), now });
  const again = await creditApplePurchase({ db, eco, uid: 'u1', transaction: tx(), now });
  assert.equal(again.mailId, 'phale_iap_1000001');
  const mails = [...db.docs.keys()].filter((p) => p.startsWith('mails/'));
  assert.deepEqual(mails, ['mails/phale_iap_1000001']);
});

test('a transaction for another account is refused', async () => {
  const db = new FakeFirestore();
  await creditApplePurchase({ db, eco, uid: 'u1', transaction: tx(), now });
  await assert.rejects(
    () => creditApplePurchase({ db, eco, uid: 'u2', transaction: tx(), now }),
    (e) => e instanceof AppleIapError && e.code === 'owner',
  );
});

test('an unknown product is refused', async () => {
  const db = new FakeFirestore();
  await assert.rejects(
    () => creditApplePurchase({
      db, eco, uid: 'u1', transaction: tx({ productId: 'other' }), now,
    }),
    (e) => e instanceof AppleIapError && e.code === 'product',
  );
});

// ---- what the record keeps ------------------------------------------------

test('the record keeps what Apple says was paid, and the VND list price', async () => {
  const db = new FakeFirestore();
  await creditApplePurchase({
    db, eco, uid: 'u1', now,
    transaction: tx({
      environment: 'Production', price: 49000000, currency: 'VND', storefront: 'VNM',
      purchaseDate: Date.parse('2026-10-16T11:59:00Z'), originalTransactionId: '1000001',
    }),
  });
  const row = db.read('phale_iap/1000001');
  assert.equal(row.environment, 'Production');
  assert.equal(row.price, 49000000);
  assert.equal(row.currency, 'VND');
  assert.equal(row.storefront, 'VNM');
  assert.deepEqual(row.purchaseDate, new Date('2026-10-16T11:59:00Z'));
  assert.equal(row.originalTransactionId, '1000001');
  assert.equal(row.packPriceVnd, 50000);
});

// ---- appAccountToken ------------------------------------------------------

test('appAccountTokenFor is a stable version 5 UUID per uid', () => {
  const a = appAccountTokenFor('u1');
  assert.match(a, /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.equal(appAccountTokenFor('u1'), a);
  assert.notEqual(appAccountTokenFor('u2'), a);
  // Same value as lib/iap/phale_products.dart (test/iap/phale_products_test.dart).
  assert.equal(appAccountTokenFor('rFdE3O7LLBZIu0msxtvGktXmfJp1'), TOKEN_VECTOR);
});

test('a purchase made for another account is refused, its own account is credited', async () => {
  const db = new FakeFirestore();
  const t = tx({ appAccountToken: appAccountTokenFor('u1').toUpperCase() });
  await assert.rejects(
    () => creditApplePurchase({ db, eco, uid: 'u2', transaction: t, now }),
    (e) => e instanceof AppleIapError && e.code === 'account',
  );
  const out = await creditApplePurchase({ db, eco, uid: 'u1', transaction: t, now });
  assert.equal(out.phaLe, 550);
});

// ---- refunds --------------------------------------------------------------

const later = new Date('2026-10-20T08:00:00Z');
const refund = (db, type = 'REFUND') => applyAppleRefund({
  db, transaction: tx({ revocationReason: 0 }), notificationType: type, now: later,
});

test('a refund before the mail is claimed voids the mail', async () => {
  const db = new FakeFirestore();
  await creditApplePurchase({ db, eco, uid: 'u1', transaction: tx(), now });
  const out = await refund(db);
  assert.equal(out.result, 'mail_voided');
  const mail = db.read('mails/phale_iap_1000001');
  assert.deepEqual(mail.expiresAt, later);
  assert.equal(mail.voidReason, 'refund');
  const row = db.read('phale_iap/1000001');
  assert.deepEqual(row.refundedAt, later);
  assert.equal(row.refundType, 'REFUND');
  assert.equal(row.phaleDebt, 0);
});

test('a refund after the claim takes the Pha lê back from the save', async () => {
  const db = new FakeFirestore();
  await creditApplePurchase({ db, eco, uid: 'u1', transaction: tx(), now });
  db.seed('users/u1/mailState/phale_iap_1000001', { read: true, claimed: true });
  db.seed('users/u1', { progress: { version: 4, money: 5, phaLe: 900 }, updatedAt: now });
  const out = await refund(db, 'REVOKE');
  assert.deepEqual(out, { result: 'balance', taken: 550, debt: 0 });
  assert.equal(db.read('users/u1').progress.phaLe, 350);
  assert.equal(db.read('users/u1').progress.money, 5);
  assert.equal(db.read('phale_iap/1000001').refundType, 'REVOKE');
});

test('a refund never takes the balance below 0 and records the rest as debt', async () => {
  const db = new FakeFirestore();
  await creditApplePurchase({ db, eco, uid: 'u1', transaction: tx(), now });
  db.seed('users/u1/mailState/phale_iap_1000001', { read: true, claimed: true });
  db.seed('users/u1', { progress: { version: 4, phaLe: 200 } });
  const out = await refund(db);
  assert.deepEqual(out, { result: 'balance', taken: 200, debt: 350 });
  assert.equal(db.read('users/u1').progress.phaLe, 0);
  assert.equal(db.read('phale_iap/1000001').phaleDebt, 350);
});

test('with a server wallet, a refund after the claim takes the Pha lê from wallets/{uid}', async () => {
  const db = new FakeFirestore();
  await creditApplePurchase({ db, eco, uid: 'u1', transaction: tx(), now });
  assert.equal(db.read('mails/phale_iap_1000001').walletClaim, true, 'claimed through walletClaimMail');
  db.seed('users/u1/mailState/phale_iap_1000001', { read: true, claimed: true });
  db.seed('users/u1', { progress: { version: 4, phaLe: 900 } });
  db.seed('wallets/u1', { phaLe: 600 });
  const out = await refund(db);
  assert.deepEqual(out, { result: 'wallet', taken: 550, debt: 0 });
  assert.equal(db.read('wallets/u1').phaLe, 50);
  assert.equal(db.read('users/u1').progress.phaLe, 900, 'the save copy is left to the next sync');
  assert.equal(db.read('phale_iap/1000001').clawback, 'wallet');
});

test('the same refund twice changes nothing the second time', async () => {
  const db = new FakeFirestore();
  await creditApplePurchase({ db, eco, uid: 'u1', transaction: tx(), now });
  db.seed('users/u1/mailState/phale_iap_1000001', { read: true, claimed: true });
  db.seed('users/u1', { progress: { version: 4, phaLe: 900 } });
  await refund(db);
  const again = await refund(db);
  assert.equal(again.result, 'already');
  assert.equal(db.read('users/u1').progress.phaLe, 350);
});

test('a refund that arrives before the credit makes the later credit fail as revoked', async () => {
  const db = new FakeFirestore();
  assert.equal((await refund(db)).result, 'uncredited');
  await assert.rejects(
    () => creditApplePurchase({ db, eco, uid: 'u1', transaction: tx(), now }),
    (e) => e instanceof AppleIapError && e.code === 'revoked',
  );
  assert.equal(db.read('mails/phale_iap_1000001'), undefined);
});

test('a replay of a refunded purchase is refused as revoked', async () => {
  const db = new FakeFirestore();
  await creditApplePurchase({ db, eco, uid: 'u1', transaction: tx(), now });
  await refund(db);
  await assert.rejects(
    () => creditApplePurchase({ db, eco, uid: 'u1', transaction: tx(), now }),
    (e) => e instanceof AppleIapError && e.code === 'revoked',
  );
});

// ---- the HTTP handler (verifier mocked) ------------------------------------

const quiet = { info() {}, warn() {}, error() {} };
const fakeRes = () => {
  const r = { code: 0, body: null };
  r.status = (c) => { r.code = c; return r; };
  r.json = (b) => { r.body = b; return r; };
  return r;
};
const handler = (db, verify) => appleNotificationHandler({ db, verify, now: () => later, logger: quiet, eco });
const post = (signedPayload) => ({ method: 'POST', body: { signedPayload } });
const JWS = 'eyJhbGciOiJFUzI1NiJ9.payload.signature';

test('appleNotifications refuses a payload Apple did not sign', async () => {
  const db = new FakeFirestore();
  const res = fakeRes();
  await handler(db, async () => { throw new Error('bad signature'); })(post(JWS), res);
  assert.equal(res.code, 401);
  const res2 = fakeRes();
  await handler(db, async () => ({}))({ method: 'GET', body: {} }, res2);
  assert.equal(res2.code, 405);
  const res3 = fakeRes();
  await handler(db, async () => ({}))(post(''), res3);
  assert.equal(res3.code, 400);
});

test('appleNotifications applies a verified REFUND and ignores other types', async () => {
  const db = new FakeFirestore();
  await creditApplePurchase({ db, eco, uid: 'u1', transaction: tx(), now });
  const other = fakeRes();
  await handler(db, async () => ({ notificationType: 'CONSUMPTION_REQUEST', transaction: tx() }))(post(JWS), other);
  assert.equal(other.code, 200);
  assert.equal(db.read('phale_iap/1000001').refundedAt, undefined);
  const res = fakeRes();
  await handler(db, async (p) => {
    assert.equal(p, JWS);
    return { notificationType: 'REFUND', transaction: tx() };
  })(post(JWS), res);
  assert.equal(res.code, 200);
  assert.equal(res.body.result, 'mail_voided');
  assert.deepEqual(db.read('phale_iap/1000001').refundedAt, later);
});
