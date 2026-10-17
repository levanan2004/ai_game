'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { refundRules } = require('./wallet');

const BUNDLE_ID = 'com.tiemhoasommai.game';
const APP_APPLE_ID = 6821925768;

/** Consumable product id -> economy.json pack id. */
const PRODUCT_TO_PACK = {
  'com.tiemhoasommai.game.phale.pack_10k': 'pack_10k',
  'com.tiemhoasommai.game.phale.pack_20k': 'pack_20k',
  'com.tiemhoasommai.game.phale.pack_50k': 'pack_50k',
  'com.tiemhoasommai.game.phale.pack_100k': 'pack_100k',
  'com.tiemhoasommai.game.phale.pack_200k': 'pack_200k',
  'com.tiemhoasommai.game.phale.pack_500k': 'pack_500k',
};

class AppleIapError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}

/**
 * Name-based UUID (version 5, SHA-1) of [uid]. The app passes it to StoreKit
 * as appAccountToken (lib/iap/phale_products.dart appAccountTokenFor, same
 * namespace), so a signed transaction names the account that paid.
 */
const ACCOUNT_TOKEN_NAMESPACE = 'a7c1e2b4-5d6f-4a89-b0c1-d2e3f4a5b6c7';

function appAccountTokenFor(uid) {
  const ns = Buffer.from(ACCOUNT_TOKEN_NAMESPACE.replace(/-/g, ''), 'hex');
  const h = crypto.createHash('sha1').update(ns).update(String(uid), 'utf8').digest();
  h[6] = (h[6] & 0x0f) | 0x50;
  h[8] = (h[8] & 0x3f) | 0x80;
  const x = h.subarray(0, 16).toString('hex');
  return `${x.slice(0, 8)}-${x.slice(8, 12)}-${x.slice(12, 16)}-${x.slice(16, 20)}-${x.slice(20)}`;
}

/** Firestore-safe doc id of an App Store transaction id. */
function txnDocId(id) {
  return String(id || '').replace(/[^A-Za-z0-9_-]/g, '_');
}

function packForProduct(eco, productId) {
  const packId = PRODUCT_TO_PACK[productId];
  if (!packId) return null;
  const table = (eco.phaLeShop && eco.phaLeShop.packs) || [];
  return table.find((p) => p && p.id === packId && p.phaLe > 0) || null;
}

const num = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : null);
const str = (v) => (typeof v === 'string' && v ? v : null);

/**
 * Writes the Pha lê mail once per App Store transaction. [transaction] is
 * already verified (productId, transactionId, bundleId, revocationDate).
 * A second call with the same transaction id returns the first mail.
 *
 * The record keeps what Apple says was paid (price in 1/1000 of [currency],
 * environment, storefront) and packPriceVnd, the VND list price of the pack,
 * so a "total topped up" can add App Store and bank (phale_orders.amount)
 * orders. Sandbox rows (TestFlight, App Review) are real credits but not
 * real money.
 */
async function creditApplePurchase({ db, eco, uid, transaction, now }) {
  const productId = String((transaction && transaction.productId) || '');
  const txnId = txnDocId(transaction && transaction.transactionId);
  if (!uid || !txnId || transaction.bundleId !== BUNDLE_ID) {
    throw new AppleIapError('bad');
  }
  if (transaction.revocationDate) throw new AppleIapError('revoked');
  // Bought while another account was signed in: that account gets it.
  const token = str(transaction.appAccountToken);
  if (token && token.toLowerCase() !== appAccountTokenFor(uid)) {
    throw new AppleIapError('account');
  }
  const pack = packForProduct(eco, productId);
  if (!pack) throw new AppleIapError('product');
  const mailId = `phale_iap_${txnId}`;
  const saved = await db.runTransaction(async (tx) => {
    const ref = db.doc(`phale_iap/${txnId}`);
    const snap = await tx.get(ref);
    if (snap.exists) {
      const row = snap.data();
      if (row.refundedAt) throw new AppleIapError('revoked');
      if (row.uid !== uid) throw new AppleIapError('owner');
      return row;
    }
    const purchaseDate = num(transaction.purchaseDate);
    const row = {
      uid,
      packId: pack.id,
      productId,
      phaLe: pack.phaLe,
      mailId,
      createdAt: now,
      packPriceVnd: num(pack.priceVnd),
      environment: str(transaction.environment),
      price: num(transaction.price),
      currency: str(transaction.currency),
      storefront: str(transaction.storefront),
      purchaseDate: purchaseDate === null ? null : new Date(purchaseDate),
      originalTransactionId: str(String(transaction.originalTransactionId || '')),
      appAccountToken: token,
    };
    tx.create(ref, row);
    tx.create(db.doc(`mails/${mailId}`), {
      title: 'Nạp Pha lê',
      body: `Cảm ơn bạn đã nạp qua App Store. ${pack.phaLe} Pha lê đã sẵn sàng, nhận ngay nhé!`,
      target: uid,
      rewards: { items: [{ kind: 'phaLe', amount: pack.phaLe }] },
      walletClaim: true, // claimed through walletClaimMail (wallet.js)
      createdAt: now,
    });
    return row;
  });
  return {
    mailId: saved.mailId,
    phaLe: saved.phaLe,
    transactionId: txnId,
    packId: saved.packId,
  };
}

/** Notification types that take a purchase back (refund, Family Sharing revoke). */
const CLAWBACK_TYPES = new Set(['REFUND', 'REVOKE']);

/**
 * Takes back the Pha lê of a refunded / revoked App Store transaction, once.
 *   - mail not claimed yet: the mail is voided (expiresAt = now, so the
 *     mailbox hides it and firestore.rules refuse the claim).
 *   - mail claimed: the Pha lê is subtracted from wallets/{uid}.phaLe (the
 *     server wallet, wallet.js), or, for an account without one yet, from the save
 *     (users/{uid}.progress.phaLe), never below 0; what could not be taken is
 *     kept as phaleDebt on the phale_iap row for the admin and as
 *     wallets/{uid}.phaLeDebt (no Pha lê spend until it is paid off).
 *   - no row yet (refund before the app reached the server): a refunded row
 *     is written so a later credit is refused.
 * A second notification for the same transaction changes nothing.
 * Note: an open game tab still holds the old balance and its next save puts
 * it back; the row keeps phaleTaken / phaleDebt so the admin can check.
 */
async function applyAppleRefund({ db, eco, transaction, notificationType, now }) {
  const txnId = txnDocId(transaction && transaction.transactionId);
  if (!txnId) return { result: 'bad' };
  return db.runTransaction(async (tx) => {
    const ref = db.doc(`phale_iap/${txnId}`);
    const snap = await tx.get(ref);
    const refund = {
      refundedAt: now,
      refundType: notificationType,
      revocationReason: num(transaction.revocationReason),
    };
    if (!snap.exists) {
      tx.create(ref, {
        uid: null,
        productId: String(transaction.productId || ''),
        createdAt: now,
        uncredited: true,
        ...refund,
      });
      return { result: 'uncredited' };
    }
    const row = snap.data();
    if (row.refundedAt) return { result: 'already' };
    if (!row.uid || !row.mailId) {
      tx.update(ref, { ...refund, clawback: 'none', phaleTaken: 0, phaleDebt: 0 });
      return { result: 'no-account' };
    }
    const amount = Math.max(0, Number(row.phaLe) || 0);
    const out = await takeBack({ tx, db, eco, uid: row.uid, mailId: row.mailId, amount, now });
    tx.update(ref, { ...refund, clawback: out.clawback, phaleTaken: out.taken, phaleDebt: out.debt });
    return out.clawback === 'mail_voided'
      ? { result: 'mail_voided' }
      : { result: out.clawback, taken: out.taken, debt: out.debt };
  });
}

/**
 * Takes [amount] Pha lê of one credit mail back inside [tx] (all reads first,
 * then the writes), the same way for an App Store refund and a bank refund
 * (bank_refund.js):
 *   - mail not claimed yet: the mail is voided -> clawback 'mail_voided'.
 *   - claimed, server wallet seeded: from wallets/{uid}.phaLe -> 'wallet'.
 *   - claimed, no wallet yet: from users/{uid}.progress.phaLe -> 'balance'.
 * Never below 0; what could not be taken is the debt, kept as
 * wallets/{uid}.phaLeDebt (economy.json vip.refund): wallet.js pays it from
 * the next credits and refuses every Pha lê spend while it is open.
 * With vip.refund.clawBackPhaLe false nothing is touched (the mail stays
 * claimable, the balance stays) -> clawback 'off'.
 */
function debtOf(walletSnap) {
  return walletSnap.exists ? Math.max(0, Math.floor(Number(walletSnap.data().phaLeDebt) || 0)) : 0;
}

async function takeBack({ tx, db, eco, uid, mailId, amount, now }) {
  if (!refundRules(eco).clawBackPhaLe) return { clawback: 'off', taken: 0, debt: 0 };
  const mailRef = db.doc(`mails/${mailId}`);
  const markRef = db.doc(`users/${uid}/mailState/${mailId}`);
  const userRef = db.doc(`users/${uid}`);
  const walletRef = db.doc(`wallets/${uid}`);
  const [mail, mark, user, wallet] = [
    await tx.get(mailRef), await tx.get(markRef), await tx.get(userRef), await tx.get(walletRef)];
  const claimed = mark.exists && mark.data().claimed === true;
  if (!claimed) {
    if (mail.exists) tx.update(mailRef, { expiresAt: now, voidedAt: now, voidReason: 'refund' });
    return { clawback: 'mail_voided', taken: 0, debt: 0 };
  }
  if (wallet.exists && wallet.data().seededAt) {
    // The server wallet (wallet.js) is the balance once it is seeded (a doc
    // with only the VIP fields of vip.js is not a balance yet).
    const have = Math.max(0, Math.floor(Number(wallet.data().phaLe) || 0));
    const take = Math.min(have, amount);
    const debt = amount - take;
    if (take > 0 || debt > 0) {
      tx.update(walletRef, {
        phaLe: have - take,
        ...(debt > 0 ? { phaLeDebt: debtOf(wallet) + debt } : {}),
        updatedAt: now,
      });
    }
    return { clawback: 'wallet', taken: take, debt };
  }
  const progress = user.exists ? user.data().progress : null;
  const have = progress && typeof progress === 'object'
    ? Math.max(0, Math.floor(Number(progress.phaLe) || 0))
    : 0;
  const take = Math.min(have, amount);
  if (take > 0) {
    tx.update(userRef, { progress: { ...progress, phaLe: have - take }, updatedAt: now });
  }
  const debt = amount - take;
  // The wallet seeds later from the save and keeps this field (loadWallet).
  if (debt > 0) tx.set(walletRef, { phaLeDebt: debtOf(wallet) + debt, updatedAt: now }, { merge: true });
  return { clawback: 'balance', taken: take, debt };
}

/**
 * HTTP handler of App Store Server Notifications V2 (POST {signedPayload}).
 * [verify] is verifyNotification (a stub in tests). 200 tells Apple to stop
 * retrying: a bad signature gets 401, a failure to apply gets 500 (retried).
 */
function appleNotificationHandler({ db, verify, now, logger, eco }) {
  return async (req, res) => {
    if (req.method !== 'POST') return res.status(405).json({ error: 'method' });
    const payload = req.body && req.body.signedPayload;
    if (typeof payload !== 'string' || payload.length < 20) {
      return res.status(400).json({ error: 'bad' });
    }
    let note;
    try {
      note = await verify(payload);
    } catch (e) {
      logger.warn('apple notification rejected', { message: e && e.message });
      return res.status(401).json({ error: 'signature' });
    }
    const t = note.transaction;
    if (!CLAWBACK_TYPES.has(note.notificationType) || !t || !packForProduct(eco, t.productId)) {
      return res.status(200).json({ ok: true, ignored: note.notificationType || null });
    }
    try {
      const out = await applyAppleRefund({
        db, eco, transaction: t, notificationType: note.notificationType, now: now(),
      });
      logger.info('apple refund', { type: note.notificationType, txn: txnDocId(t.transactionId), ...out });
      return res.status(200).json({ ok: true, ...out });
    } catch (e) {
      logger.error('apple refund failed', { message: e && e.message });
      return res.status(500).json({ error: 'server' });
    }
  };
}

function appleRootCerts() {
  const dir = path.join(__dirname, 'certs');
  return ['AppleRootCA-G3.cer', 'AppleRootCA-G2.cer'].map((name) =>
    fs.readFileSync(path.join(dir, name)));
}

/** Production first, then sandbox (TestFlight and App Review buy in sandbox). */
async function verifyBoth(call) {
  const { SignedDataVerifier, Environment } = require('@apple/app-store-server-library');
  const roots = appleRootCerts();
  const verifier = (environment) => new SignedDataVerifier(
    roots,
    true,
    environment,
    BUNDLE_ID,
    environment === Environment.PRODUCTION ? APP_APPLE_ID : undefined,
  );
  try {
    return await call(verifier(Environment.PRODUCTION));
  } catch (_) {
    return call(verifier(Environment.SANDBOX));
  }
}

/** Checks the StoreKit 2 signed transaction (JWS) against Apple's certificate. */
function verifySignedTransaction(jws) {
  return verifyBoth((v) => v.verifyAndDecodeTransaction(jws));
}

/**
 * Checks an App Store Server Notification V2 (`signedPayload`) and the
 * signed transaction inside it. Returns { notificationType, subtype,
 * transaction } (transaction null when the notification carries none).
 */
async function verifyNotification(signedPayload) {
  return verifyBoth(async (v) => {
    const n = await v.verifyAndDecodeNotification(signedPayload);
    const signed = n && n.data && n.data.signedTransactionInfo;
    return {
      notificationType: n && n.notificationType,
      subtype: (n && n.subtype) || null,
      transaction: signed ? await v.verifyAndDecodeTransaction(signed) : null,
    };
  });
}

module.exports = {
  BUNDLE_ID,
  PRODUCT_TO_PACK,
  AppleIapError,
  appAccountTokenFor,
  txnDocId,
  creditApplePurchase,
  takeBack,
  applyAppleRefund,
  appleNotificationHandler,
  verifySignedTransaction,
  verifyNotification,
};
