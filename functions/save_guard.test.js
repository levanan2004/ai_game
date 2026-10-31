'use strict';
// save_guard.js against Hà Phương's nguong_chong_hack.json.

const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const AC = require('./anti_cheat');
const G = require('./save_guard');

const TH = AC.loadThresholds(require('./nguong_chong_hack.json'));
const T0 = new Date('2026-11-01T03:00:00Z');
const sec = (s) => new Date(T0.getTime() + s * 1000);

test('nguong_chong_hack.json: 152.096.956 xu per game day (1-9), 181.537.834 from day 10, 60 reviews / 300 stars, 200 s', () => {
  assert.equal(TH.coinsDay1to9, 152096956);
  assert.equal(TH.coinsDay10plus, 181537834);
  assert.equal(TH.maxReviewsPerGameDay, 60);
  assert.equal(TH.maxStarsPerGameDay, 300);
  assert.equal(TH.minGameDaySeconds, 200);
  assert.equal(AC.maxPlayCoins(TH, 8, 10), 152096956 + 181537834);
});

test('judgeSave: a normal day passes; xu over the per-day max is refused and the state kept', () => {
  const st = { day: 5, money: 1000000, at: T0 };
  const ok = G.judgeSave(TH, st, { day: 6, money: 100000000 }, sec(400), 0);
  assert.deepEqual(ok.reasons, []);
  assert.equal(ok.state.day, 6);
  // Two game days (5 in progress + 6) at most, plus login xu.
  const bad = G.judgeSave(TH, st, { day: 6, money: 1000000 + 2 * 152096956 + 200000 }, sec(400), 0);
  assert.deepEqual(bad.reasons, ['coins_gain']);
  assert.equal(bad.revert, true);
  assert.equal(bad.state, st);
  // The same xu passes when the server knows it gave them (Pha lê exchange, letters).
  assert.deepEqual(G.judgeSave(TH, st, { day: 6, money: 1000000 + 2 * 152096956 + 200000 }, sec(400), 100000000).reasons, []);
});

test('judgeSave: skipping game days by editing `day` gives no extra xu (server clock, 200 s per day)', () => {
  const st = { day: 5, money: 0, at: T0 };
  const r = G.judgeSave(TH, st, { day: 50, money: 5 * 152096956 }, sec(100), 0);
  assert.deepEqual(r.reasons, ['coins_gain']);
  const slow = G.judgeSave(TH, st, { day: 50, money: 5 * 152096956 }, sec(200 * 45), 0);
  assert.deepEqual(slow.reasons, []);
});

test('judgeSave: a game day over 60 reviews or 300 stars is refused', () => {
  const st = { day: 3, money: 0, at: T0 };
  const rev = (n, stars) => Array.from({ length: n }, () => ({ day: 3, stars }));
  assert.deepEqual(G.judgeSave(TH, st, { day: 4, money: 0, reviews: rev(61, 3) }, sec(400), 0).reasons, ['stars_day']);
  assert.deepEqual(G.judgeSave(TH, st, { day: 4, money: 0, reviews: rev(60, 5) }, sec(400), 0).reasons, []);
});

test('first save seen: only the total ceiling, flagged not reverted', () => {
  assert.deepEqual(G.judgeSave(TH, null, { day: 1, money: 500000 }, T0, 0).reasons, []);
  const r = G.judgeSave(TH, null, { day: 1, money: 999999999999 }, T0, 0);
  assert.deepEqual(r.reasons, ['coins_total']);
  assert.equal(r.revert, false);
});

test('guard: a hacked save is reverted to the one before and the account flagged; server xu count', async () => {
  const db = new FakeFirestore();
  const good = { day: 2, money: 600000 };
  db.seed('users/u', { progress: good });
  await G.guard({ db, uid: 'u', before: null, after: { progress: good }, now: T0, th: TH });
  assert.equal(db.read('save_guard/u').day, 2);
  const hacked = { day: 3, money: 9e12 };
  db.seed('users/u', { progress: hacked });
  const out = await G.guard({ db, uid: 'u', before: { progress: good }, after: { progress: hacked }, now: sec(400), th: TH });
  assert.deepEqual(out, { ok: false, reasons: ['coins_gain'], reverted: true });
  assert.deepEqual(db.read('users/u').progress, good);
  assert.equal(db.read('cheat_flags/u').flagged, true);
  assert.equal(db.read('save_guard/u').money, 600000);
  // The revert's own trigger passes.
  assert.equal((await G.guard({ db, uid: 'u', before: { progress: hacked }, after: { progress: good }, now: sec(401), th: TH })).ok, true);
  // A big letter of xu from the server is allowed on top.
  db.seed('mails/bxh_u', { target: 'u', createdAt: sec(500), rewards: { items: [{ kind: 'coins', amount: 5e9 }] } });
  db.seed('wallets/u/ledger/x', { type: 'exchange', coins: 1e9, at: sec(500) });
  assert.equal(await G.serverCoins(db, 'u', sec(450), {}), 6e9);
  const rich = { day: 3, money: 600000 + 6e9 };
  assert.equal((await G.guard({ db, uid: 'v', before: null, after: { progress: { day: 2, money: 0 } }, now: T0, th: TH })).ok, true);
  db.seed('mails/v', { target: 'v', createdAt: sec(500), rewards: { items: [{ kind: 'coins', amount: 6e9 }] } });
  assert.equal((await G.guard({ db, uid: 'v', before: null, after: { progress: rich }, now: sec(600), th: TH })).ok, true);
});
