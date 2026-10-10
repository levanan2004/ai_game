'use strict';
// Pha lê top-up by bank transfer (SePay). Pure logic: the Admin SDK Firestore
// (or the fake in fake_firestore.js) is passed in, nothing here reads env or
// secrets, so every rule below is unit tested. index.js wires it to HTTPS.
//
// Collections (all written ONLY by these functions; firestore.rules lets a
// player read his own order and nothing else):
//   phale_orders/{code}   one order. The doc id IS the transfer content / the
//                         invoice number, so a payment is matched with one get().
//   phale_pending/{uid}   {orderId}: the account's one open order.
//   sepay_txns/{txnId}    one doc per SePay transaction id = the idempotency
//                         key. A transaction is credited at most once, ever.
//   mails/phale_{code}    the credit itself (see "Why a mail" in the README).

const crypto = require('crypto');

const ORDERS = 'phale_orders';
const PENDING = 'phale_pending';
const TXNS = 'sepay_txns';
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0 O 1 I
const CODE_LEN = 10; // 32^10 = 2^50 codes
const DEFAULTS = {
  orderMinutes: 15, // the countdown of the order screen (SPEC S6a)
  graceSeconds: 120, // money that lands this long after expiry is still paid
  codePrefix: 'THSM', // must match SePay "tiền tố mã thanh toán"
};

const MAIL_TITLE = 'Nạp Pha lê';

class TopupError extends Error {
  constructor(code, http = 400) {
    super(code);
    this.code = code; // closed | bad_pack | not_found | not_pending | busy
    this.http = http;
  }
}

function isAlreadyExists(e) {
  return !!e && (e.code === 6 || e.code === 'already-exists' || e.code === 'ALREADY_EXISTS');
}

function toDate(v) {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof v.toDate === 'function') return v.toDate();
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** The pack table of economy.json (`phaLeShop.packs`), never the client's. */
function packTable(eco) {
  const raw = eco.phaLeShop || {};
  return (raw.packs || [])
    .filter((p) => p && p.priceVnd > 0 && p.phaLe > 0)
    .map((p) => ({ id: p.id, priceVnd: p.priceVnd, phaLe: p.phaLe, bonusPercent: p.bonusPercent || 0 }));
}

/** The pack whose price is exactly [amount] (VND), or null. */
function packByAmount(packs, amount) {
  return packs.find((p) => p.priceVnd === amount) || null;
}

function newCode(prefix = DEFAULTS.codePrefix, randomInt = crypto.randomInt) {
  let s = '';
  for (let i = 0; i < CODE_LEN; i++) s += ALPHABET[randomInt(ALPHABET.length)];
  return prefix + s;
}

/** Finds an order code of this shop in free text (a bank transfer content). */
function findCode(text, prefix = DEFAULTS.codePrefix) {
  if (!text) return null;
  const re = new RegExp(`${prefix}[${ALPHABET}]{${CODE_LEN}}`, 'i');
  const m = re.exec(String(text).replace(/[\s\-_.]/g, ''));
  return m ? m[0].toUpperCase() : null;
}

function qrUrl(bank, accountNo, amount, code) {
  const q = new URLSearchParams({ acc: accountNo, bank: bank.code, amount: String(amount), des: code });
  return `https://qr.sepay.vn/img?${q.toString()}`;
}

/** What the app shows (docs/PHALE_SHOP_API.md field names). */
function orderView(o, id, now) {
  const expires = toDate(o.expiresAt);
  let status = o.status;
  if (status === 'pending' && expires && now > expires) status = 'expired';
  return {
    orderId: id,
    packId: o.packId,
    amount: o.amount,
    crystals: o.crystals,
    bonusPercent: o.bonusPercent || 0,
    bank: o.bank,
    accountNo: o.accountNo,
    accountName: o.accountName,
    transferContent: o.transferContent,
    qrImageUrl: o.qrImageUrl || null,
    expiresAt: expires ? expires.toISOString() : null,
    serverTime: now.toISOString(),
    // the app's words: lech_goi is "mismatch" there
    status: status === 'lech_goi' ? 'mismatch' : status,
    crystalsGranted: status === 'paid' ? o.crystalsGranted : null,
    newBalance: null, // the balance is the player's save; the app fills it in
    mailId: status === 'paid' ? o.mailId || null : null,
  };
}

/**
 * Makes an order for [packId], or returns the account's open one.
 * [bank] = {name, code, accountNo, accountName}; [cfg] overrides DEFAULTS.
 */
async function createOrder({ db, eco, uid, packId, bank, now, cfg = {}, open = true, randomInt }) {
  const c = { ...DEFAULTS, ...cfg };
  if (!open) throw new TopupError('closed', 503);
  const pack = packTable(eco).find((p) => p.id === packId);
  if (!pack) throw new TopupError('bad_pack', 400);
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = newCode(c.codePrefix, randomInt);
    try {
      return await db.runTransaction(async (tx) => {
        const pointer = db.doc(`${PENDING}/${uid}`);
        const cur = await tx.get(pointer);
        if (cur.exists) {
          const old = await tx.get(db.doc(`${ORDERS}/${cur.data().orderId}`));
          const od = old.exists ? old.data() : null;
          // One open order per account: hand back the one that is still open.
          if (od && od.uid === uid && od.status === 'pending' && toDate(od.expiresAt) > now) {
            return orderView(od, old.id, now);
          }
        }
        const expiresAt = new Date(now.getTime() + c.orderMinutes * 60000);
        const doc = {
          uid,
          packId: pack.id,
          amount: pack.priceVnd,
          crystals: pack.phaLe,
          bonusPercent: pack.bonusPercent,
          status: 'pending',
          transferContent: code,
          bank: bank.name,
          accountNo: bank.accountNo,
          accountName: bank.accountName,
          qrImageUrl: qrUrl(bank, bank.accountNo, pack.priceVnd, code),
          sepayTxnId: null,
          createdAt: now,
          expiresAt,
          paidAt: null,
          crystalsGranted: null,
        };
        tx.create(db.doc(`${ORDERS}/${code}`), doc);
        tx.set(pointer, { orderId: code, updatedAt: now });
        return orderView(doc, code, now);
      });
    } catch (e) {
      if (!isAlreadyExists(e)) throw e; // a code clash: draw another
    }
  }
  throw new TopupError('busy', 503);
}

/** The status call the app polls: reads the order doc, nothing else. */
async function orderStatus({ db, uid, orderId, now }) {
  const snap = await db.doc(`${ORDERS}/${orderId}`).get();
  if (!snap.exists || snap.data().uid !== uid) throw new TopupError('not_found', 404);
  return orderView(snap.data(), snap.id, now);
}

/** "Hủy đơn": only a pending order of the caller; the code stops being paid. */
async function cancelOrder({ db, uid, orderId, now }) {
  return db.runTransaction(async (tx) => {
    const ref = db.doc(`${ORDERS}/${orderId}`);
    const snap = await tx.get(ref);
    if (!snap.exists || snap.data().uid !== uid) throw new TopupError('not_found', 404);
    const o = snap.data();
    if (o.status !== 'pending') return orderView(o, snap.id, now); // already final
    tx.update(ref, { status: 'cancelled', cancelledAt: now });
    tx.delete(db.doc(`${PENDING}/${uid}`));
    return orderView({ ...o, status: 'cancelled' }, snap.id, now);
  });
}

function creditMail({ uid, code, pack, amount, now }) {
  return {
    title: MAIL_TITLE,
    body:
      `Cảm ơn bạn đã nạp ${amount.toLocaleString('vi-VN')}đ. ` +
      `${pack.phaLe} Pha lê đã sẵn sàng, nhận ngay nhé! Mã đơn: ${code}.`,
    target: uid,
    rewards: { items: [{ kind: 'phaLe', amount: pack.phaLe }] },
    createdAt: now,
  };
}

/**
 * One money-in event from SePay: {txnId, amount, code, source, raw?}.
 * Returns a result string (also stored on sepay_txns/{txnId}):
 *   credited | duplicate | no_order | order_already_paid | cancelled_order |
 *   late | lech_goi
 * Only `credited` pays. Everything runs in ONE transaction: the txn doc, the
 * order, the pointer and the mail either all land or none does, so a retry
 * (SePay retries on any non-200) or two IPNs at once cannot pay twice.
 */
async function handlePayment({ db, eco, event, now, cfg = {}, logger = console }) {
  const c = { ...DEFAULTS, ...cfg };
  // The id is a document id: letters, digits, _ and - only.
  const txnId = String(event.txnId || '').replace(/[^A-Za-z0-9_-]/g, '_');
  const amount = Math.round(Number(event.amount));
  if (!txnId || !Number.isFinite(amount) || amount <= 0) throw new TopupError('bad_event', 400);
  const code = event.code ? String(event.code).toUpperCase() : null;
  const packs = packTable(eco);
  const result = await db.runTransaction(async (tx) => {
    const txnRef = db.doc(`${TXNS}/${txnId}`);
    const orderRef = code ? db.doc(`${ORDERS}/${code}`) : null;
    const txnSnap = await tx.get(txnRef);
    if (txnSnap.exists) return 'duplicate';
    const orderSnap = orderRef ? await tx.get(orderRef) : null;
    const record = (res, extra = {}) =>
      tx.create(txnRef, {
        txnId, amount, code, source: event.source || 'ipn', result: res,
        orderId: orderSnap && orderSnap.exists ? orderSnap.id : null,
        receivedAt: now, ...extra,
      });
    if (!orderSnap || !orderSnap.exists) {
      record('no_order');
      return 'no_order';
    }
    const o = orderSnap.data();
    const flag = (patch) => tx.update(orderRef, patch);
    if (o.status === 'paid') {
      record('order_already_paid', { uid: o.uid });
      flag({ extraTxnIds: [...(o.extraTxnIds || []), txnId] });
      return 'order_already_paid';
    }
    if (o.status === 'cancelled') {
      record('cancelled_order', { uid: o.uid });
      flag({ lateTxnId: txnId, lateAmount: amount });
      return 'cancelled_order';
    }
    const expires = toDate(o.expiresAt);
    if (expires && now.getTime() > expires.getTime() + c.graceSeconds * 1000) {
      record('late', { uid: o.uid });
      flag({ status: 'expired', lateTxnId: txnId, lateAmount: amount });
      tx.delete(db.doc(`${PENDING}/${o.uid}`));
      return 'late';
    }
    const pack = packByAmount(packs, amount); // Pha lê comes from the AMOUNT
    if (!pack) {
      record('lech_goi', { uid: o.uid });
      flag({ status: 'lech_goi', sepayTxnId: txnId, receivedAmount: amount });
      tx.delete(db.doc(`${PENDING}/${o.uid}`));
      return 'lech_goi';
    }
    const mailId = `phale_${orderSnap.id}`;
    record('credited', { uid: o.uid, packId: pack.id, crystals: pack.phaLe, mailId });
    flag({
      status: 'paid', sepayTxnId: txnId, paidAt: now, packId: pack.id,
      orderedPackId: o.packId, crystals: pack.phaLe, amount,
      crystalsGranted: pack.phaLe, mailId,
    });
    tx.create(db.doc(`mails/${mailId}`), creditMail({ uid: o.uid, code: orderSnap.id, pack, amount, now }));
    tx.delete(db.doc(`${PENDING}/${o.uid}`));
    return 'credited';
  });
  logger.info('sepay payment', { txnId, code, amount, source: event.source, result });
  return result;
}

module.exports = {
  ORDERS, PENDING, TXNS, DEFAULTS, MAIL_TITLE, TopupError,
  packTable, packByAmount, newCode, findCode, qrUrl, orderView,
  createOrder, orderStatus, cancelOrder, handlePayment,
};