'use strict';
// Automatic season payout of Bảng Đánh giá: the Mị lực payout's flow
// (payout.js) on the rating board, with Hà Phương's own reward table
// (economy.json ratingBoard.rewards: Pha lê, giọt hoa, xu, no pet item; #1
// also gets the title "Tiệm 5 sao mùa") and Nhất's letter (mục 11).
//
// One tick (runRatingPayout), on the same kill switch as the Mị lực payout
// (config/charmPayout.autoPayout === false pays nobody):
//   every rating_board/{period} whose endsAt + 5 min has passed and whose
//   payout.status is not 'done' is paid (payRatingPeriod).
//
// payRatingPeriod(period):
//   * the rows the server scored with at least minRatingsToRank reviews
//     (sortKey > 0) are ranked: higher sortKey first (score to 3 decimals,
//     then more reviews), then who reached it first, then uid;
//   * the top topLimit (100) with a reward line get it;
//   * a row is HELD (no mail; review line "held" with its items) when the
//     account was created inside the season (new_account, as on Mị lực);
//     the admin's "Duyệt thưởng" in /quan-tri pays it (lib/logic/charm_payout.dart);
//   * every other row gets ONE mail mails/bxh_{period}_{uid}, created only
//     if absent (a rerun never doubles a reward);
//   * the #1, once paid, is written as rating_board/{period}.champion: the
//     app shows "Tiệm 5 sao mùa" on that shop's card during the next season.
// Lines go to rating_board/{period}/review/{uid}, the summary to
// rating_board/{period}.payout.

const {
  GRACE_MS, BOARD_NAMES, groupDigits, listVi, toDate, createIfAbsent, loadUsers, autoPayoutOn,
} = require('./payout');
const { ratingConfig } = require('./rating_board');
const S = require('./season');

const USER_CHUNK = 100;

/** The reward line of [rank] in ratingBoard.rewards, or null. */
function ratingRewardFor(rank, cfg) {
  for (const r of cfg.rewards || []) {
    if (r && rank >= Number(r.rankFrom) && rank <= Number(r.rankTo)) return r;
  }
  return null;
}

const pos = (v) => (Number(v) > 0 ? Math.trunc(Number(v)) : 0);

/** Pha lê, giọt hoa, xu of a line (only the non-zero ones). */
function ratingRewardItems(line) {
  const items = [];
  if (pos(line.phaLe)) items.push({ kind: 'phaLe', amount: pos(line.phaLe) });
  if (pos(line.giotHoa)) items.push({ kind: 'giotHoa', amount: pos(line.giotHoa) });
  if (pos(line.coins)) items.push({ kind: 'coins', amount: pos(line.coins) });
  return items;
}

/**
 * Title and body, Nhất's keys verbatim: season.reward.mail_title with
 * {board_name} = season.board.review, season.reward.review.mail_body with
 * {reward_list} = the non-zero items joined like her example ("200 Pha lê,
 * 20 giọt hoa, 10.000.000 xu và danh hiệu "Tiệm 5 sao mùa""), the title by
 * season.reward.review.title_line. Same text in lib/logic/charm_payout.dart
 * ratingMailText.
 */
function ratingMailText({ rank, line }) {
  const parts = [];
  if (pos(line.phaLe)) parts.push(`${groupDigits(pos(line.phaLe))} Pha lê`);
  if (pos(line.giotHoa)) parts.push(`${groupDigits(pos(line.giotHoa))} giọt hoa`);
  if (pos(line.coins)) parts.push(`${groupDigits(pos(line.coins))} xu`);
  if (typeof line.badge === 'string' && line.badge) {
    // title_line 'Danh hiệu "{title_name}"', lower-case inside the list.
    parts.push(`danh hiệu "${line.badge}"`);
  }
  return {
    title: `Thưởng mùa ${BOARD_NAMES.review}: hạng ${rank}`,
    body: `Chúc mừng bạn đạt hạng ${rank} bảng Đánh giá mùa này! Quà của bạn: ${listVi(parts)}.`,
  };
}

function ratingRewardMail({ rank, uid, line, now }) {
  const items = ratingRewardItems(line);
  const text = ratingMailText({ rank, line });
  return {
    title: text.title,
    body: text.body,
    target: uid,
    rewards: { items },
    ...(items.some((i) => i.kind === 'phaLe') ? { walletClaim: true } : {}),
    createdAt: now,
  };
}

/** Pays one rating period. Returns the summary also stored in the meta doc. */
async function payRatingPeriod({ db, eco, period, meta, now, authCreated, logger }) {
  const log = logger || { info() {}, warn() {} };
  const cfg = ratingConfig(eco, now);
  if (!cfg) return { status: 'no-config' };
  const onClock = S.seasonOf(cfg.clock, period);
  const seasonStart = toDate(meta.startsAt) || (onClock && onClock.start);
  const snap = await db.collection(`rating_board/${period}/entries`).where('sortKey', '>', 0).get();
  const rows = snap.docs.map((d) => ({ uid: d.id, entry: d.data() }))
    .filter((r) => Number(r.entry.v) >= cfg.minToRank)
    .map((r) => ({
      ...r,
      key: Number(r.entry.sortKey) || 0,
      reachedAt: (toDate(r.entry.reachedAt) || toDate(r.entry.updatedAt) || now).getTime(),
    }));
  rows.sort((a, b) =>
    b.key - a.key || a.reachedAt - b.reachedAt || (a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0));
  const top = rows.slice(0, cfg.topLimit);
  const uids = top.map((r) => r.uid);
  const users = await loadUsers(db, uids);
  const created = authCreated ? await authCreated(uids) : new Map();
  const prior = new Map();
  for (let i = 0; i < uids.length; i += USER_CHUNK) {
    const refs = uids.slice(i, i + USER_CHUNK).map((u) => db.doc(`rating_board/${period}/review/${u}`));
    if (refs.length) for (const s of await db.getAll(...refs)) if (s.exists) prior.set(s.id, s.data());
  }

  const review = [];
  let sent = 0;
  let already = 0;
  let held = 0;
  let failed = 0;
  let champion = null;
  for (let i = 0; i < top.length; i++) {
    const r = top[i];
    const rank = i + 1;
    const line = ratingRewardFor(rank, cfg);
    if (!line) continue;
    const before = prior.get(r.uid);
    if (before && before.status === 'released') continue; // the admin already paid
    const user = users.get(r.uid) || {};
    const info = {
      uid: r.uid, displayName: String(r.entry.displayName || ''), rank,
      v: Number(r.entry.v) || 0, score: Number(r.entry.score) || 0,
    };
    const items = ratingRewardItems(line);
    const flags = [];
    const madeAt = toDate(created.get(r.uid)) || toDate(user.joinedAt);
    if (seasonStart && madeAt && madeAt.getTime() >= seasonStart.getTime()) flags.push('new_account');
    if (before && before.status === 'held') {
      for (const f of before.flags || []) if (!flags.includes(f)) flags.push(f);
    }
    if (flags.length > 0) {
      held++;
      review.push({ ...info, status: 'held', flags, items, ...(line.badge ? { badge: line.badge } : {}) });
      continue;
    }
    const mailId = `bxh_${period}_${r.uid}`;
    try {
      const made = await createIfAbsent(db.doc(`mails/${mailId}`), ratingRewardMail({ rank, uid: r.uid, line, now }));
      if (made) sent++; else already++;
      review.push({ ...info, status: 'sent', mailId });
      if (rank === 1 && line.badge) champion = r.uid;
    } catch (e) {
      failed++;
      log.warn('rating payout: mail failed', { period, uid: r.uid, message: String(e && e.message) });
      review.push({ ...info, status: 'failed', mailId });
    }
  }

  for (const l of review) {
    const ref = db.doc(`rating_board/${period}/review/${l.uid}`);
    const old = await ref.get();
    if (old.exists && old.data().status === 'released') continue;
    await ref.set({ ...l, createdAt: now });
  }
  // Same closing lock as the Mị lực board (season.lockMinutesAfterClose).
  const lock = S.lockInfo(toDate(meta.endsAt) || (onClock && onClock.end), cfg.lockMinutes, now);
  if (lock.late) log.warn('rating payout after the closing lock', { period, lockedUntil: lock.lockedUntil });
  const summary = {
    status: failed > 0 ? 'partial' : 'done',
    at: now, rows: rows.length, ranked: top.length,
    sent: sent + already, created: sent, held, skipped: 0, failed,
    ...(lock.lockedUntil ? { lockedUntil: lock.lockedUntil, lateAfterLock: lock.late } : {}),
  };
  await db.doc(`rating_board/${period}`).set(
    { payout: summary, ...(champion ? { champion } : {}) }, { merge: true });
  log.info('rating payout', { period, ...summary, champion });
  return summary;
}

/** One scheduler tick of the rating board payout. */
async function runRatingPayout({ db, eco, now, authCreated, logger }) {
  const log = logger || { info() {}, warn() {} };
  const result = { paid: {}, skipped: null };
  if (!ratingConfig(eco, now)) return { ...result, skipped: 'no-board' };
  if (!(await autoPayoutOn(db))) {
    log.warn('rating payout: autoPayout is off, nothing paid');
    return { ...result, skipped: 'autoPayout-off' };
  }
  const cutoff = new Date(now.getTime() - GRACE_MS);
  const due = await db.collection('rating_board').where('endsAt', '<=', cutoff).get();
  for (const d of due.docs) {
    const meta = d.data();
    if (meta.payout && meta.payout.status === 'done') continue;
    result.paid[d.id] = await payRatingPeriod({ db, eco, period: d.id, meta, now, authCreated, logger });
  }
  return result;
}

module.exports = {
  ratingRewardFor, ratingRewardItems, ratingMailText, ratingRewardMail, payRatingPeriod, runRatingPayout,
};
