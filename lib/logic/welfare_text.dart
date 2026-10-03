/// Player-facing copy for Phúc lợi and Hộp thư, from the writer. Keep every
/// string here so wording changes touch one file.
abstract final class WelfareText {
  // Điểm danh
  static const loginTitle = 'Điểm danh mỗi ngày';
  static String loginDay(int n) => 'Ngày $n';
  static const loginClaim = 'Nhận quà';
  // Placeholders until Nhất writes them.
  static const loginWeekNewbie = 'Tuần tân thủ';
  static const loginWeekly = 'Quà hằng tuần';
  static String loginTotal(int n) => 'Đã điểm danh $n ngày';
  static String loginMilestone(int day) => 'Mốc $day ngày';
  static const loginClaimed = 'Đã nhận';
  static String loginDone(int n) =>
      'Đã nhận quà ngày $n! Mai ghé tiệm nhận tiếp nhé.';

  /// Nhất's copy, ticking every second.
  static String loginNext(Duration left) {
    String two(int n) => n.toString().padLeft(2, '0');
    final s = left.isNegative ? 0 : left.inSeconds;
    return 'Quà tiếp theo sau '
        '${two(s ~/ 3600)}:${two(s ~/ 60 % 60)}:${two(s % 60)}';
  }

  static const loginAlready = 'Hôm nay bạn nhận rồi, mai quay lại nha.';
  static const loginGuest =
      'Đăng nhập để điểm danh và giữ quà trên tài khoản nhé.';

  static String loginFinished({required bool repeat}) => repeat
      ? 'Bạn đã nhận đủ quà 7 ngày rồi! Vòng mới sẽ bắt đầu sớm thôi.'
      : 'Bạn đã nhận đủ quà 7 ngày rồi, cảm ơn chủ tiệm!';
  static const loginBusy = 'Đang ghi tên vào sổ điểm danh...';
  static const loginRefused =
      'Chưa điểm danh được. Bạn đăng nhập lại rồi thử nhé.';
  static const loginFailed =
      'Mạng hơi chậm, chưa điểm danh được. Bạn thử lại sau chút nhé.';

  // Giftcode
  static const codeHint = 'Nhập mã quà tặng';
  static const codeButton = 'Đổi quà';
  static const codeSuccess = 'Đổi mã thành công! Quà đã vào tiệm.';
  static const codeWrong = 'Mã này không đúng, bạn kiểm tra lại nhé.';
  static const codeExpired = 'Mã này đã hết hạn mất rồi.';
  static const codeUsed = 'Mã này đã có người dùng rồi.';
  static const codeAlready = 'Bạn đã đổi mã này rồi nha.';
  static const codeGuest = 'Đăng nhập để đổi mã quà tặng nhé.';

  static const codeEmpty = 'Bạn nhập mã quà tặng vào ô trên nhé.';
  static const codeBusy = 'Đang mở quà...';
  static const codeRefused =
      'Chưa đổi được mã này. Bạn đăng nhập lại rồi thử nhé.';
  static const codeFailed =
      'Mạng hơi chậm, chưa đổi được mã. Bạn thử lại sau chút nhé.';

  // Hộp thư
  static const mailEmpty = 'Hộp thư đang trống. Có quà là tiệm báo bạn liền!';
  static const mailExpired = 'Thư này đã hết hạn.';

  // Bạn biết? (shown while the slides collection is empty)
  static const defaultSlides = [
    'Hoa để lâu sẽ héo và mất luôn. Mua vừa đủ bán trong ngày là bí quyết của chủ tiệm giỏi.',
    'Khách thần bí ghé tiệm mỗi 10 ngày và tặng Giọt hoa. Giọt hoa giúp mèo lớn lên.',
    'Mèo càng lớn thì chuột càng khó lấy trộm hoa của tiệm.',
  ];
}
