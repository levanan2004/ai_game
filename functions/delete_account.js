'use strict';
// Account deletion (App Store 5.1.1(v) / Google Play). Pure logic: the Admin SDK
// Firestore, Auth and Storage bucket are passed in (the Firestore fake in
// fake_firestore.js and small stubs in the tests), so every rule is unit tested.
// index.js wires it to the callable `deleteAccount`.
//
// What it does for ONE uid (the caller's own, never a parameter):
//
//   0. BLOCKS (nothing is touched) while the account has a top-up order that is
//      still awaiting payment, or paid / cancelled in the last
//      RECENT_ORDER_MINUTES: a late transfer must not be lost.
//   1. ANONYMIZES the order-of-record data. phale_orders, sepay_txns and
//      phale_iap (App Store purchases) keep order id, amount, time, bank or
//      App Store transaction id (accounting) but `uid` is set to null. The doc id is the order code, which says nothing about the
//      player. phale_pending/{uid} is deleted. supporters rows keep amount and
//      date only (name, message, avatar, uid removed). A single-use giftcode
//      keeps "used", with usedBy replaced by 'deleted'.
//   2. DELETES users/{uid} and every sub-collection (save, seat, mailState,
//      welfare, redeemed), wallets/{uid} (+ ledger), profiles, player_avatars
//      (with the worn avatar frame and VIP tier), vip_hall (Bảng vinh danh),
//      public_profiles (with titleStats, pinnedTitle, bestRank), player_prefs (block
//      list, chat rules accepted), shop_names, the
//      charm_board entry and review line of EVERY season, the rating_board
//      (Bảng Đánh giá) entry of every season and rating_state, notice_replies (and
//      the photos under reply_photos/{uid}/), mails addressed to the uid,
//      supporter_private rows of the player's supporters rows, admins/{uid},
//      profile_reports the player sent or that are about the player,
//      the player's Tin thế giới messages (world_chat), chat_reports the
//      player sent or that are about the player, world_chat_state/{uid} and
//      chat_mutes/{uid},
//      Storage users/{uid}/avatar.jpg.
//      A champion title the player holds (titles/{titleId}) becomes vacant
//      (holderUid '') until the next payout; rating_board/{period}.champion
//      naming the player is cleared.
//   3. Deletes the Firebase Auth user LAST, and only when every step above
//      worked. A step that failed makes the call fail with `partial` and the
//      Auth user stays, so the player can simply call it again: every step is
//      idempotent (a missing doc or file is not an error).
//
// Nothing here logs a uid, an email or a name: only step names and counts.

const RECENT_ORDER_MINUTES = 10;
const ANON_USED_BY = 'deleted';

class DeleteBlockedError extends Error {
  constructor() {
    super('order-pending');
    this.code = 'order-pending';
  }
}

class DeletePartialError extends Error {
  constructor(steps) {
    super('partial');
    this.code = 'partial';
    this.steps = steps;
  }
}

function toDate(v) {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof v.toDate === 'function') return v.toDate();
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

/**
 * True when a top-up order of this account could still bring money in: awaiting
 * payment (pending and not expired for RECENT_ORDER_MINUTES yet) or paid or
 * cancelled in the last RECENT_ORDER_MINUTES.
 */
function orderIsRecent(o, now, minutes = RECENT_ORDER_MINUTES) {
  const since = now.getTime() - minutes * 60000;
  const after = (v) => {
    const d = toDate(v);
    return !!d && d.getTime() > since;
  };
  if (o.status === 'pending') return after(o.expiresAt);
  if (o.status === 'paid') return after(o.paidAt);
  if (o.status === 'cancelled') return after(o.cancelledAt);
  return false;
}

async function ordersOf(db, uid) {
  return (await db.collection('phale_orders').where('uid', '==', uid).get()).docs;
}

async function hasRecentOrder({ db, uid, now, minutes }) {
  return (await ordersOf(db, uid)).some((d) => orderIsRecent(d.data(), now, minutes));
}

async function deleteDocs(snapshot) {
  let n = 0;
  for (const d of snapshot.docs) {
    await d.ref.delete();
    n++;
  }
  return n;
}

async function deleteAccount({ db, auth, bucket, uid, now = new Date(), logger = console, recentMinutes }) {
  if (!uid || typeof uid !== 'string') throw new Error('no uid');
  const log = { deleted: {}, anonymized: {} };

  // 0. blocked: nothing is touched.
  if (await hasRecentOrder({ db, uid, now, minutes: recentMinutes })) {
    logger.info('delete account blocked', { reason: 'order-pending' });
    throw new DeleteBlockedError();
  }

  const failed = [];
  const step = async (name, fn) => {
    try {
      await fn();
    } catch (e) {
      failed.push(name);
      // The code only (no message: a Firestore message can carry a path with the uid).
      logger.error('delete account step failed', { step: name, code: (e && e.code) || null });
    }
  };

  // 1. anonymize the order records.
  await step('orders', async () => {
    let n = 0;
    for (const d of await ordersOf(db, uid)) {
      await d.ref.update({ uid: null, anonymizedAt: now });
      n++;
    }
    log.anonymized.orders = n;
  });
  await step('payments', async () => {
    const snap = await db.collection('sepay_txns').where('uid', '==', uid).get();
    for (const d of snap.docs) await d.ref.update({ uid: null, anonymizedAt: now });
    log.anonymized.payments = snap.docs.length;
  });
  await step('app-store', async () => {
    const snap = await db.collection('phale_iap').where('uid', '==', uid).get();
    for (const d of snap.docs) await d.ref.update({ uid: null, anonymizedAt: now });
    log.anonymized.appStore = snap.docs.length;
  });
  await step('pending-pointer', async () => {
    await db.doc(`phale_pending/${uid}`).delete();
  });
  await step('supporters', async () => {
    const snap = await db.collection('supporters').where('uid', '==', uid).get();
    for (const d of snap.docs) {
      const row = d.data() || {};
      // The private note (a phone number) and the photo go first: once the row is
      // anonymized a retry would no longer find it by uid.
      await db.doc(`supporter_private/${d.id}`).delete();
      const avatar = typeof row.avatar === 'string' ? row.avatar : '';
      if (avatar.startsWith('supporters/')) {
        await bucket.file(avatar).delete({ ignoreNotFound: true });
      }
      await d.ref.update({
        uid: '', name: 'Ẩn danh', message: '', avatar: '', visible: false, anonymizedAt: now,
      });
    }
    log.anonymized.supporters = snap.docs.length;
  });
  await step('giftcodes', async () => {
    const snap = await db.collection('giftcodes').where('usedBy', '==', uid).get();
    for (const d of snap.docs) await d.ref.update({ usedBy: ANON_USED_BY });
    log.anonymized.giftcodes = snap.docs.length;
  });

  // 2. delete (Nhất's order: save, profile, avatar, shop name, board, replies, mail).
  await step('save', async () => {
    await db.recursiveDelete(db.doc(`users/${uid}`));
  });
  await step('wallet', async () => {
    // Pha lê balance, Thẻ gacha, pity counters and their ledger (wallet.js).
    await db.recursiveDelete(db.doc(`wallets/${uid}`));
  });
  await step('profile', async () => {
    await db.doc(`profiles/${uid}`).delete();
  });
  await step('avatar', async () => {
    await db.doc(`player_avatars/${uid}`).delete();
    // The profile card's public facts (public_profile.js).
    await db.doc(`public_profiles/${uid}`).delete();
    // The Bảng vinh danh row (vip.js), if VIP 10.
    await db.doc(`vip_hall/${uid}`).delete();
    // Block list and chat "rules accepted" (lib/logic/account_prefs.dart).
    await db.doc(`player_prefs/${uid}`).delete();
    await bucket.file(`users/${uid}/avatar.jpg`).delete({ ignoreNotFound: true });
  });
  await step('titles', async () => {
    // Vacant until the next season's #1 takes it (titles.js).
    const held = await db.collection('titles').where('holderUid', '==', uid).get();
    for (const d of held.docs) await d.ref.update({ holderUid: '', vacatedAt: now });
    log.deleted.titles = held.docs.length;
    const champ = await db.collection('rating_board').where('champion', '==', uid).get();
    for (const d of champ.docs) await d.ref.update({ champion: '' });
  });
  await step('shop-name', async () => {
    log.deleted.shopNames = await deleteDocs(await db.collection('shop_names').where('uid', '==', uid).get());
  });
  await step('charm-board', async () => {
    // listDocuments also returns a season that has entries but no meta doc.
    let n = 0;
    for (const season of await db.collection('charm_board').listDocuments()) {
      await season.collection('entries').doc(uid).delete();
      await season.collection('review').doc(uid).delete();
      n++;
    }
    log.deleted.seasons = n;
  });
  await step('rating-board', async () => {
    // Bảng Đánh giá rows of every season and the server's counters.
    for (const season of await db.collection('rating_board').listDocuments()) {
      await season.collection('entries').doc(uid).delete();
    }
    await db.doc(`rating_state/${uid}`).delete();
  });
  await step('replies', async () => {
    log.deleted.replies = await deleteDocs(await db.collection('notice_replies').where('uid', '==', uid).get());
    await bucket.deleteFiles({ prefix: `reply_photos/${uid}/`, force: true });
  });
  await step('mailbox', async () => {
    log.deleted.mails = await deleteDocs(await db.collection('mails').where('target', '==', uid).get());
  });
  await step('world-chat', async () => {
    log.deleted.chatMessages = await deleteDocs(await db.collection('world_chat').where('uid', '==', uid).get());
    const reports = db.collection('chat_reports');
    log.deleted.chatReports = await deleteDocs(await reports.where('reporterUid', '==', uid).get())
      + await deleteDocs(await reports.where('targetUid', '==', uid).get());
    await db.doc(`world_chat_state/${uid}`).delete();
    await db.doc(`chat_mutes/${uid}`).delete();
  });
  await step('reports', async () => {
    const reports = db.collection('profile_reports');
    log.deleted.reports = await deleteDocs(await reports.where('reporterUid', '==', uid).get())
      + await deleteDocs(await reports.where('targetUid', '==', uid).get());
  });
  await step('admin-flag', async () => {
    await db.doc(`admins/${uid}`).delete();
  });

  if (failed.length) throw new DeletePartialError(failed);

  // 3. the login itself, last.
  try {
    await auth.deleteUser(uid);
  } catch (e) {
    if (!(e && e.code === 'auth/user-not-found')) {
      logger.error('delete account step failed', { step: 'auth', code: (e && e.code) || null });
      throw new DeletePartialError(['auth']);
    }
  }
  logger.info('delete account done', log);
  return { status: 'deleted' };
}

module.exports = {
  RECENT_ORDER_MINUTES, ANON_USED_BY, DeleteBlockedError, DeletePartialError,
  orderIsRecent, hasRecentOrder, deleteAccount,
};
