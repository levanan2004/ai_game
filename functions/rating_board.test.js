'use strict';
// Bảng xếp hạng Đánh giá on the server (rating_board.js), economy.json
// `ratingBoard` (Hà Phương's block), on the in-memory Firestore.
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const { defaultFilter } = require('./word_filter');
const R = require('./rating_board');

const ECO = require('./economy.json');
// Season 2 starts 09/11/2026 00:00 in Vietnam.
const T0 = new Date('2026-11-10T03:00:00Z');
const CFG = R.ratingConfig(ECO, T0);
const sec = (s) => new Date(T0.getTime() + s * 1000);
const rev = (day, stars) => ({ day, stars, customerName: 'Khách', outcome: 'great' });
const save = (day, reviews = [], extra = {}) => ({ day, reviews, shopName: 'Tiệm Lan', ...extra });

test('economy.json ratingBoard: m 100, C 4,0 until 2.000, 50 to rank, caps 100/day, 60/game day, 200 s, season 2', () => {
  assert.equal(CFG.period, 'rating-2');
  assert.equal(CFG.m, 100);
  assert.equal(CFG.cFallback, 4);
  assert.equal(CFG.cUntil, 2000);
  assert.equal(CFG.minToRank, 50);
  assert.equal(CFG.dailyCap, 100);
  assert.equal(CFG.seasonCap, 2800);
  assert.equal(CFG.dayMax, 60);
  assert.equal(CFG.daySeconds, 200);
  assert.equal(CFG.topLimit, 100);
  assert.equal(CFG.start.toISOString(), '2026-11-08T17:00:00.000Z');
  assert.equal(CFG.end.toISOString(), '2026-12-06T17:00:00.000Z');
  assert.equal(R.ratingConfig({}), null);
});

test('Bayes score: the four examples of the block', () => {
  for (const e of ECO.ratingBoard.examples) {
    const sc = R.score(CFG, e.v, e.v * e.R, 4);
    assert.equal(Math.round(sc * 1000) / 1000, e.score);
    assert.equal(R.sortKey(CFG, e.v, sc) > 0, e.shown);
  }
  // Tie-break: same rounded score, more reviews first.
  assert.ok(R.sortKey(CFG, 120, 4.5) > R.sortKey(CFG, 80, 4.5));
  assert.ok(R.sortKey(CFG, 50, 4.501) > R.sortKey(CFG, 2800, 4.5));
  assert.equal(R.seasonC(CFG, 1999, 1999 * 4.8), 4);
  assert.equal(R.seasonC(CFG, 2000, 2000 * 4.5), 4.5);
});

test('plan: the first save only starts the clock; a finished day counts on the next morning', () => {
  let p = R.plan(CFG, null, save(5, [rev(4, 5)]), T0);
  assert.deepEqual(p.add, []);
  assert.equal(p.state.day, 5);
  p = R.plan(CFG, p.state, save(6, [rev(4, 5), rev(5, 5), rev(5, 4), rev(6, 3)]), sec(300));
  assert.deepEqual(p.add, [5, 4]); // day 5 only: day 4 was before the clock, day 6 not finished
  assert.equal(p.state.v, 2);
  assert.equal(p.state.sum, 9);
  // The same save again (another write of users/{uid}): nothing new.
  const again = R.plan(CFG, p.state, save(6, [rev(5, 5), rev(5, 4)]), sec(320));
  assert.deepEqual(again.add, []);
  assert.equal(again.changed, false);
});

test('anti-farm: a game day under 200 s, a day over 60 reviews, 100 per Vietnam day, 2.800 per season', () => {
  const start = R.plan(CFG, null, save(1), T0).state;
  // Day 1 done in 150 s: dropped.
  let p = R.plan(CFG, start, save(2, [rev(1, 5), rev(1, 5)]), sec(150));
  assert.deepEqual(p.add, []);
  assert.equal(p.dropped.short, 2);
  // Three days in 500 s: under 3 x 200, all dropped.
  p = R.plan(CFG, p.state, save(5, [rev(2, 5), rev(3, 5), rev(4, 5)]), sec(650));
  assert.equal(p.dropped.short, 3);
  // 61 reviews in one day: that day counts 0.
  p = R.plan(CFG, p.state, save(6, Array.from({ length: 61 }, () => rev(5, 5))), sec(900));
  assert.equal(p.dropped.busy, 61);
  assert.deepEqual(p.add, []);
  // 60 then 60 on the same Vietnam day: 100 counted.
  p = R.plan(CFG, p.state, save(7, Array.from({ length: 60 }, () => rev(6, 4))), sec(1200));
  assert.equal(p.add.length, 60);
  p = R.plan(CFG, p.state, save(8, Array.from({ length: 60 }, () => rev(7, 4))), sec(1500));
  assert.equal(p.add.length, 40);
  assert.equal(p.dropped.cap, 20);
  // Next Vietnam day: counts again.
  p = R.plan(CFG, p.state, save(9, [rev(8, 5)]), sec(86400));
  assert.deepEqual(p.add, [5]);
  // Season cap.
  const full = { ...p.state, v: 2800 };
  p = R.plan(CFG, full, save(10, [rev(9, 5)]), sec(86400 + 300));
  assert.deepEqual(p.add, []);
});

test('plan: outside the season nothing counts; a new season starts from 0; bad reviews ignored', () => {
  const before = new Date('2026-11-01T03:00:00Z');
  let p = R.plan(CFG, null, save(3), before);
  p = R.plan(CFG, p.state, save(4, [rev(3, 5)]), new Date(before.getTime() + 600000));
  assert.deepEqual(p.add, []);
  const old = { day: 3, dayAt: T0, period: 'rating-1', v: 900, sum: 4000, capDate: '2026-11-10', capCount: 0 };
  p = R.plan(CFG, old, save(4, [rev(3, 5), rev(3, 9), rev(3, 0), { day: 3 }, { day: 'x', stars: 5 }]), sec(400));
  assert.equal(p.state.period, 'rating-2');
  assert.equal(p.state.v, 1);
  assert.deepEqual(p.add, [5]);
});

test('ingest: only the server writes the row; score, sortKey, name filtered, avatar from player_avatars', async () => {
  const db = new FakeFirestore();
  db.seed('player_avatars/u1', { path: 'minh_anh', rev: 1 });
  const filter = defaultFilter();
  const go = (progress, at) => R.ingest({ db, eco: ECO, uid: 'u1', progress, now: at, filter });
  await go(save(1), T0);
  assert.equal(db.read('rating_board/rating-2/entries/u1'), undefined);
  const day1 = Array.from({ length: 50 }, () => rev(1, 5));
  assert.deepEqual(await go(save(2, day1), sec(400)), { counted: 50 });
  const e = db.read('rating_board/rating-2/entries/u1');
  assert.equal(e.v, 50);
  assert.equal(e.sum, 250);
  assert.equal(e.avatar, 'minh_anh');
  assert.equal(e.displayName, 'Tiệm Lan');
  assert.equal(Math.round(e.score * 1000), Math.round(((250 + 400) / 150) * 1000));
  assert.ok(e.sortKey > 0);
  assert.deepEqual(db.read('rating_board/rating-2'), { totalV: 50, totalSum: 250, C: 4, updatedAt: sec(400) });
  // A refused shop name shows the fallback.
  await go(save(3, [rev(2, 4)], { shopName: 'địt mẹ' }), sec(800));
  assert.equal(db.read('rating_board/rating-2/entries/u1').displayName, 'Chủ tiệm');
  // Under 50: on the store, sortKey 0 (not on the board).
  await R.ingest({ db, eco: ECO, uid: 'u2', progress: save(1), now: T0, filter });
  await R.ingest({ db, eco: ECO, uid: 'u2', progress: save(2, [rev(1, 5)]), now: sec(400), filter });
  assert.equal(db.read('rating_board/rating-2/entries/u2').sortKey, 0);
});

test('refresh: C moves to the season average from 2.000 reviews and every row is rescored', async () => {
  const db = new FakeFirestore();
  db.seed('rating_board/rating-2', { totalV: 1999, totalSum: 1999 * 4.5, C: 4 });
  db.seed('rating_board/rating-2/entries/a', { v: 100, sum: 480, score: 4.4, sortKey: 1, reachedAt: T0 });
  assert.deepEqual(await R.refresh({ db, eco: ECO, now: sec(60) }), { rescored: 0, C: 4 });
  db.seed('rating_board/rating-2', { totalV: 2000, totalSum: 9000, C: 4 });
  const out = await R.refresh({ db, eco: ECO, now: sec(120) });
  assert.equal(out.C, 4.5);
  assert.equal(out.rescored, 1);
  const a = db.read('rating_board/rating-2/entries/a');
  assert.equal(a.score, (480 + 450) / 200);
  assert.equal(a.sortKey, R.sortKey(CFG, 100, a.score));
  assert.deepEqual(a.reachedAt, sec(120));
  assert.equal(db.read('rating_board/rating-2').C, 4.5);
});

test('shared season clock: rating-2 from Mon 09/11 0h VN, then rating-3, rating-4 every 28 days', () => {
  const before = R.ratingConfig(ECO, new Date('2026-11-08T16:59:59Z'));
  assert.equal(before.period, 'rating-2', 'the first season, not started yet');
  assert.ok(before.start.getTime() > new Date('2026-11-08T16:59:59Z').getTime());
  const s3 = R.ratingConfig(ECO, new Date('2026-12-06T17:00:00Z'));
  assert.equal(s3.period, 'rating-3');
  assert.equal(s3.seasonNumber, 3);
  assert.equal(s3.start.toISOString(), '2026-12-06T17:00:00.000Z');
  assert.equal(s3.end.toISOString(), '2027-01-03T17:00:00.000Z');
  assert.equal(R.ratingConfig(ECO, new Date('2027-01-03T17:00:00Z')).period, 'rating-4');
  // On the Mị lực clock: season 2 of both boards starts the same instant.
  const { loadEconomy } = require('./charm');
  const charm = loadEconomy(ECO);
  assert.equal(charm.periodAt(CFG.start), 'season-2');
  assert.equal(charm.periodAt(new Date(CFG.start.getTime() - 1)), 'season-1');
});

test('a save in a new season counts on the new board, from zero', async () => {
  const db = new FakeFirestore();
  const s3 = new Date('2026-12-07T03:00:00Z');
  const at = (t, s) => new Date(t.getTime() + s * 1000);
  const run = (progress, now) => R.ingest({ db, eco: ECO, uid: 'u1', progress, now, filter: defaultFilter() });
  await run(save(1), at(s3, 0));
  await run(save(2, [rev(1, 5), rev(1, 4)]), at(s3, 300));
  const e = db.read('rating_board/rating-3/entries/u1');
  assert.equal(e.v, 2);
  assert.equal(db.read('rating_board/rating-2/entries/u1'), undefined);
});
