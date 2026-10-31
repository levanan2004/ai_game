'use strict';
// Anti-cheat for hacked clients that edit their own save (users/{uid}).
// Thresholds are Hà Phương's nguong_chong_hack.json (assets/data, copied next
// to this file by sync-economy.js); nothing here is a tuned number.
//
//   cheat_flags/{uid}   server only: {flagged: true, reasons: [..], firstAt,
//                       at, details}. A flagged account is left off both
//                       boards and gets no season reward. It is NOT locked:
//                       it can still play. An admin clears it by deleting
//                       the doc.

const int = (v) => (Number.isFinite(Number(v)) ? Math.max(0, Math.floor(Number(v))) : 0);

/** nguong_chong_hack.json -> the numbers the checks need. */
function loadThresholds(json) {
  const j = json || {};
  const perDay = j.maxCoinsPerGameDay || {};
  const rv = j.reviews || {};
  const rs = j.ratingSuspicion || {};
  const extra = j.extraCoinSourcesOutsideGameDays || {};
  const coinOnly = (j.charm && j.charm.coinOnlyMax) || {};
  return {
    startCash: int(j.startCash),
    coinsDay1to9: int(perDay.day1to9),
    coinsDay10plus: int(perDay.day10plus),
    loginCoinsPerRealWeek: int(extra.loginCoinsPerRealWeek),
    alphaGiftOnce: int(extra.alphaGiftOnce),
    maxReviewsPerGameDay: int(rv.maxReviewsPerGameDay),
    maxStarsPerGameDay: int(rv.maxStarsPerGameDay),
    minGameDaySeconds: Number(rv.minGameDaySeconds) > 0 ? Number(rv.minGameDaySeconds) : 0,
    windowGameDays: int(rs.windowGameDays),
    minReviewsInWindow: int(rs.minReviewsInWindow),
    fiveStarShareMin: Number(rs.fiveStarShareMin) > 0 ? Number(rs.fiveStarShareMin) : 0,
    // One-time backfill of xu pets / items bought before coinBuy existed.
    backfillPetCharm: int(coinOnly.pet),
    backfillItemCharm: int(coinOnly.petItems),
  };
}

let cached = null;
/** The deployed thresholds (null when the file is missing: checks are off). */
function thresholds() {
  if (cached === null) {
    try { cached = loadThresholds(require('./nguong_chong_hack.json')); } catch (_) { cached = false; }
  }
  return cached || null;
}

/** Max xu earned by playing game days (from, to]: day 1-9 and day 10+ rates. */
function maxPlayCoins(th, fromDay, toDay) {
  let sum = 0;
  for (let d = Math.max(1, fromDay + 1); d <= toDay; d++) sum += d < 10 ? th.coinsDay1to9 : th.coinsDay10plus;
  return sum;
}

/**
 * Letters to everyone (target 'all') that [uid] claimed, claimed at or after
 * [since] (null: ever): users/{uid}/mailState/{mailId}.claimed.
 */
async function claimedAllMails(db, uid, since) {
  const out = [];
  const marks = await db.collection(`users/${uid}/mailState`).where('claimed', '==', true).get();
  for (const d of marks.docs) {
    const at = toDate(d.data().claimedAt);
    if (since && !(at && at.getTime() >= since.getTime())) continue;
    const m = await db.doc(`mails/${d.id}`).get();
    if (m.exists && m.data().target === 'all') out.push(m.data());
  }
  return out;
}

/** Firestore Timestamp, Date, millis or ISO string -> Date (or null). */
function toDate(v) {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof v.toDate === 'function') return v.toDate();
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** True when cheat_flags/{uid} says flagged. */
async function isFlagged(db, uid) {
  const s = await db.doc(`cheat_flags/${uid}`).get();
  return s.exists && s.data().flagged === true;
}

/** The flagged uids among [uids] (one getAll per 100). */
async function flaggedOf(db, uids) {
  const out = new Set();
  for (let i = 0; i < uids.length; i += 100) {
    const refs = uids.slice(i, i + 100).map((u) => db.doc(`cheat_flags/${u}`));
    if (!refs.length) continue;
    for (const s of await db.getAll(...refs)) if (s.exists && s.data().flagged === true) out.add(s.id);
  }
  return out;
}

/** Adds [reasons] to cheat_flags/{uid} (kept, never removed here). */
async function flag(db, uid, reasons, details, now) {
  const ref = db.doc(`cheat_flags/${uid}`);
  const old = await ref.get();
  const d = old.exists ? old.data() : {};
  const all = [...new Set([...(d.reasons || []), ...reasons])];
  await ref.set({
    flagged: true, reasons: all, firstAt: d.firstAt || now, at: now,
    details: { ...(d.details || {}), ...(details || {}) },
  });
  return all;
}

module.exports = { claimedAllMails, toDate, int, loadThresholds, thresholds, maxPlayCoins, isFlagged, flaggedOf, flag };
