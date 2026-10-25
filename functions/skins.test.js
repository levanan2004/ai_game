'use strict';
// Decoration skins bought with Pha lê (skins.js + wallet.buy kind 'skin').
// Prices come from economy.json `skins` (synced from assets/data by `npm test`).
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const W = require('./wallet');
const { skinPrice } = require('./skins');
const ECO = require('./economy.json');

const UID = 'u1';
const NOW = new Date('2026-10-25T03:00:00Z');
const T = ECO.skins.tiers;
const BIG = ECO.skins.bigSlotMultiplier;

function dbWith(phaLe) {
  const db = new FakeFirestore();
  db.seed(`users/${UID}`, { progress: { phaLe, day: 10 } });
  if (phaLe > 0) db.seed('phale_orders/TH0001', { uid: UID, status: 'paid', crystalsGranted: phaLe });
  return db;
}
const buy = (db, id) => W.buy({ db, eco: ECO, uid: UID, now: NOW, data: { kind: 'skin', id } });
const code = (c) => (e) => e instanceof W.WalletError && e.code === c;

test('skin prices follow the tier of the theme, backgrounds × bigSlotMultiplier', () => {
  assert.equal(skinPrice(ECO, 'quay_tet'), T.dep.price);
  assert.equal(skinPrice(ECO, 'bat_an_son_hai'), T.hiem.price);
  assert.equal(skinPrice(ECO, 'nen_man_hinh_son_hai'), Math.round(T.hiem.price * BIG.nenManHinh));
  assert.equal(skinPrice(ECO, 'nen_phong_trung_thu'), Math.round(T.dep.price * BIG.nenPhong));
});

test('free, xu, event and unknown skins are not sold for Pha lê', () => {
  for (const id of ['quay_mac_dinh', 'quay_he_bien', 'quay_bxh_mua1', 'quay_dragon', 'rong_tet', '', null]) {
    assert.equal(skinPrice(ECO, id), 0, String(id));
  }
});

test('buy takes the Pha lê once, records the skin and rejects a second buy', async () => {
  const price = T.dep.price;
  const db = dbWith(price * 3);
  const r = await buy(db, 'quay_tet');
  assert.equal(r.spent, price);
  assert.equal(r.phaLe, price * 2);
  assert.deepEqual(db.read(`wallets/${UID}`).skins, { quay_tet: 1 });
  await assert.rejects(buy(db, 'quay_tet'), code('owned'));
  assert.equal(db.read(`wallets/${UID}`).phaLe, price * 2);
});

test('not enough Pha lê, xu or event skins are refused and nothing is recorded', async () => {
  const db = dbWith(T.hiem.price - 1);
  await assert.rejects(buy(db, 'bat_an_son_hai'), code('balance'));
  await assert.rejects(buy(db, 'quay_he_bien'), code('not-for-sale'));
  await assert.rejects(buy(db, 'quay_bxh_mua1'), code('not-for-sale'));
  const w = db.read(`wallets/${UID}`);
  assert.ok(!w || !w.skins || !w.skins.bat_an_son_hai);
});
