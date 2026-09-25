import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../components/shop_scene.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';

/// Flame game: drives the [ShopSession] clock and renders the shop scene.
///
/// The camera uses a fixed portrait canvas of [logicalWidth] by
/// [logicalHeight]; Flutter screens are laid out in the same 360×640 frame
/// (see `GameFrame`), so game and widget coordinates match.
class ShopGame extends FlameGame {
  ShopGame(this.session)
    : super(
        camera: CameraComponent.withFixedResolution(
          width: logicalWidth,
          height: logicalHeight,
        ),
      );

  static const logicalWidth = 360.0;
  static const logicalHeight = 640.0;

  final ShopSession session;

  @override
  Color backgroundColor() => AppColors.bgBase;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    await world.add(ShopScene(session));
  }

  @override
  void update(double dt) {
    // Clamp long frames (tab switches) so customers don't vanish at once.
    session.tick(dt > 0.25 ? 0.25 : dt);
    super.update(dt);
  }
}
