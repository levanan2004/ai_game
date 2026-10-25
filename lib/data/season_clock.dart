/// The one season clock of both boards (Mị lực and Đánh giá; Hà Phương's
/// `ratingBoard.season.sharedClockWithCharm`, `autoChain`): seasons of
/// `cycleDays` days back to back, each from Monday 00:00 to Sunday 23:59
/// Vietnam time. Season numbers count on the Mị lực clock (season 1 =
/// 12/10/2026); the rating board joins at season 2 (09/11/2026).
///
/// Each board's economy.json block keeps its FIRST season: `periodKey` (the
/// key of that season, e.g. "season-1" or "rating-2") and `seasonStart`.
/// Later seasons follow on their own: the key's number goes up by one every
/// `cycleDays` (functions/season.js does the same on the server).
library;

/// One season of a board.
class Season {
  const Season({
    required this.number,
    required this.period,
    required this.start,
    required this.end,
  });

  /// 1, 2, ... ("mùa {so_mua}").
  final int number;

  /// The Firestore key of that season's board (`season-3`, `rating-3`).
  final String period;

  /// First instant (Monday 00:00 Vietnam) as UTC.
  final DateTime start;

  /// The instant it is over (the next Monday 00:00 Vietnam) as UTC.
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      other is Season && other.period == period && other.start == start;

  @override
  int get hashCode => Object.hash(period, start);
}

/// "season-1" -> ("season-", 1); null without a trailing number.
(String, int)? splitPeriodKey(String key) {
  final m = RegExp(r'^(.*?)(\d+)$').firstMatch(key);
  if (m == null) return null;
  return (m.group(1)!, int.parse(m.group(2)!));
}

/// The clock of one board, from its first season.
class SeasonClock {
  const SeasonClock({
    required this.firstPeriod,
    required this.firstStart,
    this.cycleDays = 28,
  });

  final String firstPeriod;
  final DateTime firstStart;
  final int cycleDays;

  Duration get cycle => Duration(days: cycleDays);

  /// Season [number] (never before the first one).
  Season season(int number) {
    final parts = splitPeriodKey(firstPeriod);
    final first = parts?.$2 ?? 1;
    final n = number < first ? first : number;
    final start = firstStart.add(cycle * (n - first));
    return Season(
      number: n,
      // A key without a number cannot chain: it stays the one season.
      period: parts == null ? firstPeriod : '${parts.$1}$n',
      start: start,
      end: start.add(cycle),
    );
  }

  /// The season running at [now]; before the first season starts, the
  /// first season (not started yet: [now] is before its start).
  Season at(DateTime now) {
    final first = splitPeriodKey(firstPeriod)?.$2 ?? 1;
    if (splitPeriodKey(firstPeriod) == null || now.isBefore(firstStart)) {
      return season(first);
    }
    final passed =
        now.difference(firstStart).inMicroseconds ~/ cycle.inMicroseconds;
    return season(first + passed);
  }

  /// The season before the one at [now], or null in the first season.
  Season? previous(DateTime now) {
    final s = at(now);
    final first = splitPeriodKey(firstPeriod)?.$2 ?? 1;
    return s.number > first ? season(s.number - 1) : null;
  }

  /// The season that closed less than [lock] ago ("Đang chốt bảng": the
  /// board still shows it, frozen, while the payout runs), else null.
  Season? closing(DateTime now, Duration lock) {
    if (lock <= Duration.zero) return null;
    final prev = previous(now);
    if (prev == null || !now.isBefore(prev.end.add(lock))) return null;
    return prev;
  }
}

/// economy.json `ratingBoard.season.lockMinutesAfterClose`: minutes after a
/// season closes during which BOTH boards stay frozen on it (Hà Phương
/// 17/10: 60). Missing or not a whole number >= 0: 0 (no freeze).
int seasonLockMinutes(Object? ratingBoardJson) {
  final season = ratingBoardJson is Map ? ratingBoardJson['season'] : null;
  final v = season is Map ? season['lockMinutesAfterClose'] : null;
  return v is num && v >= 0 ? v.toInt() : 0;
}

/// The end of the season keyed [period] on [clock] (same prefix, a number
/// from the first season on), else null.
DateTime? seasonEndOf(SeasonClock? clock, String period) {
  if (clock == null) return null;
  final first = splitPeriodKey(clock.firstPeriod);
  final got = splitPeriodKey(period);
  if (first == null || got == null || got.$1 != first.$1) return null;
  if (got.$2 < first.$2) return null;
  return clock.season(got.$2).end;
}

/// {board_name} of the season reward letters (Nhất mục 11, verbatim; also
/// functions/payout.js BOARD_NAMES).
abstract final class SeasonBoardName {
  static const charm = 'Mị lực'; // season.board.charm
  static const review = 'Đánh giá'; // season.board.review
}
