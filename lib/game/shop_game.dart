import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../components/tap_target.dart';
import '../save/game_state.dart';
import '../save/progress_store.dart';

/// Minimal shop-game shell.
///
/// The camera uses a fixed portrait canvas of [logicalWidth] by
/// [logicalHeight] (9:16). [FixedResolutionViewport] scales that canvas to fit
/// the window and letterboxes the rest, including when the window resizes.
/// Game coordinates stay the same on a phone and on a desktop browser.
class ShopGame extends FlameGame {
  ShopGame({ProgressStore? store})
    : _storeOverride = store,
      super(
        camera: CameraComponent.withFixedResolution(
          width: logicalWidth,
          height: logicalHeight,
        ),
      );

  static const logicalWidth = 360.0;
  static const logicalHeight = 640.0;

  final ProgressStore? _storeOverride;
  late final ProgressStore _store;

  GameState state = GameState.initial;
  late final TextComponent _status;

  Future<void> _pendingSaves = Future<void>.value();

  /// Completes after queued writes finish. Tests await this after a tap.
  Future<void> get pendingSaves => _pendingSaves;

  String get statusText => _status.text;

  static String labelFor(GameState state) {
    return 'placeholder money: ${state.money}\n'
        'placeholder day: ${state.day}\n'
        'placeholder taps: ${state.tapCount}';
  }

  @override
  Future<void> onLoad() async {
    _store = _storeOverride ?? await ProgressStore.persistent();
    state = await _store.load();

    _status = TextComponent(
      text: labelFor(state),
      anchor: Anchor.center,
      position: Vector2(0, -150),
    );
    await world.add(_status);
    await world.add(TapTarget(onPressed: registerPlaceholderTap));
  }

  /// Increments the placeholder tap counter and saves the whole state.
  void registerPlaceholderTap() {
    state = state.copyWith(tapCount: state.tapCount + 1);
    _status.text = labelFor(state);
    final snapshot = state;
    _pendingSaves = _pendingSaves.then((_) => _store.save(snapshot));
  }
}
