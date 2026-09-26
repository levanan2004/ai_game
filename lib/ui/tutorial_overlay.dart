import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';

/// Widgets the first-day tutorial points at (spec_popup_va_mo_dau.md §6).
/// Screens wrap the element with `KeyedSubtree(key: TutorialTargets.x)`.
abstract final class TutorialTargets {
  static final rosePlus = GlobalKey(debugLabel: 'tut-rose-plus');
  static final marketBuy = GlobalKey(debugLabel: 'tut-market-buy');
  static final openButton = GlobalKey(debugLabel: 'tut-open');
  static final ticket = GlobalKey(debugLabel: 'tut-ticket');
  static final tray = GlobalKey(debugLabel: 'tut-tray');
  static final deliver = GlobalKey(debugLabel: 'tut-deliver');
  static final wrapHold = GlobalKey(debugLabel: 'tut-wrap-hold');
  static final popupStars = GlobalKey(debugLabel: 'tut-stars');
  static final popupContinue = GlobalKey(debugLabel: 'tut-continue');
}

/// One tutorial step: short title and the spec's line.
/// TODO(Phú): the spec gives the full line per step but a title only for
/// step 1 ("Chào chủ tiệm mới!"); titles 2 to 8 are placeholders.
class TutorialStepText {
  const TutorialStepText(this.title, this.body);
  final String title;
  final String body;
}

const tutorialTexts = <TutorialStepText>[
  TutorialStepText(
    'Chào chủ tiệm mới!',
    'Bấm dấu + để mua một bó hoa hồng nhé.',
  ),
  TutorialStepText(
    'Mang hoa về tiệm',
    'Mua đủ rồi thì bấm để mang hoa về tiệm.',
  ),
  TutorialStepText('Mở cửa', 'Mở cửa đón khách thôi!'),
  TutorialStepText(
    'Khách đầu tiên',
    'Khách cần hoa gì thì ghi trong bong bóng. Chạm vào khách để bó hoa.',
  ),
  TutorialStepText(
    'Phiếu khách',
    'Đây là yêu cầu của khách: loài hoa, số cành, giấy và nơ.',
  ),
  TutorialStepText(
    'Bó hoa',
    'Chạm thẻ hoa để thêm cành, rồi chọn giấy và nơ cho đúng phiếu.',
  ),
  TutorialStepText(
    'Gói hoa',
    'Giữ nút, thả tay khi vòng nằm trong vùng xanh để được boa thêm.',
  ),
  TutorialStepText(
    'Đánh giá',
    'Bó càng đúng yêu cầu thì càng nhiều sao và tiền boa. Chúc tiệm đắt khách!',
  ),
];

/// Spotlight overlay: dims the screen, cuts a rounded hole around the
/// target with a pulsing `accent.base` ring, lets taps through only inside
/// the hole, and shows the dialogue card on the other half of the screen.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({super.key, required this.session});

  final ShopSession session;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Rect? _hole;
  List<Rect> _pass = const [];
  double _pulse = 0;

  /// Step 4 points at the Flame scene: first queue slot and its bubble
  /// (frame coordinates from shop_scene.dart).
  static const _firstCustomerRect = Rect.fromLTRB(26, 160, 282, 276);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Rect? _rectOf(GlobalKey key) {
    final target = key.currentContext?.findRenderObject();
    final me = context.findRenderObject();
    if (target is! RenderBox || me is! RenderBox || !target.attached) {
      return null;
    }
    if (!target.hasSize || !me.hasSize) return null;
    final tl = me.globalToLocal(target.localToGlobal(Offset.zero));
    final br = me.globalToLocal(
      target.localToGlobal(target.size.bottomRight(Offset.zero)),
    );
    return Rect.fromPoints(tl, br);
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final s = widget.session;
    Rect? hole;
    var pass = <Rect>[];
    switch (s.tutorialStep) {
      case 1:
        hole = _rectOf(TutorialTargets.rosePlus);
      case 2:
        hole = _rectOf(TutorialTargets.marketBuy);
      case 3:
        hole = _rectOf(TutorialTargets.openButton);
      case 4:
        final c = s.nextForPlayer;
        hole = c == null ? null : _firstCustomerRect;
      case 5:
        hole = _rectOf(TutorialTargets.ticket);
      case 6:
        hole = _rectOf(TutorialTargets.tray);
      case 7:
        hole = _rectOf(
          s.wrapping ? TutorialTargets.wrapHold : TutorialTargets.deliver,
        );
      case 8:
        hole = _rectOf(TutorialTargets.popupStars);
        final cont = _rectOf(TutorialTargets.popupContinue);
        if (cont != null) pass = [cont];
    }
    hole = hole?.inflate(6);
    final pulse = (elapsed.inMilliseconds % 1000) / 1000;
    setState(() {
      _hole = hole;
      _pass = [?hole, ...pass];
      _pulse = pulse;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final step = s.tutorialStep;
    if (step <= 0 || step > tutorialTexts.length) {
      return const SizedBox.shrink();
    }
    final hole = _hole;
    // Step 5 waits for a tap on the card; the ticket itself is only shown.
    final holes = step == 5 ? <Rect>[] : _pass;
    final cardTop = hole != null && hole.center.dy < 320 ? 330.0 : 64.0;
    return Stack(
      children: [
        Positioned.fill(child: _HoleBarrier(holes: holes)),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _SpotlightPainter(hole, _pulse)),
          ),
        ),
        Positioned(
          left: 24,
          top: cardTop,
          width: 312,
          height: 104,
          child: GestureDetector(
            key: const Key('tutorial-card'),
            behavior: HitTestBehavior.opaque,
            onTap: s.tutorialCardTapped,
            child: TutorialCard(step: step),
          ),
        ),
        Positioned(
          right: 24,
          top: cardTop + 116,
          child: GestureDetector(
            key: const Key('tutorial-skip'),
            behavior: HitTestBehavior.opaque,
            onTap: s.skipTutorial,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                'Bỏ qua',
                style: AppText.body(
                  size: 13,
                  weight: 800,
                  color: AppColors.textInverse,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Xem hướng dẫn" from the pause popup: the same cards, no spotlight and
/// nothing to do; tap the card for the next step.
class TutorialViewer extends StatelessWidget {
  const TutorialViewer({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final step = s.tutorialViewStep;
    if (step <= 0 || step > tutorialTexts.length) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: s.nextTutorialView,
      child: ColoredBox(
        color: _dim,
        child: Stack(
          children: [
            Positioned(
              left: 24,
              top: 268,
              width: 312,
              height: 104,
              child: GestureDetector(
                key: const Key('tutorial-view-card'),
                behavior: HitTestBehavior.opaque,
                onTap: s.nextTutorialView,
                child: TutorialCard(step: step),
              ),
            ),
            Positioned(
              right: 24,
              top: 384,
              child: GestureDetector(
                key: const Key('tutorial-view-close'),
                behavior: HitTestBehavior.opaque,
                onTap: s.closeTutorialView,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    'Bỏ qua',
                    style: AppText.body(
                      size: 13,
                      weight: 800,
                      color: AppColors.textInverse,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `bg.overlay`, a bit darker than popups (spec §6).
const _dim = Color(0x9943392F);

/// Dialogue card 312×104: shop owner, title, line, "n/8".
class TutorialCard extends StatelessWidget {
  const TutorialCard({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final t = tutorialTexts[step - 1];
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
        children: [
          Positioned(
            left: 10,
            top: 22,
            child: ArtImage(Art.upgrade('staff'), size: 60),
          ),
          Positioned(
            left: 78,
            right: 14,
            top: 12,
            child: Text(t.title, style: AppText.heading(size: 15)),
          ),
          Positioned(
            left: 78,
            right: 14,
            top: 36,
            child: Text(
              t.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 12, weight: 700),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 8,
            child: Text(
              '$step/${tutorialTexts.length}',
              style: AppText.caption(size: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.hole, this.pulse);

  final Rect? hole;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final h = hole;
    if (h == null) {
      canvas.drawPath(full, Paint()..color = _dim);
      return;
    }
    final rr = RRect.fromRectAndRadius(h, const Radius.circular(AppRadius.md));
    final dim = Path.combine(
      PathOperation.difference,
      full,
      Path()..addRRect(rr),
    );
    canvas.drawPath(dim, Paint()..color = _dim);
    // Gentle blink of the 3 px ring.
    final a = 0.55 + 0.45 * (1 - (2 * pulse - 1).abs());
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.accentBase.withValues(alpha: a),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.pulse != pulse;
}

/// Absorbs every tap except inside [holes], where the hit test fails so the
/// widgets underneath (the spotlighted element) get the tap.
class _HoleBarrier extends LeafRenderObjectWidget {
  const _HoleBarrier({required this.holes});

  final List<Rect> holes;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHoleBarrier(holes);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHoleBarrier renderObject,
  ) {
    renderObject.holes = holes;
  }
}

class _RenderHoleBarrier extends RenderBox {
  _RenderHoleBarrier(this.holes);

  List<Rect> holes;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    for (final h in holes) {
      if (h.contains(position)) return false;
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}
