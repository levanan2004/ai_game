import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/gacha.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'gacha_text.dart';

/// "Vòng quay" in the right icon column: a cream circle with a gold border,
/// `gacha/icon_vong_quay.webp`, the label under it like the bottom-bar
/// labels. Red dot: an unused card of this week's pot, or a new week not
/// opened yet. After "Đóng" on the intro it glows and blinks twice.
class GachaEntryIcon extends StatefulWidget {
  const GachaEntryIcon({super.key, required this.gacha});

  final GachaController gacha;

  static const double width = 60;
  static const double height = 70;

  @override
  State<GachaEntryIcon> createState() => _GachaEntryIconState();
}

class _GachaEntryIconState extends State<GachaEntryIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late int _seq = widget.gacha.glowSeq;

  @override
  void initState() {
    super.initState();
    widget.gacha.addListener(_check);
  }

  @override
  void didUpdateWidget(covariant GachaEntryIcon old) {
    super.didUpdateWidget(old);
    if (old.gacha != widget.gacha) {
      old.gacha.removeListener(_check);
      widget.gacha.addListener(_check);
    }
  }

  @override
  void dispose() {
    widget.gacha.removeListener(_check);
    _glow.dispose();
    super.dispose();
  }

  void _check() {
    if (widget.gacha.glowSeq != _seq) {
      _seq = widget.gacha.glowSeq;
      _glow.forward(from: 0);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.gacha;
    return Semantics(
      button: true,
      label: GachaText.iconLabel,
      child: GestureDetector(
        key: const Key('gacha-entry'),
        behavior: HitTestBehavior.opaque,
        onTap: g.openScreen,
        child: SizedBox(
          width: GachaEntryIcon.width,
          height: GachaEntryIcon.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 6,
                top: 0,
                width: 48,
                height: 48,
                child: AnimatedBuilder(
                  animation: _glow,
                  builder: (context, child) {
                    // Two blinks: (1 - cos 4πt) / 2 peaks twice.
                    final t = _glow.value;
                    final v = t <= 0 || t >= 1
                        ? 0.0
                        : (1 - math.cos(4 * math.pi * t)) / 2;
                    return DecoratedBox(
                      key: const Key('gacha-entry-circle'),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.templeGold,
                          width: 2.5,
                        ),
                        boxShadow: [
                          const BoxShadow(
                            color: Color(0x332E3A2C),
                            offset: Offset(0, 2),
                            blurRadius: 3,
                          ),
                          if (v > 0)
                            BoxShadow(
                              color: AppColors.templeGold.withValues(
                                alpha: 0.9 * v,
                              ),
                              blurRadius: 14 * v,
                              spreadRadius: 4 * v,
                            ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      Art.gacha('icon_vong_quay'),
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.casino_outlined,
                        color: AppColors.templeGold,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -4,
                right: -4,
                top: 50,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    GachaText.iconLabel,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style:
                        AppText.make(
                          AppFonts.display,
                          11.5,
                          700,
                          height: 1.1,
                          color: AppColors.navLabel,
                        ).copyWith(
                          shadows: const [
                            Shadow(color: Colors.white, blurRadius: 3),
                            Shadow(color: Colors.white, blurRadius: 1.5),
                          ],
                        ),
                  ),
                ),
              ),
              if (g.dot)
                Positioned(
                  right: 4,
                  top: -2,
                  width: 16,
                  height: 16,
                  child: ArtImage(
                    Art.menu('cham_do'),
                    key: const Key('gacha-entry-dot'),
                    size: 16,
                    fallback: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.statusDanger,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One-time intro on entering the game: the week's banner on top,
/// "Xem ngay" opens the wheel, "Đóng" makes the icon blink twice.
class GachaIntroPopup extends StatelessWidget {
  const GachaIntroPopup({super.key, required this.gacha});

  final GachaController gacha;

  @override
  Widget build(BuildContext context) {
    final g = gacha;
    final asset = g.assetOf(g.potId);
    return Stack(
      key: const Key('gacha-intro'),
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.bgOverlay)),
        Center(
          child: Container(
            width: 312,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.bgBase,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.templeGold, width: 2),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (asset != null)
                          Positioned.fill(
                            child: Image.asset(
                              Art.gachaPot(asset, 'banner'),
                              key: const Key('gacha-intro-banner'),
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 56),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              g.potName(g.potId),
                              maxLines: 1,
                              style: AppText.title(size: 16, weight: 800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    GachaText.introTitle,
                    textAlign: TextAlign.center,
                    style: AppText.title(size: 18, weight: 800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    GachaText.introBody(g.potName(g.potId)),
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 13, weight: 700),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ChunkyButton(
                            key: const Key('gacha-intro-close'),
                            label: GachaText.introClose,
                            kind: ButtonKind.ghost,
                            onPressed: () => g.closeIntro(open: false),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ChunkyButton(
                            key: const Key('gacha-intro-ok'),
                            label: GachaText.introOk,
                            onPressed: () => g.closeIntro(open: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
