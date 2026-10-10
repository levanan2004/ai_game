import 'package:cloud_firestore/cloud_firestore.dart';

import 'charm_board.dart';

/// `charm_board/{periodKey}/entries/{uid}` (shape in charm_board.dart).
/// Not wired to any screen yet.
class FirestoreCharmBoard implements CharmBoardSource {
  FirestoreCharmBoard({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _entries(String period) {
    if (!isValidPeriodKey(period)) throw ArgumentError('bad period $period');
    return _db.collection('charm_board').doc(period).collection('entries');
  }

  @override
  Future<List<CharmBoardRow>> top({
    required String period,
    int limit = charmBoardTopLimit,
  }) async {
    final n = limit.clamp(1, charmBoardTopLimit);
    // One-field order: no composite index. Equal charm is settled in
    // rankCharmBoard by updatedAt, among the rows that were read.
    final snap = await _entries(
      period,
    ).orderBy('charm', descending: true).limit(n).get();
    return rankCharmBoard([
      for (final doc in snap.docs)
        ?CharmBoardEntry.fromMap(
          doc.id,
          doc.data(),
          updatedAt: switch (doc.data()['updatedAt']) {
            final Timestamp t => t.toDate(),
            _ => null,
          },
        ),
    ], limit: n);
  }

  @override
  Future<void> publish({
    required String period,
    required CharmBoardEntry entry,
  }) {
    return _entries(period).doc(entry.uid).set({
      ...entry.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> remove({required String period, required String uid}) {
    return _entries(period).doc(uid).delete();
  }
}
