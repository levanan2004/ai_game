'use strict';
// Khung avatar server rules (avatar_frames.js) on the in-memory Firestore.
// Frames from economy.json `avatarFrames`, VIP levels from `vip.tiers[].frame`.
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const { defaultFilter, defaultWordList } = require('./word_filter');
const F = require('./avatar_frames');
const chat = require('./world_chat');
const { checkEntry } = require('./verify');

const ECO = require('./economy.json');
const T0 = new Date('2026-10-17T03:00:00Z');

async function code(p) {
  try { await p; } catch (e) { assert.ok(e instanceof F.FrameError, e && e.stack); return e.code; }
  assert.fail('expected a refusal');
}

test('economy.json avatarFrames: the 8 frames of spec 3.3, VIP levels from vip.tiers', () => {
  const frames = F.framesConfig(ECO);
  assert.deepEqual(frames.map((f) => f.id), ['la_non', 'hoa_dao', 'vip_la_xanh', 'vip_hoa_dao',
    'vip_bac', 'vip_vang', 'vip_ngoc_luc_bao', 'vuong_mien_mua']);
  const vip = Object.fromEntries(frames.filter((f) => f.source === 'vip').map((f) => [f.id, f.vipLevel]));
  assert.deepEqual(vip, { vip_la_xanh: 1, vip_hoa_dao: 3, vip_bac: 5, vip_vang: 7, vip_ngoc_luc_bao: 9 });
  assert.deepEqual(F.framesConfig({}), []);
});

test('owned: default for everyone, VIP by level (none yet), granted from the wallet', () => {
  assert.deepEqual(F.ownedFrames(ECO, {}), ['la_non']);
  assert.deepEqual(F.ownedFrames(ECO, null), ['la_non']);
  assert.deepEqual(F.ownedFrames(ECO, { vipLevel: 4 }), ['la_non', 'vip_la_xanh', 'vip_hoa_dao']);
  assert.deepEqual(F.ownedFrames(ECO, { frames: ['vuong_mien_mua', 'nope', 3] }), ['la_non', 'vuong_mien_mua']);
});

test('equip: owned frames only, unknown refused, empty takes it off; the app cannot pick', async () => {
  const db = new FakeFirestore();
  db.seed('player_avatars/u1', { path: 'minh_anh', rev: 2 });
  const equip = (frameId, uid = 'u1') => F.equip({ db, eco: ECO, uid, data: { frameId }, now: T0 });
  assert.equal(await code(equip('vip_vang')), 'not_owned');
  assert.equal(await code(equip('hoa_dao')), 'not_owned');
  assert.equal(await code(equip('khung_gia')), 'unknown');
  assert.equal(await code(F.equip({ db, eco: ECO, uid: 'u1', data: {}, now: T0 })), 'bad');
  assert.equal(db.docs.get('player_avatars/u1').frame, undefined);

  assert.deepEqual(await equip('la_non'), { equipped: 'la_non' });
  const doc = db.docs.get('player_avatars/u1');
  assert.equal(doc.frame, 'la_non');
  assert.equal(doc.path, 'minh_anh', 'the portrait stays');
  assert.deepEqual(await F.list({ db, eco: ECO, uid: 'u1' }), { owned: ['la_non'], equipped: 'la_non', vipLevel: 0 });

  db.seed('wallets/u1', { vipLevel: 7 });
  assert.deepEqual(await equip('vip_vang'), { equipped: 'vip_vang' });
  db.seed('wallets/u1', { vipLevel: 0 });
  assert.equal((await F.list({ db, eco: ECO, uid: 'u1' })).equipped, '', 'a frame no longer owned is not reported as worn');

  assert.deepEqual(await equip(''), { equipped: '' });
  assert.equal(db.docs.get('player_avatars/u1').frame, '');
  // A player with no avatar doc yet.
  await equip('la_non', 'u9');
  assert.equal(db.docs.get('player_avatars/u9').frame, 'la_non');
});

test('a chat message carries the frame from player_avatars, never from the app', async () => {
  const db = new FakeFirestore();
  db.seed('config/worldChat', { enabled: true });
  db.seed('users/u1', { progress: { day: 9, shopName: 'Tiệm Mai' } });
  db.seed('player_avatars/u1', { path: 'a.png', rev: 1, frame: 'la_non' });
  const send = (text, data = {}) => chat.send({
    db, eco: ECO, uid: 'u1', now: T0, data: { text, avatar: 'a.png', ...data },
    filter: defaultFilter(), words: defaultWordList(),
  });
  const r = await send('chào cả nhà', { frame: 'vip_ngoc_luc_bao' });
  assert.equal(db.docs.get(`world_chat/${r.id}`).frame, 'la_non');
  assert.deepEqual(db.docs.get('public_profiles/u1'), { day: 9, updatedAt: T0 });

  db.seed('player_avatars/u1', { path: 'a.png', rev: 1, frame: 'khung_cu' });
  const r2 = await chat.send({
    db, eco: ECO, uid: 'u1', now: new Date(T0.getTime() + 20000), data: { text: 'câu khác' },
    filter: defaultFilter(), words: defaultWordList(),
  });
  assert.equal('frame' in db.docs.get(`world_chat/${r2.id}`), false, 'an id economy.json no longer lists is dropped');
});

test('the board trigger refreshes public_profiles from the save; the sweep does not', async () => {
  const db = new FakeFirestore();
  db.seed('users/u1', { progress: { day: 37 } });
  const logger = { warn() {}, info() {} };
  const ref = { delete: async () => {}, update: async () => {} };
  const run = (profile) => checkEntry({
    db, eco: require('./charm').loadEconomy(ECO), period: 's1', uid: 'u1',
    entry: { displayName: 'Tiệm Mai', charm: 0 }, ref, mode: 'log', now: T0, logger, profile,
  });
  await run(false);
  assert.equal(db.docs.has('public_profiles/u1'), false);
  await run(true);
  assert.deepEqual(db.docs.get('public_profiles/u1'), { day: 37, updatedAt: T0 });
});
