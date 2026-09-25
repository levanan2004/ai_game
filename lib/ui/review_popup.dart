import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Popup right after delivery (spec_danh_gia.md §1).
class ReviewPopup extends StatefulWidget {
  const ReviewPopup({
    super.key,
    required this.result,
    required this.session,
    required this.onClose,
  });

  final DeliveryResult result;
  final ShopSession session;
  final VoidCallback onClose;

  @override
  State<ReviewPopup> createState() => _ReviewPopupState();
}

class _ReviewPopupState extends State<ReviewPopup>
    with SingleTickerProviderStateMixin {
  /// popupIn (320 ms) + 5 stars 80 ms apart, each popping in over `base`.
  static const _starGap = 80;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds:
          AppMotion.slow.inMilliseconds +
          _starGap * 5 +
          AppMotion.base.inMilliseconds,
    ),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _interval(int startMs, int lengthMs, Curve curve) {
    final total = _c.duration!.inMilliseconds;
    final t = ((_c.value * total - startMs) / lengthMs).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final e = widget.session.e;
    final occ = e.occasion(r.review.occasionId);
    final stars = r.review.stars;
    final slow = AppMotion.slow.inMilliseconds;
    final base = AppMotion.base.inMilliseconds;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onClose,
      child: ColoredBox(
        color: AppColors.bgOverlay,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final inT = _interval(0, slow, Curves.easeOutBack);
            final fade = _interval(0, slow, Curves.linear);
            final bubble = _interval(slow + _starGap * 5, base, Curves.easeOutCubic);
            return Stack(
              children: [
                Positioned(
                  left: 32,
                  top: 150,
                  width: 296,
                  height: 300,
                  child: Opacity(
                    opacity: fade,
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * inT,
                      child: GestureDetector(
                        onTap: () {},
                        child: _card(r, occ.id, occ.nameVi, stars, bubble),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 48,
                  top: 464,
                  width: 264,
                  height: 52,
                  child: Opacity(
                    opacity: fade,
                    child: ChunkyButton(
                      key: const Key('popup-continue'),
                      label: 'Tiếp tục',
                      onPressed: widget.onClose,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _card(
    DeliveryResult r,
    String occId,
    String occName,
    int stars,
    double bubble,
  ) {
    final slow = AppMotion.slow.inMilliseconds;
    final base = AppMotion.base.inMilliseconds;
    final tip = r.payment.tipTotal;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: AppColors.surfaceBorderStrong,
            offset: Offset(0, AppSize.shadowOffset),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 148 - 28,
            top: 44 - 28,
            child: Avatar(
              name: r.customer.name,
              avatarId: r.customer.avatarId,
              radius: 28,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 76,
            child: Text(
              r.customer.name,
              textAlign: TextAlign.center,
              style: AppText.title(size: 18, weight: 800),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 102,
            child: Center(
              child: OccasionChip(occasionId: occId, label: occName),
            ),
          ),
          for (var i = 0; i < 5; i++)
            Positioned(
              left: 148 - 60 + i * 30 - 13,
              top: 146 - 13,
              child: Builder(
                builder: (context) {
                  final t = _interval(slow + i * _starGap, base, Curves.easeOutBack);
                  final lit = i < stars;
                  return Transform.scale(
                    scale: lit ? 0.4 + 0.6 * t : 1,
                    child: StarIcon(radius: 13, fill: lit && t > 0 ? 1 : 0),
                  );
                },
              ),
            ),
          Positioned(
            left: 16,
            top: 170,
            width: 264,
            height: 52,
            child: Opacity(
              opacity: bubble,
              child: CustomPaint(
                painter: _BubblePainter(),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      r.review.comment,
                      key: const Key('popup-comment'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 12, weight: 700),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: 231,
            child: _moneyRow('Tiền hoa', formatSignedK(r.payment.pay), AppColors.textPrimary),
          ),
          if (tip > 0)
            Positioned(
              left: 24,
              right: 24,
              top: 249,
              child: _moneyRow('Tiền boa', formatSignedK(tip), AppColors.statusSuccess),
            ),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, String value, Color color) => Row(
    children: [
      Text(label, style: AppText.body(size: 12, weight: 700, color: AppColors.textSecondary)),
      const Spacer(),
      Text(value, style: AppText.number(size: 14, color: color)),
    ],
  );
}

class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.surfaceSunken;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(AppRadius.md)),
      p,
    );
    final cx = size.width / 2;
    final tail = Path()
      ..moveTo(cx - 8, 0)
      ..lineTo(cx + 8, 0)
      ..lineTo(cx, -8)
      ..close();
    canvas.drawPath(tail, p);
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => false;
}
