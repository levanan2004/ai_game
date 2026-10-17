'use strict';
// Khung avatar (spec 3). Pure logic: Firestore and the clock are passed in
// (avatar_frames.test.js runs it on fake_firestore.js); index.js wires the
// callables avatarFrameList and avatarFrameEquip.
//
//   player_avatars/{uid}.frame   the equipped frame id ('' or missing = none).
//                                Written ONLY here: the rules let the player
//                                write path/rev but never change frame, so a
//                                frame other players see is always one this
//                                check allowed.
//   wallets/{uid}.frames         [id] frames the server granted (event,
//                                season top). Nothing grants yet.
//   wallets/{uid}.vipLevel       the VIP level once VIP exists (task 6).
//                                Missing = 0: every VIP frame stays locked.
//
// Which frames exist and how each opens comes from economy.json
// `avatarFrames` (and `vip.tiers[].frame` for the VIP level of a frame).

class FrameError extends Error {
  constructor(code) { super(code); this.code = code; }
}

const SOURCES = ['default', 'vip', 'event', 'seasonTop', 'buy'];
const ID = /^[a-z0-9_]{1,40}$/;

/** economy.json avatarFrames + the lowest VIP level of each VIP frame. */
function framesConfig(eco) {
  const block = eco && eco.avatarFrames;
  const list = block && Array.isArray(block.frames) ? block.frames : [];
  const vipAt = {};
  const tiers = eco && eco.vip && Array.isArray(eco.vip.tiers) ? eco.vip.tiers : [];
  for (const t of tiers) {
    if (!t || typeof t.frame !== 'string' || !t.frame) continue;
    const level = Math.floor(Number(t.level) || 0);
    if (level > 0 && (vipAt[t.frame] == null || level < vipAt[t.frame])) vipAt[t.frame] = level;
  }
  const frames = [];
  for (const f of list) {
    if (!f || typeof f.id !== 'string' || !ID.test(f.id)) continue;
    const source = SOURCES.includes(f.source) ? f.source : 'event';
    frames.push({ id: f.id, source, vipLevel: source === 'vip' ? (vipAt[f.id] || null) : null });
  }
  return frames;
}

const int = (v) => (Number.isFinite(Number(v)) ? Math.max(0, Math.floor(Number(v))) : 0);

/** The frame ids this wallet may wear, in economy.json order. */
function ownedFrames(eco, wallet) {
  const w = wallet || {};
  const vip = int(w.vipLevel);
  const granted = new Set(Array.isArray(w.frames) ? w.frames.filter((x) => typeof x === 'string') : []);
  return framesConfig(eco)
    .filter((f) => f.source === 'default'
      || (f.source === 'vip' && f.vipLevel != null && vip >= f.vipLevel)
      || granted.has(f.id))
    .map((f) => f.id);
}

async function walletOf(db, uid) {
  const snap = await db.doc(`wallets/${uid}`).get();
  return snap.exists ? snap.data() : {};
}

/** What this player owns, what they wear and their VIP level. */
async function list({ db, eco, uid }) {
  const wallet = await walletOf(db, uid);
  const avatar = await db.doc(`player_avatars/${uid}`).get();
  const worn = avatar.exists && typeof avatar.data().frame === 'string' ? avatar.data().frame : '';
  const owned = ownedFrames(eco, wallet);
  return { owned, equipped: owned.includes(worn) ? worn : '', vipLevel: int(wallet.vipLevel) };
}

/**
 * Wears [data.frameId] ('' takes the frame off). Refused: an id economy.json
 * does not list ('unknown'), one this player does not own ('not_owned').
 */
async function equip({ db, eco, uid, data, now }) {
  const id = data && typeof data.frameId === 'string' ? data.frameId : null;
  if (id === null) throw new FrameError('bad');
  if (id !== '') {
    if (!framesConfig(eco).some((f) => f.id === id)) throw new FrameError('unknown');
    if (!ownedFrames(eco, await walletOf(db, uid)).includes(id)) throw new FrameError('not_owned');
  }
  await db.doc(`player_avatars/${uid}`).set({ frame: id, frameAt: now }, { merge: true });
  return { equipped: id };
}

/**
 * The frame a message or card may show for [uid]: the stored one if
 * economy.json still lists it, else ''. Ownership was checked when it was
 * worn (equip); a frame lost later (VIP drop, task 6) is taken off there.
 */
function frameFromAvatarDoc(eco, data) {
  const id = data && typeof data.frame === 'string' ? data.frame : '';
  return id && framesConfig(eco).some((f) => f.id === id) ? id : '';
}

module.exports = { FrameError, framesConfig, ownedFrames, list, equip, frameFromAvatarDoc };
