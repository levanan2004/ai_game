import '../logic/price_format.dart';

/// Texts of the Pha lê shop, one getter per `phale.*` key of
/// SPEC_cua_hang_phale.md section 8. Every one of them is still PENDING
/// Nhất's approval (the spec calls them "chữ tạm"); the key is in the comment.
class PhaleText {
  const PhaleText._();

  static const title = 'Cửa hàng Pha lê'; // phale.title
  static const pick = 'Chọn gói'; // phale.pick
  static String amount(int n) => '${coinFull(n)} Pha lê'; // phale.pack.amount
  static String price(int vnd) => vndLabel(vnd); // phale.pack.price
  static String bonus(int n) => '+$n%'; // phale.pack.bonus
  static const best = 'Đáng giá nhất'; // phale.pack.best
  static const buy = 'Mua'; // phale.pack.buy

  static const useTitle = 'Pha lê dùng để làm gì'; // phale.use.title
  static const usePot = 'Chậu hoa'; // phale.use.pot
  static const usePet = 'Thú cưng'; // phale.use.pet
  static const useItem = 'Đồ pet'; // phale.use.item
  static String useFrom(int n) => 'Từ $n'; // phale.use.from
  static const note =
      'Pha lê chỉ mua bằng tiền thật, không đổi qua xu.'; // phale.note
  static const linkTerms = 'Điều khoản'; // phale.link.terms
  static const linkOrders = 'Đơn của tôi'; // phale.link.orders (proposal)

  static String confirmTitle(int n) =>
      'Mua ${coinFull(n)} Pha lê?'; // phale.confirm.title
  static const confirmQr =
      'Chuyển khoản qua mã QR. Pha lê vào ví khi tiệm nhận được tiền.'; // phale.confirm.qr
  static const confirmAge = 'Dưới 16 tuổi, hãy nhờ bố mẹ đồng ý.'; // .age
  static const confirmGet = 'Bạn nhận'; // .get
  static const confirmBonus = 'Đã gồm thưởng'; // .bonus
  static const confirmPrice = 'Giá'; // .price
  static const confirmLater = 'Để sau'; // .later
  static const confirmOk = 'Mua'; // .ok

  static const createTitle = 'Đang tạo đơn'; // phale.create.title
  static const createL1 = 'Chờ một chút nhé.'; // .l1
  static const createL2 = 'Sắp có mã QR để chuyển khoản.'; // .l2

  static const createFailTitle = 'Chưa tạo được đơn'; // phale.createfail.title
  static const createFailBody =
      'Không kết nối được. Bạn chưa bị tính tiền.'; // .body
  static const createFailRetry = 'Thử lại'; // .retry
  static const createFailLater = 'Để sau'; // .later

  static const orderTitle = 'Chuyển khoản'; // phale.order.title
  static const orderWait = 'Đang chờ tiền về'; // .wait
  static const orderCheck = 'Đang kiểm tra…'; // .check
  static const orderRetry = 'Đang thử lại…'; // .retry
  static String orderTimer(String mmss) => 'Còn $mmss'; // .timer
  static const orderTimerEnd = 'Hết hạn'; // .timer_end
  static const orderSaveQr = 'Lưu ảnh QR'; // .saveqr
  static const orderBank = 'Ngân hàng'; // .bank
  static const orderName = 'Chủ tài khoản'; // .name
  static const orderAcc = 'Số tài khoản'; // .acc
  static const orderAmount = 'Số tiền'; // .amount
  static const orderCopySmall = 'Chép'; // .copy_small
  static const orderMemo = 'Nội dung chuyển khoản'; // .memo
  static const orderMemoSub = 'Mã đơn, chỉ dùng một lần'; // .memo_sub
  static const orderCopy = 'Sao chép'; // .copy
  static const orderCopied = 'Đã sao chép'; // .copied
  static const orderRule1 = 'Chuyển đúng số tiền và đúng nội dung.'; // .rule1
  static const orderRule2 = 'Giữ nguyên nội dung chuyển khoản.'; // .rule2
  static const orderRule3 = 'Pha lê tự vào ví khi tiền về.'; // .rule3
  static const orderPaid = 'Tôi đã chuyển'; // .paid
  static const orderNotYet = 'Chưa thấy tiền về. Chờ thêm chút nhé.'; // .notyet
  static const orderCancel = 'Hủy đơn'; // .cancel
  static const demoChip = 'DEMO'; // not in the spec: marks fake order data
  static const qrFake =
      'QR GIẢ'; // not in the spec: the mock's label on the fake QR

  static const cancelAskTitle = 'Hủy đơn này?'; // phale.cancelask.title
  static const cancelAskBody = 'Chỉ hủy khi bạn chưa chuyển tiền.'; // .body
  static const cancelAskHint =
      'Đã chuyển rồi? Đừng hủy. Chờ tiền về hoặc liên hệ hỗ trợ.'; // .hint
  static const cancelAskYes = 'Hủy đơn'; // .yes
  static const cancelAskNo = 'Giữ đơn'; // .no

  static const cancelledTitle = 'Đơn đã hủy'; // phale.cancelled.title
  static const cancelledBody =
      'Mã QR cũ đã hết hiệu lực. Đừng chuyển tiền vào mã cũ.'; // phale.cancelled.body
  static const cancelledHint =
      'Đã chuyển rồi? Pha lê vẫn vào ví khi tiền về. Chờ lâu thì gửi mã đơn cho hỗ trợ.'; // phale.cancelled.hint
  static const cancelledClose = 'Đóng'; // .close
  static const cancelledNew = 'Tạo đơn mới'; // .new

  static const expiredChip = 'Đơn đã hết hạn'; // phale.expired.chip
  static const expiredLock = 'Mã hết hạn'; // .lock
  static const expiredTitle =
      'Mã này đã hết hạn, đừng chuyển thêm.'; // phale.expired.title
  static const expiredHint =
      'Đã chuyển đúng rồi? Pha lê vẫn vào ví khi tiền về. Chờ lâu thì gửi mã đơn cho hỗ trợ:'; // phale.expired.hint

  static const mismatchChip = 'Chưa khớp đơn'; // phale.mismatch.chip
  static const mismatchTitle = 'Chưa khớp đơn'; // .title
  static const mismatchBody =
      'Tiệm thấy tiền về nhưng số tiền hoặc nội dung chưa khớp đơn, nên chưa cộng Pha lê.'; // phale.mismatch.body
  static const mismatchNeed = 'Đơn cần'; // .need
  static const mismatchMemo = 'Nội dung'; // .memo
  static const mismatchFoot =
      'Gửi mã đơn cho hỗ trợ, tiệm sẽ kiểm tra rồi báo bạn.'; // phale.mismatch.foot
  static const mismatchSupport = 'Liên hệ hỗ trợ'; // .support

  /// Where "Liên hệ hỗ trợ" leads for now (the address on the Liên hệ page).
  /// Change it here only.
  static const supportEmail = 'anxaitech@gmail.com';

  /// A mail to support with the order code in the subject and the body.
  static String supportMailto(String orderCode) {
    final subject = Uri.encodeComponent('Hỗ trợ đơn nạp Pha lê $orderCode');
    final body = Uri.encodeComponent(
      'Mã đơn: $orderCode\nMình đã chuyển khoản nhưng chưa thấy Pha lê. '
      'Nhờ tiệm kiểm tra giúp mình.',
    );
    return 'mailto:$supportEmail?subject=$subject&body=$body';
  }

  // A second transfer for an order that is already paid. No promise of a
  // refund: the shop looks at it and tells the player.
  static const duplicateTitle = 'Chuyển khoản trùng'; // phale.duplicate.title
  static const duplicateBody =
      'Tiệm thấy hai lần chuyển cho cùng một đơn. Tiệm sẽ kiểm tra rồi báo bạn.'; // .body

  static const offlineBanner =
      'Mất kết nối. Đơn vẫn giữ, app sẽ tự thử lại.'; // phale.offline.banner

  static const pendingTitle = 'Bạn có đơn đang chờ'; // phale.pending.title
  static String pendingSub(String price, String mmss) =>
      '$price · còn $mmss'; // .sub
  static const pendingBtn = 'Xem đơn'; // .btn

  static const doneTitle = 'Đã nhận tiền!'; // phale.done.title
  static const doneAdded = 'Cộng thêm'; // .added
  static const doneBalance = 'Số dư mới'; // .balance
  static const doneMsg = 'Pha lê đã vào ví của bạn.'; // .msg
  static const doneBtn = 'Xong'; // .btn

  static const guestStrip = 'Cần đăng nhập để mua Pha lê'; // phale.guest.strip
  static const guestBtn = 'Đăng nhập'; // .btn
  static const guestToast = 'Đăng nhập để mua Pha lê'; // .toast

  static const poorHave = 'Bạn có'; // phale.poor.have
  static const poorNeed = 'Cần'; // .need
  static String poorShort(int n) => 'Thiếu ${coinFull(n)} Pha lê'; // .short
  static const poorCta = 'Nạp thêm Pha lê'; // .cta
  static const poorLater = 'Để sau'; // .later

  static String ctxBanner(int n, String name) =>
      'Cần thêm ${coinFull(n)} Pha lê để mua $name'; // phale.ctx.banner

  static const settingsRow = 'Cửa hàng Pha lê'; // phale.settings.row
  static const settingsSub = 'Nạp Pha lê bằng tiền thật'; // .sub
  static const settingsOpen = 'Mở'; // .open

  static const loadHint = 'Đang tải gói…'; // phale.load.hint
  static const errTitle = 'Chưa lấy được giá'; // phale.err.title
  static const errBody = 'Kiểm tra mạng rồi thử lại.'; // .body
  static const errRetry = 'Thử lại'; // .retry

  static const soonBanner =
      'Nạp Pha lê sắp mở, bạn chờ chút nhé.'; // phale.soon.banner
  static const soonBtn = 'Sắp mở'; // .btn
  static const soonToast = 'Chưa mở nạp. Bạn quay lại sau nhé.'; // .toast

  /// "mm:ss" of a countdown.
  static String clock(Duration d) {
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }
}
