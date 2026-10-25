import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/gacha.dart';

/// Lịch sử quay from `wallets/{uid}/ledger` (functions/wallet.js spin rows;
/// the owner may read them, firestore.rules). The newest rows are read and
/// the spins kept, so no extra index is needed.
class FirestoreGachaHistory implements GachaHistorySource {
  FirestoreGachaHistory({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<SpinRecord>> recent(String uid, {int limit = 30}) async {
    final snap = await _db
        .collection('wallets/$uid/ledger')
        .orderBy('at', descending: true)
        .limit(limit * 3)
        .get();
    final out = <SpinRecord>[];
    for (final doc in snap.docs) {
      final r = readSpinRecord(doc.data());
      if (r != null) out.add(r);
      if (out.length >= limit) break;
    }
    return out;
  }
}

/// One ledger row as a spin, or null when it is another kind. For tests.
SpinRecord? readSpinRecord(Map<String, dynamic> d) {
  if (d['type'] != 'spin') return null;
  final at = d['at'];
  final when = at is Timestamp
      ? at.toDate()
      : at is DateTime
      ? at
      : null;
  final pot = d['potId'];
  if (when == null || pot is! String) return null;
  return SpinRecord(
    at: when,
    potId: pot,
    results: SpinResult.listFrom(d['results']),
  );
}
