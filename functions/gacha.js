'use strict';
// Vòng quay tuần (gacha): which Sơn Hải pot is on this week, card prices and
// the draw. Pure helpers, no Firestore; wallet.js runs them in transactions.
// Every number comes from economy.json `gacha` (never from the client).

const DAY_MS = 86400000;
const WEEK_MS = 7 * DAY_MS;
const VN_OFFSET_MS = 7 * 3600000; // Asia/Ho_Chi_Minh, no daylight saving.

/** Real calendar day number in Việt Nam (resets 0h VN). Same as rules vnDay(). */
function vnDay(now) {
  return Math.floor((now.getTime() + VN_OFFSET_MS) / DAY_MS);
}

/** 0h (VN) of the date "YYYY-MM-DD", as a Date. Null when not a date. */
function vnMidnight(ymd) {
  if (typeof ymd !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(ymd)) return null;
  const t = Date.parse(`${ymd}T00:00:00+07:00`);
  return Number.isFinite(t) ? new Date(t) : null;
}

function cfgOf(eco) {
  return (eco && eco.gacha) || {};
}

function rotation(eco) {
  const r = cfgOf(eco).weeklyRotation;
  return Array.isArray(r) ? r.filter((id) => typeof id === 'string' && id) : [];
}

/**
 * The week at [now]: index (0 = first week of `rotationStart`), the pot on
 * show, when it started and when the next pot comes (always 0h Monday VN when
 * rotationStart is a Monday). potId null: not started, over (rotationRepeat
 * false) or no config.
 */
function weekAt(eco, now) {
  const cfg = cfgOf(eco);
  const rot = rotation(eco);
  const start = vnMidnight(cfg.rotationStart);
  const none = { index: -1, potId: null, weekStart: null, weekEnd: start, nextPotId: rot[0] || null };
  if (!start || rot.length === 0) return { ...none, weekEnd: null, nextPotId: null };
  const t = now.getTime();
  if (t < start.getTime()) return none;
  const index = Math.floor((t - start.getTime()) / WEEK_MS);
  const repeat = cfg.rotationRepeat !== false;
  const at = (i) => (repeat ? rot[i % rot.length] : rot[i] || null);
  const weekStart = new Date(start.getTime() + index * WEEK_MS);
  return {
    index,
    potId: at(index),
    weekStart,
    weekEnd: new Date(weekStart.getTime() + WEEK_MS),
    nextPotId: at(index + 1),
  };
}

/** Whole days left until the pot changes (ceil; 0 when none). */
function daysLeft(week, now) {
  if (!week.weekEnd) return 0;
  return Math.max(0, Math.ceil((week.weekEnd.getTime() - now.getTime()) / DAY_MS));
}

function priceCfg(eco) {
  return cfgOf(eco).ticketPrice || {};
}

/** Pha lê per card, or 0 when not on sale for Pha lê. */
function phaLeTicketPrice(eco) {
  const p = Number(priceCfg(eco).phaLe);
  return Number.isInteger(p) && p > 0 ? p : 0;
}

/** Xu per card on the shop's game day [day]; 0 when no tier matches. */
function coinTicketPrice(eco, day) {
  const tiers = Array.isArray(priceCfg(eco).coinsByDay) ? priceCfg(eco).coinsByDay : [];
  for (const t of tiers) {
    const from = Number(t.fromDay) || 1;
    const to = t.toDay == null ? Infinity : Number(t.toDay);
    if (day >= from && day <= to && Number(t.coins) > 0) return Number(t.coins);
  }
  return 0;
}

/** Most cards bought with xu per real VN day. 0 = unlimited (0, null, missing). */
function coinTicketDailyMax(eco) {
  const n = Number(priceCfg(eco).maxCoinTicketsPerDay);
  return Number.isInteger(n) && n > 0 ? n : 0;
}

/** Spins of one pot's card that guarantee that pot. 0 = no pity. */
function pityAt(eco) {
  const n = Number(cfgOf(eco).pityAt);
  return Number.isInteger(n) && n > 0 ? n : 0;
}

/**
 * Counters reset at the start of each week unless `pityCarryOver` is true
 * (Hà Phương: pityCarryOver false + pityResetAt, An 17/10 14:01). Missing =
 * reset.
 */
function pityCarries(eco) {
  return cfgOf(eco).pityCarryOver === true;
}

/**
 * The pity counter of [potId] this week. `resetFrom` is the old count that
 * the weekly reset turned into 0 (0 when nothing was reset), so the app can
 * tell the player once; `lastWeek` is the week index it came from.
 */
function pityOf(eco, wallet, potId, weekIndex) {
  const raw = (wallet.pity && wallet.pity[potId]) || {};
  const n = Math.max(0, Math.floor(Number(raw.n) || 0));
  const week = Number.isInteger(raw.week) ? raw.week : null;
  if (pityCarries(eco) || week === weekIndex || n === 0) {
    return { n, resetFrom: 0, lastWeek: null };
  }
  return { n: 0, resetFrom: n, lastWeek: week };
}

/** Gift cards: by the week the mail arrived (default) or the claim time. */
function giftTicketPotId(eco, mail, now) {
  if (mail && typeof mail.ticketPot === 'string' && mail.ticketPot) return mail.ticketPot;
  const by = cfgOf(eco).giftTicketPotBy || 'mailArrivalWeek';
  const created = mail && mail.createdAt;
  const at = by === 'mailArrivalWeek' && created ? toDate(created) : now;
  return weekAt(eco, at || now).potId;
}

function toDate(v) {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof v.toDate === 'function') return v.toDate();
  if (typeof v === 'number') return new Date(v);
  return null;
}

/** The odds table (weights out of the total, Hà Phương: 10 000). */
function table(eco) {
  const t = cfgOf(eco).table_permyriad;
  return Array.isArray(t) ? t.filter((r) => r && Number(r.w) > 0) : [];
}

function pick(list, rand) {
  return list[Math.min(list.length - 1, Math.floor(rand() * list.length))];
}

/** Pot ids of a set (`chomSao`...) in economy.json pots. */
function potsOfSet(eco, set) {
  return (eco.pots || []).filter((p) => p && p.set === set).map((p) => p.id);
}

/**
 * One draw for the week's pot [potId]. [forceFeatured]: pity hit. [owns]:
 * the player already has that pot (or won it earlier in this batch), so the
 * featured row pays its `ifOwned` xu instead. Returns the reward items in
 * the mailbox's RewardBundle shape plus `featured`/`dup` flags.
 */
function draw(eco, { potId, forceFeatured, owns, rand }) {
  const rows = table(eco);
  let row;
  if (forceFeatured) {
    row = rows.find((r) => r.item === 'potOfWeek');
  } else {
    const total = rows.reduce((s, r) => s + Number(r.w), 0);
    let roll = rand() * total;
    for (const r of rows) {
      roll -= Number(r.w);
      if (roll < 0) { row = r; break; }
    }
    row = row || rows[rows.length - 1];
  }
  if (!row) throw new Error('gacha-table');
  if (row.item === 'potOfWeek') {
    const dupXu = Number(row.ifOwned && row.ifOwned.coins) || 0;
    if (owns) {
      return { featured: true, dup: true, items: dupXu > 0 ? [{ kind: 'coins', amount: dupXu }] : [] };
    }
    return { featured: true, dup: false, items: [{ kind: 'pot', id: potId, amount: 1 }] };
  }
  if (row.item === 'petItemRare' || row.item === 'petItemCommon') {
    const ids = Array.isArray(row.split) ? row.split : [];
    return { featured: false, dup: false, items: [{ kind: 'petItem', id: pick(ids, rand), amount: 1 }] };
  }
  if (row.item === 'chomSaoPot') {
    const ids = potsOfSet(eco, 'chomSao');
    return { featured: false, dup: false, items: [{ kind: 'pot', id: pick(ids, rand), amount: 1 }] };
  }
  if (row.coins) return { featured: false, dup: false, items: [{ kind: 'coins', amount: Number(row.coins) }] };
  if (row.giotHoa) return { featured: false, dup: false, items: [{ kind: 'giotHoa', amount: Number(row.giotHoa) }] };
  if (row.banhMat) {
    return { featured: false, dup: false, items: [{ kind: 'treat', id: 'banh_mat', amount: Number(row.banhMat) }] };
  }
  throw new Error('gacha-row');
}

module.exports = {
  DAY_MS, WEEK_MS, vnDay, vnMidnight, weekAt, daysLeft, phaLeTicketPrice, coinTicketPrice,
  coinTicketDailyMax, pityAt, pityCarries, pityOf, giftTicketPotId, toDate, table, draw, potsOfSet,
};
