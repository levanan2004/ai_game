'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const { FakeFirestore } = require('./fake_firestore');
const topup = require('./topup');
const sepay = require('./sepay');
const { paymentHandler, playerHandler } = require('./topup_http');

const eco = { phaLeShop: require('../assets/data/economy.json').phaLeShop };
const BANK = { name: 'Vietcombank', code: 'VCB', accountNo: '0123456789', accountName: 'CONG TY TEST' };
const T0 = new Date('2026-10-20T08:00:00Z');
const at = (min) => new Date(T0.getTime() + min * 60000);
const quiet = { info() {}, warn() {}, error() {} };
const SECRET = 's3cret-key-value';
const APIKEY = 'api-key-value';

async function order(db, { uid = 'u1', packId = 'pack_50k', now = T0, open = true } = {}) {
  return topup.createOrder({ db, eco, uid, packId, bank: BANK, now, open });
}
const pay = (db, o, amount, now, txnId = 'T1', code = o.transferContent) =>
  topup.handlePayment({ db, eco, event: { txnId, amount, code, source: 'ipn' }, now, logger: quiet });

// ---- pack table -------------------------------------------------------------

test('the six packs come from economy.json (10k=100 ... 500k=6250)', () => {
  const t = topup.packTable(eco).map((p) => [p.priceVnd, p.phaLe]);
  assert.deepEqual(t, [[10000, 100], [20000, 210], [50000, 550], [100000, 1150], [200000, 2400], [500000, 6250]]);
});

// ---- create / status / cancel -------------------------------------------------

test('create: pack by id from the server table, unique unguessable code, QR url', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  assert.equal(o.amount, 50000);
  assert.equal(o.crystals, 550);
  assert.equal(o.status, 'pending');
  assert.match(o.transferContent, /^THSM[A-HJ-NP-Z2-9]{10}$/);
  assert.equal(o.orderId, o.transferContent);
  assert.equal(o.expiresAt, at(15).toISOString());
  assert.match(o.qrImageUrl, /^https:\/\/qr\.sepay\.vn\/img\?acc=0123456789&bank=VCB&amount=50000&des=THSM/);
  const b = await order(new FakeFirestore());
  assert.notEqual(o.transferContent, b.transferContent);
});

test('create: an unknown pack, or the shop closed, makes no order', async () => {
  const db = new FakeFirestore();
  await assert.rejects(order(db, { packId: 'pack_1' }), { code: 'bad_pack' });
  await assert.rejects(order(db, { open: false }), { code: 'closed' });
  assert.equal([...db.docs.keys()].length, 0);
});

test('one pending order per account: the open one comes back, another account gets its own', async () => {
  const db = new FakeFirestore();
  const a = await order(db, { packId: 'pack_50k' });
  const again = await order(db, { packId: 'pack_500k', now: at(5) });
  assert.equal(again.orderId, a.orderId);
  assert.equal(again.amount, 50000);
  const other = await order(db, { uid: 'u2' });
  assert.notEqual(other.orderId, a.orderId);
});

test('an expired or cancelled order lets the account make a new one', async () => {
  const db = new FakeFirestore();
  const a = await order(db);
  const b = await order(db, { now: at(16) }); // a expired at 15
  assert.notEqual(b.orderId, a.orderId);
  await topup.cancelOrder({ db, uid: 'u1', orderId: b.orderId, now: at(17) });
  const c = await order(db, { now: at(18) });
  assert.notEqual(c.orderId, b.orderId);
});

test('status only reads: pending, then expired by the clock, never changes the doc', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  const before = JSON.stringify(db.read(`phale_orders/${o.orderId}`));
  assert.equal((await topup.orderStatus({ db, uid: 'u1', orderId: o.orderId, now: at(3) })).status, 'pending');
  const late = await topup.orderStatus({ db, uid: 'u1', orderId: o.orderId, now: at(30) });
  assert.equal(late.status, 'expired');
  assert.equal(late.serverTime, at(30).toISOString());
  assert.equal(JSON.stringify(db.read(`phale_orders/${o.orderId}`)), before);
  assert.deepEqual(db.log.filter(([k]) => k !== 'create' && k !== 'set'), []);
});

test('status and cancel: only the owner', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  await assert.rejects(topup.orderStatus({ db, uid: 'u2', orderId: o.orderId, now: T0 }), { code: 'not_found' });
  await assert.rejects(topup.cancelOrder({ db, uid: 'u2', orderId: o.orderId, now: T0 }), { code: 'not_found' });
  const c = await topup.cancelOrder({ db, uid: 'u1', orderId: o.orderId, now: at(1) });
  assert.equal(c.status, 'cancelled');
  assert.equal(db.read('phale_pending/u1'), undefined);
});

// ---- payment ----------------------------------------------------------------

test('exact amount pays once: order paid, one mail with the pack Pha lê, pointer freed', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  assert.equal(await pay(db, o, 50000, at(2)), 'credited');
  const saved = db.read(`phale_orders/${o.orderId}`);
  assert.equal(saved.status, 'paid');
  assert.equal(saved.crystalsGranted, 550);
  assert.equal(saved.sepayTxnId, 'T1');
  const mail = db.read(`mails/phale_${o.orderId}`);
  assert.equal(mail.target, 'u1');
  assert.deepEqual(mail.rewards.items, [{ kind: 'phaLe', amount: 550 }]);
  assert.equal(db.read('phale_pending/u1'), undefined);
  assert.equal(db.read('sepay_txns/T1').result, 'credited');
  const view = await topup.orderStatus({ db, uid: 'u1', orderId: o.orderId, now: at(3) });
  assert.equal(view.status, 'paid');
  assert.equal(view.crystalsGranted, 550);
  assert.equal(view.mailId, `phale_${o.orderId}`);
});

test('Pha lê comes from the AMOUNT: paying another pack price pays that pack', async () => {
  const db = new FakeFirestore();
  const o = await order(db, { packId: 'pack_50k' });
  assert.equal(await pay(db, o, 100000, at(1)), 'credited');
  assert.equal(db.read(`phale_orders/${o.orderId}`).crystalsGranted, 1150);
  assert.equal(db.read(`phale_orders/${o.orderId}`).packId, 'pack_100k');
  assert.equal(db.read(`mails/phale_${o.orderId}`).rewards.items[0].amount, 1150);
});

test('an amount that matches no pack: NOT credited, order lech_goi for the admin', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  assert.equal(await pay(db, o, 49000, at(1)), 'lech_goi');
  const saved = db.read(`phale_orders/${o.orderId}`);
  assert.equal(saved.status, 'lech_goi');
  assert.equal(saved.receivedAmount, 49000);
  assert.equal(db.read(`mails/phale_${o.orderId}`), undefined);
  assert.equal(db.read('sepay_txns/T1').result, 'lech_goi');
  const view = await topup.orderStatus({ db, uid: 'u1', orderId: o.orderId, now: at(2) });
  assert.equal(view.status, 'mismatch');
  assert.equal(view.crystalsGranted, null);
});

test('the same SePay transaction twice credits once (retry)', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  assert.equal(await pay(db, o, 50000, at(1)), 'credited');
  assert.equal(await pay(db, o, 50000, at(1)), 'duplicate');
  assert.equal(await pay(db, o, 50000, at(9)), 'duplicate');
  assert.equal(db.log.filter(([k, p]) => k === 'create' && p.startsWith('mails/')).length, 1);
});

test('a second transaction on an order that is already paid is recorded, not credited', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  await pay(db, o, 50000, at(1), 'T1');
  assert.equal(await pay(db, o, 50000, at(2), 'T2'), 'order_already_paid');
  assert.equal(db.read('sepay_txns/T2').result, 'order_already_paid');
  assert.deepEqual(db.read(`phale_orders/${o.orderId}`).extraTxnIds, ['T2']);
  assert.equal(db.log.filter(([k, p]) => k === 'create' && p.startsWith('mails/')).length, 1);
});

test('two IPNs at once: the same transaction pays once; two transactions pay once', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  const same = await Promise.all([pay(db, o, 50000, at(1), 'T1'), pay(db, o, 50000, at(1), 'T1')]);
  assert.deepEqual(same.sort(), ['credited', 'duplicate']);
  const db2 = new FakeFirestore();
  const o2 = await order(db2);
  const two = await Promise.all([pay(db2, o2, 50000, at(1), 'A'), pay(db2, o2, 50000, at(1), 'B')]);
  assert.deepEqual(two.sort(), ['credited', 'order_already_paid']);
  assert.equal(db2.log.filter(([k, p]) => k === 'create' && p.startsWith('mails/')).length, 1);
});

test('an expired order: money after the grace is NOT credited (late, for the admin)', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  // 15 min + 120 s grace: still paid at 16:30, late at 18
  assert.equal(await pay(db, o, 50000, at(18), 'T9'), 'late');
  const saved = db.read(`phale_orders/${o.orderId}`);
  assert.equal(saved.status, 'expired');
  assert.equal(saved.lateTxnId, 'T9');
  assert.equal(db.read(`mails/phale_${o.orderId}`), undefined);
  const db2 = new FakeFirestore();
  const o2 = await order(db2);
  assert.equal(await pay(db2, o2, 50000, at(16.5)), 'credited');
});

test('a cancelled order: money is recorded, not credited', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  await topup.cancelOrder({ db, uid: 'u1', orderId: o.orderId, now: at(1) });
  assert.equal(await pay(db, o, 50000, at(2)), 'cancelled_order');
  assert.equal(db.read(`phale_orders/${o.orderId}`).status, 'cancelled');
  assert.equal(db.read(`mails/phale_${o.orderId}`), undefined);
});

test('a payment whose code matches no order is recorded and ignored', async () => {
  const db = new FakeFirestore();
  assert.equal(await topup.handlePayment({ db, eco, event: { txnId: 'X', amount: 50000, code: 'THSMNOPE' }, now: T0, logger: quiet }), 'no_order');
  assert.equal(await topup.handlePayment({ db, eco, event: { txnId: 'Y', amount: 50000, code: null }, now: T0, logger: quiet }), 'no_order');
  assert.equal(db.log.filter(([, p]) => p.startsWith('mails/')).length, 0);
});

test('findCode reads the code out of a bank transfer content', () => {
  const o = 'THSMK7P2Q9XABC';
  assert.equal(topup.findCode(`NAP ${o} cam on`), o);
  assert.equal(topup.findCode(`thsmk7p2q9xabc`), o);
  assert.equal(topup.findCode(`THSM K7P2 Q9XABC`), o);
  assert.equal(topup.findCode('hello'), null);
});

// ---- signatures / handlers ---------------------------------------------------

const ipnBody = (o, amount = 50000, extra = {}) => ({
  timestamp: 1, notification_type: 'ORDER_PAID',
  order: { order_invoice_number: o.transferContent, order_amount: `${amount}.00`, order_status: 'CAPTURED' },
  transaction: { transaction_id: 'abc123', transaction_amount: String(amount), transaction_status: 'APPROVED', transaction_type: 'PAYMENT', payment_method: 'BANK_TRANSFER' },
  ...extra,
});
const fakeRes = () => ({ code: 0, body: null, status(c) { this.code = c; return this; }, json(b) { this.body = b; return this; } });
const secrets = () => ({ secretKey: SECRET, apiKey: APIKEY });
const handler = (kind, db, now = () => at(1)) =>
  paymentHandler({ kind, db, eco, getSecrets: secrets, now, logger: quiet });

test('IPN: right X-Secret-Key credits (200), wrong or missing key is 401 and changes nothing', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  const h = handler('ipn', db);
  for (const headers of [{}, { 'x-secret-key': 'nope' }, { 'x-secret-key': '' }]) {
    const res = fakeRes();
    await h({ method: 'POST', headers, body: ipnBody(o) }, res);
    assert.equal(res.code, 401);
  }
  assert.equal(db.read(`phale_orders/${o.orderId}`).status, 'pending');
  const ok = fakeRes();
  await h({ method: 'POST', headers: { 'x-secret-key': SECRET }, body: ipnBody(o) }, ok);
  assert.equal(ok.code, 200);
  assert.equal(ok.body.result, 'credited');
  assert.equal(db.read('sepay_txns/ipn_abc123').result, 'credited');
});

test('IPN: a retry of the same notification is 200 and credits nothing more', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  const h = handler('ipn', db);
  const call = async () => { const r = fakeRes(); await h({ method: 'POST', headers: { 'x-secret-key': SECRET }, body: ipnBody(o) }, r); return r; };
  assert.equal((await call()).body.result, 'credited');
  const again = await call();
  assert.equal(again.code, 200);
  assert.equal(again.body.result, 'duplicate');
});

test('IPN: the amount in the body decides, a wrong amount is lech_goi (no credit)', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  const res = fakeRes();
  await handler('ipn', db)({ method: 'POST', headers: { 'x-secret-key': SECRET }, body: ipnBody(o, 12345) }, res);
  assert.equal(res.body.result, 'lech_goi');
  assert.equal(db.read(`mails/phale_${o.orderId}`), undefined);
});

test('IPN: only ORDER_PAID pays; void and declined are acknowledged without credit', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  const h = handler('ipn', db);
  const r1 = fakeRes();
  await h({ method: 'POST', headers: { 'x-secret-key': SECRET }, body: ipnBody(o, 50000, { notification_type: 'TRANSACTION_VOID' }) }, r1);
  assert.equal(r1.code, 200);
  assert.equal(r1.body.void, true);
  const b = ipnBody(o);
  b.transaction.transaction_status = 'DECLINED';
  const r2 = fakeRes();
  await h({ method: 'POST', headers: { 'x-secret-key': SECRET }, body: b }, r2);
  assert.equal(r2.body.ignored, true);
  assert.equal(db.read(`phale_orders/${o.orderId}`).status, 'pending');
});

test('IPN: a database failure is 500 so SePay retries, and nothing half-lands', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  db.failCreate.add(`mails/phale_${o.orderId}`);
  const res = fakeRes();
  await handler('ipn', db)({ method: 'POST', headers: { 'x-secret-key': SECRET }, body: ipnBody(o) }, res);
  assert.equal(res.code, 500);
  // all or nothing: no paid order without its mail, no used transaction id
  assert.equal(db.read(`phale_orders/${o.orderId}`).status, 'pending');
  assert.equal(db.read('sepay_txns/ipn_abc123'), undefined);
});

test('bank webhook: Apikey ok, wrong key 401, money out ignored, content carries the code', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  const h = handler('bank', db);
  const body = { id: 92704, transferType: 'in', transferAmount: 50000, content: `NAP ${o.transferContent}`, code: null };
  const bad = fakeRes();
  await h({ method: 'POST', headers: { authorization: 'Apikey wrong' }, body }, bad);
  assert.equal(bad.code, 401);
  const out = fakeRes();
  await h({ method: 'POST', headers: { authorization: `Apikey ${APIKEY}` }, body: { ...body, transferType: 'out' } }, out);
  assert.equal(out.body.ignored, true);
  const ok = fakeRes();
  await h({ method: 'POST', headers: { authorization: `apikey ${APIKEY}` }, body }, ok);
  assert.equal(ok.body.result, 'credited');
  assert.equal(db.read('sepay_txns/bank_92704').result, 'credited');
});

test('bank webhook: HMAC signature ok / bad / stale timestamp', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  const body = { id: 7, transferType: 'in', transferAmount: 50000, content: o.transferContent };
  const raw = JSON.stringify(body);
  const nowSec = Math.floor(at(1).getTime() / 1000);
  const sign = (ts, secret = SECRET) => `sha256=${crypto.createHmac('sha256', secret).update(`${ts}.${raw}`).digest('hex')}`;
  const h = handler('bank', db);
  const call = async (headers) => { const r = fakeRes(); await h({ method: 'POST', headers, body, rawBody: Buffer.from(raw) }, r); return r; };
  assert.equal((await call({ 'x-sepay-signature': sign(nowSec, 'other'), 'x-sepay-timestamp': String(nowSec) })).code, 401);
  assert.equal((await call({ 'x-sepay-signature': sign(nowSec - 4000), 'x-sepay-timestamp': String(nowSec - 4000) })).code, 401);
  const good = await call({ 'x-sepay-signature': sign(nowSec), 'x-sepay-timestamp': String(nowSec) });
  assert.equal(good.code, 200);
  assert.equal(good.body.result, 'credited');
});

test('player calls: no or bad token is 401; create/status/cancel work for the owner', async () => {
  const db = new FakeFirestore();
  const verify = async (t) => { if (t === 'good') return 'u1'; throw new Error('bad'); };
  const mk = (action, open = true) => playerHandler({ action, db, eco, verify, now: () => T0, bank: BANK, isOpen: async () => open, logger: quiet });
  const r0 = fakeRes();
  await mk('create')({ method: 'POST', headers: {}, body: { packId: 'pack_10k' } }, r0);
  assert.equal(r0.code, 401);
  const r1 = fakeRes();
  await mk('create')({ method: 'POST', headers: { authorization: 'Bearer bad' }, body: { packId: 'pack_10k' } }, r1);
  assert.equal(r1.code, 401);
  const closed = fakeRes();
  await mk('create', false)({ method: 'POST', headers: { authorization: 'Bearer good' }, body: { packId: 'pack_10k' } }, closed);
  assert.equal(closed.code, 503);
  const made = fakeRes();
  await mk('create')({ method: 'POST', headers: { authorization: 'Bearer good' }, body: { packId: 'pack_10k' } }, made);
  assert.equal(made.code, 200);
  assert.equal(made.body.amount, 10000);
  const st = fakeRes();
  await mk('status')({ method: 'GET', headers: { authorization: 'Bearer good' }, query: { orderId: made.body.orderId } }, st);
  assert.equal(st.body.status, 'pending');
  const ca = fakeRes();
  await mk('cancel')({ method: 'POST', headers: { authorization: 'Bearer good' }, body: { orderId: made.body.orderId } }, ca);
  assert.equal(ca.body.status, 'cancelled');
});

test('secret key never appears in a log line or a response', async () => {
  const db = new FakeFirestore();
  const o = await order(db);
  const lines = [];
  const logger = { info: (...a) => lines.push(JSON.stringify(a)), warn: (...a) => lines.push(JSON.stringify(a)), error: (...a) => lines.push(JSON.stringify(a)) };
  const h = paymentHandler({ kind: 'ipn', db, eco, getSecrets: secrets, now: () => at(1), logger });
  const res = fakeRes();
  await h({ method: 'POST', headers: { 'x-secret-key': SECRET }, body: ipnBody(o) }, res);
  assert.ok(lines.length > 0);
  for (const l of [...lines, JSON.stringify(res.body)]) assert.ok(!l.includes(SECRET));
  assert.ok(lines.every((l) => !l.includes(SECRET)));
  assert.ok(sepay.safeEqual('a', 'a') && !sepay.safeEqual('a', 'b') && !sepay.safeEqual('', ''));
});
