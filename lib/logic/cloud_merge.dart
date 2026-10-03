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

/// Which morning a tab plays after entering an account.
enum MorningPick {
  /// This account's copy on this device.
  cached,

  /// The cloud save.
  cloud,

  /// Nothing saved anywhere: a new game for the account.
  fresh,
}

/// The cloud save is the account's progress and wins over this device,
/// except for the tab that already held the seat coming back from a reload
/// ([keepLocal]) with a copy at the same or a later day (an upload that had
/// not finished). With no cloud save, this account's own copy on the device
/// is used before starting fresh. Guest play is never saved, so it never
/// competes here.
MorningPick pickMorning({
  required bool keepLocal,
  required GameState? cached,
  required GameState? cloud,
}) {
  if (keepLocal &&
      cached != null &&
      (cloud == null || cached.day >= cloud.day)) {
    return MorningPick.cached;
  }
  if (cloud != null) return MorningPick.cloud;
  if (cached != null) return MorningPick.cached;
  return MorningPick.fresh;
}

/// A cloud upload must not move the account back to an earlier day unless
/// the player confirmed "Chơi mới" ([allowLower]).
bool mayReplaceCloud({
  required int cloudDay,
  required int nextDay,
  required bool allowLower,
}) => allowLower || nextDay >= cloudDay;

// Sign-in lines. Copy is easy to change here.

/// Save line on the title and in Cài đặt.
String accountSaveLabel(String name) => 'Tài khoản: $name';

/// Guest play: the banner under the coin bar and the title line.
const guestSaveLabel = 'Đang chơi thử, tiến độ không được lưu';

/// Small button on the guest banner. Starts Google sign-in.
const guestSignInButton = 'Đăng nhập để lưu';

/// Reload with a remembered account while the login is restored.
const openingShopLabel = 'Đang mở tiệm...';

/// The login or the cloud save is still not there; it keeps trying.
const openingRetryLabel = 'Chưa mở được tiệm, đang thử lại...';

/// The remembered login is gone (signed out elsewhere or expired).
const loginExpiredNotice =
    'Phiên đăng nhập đã hết. Đăng nhập lại để mở tiệm và lưu tiến độ.';

/// Shown after signing in to an account that has cloud progress.
String accountLoadedNotice(int day) =>
    'Chào mừng chủ tiệm quay lại! Tiệm đang ở ngày $day.';

/// Shown after signing in to an account with no cloud progress yet.
const newAccountNotice = 'Tiệm mới mở cửa, mình bắt đầu từ ngày 1 nhé.';

/// The cloud save could not be read on a manual sign-in.
const accountPullFailedNotice =
    'Chưa mở được sổ tiệm của tài khoản, bạn thử lại sau chút nhé.';

/// Seat lost: another tab or device opened this account. The game pauses
/// here until the player takes the shop back.
const seatLostTitle = 'Tiệm đang được mở ở nơi khác.';
const seatLostButton = 'Mở lại tiệm ở đây';

/// "Chơi mới" confirm while signed in with progress on the account.
const newGameCloudTitle = 'Bắt đầu tiệm mới?';
String newGameReplacesCloud(int day) =>
    'Tiệm Ngày $day trên tài khoản sẽ được thay bằng tiệm mới từ ngày 1, '
    'không lấy lại được.';
const newGameKeepButton = 'Giữ tiệm cũ';
const newGameRestartButton = 'Bắt đầu lại';
