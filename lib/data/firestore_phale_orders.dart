import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../logic/phale_order_admin.dart';

/// `phale_orders` for `/quan-tri` → Nạp Pha lê. Admins may list them and
/// set refundedAt / refundedBy / refundNote on a paid one (firestore.rules);
/// the vipOnOrder trigger does the rest and writes vipAfter.
class FirestorePhaleOrderAdmin implements PhaleOrderAdmin {
  FirestorePhaleOrderAdmin({
    FirebaseFirestore? firestore,
    DateTime Function()? now,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _now = now ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _now;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('phale_orders');

  @override
  Future<List<PhaleOrderRow>> orders({int limit = 200}) async {
    // Every order has createdAt (functions/topup.js createOrder).
    final snap = await _orders
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    final now = _now();
    final docs = [
      for (final doc in snap.docs)
        if (phaleOrderListed(doc.data(), now)) doc,
    ];
    final names = await _shopNames({
      for (final doc in docs)
        if (doc.data()['uid'] is String) doc.data()['uid'] as String,
    });
    return [
      for (final doc in docs)
        ?readPhaleOrderRow(doc.id, {
          ...doc.data(),
          'shopName': names[doc.data()['uid']] ?? '',
        }),
    ];
  }

  @override
  Future<PhaleOrderRow?> order(String code) async {
    final doc = await _orders.doc(code).get();
    final data = doc.data();
    if (data == null) return null;
    final row = readPhaleOrderRow(code, data);
    if (row == null) return null;
    final names = await _shopNames({row.uid});
    return readPhaleOrderRow(code, {...data, 'shopName': names[row.uid] ?? ''});
  }

  /// users/{uid}.progress.shopName, ten docs per read (admins may read users).
  Future<Map<String, String>> _shopNames(Set<String> uids) async {
    final ids = uids.where((u) => u.isNotEmpty).toList();
    final out = <String, String>{};
    for (var i = 0; i < ids.length; i += 10) {
      final part = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      try {
        final snap = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: part)
            .get();
        for (final doc in snap.docs) {
          final p = doc.data()['progress'];
          final name = p is Map ? p['shopName'] : null;
          if (name is String && name.isNotEmpty) out[doc.id] = name;
        }
      } catch (_) {
        // Names are a help only: the uid stands in.
      }
    }
    return out;
  }

  @override
  Future<void> markRefunded(String code, {String note = ''}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('sign-in-required');
    final text = note.trim();
    await _orders.doc(code).update({
      'refundedAt': FieldValue.serverTimestamp(),
      'refundedBy': uid,
      if (text.isNotEmpty)
        'refundNote': text.length > 300 ? text.substring(0, 300) : text,
    });
  }
}

/// The panel lists paid orders and open ones (pending, not expired).
bool phaleOrderListed(Map<String, dynamic> d, DateTime now) {
  final status = d['status'];
  if (status == 'paid') return true;
  if (status != 'pending') return false;
  final exp = d['expiresAt'];
  final at = exp is Timestamp
      ? exp.toDate()
      : exp is DateTime
      ? exp
      : null;
  return at == null || at.isAfter(now);
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
  final vipAfter = d['vipAfter'];
  return PhaleOrderRow(
    code: code,
    uid: uid,
    status: s(d['status']).isEmpty ? 'paid' : s(d['status']),
    shopName: s(d['shopName']),
    packId: s(d['packId']),
    amount: n(d['amount']),
    crystals: n(d['crystalsGranted'] ?? d['crystals']),
    createdAt: time(d['createdAt']),
    paidAt: time(d['paidAt']),
    refundedAt: time(d['refundedAt']),
    refundedBy: s(d['refundedBy']),
    refundNote: s(d['refundNote']),
    clawback: s(d['clawback']),
    phaleTaken: n(d['phaleTaken']),
    phaleDebt: n(d['phaleDebt']),
    vipAfter: vipAfter is num ? vipAfter.toInt() : null,
  );
}
