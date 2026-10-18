'use strict';
// Tin thế giới server rules (world_chat.js) on the in-memory Firestore.
// Numbers from economy.json `worldChat` (synced from assets/data by npm test).
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const { createFilter, defaultFilter, defaultWordList } = require('./word_filter');
const chat = require('./world_chat');

const ECO = require('./economy.json');
const W = ECO.worldChat;
const T0 = new Date('2026-10-17T03:00:00Z');
const at = (s) => new Date(T0.getTime() + s * 1000);

function world({ day = 7, enabled = true, name = 'Tiệm Mai' } = {}) {
  const db = new FakeFirestore();
  if (enabled !== null) db.seed('config/worldChat', { enabled });
  db.seed('users/u1', { progress: { day, shopName: name } });
  db.seed('users/u2', { progress: { day: 9, shopName: 'Tiệm Lan' } });
  return db;
}
const send = (db, text, now = T0, uid = 'u1', extra = {}) => chat.send({
  db, eco: ECO, uid, now, data: { text, avatar: 'a.png' }, filter: defaultFilter(), words: defaultWordList(), ...extra,
});
async function code(p) {
  try { await p; } catch (e) { assert.ok(e instanceof chat.ChatError, e && e.stack); return e; }
  assert.fail('expected a refusal');
}
const msgs = (db) => [...db.docs.keys()].filter((p) => p.startsWith('world_chat/')).sort();

test('economy.json worldChat: the numbers of spec 5.1', () => {
  assert.equal(W.unlockDay, 5);
  assert.equal(W.maxChars, 80);
  assert.equal(W.cooldownSeconds, 10);
  assert.equal(W.duplicateWindowSeconds, 60);
  assert.equal(W.keepLatest, 100);
  assert.deepEqual(W.muteLevels.map((m) => [m.id, m.minutes]),
    [['warning', 0], ['mute_1h', 60], ['mute_24h', 1440], ['mute_7d', 10080], ['ban', null]]);
  const bad = structuredClone(ECO);
  delete bad.worldChat.keepLatest;
  assert.throws(() => chat.cfg(bad), /worldChat.keepLatest/);
});

test('a message is written by the server with the save name, seq and time', async () => {
  const db = world();
  const r = await send(db, '  Chào  cả phố hoa  ');
  assert.equal(r.id, 'm0000000001');
  assert.equal(r.masked, false);
  const m = db.read('world_chat/m0000000001');
  assert.deepEqual({ ...m, createdAt: m.createdAt.toISOString() }, {
    uid: 'u1', name: 'Tiệm Mai', avatar: 'a.png', text: 'Chào  cả phố hoa', seq: 1, createdAt: T0.toISOString(),
  });
  assert.equal(db.read('world_chat_meta/state').seq, 1);
});

test('kill switch: missing doc is on; explicit false or non-true refuses', async () => {
  await send(world({ enabled: null }), 'hi');
  assert.equal((await code(send(world({ enabled: false }), 'hi'))).code, 'disabled');
  const db = world();
  db.seed('config/worldChat', { enabled: 'yes' });
  assert.equal((await code(send(db, 'hi'))).code, 'disabled');
});

test('length: empty refused, 80 characters ok (accents count 1), 81 refused', async () => {
  assert.equal((await code(send(world(), '   '))).code, 'empty');
  // 16 × "ưa hồ" = 80 characters, no run the spam filter would catch.
  const ok = Array.from({ length: 16 }, (_, i) => `ư${String.fromCharCode(97 + i)} hồ`).join('');
  assert.equal(chat.charCount(ok), 80);
  await send(world(), ok);
  const e = await code(send(world(), `${ok}x`));
  assert.equal(e.code, 'too_long');
  assert.equal(e.extra.max, 80);
});

test('day gate: day 4 refused with days left, day 5 sends, no save refused', async () => {
  const e = await code(send(world({ day: 4 }), 'hi'));
  assert.equal(e.code, 'locked_day');
  assert.deepEqual(e.extra, { unlockDay: 5, daysLeft: 1 });
  await send(world({ day: 5 }), 'hi');
  const db = world();
  db.docs.delete('users/u1');
  assert.equal((await code(send(db, 'hi'))).code, 'no_save');
});

test('cooldown: a second message within 10 s is refused with the wait', async () => {
  const db = world();
  await send(db, 'một');
  const e = await code(send(db, 'hai', at(4)));
  assert.equal(e.code, 'cooldown');
  assert.equal(e.extra.seconds, 6);
  await send(db, 'hai', at(10));
  assert.equal(msgs(db).length, 2);
});

test('duplicate: the same text within 60 s is refused, after 60 s it is fine', async () => {
  const db = world();
  await send(db, 'Chào cả nhà');
  await send(db, 'khác', at(20));
  assert.equal((await code(send(db, '  chào   CẢ nhà ', at(40)))).code, 'duplicate');
  await send(db, 'Chào cả nhà', at(61));
  // another player may say the same thing
  await send(db, 'Chào cả nhà', at(62), 'u2');
});

test('filter: chặn words refused, links and phone numbers get blocked_link', async () => {
  const words = defaultWordList();
  const link = words.nhom.find((g) => g.id === 'lien_he_duong_dan');
  assert.ok(link && link.muc.length);
  assert.equal((await code(send(world(), 'vào zalo 0912345678 nhé'))).code, 'blocked_link');
  const blockWord = words.nhom.find((g) => g.id === 'lua_dao_mua_ban').muc.find((m) => m.hanh_dong === 'chặn' && m.kieu === 'tu');
  assert.ok(blockWord, 'tu_cam.json has a chặn word in lua_dao_mua_ban');
  assert.equal((await code(send(world(), `ai ${blockWord.mau} không`))).code, 'blocked');
  // Nhất's tuc_tiu group is all `che`: masked, not refused.
  const r = await send(world(), 'hoa đẹp đm');
  assert.equal(r.masked, true);
  assert.equal(r.text, 'hoa đẹp ***');
  const db = world();
  assert.equal(db.docs.has('world_chat_state/u1'), false); // a refusal leaves no trace
});

test('filter: a che-only word is masked as *** and the message goes out', () => {
  const words = { nhom: [{ id: 'nhe', muc: [
    { id: 'n1', kieu: 'tu', mau: 'xấu', hanh_dong: 'che' },
    { id: 'b1', kieu: 'tu', mau: 'tệ', hanh_dong: 'chặn' },
  ] }, { id: 'lien_he_duong_dan', muc: [{ id: 'l1', kieu: 'tu', mau: 'zalo', hanh_dong: 'chặn' }] }], danh_sach_trang: [] };
  const f = createFilter(words);
  const links = chat.linkIds(words);
  assert.deepEqual(chat.screen(f, links, 'hoa xấu quá'), { text: 'hoa *** quá', masked: true });
  assert.deepEqual(chat.screen(f, links, 'hoa đẹp'), { text: 'hoa đẹp', masked: false });
  assert.throws(() => chat.screen(f, links, 'tệ thật'), (e) => e.code === 'blocked');
  assert.throws(() => chat.screen(f, links, 'add zalo'), (e) => e.code === 'blocked_link');
});

test('mutes: warning lets through, 1h mute refuses until it ends, ban always refuses', async () => {
  const db = world();
  db.seed('chat_mutes/u1', { level: 'warning', at: T0 });
  await send(db, 'một');
  // the end comes from economy.json (60 min after `at`), whatever else the doc says
  db.seed('chat_mutes/u1', { level: 'mute_1h', at: at(0), until: at(99999999) });
  const e = await code(send(db, 'hai', at(30)));
  assert.equal(e.code, 'muted');
  assert.equal(e.extra.until, at(3600).getTime());
  await send(db, 'hai', at(3601));
  db.seed('chat_mutes/u1', { level: 'ban', at: T0 });
  assert.equal((await code(send(db, 'ba', at(9e6)))).code, 'banned');
});

test('keeps only the newest 100 messages', async () => {
  const db = world();
  for (let i = 0; i < 103; i++) {
    const uid = `p${i}`;
    db.seed(`users/${uid}`, { progress: { day: 9, shopName: `Tiệm ${i}` } });
    await send(db, `tin ${i}`, at(i), uid);
  }
  const left = msgs(db);
  assert.equal(left.length, 100);
  assert.equal(left[0], 'world_chat/m0000000004');
  assert.equal(left[99], 'world_chat/m0000000103');
});

test('name comes from the save and goes through the shop-name filter; admins are marked official', async () => {
  const db = world({ name: '' });
  await send(db, 'hi', T0, 'u1', { isAdmin: async () => true });
  const m = db.read('world_chat/m0000000001');
  assert.equal(m.name, 'Chủ tiệm');
  assert.equal(m.official, true);
});

async function seeded() {
  const db = world();
  for (let i = 0; i < 12; i++) {
    const uid = i === 6 ? 'u2' : `p${i}`;
    if (uid !== 'u2') db.seed(`users/${uid}`, { progress: { day: 9, shopName: `Tiệm ${i}` } });
    await send(db, `tin ${i}`, at(i * 20), uid);
  }
  return db;
}
const report = (db, data, uid = 'u1') => chat.report({ db, eco: ECO, uid, now: at(999), data });

test('report: 6 reasons, snapshot of the message and 5 on each side', async () => {
  assert.deepEqual(chat.REASONS, ['profane', 'harassment', 'scam', 'adult', 'spam', 'other']);
  const db = await seeded();
  await report(db, { messageId: 'm0000000007', reason: 'harassment', note: ' quấy ' });
  const r = db.read('chat_reports/u1_m0000000007');
  assert.equal(r.reporterUid, 'u1');
  assert.equal(r.targetUid, 'u2');
  assert.equal(r.text, 'tin 6');
  assert.equal(r.reason, 'harassment');
  assert.equal(r.note, 'quấy');
  assert.equal(r.status, 'open');
  assert.deepEqual(r.context.map((c) => c.seq), [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
});

test('report: once per message, not your own, not a gone message, bad input refused', async () => {
  const db = await seeded();
  await report(db, { messageId: 'm0000000007', reason: 'spam' });
  assert.equal((await code(report(db, { messageId: 'm0000000007', reason: 'other' }))).code, 'already');
  assert.equal((await code(report(db, { messageId: 'm0000000007', reason: 'spam' }, 'u2'))).code, 'self');
  assert.equal((await code(report(db, { messageId: 'm0000000999', reason: 'spam' }))).code, 'gone');
  assert.equal((await code(report(db, { messageId: 'm0000000007', reason: 'mean' }))).code, 'bad');
  assert.equal((await code(report(db, { messageId: '../x', reason: 'spam' }))).code, 'bad');
  assert.equal((await code(report(db, { messageId: 'm0000000008', reason: 'spam', note: 'x'.repeat(201) }))).code, 'bad');
});

test('activeMute: lengths from economy.json, ended mute and unknown levels are no mute', () => {
  const L = W.muteLevels;
  assert.equal(chat.activeMute(null, T0, L), null);
  assert.equal(chat.activeMute({ level: 'mute_24h', at: at(-86401) }, T0, L), null);
  assert.deepEqual(chat.activeMute({ level: 'mute_24h', at: at(-60) }, T0, L), { level: 'mute_24h', until: at(86340) });
  assert.deepEqual(chat.activeMute({ level: 'mute_7d', at: T0 }, at(6 * 86400), L).until, at(7 * 86400));
  assert.deepEqual(chat.activeMute({ level: 'ban', at: T0 }, at(9e8), L), { level: 'ban', until: null });
  assert.equal(chat.activeMute({ level: 'forever', at: T0 }, T0, L), null);
});
