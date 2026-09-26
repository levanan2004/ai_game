import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../logic/avatar_jpeg.dart';
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
  Future<AccountProfile?> signIn() async {
    if (!kIsWeb) return null;
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
    final progress = data['progress'];
    if (progress is! Map) return null;
    final state = GameState.decode(jsonEncode(progress));
    if (state == null) return null;
    final updated = data['updatedAt'];
    return CloudRecord(
      state: state,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }

  @override
  Future<void> push(GameState state) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _doc(uid).set({
      'progress': state.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
