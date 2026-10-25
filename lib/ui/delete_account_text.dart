import '../logic/platform_flags.dart';

/// Chữ của Nhất: chu_ung_dung_v1.md mục 1, 2, 4, 7 và phần bổ sung 11/10.
/// Keys in the comments are the ones in that file.
class DeleteText {
  const DeleteText._();

  // 1. Cài đặt
  static const settingsTitle = 'Xóa tài khoản và dữ liệu'; // settings.delete_account.title
  static const settingsSubtitle =
      'Xóa hẳn tài khoản và mọi thứ của bạn trong tiệm'; // ...subtitle

  // 2. Hộp thoại xác nhận
  static const title = 'Xóa tài khoản và dữ liệu?';
  static const intro = 'Khi xóa, những thứ này sẽ mất hẳn:';
  static const list = [
    'Tiến trình, xu, Pha lê, chậu, thú cưng, sổ sưu tầm',
    'Hồ sơ, tên tiệm, tên hiển thị và avatar của bạn',
    'Điểm và thứ hạng Mị lực ở tất cả các mùa',
    'Bình luận của bạn, Hộp thư và quà chưa nhận',
    'Tài khoản đăng nhập Google của game',
  ];
  static const outro =
      'Không thể quay lại. Pha lê còn lại sẽ mất và không được hoàn tiền.';
  static const keptNote =
      'Tiệm chỉ giữ bản ghi đơn đã trả tiền 10 năm cho sổ sách, không còn gắn '
      'với tài khoản của bạn. Xem thêm ở trang Xóa tài khoản và dữ liệu.';
  static const keptNoteIos =
      'Tiệm chỉ giữ một số bản ghi giao dịch 10 năm cho sổ sách, không còn gắn '
      'với tài khoản của bạn. Xem thêm ở trang Xóa tài khoản và dữ liệu.';
  static const typedHint = 'Gõ XÓA (hoặc XOA) để xác nhận';
  static const typedPlaceholder = 'XÓA';
  static const confirm = 'Xóa tài khoản';
  static const cancel = 'Giữ tài khoản';
  static const more = 'Xem chi tiết cách xóa';
  static const moreUrl = 'https://tiemhoasommai.com/xoa-tai-khoan';

  /// xoa.confirm.phale: only when the balance is above 0 and not on iOS.
  static String phale(int n) =>
      'Bạn đang có ${_dots(n)} Pha lê. Xóa tài khoản thì Pha lê, xu và đồ đều '
      'mất, không hoàn tiền và không chuyển sang tài khoản khác.';

  /// The kept-records line for this build.
  static String get kept => isIosApp ? keptNoteIos : keptNote;

  // 4. Tiến trình, thành công, thất bại
  static const progress = 'Tiệm đang dọn dẹp, bạn đợi chút nhé...';
  static const progressSub = 'Đừng đóng app khi đang xóa.';
  static const doneTitle = 'Đã xóa xong';
  static const doneBody =
      'Tài khoản và dữ liệu của bạn đã được xóa. Cảm ơn bạn đã ghé tiệm.';
  static const doneButton = 'Về màn đầu';
  static const failGeneric = 'Chưa xóa được. Bạn thử lại sau nhé.';
  static const failNetwork = 'Mất mạng rồi. Kiểm tra kết nối rồi thử lại nhé.';
  static const failPartial = 'Xóa chưa xong hết. Bạn thử lại, hoặc gửi email cho tiệm.';
  /// delete.fail.blocked: no top-up wording, so it is the iOS message too.
  static const failBlocked =
      'Tài khoản đang có giao dịch chưa xong. Bạn đợi ít phút rồi thử lại nhé.';
  /// delete.confirm.backup_note
  static const backupNote =
      'Bản sao lưu của nhà cung cấp có thể còn giữ một thời gian.';
  static const retry = 'Thử lại';
  static const email = 'Gửi email cho tiệm';
  static const close = 'Đóng';

  // Bổ sung 11/10
  static const blocked = 'Đơn nạp đang xử lý, thử lại sau ít phút.'; // xoa.blocked.donNap
  static const blockedHint =
      'Chờ đơn nạp xong rồi xóa, để tiền bạn chuyển không bị mất Pha lê.'; // xoa.blocked.hint

  // 7. Hỗ trợ
  static const supportEmail = 'anxaitech@gmail.com';
  static const mailSubject = 'Xóa tài khoản Tiệm Hoa Sớm Mai';

  /// mailto: link with the subject and the account email already in the body.
  static String mailto(String accountEmail) => Uri(
    scheme: 'mailto',
    path: supportEmail,
    query: [
      'subject=${Uri.encodeComponent(mailSubject)}',
      'body=${Uri.encodeComponent('Tài khoản cần xóa: $accountEmail')}',
    ].join('&'),
  ).toString();

  /// Nút "Xóa tài khoản" chỉ bấm được khi gõ đúng XÓA hoặc XOA, không phân biệt
  /// hoa thường, bỏ khoảng trắng đầu và cuối. The accent may arrive composed
  /// (ó) or as o + a combining mark (what some keyboards type).
  static bool typedOk(String input) {
    var s = input.trim().toLowerCase().replaceAll('\u0301', '');
    s = s.replaceAll('ó', 'o');
    return s == 'xoa';
  }

  static String _dots(int n) {
    final s = n.abs().toString();
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }
}
