/// Vòng quay tuần and Thẻ gacha texts from Nhất
/// (v6_tin_the_gioi/chu_tinh_nang_moi.md, 17/10, mục 1a–1j), key in the
/// comment. Placeholders become parameters; nothing here is invented.
class GachaText {
  const GachaText._();

  /// `ticket.name.<pot id>` ({ticket_name}); null for an unknown pot.
  static String? ticketName(String potId) => _ticketNames[potId];

  static const _ticketNames = {
    'chau_cuu_vi_ho': 'Thẻ gacha Cửu Vĩ Hồ',
    'chau_chuc_long': 'Thẻ gacha Chúc Long',
    'chau_con_bang': 'Thẻ gacha Côn Bằng',
    'chau_bach_trach': 'Thẻ gacha Bạch Trạch',
    'chau_thao_thiet': 'Thẻ gacha Thao Thiết',
    'chau_cung_ky': 'Thẻ gacha Cùng Kỳ',
    'chau_hon_don': 'Thẻ gacha Hỗn Độn',
    'chau_dao_ngot': 'Thẻ gacha Đào Ngột',
    'chau_tat_phuong': 'Thẻ gacha Tất Phương',
    'chau_tinh_ve': 'Thẻ gacha Tinh Vệ',
    'chau_de_giang': 'Thẻ gacha Đế Giang',
    'chau_ky_lan': 'Thẻ gacha Kỳ lân xanh',
  };

  /// `ticket.buy.xu_daily_left`; [max] = {xu_ticket_daily_max}
  /// (`gacha.ticketPrice.maxCoinTicketsPerDay`).
  static String xuDailyLeft(int k, int max) =>
      'Mua bằng xu: còn $k/$max thẻ hôm nay';

  /// `ticket.buy.xu_daily_out`
  static String xuDailyOut(int max) =>
      'Hôm nay bạn đã mua đủ $max thẻ bằng xu. Mai mua tiếp nhé.';

  /// `ticket.buy.xu_over_limit`
  static String xuOverLimit(int k) =>
      'Hôm nay chỉ còn mua được $k thẻ bằng xu.';

  /// `ticket.short.xu_limit`
  static String shortXuLimit(int k, int n) =>
      'Hôm nay còn mua được $k thẻ bằng xu, chưa đủ $n thẻ.';

  /// `ticket.buy.fail.generic`
  static const buyFailGeneric =
      'Chưa mua được thẻ, bạn không bị trừ xu hay Pha lê. Thử lại nhé!';

  /// `ticket.buy.fail.network`
  static const buyFailNetwork =
      'Mất mạng rồi, chưa mua được thẻ. Kiểm tra kết nối rồi thử lại nhé.';

  /// `ticket.buy.fail.limit`: the server refused, xu cards of the day used up.
  static const buyFailLimit = 'Hôm nay đã hết lượt mua thẻ bằng xu.';

  /// `ticket.buy.fail.balance`
  static const buyFailBalance =
      'Số dư vừa thay đổi, chưa đủ để mua. Kiểm tra lại nhé.';

  /// The toast for a refused gachaBuyCards ([WalletException.code]).
  static String buyFail(String code) => switch (code) {
    'limit' => buyFailLimit,
    'balance' => buyFailBalance,
    'network' => buyFailNetwork,
    _ => buyFailGeneric,
  };

  /// `weekly_gift.day7.spin_ticket_sub` (Khoa 14:25: day 7 is claimed on
  /// Phúc lợi itself, so its card is the pot of the week it is claimed in).
  static const day7TicketSub = 'Là thẻ của chậu tuần bạn bấm nhận';

  /// `ticket.buy.gift_note`
  static const giftNote =
      'Thẻ quà VIP và sự kiện là thẻ của chậu tuần mà thư vào Hộp thư. '
      'Thẻ quà ngày 7 là thẻ của chậu tuần bạn bấm nhận.'; // ticket.buy.gift_note

  /// `ticket.gift.converted.toast`
  static String giftConvertedToast(int n, String ticketName) =>
      '$n Thẻ gacha quà là $ticketName, theo chậu của tuần thư được gửi tới.';

  /// `ticket.gift.converted.note`
  static const giftConvertedNote =
      'Thẻ quà là thẻ của chậu Sơn Hải có ở Vòng quay tuần vào lúc thư quà vào '
      'Hộp thư, không phải lúc bạn bấm Nhận.';

  /// `vip.levelup.mail_body` (the VIP mail itself is task 5).
  static String vipLevelUpMailBody(
    String vipBadge,
    int giftK,
    String ticketName,
  ) =>
      'Chúc mừng tiệm của bạn lên $vipBadge. Đây là quà một lần $giftK Thẻ '
      'gacha, Tiệm gửi tặng. Thẻ là $ticketName, thẻ của chậu Sơn Hải tuần thư '
      'này được gửi tới, dùng ở Vòng quay tuần khi chậu đó có mặt.';

  // ---- 1a. Màn vòng quay ----------------------------------------------------

  static const weekTitle = 'Vòng quay tuần'; // spin.week.title
  static String weekSubtitle(String pot) =>
      'Tuần này quay để rước $pot về tiệm'; // spin.week.subtitle
  static String weekCardTitle(String pot) =>
      '$pot · Sơn Hải'; // spin.week.card_title
  static String weekCardSub(int charm) =>
      '+$charm Mị lực khi sở hữu'; // spin.week.card_sub
  static String weekEndsIn(String weekEnd, int d, int h) =>
      'Đổi chậu lúc $weekEnd · còn $d ngày $h giờ'; // spin.week.ends_in
  static String weekEndsInHours(String weekEnd, int h) =>
      'Đổi chậu lúc $weekEnd · còn $h giờ'; // spin.week.ends_in_hours
  static String weekEndsInMinutes(String weekEnd, int m) =>
      'Đổi chậu lúc $weekEnd · còn $m phút'; // spin.week.ends_in_minutes

  /// The countdown: `ends_in`, `ends_in_hours` when 0 days are left,
  /// `ends_in_minutes` under 1 hour (Nhất: never "còn 0 ngày").
  static String weekCountdown(String weekEnd, Duration left) {
    final d = left.inDays;
    final h = left.inHours - d * 24;
    if (d > 0) return weekEndsIn(weekEnd, d, h);
    if (h > 0) return weekEndsInHours(weekEnd, h);
    final m = (left.inSeconds + 59) ~/ 60;
    return weekEndsInMinutes(weekEnd, m < 1 ? 1 : m);
  }

  static String weekNext(String next) => 'Tuần sau: $next'; // spin.week.next
  static String weekChangedToast(String pot) =>
      'Vòng quay đã sang tuần mới: $pot. Thẻ cũ của bạn vẫn còn nguyên.'; // spin.week.changed.toast
  static String weekOwnedNote(String pot, String dupXu) =>
      'Bạn đã có $pot. Trúng chậu này sẽ nhận $dupXu xu thay cho chậu.'; // spin.week.owned_note
  static const btnX1 = 'Quay 1 lượt'; // spin.btn.x1
  static const btnX10 = 'Quay 10 lượt'; // spin.btn.x10
  static const btnCostX1 = 'Dùng 1 thẻ'; // spin.btn.cost_x1
  static const btnCostX10 = 'Dùng 10 thẻ'; // spin.btn.cost_x10
  static const btnSpinning = 'Đang quay…'; // spin.btn.spinning
  static String howToPay(String ticket) =>
      'Mỗi lượt quay dùng 1 $ticket. Mua thẻ bằng xu hoặc Pha lê.'; // spin.how_to_pay
  static const ended =
      'Vòng quay đang đổi sang chậu tuần mới, đợi chút nhé. Thẻ của bạn vẫn còn nguyên.'; // spin.ended
  static const oddsBtn = 'Tỉ lệ'; // spin.odds_btn
  static String oddsShort(String pot, String rate) =>
      '$pot $rate · Xem đầy đủ ở nút Tỉ lệ'; // spin.odds_short
  static const ownedBadge = 'Đã có trong tiệm'; // spin.owned_badge
  static const skipAnimBtn = 'Bỏ qua'; // spin.skip_anim_btn
  static const spinFailGeneric =
      'Chưa quay được, thẻ của bạn vẫn còn nguyên. Thử lại nhé!'; // spin.fail.generic
  static const spinFailNetwork =
      'Mất mạng rồi. Kiểm tra kết nối rồi thử lại nhé.'; // spin.fail.network
  static const pending =
      'Bạn có 1 phần thưởng chưa nhận từ lần quay trước.'; // spin.pending
  static const loadingOdds =
      'Đang tải tỉ lệ, đợi chút nhé...'; // spin.loading_odds
  static const guestLocked =
      'Đăng nhập để quay và giữ phần thưởng'; // spin.guest.locked

  /// The toast for a refused gachaSpin ([WalletException.code]).
  static String spinFail(String code) =>
      code == 'network' ? spinFailNetwork : spinFailGeneric;

  // ---- 1b. Tỉ lệ -------------------------------------------------------------

  static const oddsTitle = 'Tỉ lệ nhận thưởng tuần này'; // spin.odds.title
  static String oddsWeek(String pot, String weekEnd) =>
      'Chậu của tuần: $pot (tới $weekEnd)'; // spin.odds.week
  static String oddsRotation(String time, int len) =>
      'Mỗi tuần một chậu Sơn Hải, đổi lúc $time (giờ VN). $len chậu lần lượt rồi lặp lại.'; // spin.odds.rotation
  static String oddsIntro(String ticket) =>
      'Mỗi $ticket cho đúng 1 lượt quay và 1 phần quà. Tỉ lệ dưới đây giống nhau cho mọi thẻ, dù mua bằng xu, Pha lê hay nhận làm quà.'; // spin.odds.intro
  static String oddsFeatured(String pot, String rate) =>
      '$pot (chậu của tuần): $rate'; // spin.odds.row.featured
  static String oddsFeaturedOwned(String pot, String dupXu, String rate) =>
      'Bạn đã có $pot, nên ô này đổi thành $dupXu xu: $rate'; // spin.odds.row.featured_owned
  static String oddsPetRare(String rate) =>
      'Đồ thú cưng hiếm: $rate'; // spin.odds.row.pet_rare
  static String oddsZodiac(String rate) =>
      'Chậu Hoàng đạo ngẫu nhiên: $rate'; // spin.odds.row.zodiac
  static String oddsXu2m(String rate) =>
      '2.000.000 xu: $rate'; // spin.odds.row.xu_2m
  static String oddsPetCommon(String rate) =>
      'Đồ thú cưng thường: $rate'; // spin.odds.row.pet_common
  static String oddsDrop10(String rate) =>
      '10 Giọt hoa: $rate'; // spin.odds.row.drop_10
  static String oddsXu500k(String rate) =>
      '500.000 xu: $rate'; // spin.odds.row.xu_500k
  static String oddsHoney3(String rate) =>
      '3 Bánh mật: $rate'; // spin.odds.row.honey_3
  static String oddsDrop3(String rate) =>
      '3 Giọt hoa: $rate'; // spin.odds.row.drop_3
  static String oddsXu200k(String rate) =>
      '200.000 xu: $rate'; // spin.odds.row.xu_200k

  /// `spin.odds.item.*`: the items of a group, as Nhất wrote them.
  static const oddsItems = {
    'vong_hoa_nho': '· Vòng hoa cài cổ: khoảng 0,33%',
    'vong_hoa_doi_dau': '· Vòng hoa đội đầu: khoảng 0,33%',
    'canh_buom': '· Cánh bướm: khoảng 0,33%',
    'no_co_vai': '· Nơ cổ vải: 2%',
    'mu_rom': '· Mũ rơm: 2%',
    'tui_vai_nho': '· Túi thêu nhỏ: 2%',
  };
  static const oddsZodiacItems = [
    '· Chậu Bạch Dương: khoảng 0,17%',
    '· Chậu Kim Ngưu: khoảng 0,17%',
    '· Chậu Song Tử: khoảng 0,17%',
    '· Chậu Cự Giải: khoảng 0,17%',
    '· Chậu Sư Tử: khoảng 0,17%',
    '· Chậu Xử Nữ: khoảng 0,17%',
    '· Chậu Thiên Bình: khoảng 0,17%',
    '· Chậu Thiên Yết: khoảng 0,17%',
    '· Chậu Nhân Mã: khoảng 0,17%',
    '· Chậu Ma Kết: khoảng 0,17%',
    '· Chậu Bảo Bình: khoảng 0,17%',
    '· Chậu Song Ngư: khoảng 0,17%',
  ];
  static const oddsX10Note =
      'Quay 10 lượt là 10 lượt riêng, mỗi lượt cùng tỉ lệ trên.'; // spin.odds.x10_note
  static String oddsPity(String pot, int at, String ticket) =>
      'Trong cùng một tuần, nếu chưa ra $pot, lượt thứ $at dùng $ticket chắc chắn ra $pot.'; // spin.odds.pity
  static const oddsPityShared =
      'Bộ đếm tính theo số thẻ của chậu tuần này đã quay, không phân biệt nguồn thẻ; về 0 khi ra chậu, và về 0 khi sang tuần mới (0h thứ Hai).'; // spin.odds.pity_shared
  static String oddsPityOwned(String pot, String dupXu) =>
      'Bạn đã có $pot thì lượt bảo hiểm cho $dupXu xu.'; // spin.odds.pity_owned
  static String oddsTicketPrice(String ticket, String xu, String pl) =>
      'Giá $ticket hôm nay: $xu xu (theo ngày của tiệm) hoặc $pl Pha lê mỗi thẻ.'; // spin.odds.ticket_price
  static String oddsTicketWeekOnly(String pot) =>
      'Tuần này chỉ bán thẻ của $pot. Thẻ không hết hạn.'; // spin.odds.ticket_week_only
  static const oddsNoPl =
      'Vòng quay không có Pha lê trong phần quà.'; // spin.odds.no_pl
  static const oddsServer =
      'Kết quả được máy chủ quyết định ngẫu nhiên theo đúng tỉ lệ trên.'; // spin.odds.server
  static const oddsGroupDetail =
      'Xem từng món trong nhóm đồ thú cưng và chậu Hoàng đạo'; // spin.odds.group_detail
  static const oddsGroupNote =
      'Trong mỗi nhóm, các món có khả năng ra như nhau. Có thể ra trùng món bạn đã có.'; // spin.odds.group_note
  static const oddsRoundNote =
      'Tỉ lệ từng món đã làm tròn; cộng lại bằng tỉ lệ của cả nhóm.'; // spin.odds.round_note
  static const oddsChangeNotice =
      'Nếu đổi tỉ lệ hay phần quà, Tiệm sẽ báo trước trong Tin tức. Chậu của tuần chỉ đổi khi sang tuần mới.'; // spin.odds.change_notice
  static const oddsClose = 'Đóng'; // spin.odds.btn_close

  // ---- 1c. Kết quả và bảo hiểm ----------------------------------------------

  static const resultTitle = 'Quà của bạn'; // spin.result.title
  static const resultTitleX10 = '10 phần quà của bạn'; // spin.result.title_x10
  static String resultFeatured(String pot) =>
      'Chúc mừng! Bạn nhận được $pot'; // spin.result.featured
  static String resultFeaturedSub(String pot, int charm) =>
      '$pot · +$charm Mị lực khi sở hữu'; // spin.result.featured_sub
  static const resultDupTitle =
      'Chậu trùng đổi thành xu'; // spin.result.dup_title
  static String resultDupXu(String pot, String dupXu) =>
      'Bạn đã có $pot nên nhận $dupXu xu thay cho chậu.'; // spin.result.dup_xu
  static String resultItem(String name) =>
      'Bạn nhận được $name.'; // spin.result.item
  static String resultXu(String xu) =>
      'Bạn nhận được $xu xu.'; // spin.result.xu
  static const resultSavedNote =
      'Quà đã vào kho của bạn.'; // spin.result.saved_note
  static String resultTicketsLeft(int k) =>
      'Còn $k Thẻ gacha'; // spin.result.tickets_left
  static const resultClaim = 'Nhận'; // spin.result.btn_claim
  static const resultClaimAll = 'Nhận hết'; // spin.result.btn_claim_all
  static const resultSkip = 'Bỏ qua'; // spin.result.btn_skip
  static const resultAgain = 'Quay tiếp'; // spin.result.btn_again
  static const resultAgainX10 =
      'Quay tiếp 10 lượt'; // spin.result.btn_again_x10
  static String pityBar(int n, int at) => 'Còn $n/$at lượt'; // spin.pity.bar
  static String pityCounter(int n, String pot) =>
      'Còn $n lượt chắc chắn ra $pot'; // spin.pity.counter
  static String pityCounterLong(int n, String pot) =>
      'Còn $n lượt chắc chắn ra $pot. Bộ đếm về 0 khi đổi chậu lúc 0h thứ Hai.'; // spin.pity.counter_long
  static const pityResetSoon =
      'Bộ đếm sẽ về 0 khi đổi chậu'; // spin.pity.reset_soon
  static String pityResetNotice(String pot) =>
      'Bộ đếm tuần trước đã về 0. Tuần này đếm lại từ đầu với $pot.'; // spin.pity.reset_notice
  static String pityReminder(int count, int at, String pot, String timeLeft) =>
      'Bạn đã quay $count/$at lượt $pot. Bộ đếm về 0 sau $timeLeft.'; // spin.pity.reminder
  static String pityNext(String pot) =>
      'Lượt này chắc chắn ra $pot!'; // spin.pity.next
  static String pityHit(String pot) =>
      'Bảo hiểm đã kích hoạt: $pot về tiệm rồi!'; // spin.pity.hit
  static String pityHitDup(String pot, String dupXu) =>
      'Bảo hiểm đã kích hoạt: bạn đã có $pot nên nhận $dupXu xu.'; // spin.pity.hit_dup
  static String pityResetNote(String pot) =>
      'Bộ đếm bảo hiểm của $pot bắt đầu lại từ 0.'; // spin.pity.reset_note

  // ---- 1d. Lịch sử quay -----------------------------------------------------

  static const historyTitle = 'Lịch sử quay'; // spin.history.title
  static const historyBtn = 'Lịch sử quay'; // spin.history.btn

  /// `spin.history.row` without {nguon_the}: the server does not record
  /// which card a spin used (Nhất: "chỉ ghi Thẻ gacha nếu không theo dõi
  /// được").
  static String historyRow(
    String time,
    String date,
    String ticket,
    String gift,
  ) => '$time $date · $ticket · $gift';
  static const historyEmpty = 'Bạn chưa quay lượt nào.'; // spin.history.empty

  // ---- 1f. Số thẻ, kho thẻ ---------------------------------------------------

  static const ticketNameGeneric = 'Thẻ gacha'; // ticket.name
  static String chip(int k) => '$k thẻ'; // ticket.chip
  static const buyBtn = 'Mua thẻ'; // spin.ticket.buy_btn
  static String chipA11y(int k) =>
      'Bạn có $k Thẻ gacha. Chạm để mua thêm.'; // ticket.chip.a11y
  static String owned(int k) => 'Bạn đang có $k Thẻ gacha'; // ticket.owned
  static const ownedZero = 'Bạn chưa có Thẻ gacha nào'; // ticket.owned.zero
  static const inventoryDesc =
      'Mỗi chậu Sơn Hải có loại thẻ riêng, không hết hạn. Thẻ của chậu khác được giữ, dùng khi chậu đó quay lại Vòng quay tuần.'; // ticket.inventory.desc
  static String inventoryRow(String ticket, int k) =>
      '$ticket · $k thẻ'; // ticket.inventory.row
  static const inventoryRowCurrent =
      'Dùng được tuần này'; // ticket.inventory.row_current
  static String inventoryRowLater(String pot, String date) =>
      'Dùng khi $pot quay lại ($date)'; // ticket.inventory.row_later
  static String notCurrentToast(String pot) =>
      'Thẻ này dùng được khi $pot quay lại. Thẻ không hết hạn.'; // ticket.not_current.toast

  // ---- 1g. Mua thẻ ------------------------------------------------------------

  static String buyTitle(String ticket) => 'Mua $ticket'; // ticket.buy.title
  static String buySubtitle(String pot) =>
      'Mỗi thẻ dùng cho 1 lượt quay $pot. Thẻ không hết hạn.'; // ticket.buy.subtitle
  static String buyWeekOnly(String pot, String weekEnd) =>
      'Tuần này chỉ bán thẻ của $pot, tới $weekEnd.'; // ticket.buy.week_only
  static String buyOwned(int k) => 'Đang có: $k thẻ'; // ticket.buy.owned
  static const buyOpt1 = 'Mua 1 thẻ'; // ticket.buy.opt_1
  static const buyOpt10 = 'Mua 10 thẻ'; // ticket.buy.opt_10
  static String buyOptMissing(int n) =>
      'Mua $n thẻ còn thiếu'; // ticket.buy.opt_missing
  static String buyUnitPrice(String xu, String pl) =>
      'Hôm nay: $xu xu hoặc $pl Pha lê mỗi thẻ'; // ticket.buy.unit_price
  static String buyBtnXu(String cost) => 'Mua · $cost xu'; // ticket.buy.btn_xu
  static String buyBtnPl(String cost) =>
      'Mua · $cost Pha lê'; // ticket.buy.btn_pl
  static const notEnoughXu = 'Bạn chưa đủ xu.'; // ticket.buy.not_enough_xu
  static const notEnoughPl = 'Bạn chưa đủ Pha lê.'; // ticket.buy.not_enough_pl
  static const btnTopup = 'Nạp Pha lê'; // ticket.buy.btn_topup
  static const noRefundNote =
      'Thẻ gacha không hoàn lại và không đổi lại ra xu, Pha lê hay thẻ chậu khác.'; // ticket.buy.no_refund_note
  static const buyCancel = 'Để sau'; // ticket.buy.cancel
  static String plConfirmTitle(String cost, int n) =>
      'Trừ $cost Pha lê để mua $n thẻ?'; // ticket.buy.pl_confirm.title
  static String plConfirmBody(int n, String cost) =>
      'Bạn mua $n Thẻ gacha với $cost Pha lê. Pha lê đã dùng không hoàn lại.'; // ticket.buy.pl_confirm.body
  static const plConfirmMinor =
      'Bạn dưới 16 tuổi cần phụ huynh đồng ý trước khi mua Pha lê và dùng Pha lê mua thẻ.'; // ticket.buy.pl_confirm.minor_note
  static const plConfirmBtn = 'Xác nhận'; // ticket.buy.pl_confirm.btn
  static const plConfirmCancel = 'Hủy'; // ticket.buy.pl_confirm.cancel

  // ---- 1h. Thiếu thẻ ----------------------------------------------------------

  static String shortTitle(int n) => 'Thiếu $n thẻ'; // ticket.short.title
  static String shortBody(int k, String ticket, int need, int n) =>
      'Bạn có $k $ticket, cần $need thẻ để quay $need lượt. Mua thêm $n thẻ nhé?'; // ticket.short.body
  static String shortBtnXu(String cost) =>
      'Mua bằng xu · $cost xu'; // ticket.short.btn_xu
  static String shortBtnPl(String cost) =>
      'Mua bằng Pha lê · $cost Pha lê'; // ticket.short.btn_pl
  static const shortBtnLater = 'Để sau'; // ticket.short.btn_later
  static String shortAfterBuy(int need) =>
      'Mua xong sẽ quay ngay $need lượt.'; // ticket.short.after_buy
  static String buySuccessToast(int n, int k) =>
      'Đã mua $n Thẻ gacha. Bạn có $k thẻ.'; // ticket.buy.success.toast

  // ---- 1j. Thông báo một lần, biểu tượng ----------------------------------

  static const introTitle = 'Mới: Vòng quay tuần'; // gacha.intro.title
  static String introBody(String pot) =>
      'Mỗi tuần một chậu Sơn Hải quý lên Vòng quay. Tuần này là $pot. Bấm biểu tượng Vòng quay bên cạnh để thử vận may nhé!'; // gacha.intro.body
  static const introOk = 'Xem ngay'; // gacha.intro.ok
  static const introClose = 'Đóng'; // gacha.intro.close
  static const iconLabel = 'Vòng quay'; // gacha.icon.label
}
