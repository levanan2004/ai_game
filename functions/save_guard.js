'use strict';
// Server check of every cloud save write (users/{uid}), against Hà Phương's
// thresholds (nguong_chong_hack.json, anti_cheat.js). The save is written by
// the app, so a hacked client can put any number in it; xu (progress.money)
// is still client-side (moving the xu wallet to the server is a later task).
//
//   save_guard/{uid}   server only: {day, money, at} of the last save that
//                      passed (server clock).
//
// A new save, compared with the last one that passed:
//   * xu gained <= maxCoinsPerGameDay for each game day played (day 1-9 and
//     day 10+ rates) + the xu the server knows it gave since then (Pha lê
//     exchange in wallets/{uid}/ledger, xu in letters: season rewards, gacha,
//     admin; admin gift / grant and gift codes) + login xu by real weeks.
//     Game days count only as fast as minGameDaySeconds allows on the server
//     clock (skipping days by editing `day` buys nothing); the game day in
//     progress counts once more (xu earned before the day ends).
//   * no game day in the save with more than maxReviewsPerGameDay reviews or
//     maxStarsPerGameDay stars.
// A save over a limit is REVERTED (users/{uid}.progress back to the save
// before it) and the account flagged (cheat_flags, anti_cheat.js): off both
// boards, no season reward. The first save the server sees has no previous
// one: it is only checked against the total ceiling (startCash + every game
// day at the max rate + all known server xu) and flagged, not reverted.

const AC = require('./anti_cheat');
const { toDate } = require('./payout');

const DAY_MS = 86400000;
const COIN_KEY = /^(coins?|xu|money)$/i;

/** Xu of a letter / gift items list or map. */
function coinsIn(items) {
  let sum = 0;
  if (Array.isArray(items)) {
    for (const it of items) if (it && it.kind === 'coins') sum += AC.int(it.amount);
  } else if (items && typeof items === 'object') {
    for (const [k, v] of Object.entries(items)) if (COIN_KEY.test(k)) sum += AC.int(v);
  }
  return sum;
}

/** Xu the server gave [uid] since [since] (null: ever). */
async function serverCoins(db, uid, since, user) {
  const after = (v) => !since || ((toDate(v) || new Date(0)).getTime() >= since.getTime());
  let sum = 0;
  const ex = await db.collection(`wallets/${uid}/ledger`).where('type', '==', 'exchange').get();
  for (const d of ex.docs) if (after(d.data().at)) sum += AC.int(d.data().coins);
  const mails = await db.collection('mails').where('target', '==', uid).get();
  for (const d of mails.docs) {
    const m = d.data();
    if (after(m.createdAt)) sum += coinsIn((m.rewards || {}).items);
  }
  const redeemed = await db.collection(`users/${uid}/redeemed`).get();
  for (const d of redeemed.docs) {
    if (!after(d.data().redeemedAt)) continue;
    const b = await db.doc(`giftcodeBatches/${d.id}`).get();
    if (b.exists) sum += coinsIn(((b.data() || {}).rewards || {}).items);
  }
  // Admin gift / grant on the user doc: counted whenever present (generous).
  const u = user || {};
  sum += coinsIn(u.gift && u.gift.items) + coinsIn(u.grant && (u.grant.items || u.grant));
  return sum;
}

/** Game days whose reviews break the per-day limits (days in [from, to)). */
function badReviewDays(th, progress, from, to) {
  const byDay = new Map();
  for (const r of Array.isArray(progress.reviews) ? progress.reviews : []) {
    if (!r || !Number.isInteger(r.day) || r.day < from || r.day >= to) continue;
    const s = Number.isInteger(r.stars) ? r.stars : 0;
    const d = byDay.get(r.day) || { n: 0, stars: 0 };
    d.n++; d.stars += s;
    byDay.set(r.day, d);
  }
  const bad = [];
  for (const [day, d] of byDay) {
    if ((th.maxReviewsPerGameDay && d.n > th.maxReviewsPerGameDay)
      || (th.maxStarsPerGameDay && d.stars > th.maxStarsPerGameDay)) bad.push(day);
  }
  return bad.sort((a, b) => a - b);
}

/**
 * Pure decision. [state] save_guard/{uid} (or null), [extra] server xu since
 * state.at (or ever, when no state). Returns {ok, reasons, state, allowed}.
 */
function judgeSave(th, state, progress, now, extra) {
  const day = Number.isInteger(progress.day) && progress.day >= 1 ? progress.day : 1;
  const money = Number.isFinite(Number(progress.money)) ? Math.floor(Number(progress.money)) : 0;
  const next = { day, money, at: now };
  if (!state || !Number.isInteger(state.day) || day < state.day) {
    // First save seen, or a new game: the total ceiling only.
    const allowed = th.startCash + AC.maxPlayCoins(th, 0, day) + th.alphaGiftOnce + extra
      + th.loginCoinsPerRealWeek * Math.ceil(day / 7);
    const reasons = money > allowed ? ['coins_total'] : [];
    return { ok: true, reasons, state: next, allowed, revert: false };
  }
  const since = toDate(state.at) || now;
  const secs = Math.max(0, (now.getTime() - since.getTime()) / 1000);
  const k = day - state.day;
  const kEff = th.minGameDaySeconds > 0 ? Math.min(k, Math.floor(secs / th.minGameDaySeconds)) : k;
  const login = th.loginCoinsPerRealWeek * Math.ceil(Math.max(1, secs * 1000 / DAY_MS) / 7);
  const allowed = AC.maxPlayCoins(th, state.day - 1, state.day + kEff) + extra + login;
  const reasons = [];
  if (money - AC.int(state.money) > allowed) reasons.push('coins_gain');
  if (badReviewDays(th, progress, state.day, day).length) reasons.push('stars_day');
  const ok = reasons.length === 0;
  return { ok, reasons, state: ok ? next : state, allowed, revert: !ok };
}

/**
 * The users/{uid} write trigger. [before] / [after] are the doc data.
 * Returns {ok, reasons, reverted}.
 */
async function guard({ db, uid, before, after, now, logger, th = AC.thresholds() }) {
  const progress = after && after.progress;
  if (!th || !progress || typeof progress !== 'object') return { ok: true, reasons: [] };
  const ref = db.doc(`save_guard/${uid}`);
  const snap = await ref.get();
  const state = snap.exists ? snap.data() : null;
  const since = state ? toDate(state.at) : null;
  const extra = await serverCoins(db, uid, since, after);
  const r = judgeSave(th, state, progress, now, extra);
  await ref.set(r.state);
  if (!r.reasons.length) return { ok: true, reasons: [] };
  await AC.flag(db, uid, r.reasons, {
    saveDay: progress.day || null, saveMoney: Number(progress.money) || 0, allowed: r.allowed,
  }, now);
  let reverted = false;
  if (r.revert && before && before.progress && typeof before.progress === 'object') {
    // Only progress: the rules let the app write a fixed set of keys, so no
    // marker field is added. The next trigger sees the old save and passes.
    await db.doc(`users/${uid}`).update({ progress: before.progress });
    reverted = true;
  }
  if (logger) logger.warn('save guard: account flagged', { uid, reasons: r.reasons, allowed: r.allowed, reverted });
  return { ok: false, reasons: r.reasons, reverted };
}

module.exports = { coinsIn, serverCoins, badReviewDays, judgeSave, guard };
