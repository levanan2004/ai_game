import 'package:flutter/material.dart';

import '../logic/login_rewards.dart';
import '../logic/rewards.dart';
import '../logic/welfare_text.dart';
import '../theme/tokens.dart';
import 'phuc_loi_art.dart';
import 'reward_bundle_view.dart';

/// Phú's art for the Điểm danh tiles (dot1_khung_qua). Return null from a
/// getter to fall back to the plain Flutter shape for that state.
abstract final class LoginTileArt {
  static PhucLoiArt? get claimed => PhucLoiArt.oDaNhan;
  static PhucLoiArt? get today => PhucLoiArt.oHomNay;
  static PhucLoiArt? get locked => PhucLoiArt.oKhoa;

  /// Frame of the big day-7 tile (any state).
  static PhucLoiArt? get day7 => PhucLoiArt.oNgay7;

  /// The tick badge over a claimed tile's bottom-right corner.
  static PhucLoiArt? get claimedBadge => PhucLoiArt.huyHieuDaNhan;
}

/// The 7-day table: days 1–6 in two rows of three, day 7 standing tall on
/// the right across both rows (preview_dot1.png, folded to fit the sheet).
///
/// Days 1–6 share the 432 canvas, so the "today" glow sticks out as Phú
/// intended instead of shrinking that tile. Cells overlap their
/// transparent margins so the visible tiles sit [gap] apart.
class LoginWeekBoard extends StatelessWidget {
  const LoginWeekBoard({super.key, required this.tile});

  /// Builds day n (1..7), usually a [LoginDayTile].
  final Widget Function(int day) tile;

  static const _ink = 325 / 432;
  static const _margin = 54 / 432;
  static const _gap = 0.07;
  static const _day7Aspect = 742 / 847;

  /// Canvas edge of a small tile for a board [width] wide.
  static double cellFor(double width) {
    const pitch = _ink + _gap;
    const day7H = pitch + _ink;
    const total = 2 * pitch + _ink + _gap + day7H * _day7Aspect;
    return width / total;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final c = cellFor(box.maxWidth);
        final pitch = (_ink + _gap) * c;
        final shift = -_margin * c;
        final day7H = pitch + _ink * c;
        final day7W = day7H * _day7Aspect;
        final day7Left = 2 * pitch + _ink * c + _gap * c;
        return SizedBox(
          width: box.maxWidth,
          height: day7H,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < 6; i++)
                Positioned(
                  left: shift + (i % 3) * pitch,
                  top: shift + (i ~/ 3) * pitch,
                  width: c,
                  height: c,
                  child: tile(i + 1),
                ),
              Positioned(
                left: day7Left,
                top: 0,
                width: day7W,
                height: day7H,
                child: tile(loginRewardDays),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One day of the 7-day table. Each state is its own widget.
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

/// Already claimed: mint tile, gift in full colour, tick badge.
class LoginTileClaimed extends StatelessWidget {
  const LoginTileClaimed({super.key, required this.day, required this.bundle});

  final int day;
  final RewardBundle bundle;

  @override
  Widget build(BuildContext context) {
    return _ArtTile(
      day: day,
      bundle: bundle,
      art: LoginTileArt.claimed,
      bandColor: AppColors.primaryPressed,
      fallbackColor: AppColors.surfaceSunken,
      badge: true,
    );
  }
}

/// Today's tile: cream with the gold glow, tap to claim.
class LoginTileToday extends StatelessWidget {
  const LoginTileToday({super.key, required this.day, required this.bundle});

  final int day;
  final RewardBundle bundle;

  @override
  Widget build(BuildContext context) {
    return _ArtTile(
      day: day,
      bundle: bundle,
      art: LoginTileArt.today,
      bandColor: AppColors.onSecondary,
      fallbackColor: AppColors.headerChip,
    );
  }
}

/// A later day: grey tile with the lock, gift greyed out.
class LoginTileLocked extends StatelessWidget {
  const LoginTileLocked({super.key, required this.day, required this.bundle});

  final int day;
  final RewardBundle bundle;

  @override
  Widget build(BuildContext context) {
    return _ArtTile(
      day: day,
      bundle: bundle,
      art: LoginTileArt.locked,
      bandColor: const Color(0xFF6B5A44),
      fallbackColor: AppColors.surfaceCard,
      greyed: true,
    );
  }
}

/// Tick badge over a claimed tile.
class ClaimedBadge extends StatelessWidget {
  const ClaimedBadge({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    final art = LoginTileArt.claimedBadge;
    final shape = Icon(
      Icons.check_circle_rounded,
      size: size,
      color: AppColors.primaryBase,
    );
    if (art == null) return shape;
    return SizedBox(
      width: size,
      height: size / art.aspect,
      child: phucLoiImage(art, fallback: shape),
    );
  }
}

/// Greyscale for locked gifts.
const _grey = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

class _ArtTile extends StatelessWidget {
  const _ArtTile({
    required this.day,
    required this.bundle,
    required this.art,
    required this.bandColor,
    required this.fallbackColor,
    this.badge = false,
    this.greyed = false,
  });

  final int day;
  final RewardBundle bundle;
  final PhucLoiArt? art;
  final Color bandColor;
  final Color fallbackColor;
  final bool badge;
  final bool greyed;

  @override
  Widget build(BuildContext context) {
    final big = day == loginRewardDays;
    final picture = big ? (LoginTileArt.day7 ?? art) : art;
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final fallback = DecoratedBox(
          decoration: BoxDecoration(
            color: fallbackColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
        );
        final ink = picture?.ink == null
            ? Offset.zero & size
            : picture!.place(picture.ink!, size);
        final band = picture?.band == null
            ? Rect.fromLTWH(0, 0, size.width, size.height * 0.22)
            : picture!.place(picture.band!, size);
        final inner = picture == null
            ? Rect.fromLTWH(
                4,
                size.height * 0.24,
                size.width - 8,
                size.height * 0.7,
              )
            : picture.place(picture.inner, size);
        final gifts = _Gifts(bundle: bundle, big: big);
        Widget content = gifts;
        if (greyed) {
          content = Opacity(
            opacity: 0.6,
            child: ColorFiltered(colorFilter: _grey, child: gifts),
          );
        }
        final badgeSize = (big ? 0.34 : 0.4) * ink.width;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: picture == null
                  ? fallback
                  : phucLoiImage(picture, fallback: fallback),
            ),
            Positioned.fromRect(
              rect: band,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    WelfareText.loginDay(day),
                    textScaler: TextScaler.noScaling,
                    style: AppText.make(
                      AppFonts.display,
                      (band.height * 0.82).clamp(6.0, 16.0),
                      800,
                      height: 1,
                      color: bandColor,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              // Locked day 7 keeps the bottom of its area for the lock.
              rect: greyed && big
                  ? Rect.fromLTWH(
                      inner.left,
                      inner.top,
                      inner.width,
                      inner.height * 0.74,
                    )
                  : inner,
              child: Center(
                child: FittedBox(fit: BoxFit.scaleDown, child: content),
              ),
            ),
            if (greyed && big)
              Positioned(
                // Day 7 has no locked picture: a small gold lock under the
                // gifts, inside its empty area.
                left: inner.left,
                width: inner.width,
                top: inner.top + inner.height * 0.74,
                height: inner.height * 0.26,
                child: FittedBox(
                  child: Icon(
                    Icons.lock_rounded,
                    key: const Key('login-day7-lock'),
                    size: 20,
                    color: const Color(0xFFC9962E),
                  ),
                ),
              ),
            if (badge)
              Positioned(
                left: ink.right - badgeSize * 0.8,
                top: ink.bottom - badgeSize * 0.8,
                child: ClaimedBadge(size: badgeSize),
              ),
          ],
        );
      },
    );
  }
}

class _Gifts extends StatelessWidget {
  const _Gifts({required this.bundle, required this.big});

  final RewardBundle bundle;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 34.0 : 28.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < bundle.items.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              rewardIcon(bundle.items[i], size: size),
              if (bundle.items[i].amount > 1)
                Text(
                  rewardAmountText(bundle.items[i]),
                  textScaler: TextScaler.noScaling,
                  style: AppText.number(
                    size: big ? 13 : 12,
                    color: AppColors.textPrimary,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
