'use strict';
// Khung tin nhắn (chat bubble frames), economy.json `chatBubbleFrames`.
//
//   player_avatars/{uid}.chatFrame      the frame the player chose (callable
//                                       chatFrameEquip; server-written).
//   player_avatars/{uid}.chatFrameBase  the last chosen frame that is not a
//                                       title frame: where a lost title frame
//                                       goes back to ("khung trước đó").
//   player_avatars/{uid}.chatFrameLost  titleId whose frame was taken off
//                                       when the title moved on (titles.js);
//                                       the app shows chat_frame.lost_title_note
//                                       until the next equip clears it.
//   world_chat/{id}.bubble              the frame a message is drawn in, worked
//                                       out HERE at send time (absent = default).
//
// Rules (block v2): VIP n frames open at vipMax >= n and stay after a VIP
// drop; "Ẩn huy hiệu VIP" shows VIP frames as the default one; title frames
// only while holding the title.

class ChatFrameError extends Error {
  constructor(code) { super(code); this.code = code; }
}

function chatFramesConfig(eco) {
  const c = (eco && eco.chatBubbleFrames) || {};
  const frames = (Array.isArray(c.frames) ? c.frames : [])
    .filter((f) => f && typeof f.id === 'string' && f.id)
    .map((f) => ({
      id: f.id,
      vip: Number.isInteger(f.vip) && f.vip > 0 ? f.vip : 0,
      title: typeof f.title === 'string' ? f.title : '',
    }));
  const def = typeof c.default === 'string' && frames.some((f) => f.id === c.default)
    ? c.default : (frames[0] ? frames[0].id : '');
  return { frames, default: def };
}

/** The frame [id] of [cfg], or null. */
const byId = (cfg, id) => cfg.frames.find((f) => f.id === id) || null;

/**
 * The frame [uid]'s next message shows. [avatar] = player_avatars doc data,
 * [holds(titleId)] / [badgeHidden] as the server knows them now.
 */
function effectiveFrame(cfg, avatar, { holds = () => false, badgeHidden = false } = {}) {
  const pick = (id) => {
    const f = byId(cfg, id);
    return f && !f.title ? f : null;
  };
  let f = byId(cfg, avatar && avatar.chatFrame);
  if (f && f.title && !holds(f.title)) f = pick(avatar && avatar.chatFrameBase);
  if (!f) f = byId(cfg, cfg.default);
  if (!f) return '';
  if (f.vip && badgeHidden) return cfg.default;
  return f.id;
}

async function equip({ db, eco, uid, data, now }) {
  const cfg = chatFramesConfig(eco);
  const id = data && typeof data.frameId === 'string' ? data.frameId : '';
  const f = byId(cfg, id);
  if (!f) throw new ChatFrameError('unknown');
  if (f.vip) {
    const w = await db.doc(`wallets/${uid}`).get();
    const max = Math.floor(Number(w.exists && w.data().vipMax) || 0);
    if (max < f.vip) throw new ChatFrameError('locked');
  }
  if (f.title) {
    const t = await db.doc(`titles/${f.title}`).get();
    if (!t.exists || t.data().holderUid !== uid) throw new ChatFrameError('not_held');
  }
  await db.doc(`player_avatars/${uid}`).set({
    chatFrame: id,
    ...(f.title ? {} : { chatFrameBase: id }),
    chatFrameLost: null,
    chatFrameAt: now,
  }, { merge: true });
  return { equipped: id };
}

/**
 * In the transaction that moves [titleId] away from [uid]: when that title's
 * frame is chosen, go back to the base frame and leave the note flag.
 * [cfg] = chatFramesConfig(eco). Firestore transactions read before they
 * write: call read() with the other reads, write() with the writes.
 */
function onTitleLost(cfg, tx, db, uid, titleId) {
  const f = cfg.frames.find((x) => x.title === titleId);
  const ref = db.doc(`player_avatars/${uid}`);
  let snap = null;
  return {
    read: async () => { if (f) snap = await tx.get(ref); },
    write: () => {
      if (!f || !snap || !snap.exists || snap.data().chatFrame !== f.id) return false;
      const base = byId(cfg, snap.data().chatFrameBase);
      tx.set(ref, {
        chatFrame: base && !base.title ? base.id : cfg.default,
        chatFrameLost: titleId,
      }, { merge: true });
      return true;
    },
  };
}

module.exports = { ChatFrameError, chatFramesConfig, byId, effectiveFrame, equip, onTitleLost };
