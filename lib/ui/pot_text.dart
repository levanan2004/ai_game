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

  /// `summary.pot_bonus.label` (end-of-day line, Nhất v6).
  static const summaryPotBonusLabel = 'Chậu trên kệ';

  /// `summary.pot_bonus.value`; [amount] in xu.
  static String summaryPotBonusValue(String amount) => '+$amount xu';

  /// `summary.pot_bonus.info` (the ⓘ of the line; no ⓘ on this screen yet).
  static const summaryPotBonusInfo =
      'Tiền thêm hôm nay nhờ chỉ số của các chậu đang đặt trên kệ.';

  /// `summary.pot_bonus.empty`: shown instead when the bonus is 0.
  static const summaryPotBonusEmpty =
      'Đặt chậu có chỉ số lên kệ để nhận thêm tiền mỗi ngày.';

  // ---- popup chi tiết chậu (Nhất, v6_tin_the_gioi/chu_chi_tiet_chau.md) ----

  /// `pot.detail.title`
  static const detailTitle = 'Chi tiết chậu';

  /// `pot.group.*`, by economy.json `set`; null for the free bucket.
  static String? group(String? set) => switch (set) {
    'sonHai' => 'Sơn Hải', // pot.group.son_hai
    'linhVat' => 'Linh vật', // pot.group.linh_vat
    'chomSao' => 'Hoàng đạo', // pot.group.hoang_dao
    'vip' => 'VIP', // pot.group.vip
    _ => null,
  };

  /// `pot.detail.stats_title`
  static const statsTitle = 'Chỉ số khi đặt trên kệ';

  /// `pot.detail.charm`
  static String charm(int charm) => 'Mị lực +$charm (tính khi sở hữu)';

  /// `pot.detail.charm_rule`
  static const charmRule =
      'Mỗi loại chậu Sơn Hải chỉ tính Mị lực 1 lần, không cần đặt lên kệ';

  /// `pot.stat.none`
  static const statNone = 'Chậu trang trí';

  /// `pot.detail.status.active`
  static const statusActive = 'Đang có tác dụng';

  /// `pot.detail.status.stat_shelf_only`
  static const statusShelfOnly =
      'Chỉ số riêng chỉ có tác dụng khi đặt trên kệ.';

  /// `pot.detail.status.in_storage`
  static const statusInStorage = 'Đặt lên kệ để kích hoạt';

  /// `pot.detail.status.not_owned`
  static const statusNotOwned = 'Chưa có trong tiệm';

  /// `pot.detail.status.shelf_full_owned`: owned, in the cupboard, shelf full.
  static const statusShelfFullOwned =
      'Kệ đã đầy. Đổi chỗ với một chậu trên kệ để chỉ số có tác dụng.';

  /// `pot.detail.status.stat_dup`: a copy of this type is already on the shelf.
  static const statusStatDup =
      'Đã có chậu cùng loại trên kệ. Mỗi loại chỉ tính chỉ số 1 lần.';

  /// `pot.detail.status.vip_locked`: short line under the lock in Kho chậu.
  static String statusVipLocked(int n) => 'Mở ở VIP $n';

  /// `pot.detail.status.vip_locked_long`: in the detail card.
  static String statusVipLockedLong(int n) =>
      'Chậu này mở khi bạn đạt VIP $n. Chỉ số chỉ có tác dụng khi chậu nằm trên kệ.';

  /// `pot.detail.shelf_count`
  static String shelfCount(int used, int max) => '$used/$max chỗ';

  /// `pot.source.son_hai`
  static const sourceSonHai = 'Nhận từ vòng quay tuần';

  /// `pot.source.son_hai_owned`
  static const sourceSonHaiOwned = 'Chậu bạn đã có vẫn là của bạn.';

  /// `pot.source.vip`
  static String sourceVip(int n) => 'Quà VIP $n';

  /// `pot.detail.btn_place`
  static const btnPlace = 'Đặt lên kệ';

  /// `pot.detail.btn_store`
  static const btnStore = 'Cất vào tủ';

  /// `pot.detail.btn_close`
  static const btnClose = 'Đóng';

  /// `pot.detail.placed.toast`
  static String placedToast(String name) => 'Đã đặt $name lên kệ.';

  /// `pot.detail.stored.toast`
  static String storedToast(String name) => 'Đã cất $name vào tủ.';

  /// `pot.detail.move_fail.toast`
  static const moveFailToast = 'Chưa đổi được chỗ chậu. Thử lại nhé!';

  /// `pot.<id>.desc`: the popup line of each pot (34 pots).
  static const descs = <String, String>{
    'chau_cuu_vi_ho':
        'Cáo chín đuôi trong Sơn Hải Kinh, tinh ý mà lém lỉnh. Chín chiếc đuôi phe phẩy là khách thần bí lại tò mò ghé tiệm.',
    'chau_chuc_long':
        'Rồng thần ngậm đuốc: mở mắt là ngày, nhắm mắt là đêm. Có Chúc Long canh quầy, ngày nào tiệm cũng sáng và đắt hàng.',
    'chau_con_bang':
        'Cá Côn biển Bắc hóa thành chim Bằng, một cánh bay xa vạn dặm. Đơn hoa giao xa cũng nhẹ như gió đưa.',
    'chau_bach_trach':
        'Thú trắng hiểu tiếng muôn loài, biết hết chuyện lạ trên đời. Kẻ trộm chạy đằng nào, Bạch Trạch cũng nghe ngóng ra.',
    'chau_thao_thiet':
        'Một trong Tứ hung, ham ăn nổi tiếng. Về tiệm hoa thì nó chỉ há miệng chờ khách vui tay thêm chút tiền tip.',
    'chau_cung_ky':
        'Một trong Tứ hung: hổ có cánh, tính hơi ngang. Mà chỉ ngang với lũ chuột thôi, với hoa thì Cùng Kỳ hiền khô.',
    'chau_hon_don':
        'Một trong Tứ hung, tròn như cục mây, không mắt không mặt, chẳng biết vội là gì. Đứng cạnh nó, khách cũng thong thả chờ.',
    'chau_dao_ngot':
        'Một trong Tứ hung, bướng bỉnh khó bảo có tiếng. Bướng tới mức không chịu cho hoa trong tiệm héo sớm.',
    'chau_tat_phuong':
        'Chim hạc một chân trong Sơn Hải Kinh, bay tới đâu báo lửa tới đó. Ra chợ, nó nhanh chân giành được hoa giá mềm.',
    'chau_tinh_ve':
        'Cô chim nhỏ ngày ngày ngậm đá lấp biển, chẳng bao giờ bỏ cuộc. Khách mến sự chăm chỉ ấy nên hay để lại chút tip.',
    'chau_de_giang':
        'Thần tròn như túi đỏ, sáu chân bốn cánh, không mặt mà giỏi múa hát. Có Đế Giang nhịp chân, tay gói hoa cũng nhanh theo.',
    'chau_ky_lan':
        'Kỳ lân hiền lành, chỉ hiện ra khi đời yên ả. Tiệm êm đềm thì khách thần bí cũng chịu ghé hơn.',
    'koi':
        'Cá chép vượt Vũ Môn hóa rồng, chăm chỉ mà bền bỉ. Đặt lên kệ, việc buôn bán cũng nhích lên từng chút.',
    'dragon':
        'Rồng bay giữa trời mây, đứng đầu Tứ linh. Khách ngắm rồng uốn quanh chậu, vui lòng thêm chút tip.',
    'crane':
        'Hạc thong dong đứng một chân, dáng của sự an nhàn. Khách ngắm hạc mà quên cả nhìn đồng hồ.',
    'phoenix':
        'Phượng hoàng múa cánh rực rỡ, nhẹ nhàng mà khéo léo. Đôi tay gói hoa cũng nhanh nhẹn theo nhịp cánh.',
    'nghe':
        'Nghê là linh vật canh cửa đình làng Việt, mắt lúc nào cũng mở. Kẻ trộm lấy gì, Nghê giúp tiệm đòi lại.',
    'tortoise':
        'Rùa thần Huyền vũ giữ phương Bắc, sống lâu và chậm rãi. Hoa trong tiệm cũng được nhờ, tươi lâu hơn.',
    'tiger':
        'Hổ trắng giữ phương Tây, oai phong mà hiền với chủ. Lũ chuột nhắt thấy bóng là chạy mất dép.',
    'qilin':
        'Kỳ lân vàng mang điềm lành, bước nhẹ không dẫm cỏ non. Khách thần bí đôi khi lần theo dấu chân nó mà tới.',
    'chau_bach_duong':
        'Chú cừu sừng vàng cuộn xoăn, hăng hái mở đầu vòng Hoàng đạo. Nhìn hiền vậy thôi chứ cứng đầu lắm.',
    'chau_kim_nguu':
        'Chú bò hiền chậm mà chắc, thích những gì êm ái và bền lâu. Đứng trên kệ là vững như kiềng.',
    'chau_song_tu':
        'Hai anh em sinh đôi, một bên trăng một bên sao, nói chuyện không ngớt. Có đôi có cặp mới vui.',
    'chau_cu_giai':
        'Chú cua giơ hai càng, vỏ cứng mà lòng mềm, thương nhà lắm. Áp tai vào như nghe tiếng sóng.',
    'chau_su_tu':
        'Bờm vàng như nắng, ngẩng cao đầu đứng giữa kệ. Đặt vào một cái là quầy sáng hẳn.',
    'chau_xu_nu':
        'Cô gái ôm bó lúa vàng, gọn gàng tỉ mỉ từng chút. Kệ có Xử Nữ là không còn hạt bụi nào.',
    'chau_thien_binh':
        'Đôi đĩa cân vàng luôn giữ thăng bằng, nhẹ nhàng và công tâm. Hoa cắm vào là thấy cân đối.',
    'chau_ho_cap':
        'Bọ cạp đỏ cong đuôi, trông dữ mà sống rất tình. Chỉ chích khi bị chọc thôi.',
    'chau_nhan_ma':
        'Chàng nửa người nửa ngựa giương cung nhắm xa, thích phiêu lưu. Mũi tên lần này nhắm vào một bó thật đẹp.',
    'chau_ma_ket':
        'Dê núi đuôi cá, leo chậm mà chắc từng bậc đá. Kiên nhẫn như người làm vườn lâu năm.',
    'chau_bao_binh':
        'Người mang bình nước rót mát cho đời, nghĩ gì cũng khác người. Nhìn lâu là thấy dịu.',
    'chau_song_ngu':
        'Hai chú cá bơi ngược chiều mà vẫn quấn quýt bên nhau, mơ mộng và dịu dàng. Như đang thì thầm vậy.',
    'chau_ngoc_bich':
        'Chậu men xanh ngọc bích, trong như mặt hồ buổi sớm. Món quà nhỏ tiệm gửi tặng bạn, chỉ để trang trí.',
    'chau_hoang_kim':
        'Chậu vàng óng như nắng ban mai, quà tiệm gửi tặng bạn. Chỉ để trang trí, đặt đâu cũng ấm cả góc.',
  };
}
