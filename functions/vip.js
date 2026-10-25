'use strict';
// VIP, 10 tiers (spec 4, economy.json `vip`). Written ONLY by the functions:
//
//   wallets/{uid}            vipLevel   current tier (0..10)
//                            vipVnd     total VND topped up, refunds taken off
//                                       (owner-readable only, never public)
//                            vipMax     highest tier ever reached
//                            vipAt      when the current tier was reached
//                            vipGifted  {level: mailId} gift mails sent (once
//                                       per tier ever: a drop and a second
//                                       climb gives nothing again)
//                            vipHallHidden  "Ẩn tên khỏi Bảng vinh danh"
//                            vipVersion / vipCheckedAt
//   player_avatars/{uid}     vip, vipAt   the public tier (badge, name colour,
//                                         title) other players read
//   vip_hall/{uid}           only while VIP 10: at (when reached), name,
//                            avatar, hidden. Never an amount.
//   mails/vip_{uid}_{k}      the one-time Thẻ gacha gift of tier k, claimed
//                            through walletClaimMail (wallet.js); its cards are
//                            for the pot of the week the mail was sent
//                            (ticketPot set here).
//   mails/vip_down_{uid}_{t} the notice after a refund lowered the tier.
//
// The total: paid bank orders (phale_orders status 'paid', `amount`, the VND
// received = the pack price) + App Store purchases not refunded
// (phale_iap.packPriceVnd, the VND list price), sandbox rows excluded (not real
// money, economy.json vip._note). Gift / ad / login Pha lê never count.
// Recomputed on every write of those docs (index.js triggers), on the first
// walletSync after VERSION changes (backfill) and by the admin (vipRecompute).

const G = require('./gacha');
const F = require('./avatar_frames');

/** Bump to make every wallet recompute on its next walletSync. */
const VERSION = 1;
const HALL_LEVEL = 10;
const SUPPORT_EMAIL = 'anxaitech@gmail.com';
const NAME_MAX = 24;

// `ticket.name.<pot id>` (Nhất, chu_tinh_nang_moi.md), for {ticket_name}.
const TICKET_NAMES = {
  chau_cuu_vi_ho: 'Thẻ gacha Cửu Vĩ Hồ',
  chau_chuc_long: 'Thẻ gacha Chúc Long',
  chau_con_bang: 'Thẻ gacha Côn Bằng',
  chau_bach_trach: 'Thẻ gacha Bạch Trạch',
  chau_thao_thiet: 'Thẻ gacha Thao Thiết',
  chau_cung_ky: 'Thẻ gacha Cùng Kỳ',
  chau_hon_don: 'Thẻ gacha Hỗn Độn',
  chau_dao_ngot: 'Thẻ gacha Đào Ngột',
  chau_tat_phuong: 'Thẻ gacha Tất Phương',
  chau_tinh_ve: 'Thẻ gacha Tinh Vệ',
  chau_de_giang: 'Thẻ gacha Đế Giang',
  chau_ky_lan: 'Thẻ gacha Kỳ lân xanh',
};

class VipError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}

const int = (v) => Math.max(0, Math.floor(Number(v) || 0));

/** economy.json vip.tiers, by level. */
function tiers(eco) {
  const list = (eco && eco.vip && Array.isArray(eco.vip.tiers)) ? eco.vip.tiers : [];
  return list
    .map((t) => ({ level: int(t.level), minVnd: int(t.minVnd), giftTickets: int(t.giftTickets), frame: t.frame || null }))
    .filter((t) => t.level > 0)
    .sort((a, b) => a.level - b.level);
}

/** The tier of [vnd] topped up (0 below VIP 1). */
function levelFor(eco, vnd) {
  let level = 0;
  for (const t of tiers(eco)) if (int(vnd) >= t.minVnd) level = t.level;
  return level;
}

/** Real money: Production rows (and rows from before `environment` was kept). */
const realMoney = (r) => r.environment == null || r.environment === 'Production';

/** Total VND [uid] topped up, refunds taken off (see the header). */
async function paidVnd(tx, db, uid) {
  const orders = await tx.get(db.collection('phale_orders').where('uid', '==', uid));
  const iap = await tx.get(db.collection('phale_iap').where('uid', '==', uid));
  let vnd = 0;
  for (const d of orders.docs) {
    const o = d.data() || {};
    if (o.status === 'paid' && !o.refundedAt) vnd += int(o.amount);
  }
  for (const d of iap.docs) {
    const r = d.data() || {};
    if (!r.refundedAt && !r.uncredited && realMoney(r)) vnd += int(r.packPriceVnd);
  }
  return vnd;
}

const badge = (k) => `VIP ${k}`;

/** `vip.levelup.mail_title` / `vip.levelup.mail_body`. */
function giftMail({ uid, level, tickets, potId, now }) {
  const ticketName = TICKET_NAMES[potId] || 'Thẻ gacha';
  return {
    title: `Quà lên ${badge(level)}`,
    body: `Chúc mừng tiệm của bạn lên ${badge(level)}. Đây là quà một lần ${tickets} Thẻ gacha, `
      + `Tiệm gửi tặng. Thẻ là ${ticketName}, thẻ của chậu Sơn Hải tuần thư này được gửi tới, `
      + 'dùng ở Vòng quay tuần khi chậu đó có mặt.',
    target: uid,
    rewards: { items: [{ kind: 'ticket', amount: tickets }] },
    walletClaim: true, // claimed through walletClaimMail (wallet.js)
    ...(potId ? { ticketPot: potId } : {}),
    vipLevel: level,
    createdAt: now,
  };
}

/** `vip.down.mail_title` / `vip.down.mail_body`. */
function downMail({ uid, level, vnd, now }) {
  return {
    title: 'Cấp VIP của bạn đã đổi',
    body: `Một đơn nạp đã được hoàn tiền nên tổng đã nạp giảm còn ${vnd.toLocaleString('de-DE')}đ. `
      + `Cấp VIP hiện tại: ${level > 0 ? badge(level) : 'VIP 0'}. Quà lên cấp bạn đã nhận vẫn được giữ. `
      + 'Đồ VIP của cấp cao hơn tạm khóa cho tới khi bạn lên lại. '
      + `Cần hỏi thêm thì email ${SUPPORT_EMAIL}.`,
    target: uid,
    vipLevel: level,
    createdAt: now,
  };
}

function cleanName(filter, raw) {
  const runes = Array.from(String(raw || '').trim()).slice(0, NAME_MAX).join('').trim();
  if (!runes) return '';
  if (filter && typeof filter.allowsShopName === 'function' && !filter.allowsShopName(runes)) return '';
  return runes;
}

function cleanAvatar(raw) {
  return typeof raw === 'string' && raw.length <= 500 && !/\s/.test(raw) ? raw : '';
}

/** What the app shows the owner (walletSync / vipRecompute answers). */
/**
 * VIP pots (economy.json vip.vipPots, Chậu Ngọc Bích VIP 3, Chậu Hoàng Kim
 * VIP 6) owned at [level]: like the VIP frames, they come only from the
 * server's tier, never from the save's potCounts.
 */
function ownedVipPots(eco, level) {
  const pots = (eco && eco.vip && eco.vip.vipPots) || {};
  const known = new Set(((eco && eco.pots) || []).map((p) => p && p.id));
  return Object.keys(pots).filter((id) => {
    const at = int(pots[id] && pots[id].level);
    return at > 0 && int(level) >= at && known.has(id);
  });
}

function vipView(eco, w) {
  const level = int(w && w.vipLevel);
  const vnd = int(w && w.vipVnd);
  const next = tiers(eco).find((t) => t.level === level + 1) || null;
  return {
    level,
    vnd,
    max: int(w && w.vipMax),
    nextVnd: next ? next.minVnd : null,
    hallHidden: !!(w && w.vipHallHidden),
    badgeHidden: !!(w && w.vipBadgeHidden),
    pots: ownedVipPots(eco, level),
  };
}

/**
 * Recomputes [uid]'s tier in one transaction and writes what changed:
 * wallet fields, the public tier, the hall row, a gift mail for each tier
 * reached for the first time, a notice when a refund lowered it.
 */
async function recompute({ db, eco, uid, now, filter }) {
  if (!uid || typeof uid !== 'string' || uid.includes('/')) throw new VipError('bad');
  return db.runTransaction(async (tx) => {
    const walletRef = db.doc(`wallets/${uid}`);
    const avatarRef = db.doc(`player_avatars/${uid}`);
    const hallRef = db.doc(`vip_hall/${uid}`);
    const userRef = db.doc(`users/${uid}`);
    const walletSnap = await tx.get(walletRef);
    const avatarSnap = await tx.get(avatarRef);
    const hallSnap = await tx.get(hallRef);
    const userSnap = await tx.get(userRef);
    const vnd = await paidVnd(tx, db, uid);
    const w = walletSnap.exists ? walletSnap.data() : {};
    const prev = int(w.vipLevel);
    // A deleted account (records stay for the admin): nothing to write.
    if (!userSnap.exists) return { prev, ...vipView(eco, w), sent: [], skipped: 'no-user' };
    const level = levelFor(eco, vnd);
    const gifted = { ...(w.vipGifted || {}) };
    const week = G.weekAt(eco, now);
    // Before the first week the gift is a card of the first pot.
    const potId = week.potId || week.nextPotId || null;
    const sent = [];
    for (const t of tiers(eco)) {
      if (t.level > level || gifted[t.level] || t.giftTickets <= 0) continue;
      const mailId = `vip_${uid}_${t.level}`;
      tx.set(db.doc(`mails/${mailId}`), giftMail({ uid, level: t.level, tickets: t.giftTickets, potId, now }));
      gifted[t.level] = mailId;
      sent.push(t.level);
    }
    if (level < prev) {
      tx.set(db.doc(`mails/vip_down_${uid}_${now.getTime()}`), downMail({ uid, level, vnd, now }));
    }
    const at = level === prev && w.vipAt ? w.vipAt : (level > 0 ? now : null);
    const fields = {
      vipLevel: level,
      vipVnd: vnd,
      vipMax: Math.max(int(w.vipMax), level),
      vipAt: at,
      vipGifted: gifted,
      vipVersion: VERSION,
      vipCheckedAt: now,
    };
    tx.set(walletRef, fields, { merge: true });

    const pub = avatarSnap.exists ? avatarSnap.data() : {};
    const patch = {};
    // "Ẩn huy hiệu VIP": others see no tier (no badge, no name colour, no
    // title, no VIP in chat). The tier and its perks stay in the wallet.
    const badgeHidden = !!w.vipBadgeHidden;
    const shown = badgeHidden ? 0 : level;
    const shownAt = shown > 0 ? at : null;
    if (int(pub.vip) !== shown || (shown > 0 && !pub.vipAt) || (shown === 0 && pub.vipAt)) {
      patch.vip = shown;
      patch.vipAt = shownAt;
    }
    // A VIP frame of a tier no longer held comes off (it stays listed,
    // locked, until the tier is back).
    const worn = typeof pub.frame === 'string' ? pub.frame : '';
    if (worn && F.framesConfig(eco).some((f) => f.id === worn && f.source === 'vip')
      && !F.ownedFrames(eco, { ...w, vipLevel: level }).includes(worn)) {
      patch.frame = '';
      patch.frameAt = now;
    }
    // Only these fields: path and rev stay as they are (merge).
    if (Object.keys(patch).length) tx.set(avatarRef, patch, { merge: true });

    if (level >= HALL_LEVEL) {
      const progress = (userSnap.data().progress) || {};
      const old = hallSnap.exists ? hallSnap.data() : null;
      // Hidden badge: the hall shows "Chủ tiệm ẩn danh" too.
      const hidden = !!w.vipHallHidden || badgeHidden;
      // A second climb to VIP 10 enters with the new date (spec 4.6).
      const hallAt = old && prev >= HALL_LEVEL && old.at ? old.at : now;
      tx.set(hallRef, {
        at: hallAt,
        hidden,
        name: hidden ? '' : cleanName(filter, progress.shopName),
        avatar: hidden ? '' : cleanAvatar(pub.path),
        updatedAt: now,
      });
    } else if (hallSnap.exists) {
      tx.delete(hallRef);
    }
    return { prev, ...vipView(eco, { ...w, ...fields }), sent };
  });
}

/** "Ẩn tên khỏi Bảng vinh danh" (spec 4.4 Cài đặt VIP): the owner's switch. */
async function setHallHidden({ db, eco, uid, now, data, filter }) {
  const hidden = data && data.hidden;
  if (typeof hidden !== 'boolean') throw new VipError('bad');
  await db.runTransaction(async (tx) => {
    const ref = db.doc(`wallets/${uid}`);
    await tx.get(ref);
    tx.set(ref, { vipHallHidden: hidden, updatedAt: now }, { merge: true });
  });
  // Rewrites the hall row (name / avatar on or off).
  return recompute({ db, eco, uid, now, filter });
}

/**
 * "Ẩn huy hiệu VIP" (Cài đặt VIP; Hà Phương for An 17/10): the owner's switch.
 * On: the public tier (player_avatars.vip) reads 0 and the hall row is
 * anonymous; the tier, its perks and the VIP screen are unchanged.
 */
async function setBadgeHidden({ db, eco, uid, now, data, filter }) {
  const hidden = data && data.hidden;
  if (typeof hidden !== 'boolean') throw new VipError('bad');
  await db.runTransaction(async (tx) => {
    const ref = db.doc(`wallets/${uid}`);
    await tx.get(ref);
    tx.set(ref, { vipBadgeHidden: hidden, updatedAt: now }, { merge: true });
  });
  return recompute({ db, eco, uid, now, filter });
}

/** Every uid with a top-up record (the admin's "recompute all"). */
async function payerUids(db) {
  const uids = new Set();
  for (const name of ['phale_orders', 'phale_iap']) {
    const snap = await db.collection(name).get();
    for (const d of snap.docs) {
      const u = d.data() && d.data().uid;
      if (typeof u === 'string' && u) uids.add(u);
    }
  }
  return [...uids].sort();
}

/**
 * The admin button: data.uid recomputes one player, data.all every payer.
 * [isAdmin] is index.js's owner / admins/{uid} check.
 */
async function adminRecompute({ db, eco, uid, now, data, filter, isAdmin }) {
  if (!(await isAdmin(uid))) throw new VipError('not-admin');
  const target = data && data.uid;
  if (typeof target === 'string' && target) {
    const r = await recompute({ db, eco, uid: target, now, filter });
    return { count: 1, changed: r.prev !== r.level ? 1 : 0, results: { [target]: r.level } };
  }
  if (!(data && data.all === true)) throw new VipError('bad');
  const results = {};
  let changed = 0;
  for (const u of await payerUids(db)) {
    const r = await recompute({ db, eco, uid: u, now, filter });
    results[u] = r.level;
    if (r.prev !== r.level) changed++;
  }
  return { count: Object.keys(results).length, changed, results };
}

/** The uids a phale_orders / phale_iap write concerns, if it can change a total. */
function touchedUids(before, after) {
  const pick = (d) => (d ? {
    uid: d.uid || null, status: d.status || null, amount: d.amount || null,
    refundedAt: !!d.refundedAt, uncredited: !!d.uncredited, price: d.packPriceVnd || null,
    env: d.environment || null,
  } : null);
  const a = pick(before);
  const b = pick(after);
  if (JSON.stringify(a) === JSON.stringify(b)) return [];
  return [...new Set([a && a.uid, b && b.uid].filter(Boolean))];
}

module.exports = {
  VERSION, HALL_LEVEL, TICKET_NAMES, VipError, tiers, levelFor, paidVnd, giftMail, downMail,
  vipView, ownedVipPots, recompute, setHallHidden, setBadgeHidden, adminRecompute, payerUids,
  touchedUids,
};
