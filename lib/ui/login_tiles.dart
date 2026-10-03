import 'package:flutter/material.dart';

import '../logic/login_rewards.dart';
import '../logic/rewards.dart';
import '../logic/welfare_text.dart';
import '../theme/tokens.dart';
import 'reward_bundle_view.dart';

/// Designer art for the Điểm danh tiles, coming later. Return an asset path
/// here (a webp under the images/welfare asset folder) and the matching
/// state draws it as its background; null keeps the Flutter shapes.
abstract final class LoginTileArt {
  static String? get claimed => null;
  static String? get today => null;
  static String? get locked => null;

  /// Frame of the big day-7 tile (any state).
  static String? get day7 => null;

  /// The "Đã nhận" stamp over a claimed tile.
  static String? get claimedBadge => null;
}

/// One day of the 7-day table. Each state is its own widget, so art can be
/// dropped in per state later.
class LoginDayTile extends StatelessWidget {
  const LoginDayTile({
    super.key,
    required this.day,
    required this.state,
    required this.bundle,
    this.onTap,
  });

  final int day;
  final LoginTile state;
  final RewardBundle bundle;
  final VoidCallback? onTap;

  bool get big => day == loginRewardDays;

  @override
  Widget build(BuildContext context) {
    final key = Key('login-day-$day-${state.name}');
    return GestureDetector(
      key: Key('login-day-$day'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: switch (state) {
        LoginTile.claimed => LoginTileClaimed(
          key: key,
          day: day,
          bundle: bundle,
        ),
        LoginTile.today => LoginTileToday(key: key, day: day, bundle: bundle),
        LoginTile.locked => LoginTileLocked(key: key, day: day, bundle: bundle),
      },
    );
  }
}

/// Already claimed: dimmed, with the [ClaimedBadge] on top.
class LoginTileClaimed extends StatelessWidget {
  const LoginTileClaimed({super.key, required this.day, required this.bundle});

  final int day;
  final RewardBundle bundle;

  @override
  Widget build(BuildContext context) {
    return _TileFrame(
      day: day,
      art: LoginTileArt.claimed,
      color: AppColors.surfaceSunken,
      border: AppColors.surfaceBorder,
      child: Stack(
        children: [
          Opacity(
            opacity: 0.45,
            child: _TileContent(day: day, bundle: bundle),
          ),
          const Positioned.fill(child: Center(child: ClaimedBadge())),
        ],
      ),
    );
  }
}

/// Today's tile: highlighted, tap to claim.
class LoginTileToday extends StatelessWidget {
  const LoginTileToday({super.key, required this.day, required this.bundle});

  final int day;
  final RewardBundle bundle;

  @override
  Widget build(BuildContext context) {
    return _TileFrame(
      day: day,
      art: LoginTileArt.today,
      color: AppColors.headerChip,
      border: AppColors.primaryBase,
      borderWidth: 2.5,
      glow: true,
      child: _TileContent(day: day, bundle: bundle),
    );
  }
}

/// A later day: faded, with a small lock.
class LoginTileLocked extends StatelessWidget {
  const LoginTileLocked({super.key, required this.day, required this.bundle});

  final int day;
  final RewardBundle bundle;

  @override
  Widget build(BuildContext context) {
    return _TileFrame(
      day: day,
      art: LoginTileArt.locked,
      color: AppColors.surfaceCard,
      border: AppColors.surfaceBorder,
      child: Stack(
        children: [
          Opacity(
            opacity: 0.55,
            child: _TileContent(day: day, bundle: bundle),
          ),
          const Positioned(
            right: 0,
            top: 0,
            child: Icon(
              Icons.lock_rounded,
              size: 13,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Đã nhận" stamp. Swap in [LoginTileArt.claimedBadge] when it exists.
class ClaimedBadge extends StatelessWidget {
  const ClaimedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final art = LoginTileArt.claimedBadge;
    if (art != null) {
      return Image.asset(
        art,
        width: 56,
        errorBuilder: (_, _, _) => const _ShapeBadge(),
      );
    }
    return const _ShapeBadge();
  }
}

class _ShapeBadge extends StatelessWidget {
  const _ShapeBadge();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 26,
          color: AppColors.primaryBase,
        ),
        Text(
          WelfareText.loginClaimed,
          style: AppText.caption(
            size: 11,
            weight: 800,
            color: AppColors.primaryPressed,
          ),
        ),
      ],
    );
  }
}

class _TileFrame extends StatelessWidget {
  const _TileFrame({
    required this.day,
    required this.art,
    required this.color,
    required this.border,
    required this.child,
    this.borderWidth = 1,
    this.glow = false,
  });

  final int day;
  final String? art;
  final Color color;
  final Color border;
  final double borderWidth;
  final bool glow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final big = day == loginRewardDays;
    final picture = big ? (LoginTileArt.day7 ?? art) : art;
    return Container(
      height: big ? 104 : 96,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        image: picture == null
            ? null
            : DecorationImage(image: AssetImage(picture), fit: BoxFit.fill),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border, width: borderWidth),
        boxShadow: glow
            ? const [
                BoxShadow(
                  color: Color(0x553E8E5A),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class _TileContent extends StatelessWidget {
  const _TileContent({required this.day, required this.bundle});

  final int day;
  final RewardBundle bundle;

  @override
  Widget build(BuildContext context) {
    final big = day == loginRewardDays;
    final size = big ? 34.0 : 26.0;
    return Column(
      children: [
        Text(
          WelfareText.loginDay(day),
          style: AppText.caption(
            size: big ? 13 : 11,
            weight: 800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: [
                for (final item in bundle.items)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      rewardIcon(item, size: size),
                      if (item.amount > 1)
                        Text(
                          '×${item.amount}',
                          style: AppText.caption(
                            size: 10,
                            weight: 800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
