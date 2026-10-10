import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'sound_engine.dart';

SoundEngine createSoundEngine() => _IoSoundEngine();

/// One prepared player per clip. [resume] replays it; the file is not opened
/// again. Mobile low-latency mode mixes outside the UI thread.
class _IoSoundEngine implements SoundEngine {
  AudioPlayer? _music;
  String? _musicAsset;
  var _musicGen = 0;

  AudioPlayer? _amb;
  var _ambReady = false;
  var _ambGen = 0;

  final Map<String, _Clip> _fx = {};

  @override
  void unlock() {}

  @override
  void playEffect(String asset) {
    unawaited(_playFx(asset));
  }

  Future<void> _playFx(String asset) async {
    final clip = _fx.putIfAbsent(asset, _Clip.new);
    try {
      clip.loading ??= _prepare(clip, asset);
      await clip.loading;
      await clip.player.seek(Duration.zero);
      await clip.player.resume();
    } catch (_) {}
  }

  Future<void> _prepare(_Clip clip, String asset) async {
    await clip.player.setPlayerMode(PlayerMode.lowLatency);
    await clip.player.setReleaseMode(ReleaseMode.stop);
    await clip.player.setSource(AssetSource(asset));
  }

  @override
  void setMusic(String? asset) {
    unawaited(_startMusic(asset));
  }

  Future<void> _startMusic(String? asset) async {
    final gen = ++_musicGen;
    try {
      final player = _music ??= AudioPlayer();
      if (asset == null) {
        _musicAsset = null;
        await player.stop();
        return;
      }
      if (asset == _musicAsset) return;
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setSource(AssetSource(asset));
      if (gen != _musicGen) return;
      _musicAsset = asset;
      await player.resume();
    } catch (_) {}
  }

  @override
  void setAmbience(bool on, String asset) {
    unawaited(_startAmb(on, asset));
  }

  Future<void> _startAmb(bool on, String asset) async {
    final gen = ++_ambGen;
    try {
      final player = _amb ??= AudioPlayer();
      if (!on) {
        await player.stop();
        return;
      }
      if (!_ambReady) {
        await player.setReleaseMode(ReleaseMode.loop);
        await player.setVolume(0.35);
        await player.setSource(AssetSource(asset));
        _ambReady = true;
      }
      if (gen != _ambGen) return;
      await player.seek(Duration.zero);
      await player.resume();
    } catch (_) {}
  }

  @override
  void dispose() {
    _music?.dispose();
    _amb?.dispose();
    for (final clip in _fx.values) {
      clip.player.dispose();
    }
  }
}

class _Clip {
  final player = AudioPlayer();
  Future<void>? loading;
}
