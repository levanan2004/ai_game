import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/shop_session.dart';
import '../theme/mock_palette.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';

/// Màn mở đầu (spec_popup_va_mo_dau.md §5, man_mo_dau_v0.1.png).
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen>
    with SingleTickerProviderStateMixin {
  /// Flowers on the counter sway ±3° with a 2 s period.
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
  bool _confirmNew = false;

  // Game name "Tiệm Hoa Sớm Mai", split over two lines as in the mockup.
  static const _titleTop = 'Tiệm Hoa';
  static const _titleBottom = 'Sớm Mai';
  // The spec's "tên game tạm" is dropped now that the name is final.
  static const _version = 'v0.1';

  /// Five flowers on the counter, as in the mockup.
  static const _counterFlowers = [
    'rose',
    'sunflower',
    'tulip',
    'daisy',
    'lily',
  ];

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final has = s.hasSave;
    return OpaqueScreen(
      color: AppColors.bgShop,
      child: Stack(
        children: [
          const Positioned(left: 0, top: 0, child: AwningStrip(height: 40)),
          Positioned(left: 316, top: 8, child: SettingsGear(session: s)),
          Positioned(
            left: 0,
            right: 0,
            top: 84,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppMotion.celebrate,
              curve: Curves.easeOutBack,
              builder: (_, t, c) =>
                  Transform.scale(scale: 0.6 + 0.4 * t, child: c),
              child: Column(
                children: [
                  Text(
                    _titleTop,
                    style: AppText.make(
                      AppFonts.display,
                      44,
                      800,
                      height: 1.0,
                      color: AppColors.primaryPressed,
                    ),
                  ),
                  Text(
                    _titleBottom,
                    style: AppText.make(
                      AppFonts.display,
                      44,
                      800,
                      height: 1.0,
                      color: AppColors.primaryBase,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 40,
            top: 196,
            width: 280,
            height: 210,
            child: _ShopPicture(sway: _sway, flowers: _counterFlowers),
          ),
          Positioned(
            left: 56,
            top: 440,
            width: 248,
            height: 60,
            child: ChunkyButton(
              key: const Key('title-main'),
              label: has ? 'Chơi tiếp' : 'Bắt đầu',
              fontSize: 20,
              onPressed: has ? s.continueFromTitle : s.requestNewGame,
            ),
          ),
          if (has)
            Positioned(
              left: 0,
              right: 0,
              top: 504,
              child: Text(
                s.state.shopName == null
                    ? 'Ngày ${s.state.day} · ${s.rank.nameVi} · ${formatK(s.state.money)}'
                    : '${s.state.shopName} · Ngày ${s.state.day} · ${formatK(s.state.money)}',
                textAlign: TextAlign.center,
                style: AppText.caption(),
              ),
            ),
          if (has)
            Positioned(
              left: 96,
              top: 536,
              width: 168,
              height: 44,
              child: ChunkyButton(
                key: const Key('title-new'),
                label: 'Chơi mới',
                kind: ButtonKind.ghost,
                fontSize: 15,
                onPressed: () => setState(() => _confirmNew = true),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 612,
            child: Text(
              _version,
              textAlign: TextAlign.center,
              style: AppText.caption(size: 10, color: AppColors.textDisabled),
            ),
          ),
          if (_confirmNew) _confirmDialog(s),
        ],
      ),
    );
  }

  Widget _confirmDialog(ShopSession s) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _confirmNew = false),
        child: ColoredBox(
          color: AppColors.bgOverlay,
          child: Stack(
            children: [
              Positioned(
                left: 40,
                top: 230,
                width: 280,
                height: 170,
                child: GestureDetector(
                  onTap: () {},
                  child: CardBox(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      children: [
                        Text(
                          'Bắt đầu lại từ ngày 1? Tiến độ hiện tại sẽ mất.',
                          key: const Key('title-new-confirm'),
                          textAlign: TextAlign.center,
                          style: AppText.body(size: 15, weight: 800),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ChunkyButton(
                                  label: 'Hủy',
                                  kind: ButtonKind.ghost,
                                  fontSize: 15,
                                  onPressed: () =>
                                      setState(() => _confirmNew = false),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: _DangerButton(
                                  key: const Key('title-new-yes'),
                                  label: 'Chơi mới',
                                  onTap: () {
                                    setState(() => _confirmNew = false);
                                    s.requestNewGame();
                                  },
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
          ),
        ),
      ),
    );
  }
}

/// "Chơi mới" in the confirm dialog: `status.danger`.
class _DangerButton extends StatelessWidget {
  const _DangerButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSize.shadowOffset),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.statusDanger,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(
                  AppColors.statusDanger,
                  AppColors.textPrimary,
                  0.3,
                )!,
                offset: const Offset(0, AppSize.shadowOffset),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.button(
              size: 15,
              weight: 800,
              color: AppColors.textInverse,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shop owner (upgrades/staff.png) behind a wooden counter with flowers.
class _ShopPicture extends StatelessWidget {
  const _ShopPicture({required this.sway, required this.flowers});

  final Animation<double> sway;
  final List<String> flowers;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.lg),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border.all(
            color: AppColors.surfaceBorder,
            width: AppBorder.thin,
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 140 - 40,
              top: 8,
              child: ArtImage(Art.upgrade('staff'), size: 80),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 132,
              height: 16,
              child: ColoredBox(color: MockPalette.shelfWood),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 148,
              bottom: 0,
              child: ColoredBox(color: MockPalette.counterTop),
            ),
            for (var i = 0; i < flowers.length; i++)
              Positioned(
                left: 14 + i * 52.0,
                top: 82,
                child: AnimatedBuilder(
                  animation: sway,
                  builder: (_, child) => Transform.rotate(
                    angle:
                        math.sin(sway.value * 2 * math.pi + i) *
                        3 *
                        math.pi /
                        180,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                  child: ArtImage(Art.flower(flowers[i]), size: 52),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
