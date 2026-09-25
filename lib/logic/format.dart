/// Money like the mockups: 1250000 -> "1.250k", 18400 -> "18,4k".
String formatK(int vnd) {
  final neg = vnd < 0;
  final abs = vnd.abs();
  final whole = abs ~/ 1000;
  final rest = abs % 1000;
  final groups = <String>[];
  var w = whole;
  do {
    final part = w % 1000;
    w ~/= 1000;
    groups.insert(0, w > 0 ? part.toString().padLeft(3, '0') : '$part');
  } while (w > 0);
  var s = groups.join('.');
  if (rest != 0) {
    final dec = (rest / 100).round();
    if (dec == 10) {
      return formatK((neg ? -1 : 1) * (whole + 1) * 1000);
    }
    if (dec > 0) s = '$s,$dec';
  }
  return '${neg ? '-' : ''}${s}k';
}

/// Signed money for summary / popup lines: "+24k", "–125k".
String formatSignedK(int vnd) =>
    vnd < 0 ? '–${formatK(-vnd)}' : '+${formatK(vnd)}';

/// One decimal with a Vietnamese comma: 4.6 -> "4,6".
String formatRating(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// In-game clock "10:40".
String formatClock(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// Multiplier written the Vietnamese way (spec: "1,8 chứ không phải 1.8"):
/// 1.8 -> "1,8", 2.0 -> "2".
String formatMultiplier(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble()
      ? r.toInt().toString()
      : r.toStringAsFixed(1).replaceAll('.', ',');
}
