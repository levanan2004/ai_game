import '../save/game_state.dart';

/// Storage path written by "Tải ảnh lên". Preset ids and `google` are not.
bool isUploadedAvatar(String id) => id.contains('/');

/// [primary] is the morning being loaded. An uploaded photo on [other] replaces a preset,
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

// Sign-in lines. Copy is easy to change here.

/// Shown after signing in to an account that has cloud progress.
String accountLoadedNotice(int day) =>
    'Đã tải tiến trình của tài khoản: ngày $day.';

/// Shown after signing in to an account with no cloud progress yet.
const newAccountNotice =
    'Tài khoản mới, bắt đầu từ ngày 1. '
    'Tiến trình chơi khách vẫn được giữ trên máy này.';

/// The cloud save could not be read, so the tab stays on the guest game.
const accountPullFailedNotice =
    'Chưa tải được tiến trình của tài khoản, thử lại nhé. '
    'Bạn vẫn đang chơi khách.';
