import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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

  AudioPlayer? _music;
  AudioPlayer? _amb;
  final List<AudioPlayer> _fx = [];
  var _fxAt = 0;
  var _musicGen = 0;
  var _ambGen = 0;
  final Map<String, bool> _haveFile = {};

  void unlock() => unlocked = true;

  /// One-shot `assets/audio/sfx/<name>.mp3`. Silent when effects are off.
  void effect(String name) {
    if (!effectsOn) return;
    try {
      heard?.add('$name.mp3');
      if (!playbackEnabled || !unlocked) return;
      unawaited(_playFx('audio/sfx/$name.mp3'));
    } catch (_) {}
  }

  /// Loop `assets/audio/<track>.mp3` while the music switch is on.
  void playMusic(String track) {
    final next = unlocked && musicOn && track.isNotEmpty ? track : null;
    if (next == activeTrack) return;
    activeTrack = next;
    if (!playbackEnabled) return;
    unawaited(_startMusic(next));
  }

  /// Loop `amb_shop.mp3` quietly under the music. An effect, so it stops
  /// when the effects switch is off.
  void setAmbience(bool on) {
    final next = on && effectsOn && unlocked;
    if (next == ambienceOn) return;
    ambienceOn = next;
    if (!playbackEnabled) return;
    unawaited(_startAmb(next));
  }

  Future<void> _startMusic(String? track) async {
    final gen = ++_musicGen;
    try {
      if (track == null) {
        await _music?.stop();
        return;
      }
      if (!await _have('assets/audio/$track.mp3')) {
        if (gen != _musicGen) return;
        activeTrack = null;
        await _music?.stop();
        return;
      }
      if (gen != _musicGen) return;
      final player = _music ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('audio/$track.mp3'));
    } catch (_) {}
  }

  Future<void> _startAmb(bool on) async {
    final gen = ++_ambGen;
    try {
      if (!on) {
        await _amb?.stop();
        return;
      }
      if (!await _have('assets/audio/sfx/amb_shop.mp3')) {
        if (gen != _ambGen) return;
        ambienceOn = false;
        await _amb?.stop();
        return;
      }
      if (gen != _ambGen) return;
      final player = _amb ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0.35);
      if (gen != _ambGen) return;
      await player.play(AssetSource('audio/sfx/amb_shop.mp3'));
    } catch (_) {}
  }

  Future<void> _playFx(String asset) async {
    try {
      final player = _takeFx();
      await player.stop();
      await player.play(AssetSource(asset));
    } catch (_) {}
  }

  AudioPlayer _takeFx() {
    if (_fx.length < 3) {
      final player = AudioPlayer();
      _fx.add(player);
      return player;
    }
    final player = _fx[_fxAt];
    _fxAt = (_fxAt + 1) % _fx.length;
    return player;
  }

  Future<bool> _have(String asset) async {
    final cached = _haveFile[asset];
    if (cached != null) return cached;
    try {
      await rootBundle.load(asset);
      _haveFile[asset] = true;
    } catch (_) {
      _haveFile[asset] = false;
    }
    return _haveFile[asset]!;
  }

  void dispose() {
    _music?.dispose();
    _amb?.dispose();
    for (final p in _fx) {
      p.dispose();
    }
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
