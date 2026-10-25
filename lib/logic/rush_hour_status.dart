// Giờ cao điểm pill state (Phú's spec, Hà Phương's peakWindows): what the
// shop shows at the current in-game minute. Numbers come from economy.json.

import '../save/game_state.dart';
import 'shop_session.dart';

enum RushKind { peak, upcoming, lunch }

class RushStatus {
  const RushStatus({
    required this.kind,
    this.labelKey,
    this.startHour = 0,
    this.multiplier = 1,
    this.minutesLeft = 0,
  });

  final RushKind kind;

  /// `peakWindows.*.labelKey` (gioDiLam, gioTanTam); null at lunch.
  final String? labelKey;

  /// Start hour of the rush window (peak and upcoming).
  final int startHour;

  /// Raw `arrivalWeightsByHour` of the current hour, one decimal (peak).
  final double multiplier;

  /// Upcoming: game minutes until the rush starts. Peak and lunch: game
  /// minutes until the window ends, rounded up; 0 = under one minute.
  final int minutesLeft;

  @override
  bool operator ==(Object other) =>
      other is RushStatus &&
      other.kind == kind &&
      other.labelKey == labelKey &&
      other.startHour == startHour &&
      other.multiplier == multiplier &&
      other.minutesLeft == minutesLeft;

  @override
  int get hashCode =>
      Object.hash(kind, labelKey, startHour, multiplier, minutesLeft);
}

/// The pill for [s] right now; null outside opening hours and in normal
/// hours (the pill hides).
RushStatus? rushStatusOf(ShopSession s) {
  final e = s.e;
  if (s.state.phase != DayPhase.open || s.afterClose) return null;
  final w = e.peakWindows;
  final exact = s.state.elapsed / e.secondsPerHour * 60;
  final minutes = exact.floor();
  final now = e.openHour * 60 + minutes;
  // Game minutes left until [endHour], rounded up; 0 under one minute.
  int until(int endHour) {
    final left = endHour * 60 - (e.openHour * 60 + exact);
    return left < 1 ? 0 : left.ceil();
  }

  final hour = now ~/ 60;
  final peak = w.peakAt(hour);
  if (peak != null) {
    final weight = e.arrivalWeightsByHour[hour] ?? 1;
    return RushStatus(
      kind: RushKind.peak,
      labelKey: peak.labelKey,
      startHour: peak.start,
      multiplier: (weight * 10).round() / 10,
      minutesLeft: until(peak.end),
    );
  }
  if (w.isLunchQuiet(hour)) {
    return RushStatus(
      kind: RushKind.lunch,
      minutesLeft: until(w.lunchQuiet!.end),
    );
  }
  for (final p in w.peaks) {
    final left = p.start * 60 - now;
    if (left > 0 && left <= w.warnBeforeMinutes) {
      return RushStatus(
        kind: RushKind.upcoming,
        labelKey: p.labelKey,
        startHour: p.start,
        minutesLeft: left,
      );
    }
  }
  return null;
}
