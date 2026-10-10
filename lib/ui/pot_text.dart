/// Texts of the "buy more copies" change of 10/10 (SPEC_tiem_chau_hoa.md 15.7).
/// Approved by Nhất: tiem.buy.more, tiem.confirm.more.*, tiem.bought.more,
/// so.cta.buyMore. Placeholders still unapproved: [kinds] (Bản đồ line).
class PotText {
  const PotText._();

  /// `tiem.buy.more`: the card button of a pot the player has. [price] is the
  /// label on the button ("2,5 tr", or "350 Pha lê").
  static String more(String price) => 'Mua thêm $price';

  /// `tiem.confirm.more.title`
  static const confirmMoreTitle = 'Mua thêm chậu này?';

  /// `tiem.confirm.more.body`; [price] is the whole number with its unit
  /// ("30.000.000 xu" or "350 Pha lê"), [n] the copies before the buy.
  static String confirmMoreBody(int n, String price) =>
      'Bạn đang có $n chiếc. Mua thêm một chiếc với giá $price nhé?';

  /// `tiem.confirm.more.go`
  static const confirmMoreGo = 'Mua thêm';

  /// `tiem.confirm.more.later`
  static const confirmMoreLater = 'Để sau';

  /// `tiem.bought.more`; [n] is the count after the buy.
  static String boughtMore(int n) => 'Đã thêm 1 chậu, bạn có $n chiếc.';

  /// `so.cta.buyMore`
  static const bookBuyMore = 'Mua thêm ở Tiệm Chậu Hoa';

  /// "xN" badge text; 100 copies and more read "x99+".
  static String count(int n) => n >= 100 ? 'x99+' : 'x$n';

  /// The card badge: "Đang có x2".
  static String have(int n) => 'Đang có ${count(n)}';

  /// Bản đồ line (placeholder key `map.pots.kinds`): kinds, not copies.
  static String kinds(int n, int total) => 'Đã có $n/$total loại chậu';
}
