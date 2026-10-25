'use strict';
// Khung tin nhắn (chat_frames.js): equip checks, the frame a message shows,
// back to the frame chosen before when a title moves on.
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const CF = require('./chat_frames');
const T = require('./titles');
const chat = require('./world_chat');
const { defaultFilter, defaultWordList } = require('./word_filter');

const ECO = require('./economy.json');
const NOW = new Date('2026-12-07T00:10:00Z');
const CFG = CF.chatFramesConfig(ECO);

const fails = async (p, code) => {
  try { await p; } catch (e) { assert.ok(e instanceof CF.ChatFrameError, e && e.stack); assert.equal(e.code, code); return; }
  assert.fail('should fail');
};

test('economy.json chatBubbleFrames: 6 frames, block v2 ids, VIP 5/7/9, two titles', () => {
  assert.deepEqual(CFG.frames, [
    { id: 'chat_thuong', vip: 0, title: '' },
    { id: 'chat_vip_bac', vip: 5, title: '' },
    { id: 'chat_vip_vang', vip: 7, title: '' },
    { id: 'chat_vip_ngoc', vip: 9, title: '' },
    { id: 'chat_de_nhat_goi_hoa', vip: 0, title: 'de_nhat_goi_hoa' },
    { id: 'chat_mi_luc_nhat_troi', vip: 0, title: 'mi_luc_nhat_troi' },
  ]);
  assert.equal(CFG.default, 'chat_thuong');
  assert.match(ECO.chatBubbleFrames.vipDowngrade, /vẫn giữ khung đã mở/);
});

test('effectiveFrame: title only while held, else the base; VIP hidden = default', () => {
  const a = { chatFrame: 'chat_de_nhat_goi_hoa', chatFrameBase: 'chat_vip_vang' };
  assert.equal(CF.effectiveFrame(CFG, a, { holds: (t) => t === 'de_nhat_goi_hoa' }), 'chat_de_nhat_goi_hoa');
  assert.equal(CF.effectiveFrame(CFG, a, { holds: () => false }), 'chat_vip_vang');
  assert.equal(CF.effectiveFrame(CFG, a, { holds: () => false, badgeHidden: true }), 'chat_thuong');
  assert.equal(CF.effectiveFrame(CFG, a, { holds: () => true, badgeHidden: true }), 'chat_de_nhat_goi_hoa',
    'hiding the VIP badge keeps a title frame');
  assert.equal(CF.effectiveFrame(CFG, { chatFrame: 'nope' }), 'chat_thuong');
  assert.equal(CF.effectiveFrame(CFG, null), 'chat_thuong');
  assert.equal(CF.effectiveFrame(CFG, { chatFrame: 'chat_mi_luc_nhat_troi', chatFrameBase: 'chat_de_nhat_goi_hoa' }), 'chat_thuong',
    'a base is never a title frame');
});

test('equip: VIP by vipMax (kept after a drop), titles only while holding', async () => {
  const db = new FakeFirestore();
  db.seed('wallets/u', { vipLevel: 3, vipMax: 7 });
  db.seed('titles/de_nhat_goi_hoa', { holderUid: 'u' });
  db.seed('titles/mi_luc_nhat_troi', { holderUid: 'x' });
  const eq = (frameId) => CF.equip({ db, eco: ECO, uid: 'u', data: { frameId }, now: NOW });
  assert.deepEqual(await eq('chat_vip_vang'), { equipped: 'chat_vip_vang' });
  let a = db.docs.get('player_avatars/u');
  assert.equal(a.chatFrame, 'chat_vip_vang');
  assert.equal(a.chatFrameBase, 'chat_vip_vang');
  await fails(eq('chat_vip_ngoc'), 'locked');
  await fails(eq('chat_mi_luc_nhat_troi'), 'not_held');
  await fails(eq('khung_la'), 'unknown');
  await fails(eq(''), 'unknown');
  await eq('chat_de_nhat_goi_hoa');
  a = db.docs.get('player_avatars/u');
  assert.equal(a.chatFrame, 'chat_de_nhat_goi_hoa');
  assert.equal(a.chatFrameBase, 'chat_vip_vang', 'a title frame keeps the base');
  await fails(CF.equip({ db, eco: ECO, uid: 'nobody', data: { frameId: 'chat_vip_bac' }, now: NOW }), 'locked');
  assert.deepEqual(await CF.equip({ db, eco: ECO, uid: 'nobody', data: { frameId: 'chat_thuong' }, now: NOW }),
    { equipped: 'chat_thuong' });
});

test('title moves on: the old holder\'s title frame goes back to the base, with the note', async () => {
  const db = new FakeFirestore();
  const RT = T.titleConfig(ECO, 'review');
  await T.transferTitle(db, RT, { uid: 'a', period: 'rating-1', seasonEnd: NOW, now: NOW });
  db.seed('player_avatars/a', { path: 'p', rev: 1, chatFrame: 'chat_de_nhat_goi_hoa', chatFrameBase: 'chat_vip_bac' });
  await T.transferTitle(db, RT, { uid: 'b', period: 'rating-2', seasonEnd: NOW, now: NOW });
  const a = db.docs.get('player_avatars/a');
  assert.equal(a.chatFrame, 'chat_vip_bac');
  assert.equal(a.chatFrameLost, 'de_nhat_goi_hoa');
  assert.equal(a.path, 'p', 'the portrait stays');
  // Someone wearing another frame is left alone.
  db.seed('player_avatars/b', { path: 'q', rev: 1, chatFrame: 'chat_vip_ngoc' });
  await T.transferTitle(db, RT, { uid: 'c', period: 'rating-3', seasonEnd: NOW, now: NOW });
  assert.equal(db.docs.get('player_avatars/b').chatFrame, 'chat_vip_ngoc');
  assert.equal(db.docs.get('player_avatars/b').chatFrameLost, undefined);
  // The next equip clears the note.
  db.seed('wallets/a', { vipMax: 5 });
  await CF.equip({ db, eco: ECO, uid: 'a', data: { frameId: 'chat_thuong' }, now: NOW });
  assert.equal(db.docs.get('player_avatars/a').chatFrameLost, null);
});

test('world chat stamps the frame worked out at send time', async () => {
  const db = new FakeFirestore();
  db.seed('config/worldChat', { enabled: true });
  db.seed('users/u1', { progress: { day: 9, shopName: 'Tiệm Mai' } });
  db.seed('titles/mi_luc_nhat_troi', { holderUid: 'u1' });
  db.seed('player_avatars/u1', { chatFrame: 'chat_mi_luc_nhat_troi', chatFrameBase: 'chat_vip_ngoc' });
  db.seed('wallets/u1', { vipMax: 9, vipBadgeHidden: false });
  let t = 0;
  const send = (text) => chat.send({
    db, eco: ECO, uid: 'u1', now: new Date(NOW.getTime() + (t += 120000)),
    data: { text }, filter: defaultFilter(), words: defaultWordList(),
  });
  const last = () => [...db.docs.entries()].filter(([k]) => k.startsWith('world_chat/')).sort().pop()[1];
  await send('chào cả nhà');
  assert.equal(last().bubble, 'chat_mi_luc_nhat_troi');
  db.seed('titles/mi_luc_nhat_troi', { holderUid: 'x' });
  await send('mình mất danh hiệu rồi');
  assert.equal(last().bubble, 'chat_vip_ngoc');
  db.seed('wallets/u1', { vipMax: 9, vipBadgeHidden: true });
  await send('ẩn huy hiệu nè');
  assert.equal(last().bubble, undefined, 'hidden VIP: the default, not stamped');
  db.seed('player_avatars/u1', {});
  await send('khung thường');
  assert.equal(last().bubble, undefined);
});
