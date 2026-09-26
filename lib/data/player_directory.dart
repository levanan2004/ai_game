import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/supporters.dart';

/// `profiles/{uid}` for the admin picker, and the owner's visibility switch.
class FirestorePlayerDirectory implements PlayerDirectory {
  FirestorePlayerDirectory({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _db.collection('profiles');

  @override
  Future<void> sync({
    required String uid,
    required String name,
    required String email,
    required String shopName,
  }) async {
    await _profiles.doc(uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'shopName': shopName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<List<PlayerProfile>> recent({int limit = 10}) async {
    final snap = await _profiles
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();
    return [for (final doc in snap.docs) _profile(doc.id, doc.data())];
  }

  @override
  Future<PlayerProfile?> byUid(String uid) async {
    final id = uid.trim();
    if (id.isEmpty) return null;
    final snap = await _profiles.doc(id).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return _profile(snap.id, data);
  }

  @override
  Future<void> setOwnVisible(String supporterId, bool visible) async {
    await _db.collection('supporters').doc(supporterId).update({
      'visible': visible,
    });
  }

  PlayerProfile _profile(String uid, Map<String, dynamic> data) {
    String text(String key) => data[key] is String ? data[key] as String : '';
    return PlayerProfile(
      uid: uid,
      name: text('name'),
      email: text('email'),
      shopName: text('shopName'),
    );
  }
}
