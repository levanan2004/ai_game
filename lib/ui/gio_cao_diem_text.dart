/// Texts of Giờ cao điểm / Giá chợ / Dịp lễ (Nhất, chu_nhat.md, and the
/// 25/10 23:11 decisions in spec_phu.md). Copied verbatim; `{slot}`s are
/// the parameters. Strings marked "not from Nhất" still need her OK.
class GioCaoDiemText {
  const GioCaoDiemText._();

  // Giờ cao điểm ------------------------------------------------------

  /// Toast title when a rush starts.
  static const peakLabel = 'Giờ cao điểm';

  /// Toast sub-line when a rush starts (never inside the pill).
  static const peakSub = 'Khách đông hơn, nhớ gói nhanh tay nhé!';

  /// Rush names by `peakWindows.*.labelKey` (decision 23:11).
  static const peakNames = {
    'gioDiLam': 'Giờ đi làm',
    'gioTanTam': 'Giờ tan tầm',
  };

  static String peakName(String? key) => peakNames[key] ?? peakLabel;

  /// Lunch pill (decision 23:11).
  static const lunchPill = 'Trưa vắng khách';

  /// Lunch toast title and sub-line.
  static const lunchLull = 'Giờ trưa vắng khách';
  static const lunchSub = 'Tranh thủ chăm hoa và chuẩn bị giấy gói nha.';

  /// Upcoming pill: "Sắp đến {tenNhan} ({gioBatDau})" (decision 23:11).
  static String upcoming(String tenNhan, String gioBatDau) =>
      'Sắp đến $tenNhan ($gioBatDau)';

  /// Countdown after the upcoming line. Not from Nhất.
  static String countdown(int phut) => '$phut phút';

  /// Pill countdown while a rush runs (Nhất 23:58); [phut] = game minutes
  /// left, rounded up; under one minute "sắp hết" replaces the minutes.
  static String peakCountdown(int phut) =>
      'Giờ cao điểm · ${phut < 1 ? soonOver : 'còn $phut phút'}';

  /// Pill countdown in the lunch lull (Nhất 23:58).
  static String lunchCountdown(int phut) =>
      'Giờ vắng · ${phut < 1 ? soonOver : 'còn $phut phút'}';

  static const soonOver = 'sắp hết';

  /// No-text pill on a narrow ledge (Nhất 23:58): " · {n}′".
  static String compactCountdown(int phut) =>
      ' · ${phut < 1 ? soonOver : '$phut′'}';

  /// After a rush (Nhất; not shown yet: the spec only toasts the start).
  static const peakEnd = 'Hết giờ cao điểm, tiệm thong thả lại rồi.';

  // Bảng giá chợ ------------------------------------------------------

  static const marketTitle = 'Giá chợ hôm nay';
  static const colFlower = 'Loại hoa';
  static const colPrice = 'Giá';
  static const colChange = 'So với hôm qua';
  static String up(int phanTram) => 'Tăng $phanTram%';
  static String down(int phanTram) => 'Giảm $phanTram%';
  static const same = 'Như hôm qua';
  static const hint =
      'Hoa nào đang rẻ thì nhập nhiều, hoa đang đắt thì cân nhắc nhé.';

  /// Day 1: the compare column (decision 23:11).
  static const firstDay = 'Mới mở chợ';

  /// Card button (Phú's spec).
  static const openSheet = 'Xem giá hôm nay';

  /// Holiday price tag (Phú's spec).
  static const holidayTag = 'Lễ';

  /// Card left line on a normal day. Not from Nhất.
  static String day(int n) => 'Ngày $n';

  // Tết poster top line (Nhất 26/10) --------------------------------------

  static const tetTomorrow = 'Ngày mai là Tết rồi!';
  static const tetDay1 = 'Chúc mừng năm mới!';
  static const tetLater = 'Xuân sang, tiệm vẫn mở cửa';

  // Dịp lễ ------------------------------------------------------------

  /// Display names (decision 23:11) by holiday id.
  static const holidayNames = {
    'valentine': 'Valentine 14/2',
    'women_0803': 'Quốc tế Phụ nữ 8/3',
    'women_2010': 'Phụ nữ Việt Nam 20/10',
    'teacher_2011': 'Ngày Nhà giáo 20/11',
    'tet': 'Tết',
  };

  static String holidayName(String id, String fallback) =>
      holidayNames[id] ?? fallback;

  static String banner(String tenDip, String tenHoa) =>
      'Sắp đến $tenDip! Hoa $tenHoa đang được săn lùng.';
  static String holidayPrice(String tenDip) => 'Giá dịp $tenDip';
  static const holidaySub =
      'Hoa lên giá nhưng khách cũng sẵn lòng trả nhiều hơn.';
  static String after(String tenDip) =>
      'Qua dịp $tenDip, giá chợ đã về bình thường.';

  /// {tenHoa}: "a và b"; 3 or more: "a, b và {n} loại khác". Only the start
  /// of a sentence is capitalised, so names are lower case here.
  static String flowerList(List<String> names) {
    final low = [for (final n in names) n.toLowerCase()];
    if (low.isEmpty) return '';
    if (low.length == 1) return low.first;
    if (low.length == 2) return '${low[0]} và ${low[1]}';
    return '${low[0]}, ${low[1]} và ${low.length - 2} loại khác';
  }
}
