import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart';

import 'sound_engine.dart';

SoundEngine createSoundEngine() => _WebSoundEngine();

/// Decode each file once. Later plays are buffer sources on the audio thread,
/// so the game loop is not asked to open an mp3 again.
class _WebSoundEngine implements SoundEngine {
  AudioContext? _ctx;
  final Map<String, Future<AudioBuffer?>> _buffers = {};
  AudioBufferSourceNode? _music;
  AudioBufferSourceNode? _amb;
  var _musicGen = 0;
  var _ambGen = 0;

  @override
  void unlock() {
    final ctx = _ctx ??= AudioContext();
    ctx.resume();
  }

  @override
  void playEffect(String asset) {
    final ctx = _ctx;
    if (ctx == null) return;
    unawaited(_playOne(ctx, asset));
  }

  Future<void> _playOne(AudioContext ctx, String asset) async {
    final buffer = await _decode(ctx, asset);
    if (buffer == null || _ctx == null) return;
    final source = ctx.createBufferSource();
    source.buffer = buffer;
    source.connect(ctx.destination);
    source.start();
  }

  @override
  void setMusic(String? asset) {
    final gen = ++_musicGen;
    _halt(_music);
    _music = null;
    final ctx = _ctx;
    if (asset == null || ctx == null) return;
    unawaited(
      _playLoop(
        ctx,
        asset,
        gen,
        () => gen == _musicGen,
        (source) => _music = source,
      ),
    );
  }

  @override
  void setAmbience(bool on, String asset) {
    final gen = ++_ambGen;
    _halt(_amb);
    _amb = null;
    final ctx = _ctx;
    if (!on || ctx == null) return;
    unawaited(
      _playLoop(
        ctx,
        asset,
        gen,
        () => gen == _ambGen,
        (source) => _amb = source,
        volume: 0.35,
      ),
    );
  }

  Future<void> _playLoop(
    AudioContext ctx,
    String asset,
    int gen,
    bool Function() current,
    void Function(AudioBufferSourceNode source) keep, {
    double volume = 1,
  }) async {
    final buffer = await _decode(ctx, asset);
    if (buffer == null || !current() || _ctx == null) return;
    final source = ctx.createBufferSource();
    source.buffer = buffer;
    source.loop = true;
    if (volume == 1) {
      source.connect(ctx.destination);
    } else {
      final gain = ctx.createGain();
      gain.gain.value = volume;
      source.connect(gain);
      gain.connect(ctx.destination);
    }
    if (!current()) return;
    source.start();
    if (!current()) {
      _halt(source);
      return;
    }
    keep(source);
  }

  Future<AudioBuffer?> _decode(AudioContext ctx, String asset) {
    return _buffers.putIfAbsent(asset, () async {
      try {
        final data = await rootBundle.load('assets/$asset');
        final bytes = Uint8List.fromList(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        return await ctx.decodeAudioData(bytes.buffer.toJS).toDart;
      } catch (_) {
        return null;
      }
    });
  }

  void _halt(AudioBufferSourceNode? source) {
    if (source == null) return;
    try {
      source.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _halt(_music);
    _halt(_amb);
    _music = null;
    _amb = null;
    final ctx = _ctx;
    _ctx = null;
    if (ctx != null) unawaited(ctx.close().toDart);
  }
}
