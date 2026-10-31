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
//     skins        {skinId: 1}  decoration skins bought with Pha lê (owned
//                  forever, never refunded: economy skins.rules)
//     wonPots      [potId]      Sơn Hải pots won here (dup check before the
//                  reward mail is claimed into the save)
//     coinItems    {pet: {id: 1}, petItem: {id: n}} pets and pet items bought
//                  with xu through coinBuy (Mị lực counts only recorded ones)
//     coinBackfill {at, pets, petItems} one-time record of xu pets / items
//                  bought before coinBuy (charm.js serverOwned)
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
const VIP = require('./vip');
const { skinPrice, legacySkinId } = require('./skins');

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

/**
 * Seed cap (economy.json `phaLeMigration`, Hà Phương; An): the first wallet
 * takes at most what the server saw topped up plus `extraGiftAllowance`
 * Pha lê of gifts. Missing block or allowance: 0 (top-ups only).
 */
function seedAllowance(eco) {
  const m = eco && eco.phaLeMigration;
  // Missing block or allowance: fail closed, the seed is capped at the
  // server-recorded top-ups only (Bảo's review 31/10, fix 3).
  if (!m || m.extraGiftAllowance == null) return 0;
  const n = Number(m.extraGiftAllowance);
  if (!Number.isInteger(n) || n < 0) throw new Error('economy.json phaLeMigration.extraGiftAllowance');
  return n;
}

/** economy.json `phaLeMigration.freePerDayAllowance` (0 when missing). */
function seedPerDay(eco) {
  const n = Number(eco && eco.phaLeMigration && eco.phaLeMigration.freePerDayAllowance);
  return Number.isInteger(n) && n > 0 ? n : 0;
}

/**
 * Whole days since the Firebase Auth account was created ([created], from
 * the Admin SDK; the save's joinedAt is written by the app, so it is not
 * used). Unknown creation time: 0 days.
 */
function accountDays(created, now) {
  if (!(created instanceof Date) || Number.isNaN(created.getTime())) return 0;
  return Math.max(0, Math.floor((now.getTime() - created.getTime()) / G.DAY_MS));
}

/**
 * Pha lê this player bought, as recorded by the server: paid bank orders
 * (phale_orders crystalsGranted) and App Store purchases not refunded
 * (phale_iap phaLe). Read inside [tx] when a wallet is first seeded.
 */
async function toppedUpPhaLe(tx, db, uid) {
  const orders = await tx.get(db.collection('phale_orders').where('uid', '==', uid));
  const iap = await tx.get(db.collection('phale_iap').where('uid', '==', uid));
  let n = 0;
  for (const d of orders.docs) {
    const o = d.data() || {};
    if (o.status === 'paid') n += int(o.crystalsGranted);
  }
  for (const d of iap.docs) {
    const r = d.data() || {};
    if (!r.refundedAt && !r.uncredited) n += int(r.phaLe);
  }
  return n;
}

/**
 * First wallet, from the save. [toppedUp]: server-recorded top-ups (see
 * toppedUpPhaLe); [days]: whole days since the account was created. With a
 * seed cap the balance is min(save, toppedUp + extraGiftAllowance +
 * freePerDayAllowance × days) and the rest is only written down in `seedExcess` (not
 * credited) for An to review.
 */
function seedWallet(eco, user, welfare, now, toppedUp = 0, days = 0) {
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
  const saved = int(progress.phaLe);
  const allowance = seedAllowance(eco);
  // phaLeMigration.rule: min(saved, toppedUp + extraGiftAllowance + freePerDayAllowance × days).
  const perDay = allowance == null ? 0 : seedPerDay(eco) * int(days);
  const cap = allowance == null ? null : int(toppedUp) + allowance + perDay;
  const phaLe = cap == null ? saved : Math.min(saved, cap);
  return {
    phaLe, cards: {}, pity: {}, xuCards: { day: 0, n: 0 }, items, earned,
    ads: { day: 0, n: 0 }, wonPots: [], spinSeq: 0,
    seededAt: now, seededPhaLe: phaLe, savedPhaLe: saved,
    ...(cap == null ? {} : { seedCap: cap, seedToppedUp: int(toppedUp), seedAccountDays: int(days) }),
    ...(saved > phaLe ? { seedExcess: saved - phaLe } : {}),
    updatedAt: now,
  };
}

/**
 * Accounts made after the server wallet went live never had Pha lê that
 * lived only in the save, so their wallet never seeds from it (An, Bảo
 * 31/10). The cutoff is the wallet's first commit (31b1df5, 17/10/2026
 * 14:23 VN): the real deploy was not before it, so an earlier cutoff can
 * only seed fewer accounts. Replace with the real deploy time once An
 * confirms it.
 */
const WALLET_LIVE_AT = new Date('2026-10-17T14:23:36+07:00');

function isLegacyAccount(created) {
  return created instanceof Date && !Number.isNaN(created.getTime())
    && created.getTime() < WALLET_LIVE_AT.getTime();
}

/**
 * A new account's first wallet: the same seed (earned markers, claimed sets,
 * debt) but 0 Pha lê and no pet items taken from the save. Top-ups reach it
 * through claimMail like any other account.
 */
function freshWallet(eco, user, welfare, now) {
  const u = user || {};
  const progress = { ...(u.progress || {}), phaLe: 0, petItems: {} };
  const w = seedWallet(eco, { ...u, progress }, welfare, now, 0, 0);
  return { ...w, savedPhaLe: int((u.progress || {}).phaLe), seedFresh: true };
}

/** Reads (or seeds) the wallet inside [tx]. */
async function loadWallet(tx, db, eco, uid, now, accountCreated) {
  const ref = db.doc(`wallets/${uid}`);
  const snap = await tx.get(ref);
  // A doc without seededAt only holds what vip.js wrote before the first
  // seed: seed it and keep those fields.
  if (snap.exists && snap.data().seededAt) return { ref, wallet: normalize(snap.data()), fresh: false };
  const before = snap.exists ? snap.data() : {};
  const user = await tx.get(db.doc(`users/${uid}`));
  const welfare = await tx.get(db.doc(`users/${uid}/welfare/login`));
  // Account age from Firebase Auth only (index.js authCreated:
  // metadata.creationTime), never the save's joinedAt. A failed lookup counts
  // as a new account.
  let created = null;
  try {
    created = accountCreated ? await accountCreated() : null;
  } catch (_) {
    created = null;
  }
  const legacy = isLegacyAccount(created);
  const toppedUp = legacy ? await toppedUpPhaLe(tx, db, uid) : 0;
  const days = legacy ? accountDays(created, now) : 0;
  const seeded = legacy
    ? seedWallet(eco, user.data(), welfare.data(), now, toppedUp, days)
    : freshWallet(eco, user.data(), welfare.data(), now);
  return { ref, wallet: { ...before, ...seeded }, fresh: true };
}

function normalize(w) {
  return {
    ...w,
    phaLe: int(w.phaLe),
    phaLeDebt: int(w.phaLeDebt),
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

/**
 * vip.refund of economy.json: a refund takes the order's Pha lê back
 * (clawBackPhaLe); what was already spent stays as wallet.phaLeDebt and,
 * with negativeBalanceBlocksSpending, no Pha lê can be spent until a top-up
 * (or any credit) pays it off.
 */
function refundRules(eco) {
  const r = (eco && eco.vip && eco.vip.refund) || {};
  return {
    clawBackPhaLe: r.clawBackPhaLe !== false,
    negativeBalanceBlocksSpending: r.negativeBalanceBlocksSpending !== false,
  };
}

/** Adds [n] Pha lê: the refund debt is paid first. Returns what went to the debt. */
function credit(wallet, n) {
  const pay = Math.min(int(wallet.phaLeDebt), int(n));
  wallet.phaLeDebt = int(wallet.phaLeDebt) - pay;
  wallet.phaLe = int(wallet.phaLe) + int(n) - pay;
  return pay;
}

/** Takes [cost] Pha lê, or throws 'balance' (not enough, or a refund debt). */
function spend(eco, wallet, cost) {
  if (int(wallet.phaLeDebt) > 0 && refundRules(eco).negativeBalanceBlocksSpending) {
    throw new WalletError('balance');
  }
  if (wallet.phaLe < cost) throw new WalletError('balance');
  wallet.phaLe -= cost;
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
    // Below 0 while a refund debt is open (the app shows it as it is).
    phaLe: int(wallet.phaLe) - int(wallet.phaLeDebt),
    phaLeDebt: int(wallet.phaLeDebt),
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
    vip: VIP.vipView(eco, wallet),
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

async function sync({ db, eco, uid, now, data, accountCreated, filter }) {
  const out = await db.runTransaction(async (tx) => {
    const { ref, wallet, fresh } = await loadWallet(tx, db, eco, uid, now, accountCreated);
    if (fresh) save(tx, ref, wallet, now);
    return { v: view(eco, wallet, now, int(data && data.gameDay)), stale: wallet.vipVersion !== VIP.VERSION };
  });
  // VIP backfill: a wallet never computed (or from an older VERSION) gets its
  // tier from the top-up records now; later payments / refunds use the triggers.
  if (out.stale) {
    const r = await VIP.recompute({ db, eco, uid, now, filter });
    out.v.vip = {
      level: r.level, vnd: r.vnd, max: r.max, nextVnd: r.nextVnd,
      hallHidden: r.hallHidden, badgeHidden: r.badgeHidden, pots: r.pots,
    };
  }
  return out.v;
}

/**
 * Claims one mail on the server: flips users/{uid}/mailState/{mailId} and
 * credits its Pha lê and Thẻ gacha to the wallet in the same transaction.
 * Cards go to the pot of the week the mail arrived (giftTicketPotBy). The
 * other items come back in `rest` for the app to add to the save.
 */
async function claimMail({ db, eco, uid, now, data, accountCreated }) {
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
    const { ref, wallet } = await loadWallet(tx, db, eco, uid, now, accountCreated);
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
    credit(wallet, phaLe);
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

/** config/loginRewards when an admin saved the version-2 shape, else economy.json `loginRewards`. */
function loginTables(eco, cfg) {
  return cfg && cfg.version === 2 && Array.isArray(cfg.newbie) && Array.isArray(cfg.weekly)
    ? cfg : { version: 2, ...((eco && eco.loginRewards) || {}) };
}

function positive(block, key, name) {
  const n = Number(block && block[key]);
  if (!Number.isInteger(n) || n <= 0) throw new Error(`economy.json ${name}.${key}`);
  return n;
}

/** economy.json `phaLeFree.adReward`: Pha lê per rewarded ad. */
const adReward = (eco) => positive(eco.phaLeFree, 'adReward', 'phaLeFree');
/** economy.json `phaLeFree.adMaxPerDay`: Pha lê ads per VN day. */
const adCap = (eco) => positive(eco.phaLeFree, 'adMaxPerDay', 'phaLeFree');
/** economy.json `phaLeExchange`: `phaLe` Pha lê buy one pack of `coins` xu. */
const exchangeRate = (eco) => ({
  phaLe: positive(eco.phaLeExchange, 'phaLe', 'phaLeExchange'),
  coins: positive(eco.phaLeExchange, 'coins', 'phaLeExchange'),
});

/**
 * Pha lê (and gift cards) the app grants on its own, checked here:
 *   login       today's Phúc lợi gift, once per VN day, read from the
 *               welfare doc the rules already guard (day + milestone)
 *   ad          rewarded ad, phaLeFree.adReward each, phaLeFree.adMaxPerDay per VN day
 *   collection  pot collection reward, once per id, amount from economy
 *   giftcode    every redeemed batch not credited yet (after the seed)
 *   resale      selling back one Pha lê pet item bought through the wallet
 *   adminGift   the Pha lê of users/{uid}.gift (admin-written), once per id
 */
async function earn({ db, eco, uid, now, data, accountCreated }) {
  const source = data && data.source;
  return db.runTransaction(async (tx) => {
    const { ref, wallet } = await loadWallet(tx, db, eco, uid, now, accountCreated);
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
      const cfg = loginTables(eco, (await tx.get(db.doc('config/loginRewards'))).data());
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
      if (n >= adCap(eco)) throw new WalletError('limit');
      wallet.ads = { day: today, n: n + 1 };
      phaLe = adReward(eco);
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
    credit(wallet, phaLe);
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
  if (kind === 'skin') return skinPrice(eco, id);
  return 0;
}

/**
 * Pays one Pha lê shop item (pot, pet, pet item, decoration skin). The app adds the item to
 * its save only after this answers.
 */
async function buy({ db, eco, uid, now, data, accountCreated }) {
  const kind = data && data.kind;
  const id = data && data.id;
  if (typeof id !== 'string' || !id) throw new WalletError('bad');
  const price = shopPrice(eco, kind, id);
  if (price <= 0) throw new WalletError('not-for-sale');
  return db.runTransaction(async (tx) => {
    const { ref, wallet } = await loadWallet(tx, db, eco, uid, now, accountCreated);
    if (kind === 'skin') {
      wallet.skins = wallet.skins || {};
      if (wallet.skins[id] || wallet.skins[legacySkinId(id)]) throw new WalletError('owned');
    }
    spend(eco, wallet, price);
    if (kind === 'skin') wallet.skins[id] = 1;
    if (kind === 'petItem') {
      const row = wallet.items[id] || { bought: 0, sold: 0 };
      wallet.items[id] = { bought: int(row.bought) + 1, sold: int(row.sold) };
    }
    save(tx, ref, wallet, now);
    ledger(tx, db, uid, { type: 'buy', kind, id, phaLe: -price }, now);
    return { spent: price, ...view(eco, wallet, now) };
  });
}

/**
 * Buys one xu pet or pet item (economy currency 'coins') on the server so
 * Mị lực can count it. The price comes off save_guard/{uid}.money, the last
 * save the server checked, NOT a number from the app; the balance allowed
 * is that money plus a fixed headroom (coinBuyHeadroom: one game day), so a
 * buy made before the next morning save still works; data.gameDay from the
 * app is ignored. A checked save older than 1 real day: 'stale-save'. The app takes the same xu from its save only after this
 * answers. Pet food stays local; xu pots carry no Mị lực and stay local.
 */
/** coinBuy refuses when the last checked save is older than this (1 real day). */
const COIN_BUY_STALE_MS = 24 * 3600 * 1000;

/**
 * Fixed headroom over the checked save money: ONE game day's max gain, tier
 * by the checked save's game day (maxCoinsPerGameDay: 1-9 / 10+), plus one
 * week's login xu. It does not grow with time and the app's game day is not
 * read; save money may go below 0 by at most this until the next save check.
 */
function coinBuyHeadroom(th, state) {
  if (!th) return 0;
  const d = Math.max(1, int(state.day));
  return (d < 10 ? th.coinsDay1to9 : th.coinsDay10plus) + (th.loginCoinsPerRealWeek || 0);
}

async function coinBuy({ db, eco, uid, now, data, accountCreated, th = require('./anti_cheat').thresholds() }) {
  const kind = data && data.kind;
  const id = data && data.id;
  if ((kind !== 'pet' && kind !== 'petItem') || typeof id !== 'string' || !id) throw new WalletError('bad');
  const list = kind === 'pet' ? ((eco.pets && eco.pets.list) || []) : ((eco.petItems && eco.petItems.list) || []);
  const def = list.find((x) => x && x.id === id);
  const price = def && def.currency !== 'phaLe' ? int(def.price) : 0;
  if (price <= 0) throw new WalletError('not-for-sale');
  const AC = require('./anti_cheat');
  if (await AC.isFlagged(db, uid)) throw new WalletError('flagged');
  return db.runTransaction(async (tx) => {
    const guardRef = db.doc(`save_guard/${uid}`);
    const g = await tx.get(guardRef);
    if (!g.exists) throw new WalletError('no-save'); // the first cloud save sets it
    const state = g.data();
    const { ref, wallet } = await loadWallet(tx, db, eco, uid, now, accountCreated);
    wallet.coinItems = { pet: { ...((wallet.coinItems || {}).pet || {}) }, petItem: { ...((wallet.coinItems || {}).petItem || {}) } };
    if (kind === 'pet' && wallet.coinItems.pet[id]) throw new WalletError('owned');
    const at = state.at && typeof state.at.toDate === 'function' ? state.at.toDate() : (state.at ? new Date(state.at) : null);
    if (!at || now.getTime() - at.getTime() > COIN_BUY_STALE_MS) throw new WalletError('stale-save');
    const allowance = coinBuyHeadroom(th, state);
    const money = Math.floor(Number(state.money) || 0);
    if (money + allowance < price) throw new WalletError('balance');
    wallet.coinItems[kind][id] = int(wallet.coinItems[kind][id]) + 1;
    tx.set(guardRef, { ...state, money: money - price });
    save(tx, ref, wallet, now);
    ledger(tx, db, uid, { type: 'coinBuy', kind, id, coins: -price }, now);
    return { spent: price, ...view(eco, wallet, now) };
  });
}

/** Pha lê → xu packs (the "thiếu xu" exchange). The app adds the xu. */
async function exchange({ db, eco, uid, now, data, accountCreated }) {
  const packs = int(data && data.packs);
  if (packs < 1 || packs > 1000) throw new WalletError('bad');
  const rate = exchangeRate(eco);
  const cost = packs * rate.phaLe;
  return db.runTransaction(async (tx) => {
    const { ref, wallet } = await loadWallet(tx, db, eco, uid, now, accountCreated);
    spend(eco, wallet, cost);
    save(tx, ref, wallet, now);
    const coins = packs * rate.coins;
    ledger(tx, db, uid, { type: 'exchange', packs, phaLe: -cost, coins }, now);
    return { spent: cost, coins, ...view(eco, wallet, now) };
  });
}

/**
 * Buys [count] cards of THIS week's pot. currency 'phaLe': checked and
 * taken here. currency 'coins': price by the app's game day; the app takes
 * the xu (xu lives in the save); the daily limit is enforced here.
 */
async function buyCards({ db, eco, uid, now, data, accountCreated }) {
  const currency = data && data.currency;
  const count = int(data && data.count);
  if (count < 1 || count > 100) throw new WalletError('bad');
  const week = G.weekAt(eco, now);
  if (!week.potId) throw new WalletError('not-started');
  if (data.potId != null && data.potId !== week.potId) throw new WalletError('not-current');
  return db.runTransaction(async (tx) => {
    const { ref, wallet } = await loadWallet(tx, db, eco, uid, now, accountCreated);
    let paid;
    if (currency === 'phaLe') {
      const price = G.phaLeTicketPrice(eco);
      if (price <= 0) throw new WalletError('not-for-sale');
      paid = { phaLe: price * count };
      spend(eco, wallet, paid.phaLe);
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
async function spin({ db, eco, uid, now, data, accountCreated, rand = Math.random }) {
  const count = int((data && data.count) || 1);
  if (count < 1 || count > MAX_BATCH) throw new WalletError('bad');
  const week = G.weekAt(eco, now);
  if (!week.potId) throw new WalletError('not-started');
  if (data && data.potId != null && data.potId !== week.potId) throw new WalletError('not-current');
  const potId = week.potId;
  return db.runTransaction(async (tx) => {
    const { ref, wallet } = await loadWallet(tx, db, eco, uid, now, accountCreated);
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
  coinBuyHeadroom, COIN_BUY_STALE_MS,
  // season_pass.js spends / credits with these. They only stage writes on
  // [tx]: call them INSIDE db.runTransaction, with the wallet loadWallet
  // read in that same transaction, never on their own.
  loadWallet, credit, spend, save, ledger, isLegacyAccount, WALLET_LIVE_AT,
  WalletError, seedWallet, seedAllowance, accountDays, toppedUpPhaLe, loginTables, view, refundRules, sync, claimMail, earn, buy, coinBuy, exchange, buyCards, spin, shopPrice,
};
