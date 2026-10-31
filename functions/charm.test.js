'use strict';
// node --test charm.test.js   (from functions/, after `npm run sync`).
// The same cases as test/logic/charm_rewards_test.dart, so the server and the
// app cannot drift apart without one of the two suites failing.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { loadEconomy, charmFromProgress, judge } = require('./charm');

const economyPath = fs.existsSync(path.join(__dirname, 'economy.json'))
  ? path.join(__dirname, 'economy.json')
  : path.join(__dirname, '..', 'assets', 'data', 'economy.json');
const eco = loadEconomy(JSON.parse(fs.readFileSync(economyPath, 'utf8')));

const save = (id, stage, worn = {}) => ({
  petCharm: id,
  pets: [{ id, ...(stage ? { stage } : {}), ...(Object.keys(worn).length ? { worn } : {}) }],
});

test('base x stage multiplier', () => {
  assert.equal(charmFromProgress(save('kim_long', 2), eco).charm, 300);
  assert.equal(charmFromProgress(save('kim_long', 1), eco).charm, 225);
  assert.equal(charmFromProgress(save('kim_long', 0), eco).charm, 150);
  assert.equal(charmFromProgress(save('ca_chep', 0), eco).charm, 10);
});

test('worn items add their tier charm, once per slot', () => {
  const one = charmFromProgress(save('kim_long', 2, { neck: 'no_co_vai' }), eco);
  assert.equal(one.charm, 305);
  assert.deepEqual(one.worn, { neck: 'no_co_vai' });
  const full = charmFromProgress(save('kim_long', 2, {
    neck: 'day_chuyen_suong_mai', head: 'vuong_mien_som_mai', accessory: 'canh_binh_minh',
  }), eco);
  assert.equal(full.charm, 600);
});

test('an item in the wrong slot, an unknown item or a stray slot adds nothing', () => {
  const r = charmFromProgress(save('kim_long', 2, { neck: 'mu_rom', head: 'nope', tail: 'no_co_vai' }), eco);
  assert.equal(r.charm, 300);
  assert.deepEqual(r.worn, {});
});

test('an empty slot, a pet that is not owned or a broken save is 0', () => {
  assert.equal(charmFromProgress({ pets: [] }, eco).charm, 0);
  assert.equal(charmFromProgress({ petCharm: 'kim_long', pets: [{ id: 'meo' }] }, eco).charm, 0);
  assert.equal(charmFromProgress(null, eco).charm, 0);
  assert.equal(charmFromProgress({ petCharm: 'ghost', pets: [{ id: 'ghost' }] }, eco).charm, 0);
});

test('stage is clamped', () => {
  assert.equal(charmFromProgress(save('kim_long', 9), eco).charm, 300);
  assert.equal(charmFromProgress(save('kim_long', -3), eco).charm, 150);
});

const FULL = { neck: 'day_chuyen_suong_mai', head: 'vuong_mien_som_mai', accessory: 'canh_binh_minh' };
const SON_HAI = ['chau_cuu_vi_ho', 'chau_chuc_long', 'chau_con_bang', 'chau_bach_trach',
  'chau_thao_thiet', 'chau_cung_ky', 'chau_hon_don', 'chau_dao_ngot', 'chau_tat_phuong',
  'chau_tinh_ve', 'chau_de_giang', 'chau_ky_lan'];

test('each owned Sơn Hải type adds its charm once, shelf or cupboard', () => {
  const per = eco.potCharm.get('chau_cuu_vi_ho');
  assert.equal(per, 60);
  const base = save('kim_long', 2, FULL);
  // Three copies of one type: counted once, nothing on the shelf needed.
  const one = charmFromProgress({ ...base, potCounts: { chau_cuu_vi_ho: 3 } }, eco);
  assert.equal(one.charm, 600 + per);
  const two = charmFromProgress({ ...base, potCounts: { chau_cuu_vi_ho: 1, chau_chuc_long: 2 } }, eco);
  assert.equal(two.charm, 600 + 2 * per);
  // A pot on the shelf that the save does not own, a Linh vật pot, a zero
  // count and an unknown id add nothing.
  const none = charmFromProgress({
    ...base, barPots: ['chau_tinh_ve'], potCounts: { dragon: 2, chau_de_giang: 0, ghost: 4 },
  }, eco);
  assert.equal(none.charm, 600);
});

test('no overall cap: all 12 Sơn Hải types reach 1320, parts clamp on their own', () => {
  const counts = Object.fromEntries(SON_HAI.map((id) => [id, 1]));
  const all = charmFromProgress({ ...save('kim_long', 2, FULL), potCounts: counts }, eco);
  assert.equal(all.charm, 1320);
  assert.ok(all.charm > 600);
  assert.equal(eco.partMax.pet + eco.partMax.petItems + eco.partMax.pots, 1320);
  // The pot part still counts with a small pet.
  assert.equal(charmFromProgress({ ...save('ca_chep', 0), potCounts: counts }, eco).charm, 10 + 720);
  // No pet in the charm slot: 0, whatever the pots.
  assert.equal(charmFromProgress({ pets: [], potCounts: counts }, eco).charm, 0);
});

test('judge lowers a row above the recomputed value, even above the old cap', () => {
  const progress = { ...save('kim_long', 2, FULL), potCounts: { chau_cuu_vi_ho: 1, chau_ky_lan: 1 } };
  assert.equal(judge({ charm: 720 }, progress, eco).verdict, 'ok');
  const inflated = judge({ charm: 900 }, progress, eco);
  assert.equal(inflated.verdict, 'lower');
  assert.equal(inflated.real.charm, 720);
  assert.equal(judge({ charm: 1320 }, save('kim_long', 2, FULL), eco).verdict, 'lower');
});

test('judge: ok, lower, remove', () => {
  const progress = save('kim_long', 2, { neck: 'no_co_vai' });
  assert.equal(judge({ charm: 305 }, progress, eco).verdict, 'ok');
  assert.equal(judge({ charm: 200 }, progress, eco).verdict, 'ok'); // a save ahead of the row is fine
  const lower = judge({ charm: 600 }, progress, eco);
  assert.equal(lower.verdict, 'lower');
  assert.equal(lower.real.charm, 305);
  assert.equal(judge({ charm: 100 }, { petCharm: 'ca_chep', pets: [{ id: 'ca_chep' }] }, eco).verdict, 'remove');
  assert.equal(judge({ charm: 100 }, null, eco).verdict, 'remove');
});

test('the config the function reads matches the app', () => {
  assert.equal(eco.minCharm, 20);
  assert.deepEqual(eco.slots, ['neck', 'head', 'accessory']);
  assert.equal(eco.byTier.huyenThoai, 100);
});

test('serverOwned: Pha lê items (bought > sold), won pots, Pha lê buys and server letters; xu buys are not there', async () => {
  const { FakeFirestore } = require('./fake_firestore');
  const { serverOwned } = require('./charm');
  const db = new FakeFirestore();
  db.seed('wallets/u', { items: { a: { bought: 1, sold: 0 }, b: { bought: 1, sold: 1 } }, wonPots: ['chau_cung_ky'] });
  db.seed('wallets/u/ledger/1', { type: 'buy', kind: 'pet', id: 'kim_long' });
  db.seed('wallets/u/ledger/2', { type: 'spin', results: [] });
  db.seed('mails/m1', { target: 'u', rewards: { items: [{ kind: 'pot', id: 'chau_thao_thiet' }, { kind: 'coins', amount: 5 }] } });
  db.seed('mails/m2', { target: 'other', rewards: { items: [{ kind: 'pet', id: 'meo' }] } });
  const o = await serverOwned(db, 'u');
  assert.deepEqual([...o.pets], ['kim_long']);
  assert.deepEqual([...o.items], ['a']);
  assert.deepEqual([...o.pots].sort(), ['chau_cung_ky', 'chau_thao_thiet']);
  const eco2 = loadEconomy(JSON.parse(fs.readFileSync(path.join(__dirname, 'economy.json'), 'utf8')));
  const save = { petCharm: 'kim_long', pets: [{ id: 'kim_long', stage: 2 }], potCounts: { chau_cung_ky: 1, chau_hack: 1 } };
  const none = { pets: new Set(), items: new Set(), pots: new Set() };
  assert.equal(charmFromProgress(save, eco2, none).charm, 0);
  assert.equal(charmFromProgress(save, eco2, o).charm, charmFromProgress({ ...save, potCounts: { chau_cung_ky: 1 } }, eco2).charm);
});

test('serverOwned: a claimed letter to everyone counts, an unclaimed one does not', async () => {
  const { FakeFirestore } = require('./fake_firestore');
  const { serverOwned } = require('./charm');
  const db = new FakeFirestore();
  db.seed('mails/a', { target: 'all', rewards: { items: [{ kind: 'petItem', id: 'x' }] } });
  db.seed('mails/b', { target: 'all', rewards: { items: [{ kind: 'petItem', id: 'y' }] } });
  db.seed('users/u/mailState/a', { claimed: true, claimedAt: new Date() });
  assert.deepEqual([...(await serverOwned(db, 'u')).items], ['x']);
});

test('coin buys count: coinBuy records, and a one-time backfill capped at 20 pet + 45 item charm', async () => {
  const { FakeFirestore } = require('./fake_firestore');
  const { serverOwned, coinBackfill } = require('./charm');
  const AC = require('./anti_cheat');
  const th = AC.loadThresholds(require('./nguong_chong_hack.json'));
  assert.equal(th.backfillPetCharm + th.backfillItemCharm, 65);
  const eco2 = loadEconomy(JSON.parse(fs.readFileSync(path.join(__dirname, 'economy.json'), 'utf8')));
  const save = {
    petCharm: 'meo',
    pets: [{ id: 'meo', stage: 2, worn: { neck: 'vong_hoa_nho', head: 'mu_rom', accessory: 'canh_buom' } }, { id: 'kim_long', stage: 2 }],
  };
  const b = coinBackfill(save, eco2, th);
  assert.deepEqual(b.pets, ['meo']); // kim_long is a Pha lê pet: never backfilled
  // hiem 15 + thuong 5 + hiem 15 = 35 <= 45: all three.
  assert.deepEqual(b.petItems, ['vong_hoa_nho', 'mu_rom', 'canh_buom']);
  const db = new FakeFirestore();
  const o = await serverOwned(db, 'u', { eco: eco2, progress: save, th });
  assert.equal(charmFromProgress(save, eco2, o).charm, 20 + 35);
  assert.deepEqual(db.read('wallets/u').coinBackfill.pets, ['meo']);
  // Only once: a later save with another xu pet adds nothing without coinBuy.
  const o2 = await serverOwned(db, 'u', { eco: eco2, progress: { petCharm: 'hac', pets: [{ id: 'hac', stage: 2 }] }, th });
  assert.equal(o2.pets.has('hac'), false);
  db.seed('wallets/u', { ...db.read('wallets/u'), coinItems: { pet: { hac: 1 }, petItem: {} } });
  assert.equal((await serverOwned(db, 'u')).pets.has('hac'), true);
});
