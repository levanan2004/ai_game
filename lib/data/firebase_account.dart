import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../logic/avatar_jpeg.dart';
import '../logic/pet.dart';
import '../logic/xu_grant.dart';
import '../save/game_state.dart';
import 'account_gateway.dart';

/// Google sign-in (web popup), `users/{uid}` progress, and avatar upload.
class FirebaseAccount implements AccountGateway {
  FirebaseAccount({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  /// True after this session has seen or written `joinedAt`, so later
  /// saves do not read the user document again.
  var _joinedStored = false;

  String? _seatId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _seatWatch;

  DocumentReference<Map<String, dynamic>> _seat(String uid) =>
      _doc(uid).collection('seat').doc('current');

  AccountProfile? _profile(User? user) {
    if (user == null) return null;
    return AccountProfile(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  @override
  AccountProfile? currentProfile() => _profile(_auth.currentUser);

  @override
  Future<void> useTabLogin() async {
    if (!kIsWeb) return;
    try {
      await _auth.setPersistence(Persistence.SESSION);
    } catch (_) {}
  }

  @override
  Future<AccountProfile?> signIn() async {
    if (!kIsWeb) return null;
    await useTabLogin();
    final cred = await _auth.signInWithPopup(GoogleAuthProvider());
    return _profile(cred.user);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<CloudRecord?> pull() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _doc(uid).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    final joinedRaw = data['joinedAt'];
    final joinedAt = joinedRaw is Timestamp ? joinedRaw.toDate() : null;
    final progress = data['progress'];
    // A save that cannot be read is not an empty account. Treating it as
    // empty would upload this device's morning over the real one.
    if (!data.containsKey('progress')) {
      if (joinedAt != null) throw StateError('progress');
      return null;
    }
    if (progress is! Map) throw StateError('progress');
    final state = GameState.decode(jsonEncode(progress));
    if (state == null) throw StateError('progress');
    final updated = data['updatedAt'];
    return CloudRecord(
      state: state,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
      joinedAt: joinedAt,
    );
  }

  @override
  Future<void> rememberJoin() async {
    if (_joinedStored) return;
    final user = _auth.currentUser;
    if (user == null) return;
    final created = user.metadata.creationTime;
    if (created == null) return;
    final ref = _doc(user.uid);
    try {
      final snap = await ref.get();
      if (snap.data()?['joinedAt'] != null) {
        _joinedStored = true;
        return;
      }
      await ref.update({'joinedAt': Timestamp.fromDate(created)});
      _joinedStored = true;
    } catch (_) {}
  }

  @override
  Future<XuGrant?> pullGrant() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _doc(uid).get();
    return grantFromMap(snap.data()?['grant']);
  }

  @override
  Future<PetGiftBox?> pullGift() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _doc(uid).get();
    return giftFromMap(snap.data()?['gift']);
  }

  @override
  Future<String?> seatHolder() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _seat(uid).get();
    final id = snap.data()?['id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  @override
  Future<bool> claimIfFree(String tabId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final ref = _seat(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.data()?['id'];
      if (current is String && current.isNotEmpty && current != tabId) {
        return false;
      }
      tx.set(ref, {'id': tabId});
      return true;
    });
  }

  @override
  Future<void> takeSeat(String tabId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _seat(uid).set({'id': tabId});
  }

  @override
  Future<void> releaseSeat(String tabId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _seat(uid);
    final snap = await ref.get();
    if (snap.data()?['id'] == tabId) await ref.delete();
  }

  @override
  void bindSeat(String? tabId) => _seatId = tabId;

  @override
  void watchSeat(void Function(String? holderId) onChange) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _seatWatch?.cancel();
    _seatWatch = _seat(uid).snapshots().listen((snap) {
      final id = snap.data()?['id'];
      onChange(id is String && id.isNotEmpty ? id : null);
    }, onError: (_) {});
  }

  @override
  void stopWatchingSeat() {
    _seatWatch?.cancel();
    _seatWatch = null;
  }

  @override
  Future<void> push(GameState state) async {
    final user = _auth.currentUser;
    final seatId = _seatId;
    if (user == null || seatId == null) return;
    final ref = _doc(user.uid);
    // Progress is its own write. joinedAt is added afterwards so an older
    // ruleset that only allows progress still accepts the save.
    // seatTick must be request.time so a tab that lost the seat cannot
    // reuse a previous proof.
    await ref.set({
      'progress': state.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
      'seatId': seatId,
      'seatTick': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (_joinedStored) return;
    final snap = await ref.get();
    if (snap.data()?['joinedAt'] != null) {
      _joinedStored = true;
      return;
    }
    final created = user.metadata.creationTime;
    if (created == null) return;
    try {
      await ref.update({'joinedAt': Timestamp.fromDate(created)});
      _joinedStored = true;
    } catch (_) {}
  }

  @override
  Future<Uint8List?> pickAvatarJpeg() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return squareAvatarJpeg(await file.readAsBytes());
  }

  @override
  Future<String?> uploadAvatar(Uint8List jpeg) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || jpeg.length > 512 * 1024) return null;
    final path = 'users/$uid/avatar.jpg';
    await _storage
        .ref(path)
        .putData(jpeg, SettableMetadata(contentType: 'image/jpeg'));
    return path;
  }
}
