import '../save/game_state.dart';

/// What a bed looks like right now. Computed from the clock, not stored.
enum GardenPhase { locked, empty, sprout, leaf, bloom, wilted }

class GardenView {
  const GardenView({
    required this.phase,
    required this.thirsty,
    this.flowerId,
    this.remaining,
  });

  final GardenPhase phase;
  final bool thirsty;
  final String? flowerId;

  /// Until the next watering, or until a thirsty plant wilts.
  final Duration? remaining;
}

/// [stepMinutes] is the wait between waterings. A thirsty plant that waits
/// that long again wilts. Stage 2 is a bloom and does not wilt.
GardenView viewPlot(GardenPlot plot, int stepMinutes, DateTime now) {
  if (!plot.tilled) {
    return const GardenView(phase: GardenPhase.locked, thirsty: false);
  }
  final id = plot.flowerId;
  if (id == null) {
    return const GardenView(phase: GardenPhase.empty, thirsty: false);
  }
  if (plot.stage >= 2) {
    return GardenView(phase: GardenPhase.bloom, thirsty: false, flowerId: id);
  }
  final step = stepMinutes < 1 ? 1 : stepMinutes;
  final next = DateTime.fromMillisecondsSinceEpoch(plot.nextAtMs);
  final wiltAt = next.add(Duration(minutes: step));
  if (!now.isBefore(wiltAt)) {
    return GardenView(phase: GardenPhase.wilted, thirsty: false, flowerId: id);
  }
  final phase = plot.stage <= 0 ? GardenPhase.sprout : GardenPhase.leaf;
  if (now.isBefore(next)) {
    return GardenView(
      phase: phase,
      thirsty: false,
      flowerId: id,
      remaining: next.difference(now),
    );
  }
  return GardenView(
    phase: phase,
    thirsty: true,
    flowerId: id,
    remaining: wiltAt.difference(now),
  );
}

/// "18 phút", "2 giờ 5 phút", or "chưa đầy 1 phút".
String formatGardenWait(Duration remaining) {
  final minutes = remaining.inMinutes;
  if (minutes < 1) return 'chưa đầy 1 phút';
  if (minutes < 60) return '$minutes phút';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours giờ';
  return '$hours giờ $rest phút';
}

/// Asset id under assets/images/garden/, without the folder.
String gardenArtId(GardenView view) => switch (view.phase) {
  GardenPhase.locked => 'dat_khoa',
  GardenPhase.empty => 'dat_toi',
  GardenPhase.sprout => 'dat_cay',
  GardenPhase.leaf => 'dat_lon',
  GardenPhase.bloom => 'dat_hoa_${view.flowerId}',
  GardenPhase.wilted => 'dat_heo',
};
