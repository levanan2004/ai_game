'use strict';
// The per-row check behind verifyCharmEntry / sweepCharmBoard, with the
// database passed in so charm.test.js can run it against a fake Firestore.
const { judge } = require('./charm');
const { defaultFilter } = require('./word_filter');
const { publicProfile } = require('./public_profile');

/** `fix` unless CHARM_MODE=log (the way back to log-only). */
function modeFromEnv(env) {
  return env && env.CHARM_MODE === 'log' ? 'log' : 'fix';
}

/**
 * Compares one board row with the player's save.
 *  - always logs a mismatch for the admin (logger.warn 'charm board mismatch')
 *  - mode 'fix': a row above what the save backs is lowered to it, a row with
 *    no pet / under the minimum / no readable save is deleted
 *  - mode 'log': nothing is changed
 * A row below what the save backs is never raised: the cloud save is written
 * at the morning checkpoint, so it can lag behind what the device published.
 * A shop name the word filter refuses (word_filter.js, the app refuses it
 * too) takes the row off the board in 'fix' mode, logged as 'charm board
 * name refused'.
 * With [profile] it also refreshes public_profiles/{uid} from the save.
 * Returns the verdict ('ok' | 'lower' | 'remove' | 'name').
 */
async function checkEntry({ db, eco, period, uid, entry, ref, mode, now, logger, filter, profile = false }) {
  const words = filter || defaultFilter();
  if (typeof entry.displayName === 'string' && !words.allowsShopName(entry.displayName)) {
    logger.warn('charm board name refused', { period, uid, mode });
    if (mode === 'fix') await ref.delete();
    return 'name';
  }
  const snap = await db.doc(`users/${uid}`).get();
  const progress = snap.exists ? snap.data().progress : null;
  // [profile] (the write trigger, not the sweep): refresh the public facts
  // of the profile card from the save just read (public_profile.js).
  if (profile && progress) {
    await db.doc(`public_profiles/${uid}`).set(publicProfile(progress, now), { merge: true });
  }
  const { verdict, real } = judge(entry, progress, eco);
  if (verdict === 'ok') return verdict;
  logger.warn('charm board mismatch', {
    period, uid, verdict, stored: entry.charm, recomputed: real.charm, mode,
  });
  if (mode !== 'fix') return verdict;
  if (verdict === 'remove') {
    await ref.delete();
  } else {
    // A lower charm is a new score: reachedAt (the tie-break) moves to now.
    await ref.update({
      charm: real.charm, petId: real.petId, stage: real.stage, worn: real.worn,
      reachedAt: now,
    });
  }
  return verdict;
}

module.exports = { modeFromEnv, checkEntry };