'use strict';
// Automatic season payout of the Mị lực board. Pure logic: the Firestore
// handle, the clock and the Auth lookup are passed in, so the
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
//       mismatch     the board value is HIGHER than the recomputed charm,
//       new_account  the account was created inside the season (Auth creation
//                    time, falling back to users/{uid}.joinedAt);
//   * every other ranked row gets ONE mail mails/bxh_{period}_{uid}, created
//     only if absent (a rerun never doubles a reward). The pet item is picked
//     by pickSeasonItem: deterministic per period + uid (a rerun or the
//     admin's release picks the same), among the tier's items the save does
//     not own (leaderboard.petItemPick "randomNotOwned"); held rows keep the
//     picked items in their review line for the admin's "Duyệt thưởng".

const { charmFromProgress, rewardFor, serverOwned } = require('./charm');
const AC = require('./anti_cheat');
const S = require('./season');
const T = require('./titles');

const GRACE_MS = 5 * 60 * 1000;
// {board_name} of the reward letters (Nhất mục 11: season.board.charm /
// season.board.review; lib/data/season_clock.dart SeasonBoardName).
const BOARD_NAMES = { charm: 'Mị lực', review: 'Đánh giá' };
// Rarity names as the app shows them (lib/ui/charm_board_screen.dart, bxh.rar.*).
const TIER_NAMES = { thuong: 'Thường', hiem: 'Hiếm', suThi: 'Sử thi', huyenThoai: 'Huyền thoại' };
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

/** 1000000 -> "1.000.000" (Vietnamese grouping, like the app's prices). */
function groupDigits(n) {
  return String(Math.trunc(n)).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

/** ["a"] -> "a"; ["a", "b"] -> "a và b"; ["a", "b", "c"] -> "a, b và c". */
function listVi(parts) {
  if (parts.length <= 1) return parts.join('');
  return `${parts.slice(0, -1).join(', ')} và ${parts[parts.length - 1]}`;
}

/** "200 Pha lê" / "1.000.000 xu" for a phaLe / coins item. */
function amountText(item) {
  return item.kind === 'phaLe' ? `${groupDigits(item.amount)} Pha lê` : `${groupDigits(item.amount)} xu`;
}

/**
 * Title and body of a season reward letter, Nhất's keys verbatim
 * (season.reward.mail_title, mail_body, mail_body_fallback). A rank without
 * Pha lê or without giọt hoa drops that whole phrase. [items] is what
 * rewardItems gave for [line]: the line's Pha lê and giọt hoa, then the pick
 * (a pet item, or its price when the player owns the whole rarity).
 * The #1 also lists its title (leaderboard.championTitle, "Mị Lực Nhất
 * Trời") as the last gift, worded like the rating letter
 * (season.reward.review.title_line, lower-case inside the list).
 * Same text in lib/logic/charm_rewards.dart seasonMailText.
 */
function seasonMailText({ rank, line, items, eco }) {
  const phaLe = line.phaLe > 0 ? `${groupDigits(line.phaLe)} Pha lê` : null;
  const giot = line.giotHoa > 0 ? `${groupDigits(line.giotHoa)} giọt hoa` : null;
  const own = [phaLe, giot].filter(Boolean);
  const tc = eco.championTitle;
  const titleGift = tc && rank === tc.rank ? `danh hiệu "${tc.name}"` : null;
  const pick = items.slice(own.length)[0] || null;
  const head = `Chúc mừng bạn đạt hạng ${rank} bảng ${BOARD_NAMES.charm} mùa này!`;
  const title = `Thưởng mùa ${BOARD_NAMES.charm}: hạng ${rank}`;
  if (pick && pick.kind !== 'petItem') {
    const rarity = TIER_NAMES[line.petItemRarity] || line.petItemRarity || '';
    const more = [...own, ...(titleGift ? [titleGift] : [])];
    const extra = more.length ? `, kèm ${listVi(more)}` : '';
    return { title, body: `${head} Bạn đã có đủ đồ pet ${rarity}, nên nhận ${amountText(pick)} thay thế${extra}.` };
  }
  const name = pick ? ((eco.items.get(pick.id) || {}).name || pick.id) : null;
  const gifts = [...own, ...(name ? [name] : []), ...(titleGift ? [titleGift] : [])];
  return { title, body: gifts.length ? `${head} Quà của bạn: ${listVi(gifts)}.` : head };
}

/** The letter that carries a reward (lib/logic/charm_rewards.dart charmRewardMail). */
function rewardMail({ period, rank, uid, items, line, eco, now }) {
  const text = seasonMailText({ rank, line, items, eco });
  return {
    title: text.title,
    body: text.body,
    target: uid,
    rewards: { items },
    // Pha lê in it: claimed through walletClaimMail (wallet.js) into wallets/{uid}.
    ...(items.some((i) => i && i.kind === 'phaLe') ? { walletClaim: true } : {}),
    createdAt: now,
  };
}

/**
 * FNV-1a (32 bit) of `${period}:${uid}`: the season's dice for one player.
 * Same function in lib/logic/charm_rewards.dart (seasonPickHash), checked by
 * the shared fixture test/fixtures/charm_rewards_fixture.json.
 */
function seasonPickHash(period, uid) {
  const s = `${period}:${uid}`;
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

/** Item ids a save owns: progress.petItems (count > 0) and every worn item. */
function ownedPetItems(progress) {
  const out = new Set();
  const p = progress || {};
  for (const [id, n] of Object.entries(p.petItems || {})) if (Number(n) > 0) out.add(id);
  for (const pet of Array.isArray(p.pets) ? p.pets : []) {
    for (const id of Object.values((pet && pet.worn) || {})) if (typeof id === 'string') out.add(id);
  }
  return out;
}

/**
 * The one pet item of a reward line's [tier] (leaderboard.petItemPick):
 *   randomNotOwned  one of the tier's items the player does not own, picked
 *                   by seasonPickHash(period, uid) % count; when they own
 *                   them all, the shop price of the tier item at
 *                   hash % tierSize, in that item's currency (Pha lê or xu);
 *   anything else   any item of the tier, same dice.
 * Null when the tier has no items.
 */
function pickSeasonItem(eco, tier, { period, uid, owned }) {
  const pool = (tier && eco.itemsByTier[tier]) || [];
  if (pool.length === 0) return null;
  const h = seasonPickHash(period, uid);
  if (eco.petItemPick !== 'randomNotOwned') return { kind: 'petItem', id: pool[h % pool.length], amount: 1 };
  const have = owned || new Set();
  const left = pool.filter((id) => !have.has(id));
  if (left.length > 0) return { kind: 'petItem', id: left[h % left.length], amount: 1 };
  const item = eco.items.get(pool[h % pool.length]) || {};
  if (!(item.price > 0)) return null;
  return item.currency === 'phaLe'
    ? { kind: 'phaLe', amount: item.price }
    : { kind: 'coins', amount: item.price };
}

/**
 * What one reward line pays (lib/logic/charm_rewards.dart charmRewardBundle):
 * Pha lê, Giọt hoa, then exactly one pet item of the line's tier (or its
 * price when every item of the tier is owned, see pickSeasonItem).
 */
function rewardItems(line, eco, who) {
  const items = [];
  if (line.phaLe > 0) items.push({ kind: 'phaLe', amount: line.phaLe });
  if (line.giotHoa > 0) items.push({ kind: 'giotHoa', amount: line.giotHoa });
  const pick = pickSeasonItem(eco, line.petItemRarity, who);
  if (pick) items.push(pick);
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
 * charm_board/{period} for the live season and the next one on the shared
 * clock, when missing (so every Monday 00:00 the next board has its meta).
 * An existing doc (an admin may have edited endsAt) is never touched.
 */
async function ensureSeasonMetas({ db, eco, now }) {
  const created = [];
  if (!eco.clock) return created;
  // The live season on the shared clock (season.js) and the next one.
  const live = S.seasonAt(eco.clock, now);
  const next = S.season(eco.clock, live.number + 1);
  const plan = [[live.period, live.start, live.end], [next.period, next.start, next.end]];
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
async function payPeriod({ db, eco, period, meta, now, authCreated, logger }) {
  const log = logger || { info() {}, warn() {} };
  const onClock = eco.clock ? S.seasonOf(eco.clock, period) : null;
  const seasonStart = toDate(meta.startsAt) || (onClock && onClock.start) || eco.seasonStart;
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

  const flagged = await AC.flaggedOf(db, uids);
  const review = []; // review lines, ranked + skipped
  const ranked = [];
  for (const row of rows) {
    const { uid, entry } = row;
    const base = {
      uid,
      displayName: String(entry.displayName || ''),
      stored: Number(entry.charm) || 0,
    };
    if (flagged.has(uid)) {
      // anti_cheat.js cheat_flags: off the board, no reward.
      review.push({ ...base, status: 'skipped', reason: 'flagged', recomputed: 0 });
      row.drop = true;
      continue;
    }
    const user = users.get(uid);
    if (!user || !user.progress) {
      review.push({ ...base, status: 'skipped', reason: 'no_save', recomputed: 0 });
      row.drop = true;
      continue;
    }
    // Recomputed from the save, counting only what the server sold or gave.
    const real = charmFromProgress(user.progress, eco, await serverOwned(db, uid, { eco, progress: user.progress, now }));
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
    // Only a board value ABOVE what the save backs is suspicious. A board value
    // at or below it is just a stale row (the cloud save is ahead): pay the
    // recomputed value and overwrite the row.
    if (base.stored > real.charm) flags.push('mismatch');
    const madeAt = toDate(created.get(uid)) || toDate(user.joinedAt);
    if (seasonStart && madeAt && madeAt.getTime() >= seasonStart.getTime()) {
      flags.push('new_account');
    }
    const before = prior.get(uid);
    if (before && before.status === 'held') {
      for (const f of before.flags || []) if (!flags.includes(f)) flags.push(f);
    }
    ranked.push({
      ...row, base, real, flags, owned: ownedPetItems(user.progress), released: !!(before && before.status === 'released'),
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
    const items = rewardItems(line, eco, { period, uid: r.uid, owned: r.owned });
    if (r.flags.length > 0) {
      held++;
      // The admin's "Duyệt thưởng" sends exactly these (charm_payout.dart).
      review.push({ ...info, status: 'held', flags: r.flags, items });
      continue;
    }
    const mailId = `bxh_${period}_${r.uid}`;
    try {
      const made = await createIfAbsent(
        db.doc(`mails/${mailId}`),
        rewardMail({ period, rank, uid: r.uid, items, line, eco, now }),
      );
      if (made) sent++; else already++;
      review.push({ ...info, status: 'sent', mailId });
      // The #1 takes "Mị Lực Nhất Trời" (leaderboard.championTitle) from its
      // previous holder; a held #1 takes it when the admin releases it.
      const tc = eco.championTitle;
      if (tc && rank === tc.rank) {
        await T.transferTitle(db, tc, {
          uid: r.uid, period, seasonStart, now,
          seasonEnd: toDate(meta.endsAt) || (onClock && onClock.end) || null,
        });
      }
    } catch (e) {
      failed++;
      log.warn('charm payout: mail failed', { period, uid: r.uid, message: String(e && e.message) });
      review.push({ ...info, status: 'failed', mailId });
    }
  }
  // Best rank ever reached on the Mị lực board (titles.js; held rows too).
  // The Mị lực board gives no title for now.
  await T.recordBestRanks(db, 'charm', period, top.map((r, i) => ({ uid: r.uid, rank: i + 1 })), now);
  // Ranked but past the reward table's end (rank 101+): no reward, no line.
  const skipped = review.filter((l) => l.status === 'skipped').length;

  for (const line of review) {
    const ref = db.doc(`charm_board/${period}/review/${line.uid}`);
    const old = await ref.get();
    // An admin's release of a held row is never overwritten by a rerun.
    if (old.exists && old.data().status === 'released') continue;
    await ref.set({ ...line, createdAt: now });
  }

  // The app shows "Đang chốt bảng" until endsAt + lockMinutesAfterClose;
  // mails written after that arrive when the board already shows the next
  // season: logged and marked so the admin sees it.
  const lock = S.lockInfo(toDate(meta.endsAt) || (onClock && onClock.end), eco.lockMinutes, now);
  if (lock.late) log.warn('charm payout after the closing lock', { period, lockedUntil: lock.lockedUntil });
  const summary = {
    status: failed > 0 ? 'partial' : 'done',
    at: now, rows: rows.length, ranked: ranked.length,
    sent: sent + already, created: sent, held, skipped, failed,
    ...(lock.lockedUntil ? { lockedUntil: lock.lockedUntil, lateAfterLock: lock.late } : {}),
  };
  await db.doc(`charm_board/${period}`).set({ payout: summary }, { merge: true });
  log.info('charm payout', { period, ...summary });
  return summary;
}

/** One scheduler tick. */
async function runPayout({ db, eco, now, authCreated, logger }) {
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
      db, eco, period: d.id, meta, now, authCreated, logger,
    });
  }
  return result;
}

module.exports = {
  GRACE_MS, TIER_NAMES, nextPeriodKey, rewardItems, rewardMail, seasonMailText, listVi, groupDigits, ensureSeasonMetas,
  seasonPickHash, ownedPetItems, pickSeasonItem,
  autoPayoutOn, payPeriod, runPayout, toDate, createIfAbsent, loadUsers, BOARD_NAMES,
};
