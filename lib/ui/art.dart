import 'package:flutter/widgets.dart';

/// Paths of Phú's art v0.1 (assets/images, PNG 256px, transparent).
/// File names equal the ids in economy.json; customer avatars use the
/// avatarId from customers/index.json.
class Art {
  const Art._();

  static const root = 'assets/images/';

  static String flower(String id) => '${root}flowers/$id.png';
  static String paper(String id) => '${root}papers/$id.png';
  static String ribbon(String id) => '${root}ribbons/$id.png';
  static String upgrade(String id) => '${root}upgrades/$id.png';
  static String customer(String avatarId) => '${root}customers/$avatarId.png';

  /// Same path relative to [root], as Flame's image cache expects.
  static String forFlame(String path) =>
      path.startsWith(root) ? path.substring(root.length) : path;
}

/// A PNG from [Art] at a fixed square size. Shows [fallback] (the old drawn
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
