'use strict';
// Server side of the Mị lực board (NOT deployed from this repo's CI; see
// functions/README.md). All functions use the Admin SDK, so they are not
// bound by firestore.rules.
//
//  verifyCharmEntry   runs when a player writes charm_board/{period}/entries/{uid}
//                     and compares the row with users/{uid}.progress.
//  sweepCharmBoard    every 30 minutes re-checks the top rows of the live period
//                     (catches an edit made while the trigger was down).
//  payoutCharmBoard   every 10 minutes: creates the season meta docs, and once a
//                     season is over (endsAt + 5 min) recomputes the board and
//                     writes the reward mails. See payout.js.
//
// CHARM_MODE (env, default "fix"):
//   fix  lower a row to what the save backs, or delete it under the minimum
//        (every mismatch is also logged for the admin)
//   log  only write the warning to Cloud Logging, change nothing

const admin = require('firebase-admin');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const { loadEconomy } = require('./charm');
const { modeFromEnv, checkEntry } = require('./verify');
const { runPayout } = require('./payout');

admin.initializeApp();
const db = admin.firestore();
const eco = loadEconomy(require('./economy.json'));
const REGION = 'asia-southeast1';

const check = (period, uid, entry, ref) => checkEntry({
  db, eco, period, uid, entry, ref, mode: modeFromEnv(process.env),
  now: new Date(), logger,
});

exports.verifyCharmEntry = onDocumentWritten(
  { document: 'charm_board/{period}/entries/{uid}', region: REGION },
  async (event) => {
    const after = event.data && event.data.after;
    if (!after || !after.exists) return; // a delete needs no check
    // Our own fix lowers the charm to a value the save backs, so the second
    // pass finds the row ok and stops (no loop).
    await check(event.params.period, event.params.uid, after.data(), after.ref);
  },
);

exports.sweepCharmBoard = onSchedule(
  { schedule: 'every 30 minutes', region: REGION, timeZone: 'Asia/Ho_Chi_Minh' },
  async () => {
    const rows = await db
      .collection('charm_board').doc(eco.periodKey).collection('entries')
      .orderBy('charm', 'desc').limit(100).get();
    let bad = 0;
    for (const doc of rows.docs) {
      if ((await check(eco.periodKey, doc.id, doc.data(), doc.ref)) !== 'ok') bad++;
    }
    logger.info('charm board sweep', { period: eco.periodKey, rows: rows.size, mismatched: bad });
  },
);

/** Account creation times from Firebase Auth (100 uids per call). */
async function authCreated(uids) {
  const out = new Map();
  for (let i = 0; i < uids.length; i += 100) {
    const res = await admin.auth().getUsers(uids.slice(i, i + 100).map((uid) => ({ uid })));
    for (const u of res.users) {
      const t = u.metadata && u.metadata.creationTime;
      if (t) out.set(u.uid, new Date(t));
    }
  }
  return out;
}

exports.payoutCharmBoard = onSchedule(
  { schedule: 'every 10 minutes', region: REGION, timeZone: 'Asia/Ho_Chi_Minh', timeoutSeconds: 540 },
  async () => {
    const result = await runPayout({
      db, eco, now: new Date(), random: Math.random, authCreated, logger,
    });
    logger.info('charm payout tick', result);
  },
);

// ---------------------------------------------------------------------------
// Pha lê top-up by bank transfer (SePay). Logic: topup.js, sepay.js,
// topup_http.js. NOT deployed from this repo; see README "Pha lê top-up".
//
//  sepayIpn            Cổng thanh toán IPN  (header X-Secret-Key)
//  sepayBankWebhook    bank-transaction webhook (Authorization: Apikey / HMAC)
//  phaleCreateOrder    app -> new order (or the open one)      POST {packId}
//  phaleOrderStatus    app -> reads the order doc only         GET ?orderId=
//  phaleCancelOrder    app -> "Hủy đơn"                        POST {orderId}
// Secrets (firebase functions:secrets:set): SEPAY_SECRET_KEY, SEPAY_API_KEY,
// SEPAY_MERCHANT_ID (kept for later API calls; not read by this code).
// Settings (functions/.env.<project>): SEPAY_BANK_NAME, SEPAY_BANK_CODE,
// SEPAY_ACCOUNT_NO, SEPAY_ACCOUNT_NAME, SEPAY_CODE_PREFIX.
// ---------------------------------------------------------------------------
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');
const { paymentHandler, playerHandler } = require('./topup_http');

const SEPAY_SECRET_KEY = defineSecret('SEPAY_SECRET_KEY');
const SEPAY_API_KEY = defineSecret('SEPAY_API_KEY');
const SEPAY_MERCHANT_ID = defineSecret('SEPAY_MERCHANT_ID');
const BANK_NAME = defineString('SEPAY_BANK_NAME', { default: '' });
const BANK_CODE = defineString('SEPAY_BANK_CODE', { default: '' });
const ACCOUNT_NO = defineString('SEPAY_ACCOUNT_NO', { default: '' });
const ACCOUNT_NAME = defineString('SEPAY_ACCOUNT_NAME', { default: '' });
const CODE_PREFIX = defineString('SEPAY_CODE_PREFIX', { default: 'THSM' });

const topupEco = { phaLeShop: require('./economy.json').phaLeShop };
const topupCfg = () => ({ codePrefix: CODE_PREFIX.value() });
const topupBank = () => ({
  name: BANK_NAME.value(), code: BANK_CODE.value(),
  accountNo: ACCOUNT_NO.value(), accountName: ACCOUNT_NAME.value(),
});
// The second lock: config/phaleShop.open must be true (admin sets it) or no
// order can be made, whatever the app's economy.json says.
const shopIsOpen = async () => {
  const s = await db.doc('config/phaleShop').get();
  return s.exists && s.data().open === true;
};
const payment = (kind) => paymentHandler({
  kind, db, eco: topupEco, now: () => new Date(), cfg: topupCfg(), logger,
  getSecrets: () => ({ secretKey: SEPAY_SECRET_KEY.value(), apiKey: SEPAY_API_KEY.value() }),
});
const player = (action) => playerHandler({
  action, db, eco: topupEco, now: () => new Date(), cfg: topupCfg(), logger,
  bank: topupBank(), isOpen: shopIsOpen,
  verify: async (token) => (await admin.auth().verifyIdToken(token)).uid,
});

exports.sepayIpn = onRequest(
  { region: REGION, secrets: [SEPAY_SECRET_KEY], timeoutSeconds: 30 },
  (req, res) => payment('ipn')(req, res),
);
exports.sepayBankWebhook = onRequest(
  { region: REGION, secrets: [SEPAY_API_KEY, SEPAY_SECRET_KEY], timeoutSeconds: 30 },
  (req, res) => payment('bank')(req, res),
);
exports.phaleCreateOrder = onRequest(
  { region: REGION, cors: true }, (req, res) => player('create')(req, res));
exports.phaleOrderStatus = onRequest(
  { region: REGION, cors: true }, (req, res) => player('status')(req, res));
exports.phaleCancelOrder = onRequest(
  { region: REGION, cors: true }, (req, res) => player('cancel')(req, res));
void SEPAY_MERCHANT_ID;