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

test('stage is clamped and the score is capped at 600', () => {
  assert.equal(charmFromProgress(save('kim_long', 9), eco).charm, 300);
  assert.equal(charmFromProgress(save('kim_long', -3), eco).charm, 150);
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
