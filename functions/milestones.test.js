'use strict';
// Customers-served milestone titles (milestones.js).
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const M = require('./milestones');
const T = require('./titles');

const ECO = require('./economy.json');
const CFG = M.milestoneConfig(ECO);
const T0 = new Date('2026-11-20T03:00:00Z'); // 10:00 VN
const after = (s) => new Date(T0.getTime() + s * 1000);
const save = (day, sold) => ({ day, lifetimeBouquetsSold: sold });

test('economy.json: tiers and limits copied from block v2 milestoneTitles', () => {
  assert.deepEqual(CFG.tiers, [
    { id: 'title_khach_1k', name: 'Người Bán Hoa Tận Tâm', threshold: 1000 },
    { id: 'title_khach_10k', name: 'Chủ Shop Được Yêu Mến', threshold: 10000 },
    { id: 'title_khach_100k', name: 'Chủ Shop Huyền Thoại', threshold: 100000 },
  ]);
  assert.equal(CFG.daySeconds, 200);
  assert.equal(CFG.perGameDay, 60);
  assert.equal(CFG.perRealDay, 3000);
  assert.equal(ECO.milestoneTitles.permanent, true);
  assert.equal(M.milestoneConfig({}), null);
  assert.throws(() => M.milestoneConfig({ milestoneTitles: { tiers: [], serverCheck: {} } }));
});

test('first save: starts at min(sold, 60 x days played)', () => {
  let p = M.plan(CFG, null, save(21, 2000), T0); // 20 days played -> 1200
  assert.equal(p.state.counted, 1200);
  assert.equal(p.seeded, true);
  p = M.plan(CFG, null, save(21, 500), T0);
  assert.equal(p.state.counted, 500);
  p = M.plan(CFG, null, save(1, 0), T0);
  assert.equal(p.state.counted, 0);
  assert.equal(M.plan(CFG, null, save(0, 10), T0).state, null, 'no day, no state');
});

test('a later day adds the new customers; 200 s per day, 60 per day, else nothing', () => {
  const st = M.plan(CFG, null, save(5, 100), T0).state; // 4 days -> 100
  // one day in 250 s, 40 customers: counted
  let p = M.plan(CFG, st, save(6, 140), after(250));
  assert.equal(p.add, 40);
  assert.equal(p.state.counted, 140);
  // one day in 150 s: too short, nothing, baseline still moves
  p = M.plan(CFG, st, save(6, 140), after(150));
  assert.equal(p.add, 0);
  assert.equal(p.dropped.short, 40);
  assert.equal(p.state.sold, 140);
  assert.equal(p.state.note, 'short');
  // two days in 500 s with 200 customers: at most 120 (aggregate cap)
  p = M.plan(CFG, st, save(7, 300), after(500));
  assert.equal(p.add, 120);
  assert.equal(p.dropped.busy, 80);
  // same day again: nothing; a lower day (new game) restarts the baseline
  p = M.plan(CFG, st, save(5, 130), after(900));
  assert.equal(p.add, 0);
  assert.equal(p.changed, false);
  p = M.plan(CFG, { ...st, counted: 100 }, save(1, 0), after(900));
  assert.equal(p.state.counted, 100, 'a new game keeps what was counted');
  assert.equal(p.state.sold, 0);
  assert.equal(p.state.day, 1);
});

test('at most 3.000 per Vietnam day; the next day starts again', () => {
  const st = { day: 100, dayAt: T0, sold: 0, counted: 0, capDate: M.vnDate(T0), capCount: 2990 };
  let p = M.plan(CFG, st, save(101, 50), after(300));
  assert.equal(p.add, 10);
  assert.equal(p.dropped.cap, 40);
  assert.equal(p.state.note, 'cap');
  const nextDay = new Date(T0.getTime() + 24 * 3600 * 1000);
  p = M.plan(CFG, st, save(101, 50), nextDay);
  assert.equal(p.add, 50);
  assert.equal(p.state.capCount, 50);
});

test('ingest: count on the profile, permanent titles once, retro flag from the start', async () => {
  const db = new FakeFirestore();
  let out = await M.ingest({ db, eco: ECO, uid: 'u1', progress: save(30, 1500), now: T0 });
  assert.deepEqual(out, { counted: 1500, add: 1500, awarded: ['title_khach_1k'] });
  const prof = db.read('public_profiles/u1');
  assert.equal(prof.customers, 1500);
  assert.deepEqual(prof.titleStats.title_khach_1k, { permanent: true, since: T0, threshold: 1000, retro: true });
  // later days: count grows, the title is not given twice
  out = await M.ingest({ db, eco: ECO, uid: 'u1', progress: save(31, 1550), now: after(300) });
  assert.deepEqual(out, { counted: 1550, add: 50, awarded: [] });
  assert.equal(db.read('public_profiles/u1').customers, 1550);
  assert.equal(db.read('public_profiles/u1').titleStats.title_khach_1k.retro, true);
  // a permanent title is held and can be pinned (titles.js)
  assert.deepEqual(await T.pin({ db, uid: 'u1', data: { id: 'title_khach_1k' } }), { pinnedTitle: 'title_khach_1k' });
  await assert.rejects(T.pin({ db, uid: 'u1', data: { id: 'title_khach_10k' } }), /bad-id/);
});

test('ingest: reaching a tier while playing is not retro; other fields stay', async () => {
  const db = new FakeFirestore();
  db.seed('public_profiles/u2', { pinnedTitle: 'de_nhat_goi_hoa', titleStats: { de_nhat_goi_hoa: { timesWon: 2 } } });
  db.seed('milestone_state/u2', { day: 50, dayAt: T0, sold: 990, counted: 990, capDate: M.vnDate(T0), capCount: 0 });
  const out = await M.ingest({ db, eco: ECO, uid: 'u2', progress: save(51, 1010), now: after(400) });
  assert.deepEqual(out.awarded, ['title_khach_1k']);
  const prof = db.read('public_profiles/u2');
  assert.equal(prof.titleStats.title_khach_1k.retro, false);
  assert.equal(prof.titleStats.de_nhat_goi_hoa.timesWon, 2);
  assert.equal(prof.pinnedTitle, 'de_nhat_goi_hoa');
});

test('first seed (lazy, retro): a player past all 3 milestones gets all 3 in one run', async () => {
  const db = new FakeFirestore();
  // Hà Phương 18/10: no backfill; the first users/{uid} write seeds. 2.001 game
  // days played -> seed min(150.000, 60 x 2.000 = 120.000) = 120.000.
  const out = await M.ingest({ db, eco: ECO, uid: 'old', progress: save(2001, 150000), now: T0 });
  assert.equal(out.counted, 120000);
  assert.deepEqual(out.awarded, ['title_khach_1k', 'title_khach_10k', 'title_khach_100k']);
  const stats = db.read('public_profiles/old').titleStats;
  for (const [id, threshold] of [['title_khach_1k', 1000], ['title_khach_10k', 10000], ['title_khach_100k', 100000]]) {
    assert.deepEqual(stats[id], { permanent: true, since: T0, threshold, retro: true });
  }
  // Past 2 of 3: exactly those 2.
  const db2 = new FakeFirestore();
  const two = await M.ingest({ db: db2, eco: ECO, uid: 'mid', progress: save(1001, 20000), now: T0 });
  assert.deepEqual(two.awarded, ['title_khach_1k', 'title_khach_10k']);
  const again = await M.ingest({ db: db2, eco: ECO, uid: 'mid', progress: save(1001, 20000), now: after(60) });
  assert.deepEqual(again.awarded, [], 'a second write of the same save gives nothing twice');
});
