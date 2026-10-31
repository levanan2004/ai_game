'use strict';
// Season Pass server part (season_pass.js) on fake_firestore.js.
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const SP = require('./season_pass');

const ECO = require('./economy.json');
const CFG = SP.passConfig(ECO);
const UID = 'u1';
// Season 2 of the shared clock (the pass's firstSeasonStart), day 2, 10:00 VN.
const T0 = new Date('2026-11-10T03:00:00Z');
const PERIOD = SP.seasonNow(CFG, T0).period;
const after = (s) => new Date(T0.getTime() + s * 1000);
const DOC = `season_pass/${UID}/seasons/${PERIOD}`;
const sumXp = (n) => CFG.tiers.slice(0, n).reduce((a, t) => a + t.xp, 0);

// A save guardSave accepted: users/{uid}.progress, then the save_guard/{uid}
// write it makes (the trigger the pass listens to).
async function save(d, progress, now) {
  d.seed(`users/${UID}`, { progress });
  const ref = `save_guard/${UID}`;
  const before = d.read(ref) || null;
  const after = { day: progress.day, money: 0, at: now };
  d.seed(ref, after);
  return SP.ingestSave({ db: d, eco: ECO, uid: UID, before, after, now });
}

function db({ theme = 'tet', phaLe = 0, xp = null, premium = false } = {}) {
  const d = new FakeFirestore();
  if (theme) d.seed('config/seasonPass', { themeByPeriod: { [PERIOD]: theme } });
  d.seed(`wallets/${UID}`, { seededAt: T0, phaLe, cards: {}, earned: {} });
  if (xp != null) d.seed(DOC, { ...SP.emptyDoc(PERIOD, theme, T0), xp, premium });
  return d;
}

test('config: every number from economy.json seasonPass', () => {
  const sp = ECO.seasonPass;
  assert.equal(CFG.tiers.length, sp.tiers.length);
  assert.equal(CFG.missions.length, sp.missions.length);
  assert.equal(CFG.price, sp.premium.price);
  assert.equal(CFG.buyUntilDay, sp.premium.buyableUntilDayOfSeason);
  assert.equal(CFG.mailExpireDays, sp.unclaimedAtSeasonEnd.mailExpireDays);
  assert.equal(sumXp(CFG.tiers.length), sp.xp.totalToMax);
  assert.equal(SP.passConfig({}), null);
  assert.throws(() => SP.passConfig({ ...ECO, seasonPass: { ...sp, premium: { ...sp.premium, price: 'x' } } }));
  assert.equal(SP.seasonNow(CFG, new Date('2026-11-01T00:00:00Z')), null, 'closed before firstSeasonStart');
});

test('tierAt follows the cumulative perTier XP', () => {
  assert.equal(SP.tierAt(CFG, 0), 0);
  assert.equal(SP.tierAt(CFG, sumXp(1)), 1);
  assert.equal(SP.tierAt(CFG, sumXp(12) - 1), 11);
  assert.equal(SP.tierAt(CFG, 1e9), CFG.tiers.length);
});

test('save: bouquets and reviews count after the antiFarm clock; missions give XP once', async () => {
  const d = db();
  const daily = ECO.seasonPass.missions.find((m) => m.type === 'daily' && m.goal === 'bouquetsSold');
  await save(d, { day: 5, lifetimeBouquetsSold: 100 }, T0);
  assert.equal(d.read(DOC), undefined, 'the first save only starts the clock');
  const reviews = Array.from({ length: daily.target }, () => ({ day: 5, outcome: 'great', stars: 5, occasionId: 'birthday', stems: {} }));
  const wait = ECO.ratingBoard.minGameDaySeconds;
  await save(d, { day: 6, lifetimeBouquetsSold: 100 + daily.target, reviews }, after(wait));
  const doc = d.read(DOC);
  assert.ok(doc.done[`${daily.key || daily.missionKey}@${'2026-11-10'}`]);
  assert.ok(doc.xp >= daily.xp);
  const xp = doc.xp;
  // The same day again: nothing new.
  await save(d, { day: 6, lifetimeBouquetsSold: 999, reviews }, after(wait + 10));
  assert.equal(d.read(DOC).xp, xp);
});

test('save: a jump faster than minGameDaySeconds counts nothing', async () => {
  const d = db();
  await save(d, { day: 5, lifetimeBouquetsSold: 0 }, T0);
  await save(d, { day: 9, lifetimeBouquetsSold: 200 }, after(10));
  assert.equal(d.read(DOC), undefined);
});

test('save: no theme for the season = no pass progress; flagged account ignored', async () => {
  const d = db({ theme: null });
  await save(d, { day: 5, lifetimeBouquetsSold: 0 }, T0);
  await save(d, { day: 6, lifetimeBouquetsSold: 50 }, after(1000));
  assert.equal(d.read(DOC), undefined);
  const f = db();
  f.seed(`cheat_flags/${UID}`, { flagged: true });
  assert.equal((await save(f, { day: 5 }, T0)).status, 'flagged');
});

test('fix 1: only a save the guard accepted counts; raw save edits and capped fields do not', async () => {
  const d = db();
  const wait = ECO.ratingBoard.minGameDaySeconds;
  await save(d, { day: 5, lifetimeBouquetsSold: 0 }, T0);
  // users/{uid} changed but the guard did not move (a rejected save rewrites
  // the same state): nothing.
  d.seed(`users/${UID}`, { progress: { day: 6, lifetimeBouquetsSold: 100000 } });
  const g = d.read(`save_guard/${UID}`);
  assert.equal((await SP.ingestSave({ db: d, eco: ECO, uid: UID, before: g, after: g, now: after(wait) })).status, 'same');
  // The guard's day is not the save's day (reverted meanwhile): nothing.
  d.seed(`users/${UID}`, { progress: { day: 5, lifetimeBouquetsSold: 100000 } });
  const r = await SP.ingestSave({ db: d, eco: ECO, uid: UID, before: g, after: { day: 6, money: 0, at: after(wait) }, now: after(wait) });
  assert.equal(r.status, 'not-guarded');
  assert.equal(d.read(DOC), undefined);
});

test('fix 1: bouquets capped by servedCapPerGameDay, stems by bouquet.maxStems per bouquet and per day', () => {
  const TH = require('./anti_cheat').thresholds();
  const max = ECO.bouquet.maxStems;
  assert.equal(max, 15);
  const flowers = ['hoa_x'];
  const clock = { day: 5, dayAt: T0, sold: 0 };
  const wait = ECO.ratingBoard.minGameDaySeconds;
  const reviews = [
    { day: 5, outcome: 'great', stars: 5, stems: { hoa_x: 999 } },
    { day: 5, outcome: 'okay', stars: 3, stems: { hoa_x: 4 } },
    { day: 5, outcome: 'left', stars: 0, stems: { hoa_x: 15 } },
  ];
  const p = SP.planSave(ECO, CFG, clock, { day: 6, lifetimeBouquetsSold: 1e9, reviews }, after(wait), flowers, TH);
  assert.equal(TH.servedCapPerGameDay, 60);
  assert.equal(p.add.bouquetsSold, 60);
  assert.equal(p.add.themeFlowerStemsSold, max + 4, 'one bouquet holds at most maxStems; unserved counts 0');
  const many = Array.from({ length: TH.maxReviewsPerGameDay + 1 }, () => ({ day: 5, outcome: 'great', stars: 1, stems: { hoa_x: 1 } }));
  const q = SP.planSave(ECO, CFG, clock, { day: 6, reviews: many }, after(wait), flowers, TH);
  assert.equal(q.add.greatReviews, 0, 'a day over maxReviewsPerGameDay counts nothing');
});

test('fix 2/5: a flagged account cannot claim, buy premium or get the end mail (flag read in the transaction)', async () => {
  const d = db({ xp: sumXp(CFG.tiers.length), phaLe: CFG.price });
  d.seed(`cheat_flags/${UID}`, { flagged: true });
  const code = (c) => (e) => e instanceof SP.SeasonPassError && e.code === c;
  await assert.rejects(SP.claim({ db: d, eco: ECO, uid: UID, now: T0, data: { tier: 1, track: 'free' } }), code('flagged'));
  await assert.rejects(SP.buyPremium({ db: d, eco: ECO, uid: UID, now: T0 }), code('flagged'));
  const end = new Date(SP.seasonNow(CFG, T0).end.getTime() + 3600000);
  const r = await SP.mailUnclaimed({ db: d, eco: ECO, now: end });
  assert.equal(r.mailed, 0);
  assert.equal(d.read(`mails/sp_end_${UID}_${PERIOD}`), undefined);
  assert.equal(d.read(DOC).endMailed, undefined, 'kept for a cleared flag');
});

test('client-only goals never move', () => {
  const doc = SP.emptyDoc(PERIOD, 'tet', T0);
  const season = SP.seasonNow(CFG, T0);
  const add = {};
  for (const m of CFG.missions) if (!m.source) add[m.goal] = 1e9;
  assert.equal(SP.applyProgress(CFG, doc, season, T0, add), 0);
});

test('login: one login day per VN date from the server clock', async () => {
  const d = db();
  const G = require('./gacha');
  const welfare = { lastClaimDay: G.vnDay(T0) };
  assert.equal((await SP.ingestLogin({ db: d, eco: ECO, uid: UID, welfare, now: T0 })).status, 'counted');
  assert.equal((await SP.ingestLogin({ db: d, eco: ECO, uid: UID, welfare, now: after(60) })).status, 'already');
  assert.equal((await SP.ingestLogin({ db: d, eco: ECO, uid: UID, welfare: { lastClaimDay: G.vnDay(T0) - 1 }, now: T0 })).status, 'off');
  assert.equal(d.read(DOC).season.c.loginDays, 1);
});

test('buy premium: takes the block price from the wallet, once, refuses short balance', async () => {
  const poor = db({ phaLe: CFG.price - 1 });
  await assert.rejects(SP.buyPremium({ db: poor, eco: ECO, uid: UID, now: T0 }), { code: 'balance' });
  assert.equal(poor.read(`wallets/${UID}`).phaLe, CFG.price - 1);
  const d = db({ phaLe: CFG.price + 5 });
  const [a, b] = await Promise.all([
    SP.buyPremium({ db: d, eco: ECO, uid: UID, now: T0 }),
    SP.buyPremium({ db: d, eco: ECO, uid: UID, now: T0 }),
  ]);
  assert.deepEqual([a.status, b.status].sort(), ['already', 'bought']);
  assert.equal(d.read(`wallets/${UID}`).phaLe, 5);
  assert.equal(d.read(DOC).premium, true);
  const rows = [...d.docs.keys()].filter((k) => k.startsWith(`wallets/${UID}/ledger/`));
  assert.equal(rows.length, 1);
  assert.equal(d.read(rows[0]).phaLe, -CFG.price);
  await assert.rejects(SP.buyPremium({ db: db({ theme: null, phaLe: 999 }), eco: ECO, uid: UID, now: T0 }), { code: 'closed' });
});

test('claim: tier reached, once per track, premium needs premium; rewards go to a mail / wallet', async () => {
  const d = db({ xp: sumXp(CFG.tiers.length) });
  await assert.rejects(SP.claim({ db: d, eco: ECO, uid: UID, now: T0, data: { tier: 0, track: 'free' } }), { code: 'bad' });
  await assert.rejects(SP.claim({ db: d, eco: ECO, uid: UID, now: T0, data: { tier: 1, track: 'premium' } }), { code: 'no-premium' });
  const t2 = CFG.tiers[1].free;
  const r = await SP.claim({ db: d, eco: ECO, uid: UID, now: T0, data: { tier: 2, track: 'free' } });
  assert.equal(r.status, 'claimed');
  const mail = d.read(`mails/${r.mailId}`);
  assert.equal(mail.target, UID);
  assert.deepEqual(mail.rewards.items, SP.rewardsOf(t2, 'tet').items);
  const again = await SP.claim({ db: d, eco: ECO, uid: UID, now: T0, data: { tier: 2, track: 'free' } });
  assert.equal(again.status, 'already');
  const low = db({ xp: sumXp(3) - 1 });
  await assert.rejects(SP.claim({ db: low, eco: ECO, uid: UID, now: T0, data: { tier: 3, track: 'free' } }), { code: 'not-reached' });
});

test('claim: a skin of the theme goes to wallets.skins (khung avatar also to frames)', async () => {
  const d = db({ xp: sumXp(CFG.tiers.length), premium: true });
  for (const t of CFG.tiers) {
    for (const track of ['free', 'premium']) {
      await SP.claim({ db: d, eco: ECO, uid: UID, now: T0, data: { tier: t.tier, track } });
    }
  }
  const w = d.read(`wallets/${UID}`);
  const want = CFG.tiers.flatMap((t) => [...SP.rewardsOf(t.free, 'tet').skins, ...SP.rewardsOf(t.premium, 'tet').skins]);
  assert.ok(want.length > 0);
  for (const id of want) assert.equal(w.skins[id], 1, id);
  for (const id of want.filter((x) => x.startsWith('khung_avatar_'))) assert.ok(w.frames.includes(id));
  assert.ok(want.every((id) => !id.includes('{theme}')));
});

test('season end: one mail with every unclaimed reached tier, premium only if bought, expiring', async () => {
  const d = db({ xp: sumXp(2), premium: false });
  await SP.claim({ db: d, eco: ECO, uid: UID, now: T0, data: { tier: 1, track: 'free' } });
  const end = SP.seasonNow(CFG, T0).end;
  const now = new Date(end.getTime() + 3600 * 1000);
  const out = await SP.mailUnclaimed({ db: d, eco: ECO, now });
  assert.equal(out.mailed, 1);
  const mail = d.read(`mails/sp_end_${UID}_${PERIOD}`);
  assert.deepEqual(mail.rewards.items, SP.rewardsOf(CFG.tiers[1].free, 'tet').items);
  assert.equal(mail.expiresAt.getTime() - now.getTime(), CFG.mailExpireDays * 86400000);
  assert.equal((await SP.mailUnclaimed({ db: d, eco: ECO, now })).mailed, 0, 'never twice');
});

test('every mission goal of the block has a server source; an unmapped goal throws', () => {
  for (const m of ECO.seasonPass.missions) assert.ok(SP.SOURCES[m.goal], `${m.missionKey}: ${m.goal}`);
  const bad = { ...ECO.seasonPass, missions: [...ECO.seasonPass.missions, { missionKey: 'x', type: 'daily', goal: 'nope', target: 1, xp: 1 }] };
  assert.throws(() => SP.passConfig({ ...ECO, seasonPass: bad }), /no server source/);
});

test('themes: every nameKey has a name (tri_an_2011 = Tri ân 20/11)', () => {
  for (const t of ECO.seasonPass.themes) assert.ok(SP.THEME_NAMES[t.nameKey], t.nameKey);
  assert.equal(SP.THEME_NAMES.sp_theme_2011_name, 'Tri ân 20/11');
});

test('petItem reward (tier 10 free no_co_vai) goes by mail as a pet item of economy.json petItems', () => {
  const t10 = ECO.seasonPass.tiers[9];
  const r = SP.rewardsOf(t10.free, 'tri_an_2011');
  assert.deepEqual(r.unmapped, []);
  assert.ok(r.items.some((i) => i.kind === 'petItem' && i.id === 'no_co_vai' && i.amount === 1));
  const ids = JSON.stringify(ECO.petItems);
  assert.ok(ids.includes('"no_co_vai"'));
});

test('claim mail: Nhất\'s title/body, rewards joined with " + ", premium tag, expiry mailExpireDays', async () => {
  const d = db({ theme: 'tri_an_2011', xp: sumXp(12), premium: true });
  await SP.claim({ db: d, eco: ECO, uid: UID, now: T0, data: { tier: 10, track: 'free' } });
  const m = d.read(`mails/sp_${UID}_${PERIOD}_free_10`);
  assert.equal(m.title, 'Quà bậc 10 Season Pass đã tới!');
  assert.equal(m.body, `Tiệm mình vừa lên bậc 10 của Tri ân 20/11. Quà gửi kèm thư này: 1 vé quay + Nơ cổ vải. Mở thư để nhận nhé, thư giữ trong ${CFG.mailExpireDays} ngày.`);
  assert.equal(m.tag, undefined);
  assert.equal(m.expiresAt.getTime(), T0.getTime() + CFG.mailExpireDays * 86400000);
  await SP.claim({ db: d, eco: ECO, uid: UID, now: T0, data: { tier: 12, track: 'premium' } });
  const p = d.read(`mails/sp_${UID}_${PERIOD}_premium_12`);
  assert.equal(p.tag, 'Quà nhánh cao cấp');
  assert.match(p.body, /Quà gửi kèm thư này: 30 Pha lê\./);
  for (const t of ECO.seasonPass.tiers) {
    for (const tr of ['free', 'premium']) {
      const r = SP.rewardsOf(t[tr], 'tet');
      assert.deepEqual(r.unmapped, [], `tier ${t.tier} ${tr}`);
      if (r.items.length) SP.claimMailText(t.tier, tr, 'x', r.items, 7);
    }
  }
});
