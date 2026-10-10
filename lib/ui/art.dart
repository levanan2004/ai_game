import 'package:flutter/widgets.dart';

/// Paths of Phú's art v0.1 (assets/images, WebP, transparent).
/// File names equal the ids in economy.json; customer avatars use the
/// avatarId from customers/index.json.
class Art {
  const Art._();

  static const root = 'assets/images/';

  /// Game art is WebP. The bank QR in [donate] stays PNG so it always scans.
  static const ext = '.webp';

  static String flower(String id) => '${root}flowers/$id$ext';

  /// Wilted picture of a dot-2 flower (`flowers/<id>_heo`).
  static String flowerWilted(String id) => '${root}flowers/${id}_heo$ext';
  static String pot(String id) => '${root}pots/$id$ext';
  static String ui(String id) => '${root}ui/$id$ext';
  static String paper(String id) => '${root}papers/$id$ext';
  static String ribbon(String id) => '${root}ribbons/$id$ext';
  static String upgrade(String id) => '${root}upgrades/$id$ext';
  static String customer(String avatarId) => '${root}customers/$avatarId$ext';

  /// Full-body queue sprite (256×480). Round avatars stay in [customer].
  static String customerFull(String avatarId) =>
      '${root}customers_full/$avatarId$ext';
  static String nav(String id) => '${root}nav/$id$ext';
  static String garden(String id) => '${root}garden/$id$ext';
  static String pet(String id) => '${root}pets/$id$ext';
  static String scene(String id) => '${root}scenes/$id$ext';
  static String event(String id) => '${root}events/$id$ext';
  static String shipper(String id) => '${root}shippers/$id$ext';

  /// Phúc lợi frames, check-in tiles, badge and envelopes (dot1_khung_qua).
  static String phucLoi(String id) => '${root}phuc_loi/$id$ext';

  /// "Bạn biết?" cards, 1080×480, left half empty for text.
  static String banBiet(String id) => '${root}ban_biet/$id$ext';

  /// Phú's UI sheet dot1_ui: popup frame, tray, buttons, tabs, ribbon.
  /// Xếp hạng Mị lực art (dot1_1010/cat_xep_hang): frames, medals, shields.
  static String bxh(String id) => '${root}bxh/$id$ext';

  static String uiSkin(String id) => '${root}ui_dot1/$id$ext';

  /// Corner menu (nut_menu): button, tray and red dot, with 2.0x/3.0x
  /// variant folders so Flutter picks a whole-number scale.
  static String menu(String id) => '${root}ui_menu/$id$ext';

  /// Riding pose while a delivery is out; `id_cho` while that shipper waits.
  static String shipperPose(String id, {required bool riding}) =>
      shipper(riding ? id : '${id}_cho');
  static String donate(String id) => '${root}donate/$id.png';

  /// Same path relative to [root], as Flame's image cache expects.
  static String forFlame(String path) =>
      path.startsWith(root) ? path.substring(root.length) : path;
}

/// An image from [Art] at a fixed square size. Shows [fallback] (the old drawn
/// placeholder) if the file is missing, so a new id never crashes a screen.
class ArtImage extends StatelessWidget {
  const ArtImage(
    this.path, {
    super.key,
    required this.size,
    this.opacity = 1,
    this.fallback,
  });

  final String path;
  final double size;
  final double opacity;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        opacity: opacity >= 1 ? null : AlwaysStoppedAnimation(opacity),
        errorBuilder: (context, error, stack) =>
            fallback ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Wrapping-paper picture. `mesh` is white thread on a transparent ground,
/// so a soft shadow sits behind it; the other papers are opaque enough.
Widget paperImage(String id, {required double size, Widget? fallback}) {
  final image = ArtImage(Art.paper(id), size: size, fallback: fallback);
  if (id != 'mesh') return image;
  return Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      Container(
        width: size * 0.62,
        height: size * 0.5,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
      ),
      image,
    ],
  );
}
