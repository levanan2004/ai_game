'use strict';
// Server-side Pha lê wallet, gacha cards and pity counters.
//
//   wallets/{uid}   written ONLY here (rules: owner may read, nobody writes)
//     phaLe        the Pha lê balance that every spend checks
//     cards        {potId: n}   Thẻ gacha per Sơn Hải pot; never expire
//     pity         {potId: {n, week}}  spins since that pot last came out, and
//                  the rotation week they were counted in (reset weekly unless
//                  gacha.pityCarryOver is true)
//     xuCards      {day, n}     cards bought with xu on VN real day `day`
//     items        {petItemId: {bought, sold}} Pha lê pet items, for resale
//     earned       {key: 1}     one-time credits already paid (login day,
//                  pot collection, giftcode batch, milestone...)
//     ads          {day, n}     rewarded-ad Pha lê credits today
//     wonPots      [potId]      Sơn Hải pots won here (dup check before the
//                  reward mail is claimed into the save)
//     spinSeq, seededAt, seededPhaLe, updatedAt
//
// The first call seeds the wallet once from the save (users/{uid}.progress
// .phaLe): Pha lê earned before the server wallet existed lived only in the
// save. After that the save's phaLe is just a copy for display.
//
// Xu is NOT server-side: a card bought with xu trusts the app's game day for
// the price and the app takes the xu from its own save. Only the daily limit
// (gacha.ticketPrice.maxCoinTicketsPerDay) is enforced here.

const G = require('./gacha');
const D = require('./client_defaults');

class WalletError extends Error {
  constructor(code) { super(code); this.code = code; }
}

const MAX_BATCH = 10;

const int = (v) => (Number.isFinite(Number(v)) ? Math.max(0, Math.floor(Number(v))) : 0);

function sumKind(items, kind) {
  return (Array.isArray(items) ? items : [])
    .filter((i) => i && i.kind === kind)
    .reduce((s, i) => s + int(i.amount), 0);
}

function itemsOf(rewards) {
  return (rewards && Array.isArray(rewards.items)) ? rewards.items.filter((i) => i && typeof i === 'object') : [];
}

/** First wallet, from the save. */
function seedWallet(eco, user, welfare, now) {
  const progress = (user && user.progress) || {};
  const items = {};
  const phaLeItems = new Set(((eco.petItems && eco.petItems.list) || [])
    .filter((i) => i.currency === 'phaLe').map((i) => i.id));
  for (const [id, n] of Object.entries(progress.petItems || {})) {
    if (phaLeItems.has(id) && int(n) > 0) items[id] = { bought: int(n), sold: 0 };
  }
  const earned = {};
  for (const id of Array.isArray(progress.claimedSets) ? progress.claimedSets : []) earned[`col_${id}`] = 1;
  // The admin gift already opened is in the save's balance.
  const gift = user && user.gift;
  if (gift && gift.id && progress.appliedGiftId === gift.id) earned[`gift_${gift.id}`] = 1;
  // Today's login gift, if already claimed, is in the save's balance.
  if (welfare && welfare.lastClaimDay === G.vnDay(now)) earned[`login_${G.vnDay(now)}`] = 1;
  const phaLe = int(progress.phaLe);
  return {
    phaLe, cards: {}, pity: {}, xuCards: { day: 0, n: 0 }, items, earned,
    ads: { day: 0, n: 0 }, wonPots: [], spinSeq: 0,
    seededAt: now, seededPhaLe: phaLe, updatedAt: now,
  };
}

/** Reads (or seeds) the wallet inside [tx]. */
async function loadWallet(tx, db, eco, uid, now) {
  const ref = db.doc(`wallets/${uid}`);
  const snap = await tx.get(ref);
  if (snap.exists) return { ref, wallet: normalize(snap.data()), fresh: false };
  const user = await tx.get(db.doc(`users/${uid}`));
  const welfare = await tx.get(db.doc(`users/${uid}/welfare/login`));
  return { ref, wallet: seedWallet(eco, user.data(), welfare.data(), now), fresh: true };
}

function normalize(w) {
  return {
    ...w,
    phaLe: int(w.phaLe),
    cards: { ...(w.cards || {}) },
    pity: { ...(w.pity || {}) },
    xuCards: w.xuCards || { day: 0, n: 0 },
    items: { ...(w.items || {}) },
    earned: { ...(w.earned || {}) },
    ads: w.ads || { day: 0, n: 0 },
    wonPots: Array.isArray(w.wonPots) ? [...w.wonPots] : [],
    spinSeq: int(w.spinSeq),
  };
}

function xuBoughtToday(wallet, now) {
  return wallet.xuCards && wallet.xuCards.day === G.vnDay(now) ? int(wallet.xuCards.n) : 0;
}

/** What every callable returns: the numbers the app shows. */
function view(eco, wallet, now, gameDay) {
  const week = G.weekAt(eco, now);
  const max = G.coinTicketDailyMax(eco);
  const bought = xuBoughtToday(wallet, now);
  const pity = {};
  for (const id of new Set([...Object.keys(wallet.pity || {}), ...(week.potId ? [week.potId] : [])])) {
    pity[id] = G.pityOf(eco, wallet, id, week.index);
  }
  const cards = {};
  for (const [id, n] of Object.entries(wallet.cards || {})) if (int(n) > 0) cards[id] = int(n);
  return {
    phaLe: int(wallet.phaLe),
    cards,
    week: {
      index: week.index,
      potId: week.potId,
      nextPotId: week.nextPotId,
      weekStart: week.weekStart ? week.weekStart.getTime() : null,
      weekEnd: week.weekEnd ? week.weekEnd.getTime() : null,
      daysLeft: G.daysLeft(week, now),
    },
    pity,
    pityAt: G.pityAt(eco),
    xuCardsToday: { bought, max, left: max > 0 ? Math.max(0, max - bought) : null },
    price: {
      phaLe: G.phaLeTicketPrice(eco),
      coins: Number.isInteger(gameDay) && gameDay > 0 ? G.coinTicketPrice(eco, gameDay) : null,
    },
  };
}

function save(tx, ref, wallet, now) {
  tx.set(ref, { ...wallet, updatedAt: now });
}

function ledger(tx, db, uid, row, now) {
  tx.set(db.collection(`wallets/${uid}/ledger`).doc(`${now.getTime()}_${Math.random().toString(36).slice(2, 10)}`),
    { ...row, at: now });
}

// ---------------------------------------------------------------------------

async function sync({ db, eco, uid, now, data }) {
  return db.runTransaction(async (tx) => {
    const { ref, wallet, fresh } = await loadWallet(tx, db, eco, uid, now);
    if (fresh) save(tx, ref, wallet, now);
    return view(eco, wallet, now, int(data && data.gameDay));
  });
}

/**
 * Claims one mail on the server: flips users/{uid}/mailState/{mailId} and
 * credits its Pha lê and Thẻ gacha to the wallet in the same transaction.
 * Cards go to the pot of the week the mail arrived (giftTicketPotBy). The
 * other items come back in `rest` for the app to add to the save.
 */
async function claimMail({ db, eco, uid, now, data }) {
  const mailId = data && data.mailId;
  if (typeof mailId !== 'string' || !mailId || mailId.length > 200 || mailId.includes('/')) {
    throw new WalletError('bad');
  }
  return db.runTransaction(async (tx) => {
    const mailSnap = await tx.get(db.doc(`mails/${mailId}`));
    if (!mailSnap.exists) throw new WalletError('missing');
    const mail = mailSnap.data();
    if (mail.target !== 'all' && mail.target !== uid) throw new WalletError('not-yours');
    const exp = G.toDate(mail.expiresAt);
    if (exp && exp.getTime() <= now.getTime()) throw new WalletError('expired');
    const markRef = db.doc(`users/${uid}/mailState/${mailId}`);
    const mark = await tx.get(markRef);
    const { ref, wallet } = await loadWallet(tx, db, eco, uid, now);
    if (mark.exists && mark.data().claimed === true) {
      return { status: 'already', rest: [], credited: { phaLe: 0, cards: {} }, ...view(eco, wallet, now) };
    }
    const items = itemsOf(mail.rewards);
    const phaLe = sumKind(items, 'phaLe');
    const tickets = sumKind(items, 'ticket');
    const cards = {};
    if (tickets > 0) {
      const potId = G.giftTicketPotId(eco, mail, now);
      if (!potId) throw new WalletError('not-started');
      cards[potId] = tickets;
      wallet.cards[potId] = int(wallet.cards[potId]) + tickets;
    }
    wallet.phaLe += phaLe;
    tx.set(markRef, { read: true, claimed: true, readAt: now, claimedAt: now });
    save(tx, ref, wallet, now);
    if (phaLe > 0 || tickets > 0) ledger(tx, db, uid, { type: 'mail', mailId, phaLe, cards }, now);
    return {
      status: 'claimed',
      rest: items.filter((i) => i.kind !== 'phaLe' && i.kind !== 'ticket'),
      credited: { phaLe, cards },
      ...view(eco, wallet, now),
    };
  });
}

function loginTables(cfg) {
  return cfg && cfg.version === 2 && Array.isArray(cfg.newbie) && Array.isArray(cfg.weekly)
    ? cfg : D.defaultLoginRewards;
}

/**
 * Pha lê (and gift cards) the app grants on its own, checked here:
 *   login       today's Phúc lợi gift, once per VN day, read from the
 *               welfare doc the rules already guard (day + milestone)
 *   ad          rewarded ad, fixed amount, rewardedAdDailyCap per VN day
 *   collection  pot collection reward, once per id, amount from economy
 *   giftcode    every redeemed batch not credited yet (after the seed)
 *   resale      selling back one Pha lê pet item bought through the wallet
 *   adminGift   the Pha lê of users/{uid}.gift (admin-written), once per id
 */
async function earn({ db, eco, uid, now, data }) {
  const source = data && data.source;
  return db.runTransaction(async (tx) => {
    const { ref, wallet } = await loadWallet(tx, db, eco, uid, now);
    const today = G.vnDay(now);
    let phaLe = 0;
    const cards = {};
    const once = (key) => {
      if (wallet.earned[key]) throw new WalletError('already');
      wallet.earned[key] = 1;
    };
    if (source === 'login') {
      const w = (await tx.get(db.doc(`users/${uid}/welfare/login`))).data();
      if (!w || w.lastClaimDay !== today) throw new WalletError('not-earned');
      once(`login_${today}`);
      const cfg = loginTables((await tx.get(db.doc('config/loginRewards'))).data());
      const count = int(w.claimedCount);
      const cycle = Math.max(1, int(w.cycle));
      const table = cycle === 1 ? cfg.newbie : cfg.weekly;
      const items = [...itemsOf(table[count - 1])];
      const total = (cycle - 1) * 7 + count;
      for (const m of cfg.milestones || []) if (int(m.day) === total) items.push(...itemsOf(m.rewards));
      phaLe = sumKind(items, 'phaLe');
      const tickets = sumKind(items, 'ticket');
      if (tickets > 0) {
        // Claimed straight on the Phúc lợi screen (no mail): the pot of the
        // week at claim time.
        const potId = G.weekAt(eco, now).potId;
        if (potId) cards[potId] = tickets;
      }
    } else if (source === 'ad') {
      const n = wallet.ads && wallet.ads.day === today ? int(wallet.ads.n) : 0;
      if (n >= D.rewardedAdDailyCap) throw new WalletError('limit');
      wallet.ads = { day: today, n: n + 1 };
      phaLe = D.rewardedPhaLeAmount;
    } else if (source === 'collection') {
      const id = data.ref;
      const c = ((eco.potCollections && eco.potCollections.list) || []).find((x) => x.id === id);
      if (!c) throw new WalletError('bad');
      const progress = ((await tx.get(db.doc(`users/${uid}`))).data() || {}).progress || {};
      const counts = progress.potCounts || {};
      if (!(c.pots || []).every((p) => int(counts[p]) > 0)) throw new WalletError('not-earned');
      once(`col_${id}`);
      phaLe = int(c.reward && c.reward.phaLe);
    } else if (source === 'giftcode') {
      const seeded = G.toDate(wallet.seededAt) || new Date(0);
      const list = await tx.get(db.collection(`users/${uid}/redeemed`));
      const fresh = list.docs.filter((d) => !wallet.earned[`gc_${d.id}`]
        && (G.toDate(d.data().redeemedAt) || new Date(0)).getTime() >= seeded.getTime());
      for (const d of fresh) {
        const batch = (await tx.get(db.doc(`giftcodeBatches/${d.id}`))).data() || {};
        wallet.earned[`gc_${d.id}`] = 1;
        phaLe += sumKind(itemsOf(batch.rewards), 'phaLe');
      }
      if (fresh.length === 0) throw new WalletError('not-earned');
    } else if (source === 'adminGift') {
      const gift = ((await tx.get(db.doc(`users/${uid}`))).data() || {}).gift;
      if (!gift || typeof gift.id !== 'string' || !gift.id) throw new WalletError('not-earned');
      once(`gift_${gift.id}`);
      phaLe = int(gift.items && gift.items.pha_le);
    } else if (source === 'resale') {
      const id = data.ref;
      const def = ((eco.petItems && eco.petItems.list) || []).find((x) => x.id === id);
      if (!def || def.currency !== 'phaLe') throw new WalletError('bad');
      const row = wallet.items[id] || { bought: 0, sold: 0 };
      if (int(row.bought) - int(row.sold) <= 0) throw new WalletError('not-earned');
      wallet.items[id] = { bought: int(row.bought), sold: int(row.sold) + 1 };
      phaLe = Math.floor(int(def.price) * Number(eco.petItems.resaleRate || 0));
    } else {
      throw new WalletError('bad');
    }
    wallet.phaLe += phaLe;
    for (const [p, n] of Object.entries(cards)) wallet.cards[p] = int(wallet.cards[p]) + n;
    save(tx, ref, wallet, now);
    ledger(tx, db, uid, { type: 'earn', source, ref: data.ref || null, phaLe, cards }, now);
    return { credited: { phaLe, cards }, ...view(eco, wallet, now) };
  });
}

/** Price in Pha lê of one shop item, from economy.json. */
function shopPrice(eco, kind, id) {
  if (kind === 'pot') {
    const p = (eco.pots || []).find((x) => x.id === id);
    if (!p || p.currency !== 'phaLe' || p.buyable === false) return 0;
    return int(p.phaLePrice);
  }
  if (kind === 'pet') {
    const p = ((eco.pets && eco.pets.list) || []).find((x) => x.id === id);
    return p && p.currency === 'phaLe' ? int(p.price) : 0;
  }
  if (kind === 'petItem') {
    const p = ((eco.petItems && eco.petItems.list) || []).find((x) => x.id === id);
    return p && p.currency === 'phaLe' ? int(p.price) : 0;
  }
  return 0;
}

/**
 * Pays one Pha lê shop item (pot, pet, pet item). The app adds the item to
 * its save only after this answers.
 */
async function buy({ db, eco, uid, now, data }) {
  const kind = data && data.kind;
  const id = data && data.id;
  if (typeof id !== 'string' || !id) throw new WalletError('bad');
  const price = shopPrice(eco, kind, id);
  if (price <= 0) throw new WalletError('not-for-sale');
  return db.runTransaction(async (tx) => {
    const { ref, wallet } = await loadWallet(tx, db, eco, uid, now);
    if (wallet.phaLe < price) throw new WalletError('balance');
    wallet.phaLe -= price;
    if (kind === 'petItem') {
      const row = wallet.items[id] || { bought: 0, sold: 0 };
      wallet.items[id] = { bought: int(row.bought) + 1, sold: int(row.sold) };
    }
    save(tx, ref, wallet, now);
    ledger(tx, db, uid, { type: 'buy', kind, id, phaLe: -price }, now);
    return { spent: price, ...view(eco, wallet, now) };
  });
}

/** Pha lê → xu packs (the "thiếu xu" exchange). The app adds the xu. */
async function exchange({ db, eco, uid, now, data }) {
  const packs = int(data && data.packs);
  if (packs < 1 || packs > 1000) throw new WalletError('bad');
  const cost = packs * D.phaLePerExchangePack;
  return db.runTransaction(async (tx) => {
    const { ref, wallet } = await loadWallet(tx, db, eco, uid, now);
    if (wallet.phaLe < cost) throw new WalletError('balance');
    wallet.phaLe -= cost;
    save(tx, ref, wallet, now);
    const coins = packs * D.xuPerExchangePack;
    ledger(tx, db, uid, { type: 'exchange', packs, phaLe: -cost, coins }, now);
    return { spent: cost, coins, ...view(eco, wallet, now) };
  });
}

/**
 * Buys [count] cards of THIS week's pot. currency 'phaLe': checked and
 * taken here. currency 'coins': price by the app's game day; the app takes
 * the xu (xu lives in the save); the daily limit is enforced here.
 */
async function buyCards({ db, eco, uid, now, data }) {
  const currency = data && data.currency;
  const count = int(data && data.count);
  if (count < 1 || count > 100) throw new WalletError('bad');
  const week = G.weekAt(eco, now);
  if (!week.potId) throw new WalletError('not-started');
  if (data.potId != null && data.potId !== week.potId) throw new WalletError('not-current');
  return db.runTransaction(async (tx) => {
    const { ref, wallet } = await loadWallet(tx, db, eco, uid, now);
    let paid;
    if (currency === 'phaLe') {
      const price = G.phaLeTicketPrice(eco);
      if (price <= 0) throw new WalletError('not-for-sale');
      paid = { phaLe: price * count };
      if (wallet.phaLe < paid.phaLe) throw new WalletError('balance');
      wallet.phaLe -= paid.phaLe;
    } else if (currency === 'coins') {
      const gameDay = int(data.gameDay);
      const price = G.coinTicketPrice(eco, gameDay);
      if (gameDay < 1 || price <= 0) throw new WalletError('bad');
      const max = G.coinTicketDailyMax(eco);
      const bought = xuBoughtToday(wallet, now);
      if (max > 0 && bought + count > max) throw new WalletError('limit');
      wallet.xuCards = { day: G.vnDay(now), n: bought + count };
      paid = { coins: price * count };
    } else {
      throw new WalletError('bad');
    }
    wallet.cards[week.potId] = int(wallet.cards[week.potId]) + count;
    save(tx, ref, wallet, now);
    ledger(tx, db, uid, { type: 'cards', potId: week.potId, count, ...paid }, now);
    return { potId: week.potId, count, paid, ...view(eco, wallet, now, int(data.gameDay)) };
  });
}

/**
 * Spins [count] (1..10) cards of this week's pot. Each spin rolls the odds
 * table; the spin that reaches pityAt gives the pot for sure. The rewards
 * go into one mail (`gacha_{uid}_{seq}`), claimed like any gift.
 */
async function spin({ db, eco, uid, now, data, rand = Math.random }) {
  const count = int((data && data.count) || 1);
  if (count < 1 || count > MAX_BATCH) throw new WalletError('bad');
  const week = G.weekAt(eco, now);
  if (!week.potId) throw new WalletError('not-started');
  if (data && data.potId != null && data.potId !== week.potId) throw new WalletError('not-current');
  const potId = week.potId;
  return db.runTransaction(async (tx) => {
    const { ref, wallet } = await loadWallet(tx, db, eco, uid, now);
    if (int(wallet.cards[potId]) < count) throw new WalletError('no-cards');
    const progress = ((await tx.get(db.doc(`users/${uid}`))).data() || {}).progress || {};
    let owns = int((progress.potCounts || {})[potId]) > 0 || wallet.wonPots.includes(potId);
    const before = G.pityOf(eco, wallet, potId, week.index);
    const at = G.pityAt(eco);
    let n = before.n;
    const results = [];
    for (let i = 0; i < count; i++) {
      const forced = at > 0 && n + 1 >= at;
      const r = G.draw(eco, { potId, forceFeatured: forced, owns, rand });
      if (r.featured) {
        n = 0;
        if (!r.dup) { owns = true; wallet.wonPots.push(potId); }
      } else {
        n += 1;
      }
      results.push({ ...r, pity: forced });
    }
    wallet.cards[potId] = int(wallet.cards[potId]) - count;
    wallet.pity[potId] = { n, week: week.index };
    wallet.spinSeq += 1;
    const mailId = `gacha_${uid}_${wallet.spinSeq}`;
    const items = results.flatMap((r) => r.items);
    tx.create(db.doc(`mails/${mailId}`), {
      title: 'Vòng quay tuần',
      body: '',
      target: uid,
      rewards: { items },
      createdAt: now,
    });
    save(tx, ref, wallet, now);
    ledger(tx, db, uid, { type: 'spin', potId, count, mailId, week: week.index, results }, now);
    return {
      potId, mailId, results,
      resetFrom: before.resetFrom,
      ...view(eco, wallet, now),
    };
  });
}

module.exports = {
  WalletError, seedWallet, view, sync, claimMail, earn, buy, exchange, buyCards, spin, shopPrice,
};
