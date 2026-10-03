import '../save/game_state.dart';

/// Storage path written by "Tải ảnh lên". Preset ids and `google` are not.
bool isUploadedAvatar(String id) => id.contains('/');

/// [primary] won the merge. An uploaded photo on [other] replaces a preset,
/// so a further cloud morning cannot put the default portrait back.
void keepUploadedAvatar(GameState primary, GameState? other) {
  if (other == null) return;
  if (isUploadedAvatar(other.ownerAvatar) &&
      !isUploadedAvatar(primary.ownerAvatar)) {
    primary.ownerAvatar = other.ownerAvatar;
    primary.ownerAvatarRev = other.ownerAvatarRev;
  }
}

/// A Google account at this day already played. Guest progress on the
/// website must not replace it, even when [joinedAt] was never stored.
const establishedAccountDay = 2;

/// True when this account has logged in before. [joined] is the
/// `users/{uid}.joinedAt` stamp. A morning at day 2 or later counts too.
bool accountAlreadyPlayed({required int? day, required bool joined}) =>
    joined || (day != null && day >= establishedAccountDay);

/// What to do when this tab enters a Google account.
///
/// An empty cloud receives the morning on this device. A cloud save is
/// the account's morning: this device does not upload over it, whether
/// the local day is earlier or later. The tab that already holds the
/// seat keeps playing its own morning and does not call [enter].
class CloudMerge {
  const CloudMerge({required this.useCloud, required this.pushLocal});

  /// Replace the local morning with the cloud morning.
  final bool useCloud;

  /// Upload the local morning. Never combined with [useCloud].
  final bool pushLocal;

  static CloudMerge enter({
    required bool hasCloud,
    required bool hasLocalSave,
  }) {
    if (!hasCloud) {
      return CloudMerge(useCloud: false, pushLocal: hasLocalSave);
    }
    return const CloudMerge(useCloud: true, pushLocal: false);
  }
}
