'use strict';
// Server-side check of the Mị lực board (NOT deployed from this repo's CI;
// see functions/README.md). Two functions, both use the Admin SDK so they are
// not bound by firestore.rules:
//
//  verifyCharmEntry   runs when a player writes charm_board/{period}/entries/{uid}
//                     and compares the row with users/{uid}.progress.
//  sweepCharmBoard    every 30 minutes re-checks the top rows of the live period
//                     (catches an edit made while the trigger was down).
//
// CHARM_MODE (env, default "log"):
//   log  only write a warning to Cloud Logging, change nothing
//   fix  lower a row to what the save backs, or delete it under the minimum
//
// The game keeps publishing from the device exactly as before; this is a
// second opinion, and the admin review panel in /quan-tri shows the same
// recomputed number next to the stored one before any reward is paid.

const admin = require('firebase-admin');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const { loadEconomy, judge } = require('./charm');

admin.initializeApp();
const db = admin.firestore();
const eco = loadEconomy(require('./economy.json'));
const REGION = 'asia-southeast1';
const MODE = () => (process.env.CHARM_MODE === 'fix' ? 'fix' : 'log');

async function check(period, uid, entry, ref) {
  const snap = await db.collection('users').doc(uid).get();
  const progress = snap.exists ? snap.data().progress : null;
  const { verdict, real } = judge(entry, progress, eco);
  if (verdict === 'ok') return verdict;
  logger.warn('charm board mismatch', {
    period, uid, verdict, stored: entry.charm, recomputed: real.charm, mode: MODE(),
  });
  if (MODE() !== 'fix') return verdict;
  if (verdict === 'remove') {
    await ref.delete();
  } else {
    // A lower charm is a new score: reachedAt (the tie-break) moves to now.
    await ref.update({
      charm: real.charm,
      petId: real.petId,
      stage: real.stage,
      worn: real.worn,
      reachedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  return verdict;
}

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
