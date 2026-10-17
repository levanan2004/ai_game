import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'art.dart';
import 'vip_text.dart';

/// VIP name colour by tier (spec 4.3, "gợi ý" colours as given). VIP 3 uses
/// the second of its two suggestions. Null below VIP 1.
Color? vipNameColor(int level) => switch (level) {
  1 => const Color(0xFF3F7F52),
  2 => const Color(0xFF2F6340),
  3 => const Color(0xFFE08AB0),
  4 => const Color(0xFFD478A0),
  5 => const Color(0xFF2E6EA0),
  6 => const Color(0xFF1A5A8A),
  7 => const Color(0xFFC98A2A),
  8 => const Color(0xFFB07820),
  9 || 10 => AppColors.statusSuccess,
  _ => null,
};

/// The VIP badge `vip/vip_<n>.webp` (spec 4.3): 16 dp in chat, 18 on board
/// rows, 24 on the profile card, 64 on the VIP screen. Always right after
/// the name. VIP 10 at 56 dp and more gets one shimmer pass.
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
    Widget badge = ArtImage(Art.vip('vip_$level'), size: size, fallback: pill);
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
        // vip/icon_vuong_mien_danh_hieu.webp is not drawn yet (spec 4.5 🟠).
        Icon(
          Icons.workspace_premium,
          size: size + 5,
          color: AppColors.statusSuccess,
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
