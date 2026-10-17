'use strict';
// Bảng xếp hạng Đánh giá (spec Phú mục 2; economy.json `ratingBoard`, Hà
// Phương's block). The server is the only writer: the app cannot write a
// score. Every write of users/{uid} (the cloud save, written each morning)
// runs `ingest`, which counts the reviews of the game days finished since the
// last save it saw, after these checks (ratingBoard.antiFarm):
//   - a game day is measured on the SERVER clock: from the first save that
//     showed that day to the first save that shows a later one. A jump of k
//     days needs k x minGameDaySeconds (200 s) or none of its reviews count.
//   - a game day with more than maxReviewsPerGameDay (60) reviews counts 0.
//   - at most dailyCountedCap (100) counted per day in Vietnam, at most
//     seasonCountedCap (2.800) per season.
//   - only while a season runs: from the first season (seasonStart, rating-2)
//     on, seasons chain every cycleDays on the shared clock (season.js).
//   - the first save the server ever sees only starts the clock.
// The save keeps the newest 50 reviews (GameState.maxSavedReviews), so days
// played offline across many mornings may lose some reviews: never more.
//
//   rating_state/{uid}                    server only: clock, counters
//   rating_board/{period}                 {totalV, totalSum, C, updatedAt}
//   rating_board/{period}/entries/{uid}   {uid, displayName, avatar, v, sum,
//                                          R, score, sortKey, reachedAt,
//                                          updatedAt}
//
// score = (v*R + m*C)/(v + m). C = totalSum/totalV of the season once totalV
// reaches C.fallbackUntilRatings (2.000), else C.fallback (4,0); `refresh`
// (every refreshMinutes) moves C and rescores every row. sortKey packs the
// tie-break (score rounded to 3 decimals, then more reviews) into one number
// so a single-field index orders the board; 0 below minRatingsToRank (50).
// reachedAt moves only when sortKey changes (who got there first).

const S = require('./season');

const VN_MS = 7 * 3600 * 1000;

function num(x, d) {
  return typeof x === 'number' && Number.isFinite(x) ? x : d;
}

/**
 * economy.json `ratingBoard` -> the numbers the server needs at [now] (null:
 * no board). periodKey / seasonStart are the board's FIRST season (rating-2,
 * 09/11/2026); later seasons chain on the shared clock (season.js), so
 * `period`, `start` and `end` are the season running at [now] (the first
 * one, not started, before 09/11).
 */
function ratingConfig(eco, now = new Date()) {
  const rb = eco && eco.ratingBoard;
  if (!rb || typeof rb !== 'object') return null;
  const first = S.vnDay(rb.seasonStart);
  const days = Math.max(1, Math.trunc(num(rb.cycleDays, 28)));
  const c = rb.C && typeof rb.C === 'object' ? rb.C : {};
  const firstPeriod = typeof rb.periodKey === 'string' && /^[a-z0-9][a-z0-9_-]{0,23}$/.test(rb.periodKey)
    ? rb.periodKey : null;
  if (!firstPeriod || !first) return null;
  const clock = S.clock(firstPeriod, first, days);
  const season = S.seasonAt(clock, now);
  return {
    clock,
    period: season.period,
    seasonNumber: season.number,
    start: season.start,
    end: season.end,
    m: Math.max(1, num(rb.m, 100)),
    cFallback: num(c.fallback, 4),
    cUntil: Math.max(0, Math.trunc(num(c.fallbackUntilRatings, 2000))),
    dailyCap: Math.max(1, Math.trunc(num(rb.dailyCountedCap, 100))),
    seasonCap: Math.max(1, Math.trunc(num(rb.seasonCountedCap, 2800))),
    dayMax: Math.max(1, Math.trunc(num(rb.maxReviewsPerGameDay, 60))),
    daySeconds: Math.max(0, num(rb.minGameDaySeconds, 200)),
    minToRank: Math.max(1, Math.trunc(num(rb.minRatingsToRank, 50))),
    topLimit: Math.min(100, Math.max(1, Math.trunc(num(rb.topLimit, 100)))),
    rewards: Array.isArray(rb.rewards) ? rb.rewards : [],
  };
}

/** 'YYYY-MM-DD' of [at] in Vietnam. */
function vnDate(at) {
  return new Date(at.getTime() + VN_MS).toISOString().slice(0, 10);
}

/** The season's C from its totals. */
function seasonC(cfg, totalV, totalSum) {
  return totalV >= cfg.cUntil && totalV > 0 ? totalSum / totalV : cfg.cFallback;
}

function score(cfg, v, sum, C) {
  return (sum + cfg.m * C) / (v + cfg.m);
}

/** One number for the board order: round(score, 3), then v. 0 = not ranked. */
function sortKey(cfg, v, sc) {
  if (v < cfg.minToRank) return 0;
  return Math.round(sc * 1000) * 10000 + Math.min(v, 9999);
}

/** Stars of one saved review (1..5), or null when it has none. */
function starsOf(r) {
  if (!r || typeof r !== 'object') return null;
  const s = r.stars;
  if (typeof s !== 'number' || !Number.isInteger(s) || s < 1 || s > 5) return null;
  if (typeof r.day !== 'number' || !Number.isInteger(r.day)) return null;
  return s;
}

/**
 * What the save adds. [state] is rating_state/{uid} (or null), [progress]
 * the save. Returns {state, add: [stars...], dropped: {short, busy, cap}}:
 * the new state to store (when `changed`) and the stars to count now.
 */
function plan(cfg, state, progress, now) {
  const day = progress && Number.isInteger(progress.day) ? progress.day : null;
  const out = { state: state ? { ...state } : null, add: [], dropped: { short: 0, busy: 0, cap: 0 }, changed: false };
  if (day == null || day < 1) return out;
  const t = now.getTime();
  const st = out.state;
  if (!st || !Number.isInteger(st.day)) {
    out.state = { day, dayAt: now, period: cfg.period, v: 0, sum: 0, capDate: vnDate(now), capCount: 0 };
    out.changed = true;
    return out;
  }
  if (st.period !== cfg.period) {
    Object.assign(st, { period: cfg.period, v: 0, sum: 0 });
    out.changed = true;
  }
  if (day <= st.day) {
    if (day < st.day) { // a reset save (new game): restart the clock
      Object.assign(st, { day, dayAt: now });
      out.changed = true;
    }
    return out;
  }
  const from = st.day;
  const at = st.dayAt instanceof Date ? st.dayAt.getTime()
    : st.dayAt && typeof st.dayAt.toDate === 'function' ? st.dayAt.toDate().getTime() : t;
  Object.assign(st, { day, dayAt: now });
  out.changed = true;
  const running = t >= cfg.start.getTime() && t < cfg.end.getTime();
  const byDay = new Map();
  for (const r of Array.isArray(progress.reviews) ? progress.reviews : []) {
    const s = starsOf(r);
    if (s == null || r.day < from || r.day >= day) continue;
    if (!byDay.has(r.day)) byDay.set(r.day, []);
    byDay.get(r.day).push(s);
  }
  if ((t - at) / 1000 < cfg.daySeconds * (day - from)) {
    for (const list of byDay.values()) out.dropped.short += list.length;
    return out;
  }
  if (!running) return out;
  const today = vnDate(now);
  if (st.capDate !== today) Object.assign(st, { capDate: today, capCount: 0 });
  for (const d of [...byDay.keys()].sort((a, b) => a - b)) {
    const list = byDay.get(d);
    if (list.length > cfg.dayMax) { out.dropped.busy += list.length; continue; }
    for (const s of list) {
      if (st.capCount >= cfg.dailyCap || st.v >= cfg.seasonCap) { out.dropped.cap++; continue; }
      st.capCount++;
      st.v++;
      st.sum += s;
      out.add.push(s);
    }
  }
  return out;
}

function shopName(progress, filter) {
  const raw = progress && typeof progress.shopName === 'string' ? progress.shopName.trim() : '';
  const name = [...raw].slice(0, 40).join('');
  if (!name || (filter && !filter.allowsShopName(name))) return 'Chủ tiệm';
  return name;
}

/** Counts the reviews of a new save (the users/{uid} write trigger). */
async function ingest({ db, eco, uid, progress, now, filter, logger }) {
  const cfg = ratingConfig(eco, now);
  if (!cfg || !progress) return { counted: 0 };
  return db.runTransaction(async (tx) => {
    const stateRef = db.doc(`rating_state/${uid}`);
    const metaRef = db.doc(`rating_board/${cfg.period}`);
    const entryRef = db.doc(`rating_board/${cfg.period}/entries/${uid}`);
    const [stSnap, metaSnap, entrySnap, avSnap] = await Promise.all([
      tx.get(stateRef), tx.get(metaRef), tx.get(entryRef), tx.get(db.doc(`player_avatars/${uid}`)),
    ]);
    const before = stSnap.exists ? stSnap.data() : null;
    const p = plan(cfg, before, progress, now);
    if (!p.state) return { counted: 0 };
    if (p.changed) tx.set(stateRef, p.state);
    const { short, busy, cap } = p.dropped;
    if ((short || busy || cap) && logger) {
      logger.info('rating reviews not counted', { uid, period: cfg.period, short, busy, cap });
    }
    if (!p.add.length) return { counted: 0 };
    const meta = metaSnap.exists ? metaSnap.data() : {};
    const totalV = num(meta.totalV, 0) + p.add.length;
    const totalSum = num(meta.totalSum, 0) + p.add.reduce((a, b) => a + b, 0);
    const C = num(meta.C, cfg.cFallback);
    tx.set(metaRef, { totalV, totalSum, C, updatedAt: now }, { merge: true });
    const { v, sum } = p.state;
    const sc = score(cfg, v, sum, C);
    const key = sortKey(cfg, v, sc);
    const old = entrySnap.exists ? entrySnap.data() : null;
    const av = avSnap.exists ? avSnap.data() : {};
    tx.set(entryRef, {
      uid,
      displayName: shopName(progress, filter),
      avatar: typeof av.path === 'string' && av.path.length <= 500 ? av.path : '',
      v,
      sum,
      R: sum / v,
      score: sc,
      sortKey: key,
      reachedAt: old && old.sortKey === key && old.reachedAt ? old.reachedAt : now,
      updatedAt: now,
    });
    return { counted: p.add.length };
  });
}

/**
 * Every refreshMinutes: C from the season totals; when it moved, every row
 * is rescored (reachedAt kept unless the order key changed).
 */
async function refresh({ db, eco, now, logger }) {
  const cfg = ratingConfig(eco, now);
  if (!cfg) return { rescored: 0 };
  const metaRef = db.doc(`rating_board/${cfg.period}`);
  const snap = await metaRef.get();
  const meta = snap.exists ? snap.data() : {};
  const C = seasonC(cfg, num(meta.totalV, 0), num(meta.totalSum, 0));
  const old = num(meta.C, cfg.cFallback);
  await metaRef.set({ C, updatedAt: now, startsAt: cfg.start, endsAt: cfg.end }, { merge: true });
  if (Math.abs(C - old) < 1e-9) return { rescored: 0, C };
  const rows = await db.collection(`rating_board/${cfg.period}/entries`).get();
  let n = 0;
  for (const d of rows.docs) {
    const e = d.data();
    const v = num(e.v, 0);
    if (v < 1) continue;
    const sc = score(cfg, v, num(e.sum, 0), C);
    const key = sortKey(cfg, v, sc);
    await d.ref.update({ score: sc, sortKey: key, ...(key !== e.sortKey ? { reachedAt: now } : {}) });
    n++;
  }
  if (logger) logger.info('rating board C moved', { period: cfg.period, C, old, rescored: n });
  return { rescored: n, C };
}

module.exports = { ratingConfig, vnDate, seasonC, score, sortKey, plan, shopName, ingest, refresh };
