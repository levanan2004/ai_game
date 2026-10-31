'use strict';
// Server side of the Mị lực board (NOT deployed from this repo's CI; see
// functions/README.md). All functions use the Admin SDK, so they are not
// bound by firestore.rules.
//
//  verifyCharmEntry   runs when a player writes charm_board/{period}/entries/{uid}
//                     and compares the row with users/{uid}.progress.
//  sweepCharmBoard    every 30 minutes re-checks the top rows of the live period
//                     (catches an edit made while the trigger was down).
//                     It also refreshes public_profiles/{uid} (profile card).
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

// Cap every function at 10 instances. Gen 2 defaults to 100 x 1 vCPU each, and a
// deploy of ~30 functions ran into the regional Cloud Run CPU quota
// ("Quota exceeded for total allowable CPU per project per region").
// The region's CPU quota is capped at 20 vCPU (Google refused more), so every
// function also runs on 'gcf_gen1' CPU (a fraction of a vCPU sized by memory,
// as on 1st gen). With less than 1 vCPU each instance takes one request at a
// time. No function sets its own maxInstances, cpu, memory or concurrency.
require('firebase-functions/v2').setGlobalOptions({ maxInstances: 10, cpu: 'gcf_gen1' });

const check = (period, uid, entry, ref, profile = false) => checkEntry({
  db, eco, period, uid, entry, ref, mode: modeFromEnv(process.env),
  now: new Date(), logger, profile,
});

exports.verifyCharmEntry = onDocumentWritten(
  { document: 'charm_board/{period}/entries/{uid}', region: REGION },
  async (event) => {
    const after = event.data && event.data.after;
    if (!after || !after.exists) return; // a delete needs no check
    // Our own fix lowers the charm to a value the save backs, so the second
    // pass finds the row ok and stops (no loop).
    await check(event.params.period, event.params.uid, after.data(), after.ref, true);
  },
);

exports.sweepCharmBoard = onSchedule(
  { schedule: 'every 30 minutes', region: REGION, timeZone: 'Asia/Ho_Chi_Minh' },
  async () => {
    // The live season on the shared clock (season.js), not a fixed key.
    const period = eco.periodAt(new Date());
    const rows = await db
      .collection('charm_board').doc(period).collection('entries')
      .orderBy('charm', 'desc').limit(100).get();
    let bad = 0;
    for (const doc of rows.docs) {
      if ((await check(period, doc.id, doc.data(), doc.ref)) !== 'ok') bad++;
    }
    logger.info('charm board sweep', { period, rows: rows.size, mismatched: bad });
  },
);

// Save guard (save_guard.js): every cloud save is checked against Hà
// Phương's anti-cheat thresholds; a save over them is reverted and the
// account flagged (off both boards, no season reward).
const saveGuard = require('./save_guard');

exports.guardSave = onDocumentWritten(
  { document: 'users/{uid}', region: REGION },
  async (event) => {
    const after = event.data && event.data.after;
    if (!after || !after.exists) return;
    const before = event.data.before && event.data.before.exists ? event.data.before.data() : null;
    const created = async (uid) => (await authCreated([uid])).get(uid) || null;
    await saveGuard.guard({
      db, uid: event.params.uid, before, after: after.data(), now: new Date(), logger, authCreated: created,
    });
  },
);

// Bảng xếp hạng Đánh giá (rating_board.js): each cloud save counts the
// reviews of the game days it finished; only the server writes the board.
const rating = require('./rating_board');
const ratingFilter = require('./word_filter').defaultFilter();

exports.ingestRatingReviews = onDocumentWritten(
  { document: 'users/{uid}', region: REGION },
  async (event) => {
    const after = event.data && event.data.after;
    if (!after || !after.exists) return;
    const progress = after.data().progress;
    if (!progress || typeof progress !== 'object') return;
    const out = await rating.ingest({
      db, eco: require('./economy.json'), uid: event.params.uid, progress,
      now: new Date(), filter: ratingFilter, logger,
    });
    if (out.counted) logger.info('rating reviews counted', { uid: event.params.uid, counted: out.counted });
  },
);

// Danh hiệu mốc khách (milestones.js): each cloud save counts the customers
// served since the last one; reaching 1k/10k/100k gives a permanent title.
const milestones = require('./milestones');

exports.countMilestoneCustomers = onDocumentWritten(
  { document: 'users/{uid}', region: REGION },
  async (event) => {
    const after = event.data && event.data.after;
    if (!after || !after.exists) return;
    const progress = after.data().progress;
    if (!progress || typeof progress !== 'object') return;
    const out = await milestones.ingest({
      db, eco: require('./economy.json'), uid: event.params.uid, progress, now: new Date(), logger,
    });
    if (out.awarded.length) logger.info('milestone titles', { uid: event.params.uid, awarded: out.awarded });
  },
);

exports.refreshRatingBoard = onSchedule(
  { schedule: 'every 15 minutes', region: REGION, timeZone: 'Asia/Ho_Chi_Minh', timeoutSeconds: 300 },
  async () => {
    const out = await rating.refresh({ db, eco: require('./economy.json'), now: new Date(), logger });
    logger.info('rating board refresh', out);
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
      db, eco, now: new Date(), authCreated, logger,
    });
    logger.info('charm payout tick', result);
  },
);

// Season payout of Bảng Đánh giá (rating_payout.js): same flow, switch and
// admin release as the Mị lực payout, Hà Phương's ratingBoard.rewards.
const { runRatingPayout } = require('./rating_payout');

exports.payoutRatingBoard = onSchedule(
  { schedule: 'every 10 minutes', region: REGION, timeZone: 'Asia/Ho_Chi_Minh', timeoutSeconds: 540 },
  async () => {
    const result = await runRatingPayout({
      db, eco: require('./economy.json'), now: new Date(), authCreated, logger,
    });
    logger.info('rating payout tick', result);
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

// vip.refund: the App Store refund handler honours clawBackPhaLe.
const topupEco = {
  phaLeShop: require('./economy.json').phaLeShop,
  vip: { refund: require('./economy.json').vip.refund },
};
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
  // checkRevoked = true also refuses the token of a user that was deleted (a
  // deleted account's ID token stays valid for up to an hour otherwise).
  verify: async (token) => (await admin.auth().verifyIdToken(token, true)).uid,
});

// The 5 HTTP functions must be reachable without a Google identity (SePay and the
// app are not Google principals), so Cloud Run invoker is public. Every one of
// them still checks its own credential in the handler (secret / API key / ID
// token) and answers 401/400/405 itself; 'public' only lifts the platform's 403.
exports.sepayIpn = onRequest(
  { region: REGION, invoker: 'public', secrets: [SEPAY_SECRET_KEY], timeoutSeconds: 30 },
  (req, res) => payment('ipn')(req, res),
);
exports.sepayBankWebhook = onRequest(
  { region: REGION, invoker: 'public', secrets: [SEPAY_API_KEY, SEPAY_SECRET_KEY], timeoutSeconds: 30 },
  (req, res) => payment('bank')(req, res),
);
exports.phaleCreateOrder = onRequest(
  { region: REGION, invoker: 'public', cors: true }, (req, res) => player('create')(req, res));
exports.phaleOrderStatus = onRequest(
  { region: REGION, invoker: 'public', cors: true }, (req, res) => player('status')(req, res));
exports.phaleCancelOrder = onRequest(
  { region: REGION, invoker: 'public', cors: true }, (req, res) => player('cancel')(req, res));
void SEPAY_MERCHANT_ID;

// ---------------------------------------------------------------------------
// Account deletion (App Store / Google Play). Logic and the list of what is
// deleted, anonymized and kept: delete_account.js. Callable: the app calls it
// with the signed-in player's ID token; request.auth.uid is the ONLY account it
// ever touches. invoker 'public' only lifts the platform's 403 so the browser's
// preflight and the call reach the handler, which refuses anyone without auth.
//   firebase deploy --only functions:deleteAccount
// ---------------------------------------------------------------------------
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { deleteAccount, DeleteBlockedError, DeletePartialError } = require('./delete_account');

// ---------------------------------------------------------------------------
// Pha lê via App Store In-App Purchase (iOS). The app sends the StoreKit 2
// signed transaction. This checks it with Apple and writes the same kind of
// Pha lê mail as a bank top-up. The app never adds Pha lê itself.
//   firebase deploy --only functions:phaleApplePurchase
// ---------------------------------------------------------------------------
const {
  creditApplePurchase, verifySignedTransaction, verifyNotification, appleNotificationHandler, AppleIapError,
} = require('./apple_iap');

exports.phaleApplePurchase = onCall(
  { region: REGION, invoker: 'public', cors: true, timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'sign-in-required');
    }
    const jws = request.data && request.data.signedTransaction;
    if (typeof jws !== 'string' || jws.length < 20) {
      throw new HttpsError('invalid-argument', 'bad');
    }
    let transaction;
    try {
      transaction = await verifySignedTransaction(jws);
    } catch (e) {
      logger.warn('apple transaction rejected', { message: e && e.message });
      throw new HttpsError('permission-denied', 'apple');
    }
    try {
      return await creditApplePurchase({
        db, eco: topupEco, uid: request.auth.uid, transaction, now: new Date(), logger,
      });
    } catch (e) {
      if (e instanceof AppleIapError) throw new HttpsError('failed-precondition', e.code);
      logger.error('apple credit failed', { message: e && e.message });
      throw new HttpsError('internal', 'server');
    }
  },
);

// App Store Server Notifications V2 (refunds). Apple is not a Google principal,
// so invoker is public; the handler accepts only a payload signed by Apple
// (same certs, bundle id and app id as above) and answers 401 otherwise.
// Set this URL (production and sandbox) in App Store Connect > App Information:
//   https://asia-southeast1-tiem-hoa-som-mai.cloudfunctions.net/appleNotifications
//   firebase deploy --only functions:appleNotifications
exports.appleNotifications = onRequest(
  { region: REGION, invoker: 'public', timeoutSeconds: 30 },
  (req, res) => appleNotificationHandler({
    db, verify: verifyNotification, now: () => new Date(), logger, eco: topupEco,
  })(req, res),
);

exports.deleteAccount = onCall(
  { region: REGION, invoker: 'public', cors: true, timeoutSeconds: 120 },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'sign-in-required');
    }
    const bucketName = admin.app().options.storageBucket
      || `${process.env.GCLOUD_PROJECT}.firebasestorage.app`;
    try {
      return await deleteAccount({
        db, auth: admin.auth(), bucket: admin.storage().bucket(bucketName),
        uid: request.auth.uid, now: new Date(), logger,
      });
    } catch (e) {
      if (e instanceof DeleteBlockedError) throw new HttpsError('failed-precondition', 'order-pending');
      if (e instanceof DeletePartialError) throw new HttpsError('internal', 'partial');
      logger.error('delete account failed', { code: (e && e.code) || null });
      throw new HttpsError('internal', 'server');
    }
  },
);

// ---------------------------------------------------------------------------
// Pha lê wallet + Vòng quay tuần (wallet.js, gacha.js). wallets/{uid} holds the
// Pha lê balance, Thẻ gacha per Sơn Hải pot and the pity counters; only these
// functions write it (firestore.rules). Every Pha lê spend is checked and
// taken here in one transaction. uid always comes from the auth token.
//   firebase deploy --only functions:walletSync,functions:walletClaimMail,functions:walletEarn,functions:phaleBuy,functions:phaleExchange,functions:gachaBuyCards,functions:gachaSpin
// ---------------------------------------------------------------------------
const wallet = require('./wallet');
const walletEco = require('./economy.json');

/** One callable per wallet operation; WalletError codes go back as the message. */
// The calls a player waits on (sign-in wallet read, buying, gacha, the frame
// list): a full vCPU and 80 requests per instance instead of the global
// gcf_gen1 / one request at a time, capped at 2 instances each.
const HOT = { cpu: 1, concurrency: 80, maxInstances: 2 };

function walletCallable(op, opts = {}) {
  return onCall(
    { region: REGION, invoker: 'public', cors: true, timeoutSeconds: 30, ...opts },
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError('unauthenticated', 'sign-in-required');
      }
      try {
        const uid = request.auth.uid;
        return await op({
          db, eco: walletEco, uid, now: new Date(), data: request.data || {},
          // Auth creation time, read only when a first wallet is seeded
          // (phaLeMigration: freePerDayAllowance Pha lê per account day).
          accountCreated: async () => (await authCreated([uid])).get(uid) || null,
          // The shop name of the VIP hall row (walletSync backfill, vip.js).
          filter: defaultFilter(),
        });
      } catch (e) {
        if (e instanceof wallet.WalletError) throw new HttpsError('failed-precondition', e.code);
        logger.error('wallet call failed', { message: e && e.message });
        throw new HttpsError('internal', 'server');
      }
    },
  );
}

// ---------------------------------------------------------------------------
// Tin thế giới (world_chat.js). The app never writes world_chat: it calls
// these, and the rules refuse every client write except an admin's delete.
//   firebase deploy --only functions:worldChatSend,functions:worldChatReport
// ---------------------------------------------------------------------------
const worldChat = require('./world_chat');
const { defaultFilter, defaultWordList } = require('./word_filter');
const OWNER_UIDS = ['rFdE3O7LLBZIu0msxtvGktXmfJp1']; // firestore.rules adminUids()

/** An owner uid or an admins/{uid} doc, like isAdmin() in firestore.rules. */
async function isChatAdmin(uid) {
  if (OWNER_UIDS.includes(uid)) return true;
  return (await db.doc(`admins/${uid}`).get()).exists;
}

function chatCallable(op) {
  return onCall(
    { region: REGION, invoker: 'public', cors: true, timeoutSeconds: 30 },
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError('unauthenticated', 'sign-in-required');
      }
      try {
        return await op({
          db, eco: walletEco, uid: request.auth.uid, now: new Date(),
          data: request.data || {}, filter: defaultFilter(), words: defaultWordList(),
          isAdmin: isChatAdmin,
        });
      } catch (e) {
        if (e instanceof worldChat.ChatError) {
          throw new HttpsError('failed-precondition', e.code, e.extra);
        }
        logger.error('world chat call failed', { message: e && e.message });
        throw new HttpsError('internal', 'server');
      }
    },
  );
}

exports.worldChatSend = chatCallable(worldChat.send);
exports.worldChatReport = chatCallable(worldChat.report);

// ---------------------------------------------------------------------------
// Khung avatar (avatar_frames.js). player_avatars/{uid}.frame is written only
// here, after checking the player owns the frame (rules refuse an app write).
//   firebase deploy --only functions:avatarFrameList,functions:avatarFrameEquip
// ---------------------------------------------------------------------------
const frames = require('./avatar_frames');

function frameCallable(op, opts = {}) {
  return onCall(
    { region: REGION, invoker: 'public', cors: true, timeoutSeconds: 30, ...opts },
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError('unauthenticated', 'sign-in-required');
      }
      try {
        return await op({
          db, eco: walletEco, uid: request.auth.uid, now: new Date(), data: request.data || {},
        });
      } catch (e) {
        if (e instanceof frames.FrameError) throw new HttpsError('failed-precondition', e.code);
        logger.error('avatar frame call failed', { message: e && e.message });
        throw new HttpsError('internal', 'server');
      }
    },
  );
}

exports.avatarFrameList = frameCallable(frames.list, HOT);
exports.avatarFrameEquip = frameCallable(frames.equip);

// Khung tin nhắn (chat_frames.js): player_avatars/{uid}.chatFrame is written
// only here, after checking VIP max / the title held (rules refuse an app write).
//   firebase deploy --only functions:chatFrameEquip
const chatFrames = require('./chat_frames');
exports.chatFrameEquip = onCall(
  { region: REGION, invoker: 'public', cors: true, timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'sign-in-required');
    }
    try {
      return await chatFrames.equip({
        db, eco: walletEco, uid: request.auth.uid, now: new Date(), data: request.data || {},
      });
    } catch (e) {
      if (e instanceof chatFrames.ChatFrameError) throw new HttpsError('failed-precondition', e.code);
      logger.error('chat frame call failed', { message: e && e.message });
      throw new HttpsError('internal', 'server');
    }
  },
);

// ---------------------------------------------------------------------------
// Danh hiệu (titles.js). titles/{titleId} and public_profiles' titleStats /
// pinnedTitle are written only by functions: the payouts move a champion
// title, titlePin wears one the player holds now, titleRelease (admin) gives
// it to a held #1 after "Duyệt thưởng".
//   firebase deploy --only functions:titlePin,functions:titleRelease
// ---------------------------------------------------------------------------
const titles = require('./titles');

function titleCallable(op) {
  return onCall(
    { region: REGION, invoker: 'public', cors: true, timeoutSeconds: 30 },
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError('unauthenticated', 'sign-in-required');
      }
      try {
        return await op({
          db, eco: walletEco, uid: request.auth.uid, now: new Date(),
          data: request.data || {}, isAdmin: isChatAdmin,
        });
      } catch (e) {
        if (e instanceof titles.TitleError) throw new HttpsError('failed-precondition', e.code);
        logger.error('title call failed', { message: e && e.message });
        throw new HttpsError('internal', 'server');
      }
    },
  );
}

exports.titlePin = titleCallable(titles.pin);
exports.titleRelease = titleCallable(titles.release);

exports.walletSync = walletCallable(wallet.sync, HOT);
exports.walletClaimMail = walletCallable(wallet.claimMail);
exports.walletEarn = walletCallable(wallet.earn, HOT);
exports.phaleBuy = walletCallable(wallet.buy, HOT);
exports.coinBuy = walletCallable(wallet.coinBuy, HOT);
exports.phaleExchange = walletCallable(wallet.exchange);
exports.gachaBuyCards = walletCallable(wallet.buyCards, HOT);
exports.gachaSpin = walletCallable(wallet.spin, HOT);

// ---------------------------------------------------------------------------
// VIP (vip.js). The tier is computed here from the top-up records only: on
// every write of phale_orders / phale_iap (payment, refund), on the first
// walletSync of a wallet (backfill) and by the admin (vipRecompute).
// A bank refund ("Hoàn tiền" on /quan-tri sets refundedAt on the order) also
// takes the order's Pha lê back first, like an App Store refund
// (bank_refund.js), then the tier is recomputed.
//   firebase deploy --only functions:vipOnOrder,functions:vipOnIap,functions:vipRecompute,functions:vipHallHide,functions:vipBadgeHide,functions:walletSync
// ---------------------------------------------------------------------------
const vip = require('./vip');
const bankRefund = require('./bank_refund');

async function orderFromWrite(event) {
  const after = event.data && event.data.after && event.data.after.exists ? event.data.after.data() : null;
  const refund = bankRefund.needsClawback(after);
  if (refund) {
    try {
      const r = await bankRefund.applyBankRefund({ db, eco: walletEco, code: event.params.code, now: new Date() });
      logger.info('bank refund', { code: event.params.code, ...r });
    } catch (e) {
      logger.error('bank refund failed', { code: event.params.code, message: e && e.message });
      throw e; // retried by the trigger
    }
  }
  const levels = await vipFromWrite(event);
  // The new tier on the order, for the admin's "Đã đánh dấu hoàn tiền" line.
  if (refund && after.uid && levels[after.uid] != null) {
    await bankRefund.recordVipAfter({ db, code: event.params.code, level: levels[after.uid] });
  }
}

/** Recomputes the tier of every account the write touched: uid -> level. */
async function vipFromWrite(event) {
  const before = event.data && event.data.before && event.data.before.exists ? event.data.before.data() : null;
  const after = event.data && event.data.after && event.data.after.exists ? event.data.after.data() : null;
  const levels = {};
  for (const uid of vip.touchedUids(before, after)) {
    try {
      const r = await vip.recompute({ db, eco: walletEco, uid, now: new Date(), filter: defaultFilter() });
      levels[uid] = r.level;
      logger.info('vip recompute', { uid, prev: r.prev, level: r.level, sent: r.sent });
    } catch (e) {
      logger.error('vip recompute failed', { uid, message: e && e.message });
      throw e; // retried by the trigger
    }
  }
  return levels;
}

exports.vipOnOrder = onDocumentWritten({ document: 'phale_orders/{code}', region: REGION }, orderFromWrite);
exports.vipOnIap = onDocumentWritten({ document: 'phale_iap/{txnId}', region: REGION }, vipFromWrite);

function vipCallable(op, timeoutSeconds = 30) {
  return onCall(
    { region: REGION, invoker: 'public', cors: true, timeoutSeconds },
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError('unauthenticated', 'sign-in-required');
      }
      try {
        return await op({
          db, eco: walletEco, uid: request.auth.uid, now: new Date(), data: request.data || {},
          filter: defaultFilter(), isAdmin: isChatAdmin,
        });
      } catch (e) {
        if (e instanceof vip.VipError) throw new HttpsError('failed-precondition', e.code);
        logger.error('vip call failed', { message: e && e.message });
        throw new HttpsError('internal', 'server');
      }
    },
  );
}

/** Admin button: {uid} one player, {all: true} every payer (backfill). */
exports.vipRecompute = vipCallable(vip.adminRecompute, 540);
/** Cài đặt VIP: {hidden: bool} "Ẩn tên khỏi Bảng vinh danh". */
exports.vipHallHide = vipCallable(vip.setHallHidden);
/** Cài đặt VIP: {hidden: bool} "Ẩn huy hiệu VIP" (public tier reads 0). */
exports.vipBadgeHide = vipCallable(vip.setBadgeHidden);
