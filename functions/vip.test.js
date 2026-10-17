'use strict';
// VIP (vip.js): tier from the top-up records, gift mails once per tier, the
// public tier, the hall, refunds, the backfill through walletSync.
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const G = require('./gacha');
const V = require('./vip');
const W = require('./wallet');
const IAP = require('./apple_iap');
const ECO = require('./economy.json');

const UID = 'u1';
const start = G.vnMidnight(ECO.gacha.rotationStart);
const at = (days) => new Date(start.getTime() + days * G.DAY_MS);
const WEEK0 = at(2);
const WEEK1 = at(9);
const ROT = ECO.gacha.weeklyRotation;
const filter = { allowsShopName: (s) => !/xấu/.test(s) };

function dbWith({ shopName = 'Tiệm Lan', phaLe = 0 } = {}) {
  const db = new FakeFirestore();
  db.seed(`users/${UID}`, { progress: { phaLe, shopName, day: 30 } });
  db.seed(`player_avatars/${UID}`, { path: 'minh_anh', rev: 1 });
  return db;
}
const order = (db, id, amount, extra = {}) => db.seed(`phale_orders/${id}`, { uid: UID, status: 'paid', amount, crystalsGranted: 100, ...extra });
const iap = (db, id, vnd, extra = {}) => db.seed(`phale_iap/${id}`, { uid: UID, phaLe: 100, packPriceVnd: vnd, environment: 'Production', mailId: `phale_iap_${id}`, ...extra });
const run = (db, now = WEEK0) => V.recompute({ db, eco: ECO, uid: UID, now, filter });
const mails = (db) => [...db.docs.keys()].filter((p) => p.startsWith(`mails/vip_${UID}_`)).sort();

test('economy.json vip: 10 tiers, thresholds and gifts as Hà Phương set them', () => {
  const t = V.tiers(ECO);
  assert.deepEqual(t.map((x) => x.minVnd), [50000, 200000, 500000, 1500000, 3000000, 5000000, 7000000, 10000000, 12500000, 15000000]);
  assert.deepEqual(t.map((x) => x.giftTickets), [5, 10, 20, 25, 30, 50, 50, 80, 100, 100]);
  assert.equal(t.reduce((s, x) => s + x.giftTickets, 0), ECO.vip.giftTicketsTotal);
  assert.equal(V.levelFor(ECO, 0), 0);
  assert.equal(V.levelFor(ECO, 49999), 0);
  assert.equal(V.levelFor(ECO, 50000), 1);
  assert.equal(V.levelFor(ECO, 14999999), 9);
  assert.equal(V.levelFor(ECO, 99999999), 10);
});

test('the total: paid bank orders + App Store not refunded, no sandbox, no other status', async () => {
  const db = dbWith();
  order(db, 'A', 200000);
  order(db, 'B', 100000, { status: 'pending' });
  order(db, 'C', 500000, { refundedAt: WEEK0 });
  iap(db, '1', 150000);
  iap(db, '2', 500000, { refundedAt: WEEK0 });
  iap(db, '3', 500000, { environment: 'Sandbox' });
  iap(db, '4', 500000, { uncredited: true });
  iap(db, '5', 50000, { environment: undefined });
  db.seed('phale_orders/OTHER', { uid: 'u2', status: 'paid', amount: 15000000 });
  const r = await run(db);
  assert.equal(r.vnd, 400000);
  assert.equal(r.level, 2);
  const w = db.read(`wallets/${UID}`);
  assert.equal(w.vipLevel, 2);
  assert.equal(w.vipVnd, 400000);
  assert.equal(w.vipMax, 2);
  assert.equal(w.vipVersion, V.VERSION);
  assert.equal(db.read(`player_avatars/${UID}`).vip, 2);
  assert.equal(db.read(`player_avatars/${UID}`).path, 'minh_anh', 'portrait kept');
  assert.equal(db.read(`player_avatars/${UID}`).vipVnd, undefined, 'never public');
});

test('one gift mail per tier reached, card of the pot of the week, sent once', async () => {
  const db = dbWith();
  order(db, 'A', 600000);
  const r = await run(db);
  assert.deepEqual(r.sent, [1, 2, 3]);
  assert.deepEqual(mails(db), [`mails/vip_${UID}_1`, `mails/vip_${UID}_2`, `mails/vip_${UID}_3`]);
  const m = db.read(`mails/vip_${UID}_3`);
  assert.equal(m.target, UID);
  assert.equal(m.walletClaim, true);
  assert.deepEqual(m.rewards, { items: [{ kind: 'ticket', amount: 20 }] });
  assert.equal(m.ticketPot, ROT[0]);
  assert.equal(m.title, 'Quà lên VIP 3');
  assert.match(m.body, /20 Thẻ gacha/);
  assert.match(m.body, /Thẻ gacha Cửu Vĩ Hồ/);
  // Again, nothing new.
  const again = await run(db, WEEK1);
  assert.deepEqual(again.sent, []);
  assert.equal(mails(db).length, 3);
  // More money a week later: tier 4, its card is of week 1's pot.
  order(db, 'B', 1000000);
  const up = await run(db, WEEK1);
  assert.deepEqual(up.sent, [4]);
  assert.equal(db.read(`mails/vip_${UID}_4`).ticketPot, ROT[1]);
});

test('before the first week the gift is a card of the first pot (claimable later)', async () => {
  const db = dbWith();
  order(db, 'A', 50000);
  await run(db, at(-3));
  const m = db.read(`mails/vip_${UID}_1`);
  assert.equal(m.ticketPot, ROT[0]);
  // Claimed through the wallet: the cards land on that pot.
  db.seed(`users/${UID}`, { progress: { phaLe: 0, shopName: 'Tiệm Lan', day: 30 } });
  const out = await W.claimMail({ db, eco: ECO, uid: UID, now: WEEK1, data: { mailId: `vip_${UID}_1` } });
  assert.equal(out.status, 'claimed');
  assert.deepEqual(out.credited.cards, { [ROT[0]]: 5 });
  const twice = await W.claimMail({ db, eco: ECO, uid: UID, now: WEEK1, data: { mailId: `vip_${UID}_1` } });
  assert.equal(twice.status, 'already');
  assert.equal(db.read(`wallets/${UID}`).cards[ROT[0]], 5);
});

test('a refund lowers the tier: notice mail, gifts kept, a lost VIP frame comes off, out of the hall', async () => {
  const db = dbWith();
  order(db, 'A', 15000000);
  await run(db);
  assert.ok(db.read(`vip_hall/${UID}`));
  db.seed(`player_avatars/${UID}`, { ...db.read(`player_avatars/${UID}`), frame: 'vip_ngoc_luc_bao', frameAt: WEEK0 });
  // Refunded by hand on the order.
  db.seed('phale_orders/A', { ...db.read('phale_orders/A'), refundedAt: WEEK1 });
  order(db, 'B', 600000);
  const r = await run(db, WEEK1);
  assert.equal(r.prev, 10);
  assert.equal(r.level, 3);
  assert.deepEqual(r.sent, []);
  const w = db.read(`wallets/${UID}`);
  assert.equal(w.vipLevel, 3);
  assert.equal(w.vipMax, 10);
  assert.equal(Object.keys(w.vipGifted).length, 10, 'gifts stay sent');
  const pub = db.read(`player_avatars/${UID}`);
  assert.equal(pub.vip, 3);
  assert.equal(pub.frame, '', 'VIP 9 frame taken off');
  assert.equal(db.read(`vip_hall/${UID}`), undefined);
  const down = [...db.docs.keys()].filter((p) => p.startsWith(`mails/vip_down_${UID}_`));
  assert.equal(down.length, 1);
  const body = db.read(down[0]).body;
  assert.match(body, /600\.000đ/);
  assert.match(body, /VIP 3/);
  assert.match(body, /anxaitech@gmail.com/);
  // Back to 10: no gift again, new hall date.
  order(db, 'C', 15000000);
  const back = await run(db, at(16));
  assert.equal(back.level, 10);
  assert.deepEqual(back.sent, []);
  assert.equal(db.read(`vip_hall/${UID}`).at.getTime(), at(16).getTime());
});

test('a frame still owned stays on after a drop', async () => {
  const db = dbWith();
  order(db, 'A', 1500000);
  await run(db);
  db.seed(`player_avatars/${UID}`, { ...db.read(`player_avatars/${UID}`), frame: 'vip_hoa_dao' });
  db.seed('phale_orders/A', { ...db.read('phale_orders/A'), amount: 500000 });
  await run(db, WEEK1);
  assert.equal(db.read(`player_avatars/${UID}`).frame, 'vip_hoa_dao');
});

test('the hall: name and portrait while VIP 10, hidden by the owner, date kept on recompute', async () => {
  const db = dbWith({ shopName: 'Tiệm Ngọc Lan' });
  order(db, 'A', 15000000);
  await run(db);
  let h = db.read(`vip_hall/${UID}`);
  assert.equal(h.name, 'Tiệm Ngọc Lan');
  assert.equal(h.avatar, 'minh_anh');
  assert.equal(h.hidden, false);
  assert.equal(h.at.getTime(), WEEK0.getTime());
  assert.equal(Object.keys(h).some((k) => /vnd|amount/i.test(k)), false);
  await V.setHallHidden({ db, eco: ECO, uid: UID, now: WEEK1, data: { hidden: true }, filter });
  h = db.read(`vip_hall/${UID}`);
  assert.equal(h.hidden, true);
  assert.equal(h.name, '');
  assert.equal(h.avatar, '');
  assert.equal(h.at.getTime(), WEEK0.getTime(), 'same date');
  await V.setHallHidden({ db, eco: ECO, uid: UID, now: WEEK1, data: { hidden: false }, filter });
  assert.equal(db.read(`vip_hall/${UID}`).name, 'Tiệm Ngọc Lan');
  await assert.rejects(V.setHallHidden({ db, eco: ECO, uid: UID, now: WEEK1, data: { hidden: 'yes' }, filter }), (e) => e.code === 'bad');
});

test('a name the filter refuses is left empty in the hall', async () => {
  const db = dbWith({ shopName: 'Tiệm xấu' });
  order(db, 'A', 15000000);
  await run(db);
  assert.equal(db.read(`vip_hall/${UID}`).name, '');
});

test('VIP fields before the first seed: walletSync seeds from the save and keeps them', async () => {
  const db = dbWith({ phaLe: 300 });
  order(db, 'A', 600000, { crystalsGranted: 300 });
  await run(db);
  assert.equal(db.read(`wallets/${UID}`).seededAt, undefined);
  const v = await W.sync({ db, eco: ECO, uid: UID, now: WEEK0, data: {}, filter });
  assert.equal(v.phaLe, 300, 'seeded from the save, not 0');
  assert.equal(v.vip.level, 3);
  const w = db.read(`wallets/${UID}`);
  assert.ok(w.seededAt);
  assert.equal(w.vipLevel, 3);
  assert.equal(Object.keys(w.vipGifted).length, 3);
});

test('backfill: an existing wallet without VIP gets its tier on the next walletSync', async () => {
  const db = dbWith();
  order(db, 'A', 3000000);
  db.seed(`wallets/${UID}`, { phaLe: 50, seededAt: WEEK0, cards: {}, pity: {}, items: {}, earned: {} });
  const v = await W.sync({ db, eco: ECO, uid: UID, now: WEEK0, data: {}, filter });
  assert.equal(v.vip.level, 5);
  assert.equal(v.vip.nextVnd, 5000000);
  assert.equal(v.phaLe, 50);
  assert.deepEqual(v.vip.pots, ['chau_ngoc_bich'], 'same view as the wallet calls');
  assert.equal(v.vip.badgeHidden, false);
  assert.equal(mails(db).length, 5);
  // Up to date: the next sync does not recompute (no new reads needed).
  db.seed('phale_orders/B', { uid: UID, status: 'paid', amount: 5000000 });
  const v2 = await W.sync({ db, eco: ECO, uid: UID, now: WEEK0, data: {}, filter });
  assert.equal(v2.vip.level, 5, 'the trigger does the rest');
});

test('an App Store refund with a VIP-only wallet doc takes from the save, not from 0', async () => {
  const db = dbWith({ phaLe: 500 });
  iap(db, 'T1', 50000, { phaLe: 200 });
  db.seed(`users/${UID}/mailState/phale_iap_T1`, { claimed: true });
  await run(db);
  const out = await IAP.applyAppleRefund({ db, transaction: { transactionId: 'T1' }, notificationType: 'REFUND', now: WEEK1 });
  assert.equal(out.result, 'balance');
  assert.equal(db.read(`users/${UID}`).progress.phaLe, 300);
  const r = await run(db, WEEK1);
  assert.equal(r.level, 0);
  assert.equal(db.read(`player_avatars/${UID}`).vip, 0);
});

test('a deleted account (no users doc) is left alone', async () => {
  const db = new FakeFirestore();
  db.seed('phale_orders/A', { uid: UID, status: 'paid', amount: 15000000 });
  const r = await run(db);
  assert.equal(r.skipped, 'no-user');
  assert.equal(db.read(`wallets/${UID}`), undefined);
  assert.equal(mails(db).length, 0);
});

test('touchedUids: only a change that can move a total', () => {
  const a = { uid: 'u1', status: 'pending', amount: 50000 };
  assert.deepEqual(V.touchedUids(null, a), ['u1']);
  assert.deepEqual(V.touchedUids(a, { ...a, qrImageUrl: 'x' }), []);
  assert.deepEqual(V.touchedUids(a, { ...a, status: 'paid' }), ['u1']);
  assert.deepEqual(V.touchedUids({ uid: 'u1', packPriceVnd: 1 }, { uid: 'u1', packPriceVnd: 1, refundedAt: new Date() }), ['u1']);
  assert.deepEqual(V.touchedUids({ uid: null }, { uid: 'u2' }), ['u2']);
});

test('admin recompute: admins only, one uid or every payer', async () => {
  const db = dbWith();
  order(db, 'A', 200000);
  db.seed('users/u2', { progress: { shopName: 'B' } });
  db.seed('phale_iap/X', { uid: 'u2', packPriceVnd: 500000, environment: 'Production' });
  const isAdmin = async (u) => u === 'boss';
  await assert.rejects(V.adminRecompute({ db, eco: ECO, uid: UID, now: WEEK0, data: { all: true }, filter, isAdmin }), (e) => e.code === 'not-admin');
  const one = await V.adminRecompute({ db, eco: ECO, uid: 'boss', now: WEEK0, data: { uid: UID }, filter, isAdmin });
  assert.deepEqual(one.results, { [UID]: 2 });
  const all = await V.adminRecompute({ db, eco: ECO, uid: 'boss', now: WEEK0, data: { all: true }, filter, isAdmin });
  assert.deepEqual(all.results, { [UID]: 2, u2: 3 });
  assert.equal(all.changed, 1);
  await assert.rejects(V.adminRecompute({ db, eco: ECO, uid: 'boss', now: WEEK0, data: {}, filter, isAdmin }), (e) => e.code === 'bad');
});

test('a chat message carries the VIP tier of player_avatars, never the app\'s', async () => {
  const chat = require('./world_chat');
  const { defaultFilter, defaultWordList } = require('./word_filter');
  const db = new FakeFirestore();
  db.seed('config/worldChat', { enabled: true });
  db.seed('users/u1', { progress: { day: 9, shopName: 'Tiệm Mai' } });
  db.seed('player_avatars/u1', { path: 'a.png', rev: 1, vip: 7 });
  const T = new Date('2026-10-17T03:00:00Z');
  const send = (text, now, data = {}) => chat.send({
    db, eco: ECO, uid: 'u1', now, data: { text, ...data }, filter: defaultFilter(), words: defaultWordList(),
  });
  const r = await send('chào cả nhà', T, { vip: 10 });
  assert.equal(db.read(`world_chat/${r.id}`).vip, 7);
  db.seed('player_avatars/u1', { path: 'a.png', rev: 1, vip: 0 });
  const r2 = await send('câu khác', new Date(T.getTime() + 20000));
  assert.equal('vip' in db.read(`world_chat/${r2.id}`), false);
});

test('VIP pots: owned from the server tier only (VIP 3 Ngọc Bích, VIP 6 Hoàng Kim)', async () => {
  assert.deepEqual(V.ownedVipPots(ECO, 0), []);
  assert.deepEqual(V.ownedVipPots(ECO, 2), []);
  assert.deepEqual(V.ownedVipPots(ECO, 3), ['chau_ngoc_bich']);
  assert.deepEqual(V.ownedVipPots(ECO, 6), ['chau_ngoc_bich', 'chau_hoang_kim']);
  assert.deepEqual(V.ownedVipPots(ECO, 10), ['chau_ngoc_bich', 'chau_hoang_kim']);
  // Both are pots of economy.json, decoration only, not sold.
  for (const id of ['chau_ngoc_bich', 'chau_hoang_kim']) {
    const p = ECO.pots.find((x) => x.id === id);
    assert.ok(p, id);
    assert.equal(p.set, 'vip');
    assert.equal(p.buyable, false);
    assert.equal(p.charm, 0);
    assert.deepEqual(p.stats, {});
  }
  // A save that claims a VIP pot does not make it owned.
  const db = dbWith();
  db.seed(`users/${UID}`, { progress: { phaLe: 0, shopName: 'Tiệm Lan', day: 30, potCounts: { chau_hoang_kim: 3 } } });
  order(db, 'o1', 500000);
  await run(db);
  const view = V.vipView(ECO, db.read(`wallets/${UID}`));
  assert.equal(view.level, 3);
  assert.deepEqual(view.pots, ['chau_ngoc_bich']);
});

test('Ẩn huy hiệu VIP: others see tier 0 and an anonymous hall row; the tier stays', async () => {
  const db = dbWith({ shopName: 'Tiệm Ngọc Lan' });
  order(db, 'A', 15000000);
  await run(db);
  assert.equal(db.read(`player_avatars/${UID}`).vip, 10);
  const r = await V.setBadgeHidden({ db, eco: ECO, uid: UID, now: WEEK1, data: { hidden: true }, filter });
  assert.equal(r.level, 10, 'tier unchanged');
  assert.equal(r.badgeHidden, true);
  assert.deepEqual(r.pots, ['chau_ngoc_bich', 'chau_hoang_kim'], 'perks unchanged');
  const pub = db.read(`player_avatars/${UID}`);
  assert.equal(pub.vip, 0);
  assert.equal(pub.vipAt, null);
  assert.equal(pub.path, 'minh_anh', 'portrait kept');
  const h = db.read(`vip_hall/${UID}`);
  assert.equal(h.hidden, true);
  assert.equal(h.name, '');
  assert.equal(h.at.getTime(), WEEK0.getTime(), 'place kept');
  const w = db.read(`wallets/${UID}`);
  assert.equal(w.vipLevel, 10);
  assert.equal(w.vipBadgeHidden, true);
  // A payment later still keeps it hidden.
  order(db, 'B', 50000);
  await run(db, at(12));
  assert.equal(db.read(`player_avatars/${UID}`).vip, 0);
  // Off again: tier and name back.
  await V.setBadgeHidden({ db, eco: ECO, uid: UID, now: at(13), data: { hidden: false }, filter });
  assert.equal(db.read(`player_avatars/${UID}`).vip, 10);
  assert.equal(db.read(`vip_hall/${UID}`).name, 'Tiệm Ngọc Lan');
  // The hall switch alone still works with the badge shown.
  assert.equal(db.read(`vip_hall/${UID}`).hidden, false);
  await assert.rejects(V.setBadgeHidden({ db, eco: ECO, uid: UID, now: WEEK1, data: {}, filter }), (e) => e.code === 'bad');
});

test('Ẩn huy hiệu VIP does not take the VIP avatar frame off', async () => {
  const db = dbWith();
  order(db, 'A', 5000000);
  await run(db);
  db.seed(`player_avatars/${UID}`, { ...db.read(`player_avatars/${UID}`), frame: 'vip_hoa_dao', frameAt: WEEK0 });
  await V.setBadgeHidden({ db, eco: ECO, uid: UID, now: WEEK1, data: { hidden: true }, filter });
  assert.equal(db.read(`player_avatars/${UID}`).vip, 0);
  assert.equal(db.read(`player_avatars/${UID}`).frame, 'vip_hoa_dao', 'frame stays');
  order(db, 'B', 50000);
  await run(db, at(12));
  assert.equal(db.read(`player_avatars/${UID}`).frame, 'vip_hoa_dao', 'still on after a recompute');
});

test('a chat message of a player with a hidden badge carries no tier', async () => {
  const db = dbWith();
  order(db, 'A', 5000000);
  await run(db);
  await V.setBadgeHidden({ db, eco: ECO, uid: UID, now: WEEK1, data: { hidden: true }, filter });
  assert.equal(db.read(`player_avatars/${UID}`).vip, 0);
});

// ---- bank refund ("Hoàn tiền" on /quan-tri) -----------------------------
const BR = require('./bank_refund');

function paidOrder(db, code, { amount = 500000, crystals = 6250 } = {}) {
  db.seed(`phale_orders/${code}`, {
    uid: UID, status: 'paid', amount, crystalsGranted: crystals, mailId: `phale_${code}`,
  });
  db.seed(`mails/phale_${code}`, { target: UID, title: 'Nạp Pha lê', rewards: { items: [{ kind: 'phaLe', amount: crystals }] } });
}

test('bank refund: an unclaimed credit mail is voided, the tier drops', async () => {
  const db = dbWith();
  paidOrder(db, 'R1', { amount: 500000 });
  await run(db);
  assert.equal(db.read(`wallets/${UID}`).vipLevel, 3);
  assert.equal(BR.needsClawback(db.read('phale_orders/R1')), false);
  db.seed('phale_orders/R1', { ...db.read('phale_orders/R1'), refundedAt: WEEK1, refundedBy: 'admin' });
  assert.equal(BR.needsClawback(db.read('phale_orders/R1')), true);
  const out = await BR.applyBankRefund({ db, code: 'R1', now: WEEK1 });
  assert.equal(out.result, 'mail_voided');
  const m = db.read('mails/phale_R1');
  assert.equal(m.voidReason, 'refund');
  assert.equal(m.expiresAt.getTime(), WEEK1.getTime());
  const o = db.read('phale_orders/R1');
  assert.equal(o.clawback, 'mail_voided');
  assert.equal(BR.needsClawback(o), false, 'once');
  assert.equal((await BR.applyBankRefund({ db, code: 'R1', now: WEEK1 })).result, 'already');
  // The trigger then recomputes: refunded orders do not count.
  assert.deepEqual(V.touchedUids({ uid: UID, status: 'paid', amount: 500000 }, o), [UID]);
  const r = await run(db, WEEK1);
  assert.equal(r.level, 0);
});

test('bank refund: a claimed credit comes out of the server wallet, the rest is debt', async () => {
  const db = dbWith({ phaLe: 0 });
  paidOrder(db, 'R2', { crystals: 6250 });
  db.seed(`users/${UID}/mailState/phale_R2`, { claimed: true });
  db.seed(`wallets/${UID}`, { phaLe: 4000, seededAt: WEEK0 });
  db.seed('phale_orders/R2', { ...db.read('phale_orders/R2'), refundedAt: WEEK1, refundedBy: 'admin' });
  const out = await BR.applyBankRefund({ db, code: 'R2', now: WEEK1 });
  assert.deepEqual(out, { result: 'wallet', taken: 4000, debt: 2250 });
  assert.equal(db.read(`wallets/${UID}`).phaLe, 0);
  const o = db.read('phale_orders/R2');
  assert.equal(o.phaleTaken, 4000);
  assert.equal(o.phaleDebt, 2250);
});

test('refund debt: no Pha lê spend while it is open, the next credits pay it first', async () => {
  const db = dbWith({ phaLe: 0 });
  paidOrder(db, 'R5', { crystals: 6250 });
  db.seed(`users/${UID}/mailState/phale_R5`, { claimed: true });
  db.seed(`wallets/${UID}`, { phaLe: 4000, seededAt: WEEK0 });
  db.seed('phale_orders/R5', { ...db.read('phale_orders/R5'), refundedAt: WEEK1, refundedBy: 'admin' });
  await BR.applyBankRefund({ db, code: 'R5', now: WEEK1 });
  assert.equal(db.read(`wallets/${UID}`).phaLeDebt, 2250);
  const v = await W.sync({ db, eco: ECO, uid: UID, now: WEEK1, data: {} });
  assert.equal(v.phaLe, -2250, 'shown below 0');
  assert.equal(v.phaLeDebt, 2250);
  // A credit of 1000: all of it pays the debt.
  db.seed('mails/gift_1', { target: UID, walletClaim: true, rewards: { items: [{ kind: 'phaLe', amount: 1000 }] } });
  const c1 = await W.claimMail({ db, eco: ECO, uid: UID, now: WEEK1, data: { mailId: 'gift_1' } });
  assert.equal(c1.phaLe, -1250);
  assert.equal(db.read(`wallets/${UID}`).phaLe, 0);
  // Even with Pha lê in the wallet, nothing can be spent while a debt is open.
  db.seed(`wallets/${UID}`, { ...db.read(`wallets/${UID}`), phaLe: 500 });
  const no = (e) => e.code === 'balance';
  await assert.rejects(W.exchange({ db, eco: ECO, uid: UID, now: WEEK1, data: { packs: 1 } }), no);
  await assert.rejects(W.buyCards({ db, eco: ECO, uid: UID, now: WEEK1, data: { currency: 'phaLe', count: 1 } }), no);
  const pot = ECO.pots.find((p) => p.currency === 'phaLe' && p.buyable !== false && p.phaLePrice <= 500);
  assert.ok(pot, 'a Pha lê pot to try');
  await assert.rejects(W.buy({ db, eco: ECO, uid: UID, now: WEEK1, data: { kind: 'pot', id: pot.id } }), no);
  assert.equal(db.read(`wallets/${UID}`).phaLe, 500, 'nothing taken');
  db.seed(`wallets/${UID}`, { ...db.read(`wallets/${UID}`), phaLe: 0 });
  // A top-up of 2000: 1250 pays the rest, 750 is spendable.
  db.seed('mails/phale_T', { target: UID, walletClaim: true, rewards: { items: [{ kind: 'phaLe', amount: 2000 }] } });
  const c2 = await W.claimMail({ db, eco: ECO, uid: UID, now: WEEK1, data: { mailId: 'phale_T' } });
  assert.equal(c2.phaLe, 750);
  assert.equal(c2.phaLeDebt, 0);
  const ex = await W.exchange({ db, eco: ECO, uid: UID, now: WEEK1, data: { packs: 1 } });
  assert.equal(ex.phaLe, 750 - ECO.phaLeExchange.phaLe);
});

test('refund debt before the server wallet exists is kept when it seeds', async () => {
  const db = dbWith({ phaLe: 1000 });
  paidOrder(db, 'R6', { crystals: 6250 });
  db.seed(`users/${UID}/mailState/phale_R6`, { claimed: true });
  db.seed('phale_orders/R6', { ...db.read('phale_orders/R6'), refundedAt: WEEK1, refundedBy: 'admin' });
  const out = await BR.applyBankRefund({ db, code: 'R6', now: WEEK1 });
  assert.deepEqual(out, { result: 'balance', taken: 1000, debt: 5250 });
  assert.equal(db.read(`users/${UID}`).progress.phaLe, 0);
  assert.equal(db.read(`wallets/${UID}`).phaLeDebt, 5250);
  const v = await W.sync({ db, eco: ECO, uid: UID, now: WEEK1, data: {} });
  assert.equal(v.phaLe, -5250);
  assert.equal(db.read(`wallets/${UID}`).phaLeDebt, 5250, 'seed keeps the debt');
});

test('VIP gifts: never taken back on a refund, never sent again when the tier comes back', async () => {
  const db = dbWith();
  paidOrder(db, 'R7', { amount: 600000 });
  const first = await run(db);
  assert.deepEqual(first.sent, [1, 2, 3]);
  db.seed(`users/${UID}/mailState/vip_${UID}_3`, { claimed: true });
  db.seed('phale_orders/R7', { ...db.read('phale_orders/R7'), refundedAt: WEEK1, refundedBy: 'admin' });
  await BR.applyBankRefund({ db, code: 'R7', now: WEEK1 });
  const down = await run(db, WEEK1);
  assert.equal(down.level, 0);
  for (const n of [1, 2, 3]) {
    const m = db.read(`mails/vip_${UID}_${n}`);
    assert.equal(m.voidedAt, undefined, `gift ${n} not voided`);
    assert.equal(m.expiresAt, undefined, `gift ${n} not expired`);
  }
  assert.deepEqual(Object.keys(db.read(`wallets/${UID}`).vipGifted).sort(), ['1', '2', '3']);
  order(db, 'B', 600000);
  const back = await run(db, at(16));
  assert.equal(back.level, 3);
  assert.deepEqual(back.sent, [], 'reached again: no new gift');
  assert.equal(mails(db).length, 3);
  order(db, 'C', 1000000);
  const up = await run(db, at(17));
  assert.deepEqual(up.sent, [4], 'a tier never reached before still gets its gift');
});

test('bank refund: nothing for an order not marked, not paid, or missing', async () => {
  const db = dbWith();
  paidOrder(db, 'R3');
  assert.equal((await BR.applyBankRefund({ db, code: 'R3', now: WEEK1 })).result, 'not-refunded');
  assert.equal((await BR.applyBankRefund({ db, code: 'NOPE', now: WEEK1 })).result, 'missing');
  assert.equal((await BR.applyBankRefund({ db, code: 'a/b', now: WEEK1 })).result, 'bad');
  db.seed('phale_orders/R4', { uid: UID, status: 'pending', refundedAt: WEEK1 });
  assert.equal(BR.needsClawback(db.read('phale_orders/R4')), false);
});
