import 'dart:math' as math;

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

  /// Where o_khoa draws its lock, as fractions of the tile's ink width:
  /// gap to the right edge, gap to the bottom edge, and lock height. The
  /// locked day 7 (no locked picture) puts its gold lock at the same spot,
  /// measured with a small tile's ink width so all locks match in size.
  static const lockRight = 0.098;
  static const lockBottom = 0.071;
  static const lockHeight = 0.338;
  static const lockWidth = 0.268;
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

  /// A small tile's ink width over the day-7 tile's height.
  static const smallInkPerDay7 = _ink / (2 * _ink + _gap);

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

/// "+N" on a small tile holding more gifts than the one drawn.
class MoreGiftsBadge extends StatelessWidget {
  const MoreGiftsBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primaryPressed,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceCard, width: 1.2),
      ),
      child: Text(
        WelfareText.loginMore(count),
        textScaler: TextScaler.noScaling,
        style: AppText.number(size: 10, color: AppColors.onPrimary),
      ),
    );
  }
}

/// Locked gifts keep 60% of their colour, so they stay recognisable.
const _faded = ColorFilter.matrix([
  0.6850, 0.2861, 0.0289, 0, 0, //
  0.0850, 0.8861, 0.0289, 0, 0, //
  0.0850, 0.2861, 0.6289, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// Opacity of a locked gift icon (its amount stays fully readable).
const lockedGiftOpacity = 0.8;

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
    final more = big ? 0 : math.max(0, bundle.items.length - 1);
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
        final badgeSize = (big ? 0.34 : 0.4) * ink.width;
        // Day 7's lock is sized off a small tile so every lock matches.
        final lockRef = size.height * LoginWeekBoard.smallInkPerDay7;
        final lockBox = LoginTileArt.lockHeight * lockRef * 24 / 22;
        final lockTop =
            ink.bottom - LoginTileArt.lockBottom * lockRef - lockBox * 23 / 24;
        // Locked day 7: the gifts stay above its lock. Small locked tiles
        // may use the room up to the painted lock.
        final paintedLockLeft =
            ink.right -
            (LoginTileArt.lockRight + LoginTileArt.lockWidth) * ink.width;
        final giftArea = !greyed
            ? inner
            : big
            ? Rect.fromLTRB(
                inner.left,
                inner.top,
                inner.right,
                math.min(inner.bottom, lockTop - 2),
              )
            : Rect.fromLTRB(
                inner.left,
                inner.top,
                math.max(inner.right, paintedLockLeft - 1),
                inner.bottom,
              );
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
              rect: giftArea,
              child: Center(
                child: _Gifts(
                  // Small tiles draw only the main (first) gift; the rest
                  // are in the day's detail card.
                  bundle: big || more == 0
                      ? bundle
                      : RewardBundle([bundle.items.first]),
                  big: big,
                  area: giftArea.size,
                  faded: greyed,
                ),
              ),
            ),
            if (more > 0)
              Positioned(
                right: size.width - giftArea.right - 2,
                top: giftArea.top - 3,
                child: MoreGiftsBadge(key: Key('login-more-$day'), count: more),
              ),
            if (greyed && big)
              Positioned(
                // Day 7 has no locked picture: a gold lock in the
                // bottom-right corner, where o_khoa draws its lock. The
                // glyph fills 22/24 of the icon box (x 4..20, y 1..23).
                left:
                    ink.right -
                    LoginTileArt.lockRight * lockRef -
                    lockBox * 20 / 24,
                top: lockTop,
                width: lockBox,
                height: lockBox,
                child: Icon(
                  Icons.lock_rounded,
                  key: const Key('login-day7-lock'),
                  size: lockBox,
                  color: const Color(0xFFC9962E),
                  shadows: [
                    for (final o in const [
                      Offset(1, 0),
                      Offset(-1, 0),
                      Offset(0, 1),
                      Offset(0, -1),
                    ])
                      Shadow(
                        color: const Color(0xFF6B4A1E),
                        offset: o * lockBox * 0.03,
                      ),
                  ],
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

/// The gifts inside a tile's empty area. Amounts always use the same font
/// size on every tile; when the area is narrow the icons shrink instead.
class _Gifts extends StatelessWidget {
  const _Gifts({
    required this.bundle,
    required this.big,
    required this.area,
    this.faded = false,
  });

  final RewardBundle bundle;
  final bool big;
  final Size area;
  final bool faded;

  static const gap = 3.0;

  /// Amount font size: the same on every tile of one size.
  static double amountSize({required bool big}) => big ? 13 : 12;

  @override
  Widget build(BuildContext context) {
    final items = bundle.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final style = AppText.number(
      size: amountSize(big: big),
      color: AppColors.textPrimary,
    );
    final labels = [
      for (final item in items) item.amount > 1 ? rewardAmountText(item) : null,
    ];
    final textW = <double>[];
    var textH = 0.0;
    for (final label in labels) {
      if (label == null) {
        textW.add(0);
        continue;
      }
      final tp = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        maxLines: 1,
      )..layout();
      textW.add(tp.width);
      textH = math.max(textH, tp.height);
    }
    final n = items.length;
    final gaps = gap * (n - 1);
    // Icons shrink to fit the area (text never does).
    double rowWidth(double icon) =>
        textW.fold(gaps, (sum, w) => sum + math.max(icon, w));
    var icon = math.min(big ? 34.0 : 28.0, area.height - textH);
    while (icon > 8 && rowWidth(icon) > area.width) {
      icon -= 0.5;
    }
    // Several gifts: columns as wide as the icons, the first amount aligned
    // left, the last right, so amounts may run under a neighbour's icon
    // (day 6's narrow area keeps bigger icons). Only while all amounts fit
    // side by side.
    final textSum = textW.fold(gaps, (sum, w) => sum + w);
    var edge = 0.0;
    if (n > 1) {
      edge = math.min(
        math.min(big ? 34.0 : 28.0, area.height - textH),
        (area.width - gaps) / n,
      );
      if (textSum > edge * n + gaps) edge = 0;
    }
    Widget iconOf(int i, double size) => faded
        ? Opacity(
            opacity: lockedGiftOpacity,
            child: ColorFiltered(
              colorFilter: _faded,
              child: rewardIcon(items[i], size: size),
            ),
          )
        : rewardIcon(items[i], size: size);
    Widget? amountOf(int i) => labels[i] == null
        ? null
        : Text(
            labels[i]!,
            key: Key('login-amount-${items[i].kind.json}'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textScaler: TextScaler.noScaling,
            style: style,
          );
    if (edge > icon + 0.5) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            SizedBox(
              width: edge,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconOf(i, edge),
                  if (labels[i] != null)
                    SizedBox(
                      width: edge,
                      height: textH,
                      child: OverflowBox(
                        maxWidth: double.infinity,
                        alignment: i == 0
                            ? Alignment.centerLeft
                            : i == n - 1
                            ? Alignment.centerRight
                            : Alignment.center,
                        child: amountOf(i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    return OverflowBox(
      maxWidth: double.infinity,
      maxHeight: double.infinity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            SizedBox(
              width: math.max(icon, textW[i]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [iconOf(i, icon), ?amountOf(i)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
