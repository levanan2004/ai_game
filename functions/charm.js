'use strict';
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
  // Season clock: seasonStart is a day in Vietnam (UTC+7), as in
  // lib/data/charm_board.dart; a season is cycleDays long.
  let seasonStart = null;
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(lb.seasonStart || ''));
  if (m) seasonStart = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]) - 7 * 3600 * 1000);
  const itemsByTier = {};
  for (const [id, it] of items) (itemsByTier[it.tier] = itemsByTier[it.tier] || []).push(id);
  return {
    seasonStart,
    cycleDays: Number(lb.cycleDays) >= 1 ? Math.trunc(Number(lb.cycleDays)) : 28,
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
    periodKey: lb.periodKey || 'season-1',
    minCharm: lb.minCharmToRank || MIN_CHARM,
  };
}

/** A part kept inside 0..max; a max of 0 means not set (lib/logic/pot_bonus.dart). */
function clampPart(v, max) {
  if (v < 0) return 0;
  return max > 0 && v > max ? max : v;
}

/** The pot part: every owned pot type once (`potCounts` id -> copies). */
function potsCharm(progress, eco) {
  const counts = progress.potCounts;
  if (!counts || typeof counts !== 'object' || Array.isArray(counts)) return 0;
  let sum = 0;
  for (const [id, n] of Object.entries(counts)) {
    if (!(Number(n) > 0)) continue;
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
function charmFromProgress(progress, eco) {
  const none = { charm: 0, petId: '', stage: 0, worn: {} };
  if (!progress || typeof progress !== 'object') return none;
  const id = progress.petCharm;
  if (typeof id !== 'string' || !Array.isArray(progress.pets)) return none;
  const owned = progress.pets.find((p) => p && p.id === id);
  if (!owned || !eco.pets.has(id)) return none;
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
    items += eco.byTier[item.tier] || 0;
    worn[slot] = itemId;
  }
  const charm = pet + clampPart(items, eco.partMax.petItems) + potsCharm(progress, eco);
  return { charm, petId: id, stage, worn };
}

/**
 * What to do with a published row, given the player's save.
 *  - 'ok'     the row is backed by the save (charm <= recomputed)
 *  - 'lower'  the row claims more than the save gives: set it to [target]
 *  - 'remove' the save gives less than the board minimum (or no pet at all)
 */
function judge(entry, progress, eco) {
  const real = charmFromProgress(progress, eco);
  if (real.charm < eco.minCharm) return { verdict: 'remove', real };
  if (entry.charm > real.charm) return { verdict: 'lower', real };
  return { verdict: 'ok', real };
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
  MIN_CHARM, SLOTS, loadEconomy, charmFromProgress, judge, roundHalfUp, potsCharm,
};
