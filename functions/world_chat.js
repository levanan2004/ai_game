'use strict';
// Tin thế giới (world chat). Pure logic: Firestore, the clock and the word
// filter are passed in (world_chat.test.js runs it on fake_firestore.js);
// index.js wires the callables worldChatSend and worldChatReport.
//
//   world_chat/{id}         one message {uid, name, avatar, frame?, text,
//                           seq, createdAt, official?}. frame is copied from
//                           player_avatars/{uid}.frame (server-written, see
//                           avatar_frames.js), never from the app. bubble =
//                           the chat frame (chat_frames.js effectiveFrame at
//                           send time; absent = the default). Everyone reads (rules);
//                           only these functions write; admins may delete.
//   world_chat_meta/state   {seq}: the running message number. Server only.
//   world_chat_state/{uid}  cooldown + duplicate memory. Server only.
//   chat_mutes/{uid}        {level, at, by, reason, messageId}: written by
//                           an admin in /quan-tri (rules, at = request.time).
//                           The end is worked out HERE from economy.json
//                           muteLevels (at + minutes), so the app cannot
//                           shorten a mute; ban never ends.
//   chat_reports/{reporter}_{messageId}  a report with a snapshot of the
//                           message and its neighbours. Admins read.
//   config/worldChat        {enabled}: the remote switch. Missing or not
//                           true = OFF (the app hides the chat, sends fail).
//
// Every number comes from economy.json `worldChat`.

const { frameFromAvatarDoc } = require('./avatar_frames');
const { chatFramesConfig, effectiveFrame, byId } = require('./chat_frames');

/** player_avatars/{uid}.vip (1..10, vip.js), 0 for none. */
function vipFromAvatarDoc(data) {
  const v = Math.floor(Number(data && data.vip) || 0);
  return v >= 1 && v <= 10 ? v : 0;
}
const { publicProfile } = require('./public_profile');

class ChatError extends Error {
  constructor(code, extra = {}) { super(code); this.code = code; this.extra = extra; }
}

const REASONS = ['profane', 'harassment', 'scam', 'adult', 'spam', 'other'];
const LINK_GROUP = 'lien_he_duong_dan';
const FALLBACK_NAME = 'Chủ tiệm'; // lib/data/charm_board.dart charmBoardFallbackName
const NAME_MAX = 40;

function cfg(eco) {
  const c = (eco && eco.worldChat) || {};
  const n = (k) => {
    const v = Number(c[k]);
    if (!Number.isInteger(v) || v <= 0) throw new Error(`economy.json worldChat.${k}`);
    return v;
  };
  return {
    unlockDay: n('unlockDay'),
    maxChars: n('maxChars'),
    cooldownMs: n('cooldownSeconds') * 1000,
    duplicateMs: n('duplicateWindowSeconds') * 1000,
    keep: n('keepLatest'),
    noteMax: n('reportNoteMax'),
    context: n('reportContext'),
    muteLevels: Array.isArray(c.muteLevels) ? c.muteLevels : [],
  };
}

/** Unicode characters (an accented letter counts 1), like the app's counter. */
const charCount = (s) => Array.from(s.normalize('NFC')).length;

/** Text as compared for "the same message": trimmed, spaces folded, lower case. */
const sameKey = (s) => s.normalize('NFC').trim().replace(/\s+/g, ' ').toLowerCase();

/** Ids of the tu_cam.json entries in the contact/link group (worldchat.filter.blocked_link). */
function linkIds(words) {
  const out = new Set();
  for (const g of (words && words.nhom) || []) {
    if (g.id !== LINK_GROUP) continue;
    for (const m of g.muc || []) out.add(m.id);
  }
  return out;
}

/**
 * Runs the filter. Any `chặn` entry: refused ('blocked', or 'blocked_link'
 * for contacts and links). Only `che` entries: the words that hit are
 * replaced by *** (spec 5.1) and the message goes out with masked = true;
 * when masking word by word cannot clear it, it is refused.
 */
function screen(filter, links, text) {
  const hits = filter.hits(text);
  if (hits.length === 0) return { text, masked: false };
  const blocked = hits.filter((h) => h.block);
  if (blocked.length) {
    throw new ChatError(blocked.some((h) => links.has(h.id)) ? 'blocked_link' : 'blocked');
  }
  const masked = text.split(/(\s+)/).map((t) => (/\S/.test(t) && filter.hits(t).length ? '***' : t)).join('');
  if (filter.hits(masked).length) throw new ChatError('blocked');
  return { text: masked, masked: true };
}

const toDate = (v) => {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof v.toDate === 'function') return v.toDate();
  if (typeof v === 'number') return new Date(v);
  return null;
};

async function enabled(db) {
  const snap = await db.doc('config/worldChat').get();
  return snap.exists && snap.data().enabled === true;
}

/**
 * The mute in force at [now], or null: chat_mutes doc + muteLevels of
 * economy.json. minutes null = for good (ban); 0 = only a warning.
 */
function activeMute(mute, now, levels) {
  if (!mute) return null;
  const lv = (levels || []).find((l) => l && l.id === mute.level);
  if (!lv) return null;
  if (lv.minutes === null) return { level: mute.level, until: null };
  const from = toDate(mute.at);
  const minutes = Number(lv.minutes);
  if (!from || !(minutes > 0)) return null;
  const until = new Date(from.getTime() + minutes * 60000);
  return until.getTime() > now.getTime() ? { level: mute.level, until } : null;
}

function cleanName(filter, raw) {
  const runes = Array.from(String(raw || '').trim()).slice(0, NAME_MAX).join('').trim();
  if (!runes || !filter.allowsShopName(runes)) return FALLBACK_NAME;
  return runes;
}

function cleanAvatar(raw) {
  return typeof raw === 'string' && raw.length <= 500 && !/\s/.test(raw) ? raw : '';
}

/**
 * Sends one message for [uid]: switch on, signed-in save at game day >=
 * unlockDay (the save's `progress.day`: the only day the server knows, and
 * the app writes it), not muted, not within the cooldown, not the same text
 * as one sent in the duplicate window, at most maxChars, through the filter.
 * Then keeps only the newest keepLatest messages.
 */
async function send({ db, eco, uid, now, data, filter, words, isAdmin = async () => false }) {
  const c = cfg(eco);
  if (!(await enabled(db))) throw new ChatError('disabled');
  const raw = data && typeof data.text === 'string' ? data.text : '';
  const text = raw.normalize('NFC').trim().replace(/[\r\n\t]+/g, ' ');
  if (!text) throw new ChatError('empty');
  if (charCount(text) > c.maxChars) throw new ChatError('too_long', { max: c.maxChars });
  const clean = screen(filter, linkIds(words), text);
  const official = await isAdmin(uid);

  const result = await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(db.doc(`users/${uid}`));
    const progress = (userSnap.exists && userSnap.data().progress) || null;
    if (!progress) throw new ChatError('no_save');
    const day = Math.floor(Number(progress.day) || 0);
    if (day < c.unlockDay) throw new ChatError('locked_day', { unlockDay: c.unlockDay, daysLeft: c.unlockDay - day });
    const muteSnap = await tx.get(db.doc(`chat_mutes/${uid}`));
    const mute = activeMute(muteSnap.exists ? muteSnap.data() : null, now, c.muteLevels);
    if (mute) {
      throw new ChatError(mute.until === null ? 'banned' : 'muted', { until: mute.until ? mute.until.getTime() : null });
    }
    const stateRef = db.doc(`world_chat_state/${uid}`);
    const stateSnap = await tx.get(stateRef);
    const state = stateSnap.exists ? stateSnap.data() : {};
    const last = toDate(state.lastAt);
    if (last && now.getTime() - last.getTime() < c.cooldownMs) {
      const wait = Math.ceil((c.cooldownMs - (now.getTime() - last.getTime())) / 1000);
      throw new ChatError('cooldown', { seconds: wait });
    }
    const key = sameKey(clean.text);
    const recent = (Array.isArray(state.recent) ? state.recent : [])
      .filter((r) => r && now.getTime() - Number(r.at) < c.duplicateMs);
    if (recent.some((r) => r.key === key)) throw new ChatError('duplicate');
    const avatarSnap = await tx.get(db.doc(`player_avatars/${uid}`));
    const frame = frameFromAvatarDoc(eco, avatarSnap.exists ? avatarSnap.data() : null);
    const vip = vipFromAvatarDoc(avatarSnap.exists ? avatarSnap.data() : null);
    const bubble = await bubbleOf(tx, db, eco, uid, avatarSnap.exists ? avatarSnap.data() : null);
    const metaRef = db.doc('world_chat_meta/state');
    const meta = await tx.get(metaRef);
    const seq = Math.floor(Number(meta.exists && meta.data().seq) || 0) + 1;
    const ref = db.collection('world_chat').doc(`m${String(seq).padStart(10, '0')}`);
    const msg = {
      uid,
      name: cleanName(filter, progress.shopName),
      avatar: cleanAvatar(data && data.avatar),
      ...(frame ? { frame } : {}),
      // The public VIP tier (vip.js writes player_avatars.vip), as sent.
      ...(vip ? { vip } : {}),
      ...(bubble ? { bubble } : {}),
      text: clean.text,
      seq,
      createdAt: now,
      ...(official ? { official: true } : {}),
    };
    tx.set(metaRef, { seq, updatedAt: now });
    tx.create(ref, msg);
    tx.set(stateRef, { lastAt: now, recent: [...recent, { key, at: now.getTime() }].slice(-20) });
    tx.set(db.doc(`public_profiles/${uid}`), publicProfile(progress, now), { merge: true });
    return { id: ref.id, seq, msg };
  });
  const trimmed = await trim(db, result.seq - c.keep);
  return {
    id: result.id,
    seq: result.seq,
    text: result.msg.text,
    masked: clean.masked,
    cooldownSeconds: c.cooldownMs / 1000,
    trimmed,
  };
}

/**
 * The chat frame of [uid]'s message: reads titles/{id} only for a chosen
 * title frame and wallets/{uid} only for a VIP one. '' = the default.
 */
async function bubbleOf(tx, db, eco, uid, avatar) {
  const cfg = chatFramesConfig(eco);
  const chosen = byId(cfg, avatar && avatar.chatFrame);
  if (!chosen) return '';
  let holder = '';
  if (chosen.title) {
    const t = await tx.get(db.doc(`titles/${chosen.title}`));
    holder = t.exists ? t.data().holderUid : '';
  }
  const shown = effectiveFrame(cfg, avatar, { holds: () => holder === uid });
  let badgeHidden = false;
  if (byId(cfg, shown) && byId(cfg, shown).vip) {
    const w = await tx.get(db.doc(`wallets/${uid}`));
    badgeHidden = !!(w.exists && w.data().vipBadgeHidden);
  }
  const id = effectiveFrame(cfg, avatar, { holds: () => holder === uid, badgeHidden });
  return id === cfg.default ? '' : id;
}

/** Deletes every message numbered at or below [upTo]. */
async function trim(db, upTo) {
  if (upTo < 1) return 0;
  const old = await db.collection('world_chat').where('seq', '<=', upTo).get();
  for (const d of old.docs) await d.ref.delete();
  return old.docs.length;
}

/**
 * Reports one message: one report per reporter and message, never one's own.
 * The server keeps a copy of the message and up to reportContext neighbours
 * on each side (the original scrolls away fast), for /quan-tri.
 */
async function report({ db, eco, uid, now, data }) {
  const c = cfg(eco);
  const messageId = data && data.messageId;
  if (typeof messageId !== 'string' || !/^m\d{10}$/.test(messageId)) throw new ChatError('bad');
  const reason = data.reason;
  if (!REASONS.includes(reason)) throw new ChatError('bad');
  const note = typeof data.note === 'string' ? data.note.trim() : '';
  if (charCount(note) > c.noteMax) throw new ChatError('bad');
  const snap = await db.doc(`world_chat/${messageId}`).get();
  if (!snap.exists) throw new ChatError('gone');
  const msg = snap.data();
  if (msg.uid === uid) throw new ChatError('self');
  const near = await db.collection('world_chat')
    .where('seq', '>=', msg.seq - c.context)
    .where('seq', '<=', msg.seq + c.context)
    .get();
  const context = near.docs.map((d) => d.data())
    .sort((a, b) => a.seq - b.seq)
    .map((m) => ({ uid: m.uid, name: m.name, text: m.text, seq: m.seq, at: toDate(m.createdAt) }));
  const ref = db.doc(`chat_reports/${uid}_${messageId}`);
  try {
    await ref.create({
      reporterUid: uid,
      targetUid: msg.uid,
      targetName: msg.name || '',
      messageId,
      text: msg.text,
      seq: msg.seq,
      sentAt: toDate(msg.createdAt),
      reason,
      note,
      context,
      status: 'open',
      createdAt: now,
    });
  } catch (e) {
    if (e && (e.code === 6 || e.code === 'already-exists')) throw new ChatError('already');
    throw e;
  }
  return { status: 'sent' };
}

module.exports = {
  ChatError, REASONS, cfg, charCount, sameKey, screen, linkIds, activeMute, send, report, trim,
};
