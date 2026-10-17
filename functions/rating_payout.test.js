'use strict';
// Season payout of Bảng Đánh giá (rating_payout.js) on the in-memory
// Firestore, with Hà Phương's ratingBoard.rewards from economy.json.
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const RP = require('./rating_payout');
const { ratingConfig } = require('./rating_board');
const { GRACE_MS } = require('./payout');

const ECO = require('./economy.json');
const S2 = ratingConfig(ECO, new Date('2026-11-10T00:00:00Z'));
const AFTER = new Date(S2.end.getTime() + GRACE_MS + 60000);
const mails = (db) => [...db.docs.keys()].filter((p) => p.startsWith('mails/')).sort();

/** n shops on rating-2, best first: sortKey falls with i. */
function world(n, extra = {}) {
  const db = new FakeFirestore();
  db.seed('rating_board/rating-2', { startsAt: S2.start, endsAt: S2.end });
  for (let i = 0; i < n; i++) {
    const uid = `u${String(i + 1).padStart(3, '0')}`;
    db.seed(`rating_board/rating-2/entries/${uid}`, {
      uid, displayName: `Tiệm ${i + 1}`, v: 60, sum: 290, score: 4.5,
      sortKey: 1000000 - i * 10, reachedAt: S2.start, updatedAt: S2.start,
    });
    db.seed(`users/${uid}`, { joinedAt: new Date('2026-01-01T00:00:00Z'), ...(extra[uid] || {}) });
  }
  return db;
}

test('economy.json ratingBoard.rewards: Hà Phương v2 table, no pet items', () => {
  const r = ECO.ratingBoard.rewards;
  assert.deepEqual(r.map((x) => [x.rankFrom, x.rankTo, x.phaLe, x.giotHoa, x.coins]), [
    [1, 1, 200, 20, 10000000], [2, 2, 140, 15, 7000000], [3, 3, 100, 10, 5000000],
    [4, 10, 60, 5, 3000000], [11, 50, 20, 0, 1000000], [51, 100, 0, 0, 500000],
  ]);
  assert.equal(r[0].badge, 'Tiệm 5 sao mùa');
  assert.ok(r.every((x) => !('petItemRarity' in x)));
  assert.equal(ECO.ratingBoard.minRatingsToRank, 50);
  assert.equal(ECO.ratingBoard.season.seasonStart, '2026-11-09');
  assert.equal(ECO.ratingBoard.season.cycleDays, 28);
  assert.equal(ECO.ratingBoard.season.autoChain, true);
});

test('the letters: Nhất mục 11, only non-zero items, #1 with the title', () => {
  const t = (rank) => RP.ratingMailText({ rank, line: RP.ratingRewardFor(rank, S2) });
  assert.deepEqual(t(1), {
    title: 'Thưởng mùa Đánh giá: hạng 1',
    body: 'Chúc mừng bạn đạt hạng 1 bảng Đánh giá mùa này! Quà của bạn: 200 Pha lê, 20 giọt hoa, 10.000.000 xu và danh hiệu "Tiệm 5 sao mùa".',
  });
  assert.equal(t(7).body, 'Chúc mừng bạn đạt hạng 7 bảng Đánh giá mùa này! Quà của bạn: 60 Pha lê, 5 giọt hoa và 3.000.000 xu.');
  assert.equal(t(30).body, 'Chúc mừng bạn đạt hạng 30 bảng Đánh giá mùa này! Quà của bạn: 20 Pha lê và 1.000.000 xu.');
  assert.equal(t(80).body, 'Chúc mừng bạn đạt hạng 80 bảng Đánh giá mùa này! Quà của bạn: 500.000 xu.');
  assert.equal(RP.ratingRewardFor(101, S2), null);
  assert.deepEqual(RP.ratingRewardItems(RP.ratingRewardFor(80, S2)), [{ kind: 'coins', amount: 500000 }]);
});

test('nothing is paid before the end plus the grace, then the top 100 once', async () => {
  const db = world(102);
  const early = await RP.runRatingPayout({ db, eco: ECO, now: new Date(S2.end.getTime() + GRACE_MS - 1000) });
  assert.deepEqual(early.paid, {});
  const r = await RP.runRatingPayout({ db, eco: ECO, now: AFTER });
  assert.equal(r.paid['rating-2'].sent, 100);
  assert.equal(mails(db).length, 100);
  const m1 = db.read('mails/bxh_rating-2_u001');
  assert.equal(m1.title, 'Thưởng mùa Đánh giá: hạng 1');
  assert.deepEqual(m1.rewards.items, [
    { kind: 'phaLe', amount: 200 }, { kind: 'giotHoa', amount: 20 }, { kind: 'coins', amount: 10000000 }]);
  assert.equal(m1.walletClaim, true);
  assert.equal(db.read('mails/bxh_rating-2_u080').walletClaim, undefined, 'xu only');
  assert.equal(db.read('mails/bxh_rating-2_u101'), undefined);
  assert.equal(db.read('rating_board/rating-2').champion, 'u001');
  assert.equal(db.read('rating_board/rating-2').payout.status, 'done');
  // A later tick pays nobody again.
  const again = await RP.runRatingPayout({ db, eco: ECO, now: new Date(AFTER.getTime() + 600000) });
  assert.deepEqual(again.paid, {});
  assert.equal(mails(db).length, 100);
});

test('rows under 50 reviews and the order: score, more reviews, earlier', async () => {
  const db = world(3);
  db.seed('rating_board/rating-2/entries/u002', { ...db.read('rating_board/rating-2/entries/u002'), v: 49, sortKey: 0 });
  db.seed('rating_board/rating-2/entries/u003', {
    ...db.read('rating_board/rating-2/entries/u003'), sortKey: 1000000, reachedAt: new Date(S2.start.getTime() - 1),
  });
  await RP.runRatingPayout({ db, eco: ECO, now: AFTER });
  assert.match(db.read('mails/bxh_rating-2_u003').title, /hạng 1$/);
  assert.match(db.read('mails/bxh_rating-2_u001').title, /hạng 2$/);
  assert.equal(db.read('mails/bxh_rating-2_u002'), undefined);
});

test('an account made inside the season is held for the admin, with its items', async () => {
  const db = world(2, { u001: { joinedAt: new Date(S2.start.getTime() + 86400000) } });
  const r = await RP.runRatingPayout({ db, eco: ECO, now: AFTER });
  assert.equal(r.paid['rating-2'].held, 1);
  assert.equal(db.read('mails/bxh_rating-2_u001'), undefined);
  const line = db.read('rating_board/rating-2/review/u001');
  assert.equal(line.status, 'held');
  assert.deepEqual(line.flags, ['new_account']);
  assert.equal(line.badge, 'Tiệm 5 sao mùa');
  assert.equal(line.items.length, 3);
  assert.equal(db.read('rating_board/rating-2').champion, undefined, 'the title waits for the admin');
  assert.match(db.read('mails/bxh_rating-2_u002').title, /hạng 2$/);
});

test('the kill switch stops the rating payout too', async () => {
  const db = world(1);
  db.seed('config/charmPayout', { autoPayout: false });
  const r = await RP.runRatingPayout({ db, eco: ECO, now: AFTER });
  assert.equal(r.skipped, 'autoPayout-off');
  assert.equal(mails(db).length, 0);
});
