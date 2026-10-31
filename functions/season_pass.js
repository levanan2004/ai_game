'use strict';
// Season Pass, server part (economy.json `seasonPass`, Hà Phương's
// season_pass_v2_block.json; every number is read from there). The server is
// the only writer: progress, XP, the premium purchase and every claim.
//
//   season_pass/{uid}                       {day, dayAt}: the game-day clock of
//                                           the last save seen (antiFarm)
//   season_pass/{uid}/seasons/{period}      {period, themeId, xp, premium,
//                                           premiumAt, daily: {date, c},
//                                           weekly: {week, c, occasions},
//                                           season: {c}, done: {key: 1},
//                                           loginDays: {date: 1},
//                                           playDays: {date: 1}, claimed:
//                                           {'free_3': at}, endMailed}
//   config/seasonPass                       {themeByPeriod: {period: themeId}}
//                                           admin-set; a season without a
//                                           theme has no pass (_themeNote)
//   mails/sp_{uid}_{period}_{track}_{tier}  one per claim (rewards.items)
//   mails/sp_end_{uid}_{period}             the season-end mail (autoMail)
//
// Seasons: alignWith 'leaderboard' = the Mị lực clock (season.js); the pass
// opens from firstSeasonStart. Mission progress only comes from sources the
// server can check (SOURCES below), never from a client count:
//   save      each save_guard/{uid} advance (a save guardSave accepted), after
//             the Bảng Đánh giá antiFarm
//             (ratingBoard.minGameDaySeconds per game day, else nothing of
//             that jump counts; maxReviewsPerGameDay; milestoneTitles
//             .serverCheck.maxServedPerGameDay for bouquets)
//   login     users/{uid}/welfare/login claimed today (server VN date)
//   derived   counted from the missions above
// Goals without a source never move (UNVERIFIED) until one exists.

const S = require('./season');
const W = require('./wallet');
const G = require('./gacha');
const AC = require('./anti_cheat');
const { milestoneConfig } = require('./milestones');

class SeasonPassError extends Error {
  constructor(code) { super(code); this.code = code; }
}

const int = (v) => (Number.isFinite(Number(v)) ? Math.max(0, Math.floor(Number(v))) : 0);
const SERVED = new Set(['great', 'okay', 'unhappy']);

const SOURCES = {
  bouquetsSold: 'save',
  greatReviews: 'save',
  onlineDelivered: 'save',
  occasionVariety: 'save',
  themeFlowerStemsSold: 'save',
  gameDaysPlayed: 'save',
  loginDays: 'login',
  dailyMissionsDone: 'derived',
  weeklySetsCleared: 'derived',
};

/** Nhất's sp_theme_*_name (v14_season_pass/text_vi.json), by nameKey. */
const THEME_NAMES = {
  sp_theme_0803_name: 'Mùa Hồng Tháng Ba',
  sp_theme_2010_name: 'Mùa Thu Tri Ân',
  sp_theme_tet_name: 'Mùa Xuân Sớm Mai',
  sp_theme_2011_name: 'Tri ân 20/11',
};

/** Nhất's sp_reward_* / sp_claim_mail_* (v14 text_vi.json) for the claim mails. */
const dots = (n) => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
const PET_ITEM_NAMES = { no_co_vai: 'Nơ cổ vải' }; // pet_item_<id>
const REWARD_TEXT = {
  coins: (i) => `${dots(i.amount)} xu`,
  phaLe: (i) => `${dots(i.amount)} Pha lê`,
  ticket: (i) => `${dots(i.amount)} vé quay`,
  treat: (i) => `${dots(i.amount)} bánh mật`,
  giotHoa: (i) => `${dots(i.amount)} giọt hoa`,
  petItem: (i) => PET_ITEM_NAMES[i.id] || null,
};
const REWARD_JOIN = ' + ';

/** sp_claim_mail_title / _body ({bac}, {tenMua}, {thuong}, {ngay}); premium tag. */
function claimMailText(tier, track, seasonName, items, days) {
  const parts = items.map((i) => (REWARD_TEXT[i.kind] ? REWARD_TEXT[i.kind](i) : null));
  if (parts.some((x) => !x)) throw new Error('season pass: no text for a reward');
  const title = `Quà bậc ${tier} Season Pass đã tới!`;
  const body = `Tiệm mình vừa lên bậc ${tier} của ${seasonName}. Quà gửi kèm thư này: `
    + `${parts.join(REWARD_JOIN)}. Mở thư để nhận nhé, thư giữ trong ${days} ngày.`;
  return {
    title,
    body,
    ...(track === 'premium' ? { tag: 'Quà nhánh cao cấp' } : {}),
  };
}

/**
 * economy.json seasonPass -> checked config, or null without the block (the
 * pass stays closed). A block with a bad number throws: never made-up numbers.
 */
function passConfig(eco) {
  const sp = eco && eco.seasonPass;
  if (!sp || typeof sp !== 'object') return null;
  const need = (v, name, min = 1) => {
    const n = Number(v);
    if (!Number.isInteger(n) || n < min) throw new Error(`economy.json seasonPass.${name}`);
    return n;
  };
  const cycleDays = need(sp.cycleDays, 'cycleDays');
  const first = S.vnDay(sp.firstSeasonStart);
  if (!first) throw new Error('economy.json seasonPass.firstSeasonStart');
  const lb = eco.leaderboard || {};
  const lbStart = S.vnDay(lb.seasonStart);
  if (sp.alignWith !== 'leaderboard' || !lbStart || typeof lb.periodKey !== 'string') {
    throw new Error('economy.json seasonPass.alignWith');
  }
  const tiers = (Array.isArray(sp.tiers) ? sp.tiers : []).map((t, i) => {
    if (!t || need(t.tier, `tiers[${i}].tier`) !== i + 1) throw new Error(`economy.json seasonPass.tiers[${i}]`);
    return { tier: i + 1, xp: need(t.xp, `tiers[${i}].xp`), free: t.free || {}, premium: t.premium || {} };
  });
  if (!tiers.length) throw new Error('economy.json seasonPass.tiers');
  const missions = (Array.isArray(sp.missions) ? sp.missions : []).map((m, i) => {
    if (!m || typeof m.missionKey !== 'string' || !['daily', 'weekly', 'season'].includes(m.type)
      || typeof m.goal !== 'string') throw new Error(`economy.json seasonPass.missions[${i}]`);
    // Every goal needs a server source (no client-only missions any more).
    if (!SOURCES[m.goal]) throw new Error(`economy.json seasonPass.missions[${i}].goal ${m.goal}: no server source`);
    return {
      key: m.missionKey, type: m.type, goal: m.goal,
      target: need(m.target, `missions[${i}].target`), xp: need(m.xp, `missions[${i}].xp`),
      source: SOURCES[m.goal] || null,
    };
  });
  const prem = sp.premium || {};
  if (prem.currency !== 'phaLe') throw new Error('economy.json seasonPass.premium.currency');
  const themes = {};
  for (const t of Array.isArray(sp.themes) ? sp.themes : []) {
    if (t && typeof t.themeId === 'string') {
      themes[t.themeId] = { nameKey: t.nameKey, flowers: Array.isArray(t.themeFlowers) ? t.themeFlowers : [] };
    }
  }
  const un = sp.unclaimedAtSeasonEnd || {};
  return {
    clock: S.clock(lb.periodKey, lbStart, cycleDays),
    firstStart: first,
    tiers,
    missions,
    themes,
    price: need(prem.price, 'premium.price'),
    buyUntilDay: need(prem.buyableUntilDayOfSeason, 'premium.buyableUntilDayOfSeason'),
    retroactive: prem.retroactiveClaims !== false,
    autoMail: un.mode === 'autoMail',
    mailExpireDays: un.mode === 'autoMail' ? need(un.mailExpireDays, 'unclaimedAtSeasonEnd.mailExpireDays') : 0,
  };
}

/** The season at [now]: {period, start, end, number}; null before the pass opens. */
function seasonNow(cfg, now) {
  if (now.getTime() < cfg.firstStart.getTime()) return null;
  const s = S.seasonAt(cfg.clock, now);
  return now.getTime() >= s.start.getTime() && now.getTime() < s.end.getTime() ? s : null;
}

async function themeOf(db, cfg, period, tx) {
  const ref = db.doc('config/seasonPass');
  const snap = tx ? await tx.get(ref) : await ref.get();
  const id = snap.exists ? ((snap.data().themeByPeriod || {})[period]) : null;
  return typeof id === 'string' && cfg.themes[id] ? id : null;
}

const vnDate = (d) => new Date(d.getTime() + S.VN_MS).toISOString().slice(0, 10);
/** 0-based week of the season holding [now]. */
const weekOf = (season, now) => Math.floor((now.getTime() - season.start.getTime()) / (7 * S.DAY_MS));

/** Cumulative XP needed for each tier; the tier reached at [xp]. */
function tierAt(cfg, xp) {
  let need = 0;
  let reached = 0;
  for (const t of cfg.tiers) {
    need += t.xp;
    if (xp >= need) reached = t.tier; else break;
  }
  return reached;
}

function emptyDoc(period, themeId, now) {
  return {
    period, themeId, xp: 0, premium: false, daily: { date: '', c: {} },
    weekly: { week: -1, c: {}, occasions: [] }, season: { c: {} }, done: {},
    loginDays: {}, playDays: {}, claimed: {}, createdAt: now, updatedAt: now,
  };
}

/**
 * Adds [add] ({goal: n}) to the doc's counters at [now] and completes the
 * missions it reaches (each once per day / week / season). Derived goals move
 * here too. Mutates [doc]; returns the XP gained.
 */
function applyProgress(cfg, doc, season, now, add, occasions = []) {
  const date = vnDate(now);
  const week = weekOf(season, now);
  if (doc.daily.date !== date) doc.daily = { date, c: {} };
  if (doc.weekly.week !== week) doc.weekly = { week, c: {}, occasions: [] };
  const bump = (scope, goal, n) => { if (n > 0) scope.c[goal] = int(scope.c[goal]) + n; };
  for (const [goal, n] of Object.entries(add)) {
    bump(doc.daily, goal, n);
    bump(doc.weekly, goal, n);
    bump(doc.season, goal, n);
  }
  const fresh = occasions.filter((o) => !doc.weekly.occasions.includes(o));
  if (fresh.length) {
    doc.weekly.occasions = [...doc.weekly.occasions, ...new Set(fresh)];
    doc.weekly.c.occasionVariety = doc.weekly.occasions.length;
  }
  let gained = 0;
  const scopeKey = (m) => (m.type === 'daily' ? `${m.key}@${date}` : m.type === 'weekly' ? `${m.key}@w${week}` : m.key);
  const scopeOf = (m) => (m.type === 'daily' ? doc.daily : m.type === 'weekly' ? doc.weekly : doc.season);
  // Two passes: the first completes direct goals, which may move derived ones.
  for (let pass = 0; pass < 3; pass++) {
    let changed = false;
    for (const m of cfg.missions) {
      if (!m.source) continue;
      const k = scopeKey(m);
      if (doc.done[k] || int(scopeOf(m).c[m.goal]) < m.target) continue;
      doc.done[k] = 1;
      gained += m.xp;
      changed = true;
      if (m.type === 'daily') bump(doc.season, 'dailyMissionsDone', 1), bump(doc.weekly, 'dailyMissionsDone', 1), bump(doc.daily, 'dailyMissionsDone', 1);
      if (m.type === 'weekly') {
        const weekly = cfg.missions.filter((x) => x.type === 'weekly');
        if (weekly.every((x) => doc.done[`${x.key}@w${week}`])) bump(doc.season, 'weeklySetsCleared', 1);
      }
    }
    if (!changed) break;
  }
  doc.xp = int(doc.xp) + gained;
  return gained;
}

/** What one save adds on the game-day clock. Pure. */
function planSave(eco, cfg, clockSt, progress, now, themeFlowers, th = AC.thresholds()) {
  const out = { clock: null, add: {}, occasions: [], days: 0, short: false };
  const day = progress && Number.isInteger(progress.day) ? progress.day : null;
  if (day == null || day < 1) return out;
  if (!clockSt || !Number.isInteger(clockSt.day) || day < clockSt.day) {
    out.clock = { day, dayAt: now, sold: int(progress.lifetimeBouquetsSold) };
    return out;
  }
  if (day === clockSt.day) return out;
  const from = clockSt.day;
  const k = day - from;
  out.clock = { day, dayAt: now, sold: int(progress.lifetimeBouquetsSold) };
  const rb = (eco && eco.ratingBoard) || {};
  const daySeconds = Number(rb.minGameDaySeconds);
  const dayMax = Number(rb.maxReviewsPerGameDay);
  if (!(daySeconds >= 0) || !(dayMax >= 1)) throw new Error('economy.json ratingBoard antiFarm');
  const at = AC.toDate(clockSt.dayAt) || now;
  if ((now.getTime() - at.getTime()) / 1000 < daySeconds * k) { out.short = true; return out; }
  const mc = milestoneConfig(eco);
  if (!mc) throw new Error('economy.json milestoneTitles.serverCheck');
  const maxStems = Number(eco.bouquet && eco.bouquet.maxStems);
  if (!(maxStems >= 1)) throw new Error('economy.json bouquet.maxStems');
  // nguong_chong_hack.json limits on top of the ratingBoard antiFarm ones.
  const t = th || {};
  const servedCap = Math.min(mc.perGameDay, int(t.servedCapPerGameDay) || mc.perGameDay);
  const reviewCap = Math.min(dayMax, int(t.maxReviewsPerGameDay) || dayMax);
  const starCap = int(t.maxStarsPerGameDay) || Infinity;
  out.days = k;
  const sold = Math.min(Math.max(0, int(progress.lifetimeBouquetsSold) - int(clockSt.sold)), servedCap * k);
  const byDay = new Map();
  for (const r of Array.isArray(progress.reviews) ? progress.reviews : []) {
    if (!r || typeof r !== 'object' || !Number.isInteger(r.day) || r.day < from || r.day >= day) continue;
    if (!byDay.has(r.day)) byDay.set(r.day, []);
    byDay.get(r.day).push(r);
  }
  let great = 0; let online = 0; let stems = 0;
  for (const list of byDay.values()) {
    // A farmed day counts nothing.
    if (list.length > reviewCap) continue;
    if (list.reduce((a, r) => a + (Number.isInteger(r.stars) ? r.stars : 0), 0) > starCap) continue;
    let served = 0;
    let dayStems = 0;
    for (const r of list) {
      if (!SERVED.has(r.outcome) || served >= servedCap) continue;
      served++;
      if (r.outcome === 'great') great++;
      if (r.online === true && r.deliveryIssue !== 'missed') online++;
      if (r.online !== true && typeof r.occasionId === 'string' && r.occasionId) out.occasions.push(r.occasionId);
      let one = 0;
      for (const [f, n] of Object.entries(r.stems && typeof r.stems === 'object' ? r.stems : {})) {
        if (themeFlowers.includes(f)) one += int(n);
      }
      dayStems += Math.min(one, maxStems); // one bouquet holds at most bouquet.maxStems
    }
    stems += Math.min(dayStems, maxStems * served);
  }
  out.add = { bouquetsSold: sold, greatReviews: great, onlineDelivered: online, themeFlowerStemsSold: stems };
  return out;
}

const flaggedIn = async (tx, db, uid) => {
  const f = await tx.get(db.doc(`cheat_flags/${uid}`));
  return f.exists && f.data().flagged === true;
};

/**
 * save_guard/{uid} write (Bảo's review 31/10, fix 1). guardSave writes a new
 * {day, money, at} only for a save that passed every anti-cheat check, so the
 * pass counts a save only when the guard moved its day forward, and only the
 * save the guard accepted (users/{uid}.progress.day === the guard's day).
 * [before] / [after] are the save_guard data; the clock is the guard's
 * server time. The counts still come from that save's fields (the server
 * keeps no per-bouquet record): capped per game day by ratingBoard,
 * milestoneTitles.serverCheck, nguong_chong_hack.json and bouquet.maxStems.
 */
async function ingestSave({ db, eco, uid, before, after, now, th = AC.thresholds() }) {
  const cfg = passConfig(eco);
  if (!cfg || !after || !Number.isInteger(after.day)) return { status: 'off' };
  if (before && Number.isInteger(before.day) && after.day === before.day) return { status: 'same' };
  const at = AC.toDate(after.at) || now;
  const season = seasonNow(cfg, at);
  return db.runTransaction(async (tx) => {
    if (await flaggedIn(tx, db, uid)) return { status: 'flagged' };
    const user = await tx.get(db.doc(`users/${uid}`));
    const progress = user.exists ? user.data().progress : null;
    if (!progress || typeof progress !== 'object' || progress.day !== after.day) return { status: 'not-guarded' };
    const rootRef = db.doc(`season_pass/${uid}`);
    const root = await tx.get(rootRef);
    const themeId = season ? await themeOf(db, cfg, season.period, tx) : null;
    const flowers = themeId ? cfg.themes[themeId].flowers : [];
    const p = planSave(eco, cfg, root.exists ? root.data() : null, progress, at, flowers, th);
    if (!p.clock) return { status: 'same' };
    tx.set(rootRef, p.clock);
    if (!season || !themeId || !p.days) return { status: p.short ? 'short' : 'clock' };
    const ref = db.doc(`season_pass/${uid}/seasons/${season.period}`);
    const snap = await tx.get(ref);
    const doc = snap.exists ? snap.data() : emptyDoc(season.period, themeId, at);
    const date = vnDate(at);
    const add = { ...p.add };
    if (!doc.playDays[date]) { doc.playDays[date] = 1; add.gameDaysPlayed = 1; }
    const xp = applyProgress(cfg, doc, season, at, add, p.occasions);
    tx.set(ref, { ...doc, updatedAt: at });
    return { status: 'counted', xp };
  });
}

/** users/{uid}/welfare/login write: one login day per VN date, server clock. */
async function ingestLogin({ db, eco, uid, welfare, now }) {
  const cfg = passConfig(eco);
  if (!cfg || !welfare || welfare.lastClaimDay !== G.vnDay(now)) return { status: 'off' };
  const season = seasonNow(cfg, now);
  if (!season) return { status: 'off' };
  return db.runTransaction(async (tx) => {
    if (await flaggedIn(tx, db, uid)) return { status: 'flagged' };
    const themeId = await themeOf(db, cfg, season.period, tx);
    if (!themeId) return { status: 'no-theme' };
    const ref = db.doc(`season_pass/${uid}/seasons/${season.period}`);
    const snap = await tx.get(ref);
    const doc = snap.exists ? snap.data() : emptyDoc(season.period, themeId, now);
    const date = vnDate(now);
    if (doc.loginDays[date]) return { status: 'already' };
    doc.loginDays[date] = 1;
    const xp = applyProgress(cfg, doc, season, now, { loginDays: 1 });
    tx.set(ref, { ...doc, updatedAt: now });
    return { status: 'counted', xp };
  });
}

/**
 * One track of one tier -> {items (mail rewards), skins (wallet ids),
 * unmapped (block keys with no reward kind yet)}. {theme} = themeId.
 */
function rewardsOf(line, themeId) {
  const items = [];
  const skins = [];
  const unmapped = [];
  for (const [k, v] of Object.entries(line || {})) {
    if (k === 'skinTier') continue;
    if (k === 'coins' || k === 'giotHoa' || k === 'phaLe') items.push({ kind: k, amount: int(v) });
    else if (k === 'gachaTicket') items.push({ kind: 'ticket', amount: int(v) });
    else if (k === 'banhMat') items.push({ kind: 'treat', id: 'banh_mat', amount: int(v) });
    // The mail pet-item grant (charm.js counts mailed pet items too).
    else if (k === 'petItem' && typeof v === 'string' && v) items.push({ kind: 'petItem', id: v, amount: 1 });
    else if ((k === 'skin' || k === 'khungAvatar') && typeof v === 'string') skins.push(v.replace('{theme}', themeId));
    else unmapped.push(k);
  }
  return { items: items.filter((i) => i.amount > 0), skins, unmapped };
}

function grantSkins(wallet, skins) {
  if (!skins.length) return;
  wallet.skins = { ...(wallet.skins || {}) };
  const frames = new Set(Array.isArray(wallet.frames) ? wallet.frames : []);
  for (const id of skins) {
    wallet.skins[id] = 1;
    if (id.startsWith('khung_avatar_')) frames.add(id);
  }
  wallet.frames = [...frames];
}

function view(cfg, doc, now) {
  const d = doc || {};
  return {
    period: d.period || null, themeId: d.themeId || null, xp: int(d.xp),
    tier: tierAt(cfg, int(d.xp)), premium: d.premium === true, claimed: Object.keys(d.claimed || {}),
  };
}

function checkTierTrack(cfg, data) {
  const tier = Number(data && data.tier);
  const track = data && data.track;
  if (!Number.isInteger(tier) || tier < 1 || tier > cfg.tiers.length || (track !== 'free' && track !== 'premium')) {
    throw new SeasonPassError('bad');
  }
  return { tier, track };
}

/** Callable: claim one tier of one track of the running season. Idempotent. */
async function claim({ db, eco, uid, now, data, accountCreated }) {
  const cfg = passConfig(eco);
  if (!cfg) throw new SeasonPassError('closed');
  const { tier, track } = checkTierTrack(cfg, data);
  const season = seasonNow(cfg, now);
  if (!season) throw new SeasonPassError('closed');
  return db.runTransaction(async (tx) => {
    if (await flaggedIn(tx, db, uid)) throw new SeasonPassError('flagged');
    const ref = db.doc(`season_pass/${uid}/seasons/${season.period}`);
    const snap = await tx.get(ref);
    if (!snap.exists) throw new SeasonPassError('not-reached');
    const doc = snap.data();
    const key = `${track}_${tier}`;
    const mailId = `sp_${uid}_${season.period}_${track}_${tier}`;
    if (doc.claimed && doc.claimed[key]) return { status: 'already', mailId, ...view(cfg, doc, now) };
    if (tierAt(cfg, int(doc.xp)) < tier) throw new SeasonPassError('not-reached');
    if (track === 'premium' && doc.premium !== true) throw new SeasonPassError('no-premium');
    const r = rewardsOf(cfg.tiers[tier - 1][track], doc.themeId);
    if (r.skins.length) {
      const { ref: wref, wallet } = await W.loadWallet(tx, db, eco, uid, now, accountCreated);
      grantSkins(wallet, r.skins);
      W.save(tx, wref, wallet, now);
    }
    if (r.items.length) {
      const theme = cfg.themes[doc.themeId] || {};
      const text = claimMailText(tier, track, THEME_NAMES[theme.nameKey] || '', r.items, cfg.mailExpireDays);
      tx.set(db.doc(`mails/${mailId}`), {
        ...text, target: uid, rewards: { items: r.items },
        ...(r.items.some((i) => i.kind === 'phaLe' || i.kind === 'ticket') ? { walletClaim: true } : {}),
        seasonPass: { period: season.period, tier, track }, createdAt: now,
      });
    }
    doc.claimed = { ...(doc.claimed || {}), [key]: now };
    if (r.unmapped.length) doc.unmapped = { ...(doc.unmapped || {}), [key]: r.unmapped };
    tx.set(ref, { ...doc, updatedAt: now });
    return {
      status: 'claimed', mailId: r.items.length ? mailId : null, items: r.items,
      skins: r.skins, unmapped: r.unmapped, ...view(cfg, doc, now),
    };
  });
}

/** Callable: open the premium track with Pha lê from the server wallet. Idempotent. */
async function buyPremium({ db, eco, uid, now, accountCreated }) {
  const cfg = passConfig(eco);
  if (!cfg) throw new SeasonPassError('closed');
  const season = seasonNow(cfg, now);
  if (!season) throw new SeasonPassError('closed');
  const dayOfSeason = Math.floor((now.getTime() - season.start.getTime()) / S.DAY_MS) + 1;
  return db.runTransaction(async (tx) => {
    if (await flaggedIn(tx, db, uid)) throw new SeasonPassError('flagged');
    const themeId = await themeOf(db, cfg, season.period, tx);
    if (!themeId) throw new SeasonPassError('closed');
    const ref = db.doc(`season_pass/${uid}/seasons/${season.period}`);
    const snap = await tx.get(ref);
    const doc = snap.exists ? snap.data() : emptyDoc(season.period, themeId, now);
    const { ref: wref, wallet } = await W.loadWallet(tx, db, eco, uid, now, accountCreated);
    if (doc.premium === true) return { status: 'already', phaLe: W.view(eco, wallet, now).phaLe, ...view(cfg, doc, now) };
    if (dayOfSeason > cfg.buyUntilDay) throw new SeasonPassError('too-late');
    try { W.spend(eco, wallet, cfg.price); } catch (e) {
      if (e instanceof W.WalletError) throw new SeasonPassError('balance');
      throw e;
    }
    doc.premium = true;
    doc.premiumAt = now;
    doc.premiumPhaLe = cfg.price;
    W.save(tx, wref, wallet, now);
    W.ledger(tx, db, uid, { type: 'seasonPass', period: season.period, phaLe: -cfg.price }, now);
    tx.set(ref, { ...doc, updatedAt: now });
    return { status: 'bought', phaLe: W.view(eco, wallet, now).phaLe, ...view(cfg, doc, now) };
  });
}

/**
 * Scheduled: after a season ends, one mail per player with every tier reached
 * and not claimed (premium only if bought); never expires (Hà Phương 31/10).
 * Skins go straight to the wallet. Runs on the season just closed.
 */
/**
 * [accountCreated] is (uid) => async () => Auth creation time. A player whose
 * wallet cannot be seeded (no Auth time) is skipped and stays unmailed.
 */
async function mailUnclaimed({ db, eco, now, accountCreated = () => async () => null, logger }) {
  const cfg = passConfig(eco);
  if (!cfg || !cfg.autoMail) return { status: 'off', mailed: 0 };
  const prev = S.seasonAt(cfg.clock, new Date(now.getTime() - cfg.clock.cycleDays * S.DAY_MS));
  if (prev.end.getTime() > now.getTime() || prev.start.getTime() < cfg.firstStart.getTime()) {
    return { status: 'none', mailed: 0 };
  }
  const users = await db.collection('season_pass').listDocuments();
  let mailed = 0;
  for (const u of users) {
    const uid = u.id;
    let did = false;
    try {
      did = await mailOne(uid);
    } catch (e) {
      if (!(e instanceof W.WalletError)) throw e;
      if (logger) logger.warn('season pass end mail deferred', { uid, code: e.code });
    }
    if (did) mailed++;
  }
  if (logger) logger.info('season pass end mails', { period: prev.period, mailed });
  return { status: 'done', period: prev.period, mailed };

  function mailOne(uid) {
    return db.runTransaction(async (tx) => {
      const ref = db.doc(`season_pass/${uid}/seasons/${prev.period}`);
      const snap = await tx.get(ref);
      if (!snap.exists || snap.data().endMailed) return false;
      // A flagged account gets no season reward (save_guard.js); the season
      // stays unmailed so a cleared flag can still be mailed later.
      if (await flaggedIn(tx, db, uid)) return false;
      const doc = snap.data();
      const reached = tierAt(cfg, int(doc.xp));
      const items = [];
      const skins = [];
      const claimed = { ...(doc.claimed || {}) };
      for (let t = 1; t <= reached; t++) {
        for (const track of doc.premium === true ? ['free', 'premium'] : ['free']) {
          if (claimed[`${track}_${t}`]) continue;
          const r = rewardsOf(cfg.tiers[t - 1][track], doc.themeId);
          items.push(...r.items);
          skins.push(...r.skins);
          claimed[`${track}_${t}`] = now;
        }
      }
      if (skins.length) {
        const { ref: wref, wallet } = await W.loadWallet(tx, db, eco, uid, now, accountCreated(uid));
        grantSkins(wallet, skins);
        W.save(tx, wref, wallet, now);
      }
      const merged = {};
      for (const i of items) {
        const k = `${i.kind}|${i.id || ''}`;
        merged[k] = merged[k] ? { ...merged[k], amount: merged[k].amount + i.amount } : { ...i };
      }
      const list = Object.values(merged);
      if (list.length) {
        const theme = cfg.themes[doc.themeId] || {};
        const name = THEME_NAMES[theme.nameKey] || '';
        tx.set(db.doc(`mails/sp_end_${uid}_${prev.period}`), {
          // sp_season_end_mail_title / sp_season_end_mail_body (Nhất, v14).
          title: `Quà mùa ${name} đang chờ bạn`,
          body: `Mùa ${name} đã khép lại. Quà bạn đã đạt mà chưa nhận được gửi vào Thư, nhận trong `
            + `${cfg.mailExpireDays} ngày nhé. Quà nhánh Pha lê chỉ gửi nếu bạn đã mở nhánh. `
            + 'Điểm và cấp không chuyển sang mùa sau.',
          target: uid, rewards: { items: list },
          ...(list.some((i) => i.kind === 'phaLe' || i.kind === 'ticket') ? { walletClaim: true } : {}),
          seasonPass: { period: prev.period, end: true },
          // Season Pass mails never expire (Hà Phương 31/10).
          createdAt: now,
        });
      }
      tx.set(ref, { ...doc, claimed, endMailed: now, updatedAt: now });
      return list.length > 0 || skins.length > 0;
    });
  }
}

module.exports = {
  SeasonPassError, SOURCES, THEME_NAMES, claimMailText, passConfig, seasonNow, tierAt, applyProgress, planSave, rewardsOf,
  ingestSave, ingestLogin, claim, buyPremium, mailUnclaimed, emptyDoc,
};
