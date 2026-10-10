'use strict';
// Automatic season payout of the Mị lực board. Pure logic: the Firestore
// handle, the clock, the dice and the Auth lookup are passed in, so the
// tests run it against a fake Firestore (payout.test.js) and index.js runs
// it against the real one. Nothing here is deployed by this repo's CI.
//
// One run (runPayout):
//   1. ensureSeasonMetas  creates charm_board/{period} (startsAt, endsAt) for
//                         the live season and the next one when missing.
//   2. kill switch        config/charmPayout.autoPayout === false: pay nobody.
//   3. every period whose endsAt + 5 min has passed and whose
//      charm_board/{period}.payout.status is not 'done' is paid (payPeriod).
//
// payPeriod(period):
//   * reads every board row and recomputes its Mị lực from users/{uid}.progress
//     (charm.js, same arithmetic as the app);
//   * a row under the minimum, with no readable save or no pet in the Mị lực
//     slot is dropped (deleted from the board, review line "skipped");
//   * the rest are ranked (higher charm first, tie: reached it first, then uid),
//     their board rows are overwritten with the recomputed values, and the top
//     100 get a reward;
//   * a row is HELD (no mail, review line "held" with its flags) when
//       mismatch     recomputed charm differs from the value on the board,
//       over_cap     the board value is above the 600 cap,
//       new_account  the account was created inside the season (Auth creation
//                    time, falling back to users/{uid}.joinedAt);
//   * every other ranked row gets ONE mail mails/bxh_{period}_{uid}, created
//     only if absent (a rerun never doubles a reward). The random item inside
//     the tier is picked now and stored in the mail.

const { charmFromProgress, rewardFor, MAX_CHARM } = require('./charm');

const GRACE_MS = 5 * 60 * 1000;
const MAIL_TITLE = 'Thưởng xếp hạng Mị lực';
const USER_CHUNK = 100;

/** Firestore Timestamp, Date, millis or ISO string -> Date (or null). */
function toDate(v) {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof v.toDate === 'function') return v.toDate();
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

function isAlreadyExists(e) {
  return !!e && (e.code === 6 || e.code === 'already-exists' || e.code === 'ALREADY_EXISTS');
}

/** `season-3` -> `season-4`; null when the key has no trailing number. */
function nextPeriodKey(key) {
  const m = /^(.*?)(\d+)$/.exec(String(key));
  return m ? `${m[1]}${Number(m[2]) + 1}` : null;
}

/** The letter that carries a reward (lib/logic/charm_rewards.dart charmRewardMail). */
function rewardMail({ period, rank, uid, items, now }) {
  return {
    title: MAIL_TITLE,
    body:
      `Bạn đứng hạng ${rank} ở bảng xếp hạng Mị lực mùa ${period}. ` +
      'Quà thưởng đã được duyệt, nhận ngay nhé!',
    target: uid,
    rewards: { items },
    createdAt: now,
  };
}

/**
 * What one reward line pays (lib/logic/charm_rewards.dart charmRewardBundle):
 * Pha lê, Giọt hoa, then one pet item of the line's tier picked at random.
 */
function rewardItems(line, eco, random) {
  const items = [];
  if (line.phaLe > 0) items.push({ kind: 'phaLe', amount: line.phaLe });
  if (line.giotHoa > 0) items.push({ kind: 'giotHoa', amount: line.giotHoa });
  const pool = (line.petItemRarity && eco.itemsByTier[line.petItemRarity]) || [];
  if (pool.length > 0) {
    const i = Math.min(pool.length - 1, Math.floor(random() * pool.length));
    items.push({ kind: 'petItem', id: pool[i], amount: 1 });
  }
  return items;
}

/** Creates [data] at [ref] unless it exists. True when this call created it. */
async function createIfAbsent(ref, data) {
  try {
    await ref.create(data);
    return true;
  } catch (e) {
    if (isAlreadyExists(e)) return false;
    throw e;
  }
}

/**
 * charm_board/{period} for the live season and the next one, when missing.
 * An existing doc (an admin may have edited endsAt) is never touched.
 */
async function ensureSeasonMetas({ db, eco, now }) {
  const created = [];
  if (!eco.seasonStart) return created;
  const cycle = eco.cycleDays * 24 * 3600 * 1000;
  const startsAt = eco.seasonStart;
  const endsAt = new Date(startsAt.getTime() + cycle);
  const plan = [[eco.periodKey, startsAt, endsAt]];
  const next = nextPeriodKey(eco.periodKey);
  if (next) plan.push([next, endsAt, new Date(endsAt.getTime() + cycle)]);
  for (const [period, s, e] of plan) {
    const did = await createIfAbsent(db.doc(`charm_board/${period}`), {
      startsAt: s, endsAt: e, createdBy: 'function', createdAt: now,
    });
    if (did) created.push(period);
  }
  return created;
}

async function autoPayoutOn(db) {
  const snap = await db.doc('config/charmPayout').get();
  return !(snap.exists && snap.data().autoPayout === false);
}

async function loadUsers(db, uids) {
  const out = new Map();
  for (let i = 0; i < uids.length; i += USER_CHUNK) {
    const refs = uids.slice(i, i + USER_CHUNK).map((u) => db.doc(`users/${u}`));
    for (const snap of await db.getAll(...refs)) {
      if (snap.exists) out.set(snap.id, snap.data());
    }
  }
  return out;
}

/** Pays one period. Returns the summary also stored in the meta doc. */
async function payPeriod({ db, eco, period, meta, now, random, authCreated, logger }) {
  const log = logger || { info() {}, warn() {} };
  const seasonStart = toDate(meta.startsAt) || eco.seasonStart;
  const entries = await db.collection(`charm_board/${period}/entries`).get();
  const rows = entries.docs.map((d) => ({ uid: d.id, ref: d.ref, entry: d.data() }));
  const uids = rows.map((r) => r.uid);
  const users = await loadUsers(db, uids);
  const created = authCreated ? await authCreated(uids) : new Map();
  // Lines written by an earlier pass of this same period: a row that was HELD
  // stays held (its board row now carries the recomputed score, so it would
  // look clean on a rerun), and one the admin RELEASED is never paid again.
  const prior = new Map();
  for (let i = 0; i < uids.length; i += USER_CHUNK) {
    const refs = uids.slice(i, i + USER_CHUNK).map((u) => db.doc(`charm_board/${period}/review/${u}`));
    for (const snap of await db.getAll(...refs)) if (snap.exists) prior.set(snap.id, snap.data());
  }

  const review = []; // review lines, ranked + skipped
  const ranked = [];
  for (const row of rows) {
    const { uid, entry } = row;
    const base = {
      uid,
      displayName: String(entry.displayName || ''),
      stored: Number(entry.charm) || 0,
    };
    const user = users.get(uid);
    if (!user || !user.progress) {
      review.push({ ...base, status: 'skipped', reason: 'no_save', recomputed: 0 });
      row.drop = true;
      continue;
    }
    const real = charmFromProgress(user.progress, eco);
    if (!real.petId) {
      review.push({ ...base, status: 'skipped', reason: 'no_pet', recomputed: 0 });
      row.drop = true;
      continue;
    }
    if (real.charm < eco.minCharm) {
      review.push({ ...base, status: 'skipped', reason: 'under_min', recomputed: real.charm });
      row.drop = true;
      continue;
    }
    const flags = [];
    if (real.charm !== base.stored) flags.push('mismatch');
    if (Number(entry.charm) > MAX_CHARM) flags.push('over_cap');
    const madeAt = toDate(created.get(uid)) || toDate(user.joinedAt);
    if (seasonStart && madeAt && madeAt.getTime() >= seasonStart.getTime()) {
      flags.push('new_account');
    }
    const before = prior.get(uid);
    if (before && before.status === 'held') {
      for (const f of before.flags || []) if (!flags.includes(f)) flags.push(f);
    }
    ranked.push({
      ...row, base, real, flags, released: !!(before && before.status === 'released'),
      reachedAt: (toDate(entry.reachedAt) || toDate(entry.updatedAt) || now).getTime(),
    });
  }

  ranked.sort((a, b) =>
    b.real.charm - a.real.charm ||
    a.reachedAt - b.reachedAt ||
    (a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0));

  // Dropped rows leave the board; the rest carry the recomputed values.
  for (const row of rows) if (row.drop) await row.ref.delete();
  for (const r of ranked) {
    if (r.real.charm !== r.base.stored || r.entry.petId !== r.real.petId) {
      const lowered = r.real.charm < r.base.stored;
      await r.ref.update({
        charm: r.real.charm, petId: r.real.petId, stage: r.real.stage, worn: r.real.worn,
        ...(lowered ? { reachedAt: now } : {}),
      });
    }
  }

  let sent = 0;
  let already = 0;
  let held = 0;
  let failed = 0;
  const top = ranked.slice(0, eco.topLimit);
  for (let i = 0; i < top.length; i++) {
    const r = top[i];
    const rank = i + 1;
    const line = rewardFor(rank, eco);
    const info = {
      uid: r.uid, displayName: r.base.displayName, rank,
      stored: r.base.stored, recomputed: r.real.charm,
      petId: r.real.petId, stage: r.real.stage, worn: r.real.worn,
    };
    if (!line) continue;
    if (r.released) continue; // the admin already decided
    if (r.flags.length > 0) {
      held++;
      review.push({ ...info, status: 'held', flags: r.flags });
      continue;
    }
    const mailId = `bxh_${period}_${r.uid}`;
    try {
      const items = rewardItems(line, eco, random);
      const made = await createIfAbsent(
        db.doc(`mails/${mailId}`),
        rewardMail({ period, rank, uid: r.uid, items, now }),
      );
      if (made) sent++; else already++;
      review.push({ ...info, status: 'sent', mailId });
    } catch (e) {
      failed++;
      log.warn('charm payout: mail failed', { period, uid: r.uid, message: String(e && e.message) });
      review.push({ ...info, status: 'failed', mailId });
    }
  }
  // Ranked but past the reward table's end (rank 101+): no reward, no line.
  const skipped = review.filter((l) => l.status === 'skipped').length;

  for (const line of review) {
    const ref = db.doc(`charm_board/${period}/review/${line.uid}`);
    const old = await ref.get();
    // An admin's release of a held row is never overwritten by a rerun.
    if (old.exists && old.data().status === 'released') continue;
    await ref.set({ ...line, createdAt: now });
  }

  const summary = {
    status: failed > 0 ? 'partial' : 'done',
    at: now, rows: rows.length, ranked: ranked.length,
    sent: sent + already, created: sent, held, skipped, failed,
  };
  await db.doc(`charm_board/${period}`).set({ payout: summary }, { merge: true });
  log.info('charm payout', { period, ...summary });
  return summary;
}

/** One scheduler tick. */
async function runPayout({ db, eco, now, random, authCreated, logger }) {
  const log = logger || { info() {}, warn() {} };
  const result = { created: [], paid: {}, skipped: null };
  result.created = await ensureSeasonMetas({ db, eco, now });
  if (!(await autoPayoutOn(db))) {
    log.warn('charm payout: autoPayout is off, nothing paid');
    result.skipped = 'autoPayout-off';
    return result;
  }
  const cutoff = new Date(now.getTime() - GRACE_MS);
  const due = await db.collection('charm_board').where('endsAt', '<=', cutoff).get();
  for (const d of due.docs) {
    const meta = d.data();
    if (meta.payout && meta.payout.status === 'done') continue;
    result.paid[d.id] = await payPeriod({
      db, eco, period: d.id, meta, now, random, authCreated, logger,
    });
  }
  return result;
}

module.exports = {
  GRACE_MS, MAIL_TITLE, nextPeriodKey, rewardItems, rewardMail, ensureSeasonMetas,
  autoPayoutOn, payPeriod, runPayout, toDate,
};