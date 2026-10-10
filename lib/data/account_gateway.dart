import 'dart:typed_data';

import '../logic/pet.dart';
import '../logic/xu_grant.dart';
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
  const CloudRecord({required this.state, this.updatedAt, this.joinedAt});

  final GameState state;
  final DateTime? updatedAt;

  /// `users/{uid}.joinedAt`: the first time this Google account entered.
  final DateTime? joinedAt;
}

/// Auth, the `users/{uid}` save, and the avatar upload.
/// The offline implementation does nothing, so a missing network cannot
/// stop the game.
abstract class AccountGateway {
  AccountProfile? currentProfile();

  Future<AccountProfile?> signIn();

  Future<void> signOut();

  /// Null only when the account has no cloud save. Throws when the save
  /// cannot be read or nobody is signed in.
  Future<CloudRecord?> pull();

  /// The login Firebase restores on page load. On the web it arrives after
  /// the first frame, so [currentProfile] alone can miss it. Null means
  /// there is no login; throws when it is not known yet (slow network), so
  /// the caller retries.
  Future<AccountProfile?> restoreProfile() async => currentProfile();

  /// Compensation waiting on `users/{uid}`, or null.
  Future<XuGrant?> pullGrant();

  /// Gift shipment waiting on `users/{uid}`, or null.
  Future<PetGiftBox?> pullGift();

  Future<void> push(GameState state);

  /// Writes `joinedAt` once, without touching progress. No-op when the
  /// stamp is already there.
  Future<void> rememberJoin() async {}

  /// Null when the player cancels the picker or the photo cannot be encoded.
  Future<Uint8List?> pickAvatarJpeg();

  /// Storage path `users/{uid}/avatar.jpg`.
  Future<String?> uploadAvatar(Uint8List jpeg);

  /// Web: keep the Google login in local storage, so a new tab or a
  /// browser restart stays signed in. No-op off the web.
  Future<void> useLastingLogin() async {}

  /// Tab id holding this account, or null when the seat is empty.
  Future<String?> seatHolder() async => null;

  /// Puts [tabId] in the seat even when another tab holds it. The newest
  /// session always wins; the old holder sees the change and leaves.
  Future<void> takeSeat(String tabId) async {}

  /// Deletes the seat when it still belongs to [tabId].
  Future<void> releaseSeat(String tabId) async {}

  /// Remember which tab may write progress, for the account signed in now.
  /// Null stops cloud writes.
  void bindSeat(String? tabId) {}

  /// Fires the current holder, then again whenever the seat changes. Fires
  /// null when the login switches to another account.
  void watchSeat(void Function(String? holderId) onChange) {}

  void stopWatchingSeat() {}
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
  Future<AccountProfile?> restoreProfile() async => null;

  @override
  Future<XuGrant?> pullGrant() async => null;

  @override
  Future<PetGiftBox?> pullGift() async => null;

  @override
  Future<void> push(GameState state) async {}

  @override
  Future<void> rememberJoin() async {}

  @override
  Future<Uint8List?> pickAvatarJpeg() async => null;

  @override
  Future<String?> uploadAvatar(Uint8List jpeg) async => null;

  @override
  Future<void> useLastingLogin() async {}

  @override
  Future<String?> seatHolder() async => null;

  @override
  Future<void> takeSeat(String tabId) async {}

  @override
  Future<void> releaseSeat(String tabId) async {}

  @override
  void bindSeat(String? tabId) {}

  @override
  void watchSeat(void Function(String? holderId) onChange) {}

  @override
  void stopWatchingSeat() {}
}
