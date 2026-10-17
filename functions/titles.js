'use strict';
// Champion titles, title counts and best ranks (An 17/10 19:46, Hà Phương
// 19:47: economy.json ratingBoard.championTitle and leaderboard.championTitle,
// "title transfers"). Two fixed titles, one holder each:
//   de_nhat_goi_hoa   #1 of Bảng Đánh giá   (name: ratingBoard.championTitle.name)
//   mi_luc_nhat_troi  #1 of Bảng Mị lực      (name: leaderboard.championTitle.name)
// At a season's payout the #1 takes the title; the previous holder loses it
// (and its pin), unless they are the #1 again. Names come from the config.
//
// Written only by functions (payouts, titlePin, titleRelease); the rules
// refuse every app write:
//   titles/{titleId}           {titleId, board, kind: 'transfer', holderUid,
//                               period, since, rank, seasonStart, seasonEnd}
//   public_profiles/{uid}
//     titleStats.{titleId}     {timesWon, lastPeriod, periods} ("Đã từng giữ
//                              {n} mùa", "×{n}"; periods makes a rerun count
//                              once); kept after the title is lost. A
//                              permanent title (kind 'permanent', e.g. the
//                              coming customers-served milestones) is an entry
//                              {permanent: true, since} here, with no titles/
//                              doc: it is held for good.
//     pinnedTitle              the titleId worn; '' for none. Only a title
//                              held now can be pinned; cleared when lost.
//     bestRank.{charm|review}  {rank, period, at}: best rank reached at a
//                              season's payout (top topLimit), only lowered.

const S = require('./season');

const TITLE_IDS = Object.freeze({ review: 'de_nhat_goi_hoa', charm: 'mi_luc_nhat_troi' });
const BLOCKS = Object.freeze({ review: 'ratingBoard', charm: 'leaderboard' });

class TitleError extends Error {
  constructor(code) { super(code); this.code = code; }
}

/**
 * The championTitle block of [board] ('review' | 'charm') in economy.json:
 * {id, board, name, rank}; null without one (that board gives no title).
 */
function titleConfig(eco, board) {
  const block = eco && BLOCKS[board] ? eco[BLOCKS[board]] : null;
  const ct = block && typeof block === 'object' ? block.championTitle : null;
  if (!ct || typeof ct !== 'object' || typeof ct.name !== 'string' || !ct.name.trim()) return null;
  const rank = Number(ct.rank) >= 1 ? Math.trunc(Number(ct.rank)) : 1;
  return { id: TITLE_IDS[board], board, name: ct.name, rank };
}

/** Season number of a period key ("rating-3" -> 3); NaN without one. */
const periodNo = (p) => { const s = S.splitKey(p); return s ? s[1] : NaN; };

/**
 * [uid], #1 of [board]'s season [period], takes that board's title. In one
 * transaction:
 *   * titleStats.{id} of the winner counts the season once (timesWon + 1,
 *     lastPeriod), even when a later season already moved the title on;
 *   * titles/{id} moves to the winner unless it already holds a LATER season
 *     (a held #1 released late never takes the title back);
 *   * the previous holder, when someone else, loses its pin of that title.
 * Rerunning the same period changes nothing. [tc] is titleConfig(eco,
 * board). Returns {counted, moved}, or null without a title.
 */
async function transferTitle(db, tc, { uid, period, seasonStart, seasonEnd, now }) {
  if (!tc || !uid || !period) return null;
  const board = tc.board;
  const titleRef = db.doc(`titles/${tc.id}`);
  const winRef = db.doc(`public_profiles/${uid}`);
  return db.runTransaction(async (tx) => {
    const cur = await tx.get(titleRef);
    const win = await tx.get(winRef);
    const held = cur.exists ? cur.data() : null;
    const prevUid = held && typeof held.holderUid === 'string' ? held.holderUid : '';
    const newer = held && Number.isFinite(periodNo(held.period)) && periodNo(held.period) > periodNo(period);
    const same = held && held.period === period;
    const move = !newer && !same;
    const prev = move && prevUid && prevUid !== uid ? await tx.get(db.doc(`public_profiles/${prevUid}`)) : null;

    const stats = win.exists && win.data().titleStats && typeof win.data().titleStats === 'object'
      ? win.data().titleStats : {};
    const mine = stats[tc.id] && typeof stats[tc.id] === 'object' ? stats[tc.id] : {};
    const counted = mine.lastPeriod !== period && !(Array.isArray(mine.periods) && mine.periods.includes(period));
    if (counted) {
      const last = typeof mine.lastPeriod === 'string' && periodNo(mine.lastPeriod) > periodNo(period)
        ? mine.lastPeriod : period;
      const periods = [...(Array.isArray(mine.periods) ? mine.periods : []), period];
      tx.set(winRef, {
        titleStats: {
          ...stats,
          [tc.id]: { timesWon: (Number(mine.timesWon) || 0) + 1, lastPeriod: last, periods },
        },
      }, { merge: true });
    }
    if (move) {
      tx.set(titleRef, {
        titleId: tc.id, board, kind: 'transfer', holderUid: uid, period, since: now, rank: tc.rank,
        seasonStart: seasonStart || null, seasonEnd: seasonEnd || null,
      });
      if (prev && prev.exists && prev.data().pinnedTitle === tc.id) {
        tx.set(prev.ref, { pinnedTitle: '' }, { merge: true });
      }
    }
    return { counted, moved: move };
  });
}

/**
 * public_profiles/{uid}.bestRank.{board} for every [{uid, rank}] of a paid
 * period: written when there is none or [rank] is better. Returns how many
 * changed.
 */
async function recordBestRanks(db, board, period, ranks, now) {
  let changed = 0;
  for (const { uid, rank } of ranks) {
    if (!uid || !(rank >= 1)) continue;
    const ref = db.doc(`public_profiles/${uid}`);
    const did = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.exists ? snap.data() : {};
      const best = data.bestRank && typeof data.bestRank === 'object' ? data.bestRank : {};
      const cur = best[board];
      if (cur && Number(cur.rank) >= 1 && Number(cur.rank) <= rank) return false;
      tx.set(ref, { bestRank: { ...best, [board]: { rank, period, at: now } } }, { merge: true });
      return true;
    });
    if (did) changed++;
  }
  return changed;
}

/** Whether [uid] holds [titleId] now: the transfer holder, or a permanent entry. */
function holds(uid, titleId, holderDoc, stats) {
  const s = stats && stats[titleId];
  if (s && typeof s === 'object' && s.permanent === true) return true;
  return !!holderDoc && holderDoc.holderUid === uid;
}

/**
 * Callable titlePin {id}: wears the title [id], or none for ''/null.
 * Returns {pinnedTitle}. Errors: 'bad-id' (not a title), 'not-held' (only
 * the current holder wears a champion title; profile.titles.wear_locked).
 */
async function pin({ db, uid, data }) {
  const raw = data ? data.id : null;
  if (raw != null && typeof raw !== 'string') throw new TitleError('bad-id');
  const id = typeof raw === 'string' ? raw.trim() : '';
  if (id.length > 64 || (id && !/^[a-z0-9_]+$/.test(id))) throw new TitleError('bad-id');
  const ref = db.doc(`public_profiles/${uid}`);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!id) {
      if (snap.exists && snap.data().pinnedTitle) tx.set(ref, { pinnedTitle: '' }, { merge: true });
      return { pinnedTitle: '' };
    }
    const stats = snap.exists ? snap.data().titleStats : null;
    const isTransfer = Object.values(TITLE_IDS).includes(id);
    const holder = isTransfer ? await tx.get(db.doc(`titles/${id}`)) : null;
    if (!holds(uid, id, holder && holder.exists ? holder.data() : null, stats)) {
      throw new TitleError(isTransfer || (stats && stats[id]) ? 'not-held' : 'bad-id');
    }
    tx.set(ref, { pinnedTitle: id }, { merge: true });
    return { pinnedTitle: id };
  });
}

/**
 * Admin callable titleRelease {period}: after "Duyệt thưởng" of a held #1
 * (lib/logic/charm_payout.dart), that #1 takes the board's title like an
 * automatic payout would. Only a review line of rank 1 that the admin has
 * released counts. Errors: 'not-admin', 'bad-period', 'not-released'.
 */
async function release({ db, eco, uid, data, now, isAdmin }) {
  if (!isAdmin || !(await isAdmin(uid))) throw new TitleError('not-admin');
  const period = data && typeof data.period === 'string' ? data.period : '';
  const board = period.startsWith('rating-') ? 'review' : period.startsWith('season-') ? 'charm' : '';
  if (!board) throw new TitleError('bad-period');
  const root = board === 'review' ? 'rating_board' : 'charm_board';
  const lines = await db.collection(`${root}/${period}/review`).where('rank', '==', 1).get();
  const line = lines.docs.map((d) => ({ uid: d.id, ...d.data() })).find((l) => l.status === 'released');
  if (!line) throw new TitleError('not-released');
  const meta = (await db.doc(`${root}/${period}`).get()).data() || {};
  const toDate = (v) => (v instanceof Date ? v : v && typeof v.toDate === 'function' ? v.toDate() : null);
  const r = await transferTitle(db, titleConfig(eco, board), {
    uid: line.uid, period, seasonStart: toDate(meta.startsAt), seasonEnd: toDate(meta.endsAt), now,
  });
  return { uid: line.uid, ...(r || { counted: false, moved: false }) };
}

module.exports = {
  TITLE_IDS, TitleError, titleConfig, periodNo, transferTitle, recordBestRanks, holds, pin, release,
};
