import '../data/pet_items.dart';
import '../logic/price_format.dart';

/// Texts of the pet room, the item picker, the item shop and the received-item
/// popups (SPEC_phong_pet_vat_pham §8, keys `petdo.*`, Nhất's wording). One
/// place, so a wording change is one edit. A widget never types these.
abstract final class PetDo {
  // ---- room (P1)
  static const roomTitle = 'Phòng pet'; // petdo.room.title
  static const roomShop = 'Tiệm đồ'; // petdo.room.shop
  static const slotEmpty = 'Trống'; // petdo.slot.empty
  static const tapHint = 'Chạm vào pet để vuốt.'; // petdo.room.tap_hint
  static const emptyHint =
      'Chưa đeo đồ nào. Ghé Tiệm đồ nhé.'; // petdo.room.empty_hint

  /// petdo.slot.neck / .head / .acc
  static String slotName(String slot) => switch (slot) {
    'neck' => 'Cổ',
    'head' => 'Đầu',
    'accessory' => 'Phụ kiện',
    _ => slot,
  };

  // ---- charm card
  static const charmTitle = 'Mị lực'; // petdo.charm.title
  static String charmItems(int n) => 'Đồ cộng thêm +$n'; // petdo.charm.items
  static String charmMax(int n) => 'Tối đa $n'; // petdo.charm.max
  static String charmMin(int n) =>
      'Cần đạt $n Mị lực để lên bảng'; // petdo.charm.min
  static const charmBase = 'Gốc'; // petdo.charm.base
  static const charmMult = 'Hệ số'; // petdo.charm.mult
  static const charmItemsCol = 'Đồ'; // petdo.charm.items_col
  static const charmTotal = 'Tổng'; // petdo.charm.total

  // ---- pet card and buttons
  static const hold = 'Bế'; // petdo.pet.hold
  static String feed(int n) => 'Cho ăn (-$n)'; // petdo.pet.feed
  static const pick = 'Chọn vào ô'; // petdo.pet.pick
  static String hungry(String pet) => '$pet đang đói'; // petdo.pet.hungry
  static String full(String pet) => '$pet no rồi.'; // petdo.pet.full
  static String progress(int n) => 'Tiến trình $n%'; // petdo.pet.progress
  static String biscuit(int n) => 'Bánh mật: $n'; // petdo.pet.biscuit
  static String adult(String pet) => '$pet đã trưởng thành.'; // petdo.pet.adult

  // ---- picker (P2)
  static String pickTitle(String slot) =>
      'Chọn đồ cho ô ${slotName(slot)}'; // petdo.pick.title
  static String pickSub(String pet, String stage, int charm) =>
      '$pet · $stage · Mị lực $charm'; // petdo.pick.sub
  static const worn = 'Đang đeo'; // petdo.pick.worn
  static String at(String pet) => 'Đang ở $pet'; // petdo.pick.at
  static const wear = 'Đeo'; // petdo.pick.wear
  static const unwear = 'Gỡ đồ'; // petdo.pick.unwear
  static String count(int n, int w, int s) =>
      'Có $n · đang đeo $w · trong kho $s'; // petdo.pick.count
  static const compare = 'Mị lực pet:'; // petdo.pick.compare
  static const compareOff = 'Nếu gỡ, Mị lực pet:'; // petdo.pick.compare_off
  static String emptyTitle(String slot) =>
      'Chưa có đồ nào cho ô ${slotName(slot)}.'; // petdo.pick.empty.title
  static const emptySub =
      'Mua ở Tiệm đồ hoặc nhận từ thưởng hạng.'; // petdo.pick.empty.sub
  static const emptyCta = 'Đến Tiệm đồ'; // petdo.pick.empty.cta

  // ---- sell
  static const sellBtn = 'Bán'; // petdo.sell.btn
  static String sellTitle(String item) => 'Bán $item?'; // petdo.sell.title
  static const sellReceive = 'Bạn nhận'; // petdo.sell.receive
  static String sellNote(int left) =>
      'Bằng 30% giá mua. Còn lại x$left trong kho.'; // petdo.sell.note
  static const sellNoteLast =
      'Bằng 30% giá mua. Món sẽ hết khỏi kho.'; // petdo.sell.note_last
  static String sellConfirm(String amount) =>
      'Bán +$amount'; // petdo.sell.confirm
  static const sellCancel = 'Để sau'; // petdo.sell.cancel
  static const sellUnwearHint = 'Tháo ra để bán'; // petdo.sell.unwear_hint
  static const sellSpare = 'Bán bản thừa'; // petdo.sell.spare
  static String sellDone(String item, String amount) =>
      'Đã bán $item. +$amount'; // petdo.sell.done

  // ---- shop (P3)
  static const shopTitle = 'Tiệm đồ pet'; // petdo.shop.title
  static const shopHint = 'Mua được nhiều bản. Bán lại 30% giá.'; // .shop.hint
  static const shortXu = 'Chưa đủ xu'; // petdo.shop.short.xu
  static const shortPl = 'Chưa đủ Pha lê'; // petdo.shop.short.pl
  static String shortTip(int n, {required bool phaLe}) =>
      'Còn thiếu ${priceUnit(n, phaLe: phaLe)}'; // petdo.shop.tip
  static const otherTitle = 'Cách khác để có đồ'; // petdo.shop.other.title
  static const otherSub =
      'Thưởng hạng Xếp hạng Mị lực · Khách thần bí tặng'; // .other.sub
  static const shopClosed = 'Mua khi tiệm đóng cửa nhé';
  static const sellClosed = 'Bán khi tiệm đóng cửa nhé';

  // ---- buy confirm
  static String buyTitle(String item) => 'Mua $item?'; // petdo.buy.title
  static String buyHave(int n) =>
      'Bạn đang có x$n. Mua thêm một bản.'; // petdo.buy.have
  static const buyNone = 'Bạn chưa có món này.'; // petdo.buy.none
  static String buySlotLine(int charm, String slot) =>
      '+$charm Mị lực · Ô ${slotName(slot)}'; // petdo.buy.slotline
  static String buyConfirm(String price) => 'Mua $price'; // petdo.buy.confirm
  static const buyCancel = 'Để sau'; // petdo.buy.cancel

  // ---- received items (P4)
  static const getRank = 'Quà xếp hạng'; // petdo.get.rank
  static String getRankSub(int n) => 'Hạng $n · mùa vừa rồi'; // .get.rank_sub
  static const getRankSubNoRank = 'Mùa vừa rồi';
  static const getMystery = 'Khách thần bí tặng quà!'; // petdo.get.mystery
  static const getMysterySub =
      'Một món đồ pet đã vào kho.'; // petdo.get.mystery_sub
  static const getNew = 'Món mới'; // petdo.get.new
  static const getGo = 'Vào phòng pet'; // petdo.get.go
  static const getLater = 'Để sau'; // petdo.get.later
  static const getHint = 'Vào phòng pet để đeo cho pet nhé.'; // petdo.get.hint
  static String getDup(int n) =>
      'Bạn có x$n. Bán bản thừa được:'; // petdo.get.dup
  static const getKeep = 'Giữ'; // petdo.get.keep

  // ---- tiers
  static String tierName(PetItemTier tier) => switch (tier) {
    PetItemTier.thuong => 'Thường',
    PetItemTier.hiem => 'Hiếm',
    PetItemTier.suThi => 'Sử thi',
    PetItemTier.huyenThoai => 'Huyền thoại',
  };

  /// The badge of copies: `x2`, and `x99+` from 100 (the spec's open point).
  static String copies(int n) => n >= 100 ? 'x99+' : 'x$n';
}
