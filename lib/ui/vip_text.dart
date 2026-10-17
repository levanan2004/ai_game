import '../logic/price_format.dart' show coinFull;

/// VIP texts from Nhất (v6_tin_the_gioi/chu_tinh_nang_moi.md 2–2d, 17/10),
/// verbatim. The key is on each line.
abstract final class VipText {
  static String badge(int k) => 'VIP $k'; // vip.badge
  static String badgeShort(int k) => 'V$k'; // vip.badge.short
  static const none = 'VIP 0'; // vip.none
  static const verifyingChip = 'Đang xác nhận giao dịch…'; // vip.verifying.chip

  /// vip.tone.* by tier (2 tiers per tone).
  static String tone(int level) => switch ((level + 1) ~/ 2) {
    1 => 'Lá xanh', // vip.tone.la_xanh
    2 => 'Hoa đào', // vip.tone.hoa_dao
    3 => 'Bạc', // vip.tone.bac
    4 => 'Vàng', // vip.tone.vang
    _ => 'Ngọc lục bảo', // vip.tone.ngoc
  };

  static String toneLabel(int level) =>
      'Tông ${tone(level)} · bậc ${level.isOdd ? 1 : 2}/2'; // vip.tone.label

  // 2b. Màn VIP
  static const screenTitle = 'Cấp VIP của bạn'; // vip.screen.title
  static String current(int k) =>
      'Bạn đang ở ${k > 0 ? badge(k) : none}'; // vip.screen.current
  static String total(int vnd) => 'Đã nạp: ${money(vnd)}đ'; // vip.screen.total
  static String progress(int vnd, int need) =>
      '${money(vnd)}/${money(need)}đ đã nạp'; // vip.screen.progress
  static const max =
      'Bạn đã ở cấp VIP cao nhất. Cảm ơn bạn đã ủng hộ tiệm!'; // vip.screen.max
  static const rule1 =
      'Cấp VIP tính từ tổng số tiền đã nạp thành công, theo giá của gói. Pha lê nhận làm quà không tính.'; // vip.screen.rule_1
  static const rule2 =
      'Đơn được hoàn tiền thì số tiền đó bị trừ khỏi tổng, cấp VIP có thể giảm. Quà lên cấp đã nhận vẫn giữ nguyên.'; // vip.screen.rule_2
  static const rule3 =
      'VIP không có quà hằng tháng và không giúp tăng hạng trên bảng xếp hạng.'; // vip.screen.rule_3
  static const rule4 =
      'Đồ VIP chỉ để trang trí, không cộng Mị lực.'; // vip.screen.rule_4
  static const perksTitle = 'Quyền lợi VIP'; // vip.perks.title
  static const cosmeticNote =
      'Chỉ để trang trí, không cộng Mị lực'; // vip.perks.cosmetic_note
  static String perkBadge(String tone) =>
      'Huy hiệu VIP tông $tone trên hồ sơ'; // vip.perk.badge
  static String perkFrame(String tone) =>
      'Khung avatar VIP $tone'; // vip.perk.frame
  static String perkNameColor(int k) =>
      'Tên tiệm có màu riêng của ${badge(k)}'; // vip.perk.name_color
  static const perkChatBubble =
      'Bong bóng chat riêng trong Tin thế giới (từ VIP 5)'; // vip.perk.chat_bubble
  static const perkEntryLine =
      'Dòng báo khi bạn vào Tin thế giới (từ VIP 7)'; // vip.perk.entry_line
  static String perkPot(String name) =>
      'Chậu trang trí riêng: $name (không cộng Mị lực)'; // vip.perk.pot
  static String perkPetOutfit(String name) =>
      'Trang phục thú cưng riêng: $name (không cộng Mị lực)'; // vip.perk.pet_outfit
  static const perkTitle = 'Danh hiệu Chủ Tiệm Ngọc'; // vip.perk.title
  static const perkHall =
      'Tên tiệm trong Bảng vinh danh Chủ Tiệm Ngọc'; // vip.perk.hall_of_fame
  static String cardThreshold(int vnd) =>
      'Từ ${money(vnd)}đ đã nạp'; // vip.tier.card.threshold
  static String cardGift(int n) =>
      'Quà lên cấp (một lần): $n Thẻ gacha'; // vip.tier.card.gift
  static const cardNewPerks = 'Mở ở cấp này'; // vip.tier.card.new_perks
  static const sampleName = 'Tiệm Sớm Mai'; // vip.tier.card.sample_name

  // Level-up popup
  static String levelUpTitle(int k) =>
      'Chúc mừng! Bạn đã lên ${badge(k)}'; // vip.levelup.title
  static String levelUpBody(int n) =>
      'Cảm ơn bạn đã ủng hộ tiệm. Quà $n Thẻ gacha đã gửi vào Hộp thư.'; // vip.levelup.body
  static const levelUpNewPerks =
      'Quyền lợi mới vừa mở:'; // vip.levelup.new_perks
  static const levelUpBtn = 'Nhận'; // vip.levelup.btn

  static String lockedItem(int k) =>
      'Món này mở ở ${badge(k)}.'; // vip.locked_item.toast
  static const guestLocked = 'Đăng nhập để tích lũy VIP'; // vip.guest.locked

  // 2c. Đồ VIP
  static const items = {
    'chau_ngoc_bich': 'Chậu Ngọc Bích', // vip.item.chau_ngoc_bich
    'chau_hoang_kim': 'Chậu Hoàng Kim', // vip.item.chau_hoang_kim
    'ao_choang_vip8': 'Áo choàng VIP', // vip.item.ao_choang_vip8
    'vuong_mien_vip10': 'Vương miện Chủ Tiệm Ngọc', // vip.item.vuong_mien_vip10
  };

  /// The pet outfit of VIP 8 / 10 (Nhất 2c; not in economy.json yet).
  static String? outfitAt(int level) => switch (level) {
    8 => items['ao_choang_vip8'],
    10 => items['vuong_mien_vip10'],
    _ => null,
  };

  static const title10 = 'Chủ Tiệm Ngọc'; // vip.item.title_10 / *.title_10
  static const hallTab = 'Vinh danh'; // vip.hall.tab (Phú 17/10)
  static const hallTitle = 'Bảng vinh danh Chủ Tiệm Ngọc'; // vip.hall.title
  static const hallSubtitle =
      'Những tiệm đã lên VIP 10, xếp theo ngày lên cấp. Cảm ơn các bạn đã ủng hộ tiệm!'; // vip.hall.subtitle
  static String hallDate(DateTime d) =>
      'Lên VIP 10 ngày ${date(d)}'; // from vip.hall.row
  static const anonName =
      'Chủ tiệm ẩn danh'; // vip.hall.anon_name, vip.honor.anonymous
  static const hallEmpty =
      'Chưa có Chủ Tiệm Ngọc nào. Tiệm đầu tiên lên VIP 10 sẽ có tên ở đây!'; // vip.hall.empty
  static String hallPage(int p, int total) =>
      'Trang $p/$total'; // vip.hall.page
  static const hallPrev = 'Trang trước'; // vip.hall.btn_prev
  static const hallNext = 'Trang sau'; // vip.hall.btn_next
  static const hallLoadFail =
      'Không tải được Bảng vinh danh. Thử lại nhé!'; // vip.hall.load_fail
  static String hallMyRow(DateTime d) =>
      'Bạn lên Chủ Tiệm Ngọc ngày ${date(d)}'; // vip.hall.my_row
  static const hallHiddenNote =
      'Bạn đang ẩn tên khỏi Bảng vinh danh, người khác thấy bạn là "Chủ tiệm ẩn danh".'; // vip.hall.hidden_note
  static const hallPrivacyNote =
      'Bảng chỉ hiện tên tiệm, cấp VIP và ngày lên VIP 10, không hiện số tiền đã nạp.'; // vip.hall.privacy_note
  static const hallHideTitle =
      'Ẩn tên khỏi Bảng vinh danh'; // settings.hall.hide.title
  static const hallHideSubtitle =
      'Bật lên thì bảng hiện bạn là "Chủ tiệm ẩn danh"'; // settings.hall.hide.subtitle
  static const hallHideOnToast =
      'Đã ẩn tên của bạn khỏi Bảng vinh danh.'; // settings.hall.hide.on.toast
  static const hallHideOffToast =
      'Tên tiệm của bạn đã hiện lại ở Bảng vinh danh.'; // settings.hall.hide.off.toast
  // Ẩn huy hiệu VIP (Nhất 10a, chu_tinh_nang_moi.md 17/10 17:42). The
  // avatar frame stays on (the switch hides badge, name colour, hall name).
  static const hideBadgeTitle = 'Ẩn huy hiệu VIP'; // settings.vip_hide.label
  static const hideBadgeSubtitle =
      'Ẩn huy hiệu, màu tên VIP, khung tin nhắn VIP và tên bạn trên Bảng vinh danh. Cấp VIP và quà vẫn giữ nguyên.'; // settings.vip_hide.desc
  static const hideBadgeOnToast =
      'Đã ẩn huy hiệu VIP. Người khác sẽ thấy bạn như mọi chủ tiệm khác.'; // settings.vip_hide.toast_on
  static const hideBadgeOffToast =
      'Đã hiện lại huy hiệu VIP.'; // settings.vip_hide.toast_off
  static const hideBadgeFail =
      'Chưa lưu được. Bạn thử lại nhé.'; // settings.vip_hide.fail

  // 2d. theo nền tảng
  static String next(int con, int k) =>
      'Nạp thêm ${money(con)}đ để lên ${badge(k)}'; // vip.screen.next
  static const firstTopUp = 'Nạp lần đầu để mở VIP 1'; // vip.screen.none
  static const topUpBtn = 'Nạp Pha lê'; // vip.screen.btn_bottom

  /// 1.500.000 (dots, like the shop's prices).
  static String money(int vnd) => coinFull(vnd);

  static String date(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year}';
  }
}
