import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/charm_rewards.dart';
import '../logic/mailbox.dart';
import '../logic/player_account.dart';
import '../save/game_state.dart';

/// Admin side of the season reward on Firestore: reads the ranked players'
/// saves (`users/{uid}.progress`), looks for rewards already written, and
/// creates `mails/bxh_{period}_{uid}` once.
class FirestoreCharmRewardStore implements CharmRewardStore {
  FirestoreCharmRewardStore({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<Map<String, GameState>> saves(List<String> uids) async {
    final out = <String, GameState>{};
    for (var i = 0; i < uids.length; i += accountSaveBatch) {
      final chunk = uids.sublist(
        i,
        i + accountSaveBatch > uids.length ? uids.length : i + accountSaveBatch,
      );
      final snap = await _db
          .collection('users')
          .where(
            FieldPath.documentId,
            whereIn: [
              for (final uid in chunk) _db.collection('users').doc(uid),
            ],
          )
          .get();
      for (final doc in snap.docs) {
        final state = decodeProgress(doc.data()['progress']);
        if (state != null) out[doc.id] = state;
      }
    }
    return out;
  }

  @override
  Future<Set<String>> granted(String period, List<String> uids) async {
    final byId = {for (final uid in uids) charmRewardMailId(period, uid): uid};
    final ids = byId.keys.toList();
    final found = <String>{};
    for (var i = 0; i < ids.length; i += accountSaveBatch) {
      final chunk = ids.sublist(
        i,
        i + accountSaveBatch > ids.length ? ids.length : i + accountSaveBatch,
      );
      final snap = await _db
          .collection('mails')
          .where(
            FieldPath.documentId,
            whereIn: [for (final id in chunk) _db.collection('mails').doc(id)],
          )
          .get();
      for (final doc in snap.docs) {
        final uid = byId[doc.id];
        if (uid != null) found.add(uid);
      }
    }
    return found;
  }

  @override
  Future<bool> grant(GameMail mail) {
    final ref = _db.collection('mails').doc(mail.id);
    final map = mailToMap(mail);
    return _db.runTransaction((tx) async {
      if ((await tx.get(ref)).exists) return false;
      tx.set(ref, {
        for (final e in map.entries)
          e.key: switch (e.value) {
            final DateTime d => Timestamp.fromDate(d),
            null => FieldValue.serverTimestamp(),
            final other => other,
          },
      });
      return true;
    });
  }
}
