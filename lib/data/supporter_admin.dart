import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../logic/supporters.dart';
import 'supporter_source.dart';

/// Writes allowed by `firestore.rules` / `storage.rules` for admins only.
class FirestoreSupporterAdmin implements SupporterAdmin {
  FirestoreSupporterAdmin({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _public =>
      _db.collection('supporters');

  CollectionReference<Map<String, dynamic>> get _private =>
      _db.collection('supporter_private');

  @override
  Future<bool> isAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    if (supportAdminUids.contains(uid)) return true;
    try {
      return (await _db.collection('admins').doc(uid).get()).exists;
    } catch (_) {
      return false;
    }
  }

  @override
  String newId() => _public.doc().id;

  @override
  Future<List<Supporter>> loadAll() async {
    final snap = await _public.get();
    return [for (final doc in snap.docs) supporterFromDoc(doc.id, doc.data())];
  }

  @override
  Future<String> loadPhone(String id) async {
    final snap = await _private.doc(id).get();
    final phone = snap.data()?['phone'];
    return phone is String ? phone : '';
  }

  @override
  Future<void> save(Supporter s, {required String phone}) async {
    final batch = _db.batch();
    batch.set(_public.doc(s.id), {
      'name': s.name.trim(),
      'message': s.message.trim(),
      'visible': s.visible,
      'avatar': s.avatar,
      'date': Timestamp.fromDate(s.date ?? DateTime.now()),
      if (s.hasAmount) 'amount': s.amount,
    });
    if (phone.isEmpty) {
      batch.delete(_private.doc(s.id));
    } else {
      batch.set(_private.doc(s.id), {
        'phone': phone,
        'name': s.name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> delete(Supporter s) async {
    final batch = _db.batch()
      ..delete(_public.doc(s.id))
      ..delete(_private.doc(s.id));
    await batch.commit();
    await deleteAvatar(s.avatar);
  }

  @override
  Future<void> deleteAvatar(String path) async {
    if (!path.startsWith('supporters/')) return;
    try {
      await _storage.ref(path).delete();
    } catch (_) {}
  }

  @override
  Future<String> uploadAvatar(String id, Uint8List jpeg) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'supporters/${id}_$stamp.jpg';
    await _storage
        .ref(path)
        .putData(jpeg, SettableMetadata(contentType: 'image/jpeg'));
    return path;
  }
}
