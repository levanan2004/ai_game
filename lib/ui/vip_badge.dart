import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'art.dart';
import 'vip_text.dart';

/// VIP name colour by tier (spec 4.3, "gợi ý" colours as given; VIP 3, 4
/// and 7 darkened by Phú for contrast; economy.json `vip.nameColors` is
/// kept equal by test). Null below VIP 1.
Color? vipNameColor(int level) => switch (level) {
  1 => const Color(0xFF3F7F52),
  2 => const Color(0xFF2F6340),
  3 => const Color(0xFFB8527E),
  4 => const Color(0xFFA23E78),
  5 => const Color(0xFF2E6EA0),
  6 => const Color(0xFF1A5A8A),
  7 => const Color(0xFF9A6418),
  8 => const Color(0xFFB07820),
  9 || 10 => AppColors.statusSuccess,
  _ => null,
};

/// Phú's VIP card background `vip/vip_nen_the.webp` (1640x381, gold frame
/// with flower corners).
const vipCardArt = 'assets/images/vip/vip_nen_the.webp';
const vipCardArtWidth = 1640.0;
const vipCardArtHeight = 381.0;

/// The file is drawn at 1/8 size on a tall card (corners 60x21 dp). A
/// power of two keeps Flutter's nine-patch size check exact.
const vipCardArtScale = 8.0;

/// The part that stretches, in file pixels: plain green between the flower
/// corners (the corners are drawn as they are).
const vipCardSlice = Rect.fromLTRB(480, 170, 1160, 211);

/// The darkest and lightest green of the stretched part (sampled from the
/// file); white text on them stays over 4.5:1.
const vipCardGreens = [Color(0xFF2A6C3F), Color(0xFF357A48)];

/// Secondary text on the card: white too.
const vipCardText = AppColors.onPrimary;

/// Phú's crown of VIP [level] next to a name (`vip/vuong_mien_vip_<n>_128`).
String vipCrownArt(int level) => Art.vip('vuong_mien_vip_${level}_128');

/// The VIP badge (spec 4.3), always right after the name: Phú's crown of
/// the tier, 16 dp in chat, 16–18 on board rows, 32 on the profile card.
/// From 40 dp (the VIP screen) the tier medal `vip/vip_<n>.webp` is drawn.
/// VIP 10 at 56 dp and more gets one shimmer pass.
class VipBadge extends StatelessWidget {
  const VipBadge({super.key, required this.level, this.size = 18});

  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (level < 1 || level > 10) return SizedBox(width: size, height: size);
    final pill = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: vipNameColor(level),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$level',
        style: AppText.caption(size: size * 0.5, color: AppColors.onPrimary),
      ),
    );
    final art = size < 40 ? vipCrownArt(level) : Art.vip('vip_$level');
    Widget badge = ArtImage(art, size: size, fallback: pill);
    if (level == 10 && size >= 56) badge = _Shimmer(child: badge);
    return Semantics(label: VipText.badge(level), child: badge);
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: -1, end: 2),
    duration: const Duration(milliseconds: 1400),
    curve: Curves.easeInOut,
    child: child,
    builder: (context, t, child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (r) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0x00FFFFFF), Color(0x88FFFFFF), Color(0x00FFFFFF)],
        stops: [
          (t - 0.3).clamp(0.0, 1.0),
          t.clamp(0.0, 1.0),
          (t + 0.3).clamp(0.0, 1.0),
        ],
      ).createShader(r),
      child: child,
    ),
  );
}

/// A shop name in its VIP colour with the badge right after it (spec 4.3).
/// Level 0: the name as [style] has it, no badge.
class VipName extends StatelessWidget {
  const VipName({
    super.key,
    required this.name,
    required this.level,
    required this.style,
    this.badgeSize = 18,
    this.badgeKey,
  });

  final String name;
  final int level;
  final TextStyle style;
  final double badgeSize;
  final Key? badgeKey;

  @override
  Widget build(BuildContext context) {
    final color = vipNameColor(level);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: color == null ? style : style.copyWith(color: color),
          ),
        ),
        if (level > 0) ...[
          const SizedBox(width: 3),
          VipBadge(key: badgeKey, level: level, size: badgeSize),
        ],
      ],
    );
  }
}

/// "Chủ Tiệm Ngọc" under the name of a VIP 10 (spec 4.5): emerald, small
/// crown on the left. Nothing below VIP 10.
class VipTitleLine extends StatelessWidget {
  const VipTitleLine({super.key, required this.level, this.size = 11});

  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (level < 10) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Phú's VIP 10 crown.
        ArtImage(
          vipCrownArt(10),
          key: const Key('vip-title-crown'),
          size: size + 5,
          fallback: Icon(
            Icons.workspace_premium,
            size: size + 5,
            color: AppColors.statusSuccess,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          VipText.title10,
          style: AppText.caption(
            size: size,
            color: AppColors.statusSuccess,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
