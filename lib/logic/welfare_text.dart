/// Player-facing copy for Phúc lợi and Hộp thư, from the writer. Keep every
/// string here so wording changes touch one file.
abstract final class WelfareText {
  // Điểm danh
  static const loginTitle = 'Điểm danh mỗi ngày';
  static String loginDay(int n) => 'Ngày $n';
  static const loginClaim = 'Nhận quà';
  static const loginClaimed = 'Đã nhận';
  static String loginDone(int n) =>
      'Đã nhận quà ngày $n! Mai ghé tiệm nhận tiếp nhé.';
  static const loginAlready = 'Hôm nay bạn nhận rồi, mai quay lại nha.';
  static const loginGuest =
      'Đăng nhập để điểm danh và giữ quà trên tài khoản nhé.';

  // Not in the writer's copy yet.
  static const loginFinished = 'Bạn đã nhận đủ 7 ngày.';
  static const loginBusy = 'Đang nhận…';
  static const loginRefused =
      'Chưa nhận được. Mở lại tiệm bằng tài khoản Google rồi thử nhé.';
  static const loginFailed =
      'Chưa nhận được. Kiểm tra mạng và giờ trên máy rồi thử lại nhé.';

  // Giftcode
  static const codeHint = 'Nhập mã quà tặng';
  static const codeButton = 'Đổi quà';
  static const codeSuccess = 'Đổi mã thành công! Quà đã vào tiệm.';
  static const codeWrong = 'Mã này không đúng, bạn kiểm tra lại nhé.';
  static const codeExpired = 'Mã này đã hết hạn mất rồi.';
  static const codeUsed = 'Mã này đã có người dùng rồi.';
  static const codeAlready = 'Bạn đã đổi mã này rồi nha.';
  static const codeGuest = 'Đăng nhập để đổi mã quà tặng nhé.';

  // Not in the writer's copy yet.
  static const codeEmpty = 'Nhập mã quà tặng trước nhé.';
  static const codeBusy = 'Đang đổi mã…';
  static const codeRefused =
      'Chưa đổi được. Mở lại tiệm bằng tài khoản Google rồi thử nhé.';
  static const codeFailed = 'Chưa đổi được, thử lại nhé.';

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
