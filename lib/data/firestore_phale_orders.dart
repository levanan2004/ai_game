import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../logic/phale_order_admin.dart';

/// `phale_orders` for `/quan-tri` → Nạp Pha lê. Admins may list them and
/// set refundedAt / refundedBy on a paid one (firestore.rules); the
/// vipOnOrder trigger does the rest.
class FirestorePhaleOrderAdmin implements PhaleOrderAdmin {
  FirestorePhaleOrderAdmin({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('phale_orders');

  @override
  Future<List<PhaleOrderRow>> paidOrders({int limit = 200}) async {
    // Only orders that were paid have paidAt (functions/topup.js).
    final snap = await _orders
        .orderBy('paidAt', descending: true)
        .limit(limit)
        .get();
    return [
      for (final doc in snap.docs)
        if (doc.data()['status'] == 'paid')
          ?readPhaleOrderRow(doc.id, doc.data()),
    ];
  }

  @override
  Future<void> markRefunded(String code) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('sign-in-required');
    await _orders.doc(code).update({
      'refundedAt': FieldValue.serverTimestamp(),
      'refundedBy': uid,
    });
  }
}

/// One phale_orders doc; null without an owner. Exposed for tests.
PhaleOrderRow? readPhaleOrderRow(String code, Map<String, dynamic> d) {
  final uid = d['uid'];
  if (uid is! String || uid.isEmpty) return null;
  DateTime? time(Object? v) => v is Timestamp
      ? v.toDate()
      : v is DateTime
      ? v
      : null;
  int n(Object? v) => v is num && v.isFinite ? v.toInt() : 0;
  String s(Object? v) => v is String ? v : '';
  return PhaleOrderRow(
    code: code,
    uid: uid,
    packId: s(d['packId']),
    amount: n(d['amount']),
    crystals: n(d['crystalsGranted'] ?? d['crystals']),
    paidAt: time(d['paidAt']),
    refundedAt: time(d['refundedAt']),
    refundedBy: s(d['refundedBy']),
    clawback: s(d['clawback']),
    phaleTaken: n(d['phaleTaken']),
    phaleDebt: n(d['phaleDebt']),
  );
}
