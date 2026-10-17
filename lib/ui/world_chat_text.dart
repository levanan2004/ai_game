/// Tin thế giới text, verbatim from Nhất (tiem-hoa-marketing/v6_tin_the_gioi:
/// chu_tin_the_gioi.md, chu_tinh_nang_moi.md mục 5, noi_quy_tin_the_gioi.md).
/// Keys in the comments. {…} slots are filled by the helpers below.
library;

class ChatText {
  ChatText._();

  static const title = 'Tin thế giới'; // worldchat.title
  static const caption = '100 tin gần nhất'; // worldchat.header.caption
  static const placeholder = 'Nói gì đó với cả phố hoa...';
  static const send = 'Gửi'; // worldchat.input.send_btn
  static String cooldown(int n) => 'Chờ ${n}s nữa nhé'; // worldchat.cooldown
  static String cooldownPlaceholder(int n) => 'Chờ $n giây để gửi tiếp';
  static String counter(int n, int max) => '$n/$max'; // input.counter
  static String tooLong(int max) =>
      'Tin dài quá $max ký tự rồi, rút gọn giúp tiệm nhé.';
  static const empty = 'Bạn chưa gõ gì cả.'; // worldchat.input.empty
  static const sendFail = 'Chưa gửi được. Chạm để thử lại.';
  static const offline = 'Mất mạng rồi. Có mạng lại thì gửi nhé.';
  static const rulesBtn = 'Luật chat'; // worldchat.rules.btn
  static const rulesTitle = 'Nội quy Tin thế giới';
  static const limitNote = 'Chỉ hiện 100 tin mới nhất. Tin cũ hơn sẽ tự trôi đi.';
  static const newMessages = 'Tin mới ↓'; // worldchat.new_messages.pill
  static const official = 'Tiệm'; // worldchat.official.badge
  static const guestLocked = 'Đăng nhập để trò chuyện';
  static const guestLogin = 'Đăng nhập';
  static const blocked = 'Tin nhắn có từ không phù hợp, bạn sửa lại nhé.';
  static const blockedLink =
      'Tin thế giới không nhận link, số điện thoại hay tên mạng xã hội.';
  static const masked = 'Một số từ đã được ẩn.'; // filter.masked_note

  /// No key for "the same text again within 60 s" yet: a verbatim fragment
  /// of noi_quy_tin_the_gioi.md điều 6 until Nhất writes one (reported).
  static const duplicate = 'Không gửi lặp một câu nhiều lần';

  static String muted(String time) => 'Bạn đang bị khóa chat, còn $time.';
  static String mutedUntil(String hour, String day) =>
      'Bạn tạm thời không thể chat đến $hour $day.'; // muted.until
  static const banned = 'Bạn không còn gửi được tin ở Tin thế giới.';
  static String minutes(int m) => '$m phút'; // muted.time.minutes
  static String hours(int h, int m) => '$h giờ $m phút';
  static String days(int d, int h) => '$d ngày $h giờ';

  /// worldchat.penalty.form.* (the admin's level picker uses them too).
  static const penalty = {
    'warning': 'nhắc nhở lần này',
    'mute_1h': 'khóa chat 1 giờ',
    'mute_24h': 'khóa chat 24 giờ',
    'mute_7d': 'khóa chat 7 ngày',
    'ban': 'cấm chat vĩnh viễn',
  };

  static const menuReport = 'Báo cáo'; // msg.menu.report
  static String menuBlock(String shop) => 'Chặn $shop'; // msg.menu.block
  static const menuProfile = 'Xem hồ sơ'; // msg.menu.view_profile
  static const menuCopy = 'Sao chép'; // msg.menu.copy
  static const copied = 'Đã sao chép.'; // msg.copied.toast

  static const reportTitle = 'Báo cáo tin nhắn này';
  static const reportIntro =
      'Chọn lý do. Tiệm sẽ xem xét và không cho người kia biết ai báo cáo.';
  static const reportNoteHint = 'Ghi thêm (không bắt buộc, tối đa 200 chữ)';
  static const reportSend = 'Gửi báo cáo';
  static const reportCancel = 'Hủy';
  static const thanksTitle = 'Cảm ơn bạn đã báo cho Tiệm';

  /// worldchat.report.thanks.body; {gio_xu_ly} = 24 (noi_quy điều 8, chờ An).
  static String thanksBody(String shop) =>
      'Tiệm sẽ xem trong vòng 24 giờ. Bạn có muốn chặn $shop luôn không?';
  static const thanksBlock = 'Chặn luôn';
  static const thanksClose = 'Để vậy';
  static const reportSent = 'Tiệm đã nhận báo cáo, cảm ơn bạn.';
  static const reportFail = 'Chưa gửi được báo cáo. Bạn thử lại nhé.';
  static const reportAlready = 'Bạn đã báo cáo tin này rồi. Tiệm đang xem.';
  static const urgentHint =
      'Ai làm bạn sợ hay đòi gặp ngoài đời? Kể với người lớn và email anxaitech@gmail.com.';

  static String blockTitle(String shop) => 'Chặn $shop?';
  static const blockBody =
      'Bạn sẽ không thấy tin của tiệm này ở Tin thế giới nữa. Họ không được báo là bị chặn.';
  static const blockBtn = 'Chặn';
  static const blockCancel = 'Thôi';
  static String blocked1(String shop) =>
      'Đã chặn $shop. Bỏ chặn ở Cài đặt > Người đã chặn.';
  static const blockSelf = 'Đây là tiệm của bạn.';
  static const blockOfficial = 'Không chặn được tin của Tiệm.';
  static String unblockTitle(String shop) => 'Bỏ chặn $shop?';
  static const unblockBody = 'Bạn sẽ thấy lại tin mới của tiệm này.';
  static const unblockBtn = 'Bỏ chặn';
  static const unblockCancel = 'Giữ chặn';
  static String unblocked(String shop) => 'Đã bỏ chặn $shop.';

  static const blockedTitle = 'Người đã chặn'; // settings.blocked.title
  static const blockedSubtitle = 'Những tiệm bạn không muốn thấy tin';
  static String blockedCount(int n) => 'Đang chặn $n tiệm';
  static const blockedEmpty = 'Bạn chưa chặn ai. Phố hoa vẫn yên bình.';

  static const emptyTitle = 'Phố hoa đang yên ắng';
  static const emptyBody = 'Chưa có tin nào. Chào mọi người một tiếng nhé!';
  static const loading = 'Tiệm đang mở cửa sổ, đợi chút nhé...';
  static const loadFail = 'Mất kết nối rồi. Thử lại nhé!';
  static const loadFailBtn = 'Thử lại';
  static const someBlocked = 'Một số tin đã được ẩn vì bạn chặn người gửi.';
  static const disabled =
      'Tin thế giới đang tạm nghỉ để Tiệm dọn dẹp. Bạn quay lại sau nhé.';

  /// chu_tinh_nang_moi.md mục 5 (worldchat.locked_day.*).
  static String lockedDay(int day, int left) =>
      'Tin thế giới mở từ ngày thứ $day của tiệm (còn $left ngày).';
  static const lockedTitle = 'Tin thế giới sắp mở';
  static String lockedBody(int day) =>
      'Bạn vẫn đọc được tin. Tới ngày thứ $day của tiệm là gửi được nhé!';

  /// noi_quy_tin_the_gioi.md, bản ngắn (worldchat.rules_popup.*).
  static const popupTitle = 'Chào bạn tới Tin thế giới';
  static const popupLines = [
    'Nói chuyện tử tế: không chửi bậy, quấy rối, nội dung người lớn hay công kích ai.',
    'Không mua bán acc, xu, Pha lê lấy tiền thật; không ghi số điện thoại, link, Zalo, FB.',
    'Thấy tin không ổn thì bấm vào tin để Báo cáo hoặc Chặn. Vi phạm có thể bị khóa chat.',
  ];
  static const popupCheck =
      'Mình đã đọc nội quy và sẽ giữ phố hoa thật dễ thương';
  static const popupConfirm = 'Vào trò chuyện';
  static const popupCancel = 'Để sau';
  static const popupFull = 'Đọc nội quy đầy đủ';

  /// noi_quy_tin_the_gioi.md "Nội quy đầy đủ", without the markdown and the
  /// [chờ …] notes.
  static const rulesIntro =
      'Tin thế giới là góc trò chuyện chung của cả phố hoa. Ai cũng đọc được tin của bạn, nên mình cùng giữ cho nơi này dễ chịu như một buổi sáng ở tiệm nhé.';
  static const rules = [
    'Nói chuyện tử tế. Không chửi bậy, không xúc phạm, quấy rối hay bắt nạt ai. Không công kích chính trị, tôn giáo, vùng miền, dân tộc, giới tính hay ngoại hình của người khác.',
    'Không có nội dung người lớn. Không gửi chữ, lời gạ gẫm hay mô tả tình dục. Phố hoa có nhiều bạn nhỏ.',
    'Không lừa đảo, không mua bán bằng tiền thật. Không mua, bán, trao đổi tài khoản, xu hay Pha lê để lấy tiền thật hay thẻ cào. Không "nạp hộ", "cày thuê", "tặng Pha lê miễn phí". Xu và Pha lê chỉ dùng trong game và không đổi ra tiền được.',
    'Không quảng cáo, không đường dẫn. Không dán link, không mời vào nhóm hay trang khác, không quảng cáo shop, kênh hay game khác.',
    'Giữ thông tin riêng cho mình. Không ghi số điện thoại, địa chỉ, trường lớp, email, Zalo, Facebook, Instagram, TikTok hay tên tài khoản mạng xã hội, của bạn hay của người khác.',
    'Không spam, không giả làm Tiệm. Không gửi lặp một câu nhiều lần, không gõ vô nghĩa cho trôi tin. Không xưng là admin, người quản trị hay "đội Tiệm". Tin thật của Tiệm luôn có nhãn Tiệm cạnh tên.',
    'Che chở các bạn nhỏ. Không hỏi tuổi, trường, nơi ở hay xin ảnh của người khác, không rủ ra nói chuyện riêng hay gặp ngoài đời. Bạn dưới 16 tuổi cần phụ huynh đồng ý mới được chơi và đăng nhập. Nếu ai làm bạn thấy sợ hay khó chịu, bạn bấm Báo cáo, kể với người lớn, hoặc email cho Tiệm.',
    'Thấy tin không ổn? Báo cáo hoặc Chặn. Bấm vào tin nhắn (hoặc bấm giữ), chọn Báo cáo, rồi chọn lý do. Tiệm xem từng báo cáo bằng tay, trong vòng 24 giờ, và không cho người kia biết ai đã báo cáo. Chọn Chặn để không thấy tin của tiệm đó nữa. Họ không được báo là bị chặn. Bạn bỏ chặn được ở Cài đặt > Người đã chặn.',
    'Bậc xử lý. Bộ lọc tự che hoặc chặn chữ chưa hợp. Khi Tiệm xác nhận một lần vi phạm, Tiệm có thể gỡ tin và xử lý theo bậc: Lần 1: nhắc nhở. Lần 2: khóa chat 1 giờ. Lần 3: khóa chat 24 giờ. Lần 4: khóa chat 7 ngày. Lần 5: cấm chat vĩnh viễn. Bậc được tính lại từ đầu nếu bạn không vi phạm thêm trong 90 ngày. Tin bị bộ lọc chặn không tính là một lần vi phạm. Lừa đảo, mua bán tài khoản hay Pha lê bằng tiền thật, nội dung tình dục nhắm tới bạn nhỏ, đe dọa người khác hay để lộ thông tin riêng của người khác: cấm chat vĩnh viễn ngay, và có thể khóa cả tài khoản (Quy chế hoạt động, mục Khóa tài khoản). Nghĩ mình bị xử lý nhầm? Email anxaitech@gmail.com hoặc vào https://tiemhoasommai.com/contact, Tiệm xem lại.',
    'Vài điều nên biết. Mỗi người gửi được 1 tin mỗi 10 giây, mỗi tin tối đa 80 ký tự. Tiệm mở được Tin thế giới từ ngày thứ 5 trong game; trước đó bạn vẫn đọc được tin. Tin thế giới chỉ giữ 100 tin mới nhất: có tin mới thì tin cũ nhất tự trôi đi. Cần đăng nhập Google mới gửi được tin; khách chỉ đọc.',
  ];
  static const rulesHelp =
      'Cần giúp hay muốn báo chuyện gấp? Email anxaitech@gmail.com · https://tiemhoasommai.com/contact';
}
