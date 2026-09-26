import '../save/game_state.dart';

/// What to do the first time this device and the cloud both have a save.
///
/// The further morning wins: the greater [GameState.day]. If the days are
/// equal, this device keeps its save and that save is uploaded, so the
/// player stays on the progress they have open. An empty cloud receives
/// the local save. A device with no save yet takes the cloud save.
class CloudMerge {
  const CloudMerge({required this.useCloud, required this.pushLocal});

  /// Replace the local morning with [cloud].
  final bool useCloud;

  /// Upload the local morning. Never combined with [useCloud].
  final bool pushLocal;

  static CloudMerge decide({
    required GameState? local,
    required bool hasLocalSave,
    required GameState? cloud,
  }) {
    if (cloud == null) {
      return CloudMerge(
        useCloud: false,
        pushLocal: hasLocalSave && local != null,
      );
    }
    if (!hasLocalSave || local == null) {
      return const CloudMerge(useCloud: true, pushLocal: false);
    }
    if (cloud.day > local.day) {
      return const CloudMerge(useCloud: true, pushLocal: false);
    }
    return const CloudMerge(useCloud: false, pushLocal: true);
  }
}
