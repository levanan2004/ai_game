'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const { creditApplePurchase, AppleIapError } = require('./apple_iap');

const eco = { phaLeShop: require('../assets/data/economy.json').phaLeShop };
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
