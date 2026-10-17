'use strict';
// Customers-served milestone titles (An 17/10 19:47; economy.json
// `milestoneTitles`, Hà Phương 19:48/19:52; names by Nhất). Permanent: anyone
// who reaches a tier keeps it for good, on top of the two champion titles.
//
// Counted on the SERVER from the cloud save (users/{uid}, pushed each game
// morning): progress.lifetimeBouquetsSold goes up once per customer who paid
// for a bouquet, online orders included; customers who left are not in it.
// Each save with a later game day adds the new customers since the last save
// seen, after the serverCheck rules:
//   - skipDaysUnderSeconds (200): a jump of k game days needs k x 200 s of
//     server time since the save that started the last day, else nothing
//     from that jump counts (note 'short': title.customers.not_counted);
//   - maxServedPerGameDay (60): at most 60 x k for a jump of k days. The save
//     has no per-day sales, so this is checked on the whole jump, not day by
//     day;
//   - maxServedPerRealDay (3.000): at most 3.000 counted per Vietnam day
//     (note 'cap': title.customers.daily_cap).
// What is not counted is lost (the baseline always moves to the save).
// `retroactive`: the first save the server sees starts the count at
// min(lifetimeBouquetsSold, 60 x game days played); days played = day - 1
// (the save is the morning of `day`).
//
//   milestone_state/{uid}   server only (the owner reads it for the notes):
//                           {day, dayAt, sold, counted, seed, capDate,
//                            capCount, note: ''|'short'|'cap', noteDate}
//   public_profiles/{uid}
//     customers             counted customers (progress "Bán cho {current}/
//                           {target} khách")
//     titleStats.{tierId}   {permanent: true, since, threshold, retro} once
//                           reached (retro: from the starting count, for
//                           title.customers.retro_toast). Never removed.

const VN_MS = 7 * 3600 * 1000;

const int = (v) => (Number.isFinite(Number(v)) ? Math.max(0, Math.floor(Number(v))) : 0);

function vnDate(d) {
  return new Date(d.getTime() + VN_MS).toISOString().slice(0, 10);
}

function toMs(v, fallback) {
  if (v instanceof Date) return v.getTime();
  if (v && typeof v.toDate === 'function') return v.toDate().getTime();
  return fallback;
}

/**
 * economy.json milestoneTitles: {tiers: [{id, threshold, name}] by threshold,
 * daySeconds, perGameDay, perRealDay}; null without the block. A block with a
 * bad value throws (a deploy must not count with made-up limits).
 */
function milestoneConfig(eco) {
  const m = eco && eco.milestoneTitles;
  if (!m || typeof m !== 'object') return null;
  const sc = m.serverCheck || {};
  const need = (v, name) => {
    const n = Number(v);
    if (!Number.isInteger(n) || n < 1) throw new Error(`economy.json milestoneTitles.${name}`);
    return n;
  };
  const tiers = (Array.isArray(m.tiers) ? m.tiers : []).map((t, i) => {
    if (!t || typeof t.id !== 'string' || !/^[a-z0-9_]+$/.test(t.id) || typeof t.name !== 'string') {
      throw new Error(`economy.json milestoneTitles.tiers[${i}]`);
    }
    return { id: t.id, name: t.name, threshold: need(t.threshold, `tiers[${i}].threshold`) };
  }).sort((a, b) => a.threshold - b.threshold);
  return {
    tiers,
    daySeconds: need(sc.skipDaysUnderSeconds, 'serverCheck.skipDaysUnderSeconds'),
    perGameDay: need(sc.maxServedPerGameDay, 'serverCheck.maxServedPerGameDay'),
    perRealDay: need(sc.maxServedPerRealDay, 'serverCheck.maxServedPerRealDay'),
  };
}

/**
 * The new state for a save. [st] is milestone_state (null the first time).
 * Returns {state, changed, add, dropped: {short, busy, cap}, seeded}.
 */
function plan(cfg, st, progress, now) {
  const out = { state: null, changed: false, add: 0, dropped: { short: 0, busy: 0, cap: 0 }, seeded: false };
  const day = int(progress && progress.day);
  if (day < 1) return out;
  const sold = int(progress.lifetimeBouquetsSold);
  const t = now.getTime();
  const today = vnDate(now);
  if (!st) {
    const seed = Math.min(sold, cfg.perGameDay * (day - 1));
    out.state = { day, dayAt: now, sold, counted: seed, seed, capDate: today, capCount: 0, note: '', noteDate: '' };
    out.changed = true;
    out.seeded = true;
    out.add = seed;
    return out;
  }
  const s = { ...st };
  out.state = s;
  if (day < s.day) { // a new game: restart the clock and the baseline
    Object.assign(s, { day, dayAt: now, sold });
    out.changed = true;
    return out;
  }
  if (day === s.day) {
    if (sold < int(s.sold)) { s.sold = sold; out.changed = true; }
    return out;
  }
  const k = day - s.day;
  const delta = Math.max(0, sold - int(s.sold));
  const at = toMs(s.dayAt, t);
  Object.assign(s, { day, dayAt: now, sold });
  out.changed = true;
  if (!delta) return out;
  if ((t - at) / 1000 < cfg.daySeconds * k) {
    out.dropped.short = delta;
    Object.assign(s, { note: 'short', noteDate: today });
    return out;
  }
  const allowed = Math.min(delta, cfg.perGameDay * k);
  out.dropped.busy = delta - allowed;
  if (s.capDate !== today) Object.assign(s, { capDate: today, capCount: 0 });
  const add = Math.min(allowed, Math.max(0, cfg.perRealDay - int(s.capCount)));
  out.dropped.cap = allowed - add;
  s.capCount = int(s.capCount) + add;
  s.counted = int(s.counted) + add;
  out.add = add;
  if (out.dropped.cap) Object.assign(s, { note: 'cap', noteDate: today });
  return out;
}

/** Tiers reached at [counted] that [stats] does not hold yet. */
function newTiers(cfg, counted, stats) {
  return cfg.tiers.filter((t) => counted >= t.threshold
    && !(stats && stats[t.id] && stats[t.id].permanent === true));
}

/**
 * Counts a new save (the users/{uid} write trigger). One transaction:
 * milestone_state, public_profiles.customers and any tier reached.
 * Returns {counted, add, awarded: [tierId]}.
 */
async function ingest({ db, eco, uid, progress, now, logger }) {
  const cfg = milestoneConfig(eco);
  if (!cfg || !progress || typeof progress !== 'object') return { counted: 0, add: 0, awarded: [] };
  return db.runTransaction(async (tx) => {
    const stRef = db.doc(`milestone_state/${uid}`);
    const profRef = db.doc(`public_profiles/${uid}`);
    const [stSnap, profSnap] = await Promise.all([tx.get(stRef), tx.get(profRef)]);
    const p = plan(cfg, stSnap.exists ? stSnap.data() : null, progress, now);
    if (!p.state) return { counted: 0, add: 0, awarded: [] };
    if (p.changed) tx.set(stRef, p.state);
    const { short, busy, cap } = p.dropped;
    if ((short || busy || cap) && logger) {
      logger.info('milestone customers not counted', { uid, short, busy, cap });
    }
    const counted = int(p.state.counted);
    const prof = profSnap.exists ? profSnap.data() : {};
    const stats = prof.titleStats && typeof prof.titleStats === 'object' ? prof.titleStats : {};
    const reached = newTiers(cfg, counted, stats);
    const patch = {};
    if (int(prof.customers) !== counted || !profSnap.exists) patch.customers = counted;
    if (reached.length) {
      const next = { ...stats };
      for (const t of reached) {
        next[t.id] = { permanent: true, since: now, threshold: t.threshold, retro: p.seeded };
      }
      patch.titleStats = next;
    }
    if (Object.keys(patch).length) tx.set(profRef, patch, { merge: true });
    return { counted, add: p.add, awarded: reached.map((t) => t.id) };
  });
}

module.exports = { milestoneConfig, plan, newTiers, ingest, vnDate };
