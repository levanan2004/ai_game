import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Loops `assets/audio/bgm_main.mp3` after the player's first tap.
///
/// audioplayers is the small, widely used player for one looping clip.
/// The folder is already an asset directory, so dropping the mp3 in and
/// rebuilding is enough. Until that file exists, [sync] does nothing and
/// the settings switch still saves. A missing or unreadable file is silent.
class Bgm {
  AudioPlayer? _player;
  var unlocked = false;
  bool? _haveFile;

  Future<bool> _exists() async {
    final cached = _haveFile;
    if (cached != null) return cached;
    try {
      await rootBundle.load('assets/audio/bgm_main.mp3');
      _haveFile = true;
    } catch (_) {
      _haveFile = false;
    }
    return _haveFile!;
  }

  void unlock() => unlocked = true;

  Future<void> sync(bool enabled) async {
    try {
      if (!enabled || !unlocked || !await _exists()) {
        await _player?.stop();
        return;
      }
      final player = _player ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      if (player.state == PlayerState.playing) return;
      await player.play(AssetSource('audio/bgm_main.mp3'));
    } catch (_) {
      // A missing plugin or a blocked browser must not stop the game.
    }
  }

  void dispose() {
    _player?.dispose();
  }
}
