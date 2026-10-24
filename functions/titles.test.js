'use strict';
// Champion titles (titles.js): one holder per title, transfer at each
// season's payout, titleStats counts, pins, titleRelease, best ranks.
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const T = require('./titles');
const RP = require('./rating_payout');
const P = require('./payout');
const { ratingConfig } = require('./rating_board');
const { loadEconomy } = require('./charm');

const ECO = require('./economy.json');
const NOW = new Date('2026-12-07T00:10:00Z');
const RT = T.titleConfig(ECO, 'review');
const CT = T.titleConfig(ECO, 'charm');

test('economy.json: the two titles, names copied from Hà Phương block v2', () => {
  const { chat, ...rt } = RT;
  const { chat: chat2, ...ct } = CT;
  assert.deepEqual(rt, { id: 'de_nhat_goi_hoa', board: 'review', name: 'Đệ Nhất Gói Hoa', rank: 1 });
  assert.deepEqual(ct, { id: 'mi_luc_nhat_troi', board: 'charm', name: 'Mị Lực Nhất Trời', rank: 1 });
  assert.equal(chat.frames.length, 6, 'the chat frames ride along (title loss)');
  assert.deepEqual(chat2, chat);
  assert.equal(ECO.ratingBoard.rewards[0].badge, 'Đệ Nhất Gói Hoa');
  assert.equal(ECO.ratingBoard.championTitle.keepIfWinAgain, true);
  assert.equal(ECO.leaderboard.championTitle.board, 'charmBoard');
  assert.deepEqual(loadEconomy(ECO).championTitle, CT);
  assert.equal(T.titleConfig({ ratingBoard: {} }, 'review'), null, 'no block, no title');
  assert.equal(T.titleConfig({ leaderboard: { championTitle: { name: ' ' } } }, 'charm'), null);
});

test('the title moves to each new #1; the old holder keeps its count and loses its pin', async () => {
  const db = new FakeFirestore();
  const t = (uid, period) => T.transferTitle(db, RT, { uid, period, seasonEnd: NOW, now: NOW });
  assert.deepEqual(await t('a', 'rating-2'), { counted: true, moved: true });
  assert.deepEqual(await T.pin({ db, uid: 'a', data: { id: 'de_nhat_goi_hoa' } }), { pinnedTitle: 'de_nhat_goi_hoa' });
  // Rerun of the same season: nothing changes.
  assert.deepEqual(await t('a', 'rating-2'), { counted: false, moved: false });
  assert.equal(db.read('public_profiles/a').titleStats.de_nhat_goi_hoa.timesWon, 1);
  // a wins again: keeps it, ×2, still pinned.
  await t('a', 'rating-3');
  assert.equal(db.read('titles/de_nhat_goi_hoa').holderUid, 'a');
  assert.equal(db.read('public_profiles/a').titleStats.de_nhat_goi_hoa.timesWon, 2);
  assert.equal(db.read('public_profiles/a').pinnedTitle, 'de_nhat_goi_hoa');
  // b wins: b holds it, a is unpinned but keeps ×2.
  await t('b', 'rating-4');
  assert.equal(db.read('titles/de_nhat_goi_hoa').holderUid, 'b');
  assert.equal(db.read('titles/de_nhat_goi_hoa').period, 'rating-4');
  assert.equal(db.read('public_profiles/a').pinnedTitle, '');
  assert.deepEqual(db.read('public_profiles/a').titleStats.de_nhat_goi_hoa,
    { timesWon: 2, lastPeriod: 'rating-3', periods: ['rating-2', 'rating-3'] });
  await assert.rejects(T.pin({ db, uid: 'a', data: { id: 'de_nhat_goi_hoa' } }), { code: 'not-held' });
  // A late release of an older season counts for c but never takes it back.
  assert.deepEqual(await t('c', 'rating-3'), { counted: true, moved: false });
  assert.equal(db.read('titles/de_nhat_goi_hoa').holderUid, 'b');
  assert.equal(db.read('public_profiles/c').titleStats.de_nhat_goi_hoa.timesWon, 1);
  // The two boards are separate titles.
  await T.transferTitle(db, CT, { uid: 'a', period: 'season-1', seasonEnd: NOW, now: NOW });
  assert.equal(db.read('titles/mi_luc_nhat_troi').holderUid, 'a');
  assert.equal(db.read('titles/mi_luc_nhat_troi').board, 'charm');
  assert.equal(db.read('titles/de_nhat_goi_hoa').holderUid, 'b');
  assert.equal(await T.transferTitle(db, null, { uid: 'a', period: 'season-1', now: NOW }), null);
});

test('the holder who lost it gets Nhất\'s mail once; no mail to a holder winning again or a vacant title', async () => {
  const db = new FakeFirestore();
  const t = (uid, period) => T.transferTitle(db, RT, { uid, period, seasonEnd: NOW, now: NOW });
  await t('a', 'rating-2');
  await t('a', 'rating-3');
  assert.equal([...db.docs.keys()].filter((k) => k.startsWith('mails/')).length, 0);
  assert.deepEqual(await t('b', 'rating-4'), { counted: true, moved: true, lostUid: 'a' });
  const mail = db.read('mails/title_lost_de_nhat_goi_hoa_rating-4_a');
  assert.deepEqual(mail, {
    title: 'Danh hiệu "Đệ Nhất Gói Hoa" đã sang chủ mới',
    body: 'Mùa mới đã có người đứng hạng 1. Danh hiệu "Đệ Nhất Gói Hoa" chuyển sang chủ mới; hồ sơ của bạn vẫn ghi lại các mùa bạn từng giữ.',
    target: 'a', rewards: { items: [] }, createdAt: NOW,
  });
  await t('b', 'rating-4');
  assert.equal([...db.docs.keys()].filter((k) => k.startsWith('mails/')).length, 1, 'a rerun sends nothing');
  // A vacant title (the holder deleted the account): nobody to tell.
  await db.doc('titles/de_nhat_goi_hoa').update({ holderUid: '' });
  assert.deepEqual(await t('c', 'rating-5'), { counted: true, moved: true });
  assert.equal(db.read('titles/de_nhat_goi_hoa').holderUid, 'c');
  assert.equal([...db.docs.keys()].filter((k) => k.startsWith('mails/')).length, 1);
});

test('titlePin: only a title held now (or a permanent one); unpin always works', async () => {
  const db = new FakeFirestore();
  await assert.rejects(T.pin({ db, uid: 'x', data: { id: 'de_nhat_goi_hoa' } }), { code: 'not-held' });
  await assert.rejects(T.pin({ db, uid: 'x', data: { id: 'nope' } }), { code: 'bad-id' });
  await assert.rejects(T.pin({ db, uid: 'x', data: { id: 'Bad Id!' } }), { code: 'bad-id' });
  await assert.rejects(T.pin({ db, uid: 'x', data: { id: 3 } }), { code: 'bad-id' });
  assert.deepEqual(await T.pin({ db, uid: 'x', data: {} }), { pinnedTitle: '' });
  assert.equal(db.read('public_profiles/x'), undefined, 'a player without titles gets no doc');
  // A permanent title (the coming milestones) is held for good.
  db.seed('public_profiles/m', { titleStats: { danh_hieu_1k: { permanent: true, since: NOW } } });
  assert.deepEqual(await T.pin({ db, uid: 'm', data: { id: 'danh_hieu_1k' } }), { pinnedTitle: 'danh_hieu_1k' });
  assert.deepEqual(await T.pin({ db, uid: 'm', data: { id: null } }), { pinnedTitle: '' });
  assert.equal(db.read('public_profiles/m').pinnedTitle, '');
});

test('titleRelease: admin only, a released #1 line, then the transfer', async () => {
  const db = new FakeFirestore();
  db.seed('rating_board/rating-2', { endsAt: NOW });
  db.seed('rating_board/rating-2/review/h', { rank: 1, status: 'held' });
  const call = (uid, period) => T.release({
    db, eco: ECO, uid, now: NOW, data: { period }, isAdmin: async (u) => u === 'admin',
  });
  await assert.rejects(call('h', 'rating-2'), { code: 'not-admin' });
  await assert.rejects(call('admin', 'x-2'), { code: 'bad-period' });
  await assert.rejects(call('admin', 'rating-2'), { code: 'not-released' });
  db.seed('rating_board/rating-2/review/h', { rank: 1, status: 'released' });
  assert.deepEqual(await call('admin', 'rating-2'), { uid: 'h', counted: true, moved: true });
  assert.equal(db.read('titles/de_nhat_goi_hoa').holderUid, 'h');
  assert.equal(db.read('titles/de_nhat_goi_hoa').seasonEnd.getTime(), NOW.getTime());
  db.seed('charm_board/season-1/review/k', { rank: 1, status: 'released' });
  assert.equal((await call('admin', 'season-1')).uid, 'k');
  assert.equal(db.read('titles/mi_luc_nhat_troi').holderUid, 'k');
});

test('best ranks only go down', async () => {
  const db = new FakeFirestore();
  assert.equal(await T.recordBestRanks(db, 'charm', 'season-1', [{ uid: 'a', rank: 7 }, { uid: 'b', rank: 0 }], NOW), 1);
  assert.equal(await T.recordBestRanks(db, 'charm', 'season-2', [{ uid: 'a', rank: 9 }], NOW), 0);
  assert.equal(await T.recordBestRanks(db, 'charm', 'season-3', [{ uid: 'a', rank: 2 }], NOW), 1);
  assert.equal(await T.recordBestRanks(db, 'review', 'rating-3', [{ uid: 'a', rank: 40 }], NOW), 1);
  assert.deepEqual(db.read('public_profiles/a').bestRank, {
    charm: { rank: 2, period: 'season-3', at: NOW }, review: { rank: 40, period: 'rating-3', at: NOW },
  });
});

test('payouts keep public_profiles fields they do not own (day from the save)', async () => {
  const db = new FakeFirestore();
  db.seed('public_profiles/a', { day: 37, updatedAt: NOW });
  await T.transferTitle(db, RT, { uid: 'a', period: 'rating-2', seasonEnd: NOW, now: NOW });
  await T.recordBestRanks(db, 'review', 'rating-2', [{ uid: 'a', rank: 1 }], NOW);
  assert.equal(db.read('public_profiles/a').day, 37);
  assert.ok(db.read('public_profiles/a').titleStats);
});

// Silence unused-import lint for helpers kept for the payout tests below.
void RP; void P; void ratingConfig;
