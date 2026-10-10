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