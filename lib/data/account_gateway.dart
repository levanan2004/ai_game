import 'dart:typed_data';

import '../save/game_state.dart';

class AccountProfile {
  const AccountProfile({
    required this.uid,
    required this.email,
    this.name,
    this.photoUrl,
  });

  final String uid;
  final String email;
  final String? name;
  final String? photoUrl;
}

class CloudRecord {
  const CloudRecord({required this.state, this.updatedAt});

  final GameState state;
  final DateTime? updatedAt;
}

/// Auth, the `users/{uid}` save, and the avatar upload.
/// The offline implementation does nothing, so a missing network cannot
/// stop the game.
abstract class AccountGateway {
  AccountProfile? currentProfile();

  Future<AccountProfile?> signIn();

  Future<void> signOut();

  Future<CloudRecord?> pull();

  Future<void> push(GameState state);

  /// Null when the player cancels the picker or the photo cannot be encoded.
  Future<Uint8List?> pickAvatarJpeg();

  /// Storage path `users/{uid}/avatar.jpg`.
  Future<String?> uploadAvatar(Uint8List jpeg);
}

class OfflineAccount implements AccountGateway {
  const OfflineAccount();

  @override
  AccountProfile? currentProfile() => null;

  @override
  Future<AccountProfile?> signIn() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<CloudRecord?> pull() async => null;

  @override
  Future<void> push(GameState state) async {}

  @override
  Future<Uint8List?> pickAvatarJpeg() async => null;

  @override
  Future<String?> uploadAvatar(Uint8List jpeg) async => null;
}
