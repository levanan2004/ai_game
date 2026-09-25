/// Shop rating = average stars of the last `ratingWindow` reviews
/// (economy.json `customers._ratingNote`).
class RatingSummary {
  const RatingSummary({
    required this.average,
    required this.count,
    required this.distribution,
  });

  final double average;

  /// Reviews inside the window (at most ratingWindow).
  final int count;

  /// Stars (1..5) to number of reviews inside the window.
  final Map<int, int> distribution;
}

/// [starsOldestFirst] holds the stars of saved reviews, oldest first.
/// With no reviews yet the rating is [fallback] (economy `start.rating`).
RatingSummary summarizeRatings(
  List<int> starsOldestFirst, {
  required int window,
  required double fallback,
}) {
  final start = starsOldestFirst.length > window
      ? starsOldestFirst.length - window
      : 0;
  final recent = starsOldestFirst.sublist(start);
  final dist = {for (var s = 1; s <= 5; s++) s: 0};
  for (final s in recent) {
    dist[s] = (dist[s] ?? 0) + 1;
  }
  final avg = recent.isEmpty
      ? fallback
      : recent.fold<int>(0, (a, b) => a + b) / recent.length;
  return RatingSummary(average: avg, count: recent.length, distribution: dist);
}
