'use strict';

const fs = require('fs');
const path = require('path');

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

function packForProduct(eco, productId) {
  const packId = PRODUCT_TO_PACK[productId];
  if (!packId) return null;
  const table = (eco.phaLeShop && eco.phaLeShop.packs) || [];
  return table.find((p) => p && p.id === packId && p.phaLe > 0) || null;
}

/**
 * Writes the Pha lê mail once per App Store transaction. [transaction] is
 * already verified (productId, transactionId, bundleId, revocationDate).
 * A second call with the same transaction id returns the first mail.
 */
async function creditApplePurchase({ db, eco, uid, transaction, now }) {
  const productId = String((transaction && transaction.productId) || '');
  const txnId = String((transaction && transaction.transactionId) || '')
    .replace(/[^A-Za-z0-9_-]/g, '_');
  if (!uid || !txnId || transaction.bundleId !== BUNDLE_ID) {
    throw new AppleIapError('bad');
  }
  if (transaction.revocationDate) throw new AppleIapError('revoked');
  const pack = packForProduct(eco, productId);
  if (!pack) throw new AppleIapError('product');
  const mailId = `phale_iap_${txnId}`;
  const saved = await db.runTransaction(async (tx) => {
    const ref = db.doc(`phale_iap/${txnId}`);
    const snap = await tx.get(ref);
    if (snap.exists) {
      const row = snap.data();
      if (row.uid !== uid) throw new AppleIapError('owner');
      return row;
    }
    const row = {
      uid, packId: pack.id, productId, phaLe: pack.phaLe, mailId, createdAt: now,
    };
    tx.create(ref, row);
    tx.create(db.doc(`mails/${mailId}`), {
      title: 'Nạp Pha lê',
      body: `Cảm ơn bạn đã nạp qua App Store. ${pack.phaLe} Pha lê đã sẵn sàng, nhận ngay nhé!`,
      target: uid,
      rewards: { items: [{ kind: 'phaLe', amount: pack.phaLe }] },
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

function appleRootCerts() {
  const dir = path.join(__dirname, 'certs');
  return ['AppleRootCA-G3.cer', 'AppleRootCA-G2.cer'].map((name) =>
    fs.readFileSync(path.join(dir, name)));
}

/** Checks the StoreKit 2 signed transaction (JWS) against Apple's certificate. */
async function verifySignedTransaction(jws) {
  const { SignedDataVerifier, Environment } = require('@apple/app-store-server-library');
  const roots = appleRootCerts();
  const tryEnv = async (environment) => {
    const verifier = new SignedDataVerifier(
      roots,
      true,
      environment,
      BUNDLE_ID,
      environment === Environment.PRODUCTION ? APP_APPLE_ID : undefined,
    );
    return verifier.verifyAndDecodeTransaction(jws);
  };
  try {
    return await tryEnv(Environment.PRODUCTION);
  } catch (_) {
    return tryEnv(Environment.SANDBOX);
  }
}

module.exports = {
  BUNDLE_ID,
  PRODUCT_TO_PACK,
  AppleIapError,
  creditApplePurchase,
  verifySignedTransaction,
};
