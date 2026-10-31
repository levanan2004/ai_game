'use strict';
const S = require('./season');
// Mị lực, recomputed on the server from a saved game. The same arithmetic as
// the game (lib/logic/charm_rewards.dart `recomputeCharm`, lib/logic/pet.dart
// `petCharmScore`, lib/data/pet_items.dart `wornItemsCharm`,
// lib/logic/pot_bonus.dart `ownedPotsCharm`). Three parts, each kept under
// its `charm.partMax` in economy.json; there is NO overall cap:
//
//   pet   = min(partMax.pet, round(pet.charmBase * stageMultiplier[stage]))
//   items = min(partMax.petItems, sum(worn item charm))
//   pots  = min(partMax.sonHaiPots, sum over owned pot TYPES of pot charm)
//
// for the pet in the save's `petCharm` slot (no pet there: 0). An item adds
// only the charm of its tier, only when it sits in its own slot; an unknown
// item or pet adds nothing. A pot type counts once however many copies the
// save owns (`potCounts`), on the shelf or in the cupboard; its charm is the
// pot's `charm`, or `charm.sonHaiCharmPerType` for a Sơn Hải pot without one.
// economy.json is the single source: sync-economy.js copies it next to this
// file before every deploy.

const MIN_CHARM = 20;
const SLOTS = ['neck', 'head', 'accessory'];

/** Reads economy.json into the few tables the score needs. */
function loadEconomy(json) {
  const charm = json.charm || {};
  const byTier = Object.assign(
    { thuong: 5, hiem: 15, suThi: 40, huyenThoai: 100 },
    charm.itemCharmByRarity || {},
  );
  const pets = new Map();
  for (const p of (json.pets && json.pets.list) || []) {
    if (p && typeof p.id === 'string') pets.set(p.id, Number(p.charmBase) || 0);
  }
  const items = new Map();
  for (const it of (json.petItems && json.petItems.list) || []) {
    if (it && typeof it.id === 'string') {
      items.set(it.id, {
        slot: it.slot,
        tier: it.rarity || it.tier,
        price: Number(it.price) > 0 ? Math.trunc(Number(it.price)) : 0,
        currency: it.currency === 'phaLe' ? 'phaLe' : 'coins',
        name: typeof it.nameVi === 'string' ? it.nameVi : it.id,
      });
    }
  }
  const part = charm.partMax || {};
  const perType = Number(charm.sonHaiCharmPerType) > 0 ? Number(charm.sonHaiCharmPerType) : 0;
  const potCharm = new Map();
  for (const p of json.pots || []) {
    if (!p || typeof p.id !== 'string') continue;
    const own = Number(p.charm) > 0 ? Math.trunc(Number(p.charm)) : 0;
    const add = own > 0 ? own : (p.set === 'sonHai' ? perType : 0);
    if (add > 0) potCharm.set(p.id, add);
  }
  const lb = json.leaderboard || {};
  // Season clock (season.js, shared with Bảng Đánh giá): seasonStart is the
  // first season's day in Vietnam (UTC+7) and periodKey its key; the next
  // seasons chain every cycleDays (season-2, season-3, ...).
  const seasonStart = S.vnDay(lb.seasonStart);
  const firstPeriod = lb.periodKey || 'season-1';
  const cycleDays = Number(lb.cycleDays) >= 1 ? Math.trunc(Number(lb.cycleDays)) : 28;
  const clock = S.clock(firstPeriod, seasonStart, cycleDays);
  const itemsByTier = {};
  for (const [id, it] of items) (itemsByTier[it.tier] = itemsByTier[it.tier] || []).push(id);
  return {
    seasonStart,
    cycleDays,
    clock,
    // "Mị Lực Nhất Trời" (leaderboard.championTitle, titles.js); null: none.
    championTitle: require('./titles').titleConfig(json, 'charm'),
    // "Đang chốt bảng" minutes after a close, shared by both boards.
    lockMinutes: S.lockMinutes(json),
    /** The live board key at [now] (the first key without a clock). */
    periodAt: (now) => (clock ? S.seasonAt(clock, now).period : firstPeriod),
    topLimit: Math.min(100, Number(lb.topLimit) >= 1 ? Math.trunc(Number(lb.topLimit)) : 100),
    rewards: Array.isArray(lb.rewards) ? lb.rewards : [],
    itemsByTier,
    // One pet item per rank; "randomNotOwned": among the tier's items the
    // player has not got (payout.js pickSeasonItem). Anything else: any item.
    petItemPick: typeof lb.petItemPick === 'string' ? lb.petItemPick : 'random',
    multipliers: charm.stageMultiplier || [1, 1.5, 2],
    slots: charm.itemSlots || SLOTS,
    byTier,
    pets,
    items,
    potCharm,
    partMax: {
      pet: Number(part.pet) > 0 ? Math.trunc(Number(part.pet)) : 0,
      petItems: Number(part.petItems) > 0 ? Math.trunc(Number(part.petItems)) : 0,
      pots: Number(part.sonHaiPots) > 0 ? Math.trunc(Number(part.sonHaiPots)) : 0,
    },
    // The FIRST season's key; the live one is periodAt(now).
    periodKey: firstPeriod,
    minCharm: lb.minCharmToRank || MIN_CHARM,
  };
}

/** A part kept inside 0..max; a max of 0 means not set (lib/logic/pot_bonus.dart). */
function clampPart(v, max) {
  if (v < 0) return 0;
  return max > 0 && v > max ? max : v;
}

/** The pot part: every owned pot type once (`potCounts` id -> copies). */
function potsCharm(progress, eco, server = null) {
  const counts = progress.potCounts;
  if (!counts || typeof counts !== 'object' || Array.isArray(counts)) return 0;
  let sum = 0;
  for (const [id, n] of Object.entries(counts)) {
    if (!(Number(n) > 0)) continue;
    if (server && !server.pots.has(id)) continue;
    sum += eco.potCharm.get(id) || 0;
  }
  return clampPart(sum, eco.partMax.pots);
}

/** Dart's num.round(): halves round away from zero. */
function roundHalfUp(x) {
  return x < 0 ? -Math.round(-x) : Math.round(x);
}

/**
 * The player's score from `users/{uid}.progress`.
 * Returns {charm, petId, stage, worn}; charm is 0 when the slot is empty or
 * holds a pet the save does not own.
 */
function charmFromProgress(progress, eco, server = null) {
  const none = { charm: 0, petId: '', stage: 0, worn: {} };
  if (!progress || typeof progress !== 'object') return none;
  const id = progress.petCharm;
  if (typeof id !== 'string' || !Array.isArray(progress.pets)) return none;
  const owned = progress.pets.find((p) => p && p.id === id);
  if (!owned || !eco.pets.has(id)) return none;
  // [server] (serverOwned): only what the server sold or gave counts; a pet,
  // item or pot that is only in the save adds 0 (a hacked save can add any).
  if (server && !server.pets.has(id)) return none;
  const stage = Math.min(2, Math.max(0, Math.trunc(Number(owned.stage) || 0)));
  const mult = eco.multipliers[Math.min(stage, eco.multipliers.length - 1)];
  const pet = clampPart(roundHalfUp(eco.pets.get(id) * mult), eco.partMax.pet);
  let items = 0;
  const worn = {};
  const wornRaw = owned.worn && typeof owned.worn === 'object' ? owned.worn : {};
  for (const slot of eco.slots) {
    const itemId = wornRaw[slot];
    if (typeof itemId !== 'string') continue;
    const item = eco.items.get(itemId);
    if (!item || item.slot !== slot) continue;
    if (server && !server.items.has(itemId)) continue;
    items += eco.byTier[item.tier] || 0;
    worn[slot] = itemId;
  }
  const charm = pet + clampPart(items, eco.partMax.petItems) + potsCharm(progress, eco, server);
  return { charm, petId: id, stage, worn };
}

/**
 * What to do with a published row, given the player's save.
 *  - 'ok'     the row is backed by the save (charm <= recomputed)
 *  - 'lower'  the row claims more than the save gives: set it to [target]
 *  - 'remove' the save gives less than the board minimum (or no pet at all)
 */
function judge(entry, progress, eco, server = null) {
  const real = charmFromProgress(progress, eco, server);
  if (real.charm < eco.minCharm) return { verdict: 'remove', real };
  if (entry.charm > real.charm) return { verdict: 'lower', real };
  return { verdict: 'ok', real };
}

/**
 * Pets, pet items and pots the SERVER has a record of for [uid]:
 *   wallets/{uid}.items        Pha lê pet items bought (bought > sold)
 *   wallets/{uid}.wonPots      Sơn Hải pots won on the weekly spin
 *   wallets/{uid}/ledger       type 'buy' (Pha lê shop: pet, pot, petItem)
 *   mails where target == uid  items of a server/admin letter: gacha spins,
 *                              season rewards, admin grants; and letters to
 *                              'all' the player claimed (mailState.claimed)
 * Anything bought with xu lives only in the save: no record, so it is not
 * here (xu is still client-side, see wallet.js).
 */
async function serverOwned(db, uid) {
  const out = { pets: new Set(), items: new Set(), pots: new Set() };
  const add = (kind, id) => {
    if (typeof id !== 'string' || !id) return;
    if (kind === 'pet') out.pets.add(id);
    else if (kind === 'petItem') out.items.add(id);
    else if (kind === 'pot') out.pots.add(id);
  };
  const w = await db.doc(`wallets/${uid}`).get();
  const wallet = w.exists ? w.data() : {};
  for (const [id, row] of Object.entries(wallet.items || {})) {
    if (row && Number(row.bought) > Number(row.sold || 0)) add('petItem', id);
  }
  for (const id of Array.isArray(wallet.wonPots) ? wallet.wonPots : []) add('pot', id);
  const buys = await db.collection(`wallets/${uid}/ledger`).where('type', '==', 'buy').get();
  for (const d of buys.docs) {
    const r = d.data();
    if (r.kind !== 'petItem') add(r.kind, r.id); // pet items: wallet.items (resale aware)
  }
  const mails = await db.collection('mails').where('target', '==', uid).get();
  for (const d of mails.docs) {
    const items = (d.data().rewards || {}).items;
    for (const it of Array.isArray(items) ? items : []) if (it) add(it.kind, it.id);
  }
  // Letters to everyone ('all') count once the player claimed them.
  for (const m of await require('./anti_cheat').claimedAllMails(db, uid, null)) {
    const items = (m.rewards || {}).items;
    for (const it of Array.isArray(items) ? items : []) if (it) add(it.kind, it.id);
  }
  return out;
}

/** The reward line of [rank] (leaderboard.rewards), or null. */
function rewardFor(rank, eco) {
  for (const r of eco.rewards) {
    if (rank >= r.rankFrom && rank <= r.rankTo) return r;
  }
  return null;
}

module.exports = {
  rewardFor,
  serverOwned, MIN_CHARM, SLOTS, loadEconomy, charmFromProgress, judge, roundHalfUp, potsCharm,
};
