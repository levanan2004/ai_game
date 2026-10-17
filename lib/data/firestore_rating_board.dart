import 'package:cloud_firestore/cloud_firestore.dart';

import 'charm_board.dart' show isValidPeriodKey;
import 'rating_board.dart';

/// `rating_board/{periodKey}/entries/{uid}`, written by the server only
/// (functions/rating_board.js); the app reads.
class FirestoreRatingBoard implements RatingBoardSource {
  FirestoreRatingBoard({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _entries(String period) {
    if (!isValidPeriodKey(period)) throw ArgumentError('bad period $period');
    return _db.collection('rating_board').doc(period).collection('entries');
  }

  static DateTime? _time(Object? v) => v is Timestamp ? v.toDate() : null;

  @override
  Future<List<RatingRow>> top({required String period, int limit = 100}) async {
    final n = limit.clamp(1, 100);
    // One-field order, no composite index. Rows under the minimum have
    // sortKey 0 and sort last; rankRatingBoard drops them and breaks equal
    // keys by reachedAt.
    final snap = await _entries(
      period,
    ).orderBy('sortKey', descending: true).limit(n).get();
    return rankRatingBoard([
      for (final doc in snap.docs)
        ?RatingEntry.fromMap(
          doc.id,
          doc.data(),
          reachedAt: _time(doc.data()['reachedAt']),
        ),
    ], limit: n);
  }

  @override
  Future<RatingEntry?> entry({
    required String period,
    required String uid,
  }) async {
    final doc = await _entries(period).doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return RatingEntry.fromMap(uid, data, reachedAt: _time(data['reachedAt']));
  }

  @override
  Future<String?> champion({required String period}) async {
    if (!isValidPeriodKey(period)) throw ArgumentError('bad period $period');
    final doc = await _db.collection('rating_board').doc(period).get();
    final uid = doc.data()?['champion'];
    return uid is String && uid.isNotEmpty ? uid : null;
  }
}
