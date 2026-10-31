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

test('first save seen: only the total ceiling, flagged and reverted', () => {
  assert.deepEqual(G.judgeSave(TH, null, { day: 1, money: 500000 }, T0, 0).reasons, []);
  const r = G.judgeSave(TH, null, { day: 1, money: 999999999999 }, T0, 0);
  assert.deepEqual(r.reasons, ['coins_total']);
  assert.equal(r.revert, true); // reverted when there is a save before it
});

const OLD = async () => new Date('2026-01-01T00:00:00Z'); // Auth creation, long ago

test('guard: a hacked save is reverted to the one before and the account flagged; server xu count', async () => {
  const db = new FakeFirestore();
  const good = { day: 2, money: 600000 };
  db.seed('users/u', { progress: good });
  await G.guard({ db, uid: 'u', before: null, after: { progress: good }, now: T0, th: TH, authCreated: OLD });
  assert.equal(db.read('save_guard/u').day, 2);
  const hacked = { day: 3, money: 9e12 };
  db.seed('users/u', { progress: hacked });
  const out = await G.guard({ db, uid: 'u', before: { progress: good }, after: { progress: hacked }, now: sec(400), th: TH, authCreated: OLD });
  assert.deepEqual(out, { ok: false, reasons: ['coins_gain'], reverted: true });
  assert.deepEqual(db.read('users/u').progress, good);
  assert.equal(db.read('cheat_flags/u').flagged, true);
  assert.equal(db.read('save_guard/u').money, 600000);
  // The revert's own trigger passes.
  assert.equal((await G.guard({ db, uid: 'u', before: { progress: hacked }, after: { progress: good }, now: sec(401), th: TH, authCreated: OLD })).ok, true);
  // A big letter of xu from the server is allowed on top.
  db.seed('mails/bxh_u', { target: 'u', createdAt: sec(500), rewards: { items: [{ kind: 'coins', amount: 5e9 }] } });
  db.seed('wallets/u/ledger/x', { type: 'exchange', coins: 1e9, at: sec(500) });
  assert.equal((await G.serverCoins(db, 'u', sec(450), {})).sum, 6e9);
  const rich = { day: 3, money: 600000 + 6e9 };
  assert.equal((await G.guard({ db, uid: 'v', before: null, after: { progress: { day: 2, money: 0 } }, now: T0, th: TH, authCreated: OLD })).ok, true);
  db.seed('mails/v', { target: 'v', createdAt: sec(500), rewards: { items: [{ kind: 'coins', amount: 6e9 }] } });
  assert.equal((await G.guard({ db, uid: 'v', before: null, after: { progress: rich }, now: sec(600), th: TH, authCreated: OLD })).ok, true);
});

test('first save / new game: the game day is capped by real time since the account was made', async () => {
  const joined = new Date(T0.getTime() - 3600 * 1000); // one hour: at most day 19
  assert.equal(G.maxDayByTime(TH, joined, T0), 19);
  const r = G.judgeSave(TH, null, { day: 100000, money: 0 }, T0, 0, joined);
  assert.deepEqual(r.reasons, ['day_too_fast']);
  assert.equal(r.revert, true);
  // The coin ceiling uses the capped day, not the save's.
  const rich = G.judgeSave(TH, null, { day: 100000, money: 1e12 }, T0, 0, joined);
  assert.deepEqual(rich.reasons, ['day_too_fast', 'coins_total']);
  // A new game (day below the last) is capped the same way.
  assert.deepEqual(G.judgeSave(TH, { day: 50, money: 0, at: T0 }, { day: 40, money: 0 }, T0, 0, joined).reasons, ['day_too_fast']);
  // An old account may be on day 100000.
  const old = new Date(T0.getTime() - 100000 * 200 * 1000);
  assert.deepEqual(G.judgeSave(TH, null, { day: 100000, money: 0 }, T0, 0, old).reasons, []);
  // guard: Auth creation time only; the hacked save is reverted and flagged.
  const db = new FakeFirestore();
  const before = { progress: { day: 3, money: 0 } };
  db.seed('users/n', { progress: { day: 100000, money: 0 } });
  const out = await G.guard({
    db, uid: 'n', before, after: { progress: { day: 100000, money: 0 } }, now: T0, th: TH,
    authCreated: async () => joined,
  });
  assert.deepEqual(out, { ok: false, reasons: ['day_too_fast'], reverted: true });
  assert.deepEqual(db.read('users/n').progress, before.progress);
  assert.equal(db.read('cheat_flags/n').flagged, true);
  assert.equal(db.read('save_guard/n'), undefined);
});

test('serverCoins: claimed letters to everyone count, unclaimed ones not; a gift or grant counts once', async () => {
  const db = new FakeFirestore();
  db.seed('mails/all1', { target: 'all', rewards: { items: [{ kind: 'coins', amount: 700 }] } });
  db.seed('mails/all2', { target: 'all', rewards: { items: [{ kind: 'coins', amount: 50 }] } });
  db.seed('users/u/mailState/all1', { claimed: true, claimedAt: sec(10) });
  db.seed('users/u/mailState/all2', { read: true });
  const user = { gift: { id: 'g1', items: { coins: 1000 } } };
  const a = await G.serverCoins(db, 'u', null, user, {});
  assert.equal(a.sum, 1700);
  const b = await G.serverCoins(db, 'u', sec(20), user, a.seen);
  assert.equal(b.sum, 0);
  const c = await G.serverCoins(db, 'u', sec(20), { gift: { id: 'g2', items: { coins: 5 } } }, a.seen);
  assert.equal(c.sum, 5);
});

test('account age is Firebase Auth only: a forged joinedAt (2020) does not lift the cap; no Auth time fails closed', async () => {
  const T = new Date('2026-10-31T12:00:00Z');
  const recent = new Date(T.getTime() - 3600 * 1000); // Auth: one hour -> day 19 at most
  const forged = { joinedAt: new Date('2020-01-01T00:00:00Z'), progress: { day: 5000, money: 0 } };
  const before = { progress: { day: 1, money: 0 } };
  const cases = [
    ['recent', async () => recent],
    ['none', async () => null],
    ['error', async () => { throw new Error('auth down'); }],
    ['absent', undefined],
  ];
  for (const [uid, authCreated] of cases) {
    const db = new FakeFirestore();
    db.seed(`users/${uid}`, forged);
    const out = await G.guard({ db, uid, before, after: forged, now: T, th: TH, authCreated });
    assert.deepEqual(out.reasons, ['day_too_fast'], uid);
    assert.equal(out.reverted, true, uid);
    assert.equal(db.read(`cheat_flags/${uid}`).flagged, true, uid);
  }
  // Without an Auth time only game day 1 passes (treated as just made).
  assert.equal(G.maxDayByTime(TH, null, T), 1);
  const db = new FakeFirestore();
  const day1 = { joinedAt: new Date('2020-01-01T00:00:00Z'), progress: { day: 1, money: 0 } };
  db.seed('users/w', day1);
  assert.equal((await G.guard({ db, uid: 'w', before: null, after: day1, now: T, th: TH })).ok, true);
});
