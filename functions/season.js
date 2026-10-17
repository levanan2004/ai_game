'use strict';
// The one season clock of both boards (lib/data/season_clock.dart, same
// arithmetic): seasons of cycleDays back to back, Monday 00:00 to Sunday
// 23:59 Vietnam time. Each board's economy.json block keeps its FIRST season
// (periodKey "season-1" / "rating-2" and seasonStart); later seasons chain
// on their own: the key's number goes up by one every cycleDays.

const VN_MS = 7 * 3600 * 1000;
const DAY_MS = 86400000;

/** 'YYYY-MM-DD' (a day in Vietnam) -> its 00:00 VN as a Date, else null. */
function vnDay(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(s || ''));
  return m ? new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]) - VN_MS) : null;
}

/** "season-1" -> ["season-", 1]; null without a trailing number. */
function splitKey(key) {
  const m = /^(.*?)(\d+)$/.exec(String(key || ''));
  return m ? [m[1], Number(m[2])] : null;
}

/** A clock from the first season: {firstPeriod, firstStart: Date, cycleDays}. */
function clock(firstPeriod, firstStart, cycleDays) {
  if (!firstPeriod || !(firstStart instanceof Date)) return null;
  const days = Number(cycleDays) >= 1 ? Math.trunc(Number(cycleDays)) : 28;
  return { firstPeriod, firstStart, cycleDays: days };
}

/** Season [n] of [c] (never before the first): {number, period, start, end}. */
function season(c, n) {
  const parts = splitKey(c.firstPeriod);
  const first = parts ? parts[1] : 1;
  const k = Math.max(first, Math.trunc(n));
  const cycle = c.cycleDays * DAY_MS;
  const start = new Date(c.firstStart.getTime() + (k - first) * cycle);
  return {
    number: k,
    period: parts ? `${parts[0]}${k}` : c.firstPeriod,
    start,
    end: new Date(start.getTime() + cycle),
  };
}

/** The season running at [now] (the first one before it starts). */
function seasonAt(c, now) {
  const parts = splitKey(c.firstPeriod);
  const first = parts ? parts[1] : 1;
  if (!parts || now.getTime() < c.firstStart.getTime()) return season(c, first);
  const passed = Math.floor((now.getTime() - c.firstStart.getTime()) / (c.cycleDays * DAY_MS));
  return season(c, first + passed);
}

/** The season keyed [period] on [c], or null when the key is not on it. */
function seasonOf(c, period) {
  const first = splitKey(c.firstPeriod);
  const got = splitKey(period);
  if (!first || !got || got[0] !== first[0] || got[1] < first[1]) return null;
  return season(c, got[1]);
}

/**
 * economy.json `ratingBoard.season.lockMinutesAfterClose`: the minutes after a
 * season closes during which BOTH boards in the app stay on it, frozen
 * ("Đang chốt bảng"), while the payout runs. Missing or invalid: 0.
 */
function lockMinutes(eco) {
  const rb = eco && eco.ratingBoard;
  const s = rb && typeof rb === 'object' ? rb.season : null;
  const v = s && typeof s === 'object' ? Number(s.lockMinutesAfterClose) : NaN;
  return Number.isFinite(v) && v >= 0 ? Math.trunc(v) : 0;
}

/**
 * The end of the closing lock of a season ending at [endsAt] (null without
 * an end or without a lock), and whether [now] is already past it: a payout
 * that writes mails after it is late (the app has left "Đang chốt bảng").
 */
function lockInfo(endsAt, minutes, now) {
  if (!(endsAt instanceof Date) || !(minutes > 0)) return { lockedUntil: null, late: false };
  const lockedUntil = new Date(endsAt.getTime() + minutes * 60 * 1000);
  return { lockedUntil, late: now.getTime() >= lockedUntil.getTime() };
}

module.exports = {
  VN_MS, DAY_MS, vnDay, splitKey, clock, season, seasonAt, seasonOf, lockMinutes, lockInfo,
};
