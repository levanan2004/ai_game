'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeFirestore } = require('./fake_firestore');
const topup = require('./topup');
const del = require('./delete_account');

const eco = { phaLeShop: require('../assets/data/economy.json').phaLeShop };
const BANK = { name: 'Vietcombank', code: 'VCB', accountNo: '0123456789', accountName: 'CONG TY TEST' };
const NOW = new Date('2026-10-20T08:00:00Z');
const min = (m) => new Date(NOW.getTime() + m * 60000);
const UID = 'uidAAAAAAAAAAAAAAAAAAAAAAAAA';
const OTHER = 'uidBBBBBBBBBBBBBBBBBBBBBBBBB';

function capture() {
  const lines = [];
  const push = (level) => (msg, data) => lines.push(JSON.stringify([level, msg, data || null]));
  return { info: push('info'), warn: push('warn'), error: push('error'), lines };
}

/** A Storage bucket stand-in: files by path; deleteFiles by prefix. */
function fakeBucket(paths = []) {
  const files = new Set(paths);
  return {
    files,
    failDeleteFiles: false,
    file(path) {
      return { async delete(opts) { if (!files.delete(path) && !(opts && opts.ignoreNotFound)) throw new Error('404'); } };
    },
    async deleteFiles({ prefix }) {
      if (this.failDeleteFiles) throw Object.assign(new Error('boom'), { code: 503 });
      for (const f of [...files]) if (f.startsWith(prefix)) files.delete(f);
    },
  };
}

function fakeAuth(uids = [UID, OTHER]) {
  const users = new Set(uids);
  return {
    users,
    async deleteUser(uid) {
      if (!users.delete(uid)) throw Object.assign(new Error('nope'), { code: 'auth/user-not-found' });
    },
  };
}

/** A player with a bit of everything, and another player who must not be touched. */
function seed(db) {
  for (const [u, n] of [[UID, 'Hoa Ơi'], [OTHER, 'Lan']]) {
    db.seed(`users/${u}`, { progress: { day: 5 }, updatedAt: NOW });
    db.seed(`users/${u}/seat/current`, { id: 'tab-12345678' });
    db.seed(`users/${u}/mailState/m1`, { read: true, claimed: true });
    db.seed(`users/${u}/welfare/login`, { claimedCount: 2 });
    db.seed(`users/${u}/redeemed/batch1`, { code: 'ABCD1234' });
    db.seed(`profiles/${u}`, { name: n, email: `${n}@example.com`, shopName: n });
    db.seed(`player_avatars/${u}`, { path: 'bear', rev: 1, frame: 'la_non' });
    db.seed(`public_profiles/${u}`, { day: 12 });
    db.seed(`player_prefs/${u}`, { blocked: { 'u-third': 'Tiệm Ba' }, chatRulesV1: true });
    db.seed(`shop_names/${n.toLowerCase()}`, { uid: u, shopName: n });
    db.seed(`charm_board/s1/entries/${u}`, { uid: u, displayName: n, charm: 50 });
    db.seed(`charm_board/s2/entries/${u}`, { uid: u, displayName: n, charm: 70 });
    db.seed(`charm_board/s2/review/${u}`, { uid: u, displayName: n, result: 'held' });
    db.seed(`notice_replies/n1_${u}`, { uid: u, noticeId: 'n1', email: `${n}@example.com`, name: n, answers: [] });
    db.seed(`mails/bxh_s1_${u}`, { target: u, title: 'Thưởng' });
    db.seed(`mails/phale_THSMAAAA${u.slice(3, 5)}`, { target: u, title: 'Nạp Pha lê' });
    db.seed(`phale_pending/${u}`, { orderId: 'x' });
    db.seed(`admins/${u}`, { x: 1 });
  }
  db.seed('mails/everyone', { target: 'all', title: 'Chào' });
  db.seed(`profile_reports/${UID}_u-third`, { reporterUid: UID, targetUid: 'u-third', reason: 'spam' });
  db.seed(`profile_reports/u-third_${UID}`, { reporterUid: 'u-third', targetUid: UID, targetName: 'Hoa Ơi', reason: 'profane' });
  db.seed(`profile_reports/${OTHER}_u-third`, { reporterUid: OTHER, targetUid: 'u-third', reason: 'other' });
  db.seed('world_chat/m0000000001', { uid: UID, name: 'Hoa Ơi', text: 'chào', seq: 1 });
  db.seed('world_chat/m0000000002', { uid: OTHER, name: 'Lan', text: 'chào bạn', seq: 2 });
  db.seed('world_chat/m0000000003', { uid: UID, name: 'Hoa Ơi', text: 'mai gặp', seq: 3 });
  db.seed(`chat_reports/${UID}_m0000000002`, { reporterUid: UID, targetUid: OTHER, messageId: 'm0000000002' });
  db.seed('chat_reports/u-third_m0000000001', { reporterUid: 'u-third', targetUid: UID, messageId: 'm0000000001' });
  db.seed('chat_reports/u-third_m0000000002', { reporterUid: 'u-third', targetUid: OTHER, messageId: 'm0000000002' });
  db.seed(`world_chat_state/${UID}`, { lastAt: NOW, recent: [] });
  db.seed(`chat_mutes/${UID}`, { level: 'mute_1h', until: NOW });
  db.seed('supporters/sup1', { uid: UID, name: 'Hoa Ơi', message: 'Chúc vui', visible: true, avatar: 'supporters/sup1_1.jpg', amount: 50000, date: NOW });
  db.seed('supporters/sup2', { uid: OTHER, name: 'Lan', message: 'hi', visible: true, avatar: 'bear', amount: 1000, date: NOW });
  db.seed('supporter_private/sup1', { phone: '0900000000', name: 'Hoa Ơi' });
  db.seed('giftcodes/CODE1', { type: 'single', batchId: 'b', usedBy: UID, usedAt: NOW });
  db.seed('giftcodes/CODE2', { type: 'single', batchId: 'b', usedBy: OTHER, usedAt: NOW });
  db.seed('phale_orders/THSMPAID000001', {
    uid: UID, packId: 'pack_50k', amount: 50000, crystals: 550, status: 'paid', transferContent: 'THSMPAID000001',
    sepayTxnId: 'T100', paidAt: min(-120), createdAt: min(-130), expiresAt: min(-115), mailId: 'phale_THSMPAID000001',
  });
  db.seed('phale_orders/THSMOLDEXP0001', {
    uid: UID, packId: 'pack_10k', amount: 10000, crystals: 100, status: 'pending', transferContent: 'THSMOLDEXP0001',
    createdAt: min(-300), expiresAt: min(-285), paidAt: null,
  });
  db.seed('phale_orders/THSMOTHER00001', { uid: OTHER, status: 'paid', amount: 20000, paidAt: min(-5) });
  db.seed('sepay_txns/T100', { txnId: 'T100', amount: 50000, code: 'THSMPAID000001', result: 'credited', orderId: 'THSMPAID000001', uid: UID });
  db.seed('sepay_txns/T200', { txnId: 'T200', amount: 5, code: null, result: 'unmatched', orderId: null, uid: null });
  db.seed('phale_iap/2000000001', {
    uid: UID, packId: 'pack_50k', phaLe: 550, mailId: 'phale_iap_2000000001', packPriceVnd: 50000,
    price: 49000000, currency: 'VND', environment: 'Production', createdAt: min(-200),
  });
  db.seed('phale_iap/2000000002', { uid: OTHER, packId: 'pack_10k', phaLe: 100, mailId: 'phale_iap_2000000002' });
}

const bucketFiles = () => [
  `users/${UID}/avatar.jpg`, `users/${OTHER}/avatar.jpg`,
  `reply_photos/${UID}/a.jpg`, `reply_photos/${UID}/b.jpg`, `reply_photos/${OTHER}/a.jpg`,
  'supporters/sup1_1.jpg',
];
const has = (db, prefix) => [...db.docs.keys()].filter((p) => p === prefix || p.startsWith(`${prefix}/`));

async function run(db, extra = {}) {
  const ctx = {
    db, auth: fakeAuth(), bucket: fakeBucket(bucketFiles()), uid: UID, now: NOW, logger: capture(), ...extra,
  };
  const out = await del.deleteAccount(ctx);
  return { out, ...ctx };
}

// ---- what is deleted ------------------------------------------------------

test('deletes every document and file of the player, in every season, and the login', async () => {
  const db = new FakeFirestore();
  seed(db);
  const { out, auth, bucket } = await run(db);
  assert.deepEqual(out, { status: 'deleted' });
  assert.deepEqual(has(db, `users/${UID}`), []); // save + seat + mailState + welfare + redeemed
  for (const p of [`profiles/${UID}`, `player_avatars/${UID}`, `public_profiles/${UID}`, `player_prefs/${UID}`, 'shop_names/hoa ơi', `charm_board/s1/entries/${UID}`,
    `charm_board/s2/entries/${UID}`, `charm_board/s2/review/${UID}`, `notice_replies/n1_${UID}`,
    `mails/bxh_s1_${UID}`, `phale_pending/${UID}`, `admins/${UID}`, 'supporter_private/sup1',
    `profile_reports/${UID}_u-third`, `profile_reports/u-third_${UID}`]) {
    assert.equal(db.read(p), undefined, p);
  }
  assert.ok(!auth.users.has(UID), 'the Auth user is deleted');
  assert.deepEqual([...bucket.files].sort(), [`reply_photos/${OTHER}/a.jpg`, `users/${OTHER}/avatar.jpg`].sort());
  // the credit mail of the player's order went too
  assert.deepEqual([...db.docs.keys()].filter((p) => p.startsWith('mails/') && db.read(p).target === UID), []);
});

test('Tin thế giới: the player\'s messages, reports sent or about them, cooldown and mute go; others stay', async () => {
  const db = new FakeFirestore();
  seed(db);
  await run(db);
  assert.deepEqual(has(db, 'world_chat'), ['world_chat/m0000000002']);
  assert.deepEqual(has(db, 'chat_reports'), ['chat_reports/u-third_m0000000002']);
  assert.equal(db.read(`world_chat_state/${UID}`), undefined);
  assert.equal(db.read(`chat_mutes/${UID}`), undefined);
});

test('another player and the shared mail are untouched', async () => {
  const db = new FakeFirestore();
  seed(db);
  const before = JSON.stringify([...db.docs].filter(([p]) => p.includes(OTHER) || p.includes('Lan') || p === 'mails/everyone'
    || p === 'supporters/sup2' || p === 'giftcodes/CODE2' || p === 'phale_orders/THSMOTHER00001' || p === 'sepay_txns/T200'));
  const { auth } = await run(db);
  const after = JSON.stringify([...db.docs].filter(([p]) => p.includes(OTHER) || p.includes('Lan') || p === 'mails/everyone'
    || p === 'supporters/sup2' || p === 'giftcodes/CODE2' || p === 'phale_orders/THSMOTHER00001' || p === 'sepay_txns/T200'));
  assert.equal(after, before);
  assert.ok(auth.users.has(OTHER));
});

test('a season that only has entries (no meta doc) is cleaned too', async () => {
  const db = new FakeFirestore();
  db.seed(`charm_board/2026-q4/entries/${UID}`, { uid: UID, charm: 30 });
  await run(db);
  assert.equal(db.read(`charm_board/2026-q4/entries/${UID}`), undefined);
});

// ---- what is anonymized, what is kept --------------------------------------

test('paid and old orders keep id, amount, time and bank transaction id, but lose the uid', async () => {
  const db = new FakeFirestore();
  seed(db);
  await run(db);
  const paid = db.read('phale_orders/THSMPAID000001');
  assert.equal(paid.uid, null);
  assert.equal(paid.amount, 50000);
  assert.equal(paid.sepayTxnId, 'T100');
  assert.equal(paid.status, 'paid');
  assert.deepEqual(paid.paidAt, min(-120));
  assert.ok(paid.anonymizedAt);
  // an old pending order (expired long ago) is anonymized too, not kept with a uid
  assert.equal(db.read('phale_orders/THSMOLDEXP0001').uid, null);
  assert.equal(db.read('sepay_txns/T100').uid, null);
  assert.equal(db.read('sepay_txns/T100').amount, 50000);
  // no order or payment doc anywhere still names the player
  for (const [p, d] of db.docs) {
    if (p.startsWith('phale_orders/') || p.startsWith('sepay_txns/')) assert.notEqual(d.uid, UID, p);
  }
});

test('App Store purchases keep pack, price and time, but lose the uid', async () => {
  const db = new FakeFirestore();
  seed(db);
  await run(db);
  const row = db.read('phale_iap/2000000001');
  assert.equal(row.uid, null);
  assert.ok(row.anonymizedAt);
  assert.equal(row.packId, 'pack_50k');
  assert.equal(row.price, 49000000);
  assert.equal(row.packPriceVnd, 50000);
  assert.equal(db.read('phale_iap/2000000002').uid, OTHER);
});

test('supporters rows keep amount and date only; a single-use giftcode stays used', async () => {
  const db = new FakeFirestore();
  seed(db);
  await run(db);
  const s = db.read('supporters/sup1');
  assert.equal(s.uid, '');
  assert.equal(s.name, 'Ẩn danh');
  assert.equal(s.message, '');
  assert.equal(s.avatar, '');
  assert.equal(s.visible, false);
  assert.equal(s.amount, 50000);
  assert.deepEqual(s.date, NOW);
  assert.equal(db.read('giftcodes/CODE1').usedBy, del.ANON_USED_BY);
  assert.equal(db.read('giftcodes/CODE2').usedBy, OTHER);
});

// ---- the late-payment guard --------------------------------------------------

test('blocked while an order awaits payment: nothing is deleted, the login stays', async () => {
  const db = new FakeFirestore();
  seed(db);
  db.seed('phale_orders/THSMWAITING001', { uid: UID, status: 'pending', amount: 50000, createdAt: min(-3), expiresAt: min(12) });
  const before = JSON.stringify([...db.docs]);
  const auth = fakeAuth();
  const bucket = fakeBucket(bucketFiles());
  await assert.rejects(del.deleteAccount({ db, auth, bucket, uid: UID, now: NOW, logger: capture() }), { code: 'order-pending' });
  assert.equal(JSON.stringify([...db.docs]), before);
  assert.ok(auth.users.has(UID));
  assert.equal(bucket.files.size, bucketFiles().length);
});

test('the guard window: pending until 10 min after expiry, paid or cancelled in the last 10 min', () => {
  const o = (x) => del.orderIsRecent(x, NOW);
  assert.equal(del.RECENT_ORDER_MINUTES, 10);
  assert.equal(o({ status: 'pending', expiresAt: min(5) }), true);
  assert.equal(o({ status: 'pending', expiresAt: min(-9) }), true);
  assert.equal(o({ status: 'pending', expiresAt: min(-11) }), false);
  assert.equal(o({ status: 'paid', paidAt: min(-9) }), true);
  assert.equal(o({ status: 'paid', paidAt: min(-11) }), false);
  assert.equal(o({ status: 'cancelled', cancelledAt: min(-2) }), true);
  assert.equal(o({ status: 'cancelled', cancelledAt: min(-30) }), false);
  assert.equal(o({ status: 'lech_goi' }), false);
  // Firestore Timestamps (toDate) work like dates
  assert.equal(o({ status: 'paid', paidAt: { toDate: () => min(-1) } }), true);
});

test('an order paid 5 minutes ago blocks; the same order paid 11 minutes ago does not', async () => {
  for (const [ago, blocked] of [[-5, true], [-11, false]]) {
    const db = new FakeFirestore();
    db.seed('phale_orders/THSMPAIDNEAR01', { uid: UID, status: 'paid', amount: 20000, paidAt: min(ago), expiresAt: min(ago - 15) });
    const p = del.deleteAccount({ db, auth: fakeAuth(), bucket: fakeBucket(), uid: UID, now: NOW, logger: capture() });
    if (blocked) await assert.rejects(p, { code: 'order-pending' });
    else assert.deepEqual(await p, { status: 'deleted' });
  }
});

test('an order of another account does not block this one', async () => {
  const db = new FakeFirestore();
  db.seed('phale_orders/THSMOTHER00002', { uid: OTHER, status: 'pending', expiresAt: min(10) });
  assert.deepEqual(await del.deleteAccount({ db, auth: fakeAuth(), bucket: fakeBucket(), uid: UID, now: NOW, logger: capture() }), { status: 'deleted' });
});

test('a late transfer to an anonymized order is flagged for the admin: no crash, no credit, no mail', async () => {
  const db = new FakeFirestore();
  seed(db);
  await run(db);
  const mailsBefore = [...db.docs.keys()].filter((p) => p.startsWith('mails/')).length;
  const logger = capture();
  // the old pending order gets money (the amount equals a pack) long after the deletion
  const res = await topup.handlePayment({
    db, eco, event: { txnId: 'LATE1', amount: 10000, code: 'THSMOLDEXP0001', source: 'ipn' }, now: min(60), logger,
  });
  assert.equal(res, 'orphan');
  assert.equal([...db.docs.keys()].filter((p) => p.startsWith('mails/')).length, mailsBefore);
  const o = db.read('phale_orders/THSMOLDEXP0001');
  assert.equal(o.status, 'pending'); // never marked paid
  assert.equal(o.orphanPayment, true);
  assert.deepEqual(o.orphanTxnIds, ['LATE1']);
  const t = db.read('sepay_txns/LATE1');
  assert.equal(t.result, 'orphan');
  assert.equal(t.uid, null);
  assert.equal(t.amount, 10000);
  assert.ok(logger.lines.some((l) => l.includes('deleted account')), 'the admin sees a warning');
  // a retry of the same notification is a duplicate, not a second flag
  assert.equal(await topup.handlePayment({ db, eco, event: { txnId: 'LATE1', amount: 10000, code: 'THSMOLDEXP0001' }, now: min(61), logger }), 'duplicate');
});

test('a second transfer to an anonymized PAID order is an orphan too (no notice mail to nobody)', async () => {
  const db = new FakeFirestore();
  seed(db);
  await run(db);
  const res = await topup.handlePayment({
    db, eco, event: { txnId: 'DUP9', amount: 50000, code: 'THSMPAID000001', source: 'ipn' }, now: min(5), logger: capture(),
  });
  assert.equal(res, 'orphan');
  assert.equal(db.read('phale_orders/THSMPAID000001').duplicatePayment, undefined);
  assert.ok([...db.docs.keys()].every((p) => !p.startsWith('mails/phale_dup_')));
});

test('an anonymized order is not readable by, nor cancellable from, any account', async () => {
  const db = new FakeFirestore();
  seed(db);
  await run(db);
  await assert.rejects(topup.orderStatus({ db, uid: UID, orderId: 'THSMPAID000001', now: NOW }), { code: 'not_found' });
  await assert.rejects(topup.cancelOrder({ db, uid: OTHER, orderId: 'THSMPAID000001', now: NOW }), { code: 'not_found' });
});

// ---- idempotent, partial, logs ------------------------------------------------

test('idempotent: a second call after everything is gone succeeds (Auth user already deleted)', async () => {
  const db = new FakeFirestore();
  seed(db);
  const first = await run(db);
  const again = await del.deleteAccount({ db, auth: first.auth, bucket: first.bucket, uid: UID, now: NOW, logger: capture() });
  assert.deepEqual(again, { status: 'deleted' });
  // and an account that never had data is fine too
  assert.deepEqual(await del.deleteAccount({ db: new FakeFirestore(), auth: fakeAuth(), bucket: fakeBucket(), uid: UID, now: NOW, logger: capture() }), { status: 'deleted' });
});

test('a failing step leaves the Auth user, still runs the other steps, and a retry finishes', async () => {
  const db = new FakeFirestore();
  seed(db);
  const auth = fakeAuth();
  const bucket = fakeBucket(bucketFiles());
  bucket.failDeleteFiles = true; // the reply photos step
  const logger = capture();
  await assert.rejects(
    del.deleteAccount({ db, auth, bucket, uid: UID, now: NOW, logger }),
    (e) => e.code === 'partial' && e.steps.join() === 'replies',
  );
  assert.ok(auth.users.has(UID), 'the login stays so the player can try again');
  assert.equal(db.read(`profiles/${UID}`), undefined, 'the other steps still ran');
  bucket.failDeleteFiles = false;
  assert.deepEqual(await del.deleteAccount({ db, auth, bucket, uid: UID, now: NOW, logger: capture() }), { status: 'deleted' });
  assert.ok(!auth.users.has(UID));
  assert.equal(bucket.files.has(`reply_photos/${UID}/a.jpg`), false);
});

test('a retry after a failed anonymize still removes the private phone note of a supporter row', async () => {
  const db = new FakeFirestore();
  seed(db);
  // first run fails after the private note was removed but before Auth
  const bucket = fakeBucket(bucketFiles());
  bucket.failDeleteFiles = true;
  await assert.rejects(del.deleteAccount({ db, auth: fakeAuth(), bucket, uid: UID, now: NOW, logger: capture() }), { code: 'partial' });
  assert.equal(db.read('supporter_private/sup1'), undefined);
  assert.equal(db.read('supporters/sup1').uid, '');
});

test('the logs carry step names and counts only: no uid, email, name or order code', async () => {
  const db = new FakeFirestore();
  seed(db);
  const logger = capture();
  const bucket = fakeBucket(bucketFiles());
  bucket.failDeleteFiles = true;
  await assert.rejects(del.deleteAccount({ db, auth: fakeAuth(), bucket, uid: UID, now: NOW, logger }));
  bucket.failDeleteFiles = false;
  await del.deleteAccount({ db, auth: fakeAuth(), bucket, uid: UID, now: NOW, logger });
  const all = logger.lines.join('\n');
  assert.ok(all.includes('delete account done'));
  for (const secret of [UID, 'example.com', 'Hoa Ơi', 'THSM', '0900000000']) assert.ok(!all.includes(secret), secret);
});

test('no uid is refused (the callable always passes request.auth.uid)', async () => {
  await assert.rejects(del.deleteAccount({ db: new FakeFirestore(), auth: fakeAuth(), bucket: fakeBucket(), uid: '', logger: capture() }));
});
