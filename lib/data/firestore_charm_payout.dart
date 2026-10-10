import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/charm_payout.dart';

/// Firestore side of the payout view: `charm_board/{period}` (meta + payout
/// summary), `charm_board/{period}/review/{uid}` and `config/charmPayout`.
/// Admin only (firestore.rules).
class FirestoreCharmPayout implements CharmPayoutStore {
  FirestoreCharmPayout({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static DateTime? _time(Object? v) => v is Timestamp ? v.toDate() : null;
  static int _int(Object? v) => v is num ? v.toInt() : 0;

  @override
  Future<PayoutMeta> meta(String period) async {
    final snap = await _db.collection('charm_board').doc(period).get();
    final data = snap.data();
    if (data == null) return const PayoutMeta();
    final p = data['payout'];
    final map = p is Map ? p : const {};
    return PayoutMeta(
      status: map['status'] is String ? map['status'] as String : null,
      endsAt: _time(data['endsAt']),
      at: _time(map['at']),
      sent: _int(map['sent']),
      held: _int(map['held']),
      skipped: _int(map['skipped']),
      failed: _int(map['failed']),
    );
  }

  @override
  Future<List<PayoutLine>> lines(String period) async {
    final snap = await _db
        .collection('charm_board')
        .doc(period)
        .collection('review')
        .get();
    final out = <PayoutLine>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final status = PayoutStatus.fromKey(d['status']);
      if (status == null) continue;
      final flags = d['flags'];
      out.add(
        PayoutLine(
          uid: doc.id,
          status: status,
          displayName: d['displayName'] is String
              ? d['displayName'] as String
              : '',
          rank: _int(d['rank']),
          stored: _int(d['stored']),
          recomputed: _int(d['recomputed']),
          flags: flags is List ? [for (final f in flags) '$f'] : const [],
          reason: d['reason'] is String ? d['reason'] as String : null,
          petId: d['petId'] is String ? d['petId'] as String : '',
          stage: _int(d['stage']),
          mailId: d['mailId'] is String ? d['mailId'] as String : null,
        ),
      );
    }
    return out;
  }

  @override
  Future<bool> autoPayout() async {
    final snap = await _db.collection('config').doc('charmPayout').get();
    return snap.data()?['autoPayout'] != false;
  }

  @override
  Future<void> setAutoPayout(bool on) => _db
      .collection('config')
      .doc('charmPayout')
      .set({'autoPayout': on, 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> markReleased(String period, String uid) => _db
      .collection('charm_board')
      .doc(period)
      .collection('review')
      .doc(uid)
      .set({
        'status': 'released',
        'releasedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
