/// Thẻ gacha texts from Nhất (v6_tin_the_gioi/chu_tinh_nang_moi.md, 17/10):
/// the xu-card daily limit and gift cards. The wheel screen itself is task 8;
/// these are what the server answers of task 2 map to.
class GachaText {
  const GachaText._();

  /// `ticket.name.<pot id>` ({ticket_name}); null for an unknown pot.
  static String? ticketName(String potId) => _ticketNames[potId];

  static const _ticketNames = {
    'chau_cuu_vi_ho': 'Thẻ gacha Cửu Vỹ Hồ',
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

  /// `weekly_gift.day7.spin_ticket_sub`
  static const day7TicketSub = 'Là thẻ của chậu tuần mà quà được gửi tới';

  /// `ticket.buy.gift_note`
  static const giftNote =
      'Thẻ quà (VIP, quà tuần) là thẻ của chậu tuần mà thư quà vào Hộp thư, '
      'không tính theo lúc bạn bấm Nhận.';

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
}
