'use strict';
// Bank (SePay) refund, marked by the admin on /quan-tri ("Hoàn tiền"): the
// admin client sets refundedAt / refundedBy on a paid phale_orders doc
// (firestore.rules allow only that). The vipOnOrder trigger then
//   1. takes the order's Pha lê back exactly like an App Store refund
//      (apple_iap.js takeBack: void the credit mail if unclaimed, else take it
//      from the server wallet or the save, never below 0, the rest is debt),
//   2. recomputes the VIP tier (vip.js; a refunded order no longer counts).
// Once per order: the result is written as clawback / phaleTaken / phaleDebt.
const { takeBack } = require('./apple_iap');

const int = (v) => (Number.isFinite(Number(v)) ? Math.max(0, Math.floor(Number(v))) : 0);

/** True when this write is the admin's refund mark, not yet acted on. */
function needsClawback(after) {
  return !!(after && after.status === 'paid' && after.refundedAt && !after.clawback);
}

async function applyBankRefund({ db, code, now }) {
  if (!code || typeof code !== 'string' || code.includes('/')) return { result: 'bad' };
  return db.runTransaction(async (tx) => {
    const ref = db.doc(`phale_orders/${code}`);
    const snap = await tx.get(ref);
    if (!snap.exists) return { result: 'missing' };
    const o = snap.data();
    if (!needsClawback(o)) return { result: o.clawback ? 'already' : 'not-refunded' };
    const mailId = typeof o.mailId === 'string' && o.mailId ? o.mailId : `phale_${code}`;
    if (!o.uid) {
      tx.update(ref, { clawback: 'none', phaleTaken: 0, phaleDebt: 0, clawbackAt: now });
      return { result: 'no-account' };
    }
    const amount = int(o.crystalsGranted != null ? o.crystalsGranted : o.crystals);
    const out = await takeBack({ tx, db, uid: o.uid, mailId, amount, now });
    tx.update(ref, { clawback: out.clawback, phaleTaken: out.taken, phaleDebt: out.debt, clawbackAt: now });
    return { result: out.clawback, taken: out.taken, debt: out.debt };
  });
}

module.exports = { needsClawback, applyBankRefund };
