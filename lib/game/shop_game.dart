import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../components/shop_scene.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import '../ui/art.dart';

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
    await world.add(ShopScene(session, images));
    // Art loads in the background; the scene draws shapes until it's ready.
    unawaited(_loadArt());
  }

  Future<void> _loadArt() async {
    final paths = [
      Art.forFlame(Art.scene('shop_bg')),
      Art.forFlame(Art.scene('ke_hoa')),
      Art.forFlame(Art.scene('xo_hoa')),
      Art.forFlame(Art.scene('mat_quay')),
      // Blank board; the two chalk lines are drawn on top in ShopScene.
      Art.forFlame(Art.scene('bang_phan')),
      Art.forFlame(Art.nav('dong_ho')),
      Art.forFlame(Art.scene('ghe_cho')),
      Art.forFlame(Art.scene('chau_cay_1')),
      Art.forFlame(Art.scene('chau_cay_2')),
      Art.forFlame(Art.scene('khung_tranh')),
      Art.forFlame(Art.nav('gian')),
      for (final name in const [
        'le_valentine',
        'le_phu_nu',
        'le_nha_giao',
        'le_tet_mai',
        'le_tet_den_long',
        'le_tet_li_xi',
      ])
        Art.forFlame(Art.scene(name)),
      for (final f in session.e.flowers) Art.forFlame(Art.flower(f.id)),
      for (final c in session.data.orders.customers)
        if (c.avatarId.isNotEmpty) ...[
          Art.forFlame(Art.customer(c.avatarId)),
          Art.forFlame(Art.customerFull(c.avatarId)),
        ],
    ];
    for (final p in paths) {
      if (images.containsKey(p)) continue;
      try {
        // Load bytes ourselves so a missing file is a caught error here
        // instead of an unhandled one inside Flame's cache.
        final data = await rootBundle.load('${Art.root}$p');
        final image = await decodeImageFromList(data.buffer.asUint8List());
        images.add(p, image);
      } catch (_) {
        // Missing file: keep the drawn placeholder for that id.
      }
    }
  }

  @override
  void update(double dt) {
    // Clamp long frames (tab switches) so customers don't vanish at once.
    session.tick(dt > 0.25 ? 0.25 : dt);
    super.update(dt);
  }
}
