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

/// Web login persistence. LOCAL keeps the login in a new tab and after the
/// browser restarts; the seat decides which tab may write progress.
const webLoginPersistence = Persistence.LOCAL;

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

  /// Account the seat was taken for. All tabs share one login, so another
  /// tab may switch the current user; progress never goes to that account.
  String? _seatUid;

  /// Last holder the seat listener saw. A push needs it to still be us.
  String? _seatHolderSeen;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _seatWatch;
  StreamSubscription<User?>? _authWatch;

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
  Future<AccountProfile?> restoreProfile() async {
    final now = _auth.currentUser;
    if (now != null) return _profile(now);
    try {
      final user = await _auth.authStateChanges().first.timeout(
        const Duration(seconds: 5),
      );
      return _profile(user ?? _auth.currentUser);
    } catch (_) {
      return _profile(_auth.currentUser);
    }
  }

  @override
  Future<void> useLastingLogin() async {
    if (!kIsWeb) return;
    try {
      await _auth.setPersistence(webLoginPersistence);
    } catch (_) {}
  }

  @override
  Future<AccountProfile?> signIn() async {
    if (!kIsWeb) return null;
    await useLastingLogin();
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
    // No user is not an empty account: the caller would start it fresh.
    if (uid == null) throw StateError('signed out');
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
  void bindSeat(String? tabId) {
    _seatId = tabId;
    _seatUid = tabId == null ? null : _auth.currentUser?.uid;
    _seatHolderSeen = tabId;
  }

  @override
  void watchSeat(void Function(String? holderId) onChange) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    stopWatchingSeat();
    _seatWatch = _seat(uid).snapshots().listen((snap) {
      final id = snap.data()?['id'];
      final holder = id is String && id.isNotEmpty ? id : null;
      _seatHolderSeen = holder;
      onChange(holder);
    }, onError: (_) {});
    // Another tab signed in with a different Google account: this tab no
    // longer holds the login it was playing.
    _authWatch = _auth.authStateChanges().listen((user) {
      if (user?.uid == uid) return;
      _seatHolderSeen = null;
      onChange(null);
    }, onError: (_) {});
  }

  @override
  void stopWatchingSeat() {
    _seatWatch?.cancel();
    _seatWatch = null;
    _authWatch?.cancel();
    _authWatch = null;
  }

  @override
  Future<void> push(GameState state) async {
    final user = _auth.currentUser;
    final seatId = _seatId;
    if (user == null || seatId == null) return;
    // Never write into an account this tab does not hold, or after another
    // tab or device took the seat. The rules check the seat again.
    if (user.uid != _seatUid || _seatHolderSeen != seatId) return;
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
