import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../logic/bouquet.dart';
import '../logic/delivery.dart';
import '../logic/format.dart';
import '../logic/match_scoring.dart';
import '../logic/payment.dart';
import '../logic/shop_session.dart';
import '../theme/mock_palette.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'paint.dart';
import 'review_popup.dart';
import 'tutorial_overlay.dart';
import 'wrap_minigame.dart';

/// Bàn bó hoa (spec_ban_bo_hoa.md).
class BouquetTableScreen extends StatefulWidget {
  const BouquetTableScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<BouquetTableScreen> createState() => _BouquetTableScreenState();
}

enum _Tab { flowers, paper, ribbon }

class _BouquetTableScreenState extends State<BouquetTableScreen> {
  _Tab _tab = _Tab.flowers;
  String? _infoFor;
  bool _showWrap = false;

  ShopSession get s => widget.session;

  WrapZone? _zone;

  void _deliver() {
    final zone = s.beginWrap();
    if (zone == null) return;
    setState(() {
      _zone = zone;
      _showWrap = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = s.tableCustomer;
    final delivery = s.lastDelivery;
    return OpaqueScreen(
      color: AppColors.bgShop,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            width: 360,
            height: 48,
            child: ColoredBox(color: AppColors.bgBase),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: TopBar(session: s, showPause: true),
          ),
          const Positioned(
            left: 0,
            top: 48,
            child: AwningStrip(height: 16, scalloped: true),
          ),
          if (s.tableOrder != null)
            Positioned(
              left: 12,
              top: 66,
              width: 336,
              height: 116,
              child: _OnlineTicket(session: s, order: s.tableOrder!),
            )
          else if (c != null)
            Positioned(
              left: 12,
              top: 66,
              width: 336,
              height: 116,
              child: KeyedSubtree(
                key: TutorialTargets.ticket,
                child: _CustomerTicket(session: s, customer: c),
              ),
            ),
          Positioned(
            left: 12,
            top: 186,
            width: 336,
            height: 236,
            child: _BouquetFrame(session: s),
          ),
          Positioned(
            left: 4,
            top: 428,
            width: 352,
            height: 152,
            child: IgnorePointer(
              child: KeyedSubtree(
                key: TutorialTargets.tray,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 478,
            width: 360,
            height: 100,
            child: _tray(),
          ),
          // Tabs sit above the tray so a tap on "Giấy" cannot land on a
          // card (or pass through to the shop queue) underneath.
          for (final t in _Tab.values)
            Positioned(
              left: 12 + t.index * 114,
              top: 432,
              width: 108,
              height: 36,
              child: _TabButton(
                key: Key('tab-${t.name}'),
                label: const ['Hoa', 'Giấy', 'Nơ'][t.index],
                active: _tab == t,
                onTap: () => setState(() => _tab = t),
              ),
            ),
          if (_infoFor != null) _infoPopup(_infoFor!),
          Positioned(
            left: 12,
            top: 588,
            width: 104,
            height: 48,
            child: ChunkyButton(
              label: 'Làm lại',
              kind: ButtonKind.ghost,
              radius: 14,
              fontSize: 16,
              weight: 700,
              textColor: AppColors.textSecondary,
              onPressed: s.resetDraft,
            ),
          ),
          Positioned(
            left: 124,
            top: 588,
            width: 224,
            height: 48,
            child: KeyedSubtree(
              key: TutorialTargets.deliver,
              child: ChunkyButton(
                key: const Key('deliver-button'),
                label: s.tableOrder != null
                    ? 'Gói & chuyển shipper'
                    : 'Gói & giao hoa',
                radius: 14,
                enabled: s.canDeliver && !s.wrapping,
                onPressed: _deliver,
              ),
            ),
          ),
          if (_showWrap && delivery == null && _zone != null)
            Positioned.fill(
              child: WrapMiniGame(
                session: s,
                zone: _zone!,
                onDone: () {
                  if (!mounted) return;
                  setState(() => _showWrap = false);
                },
              ),
            ),
          if (delivery != null)
            Positioned.fill(
              child: ReviewPopup(
                result: delivery,
                session: s,
                onClose: s.closeDeliveryPopup,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tray() {
    final cards = <Widget>[];
    switch (_tab) {
      case _Tab.flowers:
        for (final f in s.unlockedFlowers) {
          final n = s.stockAvailable(f.id, forOrder: s.tableOrder);
          cards.add(
            _TrayCard(
              key: Key('tray-${f.id}'),
              name: f.nameVi,
              subtitle: 'còn $n',
              icon: FlowerIcon(
                flowerId: f.id,
                radius: 18,
                opacity: n > 0 ? 1 : 0.4,
              ),
              enabled: n > 0,
              freshness: n > 0 ? s.freshnessFraction(f.id) : 0,
              showFreshness: true,
              onTap: () => s.addStem(f.id),
              onLongPress: (v) => setState(() => _infoFor = v ? f.id : null),
            ),
          );
        }
      case _Tab.paper:
        for (final p in s.unlockedPapers) {
          cards.add(
            _TrayCard(
              key: Key('tray-${p.id}'),
              name: p.nameVi,
              icon: ArtImage(
                Art.paper(p.id),
                size: 40,
                fallback: const _PaperIcon(),
              ),
              selected: s.draft.paperId == p.id,
              onTap: () => s.selectPaper(p.id),
            ),
          );
        }
      case _Tab.ribbon:
        for (final r in s.unlockedRibbons) {
          cards.add(
            _TrayCard(
              key: Key('tray-${r.id}'),
              name: r.nameVi,
              icon: ArtImage(
                Art.ribbon(r.id),
                size: 40,
                fallback: const _RibbonIcon(),
              ),
              selected: s.draft.ribbonId == r.id,
              onTap: () => s.selectRibbon(r.id),
            ),
          );
        }
    }
    return Stack(
      children: [
        ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 12, right: 24),
          itemCount: cards.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => cards[i],
        ),
        if (cards.length > 4)
          Positioned(
            right: 4,
            top: 30,
            child: IgnorePointer(
              child: Text(
                '›',
                style: AppText.title(
                  size: 28,
                  color: AppColors.surfaceBorderStrong,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoPopup(String flowerId) {
    final f = s.e.flower(flowerId);
    final batch = s.oldestBatch(flowerId);
    return Positioned(
      left: 60,
      top: 380,
      width: 240,
      child: IgnorePointer(
        child: CardBox(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(f.nameVi, style: AppText.heading()),
              Text(
                'Còn tươi ${batch?.freshnessLeft ?? 0} ngày',
                style: AppText.caption(),
              ),
              Text('Giá nhập ${formatK(f.buyPrice)}', style: AppText.caption()),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Pointer-down, not a tap recognizer: the tab switches even if a parent
    // scrollable or the shop scene also sees the pointer.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onTap(),
      child: AnimatedContainer(
        duration: AppMotion.base,
        decoration: BoxDecoration(
          color: active ? AppColors.primaryBase : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: active
              ? null
              : Border.all(
                  color: AppColors.surfaceBorder,
                  width: AppBorder.thin,
                ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.button(
            size: 15,
            color: active ? AppColors.onPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TrayCard extends StatelessWidget {
  const _TrayCard({
    super.key,
    required this.name,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
    this.selected = false,
    this.freshness = 0,
    this.showFreshness = false,
    this.onLongPress,
  });

  final String name;
  final String? subtitle;
  final Widget icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool selected;
  final double freshness;
  final bool showFreshness;
  final void Function(bool down)? onLongPress;

  @override
  Widget build(BuildContext context) {
    final textColor = enabled ? AppColors.textPrimary : AppColors.textDisabled;
    final card = SizedBox(
      width: AppSize.trayCardW,
      height: AppSize.trayCardH,
      child: CardBox(
        radius: AppRadius.md,
        borderColor: selected ? AppColors.primaryBase : AppColors.surfaceBorder,
        borderWidth: selected ? AppBorder.thick : AppBorder.thin,
        child: Stack(
          children: [
            Positioned(left: 0, right: 0, top: 8, child: Center(child: icon)),
            Positioned(
              left: 4,
              right: 4,
              top: 50,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  style: AppText.body(size: 12, weight: 800, color: textColor),
                ),
              ),
            ),
            if (subtitle != null)
              Positioned(
                left: 0,
                right: 0,
                top: 65,
                child: Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: AppText.caption(
                    size: 10,
                    color: enabled
                        ? AppColors.textSecondary
                        : AppColors.textDisabled,
                  ),
                ),
              ),
            if (showFreshness)
              Positioned(
                left: 9,
                top: 80,
                child: ProgressBar(
                  width: 52,
                  height: AppSize.freshnessBar,
                  fraction: freshness,
                  color: freshnessColor(freshness),
                ),
              ),
          ],
        ),
      ),
    );
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              (t) => t.onTap = enabled ? onTap : null,
            ),
        if (onLongPress != null)
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: const Duration(milliseconds: 400),
                ),
                (l) => l
                  ..onLongPressStart = ((_) => onLongPress!(true))
                  ..onLongPressEnd = ((_) => onLongPress!(false))
                  ..onLongPressCancel = (() => onLongPress!(false)),
              ),
      },
      child: card,
    );
  }
}

class _PaperIcon extends StatelessWidget {
  const _PaperIcon();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(36, 36), painter: _PaperPainter(18));
}

class _PaperPainter extends CustomPainter {
  _PaperPainter(this.half);

  final double half;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.1, size.height * 0.1)
      ..lineTo(w * 0.9, size.height * 0.1)
      ..lineTo(w * 0.7, size.height * 0.95)
      ..lineTo(w * 0.3, size.height * 0.95)
      ..close();
    canvas.drawPath(path, Paint()..color = MockPalette.paperCream);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.surfaceBorderStrong,
    );
  }

  @override
  bool shouldRepaint(_PaperPainter oldDelegate) => false;
}

class _RibbonIcon extends StatelessWidget {
  const _RibbonIcon();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(36, 36), painter: _RibbonPainter());
}

class _RibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()..color = AppColors.primaryBase;
    final left = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx - 14, c.dy - 9)
      ..lineTo(c.dx - 14, c.dy + 9)
      ..close();
    final right = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx + 14, c.dy - 9)
      ..lineTo(c.dx + 14, c.dy + 9)
      ..close();
    canvas.drawPath(left, p);
    canvas.drawPath(right, p);
    canvas.drawCircle(c, 4, Paint()..color = AppColors.primaryPressed);
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) => false;
}

/// Online order ticket: gift box instead of the patience ring.
class _OnlineTicket extends StatelessWidget {
  const _OnlineTicket({required this.session, required this.order});

  final ShopSession session;
  final OnlineOrder order;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final o = order;
    final e = s.e;
    final when = 'Giao trước ${deadlineClock(e, o.deadline)}';
    return CardBox(
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.card_giftcard, size: 40, color: AppColors.primaryBase),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đơn online', style: AppText.title(size: 15, weight: 800)),
                Text(o.line, maxLines: 2, style: AppText.body(size: 12)),
                Text(when, style: AppText.caption(size: 11, weight: 800)),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Customer ticket: patience ring avatar, occasion, request line, chips.
class _CustomerTicket extends StatefulWidget {
  const _CustomerTicket({required this.session, required this.customer});

  final ShopSession session;
  final Customer customer;

  @override
  State<_CustomerTicket> createState() => _CustomerTicketState();
}

class _CustomerTicketState extends State<_CustomerTicket>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final c = widget.customer;
    final e = s.e;
    final occ = e.occasion(c.request.occasionId);
    final f = c.patienceFraction;
    final warn = f < e.patienceWarningAt;
    final chips = <(String, Color)>[
      for (final entry in c.request.stems.entries)
        (
          '${entry.value} ${e.flower(entry.key).nameVi}',
          MockPalette.petalsFor(entry.key).$1,
        ),
      if (c.request.fillerId != null)
        (
          '${c.request.fillerCount} ${e.flower(c.request.fillerId!).nameVi}',
          MockPalette.petalsFor(c.request.fillerId!).$1,
        ),
      (e.paper(c.request.paperId).nameVi, MockPalette.paperCream),
      (e.ribbon(c.request.ribbonId).nameVi, AppColors.primarySoft),
    ];
    return CardBox(
      child: Stack(
        children: [
          Positioned(
            left: 10,
            top: 14,
            width: 60,
            height: 60,
            child: AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                // Shake briefly every 2 s under the warning threshold.
                final t = _shake.value;
                final dx = warn && t < 0.2
                    ? math.sin(t * 5 * 2 * math.pi) * 3
                    : 0.0;
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: CustomPaint(
                painter: _RingPainter(f, patienceColor(f, e.patienceWarningAt)),
                child: Center(
                  child: Avatar(
                    name: c.name,
                    avatarId: c.avatarId,
                    radius: 24,
                    initialOnly: false,
                    fontSize: 13,
                    textColor: AppColors.primaryPressed,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            width: 80,
            top: 80,
            child: Text(
              'Kiên nhẫn',
              textAlign: TextAlign.center,
              style: AppText.caption(size: 10),
            ),
          ),
          Positioned(
            left: 82,
            top: 10,
            child: OccasionChip(
              occasionId: occ.id,
              label: occ.nameVi,
              height: 22,
              fontSize: 11,
            ),
          ),
          Positioned(
            left: 82,
            top: 36,
            width: 242,
            child: Text(
              '“${c.requestLine}”',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 13, weight: 700),
            ),
          ),
          Positioned(
            left: 82,
            top: 79,
            width: 246,
            height: 24,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  for (final (label, color) in chips)
                    Container(
                      height: 22,
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: AppColors.surfaceBorder,
                          width: AppBorder.thin,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: AppText.caption(
                          size: 10,
                          weight: 800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2.5, 2.5, size.width - 5, size.height - 5);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawOval(rect, stroke..color = AppColors.freshnessTrack);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      stroke
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// Bouquet preview + match meter.
class _BouquetFrame extends StatelessWidget {
  const _BouquetFrame({required this.session});

  final ShopSession session;

  static const _center = Offset(168, 74);
  static const _neck = Offset(168, 146);

  /// Stem positions around the centre: 1, then a ring of 6, then 8.
  static Offset slot(int i) {
    if (i == 0) return _center;
    if (i <= 6) {
      final a = -math.pi / 2 + (i - 1) * math.pi / 3;
      return _center + Offset(math.cos(a), math.sin(a)) * 22;
    }
    final a = -math.pi / 2 + (i - 7) * math.pi / 4 + math.pi / 8;
    return _center + Offset(math.cos(a), math.sin(a) * 0.8) * 42;
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    final b = s.draft;
    final match = s.draftMatch;
    final e = s.e;
    return CardBox(
      color: AppColors.bgBase,
      shadow: false,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 12,
            top: 8,
            child: Text(
              'Bó hoa của bạn',
              style: AppText.title(size: 14, color: AppColors.textSecondary),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _BouquetBackPainter(b)),
            ),
          ),
          for (var i = 0; i < b.stems.length; i++)
            _StemWidget(
              key: ValueKey(b.stems[i].uid),
              stem: b.stems[i],
              at: slot(i),
              filler: e.isFiller(b.stems[i].flowerId),
              onTap: () => s.removeStem(b.stems[i].uid),
            ),
          if (b.ribbonId != null)
            Positioned(
              left: _neck.dx - 18,
              top: _neck.dy - 18,
              child: IgnorePointer(
                child: ArtImage(
                  Art.ribbon(b.ribbonId!),
                  size: 36,
                  fallback: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBase,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          if (b.isEmpty)
            Positioned(
              left: 0,
              right: 0,
              top: 100,
              child: Text(
                'Chạm hoa bên dưới để bắt đầu bó',
                textAlign: TextAlign.center,
                style: AppText.caption(),
              ),
            ),
          Positioned(
            left: 12,
            top: 210,
            child: Text(
              'Độ khớp',
              style: AppText.caption(size: 11, weight: 800),
            ),
          ),
          Positioned(
            left: 68,
            top: 210,
            width: 200,
            height: 16,
            child: CustomPaint(
              painter: _MatchPainter(
                match?.score ?? 0,
                match?.tier ?? Tier.unhappy,
                e.okayThreshold,
                e.greatThreshold,
              ),
            ),
          ),
          Positioned(
            left: 280,
            top: 211,
            child: Text(
              '${((match?.score ?? 0) * 100).round()}%',
              key: const Key('match-percent'),
              style: AppText.number(size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _StemWidget extends StatelessWidget {
  const _StemWidget({
    super.key,
    required this.stem,
    required this.at,
    required this.filler,
    required this.onTap,
  });

  final Stem stem;
  final Offset at;
  final bool filler;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = filler ? 13.0 : 22.0;
    final wilting = stem.freshnessLeft <= 1;
    final drawn = CustomPaint(
      painter: _StemHeadPainter(
        stem.flowerId,
        filler ? 9 : 20,
        filler,
        wilting,
      ),
    );
    return Positioned(
      left: at.dx - r - 2,
      top: at.dy - r - 2,
      width: r * 2 + 4,
      height: r * 2 + 4,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: AppMotion.base,
          curve: Curves.easeOutBack,
          builder: (context, v, child) =>
              Transform.scale(scale: v, child: child),
          child: Stack(
            children: [
              ArtImage(
                Art.flower(stem.flowerId),
                size: r * 2 + 4,
                opacity: wilting ? 0.6 : 1,
                fallback: drawn,
              ),
              if (wilting)
                // Small wilted marker (economy `_wiltNote`).
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.freshnessWilting,
                      shape: BoxShape.circle,
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

class _StemHeadPainter extends CustomPainter {
  _StemHeadPainter(this.id, this.r, this.filler, this.wilting);

  final String id;
  final double r;
  final bool filler;
  final bool wilting;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (filler) {
      paintFillerCluster(canvas, c, r * 0.7);
    } else {
      paintFlower(canvas, c, r, id, opacity: wilting ? 0.6 : 1);
    }
    if (wilting) {
      // Small wilted marker (economy `_wiltNote`).
      canvas.drawCircle(
        c + Offset(r * 0.7, -r * 0.7),
        3,
        Paint()..color = AppColors.freshnessWilting,
      );
    }
  }

  @override
  bool shouldRepaint(_StemHeadPainter old) =>
      old.id != id || old.wilting != wilting;
}

/// Wrapping paper (behind) and green stalks towards the neck.
class _BouquetBackPainter extends CustomPainter {
  _BouquetBackPainter(this.b) : count = b.stems.length, paper = b.paperId;

  final Bouquet b;
  final int count;
  final String? paper;

  @override
  void paint(Canvas canvas, Size size) {
    if (paper != null) {
      final path = Path()
        ..moveTo(118, 114)
        ..lineTo(218, 114)
        ..lineTo(188, 209)
        ..lineTo(148, 209)
        ..close();
      canvas.drawPath(path, Paint()..color = MockPalette.paperCream);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.surfaceBorderStrong,
      );
    }
    final stalk = Paint()
      ..color = AppColors.secondaryPressed
      ..strokeWidth = 2;
    for (var i = 0; i < count; i++) {
      canvas.drawLine(_BouquetFrame.slot(i), _BouquetFrame._neck, stalk);
    }
  }

  @override
  bool shouldRepaint(_BouquetBackPainter old) =>
      old.count != count || old.paper != paper;
}

class _MatchPainter extends CustomPainter {
  _MatchPainter(this.score, this.tier, this.okay, this.great);

  final double score;
  final Tier tier;
  final double okay;
  final double great;

  @override
  void paint(Canvas canvas, Size size) {
    const barTop = 2.0;
    const h = 12.0;
    final track = RRect.fromLTRBR(
      0,
      barTop,
      size.width,
      barTop + h,
      const Radius.circular(6),
    );
    canvas.drawRRect(track, Paint()..color = AppColors.freshnessTrack);
    if (score > 0) {
      final color = switch (tier) {
        Tier.great => AppColors.matchPerfect,
        Tier.okay => AppColors.matchOk,
        Tier.unhappy => AppColors.matchLow,
      };
      canvas.drawRRect(
        RRect.fromLTRBR(
          0,
          barTop,
          math.max(h, size.width * score),
          barTop + h,
          const Radius.circular(6),
        ),
        Paint()..color = color,
      );
    }
    final tick = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 1;
    for (final t in [okay, great]) {
      canvas.drawLine(
        Offset(size.width * t, 0),
        Offset(size.width * t, 16),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(_MatchPainter old) =>
      old.score != score || old.tier != tier;
}
