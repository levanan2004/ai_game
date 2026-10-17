import '../data/season_clock.dart';

/// Texts of the shared season clock and the season rewards (Nhất,
/// chu_tinh_nang_moi.md mục 11 "Thưởng mùa", verbatim).
abstract final class SeasonText {
  static const boardCharm = SeasonBoardName.charm; // season.board.charm
  static const boardReview = SeasonBoardName.review; // season.board.review
  static String endsIn(int seasonNo, String ddMM, int d) =>
      'Mùa $seasonNo chốt lúc 23:59 Chủ nhật $ddMM · còn $d ngày'; // season.ends_in
  static String endsInHours(int seasonNo, String ddMM, int h) =>
      'Mùa $seasonNo chốt lúc 23:59 Chủ nhật $ddMM · còn $h giờ'; // season.ends_in_hours
  static String reviewStartsOn(String ddMM) =>
      'Bảng Đánh giá bắt đầu tính từ 0h thứ Hai $ddMM'; // season.review.starts_on
  static const reviewNotCounted =
      'Ngày chơi này quá ngắn nên đánh giá không được tính vào bảng xếp hạng.'; // season.review.not_counted
  static String reviewMinReviews(int minReviews, int n) =>
      'Cần ít nhất $minReviews đánh giá trong mùa để lên bảng. Bạn đang có $n.'; // season.review.min_reviews
  static String reviewTitleLine(String titleName) =>
      'Danh hiệu "$titleName"'; // season.reward.review.title_line
  static const titleTiem5SaoMua =
      'Tiệm 5 sao mùa'; // season.title.tiem_5_sao_mua
}

/// "dd/MM" of the Vietnam day of a UTC instant.
String seasonDdMm(DateTime utc) {
  final d = utc.toUtc().add(const Duration(hours: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}';
}

/// `season.ends_in` (a day or more left) or `season.ends_in_hours`: the
/// Sunday is the last day of [season] (its end is the next Monday 00:00).
String seasonEndsInText(Season season, DateTime now) {
  final left = season.end.difference(now);
  final sunday = seasonDdMm(season.end.subtract(const Duration(minutes: 1)));
  if (left.inDays >= 1) {
    return SeasonText.endsIn(season.number, sunday, left.inDays);
  }
  final h = left.isNegative ? 0 : (left.inMinutes + 59) ~/ 60;
  return SeasonText.endsInHours(season.number, sunday, h < 1 ? 1 : h);
}
