/// Giờ cao điểm + giá chợ dao động (Hà Phương's
/// gio_cao_diem_gia_cho_block.json, merged into economy.json). Every number
/// comes from the data file.
library;

/// One `peakWindows` entry: in-game hours [start, end).
class PeakWindow {
  const PeakWindow({required this.start, required this.end, this.labelKey});

  final int start;
  final int end;

  /// Key into the rush-hour strings (`gioDiLam`, `gioTanTam`); null for the
  /// quiet lunch window.
  final String? labelKey;

  bool contains(int hour) => hour >= start && hour < end;

  static PeakWindow? fromJson(Object? j) {
    if (j is! Map) return null;
    return PeakWindow(
      start: (j['start'] as num).toInt(),
      end: (j['end'] as num).toInt(),
      labelKey: j['labelKey'] as String?,
    );
  }
}

/// `peakWindows`: morning and evening rush, quiet lunch, and how many game
/// minutes ahead the pill warns.
class PeakWindows {
  const PeakWindows({
    this.peaks = const [],
    this.lunchQuiet,
    this.warnBeforeMinutes = 0,
  });

  static const none = PeakWindows();

  /// Rush windows, earliest first.
  final List<PeakWindow> peaks;
  final PeakWindow? lunchQuiet;
  final int warnBeforeMinutes;

  /// Missing block (older data) = no rush hours.
  factory PeakWindows.fromJson(Object? j) {
    if (j is! Map) return none;
    final peaks = <PeakWindow>[];
    PeakWindow? lunch;
    for (final e in j.entries) {
      final key = e.key as String;
      if (key.startsWith('_') || e.value is! Map) continue;
      final w = PeakWindow.fromJson(e.value);
      if (w == null) continue;
      if (w.labelKey == null) {
        lunch = w;
      } else {
        peaks.add(w);
      }
    }
    peaks.sort((a, b) => a.start.compareTo(b.start));
    return PeakWindows(
      peaks: peaks,
      lunchQuiet: lunch,
      warnBeforeMinutes: (j['warnBeforeMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Rush window holding [hour], if any.
  PeakWindow? peakAt(int hour) {
    for (final w in peaks) {
      if (w.contains(hour)) return w;
    }
    return null;
  }

  bool isLunchQuiet(int hour) => lunchQuiet?.contains(hour) ?? false;
}

/// `market.dailyFluctuation` + `marketFluctuationAppliesTo`.
class DailyFluctuation {
  const DailyFluctuation({
    this.enabled = false,
    this.range = 0,
    this.step = 0,
    this.flowers = false,
  });

  static const off = DailyFluctuation();

  final bool enabled;

  /// Factor = 1 + range * u, u in [-1, 1].
  final double range;

  /// Factor is rounded to this step (0.05 -> 0.90, 0.95, … 1.10).
  final double step;

  /// `marketFluctuationAppliesTo.flowers`. Paper, ribbon and delivery fee
  /// never move.
  final bool flowers;

  bool get active => enabled && flowers && range > 0;

  factory DailyFluctuation.fromJson(Object? j, Object? appliesTo) {
    if (j is! Map) return off;
    return DailyFluctuation(
      enabled: j['enabled'] == true,
      range: (j['range'] as num?)?.toDouble() ?? 0,
      step: (j['step'] as num?)?.toDouble() ?? 0,
      flowers: appliesTo is Map ? appliesTo['flowers'] == true : true,
    );
  }
}
