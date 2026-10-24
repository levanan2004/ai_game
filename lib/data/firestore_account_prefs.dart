import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/account_prefs.dart';

/// player_prefs/{uid}: `blocked` (uid -> shop name), `chatRulesV1` (the
/// noi_quy v1 popup was accepted), `updatedAt`. firestore.rules lets only
/// the owner read or write it; functions/delete_account.js deletes it.
class FirestoreAccountPrefs implements AccountPrefsSource {
  FirestoreAccountPrefs({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.doc('player_prefs/$uid');

  @override
  Future<AccountPrefs?> load(String uid) async {
    final snap = await _doc(uid).get();
    final d = snap.data();
    if (!snap.exists || d == null) return null;
    return readAccountPrefs(d);
  }

  @override
  Future<void> save(String uid, AccountPrefs prefs) => _doc(uid).set({
    'blocked': prefs.blocked,
    'chatRulesV1': prefs.chatRulesAccepted,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

/// A player_prefs doc; bad fields read as empty.
AccountPrefs readAccountPrefs(Map<String, dynamic> d) {
  final raw = d['blocked'];
  return AccountPrefs(
    blocked: {
      if (raw is Map)
        for (final e in raw.entries)
          if (e.key is String && (e.key as String).isNotEmpty)
            e.key as String: e.value is String ? e.value as String : '',
    },
    chatRulesAccepted: d['chatRulesV1'] == true,
  );
}
