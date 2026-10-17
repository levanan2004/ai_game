import 'package:ai_game/audio/sounds.dart';

import 'helpers.dart';

/// Tests record sound requests and never open the audio plugin.
/// The shipped economy.json is loaded first, as the app does at start, so
/// numbers read through PhaLeRules.current / defaultLoginRewards are set.
Future<void> testExecutable(Future<void> Function() testMain) async {
  Sounds.playbackEnabled = false;
  loadTestData();
  await testMain();
}
