'use strict';
// node --test payout.test.js   (from functions/). Runs the scheduled payout
// against an in-memory Firestore.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { loadEconomy, rewardFor } = require('./charm');
const { FakeFirestore } = require('./fake_firestore');
const {
  nextPeriodKey, rewardItems, ensureSeasonMetas, runPayout, GRACE_MS, MAIL_TITLE,
} = require('./payout');

const economyPath = fs.existsSync(path.join(__dirname, 'economy.json'))
  ? path.join(__dirname, 'economy.json')
  : path.join(__dirname, '..', 'assets', 'data', 'economy.json');
const eco = loadEconomy(JSON.parse(fs.readFileSync(economyPath, 'utf8')));
const fixture = JSON.parse(fs.readFileSync(
  path.join(__dirname, '..', 'test', 'fixtures', 'charm_rewards_fixture.json'), 'utf8'));

const START = eco.seasonStart; // 2026-10-12 00:00 Vietnam
const END = new Date(START.getTime() + eco.cycleDays * 86400000);
const AFTER = new Date(END.getTime() + GRACE_MS + 60000); // 1 min past the grace
const dice = () => 0; // the first item of the tier

const save = (id, stage, worn = {}) => ({
  petCharm: id,
  pets: [{ id, stage, ...(Object.keys(worn).length ? { worn } : {}) }],
});
const at = (min) => new Date(START.getTime() + min * 60000);

/** A database with the season meta, and players p{i} with the given charm. */
function world(players) {
  const db = new FakeFirestore();
  db.seed('charm_board/season-1', { startsAt: START, endsAt: END });
  for (const p of players) {
    db.seed(`charm_board/season-1/entries/${p.uid}`, {
      uid: p.uid, displayName: p.name || p.uid, avatar: '',
      charm: p.stored, petId: 'kim_long', stage: 2, worn: {},
      updatedAt: at(p.reached || 10), reachedAt: at(p.reached || 10),
    });
    if (p.progress !== null) {
      db.seed(`users/${p.uid}`, { progress: p.progress || save('kim_long', 2), ...(p.joinedAt ? { joinedAt: p.joinedAt } : {}) });
    }
  }
  return db;
}
const run = (db, extra = {}) => runPayout({
  db, eco, now: AFTER, random: dice, authCreated: async () => new Map(), ...extra,
});
const mails = (db) => [...db.docs.keys()].filter((k) => k.startsWith('mails/'));
const review = (db, uid) => db.read(`charm_board/season-1/review/${uid}`);

test('nextPeriodKey', () => {
  assert.equal(nextPeriodKey('season-1'), 'season-2');
  assert.equal(nextPeriodKey('season-9'), 'season-10');
  assert.equal(nextPeriodKey('mua'), null);
});

test('ensureSeasonMetas creates the live and the next season once, never edits one', async () => {
  const db = new FakeFirestore();
  const made = await ensureSeasonMetas({ db, eco, now: AFTER });
  assert.deepEqual(made, ['season-1', 'season-2']);
  assert.deepEqual(db.read('charm_board/season-1').endsAt, END);
  assert.deepEqual(db.read('charm_board/season-2').startsAt, END);
  assert.deepEqual(
    db.read('charm_board/season-2').endsAt,
    new Date(END.getTime() + 28 * 86400000));
  // The admin moves the end of season 1; a later run keeps it.
  const edited = new Date(END.getTime() + 3600000);
  await db.doc('charm_board/season-1').set({ endsAt: edited }, { merge: true });
  assert.deepEqual(await ensureSeasonMetas({ db, eco, now: AFTER }), []);
  assert.deepEqual(db.read('charm_board/season-1').endsAt, edited);
});

test('nothing is paid before the end plus the 5 minute grace', async () => {
  const db = world([{ uid: 'a', stored: 300 }]);
  const early = new Date(END.getTime() + GRACE_MS - 1000);
  const r = await runPayout({ db, eco, now: early, random: dice });
  assert.deepEqual(r.paid, {});
  assert.equal(mails(db).length, 0);
  const at5 = new Date(END.getTime() + GRACE_MS);
  const r2 = await runPayout({ db, eco, now: at5, random: dice });
  assert.equal(r2.paid['season-1'].sent, 1);
});

test('ranked rows get one mail each, bundle by rank, id bxh_{period}_{uid}', async () => {
  const players = [
    { uid: 'p1', stored: 300, reached: 5 },
    { uid: 'p2', stored: 305, reached: 6, progress: save('kim_long', 2, { neck: 'no_co_vai' }) },
    { uid: 'p3', stored: 300, reached: 4 }, // ties p1 but got there first
  ];
  const db = world(players);
  const r = await run(db);
  assert.equal(r.paid['season-1'].status, 'done');
  assert.equal(r.paid['season-1'].sent, 3);
  const m = (u) => db.read(`mails/bxh_season-1_${u}`);
  // p2 305 is rank 1; then p3 (earlier) rank 2, p1 rank 3.
  assert.equal(m('p2').rewards.items.length, 3);
  assert.deepEqual(m('p2').rewards.items[0], { kind: 'phaLe', amount: 100 });
  assert.deepEqual(m('p2').rewards.items[1], { kind: 'giotHoa', amount: 20 });
  assert.deepEqual(m('p2').rewards.items[2], { kind: 'petItem', id: 'day_chuyen_suong_mai', amount: 1 });
  assert.match(m('p3').body, /hạng 2 ở bảng xếp hạng Mị lực mùa season-1/);
  assert.match(m('p1').body, /hạng 3 /);
  assert.deepEqual(m('p3').rewards.items[0], { kind: 'phaLe', amount: 70 });
  assert.equal(m('p3').title, MAIL_TITLE);
  assert.equal(m('p3').target, 'p3');
  assert.deepEqual(m('p3').createdAt, AFTER);
  assert.equal(review(db, 'p2').status, 'sent');
  assert.equal(review(db, 'p2').rank, 1);
});

test('rerunning never doubles a reward (create if absent)', async () => {
  const db = world([{ uid: 'a', stored: 300 }, { uid: 'b', stored: 300, reached: 11 }]);
  await run(db);
  const before = JSON.stringify(db.read('mails/bxh_season-1_a'));
  // Force a second pass by clearing the done mark, and use other dice.
  await db.doc('charm_board/season-1').set({ payout: { status: 'partial' } }, { merge: true });
  const r = await run(db, { random: () => 0.99 });
  assert.equal(r.paid['season-1'].created, 0);
  assert.equal(r.paid['season-1'].sent, 2);
  assert.equal(JSON.stringify(db.read('mails/bxh_season-1_a')), before);
  assert.equal(mails(db).length, 2);
  // A finished period is skipped altogether.
  const again = await run(db);
  assert.deepEqual(again.paid, {});
});

test('under 20, no save, no progress and no pet are dropped from the board, no reward', async () => {
  const db = world([
    { uid: 'ok', stored: 300 },
    { uid: 'weak', stored: 300, progress: save('ca_chep', 0) }, // 10
    { uid: 'nosave', stored: 300, progress: null },
    { uid: 'nopro', stored: 300, progress: undefined },
    { uid: 'nopet', stored: 300, progress: { petCharm: null, pets: [] } },
  ]);
  db.seed('users/nopro', {});
  const r = await run(db);
  assert.equal(r.paid['season-1'].sent, 1);
  assert.equal(r.paid['season-1'].skipped, 4);
  assert.deepEqual(mails(db), ['mails/bxh_season-1_ok']);
  for (const u of ['weak', 'nosave', 'nopro', 'nopet']) {
    assert.equal(db.read(`charm_board/season-1/entries/${u}`), undefined, `${u} off the board`);
    assert.equal(review(db, u).status, 'skipped');
  }
  assert.equal(review(db, 'weak').reason, 'under_min');
  assert.equal(review(db, 'nosave').reason, 'no_save');
  assert.equal(review(db, 'nopro').reason, 'no_save');
  assert.equal(review(db, 'nopet').reason, 'no_pet');
  assert.ok(db.read('charm_board/season-1/entries/ok'));
});

test('anomalies are held, not paid: mismatch, over the cap, a new account', async () => {
  const db = world([
    { uid: 'clean', stored: 300, reached: 1 },
    { uid: 'liar', stored: 340, reached: 2 }, // the save backs 300
    { uid: 'capped', stored: 700, reached: 3 },
    { uid: 'newbie', stored: 300, reached: 4 },
    { uid: 'joined', stored: 300, reached: 5, joinedAt: at(100) },
    { uid: 'old', stored: 300, reached: 6, joinedAt: at(-100000) },
  ]);
  const created = new Map([
    ['newbie', at(60)], // inside the season
    ['clean', at(-500000)], ['liar', at(-500000)], ['capped', at(-500000)],
    ['old', at(-500000)],
  ]);
  const r = await run(db, { authCreated: async () => created });
  assert.equal(r.paid['season-1'].held, 4);
  assert.equal(r.paid['season-1'].sent, 2);
  assert.deepEqual(mails(db).sort(), ['mails/bxh_season-1_clean', 'mails/bxh_season-1_old']);
  assert.deepEqual(review(db, 'liar').flags, ['mismatch']);
  assert.equal(review(db, 'liar').stored, 340);
  assert.equal(review(db, 'liar').recomputed, 300);
  assert.deepEqual(review(db, 'capped').flags, ['mismatch', 'over_cap']);
  assert.deepEqual(review(db, 'newbie').flags, ['new_account']);
  // No Auth time for joined: users/{uid}.joinedAt is the fallback.
  assert.deepEqual(review(db, 'joined').flags, ['new_account']);
  assert.equal(review(db, 'old').status, 'sent');
  // Held rows keep their rank (the others' ranks do not move) and the board
  // row is overwritten with the recomputed score.
  assert.equal(review(db, 'liar').rank > 0, true);
  assert.equal(db.read('charm_board/season-1/entries/liar').charm, 300);
  assert.equal(db.read('charm_board/season-1/entries/capped').charm, 300);
});

test('a row the admin released stays released on a rerun', async () => {
  const db = world([{ uid: 'liar', stored: 340 }]);
  await run(db);
  assert.equal(review(db, 'liar').status, 'held');
  await db.doc('charm_board/season-1/review/liar').set({ ...review(db, 'liar'), status: 'released' });
  await db.doc('charm_board/season-1').set({ payout: { status: 'partial' } }, { merge: true });
  await run(db);
  assert.equal(review(db, 'liar').status, 'released');
  assert.equal(mails(db).length, 0);
});

test('only the top 100 are rewarded, ties go to who got there first', async () => {
  const players = [];
  for (let i = 0; i < 105; i++) players.push({ uid: `u${String(i).padStart(3, '0')}`, stored: 300, reached: 10 + i });
  const db = world(players);
  const r = await run(db);
  assert.equal(r.paid['season-1'].sent, 100);
  assert.equal(mails(db).length, 100);
  assert.ok(db.read('mails/bxh_season-1_u000')); // first to get there: rank 1
  assert.ok(db.read('mails/bxh_season-1_u099')); // rank 100
  assert.equal(db.read('mails/bxh_season-1_u100'), undefined); // rank 101
  assert.deepEqual(db.read('mails/bxh_season-1_u099').rewards.items, [
    { kind: 'petItem', id: 'no_co_vai', amount: 1 },
  ]);
  assert.match(db.read('mails/bxh_season-1_u099').body, /hạng 100 /);
});

test('kill switch: autoPayout false pays nobody but still creates the season docs', async () => {
  const db = world([{ uid: 'a', stored: 300 }]);
  db.seed('config/charmPayout', { autoPayout: false });
  const r = await run(db);
  assert.equal(r.skipped, 'autoPayout-off');
  assert.equal(mails(db).length, 0);
  assert.ok(db.read('charm_board/season-2'));
  // Switched back on: the next tick pays.
  db.seed('config/charmPayout', { autoPayout: true });
  const r2 = await run(db);
  assert.equal(r2.paid['season-1'].sent, 1);
  // A missing doc means on (the default is true).
  const db2 = world([{ uid: 'a', stored: 300 }]);
  assert.equal((await run(db2)).paid['season-1'].sent, 1);
});

test('a mail that fails leaves the period partial and the next tick finishes it', async () => {
  const db = world([{ uid: 'a', stored: 300, reached: 1 }, { uid: 'b', stored: 300, reached: 2 }]);
  db.failCreate.add('mails/bxh_season-1_b');
  const r = await run(db);
  assert.equal(r.paid['season-1'].status, 'partial');
  assert.equal(r.paid['season-1'].failed, 1);
  assert.ok(db.read('mails/bxh_season-1_a'));
  db.failCreate.clear();
  const r2 = await run(db);
  assert.equal(r2.paid['season-1'].status, 'done');
  assert.equal(r2.paid['season-1'].created, 1);
  assert.ok(db.read('mails/bxh_season-1_b'));
  assert.equal(review(db, 'b').status, 'sent');
});

test('reward table parity with the Dart side (shared fixture)', () => {
  assert.equal(fixture.ranks.length, 101);
  for (const row of fixture.ranks) {
    const line = rewardFor(row.rank, eco);
    if (row.none) {
      assert.equal(line, null, `rank ${row.rank}`);
    } else {
      assert.equal(line.phaLe, row.phaLe, `rank ${row.rank} phaLe`);
      assert.equal(line.giotHoa, row.giotHoa, `rank ${row.rank} giotHoa`);
      assert.equal(line.petItemRarity, row.tier, `rank ${row.rank} tier`);
    }
  }
  assert.deepEqual(eco.itemsByTier, fixture.pools);
});

test('rewardItems: Pha lê, Giọt hoa, then one item of the tier; zero lines are left out', () => {
  const top = rewardItems(rewardFor(1, eco), eco, () => 0.99);
  assert.deepEqual(top, [
    { kind: 'phaLe', amount: 100 }, { kind: 'giotHoa', amount: 20 },
    { kind: 'petItem', id: 'canh_binh_minh', amount: 1 },
  ]);
  const last = rewardItems(rewardFor(51, eco), eco, () => 0.5);
  assert.deepEqual(last, [{ kind: 'petItem', id: 'mu_rom', amount: 1 }]);
  const mid = rewardItems(rewardFor(20, eco), eco, () => 0);
  assert.deepEqual(mid.map((i) => i.kind), ['phaLe', 'petItem']);
});