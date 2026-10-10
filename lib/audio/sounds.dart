import 'package:flutter/widgets.dart';

import 'sound_engine.dart';
import 'sound_engine_stub.dart'
    if (dart.library.html) 'sound_engine_web.dart'
    if (dart.library.io) 'sound_engine_io.dart';

/// Music and one-shot effects for the shop.
///
/// Browsers block autoplay, so nothing is sent to the plugin until [unlock]
/// (the first tap). A missing file or a failed play is ignored. Tests pass
/// [heard] and leave [playbackEnabled] false, so they never touch audio.
class Sounds {
  Sounds({this.heard});

  /// Effect file names that were requested, in order. Null in the live game.
  final List<String>? heard;

  /// The test harness turns this off. The game leaves it on.
  static var playbackEnabled = true;

  var unlocked = false;
  var musicOn = true;
  var effectsOn = true;

  /// Track currently meant to be looping, such as `bgm_main`. Null if silent.
  String? activeTrack;

  /// True while the quiet in-shop loop should be playing.
  var ambienceOn = false;

  SoundEngine? _engine;

  SoundEngine get _playback => _engine ??= createSoundEngine();

  void unlock() {
    unlocked = true;
    if (playbackEnabled) _playback.unlock();
  }

  /// One-shot `assets/audio/sfx/<name>.mp3`. Silent when effects are off.
  void effect(String name) {
    if (!effectsOn) return;
    try {
      heard?.add('$name.mp3');
      if (!playbackEnabled || !unlocked) return;
      _playback.playEffect('audio/sfx/$name.mp3');
    } catch (_) {}
  }

  /// Loop `assets/audio/<track>.mp3` while the music switch is on.
  void playMusic(String track) {
    final next = unlocked && musicOn && track.isNotEmpty ? track : null;
    if (next == activeTrack) return;
    activeTrack = next;
    if (!playbackEnabled) return;
    _playback.setMusic(next == null ? null : 'audio/$next.mp3');
  }

  /// Loop `amb_shop.mp3` quietly under the music. An effect, so it stops
  /// when the effects switch is off.
  void setAmbience(bool on) {
    final next = on && effectsOn && unlocked;
    if (next == ambienceOn) return;
    ambienceOn = next;
    if (!playbackEnabled) return;
    _playback.setAmbience(next, 'audio/sfx/amb_shop.mp3');
  }

  void dispose() {
    _engine?.dispose();
  }
}

/// Lets a button reach [Sounds] without a callback on every call site.
class SoundScope extends InheritedWidget {
  const SoundScope({super.key, required this.sounds, required super.child});

  final Sounds sounds;

  static Sounds? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SoundScope>()?.sounds;

  @override
  bool updateShouldNotify(SoundScope oldWidget) => oldWidget.sounds != sounds;
}
