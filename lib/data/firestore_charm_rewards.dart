import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/charm_rewards.dart';
import '../logic/mailbox.dart';
import '../logic/player_account.dart';
import '../save/game_state.dart';

/// Admin side of the season reward on Firestore: reads the ranked players'
/// saves (`users/{uid}.progress`) and creates `mails/bxh_{period}_{uid}` once
/// (the release of a held row).
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
