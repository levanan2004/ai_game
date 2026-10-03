import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/shop_name.dart';
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
  Future<List<PlayerProfile>> byUidPrefix(
    String prefix, {
    int limit = 10,
  }) async {
    final id = prefix.trim();
    if (id.isEmpty) return const [];
    final snap = await _profiles
        .orderBy(FieldPath.documentId)
        .startAt([id])
        .endAt(['$id\uf8ff'])
        .limit(limit)
        .get();
    return [for (final doc in snap.docs) _profile(doc.id, doc.data())];
  }

  @override
  Future<void> setOwnVisible(String supporterId, bool visible) async {
    await _db.collection('supporters').doc(supporterId).update({
      'visible': visible,
    });
  }

  CollectionReference<Map<String, dynamic>> get _names =>
      _db.collection('shop_names');

  CollectionReference<Map<String, dynamic>> get _avatars =>
      _db.collection('player_avatars');

  @override
  Future<ShopNameClaim> claimShopName({
    String? uid,
    required String shopName,
    String? previousName,
  }) async {
    final name = normalizeShopName(shopName);
    if (name == null) return ShopNameClaim.failed;
    final key = shopNameKey(name);
    final previousKey = previousName == null ? null : shopNameKey(previousName);
    try {
      if (uid == null) {
        final snap = await _names.doc(key).get();
        return snap.exists ? ShopNameClaim.taken : ShopNameClaim.claimed;
      }
      return await _db.runTransaction((tx) async {
        final next = _names.doc(key);
        final releaseOld =
            previousKey != null && previousKey != key && previousKey.isNotEmpty;
        final old = releaseOld ? _names.doc(previousKey) : null;
        final snap = await tx.get(next);
        final oldSnap = old == null ? null : await tx.get(old);
        final owner = snap.data()?['uid'];
        if (snap.exists && owner != uid) return ShopNameClaim.taken;
        tx.set(next, {'uid': uid, 'shopName': name});
        if (old != null &&
            oldSnap != null &&
            oldSnap.exists &&
            oldSnap.data()?['uid'] == uid) {
          tx.delete(old);
        }
        return ShopNameClaim.claimed;
      });
    } catch (_) {
      return ShopNameClaim.failed;
    }
  }

  @override
  Future<void> publishAvatar({
    required String uid,
    required String path,
    required int rev,
  }) async {
    await _avatars.doc(uid).set({'path': path, 'rev': rev});
  }

  @override
  Future<Map<String, String>> avatarUrls(Iterable<String> uids) async {
    final ids = uids.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return const {};
    final out = <String, String>{};
    for (final id in ids) {
      final snap = await _avatars.doc(id).get();
      final data = snap.data();
      if (data == null) continue;
      final path = data['path'];
      if (path is! String || path.isEmpty) continue;
      if (path.startsWith('http')) {
        out[snap.id] = path;
        continue;
      }
      final rev = data['rev'];
      final url = storageAvatarUrl(path, rev: rev is num ? rev.toInt() : null);
      // A preset id has no Storage URL; the board draws that portrait itself.
      out[snap.id] = url ?? path;
    }
    return out;
  }

  @override
  Future<String?> publishedAvatar(String uid) async {
    final snap = await _avatars.doc(uid).get();
    final path = snap.data()?['path'];
    if (path is String && path.isNotEmpty) return path;
    return null;
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
