import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'pot_widgets.dart';
import 'ui_skin.dart';

/// The one-time reminder, form A (SPEC_tiem_chau_hoa.md §4.4): the screen
/// dims, the "Chậu hoa" tab is cut out in gold and a box points to it.
/// Shown once; the flag is already on while it is up.
class PotShopHintBox extends StatelessWidget {
  const PotShopHintBox({
    super.key,
    required this.session,
    required this.onClose,
  });

  final ShopSession session;
  final VoidCallback onClose;

  /// The 6th tab of the bottom nav (x 300–360, y 560–640).
  static const tab = Rect.fromLTWH(302, 566, 56, 68);

  @override
  Widget build(BuildContext context) {
    final s = session;
    // Three cheap pots as a taste.
    final pots = <PotDef>[for (final p in s.potShopList('chomSao').take(3)) p];
    return Stack(
      key: const Key('pot-hint'),
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('pot-hint-dismiss'),
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: CustomPaint(painter: _SpotlightPainter(tab)),
          ),
        ),
        const Positioned(
          left: 320,
          top: 546,
          child: IgnorePointer(
            child: CustomPaint(size: Size(28, 16), painter: _ArrowPainter()),
          ),
        ),
        Positioned(
          left: 20,
          top: 150,
          width: 320,
          child: SkinPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 96,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final p in pots)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: PotArt(pot: p, base: 78 / 1.1),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tiệm có chậu mới rồi, ghé Tiệm Chậu Hoa xem thử nhé!',
                  key: const Key('pot-hint-body'),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  style: AppText.title(size: 17, weight: 800),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: SkinButton(
                          key: const Key('pot-hint-later'),
                          label: 'Để sau',
                          kind: SkinButtonKind.secondary,
                          height: 44,
                          fontSize: 16,
                          onPressed: onClose,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SkinButton(
                          key: const Key('pot-hint-go'),
                          label: 'Xem chậu',
                          height: 44,
                          fontSize: 16,
                          onPressed: () {
                            onClose();
                            s.openPotShop(group: 'chomSao');
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Dark wash with a rounded hole over [hole] and a gold rim around it.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.hole);

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(hole, const Radius.circular(18));
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rrect);
    canvas.drawPath(path, Paint()..color = const Color(0xA62E3A2C));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.accentBase,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole;
}

/// Gold triangle that points down at the tab (drawn, no icon font needed).
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.accentBase);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}
