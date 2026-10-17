'use strict';
// Server wallet (wallet.js) and Vòng quay tuần helpers (gacha.js). Numbers come
// from economy.json (synced from assets/data by `npm test`).
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const G = require('./gacha');
const W = require('./wallet');
const ECO = require('./economy.json');

const UID = 'u1';
const ROT = ECO.gacha.weeklyRotation;
// rotationStart is a Monday 0h VN; a few instants around it.
const start = G.vnMidnight(ECO.gacha.rotationStart);
const at = (days, ms = 0) => new Date(start.getTime() + days * G.DAY_MS + ms);
const WEEK0 = at(2); // Wednesday of week 0
const WEEK1 = at(9);

const eco = (patch = {}) => ({ ...ECO, gacha: { ...ECO.gacha, ...patch, ticketPrice: { ...ECO.gacha.ticketPrice, ...(patch.ticketPrice || {}) } } });

// [toppedUp]: Pha lê the server saw bought (a paid bank order), so the seed
// cap (phaLeMigration) lets the whole save balance in unless a test says so.
function dbWith({ phaLe = 0, potCounts = {}, petItems = {}, claimedSets = [], toppedUp = phaLe } = {}) {
  const db = new FakeFirestore();
  db.seed(`users/${UID}`, { progress: { phaLe, potCounts, petItems, claimedSets, day: 10 } });
  if (toppedUp > 0) db.seed('phale_orders/TH0001', { uid: UID, status: 'paid', crystalsGranted: toppedUp });
  return db;
}
const call = (op, db, data, now = WEEK0, e = ECO, extra = {}) => op({ db, eco: e, uid: UID, now, data, ...extra });
const code = (c) => (e) => e instanceof W.WalletError && e.code === c;

// ---- rotation -------------------------------------------------------------

test('rotationStart is a Monday and week 0 is the first pot of weeklyRotation', () => {
  // getUTCDay of 0h VN Monday is Sunday 17:00 UTC.
  assert.equal(new Date(start.getTime() + 7 * 3600000).getUTCDay(), 1);
  assert.equal(G.weekAt(ECO, WEEK0).potId, ROT[0]);
  assert.equal(ROT[0], 'chau_cuu_vi_ho');
});

test('the pot changes exactly at 0h Monday VN, and the 12 pots repeat', () => {
  const lastSecond = at(7, -1); // Sunday 23:59:59.999 VN
  assert.equal(G.weekAt(ECO, lastSecond).potId, ROT[0]);
  assert.equal(G.weekAt(ECO, at(7)).potId, ROT[1]);
  assert.equal(G.weekAt(ECO, at(7)).index, 1);
  assert.equal(G.weekAt(ECO, at(7 * 12)).potId, ROT[0]);
  assert.equal(G.weekAt(ECO, at(7 * 13 + 3)).potId, ROT[1]);
  assert.equal(G.weekAt(ECO, at(0, -1)).potId, null, 'before the start: no pot');
  assert.equal(G.weekAt(eco({ rotationRepeat: false }), at(7 * 12)).potId, null);
  assert.equal(G.weekAt(ECO, WEEK0).nextPotId, ROT[1]);
});

test('days left until the pot changes', () => {
  assert.equal(G.daysLeft(G.weekAt(ECO, at(0)), at(0)), 7);
  assert.equal(G.daysLeft(G.weekAt(ECO, at(6, 1)), at(6, 1)), 1);
  assert.equal(G.daysLeft(G.weekAt(ECO, WEEK0), WEEK0), 5);
});

test('vnDay turns at 0h VN (17:00 UTC)', () => {
  assert.equal(G.vnDay(new Date('2026-10-17T16:59:59Z')) + 1, G.vnDay(new Date('2026-10-17T17:00:00Z')));
});

test('xu card price follows the game-day tiers; daily max 0/null = unlimited', () => {
  const tiers = ECO.gacha.ticketPrice.coinsByDay;
  assert.equal(G.coinTicketPrice(ECO, 1), tiers[0].coins);
  assert.equal(G.coinTicketPrice(ECO, tiers[1].fromDay), tiers[1].coins);
  assert.equal(G.coinTicketPrice(ECO, 5000), tiers[tiers.length - 1].coins);
  assert.equal(G.phaLeTicketPrice(ECO), ECO.gacha.ticketPrice.phaLe);
  assert.equal(G.coinTicketDailyMax(ECO), ECO.gacha.ticketPrice.maxCoinTicketsPerDay);
  assert.equal(G.coinTicketDailyMax(eco({ ticketPrice: { maxCoinTicketsPerDay: 0 } })), 0);
  assert.equal(G.coinTicketDailyMax(eco({ ticketPrice: { maxCoinTicketsPerDay: null } })), 0);
});

// ---- Pha lê spending ------------------------------------------------------

test('first call seeds the wallet once from the save; later save edits do not count', async () => {
  const db = dbWith({ phaLe: 700 });
  const v = await call(W.sync, db, {});
  assert.equal(v.phaLe, 700);
  db.seed(`users/${UID}`, { progress: { phaLe: 999999 } });
  assert.equal((await call(W.sync, db, {})).phaLe, 700);
  assert.equal(db.read(`wallets/${UID}`).seededPhaLe, 700);
});

test('a Pha lê pot is paid from the wallet in one transaction, price from economy.json', async () => {
  const db = dbWith({ phaLe: 600 });
  const pot = ECO.pots.find((p) => p.currency === 'phaLe' && p.buyable !== false);
  const r = await call(W.buy, db, { kind: 'pot', id: pot.id });
  assert.equal(r.spent, pot.phaLePrice);
  assert.equal(r.phaLe, 600 - pot.phaLePrice);
  assert.equal(db.read(`wallets/${UID}`).phaLe, 600 - pot.phaLePrice);
});

test('not enough Pha lê: refused and nothing changes', async () => {
  const db = dbWith({ phaLe: 10 });
  const pot = ECO.pots.find((p) => p.currency === 'phaLe' && p.buyable !== false);
  await assert.rejects(call(W.buy, db, { kind: 'pot', id: pot.id }), code('balance'));
  await assert.rejects(call(W.buyCards, db, { currency: 'phaLe', count: 1 }), code('balance'));
  await assert.rejects(call(W.exchange, db, { packs: 1 }), code('balance'));
  const w = (await call(W.sync, db, {}));
  assert.equal(w.phaLe, 10);
  assert.deepEqual(w.cards, {});
});

test('Sơn Hải pots and xu items are not for sale for Pha lê', async () => {
  const db = dbWith({ phaLe: 99999 });
  await assert.rejects(call(W.buy, db, { kind: 'pot', id: 'chau_cuu_vi_ho' }), code('not-for-sale'));
  await assert.rejects(call(W.buy, db, { kind: 'pet', id: 'meo' }), code('not-for-sale'));
  await assert.rejects(call(W.buy, db, { kind: 'x', id: 'dragon' }), code('not-for-sale'));
});

test('two parallel buys never spend the same Pha lê twice', async () => {
  const db = dbWith({ phaLe: 500 });
  const out = await Promise.allSettled([
    call(W.buy, db, { kind: 'pot', id: 'dragon' }), call(W.buy, db, { kind: 'pot', id: 'tiger' })]);
  assert.equal(out.filter((o) => o.status === 'fulfilled').length, 1);
  assert.equal(db.read(`wallets/${UID}`).phaLe, 0);
});

// ---- cards ----------------------------------------------------------------

test('cards with Pha lê: 20 each, stored for THIS week\'s pot; another pot is refused', async () => {
  const db = dbWith({ phaLe: 100 });
  const r = await call(W.buyCards, db, { currency: 'phaLe', count: 3 });
  assert.equal(r.potId, ROT[0]);
  assert.equal(r.phaLe, 100 - 3 * ECO.gacha.ticketPrice.phaLe);
  assert.deepEqual(r.cards, { [ROT[0]]: 3 });
  await assert.rejects(call(W.buyCards, db, { currency: 'phaLe', count: 1, potId: ROT[1] }), code('not-current'));
});

test('cards with xu: at most maxCoinTicketsPerDay per VN day, reset at 0h VN; Pha lê cards not limited', async () => {
  const max = ECO.gacha.ticketPrice.maxCoinTicketsPerDay;
  assert.equal(max, 10);
  const db = dbWith({ phaLe: 10000 });
  const r = await call(W.buyCards, db, { currency: 'coins', count: max - 1, gameDay: 10 });
  assert.deepEqual(r.paid, { coins: (max - 1) * G.coinTicketPrice(ECO, 10) });
  assert.equal(r.xuCardsToday.left, 1);
  await assert.rejects(call(W.buyCards, db, { currency: 'coins', count: 2, gameDay: 10 }), code('limit'));
  await call(W.buyCards, db, { currency: 'coins', count: 1, gameDay: 10 });
  await assert.rejects(call(W.buyCards, db, { currency: 'coins', count: 1, gameDay: 10 }), code('limit'));
  await call(W.buyCards, db, { currency: 'phaLe', count: 20 }); // not limited
  // 23:59 VN the same day: still out; 0h VN next day: open again.
  const midnight = new Date((G.vnDay(WEEK0) + 1) * G.DAY_MS - 7 * 3600000);
  await assert.rejects(call(W.buyCards, db, { currency: 'coins', count: 1, gameDay: 10 }, new Date(midnight.getTime() - 60000)), code('limit'));
  const next = await call(W.buyCards, db, { currency: 'coins', count: max, gameDay: 11 }, midnight);
  assert.equal(next.cards[ROT[0]], max + 20 + max);
});

test('daily xu limit 0 or null means unlimited', async () => {
  for (const v of [0, null]) {
    const db = dbWith();
    const e = eco({ ticketPrice: { maxCoinTicketsPerDay: v } });
    const r = await call(W.buyCards, db, { currency: 'coins', count: 50, gameDay: 1 }, WEEK0, e);
    assert.equal(r.cards[ROT[0]], 50);
    assert.equal(r.xuCardsToday.left, null);
  }
});

test('cards never expire: last week\'s cards wait for their pot to come back', async () => {
  const db = dbWith({ phaLe: 1000 });
  await call(W.buyCards, db, { currency: 'phaLe', count: 2 }, WEEK0);
  // Week 1: another pot; the week-0 cards are kept but cannot be spun.
  const v = await call(W.sync, db, {}, WEEK1);
  assert.equal(v.week.potId, ROT[1]);
  assert.equal(v.cards[ROT[0]], 2);
  await assert.rejects(call(W.spin, db, { count: 1 }, WEEK1), code('no-cards'));
  // 12 weeks later the pot is back and the cards work.
  const r = await call(W.spin, db, { count: 1 }, at(7 * 12 + 1), ECO, { rand: () => 0.99 });
  assert.equal(r.potId, ROT[0]);
  assert.equal(r.cards[ROT[0]], 1);
});

// ---- spin, pity, duplicates -----------------------------------------------

const lowRow = () => 0.9999; // always the last (most common) row
const featuredRow = () => 0; // the first row: potOfWeek

test('a spin uses one card of this week\'s pot and writes the reward mail', async () => {
  const db = dbWith({ phaLe: 1000 });
  await call(W.buyCards, db, { currency: 'phaLe', count: 1 });
  const r = await call(W.spin, db, { count: 1 }, WEEK0, ECO, { rand: lowRow });
  const last = ECO.gacha.table_permyriad[ECO.gacha.table_permyriad.length - 1];
  assert.deepEqual(r.results[0].items, [{ kind: 'coins', amount: last.coins }]);
  assert.equal(r.cards[ROT[0]], undefined);
  const mail = db.read(`mails/${r.mailId}`);
  assert.equal(mail.target, UID);
  assert.deepEqual(mail.rewards.items, r.results[0].items);
  await assert.rejects(call(W.spin, db, { count: 1 }, WEEK0, ECO, { rand: lowRow }), code('no-cards'));
});

test('pity: the pityAt-th spin without the pot gives the pot, then the counter restarts', async () => {
  const pity = ECO.gacha.pityAt;
  const db = dbWith({ phaLe: 20 * (pity + 5) });
  await call(W.buyCards, db, { currency: 'phaLe', count: pity + 5 });
  let r;
  for (let i = 0; i < pity - 1; i += 1) r = await call(W.spin, db, { count: 1 }, WEEK0, ECO, { rand: lowRow });
  assert.equal(r.pity[ROT[0]].n, pity - 1);
  r = await call(W.spin, db, { count: 1 }, WEEK0, ECO, { rand: lowRow });
  assert.equal(r.results[0].featured, true);
  assert.equal(r.results[0].pity, true);
  assert.deepEqual(r.results[0].items, [{ kind: 'pot', id: ROT[0], amount: 1 }]);
  assert.equal(r.pity[ROT[0]].n, 0);
});

test('pity is counted per pot', async () => {
  const db = dbWith({ phaLe: 10000 });
  await call(W.buyCards, db, { currency: 'phaLe', count: 5 }, WEEK0);
  await call(W.spin, db, { count: 5 }, WEEK0, ECO, { rand: lowRow });
  await call(W.buyCards, db, { currency: 'phaLe', count: 3 }, WEEK1);
  const r = await call(W.spin, db, { count: 3 }, WEEK1, ECO, { rand: lowRow });
  assert.equal(r.pity[ROT[1]].n, 3);
  assert.equal(db.read(`wallets/${UID}`).pity[ROT[0]].n, 5, 'the other pot\'s counter is untouched');
});

test('pity resets at the start of a new week (pityCarryOver false); the old count stays readable', async () => {
  assert.equal(ECO.gacha.pityCarryOver, false);
  const db = dbWith({ phaLe: 10000 });
  await call(W.buyCards, db, { currency: 'phaLe', count: 10 }, WEEK0);
  await call(W.spin, db, { count: 7 }, WEEK0, ECO, { rand: lowRow });
  // Same week: kept.
  assert.equal((await call(W.sync, db, {}, at(6, 3600000))).pity[ROT[0]].n, 7);
  // The pot comes back 12 weeks later: counter 0, resetFrom 7.
  const back = at(7 * 12 + 1);
  const v = await call(W.sync, db, {}, back);
  assert.deepEqual(v.pity[ROT[0]], { n: 0, resetFrom: 7, lastWeek: 0 });
  const r = await call(W.spin, db, { count: 1 }, back, ECO, { rand: lowRow });
  assert.equal(r.resetFrom, 7);
  assert.equal(r.pity[ROT[0]].n, 1);
  assert.equal(r.pity[ROT[0]].resetFrom, 0);
});

test('pityCarryOver true keeps the counter across weeks; a missing key resets', () => {
  const wallet = { pity: { [ROT[0]]: { n: 40, week: 0 } } };
  assert.deepEqual(G.pityOf(eco({ pityCarryOver: true }), wallet, ROT[0], 12), { n: 40, resetFrom: 0, lastWeek: null });
  const missing = { ...ECO, gacha: { ...ECO.gacha } };
  delete missing.gacha.pityCarryOver;
  assert.equal(G.pityOf(missing, wallet, ROT[0], 12).n, 0);
});

test('already owning the week\'s pot: the featured win pays its ifOwned xu', async () => {
  const dupXu = ECO.gacha.table_permyriad.find((r) => r.item === 'potOfWeek').ifOwned.coins;
  assert.equal(dupXu, 5000000);
  const db = dbWith({ phaLe: 1000, potCounts: { [ROT[0]]: 1 } });
  await call(W.buyCards, db, { currency: 'phaLe', count: 1 });
  const r = await call(W.spin, db, { count: 1 }, WEEK0, ECO, { rand: featuredRow });
  assert.equal(r.results[0].dup, true);
  assert.deepEqual(r.results[0].items, [{ kind: 'coins', amount: dupXu }]);
});

test('a second featured win in the same 10-spin batch is a duplicate', async () => {
  const db = dbWith({ phaLe: 1000 });
  await call(W.buyCards, db, { currency: 'phaLe', count: 10 });
  const r = await call(W.spin, db, { count: 10 }, WEEK0, ECO, { rand: featuredRow });
  assert.equal(r.results.filter((x) => x.featured && !x.dup).length, 1);
  assert.equal(r.results.filter((x) => x.dup).length, 9);
  assert.equal(r.cards[ROT[0]], undefined);
});

// ---- mails and earned Pha lê ------------------------------------------------

test('a Pha lê mail is claimed on the server once; the other items come back for the app', async () => {
  const db = dbWith({ phaLe: 5 });
  db.seed('mails/phale_1', {
    target: UID, createdAt: WEEK0, walletClaim: true,
    rewards: { items: [{ kind: 'phaLe', amount: 120 }, { kind: 'coins', amount: 3000 }] },
  });
  const r = await call(W.claimMail, db, { mailId: 'phale_1' });
  assert.equal(r.status, 'claimed');
  assert.equal(r.phaLe, 125);
  assert.deepEqual(r.rest, [{ kind: 'coins', amount: 3000 }]);
  assert.equal(db.read(`users/${UID}/mailState/phale_1`).claimed, true);
  const again = await call(W.claimMail, db, { mailId: 'phale_1' });
  assert.equal(again.status, 'already');
  assert.equal(again.phaLe, 125);
});

test('a mail for someone else or expired is refused', async () => {
  const db = dbWith();
  db.seed('mails/m1', { target: 'other', rewards: { items: [{ kind: 'phaLe', amount: 1 }] } });
  db.seed('mails/m2', { target: UID, expiresAt: at(1), rewards: { items: [{ kind: 'phaLe', amount: 1 }] } });
  await assert.rejects(call(W.claimMail, db, { mailId: 'm1' }), code('not-yours'));
  await assert.rejects(call(W.claimMail, db, { mailId: 'm2' }), code('expired'));
});

test('gift cards are cards of the pot of the week the mail arrived (giftTicketPotBy mailArrivalWeek)', async () => {
  assert.equal(ECO.gacha.giftTicketPotBy, 'mailArrivalWeek');
  const db = dbWith();
  db.seed('mails/vip', { target: UID, createdAt: WEEK0, rewards: { items: [{ kind: 'ticket', amount: 2 }] } });
  const r = await call(W.claimMail, db, { mailId: 'vip' }, WEEK1); // claimed a week later
  assert.deepEqual(r.credited.cards, { [ROT[0]]: 2 });
  assert.equal(r.cards[ROT[0]], 2);
  // claimTime mode: the week of the claim.
  const db2 = dbWith();
  db2.seed('mails/vip', { target: UID, createdAt: WEEK0, rewards: { items: [{ kind: 'ticket', amount: 1 }] } });
  const r2 = await call(W.claimMail, db2, { mailId: 'vip' }, WEEK1, eco({ giftTicketPotBy: 'claimTime' }));
  assert.deepEqual(r2.credited.cards, { [ROT[1]]: 1 });
});

test('rewarded ads: fixed Pha lê, capped per VN day', async () => {
  const db = dbWith();
  for (let i = 0; i < 5; i += 1) await call(W.earn, db, { source: 'ad' });
  await assert.rejects(call(W.earn, db, { source: 'ad' }), code('limit'));
  assert.equal(db.read(`wallets/${UID}`).phaLe, 10);
  await call(W.earn, db, { source: 'ad' }, at(3));
});

test('a pot collection pays once, only when every pot is owned', async () => {
  const c = ECO.potCollections.list[0];
  const db = dbWith({ potCounts: { [c.pots[0]]: 1 } });
  await assert.rejects(call(W.earn, db, { source: 'collection', ref: c.id }), code('not-earned'));
  db.seed(`users/${UID}`, { progress: { potCounts: Object.fromEntries(c.pots.map((p) => [p, 1])) } });
  const r = await call(W.earn, db, { source: 'collection', ref: c.id });
  assert.equal(r.credited.phaLe, c.reward.phaLe);
  await assert.rejects(call(W.earn, db, { source: 'collection', ref: c.id }), code('already'));
});

test('a set claimed before the wallet existed is not paid again', async () => {
  const c = ECO.potCollections.list[0];
  const db = dbWith({ phaLe: 100, claimedSets: [c.id], potCounts: Object.fromEntries(c.pots.map((p) => [p, 1])) });
  await assert.rejects(call(W.earn, db, { source: 'collection', ref: c.id }), code('already'));
});

test('selling back a Pha lê pet item needs one bought (or owned at the seed)', async () => {
  const item = ECO.petItems.list.find((i) => i.currency === 'phaLe');
  const db = dbWith({ phaLe: item.price });
  await assert.rejects(call(W.earn, db, { source: 'resale', ref: item.id }), code('not-earned'));
  await call(W.buy, db, { kind: 'petItem', id: item.id });
  const r = await call(W.earn, db, { source: 'resale', ref: item.id });
  assert.equal(r.credited.phaLe, Math.floor(item.price * ECO.petItems.resaleRate));
  await assert.rejects(call(W.earn, db, { source: 'resale', ref: item.id }), code('not-earned'));
});

test('the Phúc lợi gift is credited once, on the VN day the welfare doc was claimed', async () => {
  const db = dbWith();
  // Wallet first, then today's claim (otherwise the seed counts it as in the save).
  await call(W.sync, db, {});
  await assert.rejects(call(W.earn, db, { source: 'login' }), code('not-earned'));
  db.seed(`users/${UID}/welfare/login`, { claimedCount: 3, cycle: 1, lastClaimDay: G.vnDay(WEEK0) });
  const r = await call(W.earn, db, { source: 'login' });
  assert.equal(r.credited.phaLe, 50); // newbie day 3 (defaults)
  await assert.rejects(call(W.earn, db, { source: 'login' }), code('already'));
});

test('a login table with a Thẻ gacha gives a card of the week at claim time', async () => {
  const db = dbWith();
  await call(W.sync, db, {});
  const weekly = Array.from({ length: 7 }, () => ({ items: [] }));
  weekly[6] = { items: [{ kind: 'ticket', amount: 1 }] };
  db.seed('config/loginRewards', { version: 2, newbie: weekly, weekly, milestones: [] });
  db.seed(`users/${UID}/welfare/login`, { claimedCount: 7, cycle: 2, lastClaimDay: G.vnDay(WEEK1) });
  const r = await call(W.earn, db, { source: 'login' }, WEEK1);
  assert.deepEqual(r.credited.cards, { [ROT[1]]: 1 });
});

test('a giftcode batch redeemed after the seed pays its Pha lê once', async () => {
  const db = dbWith();
  await call(W.sync, db, {}, at(1));
  db.seed('giftcodeBatches/b1', { rewards: { items: [{ kind: 'phaLe', amount: 30 }] } });
  db.seed(`users/${UID}/redeemed/b1`, { code: 'ABCD', redeemedAt: at(2) });
  db.seed('giftcodeBatches/b0', { rewards: { items: [{ kind: 'phaLe', amount: 99 }] } });
  db.seed(`users/${UID}/redeemed/b0`, { code: 'OLD1', redeemedAt: at(0) });
  const r = await call(W.earn, db, { source: 'giftcode' }, at(2));
  assert.equal(r.credited.phaLe, 30);
  await assert.rejects(call(W.earn, db, { source: 'giftcode' }, at(2)), code('not-earned'));
});

test('exchange takes Pha lê per pack and reports the xu for the app to add', async () => {
  const db = dbWith({ phaLe: 250 });
  const r = await call(W.exchange, db, { packs: 2 });
  assert.equal(r.phaLe, 50);
  assert.equal(r.coins, 2000000);
});

test('an admin gift pays its Pha lê once per gift id; one opened before the seed is not paid again', async () => {
  const db = dbWith();
  await call(W.sync, db, {});
  db.seed(`users/${UID}`, { progress: {}, gift: { id: 'g1', items: { pha_le: 40, xu: 1000 } } });
  assert.equal((await call(W.earn, db, { source: 'adminGift' })).credited.phaLe, 40);
  await assert.rejects(call(W.earn, db, { source: 'adminGift' }), code('already'));
  const db2 = new FakeFirestore();
  db2.seed(`users/${UID}`, { progress: { phaLe: 40, appliedGiftId: 'g1' }, gift: { id: 'g1', items: { pha_le: 40 } } });
  await assert.rejects(call(W.earn, db2, { source: 'adminGift' }), code('already'));
  assert.equal(db2.read(`wallets/${UID}`), undefined, 'a refused call writes nothing');
});

// ---- task-2 follow-up: numbers from economy.json, seed cap -----------------

test('economy.json: rotationStart 2026-10-19 (Cửu Vĩ week), ticketRarity hiem, Pha lê blocks', () => {
  assert.equal(ECO.gacha.rotationStart, '2026-10-19');
  assert.equal(G.weekAt(ECO, new Date('2026-10-21T05:00:00Z')).potId, 'chau_cuu_vi_ho');
  assert.equal(G.weekAt(ECO, new Date('2026-10-18T16:59:59Z')).potId, null, 'nothing before 0h 19/10 VN');
  assert.equal(ECO.gacha.ticketRarity, 'hiem');
  assert.deepEqual([ECO.phaLeFree.adReward, ECO.phaLeFree.adMaxPerDay], [2, 5]);
  assert.deepEqual([ECO.phaLeExchange.phaLe, ECO.phaLeExchange.coins], [100, 1000000]);
  assert.equal(ECO.phaLeMigration.extraGiftAllowance, 300);
  assert.equal(require('node:fs').existsSync(require('node:path').join(__dirname, 'client_defaults.js')), false);
});

test('economy.json loginRewards is the exact table that was in the Dart code', () => {
  const ph = (n) => ({ kind: 'phaLe', amount: n });
  const gh = (n) => ({ kind: 'giotHoa', amount: n });
  const tr = (n) => ({ kind: 'treat', id: 'banh_mat', amount: n });
  const co = (n) => ({ kind: 'coins', amount: n });
  const pot = (id) => ({ kind: 'pot', id, amount: 1 });
  const L = ECO.loginRewards;
  assert.deepEqual(L.newbie, [
    { items: [gh(10)] }, { items: [pot('dragon')] }, { items: [ph(50)] }, { items: [tr(4)] },
    { items: [co(50000)] }, { items: [pot('tiger'), gh(20)] }, { items: [ph(150), gh(25)] },
  ]);
  assert.deepEqual(L.weekly, [
    { items: [tr(1)] }, { items: [co(30000)] }, { items: [ph(20)] }, { items: [tr(2)] },
    { items: [co(50000)] }, { items: [gh(3)] }, { items: [ph(30), gh(30)] },
  ]);
  assert.deepEqual(L.milestones, [
    { day: 14, rewards: { items: [ph(40)] } }, { day: 30, rewards: { items: [ph(80)] } },
  ]);
});

test('login credit reads economy.json loginRewards while config/loginRewards is missing or old', async () => {
  const newbie = Array.from({ length: 7 }, () => ({ items: [] }));
  newbie[2] = { items: [{ kind: 'phaLe', amount: 77 }] };
  const e = { ...ECO, loginRewards: { ...ECO.loginRewards, newbie } };
  const db = dbWith();
  await call(W.sync, db, {}, WEEK0, e);
  db.seed('config/loginRewards', { days: [], repeat: true }); // legacy shape: ignored
  db.seed(`users/${UID}/welfare/login`, { claimedCount: 3, cycle: 1, lastClaimDay: G.vnDay(WEEK0) });
  assert.equal((await call(W.earn, db, { source: 'login' }, WEEK0, e)).credited.phaLe, 77);
  assert.equal(W.loginTables(e, { version: 2, newbie: [], weekly: [] }).version, 2, 'a saved v2 table wins');
});

test('rewarded ad amount and daily cap come from economy.json phaLeFree', async () => {
  const e = { ...ECO, phaLeFree: { adReward: 3, adMaxPerDay: 2 } };
  const db = dbWith();
  await call(W.earn, db, { source: 'ad' }, WEEK0, e);
  await call(W.earn, db, { source: 'ad' }, WEEK0, e);
  await assert.rejects(call(W.earn, db, { source: 'ad' }, WEEK0, e), code('limit'));
  assert.equal(db.read(`wallets/${UID}`).phaLe, 6);
  await assert.rejects(call(W.earn, dbWith(), { source: 'ad' }, WEEK0, { ...ECO, phaLeFree: {} }), /phaLeFree/);
});

test('exchange rate comes from economy.json phaLeExchange', async () => {
  const e = { ...ECO, phaLeExchange: { phaLe: 50, coins: 400000 } };
  const r = await call(W.exchange, dbWith({ phaLe: 120 }), { packs: 2 }, WEEK0, e);
  assert.equal(r.spent, 100);
  assert.equal(r.coins, 800000);
});

test('seed cap: no top-ups recorded = at most the 300 gift allowance; the rest is only written down', async () => {
  const db = dbWith({ phaLe: 5000, toppedUp: 0 });
  assert.equal((await call(W.sync, db, {})).phaLe, 300);
  const w = db.read(`wallets/${UID}`);
  assert.equal(w.seededPhaLe, 300);
  assert.equal(w.savedPhaLe, 5000);
  assert.equal(w.seedExcess, 4700, 'not credited, kept for An');
  assert.equal(w.seedCap, 300);
  assert.equal(w.seedToppedUp, 0);
});

test('seed cap counts paid bank orders and App Store purchases not refunded, of this uid only', async () => {
  const db = dbWith({ phaLe: 5000, toppedUp: 0 });
  db.seed('phale_orders/TH1', { uid: UID, status: 'paid', crystalsGranted: 1000 });
  db.seed('phale_orders/TH2', { uid: UID, status: 'pending', crystalsGranted: null });
  db.seed('phale_orders/TH3', { uid: 'other', status: 'paid', crystalsGranted: 9000 });
  db.seed('phale_iap/1', { uid: UID, phaLe: 550 });
  db.seed('phale_iap/2', { uid: UID, phaLe: 2200, refundedAt: WEEK0 });
  assert.equal((await call(W.sync, db, {})).phaLe, 1000 + 550 + 300);
  const w = db.read(`wallets/${UID}`);
  assert.equal(w.seedToppedUp, 1550);
  assert.equal(w.seedExcess, 5000 - 1850);
});

test('seed cap: a save under the cap is taken whole, no seedExcess', async () => {
  const db = dbWith({ phaLe: 120, toppedUp: 0 });
  assert.equal((await call(W.sync, db, {})).phaLe, 120);
  assert.equal(db.read(`wallets/${UID}`).seedExcess, undefined);
});

test('seed cap: the allowance number is read from economy.json; no phaLeMigration = no cap', async () => {
  const db = dbWith({ phaLe: 5000, toppedUp: 0 });
  const e = { ...ECO, phaLeMigration: { ...ECO.phaLeMigration, extraGiftAllowance: 40 } };
  assert.equal((await call(W.sync, db, {}, WEEK0, e)).phaLe, 40);
  const db2 = dbWith({ phaLe: 5000, toppedUp: 0 });
  const noCap = { ...ECO };
  delete noCap.phaLeMigration;
  assert.equal((await call(W.sync, db2, {}, WEEK0, noCap)).phaLe, 5000);
  assert.equal(db2.read(`wallets/${UID}`).seedExcess, undefined);
});

test('seed cap applies only once: a wallet that exists is never re-capped', async () => {
  const db = dbWith({ phaLe: 200, toppedUp: 0 });
  await call(W.sync, db, {});
  db.seed('mails/phale_9', { target: UID, walletClaim: true, rewards: { items: [{ kind: 'phaLe', amount: 900 }] } });
  assert.equal((await call(W.claimMail, db, { mailId: 'phale_9' })).phaLe, 1100);
});

test('seed cap adds freePerDayAllowance × whole days since the Auth account was created', async () => {
  assert.equal(ECO.phaLeMigration.freePerDayAllowance, 10);
  const db = dbWith({ phaLe: 5000, toppedUp: 0 });
  db.seed('phale_orders/TH1', { uid: UID, status: 'paid', crystalsGranted: 1000 });
  const created = new Date(WEEK0.getTime() - 20 * G.DAY_MS - 3600000); // 20 days + 1 h ago
  const r = await call(W.sync, db, {}, WEEK0, ECO, { accountCreated: async () => created });
  assert.equal(r.phaLe, 1000 + 300 + 20 * 10);
  const w = db.read(`wallets/${UID}`);
  assert.equal(w.seedAccountDays, 20);
  assert.equal(w.seedExcess, 5000 - 1500);
});

test('seed cap: unknown account creation time counts 0 days (the save joinedAt is not trusted)', async () => {
  const db = dbWith({ phaLe: 5000, toppedUp: 0 });
  db.seed(`users/${UID}`, { joinedAt: new Date('2020-01-01'), progress: { phaLe: 5000 } });
  const r = await call(W.sync, db, {}, WEEK0, ECO, { accountCreated: async () => null });
  assert.equal(r.phaLe, 300);
  assert.equal(W.accountDays(new Date(WEEK0.getTime() + G.DAY_MS), WEEK0), 0, 'never negative');
});
