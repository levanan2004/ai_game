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
    'Chào mừng chủ tiệm quay lại! Tiệm đang ở ngày $day.';

/// Shown after signing in to an account with no cloud progress yet.
const newAccountNotice =
    'Tiệm mới mở cửa, mình bắt đầu từ ngày 1 nhé. '
    'Phần chơi thử trước đó vẫn nằm trên máy này.';

/// The cloud save could not be read, so the tab stays on the guest game.
const accountPullFailedNotice =
    'Chưa mở được sổ tiệm của tài khoản, bạn thử lại sau chút nhé. '
    'Trong lúc chờ, bạn vẫn chơi thử được trên máy này.';

/// Kicked dialog: another tab or device opened this account.
const seatLostTitle = 'Tiệm đang mở ở nơi khác';
const seatLostBody =
    'Tài khoản này vừa được mở ở tab hoặc máy khác, nên ở đây tạm dừng lưu. '
    'Tiến trình vẫn an toàn trên tài khoản.';
const seatLostButton = 'Đã hiểu';
