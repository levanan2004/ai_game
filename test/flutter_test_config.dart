import 'package:ai_game/audio/sounds.dart';

/// Tests record sound requests and never open the audio plugin.
Future<void> testExecutable(Future<void> Function() testMain) async {
  Sounds.playbackEnabled = false;
  await testMain();
}
