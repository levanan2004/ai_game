import 'package:flutter/material.dart';

import '../data/wilting.dart';
import '../logic/format.dart';
import '../logic/price_format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'game_toast.dart';
import 'popups.dart' show PopupFrame;
import 'upgrades_screen.dart' show DisabledPrice, PriceButton;

// Hoa sắp héo views (Phú's spec_hoa_sap_heo.md, Nhất's strings).

/// Coral of the spec's badges and new prices.
const wiltCoral = Color(0xFFE26D5A);

WiltingText _t(ShopSession s) => s.data.wilting.text;

/// Bottom sheet frame: dim, [height] tall, top corners 20dp (spec §3).
class WiltSheet extends StatelessWidget {
  const WiltSheet({
    super.key,
    required this.height,
    required this.child,
    this.onClose,
  });

  final double height;
  final Widget child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: ColoredBox(
        color: AppColors.bgOverlay,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              height: height,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Chọn cành để phơi" at the summary (spec §3): 70% high, 4 columns,
/// 64dp cells on the 360dp frame.
class DryPickSheet extends StatefulWidget {
  const DryPickSheet({super.key, required this.session, required this.onClose});

  final ShopSession session;
  final VoidCallback onClose;

  static const cell = 64.0;

  @override
  State<DryPickSheet> createState() => _DryPickSheetState();
}

class _DryPickSheetState extends State<DryPickSheet> {
  final Map<String, int> _picks = {};

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final t = _t(s);
    final d = s.data.wilting.drying;
    final all = lastDayStems(s);
    final can = dryCandidates(s);
    var stems = 0;
    var dried = 0;
    for (final p in _picks.entries) {
      stems += p.value;
      dried += dryYield(s, p.key, p.value);
    }
    final used = driedStorageUsed(s);
    final room = d.storageCap - used;
    final over = dried > room;
    var canYield = 0;
    for (final c in can.entries) {
      canYield += dryYield(s, c.key, c.value);
    }
    return WiltSheet(
      key: const Key('dry-pick-sheet'),
      height: 640 * 0.7,
      onClose: widget.onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.get('dried', 'pickTitle'), style: AppText.heading(size: 18)),
          const SizedBox(height: 4),
          Text(t.get('dried', 'pickHint'), style: AppText.caption(size: 11)),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: (328 - 4 * DryPickSheet.cell) / 3,
              children: [
                for (final e in all.entries)
                  _PickCell(
                    key: Key('dry-cell-${e.key}'),
                    flowerId: e.key,
                    count: e.value,
                    selected: (_picks[e.key] ?? 0) > 0,
                    enabled: can.containsKey(e.key),
                    disabledHint: t.get('dried', 'pickNotDryable'),
                    onTap: () => setState(() {
                      if (_picks.remove(e.key) == null) {
                        _picks[e.key] = can[e.key]!;
                      }
                    }),
                  ),
              ],
            ),
          ),
          if (stems > 0) ...[
            Text(
              t.get('dried', 'pickCount', {
                'n': stems,
                'tien': vndLabel(stems * d.dryingCostPerStem),
              }),
              key: const Key('dry-pick-count'),
              style: AppText.body(size: 12, weight: 700),
            ),
            Text(
              t.get('dried', 'pickYield', {'n': dried}),
              key: const Key('dry-pick-yield'),
              style: AppText.caption(size: 11),
            ),
          ],
          if (room > 0 && room < canYield)
            Text(
              t.get('dried', 'storageNearlyFull', {'n': room}),
              key: const Key('dry-nearly-full'),
              style: AppText.caption(size: 11, color: wiltCoral),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: Row(
              children: [
                Text(
                  t.get('dried', 'storageCounter', {
                    'dang': used,
                    'toiDa': d.storageCap,
                  }),
                  key: const Key('dry-storage'),
                  style: AppText.body(size: 12, weight: 700),
                ),
                const Spacer(),
                SizedBox(
                  width: 92,
                  child: ChunkyButton(
                    key: const Key('dry-skip'),
                    label: t.get('dried', 'skipButton'),
                    kind: ButtonKind.ghost,
                    fontSize: 14,
                    height: 48,
                    onPressed: widget.onClose,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 112,
                  child: ChunkyButton(
                    key: const Key('dry-go'),
                    label: t.get('dried', 'dryButton'),
                    fontSize: 15,
                    height: 48,
                    enabled: stems > 0 && !over,
                    disabledHint: over
                        ? t.get('dried', 'storageFull', {'toiDa': d.storageCap})
                        : null,
                    onPressed: () {
                      if (sendToDry(s, Map.of(_picks))) widget.onClose();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickCell extends StatelessWidget {
  const _PickCell({
    super.key,
    required this.flowerId,
    required this.count,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.disabledHint,
  });

  final String disabledHint;
  final String flowerId;
  final int count;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cell = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: DryPickSheet.cell,
          height: DryPickSheet.cell,
          decoration: BoxDecoration(
            color: AppColors.surfaceSunken,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: selected
                ? Border.all(color: AppColors.primaryBase, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: ArtImage(Art.flower(flowerId), size: 40),
        ),
        Positioned(
          right: 4,
          bottom: 2,
          child: Text('$count', style: AppText.number(size: 12)),
        ),
        if (selected)
          const Positioned(
            right: -4,
            top: -4,
            child: Icon(
              Icons.check_circle,
              size: 18,
              color: AppColors.primaryBase,
            ),
          ),
      ],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : () => showGameToast(context, disabledHint),
      child: enabled ? cell : Opacity(opacity: 0.4, child: cell),
    );
  }
}

/// Small round count badge (spec: 20dp, white 12 bold).
class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: AppText.body(size: 12, weight: 800, color: Colors.white),
      ),
    );
  }
}

Widget _art(String path, double w, double h) => Image.asset(
  path,
  width: w,
  height: h,
  fit: BoxFit.contain,
  errorBuilder: (_, _, _) => SizedBox(width: w, height: h),
);

/// "Rổ hoa giảm giá" next to the counter (spec §1): 72×56, from 17h,
/// hidden when empty, pops in 0.8→1 over 250 ms.
class ClearanceBasket extends StatelessWidget {
  const ClearanceBasket({
    super.key,
    required this.session,
    required this.onTap,
  });

  final ShopSession session;
  final VoidCallback onTap;

  static const size = Size(72, 56);

  static bool visible(ShopSession s) =>
      clearanceHours(s) && clearanceBasketCount(s) > 0;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      builder: (_, v, c) => Transform.scale(scale: v, child: c),
      child: GestureDetector(
        key: const Key('clearance-basket'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.fromSize(
          size: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _art(WiltingArt.basket, size.width, size.height),
              Positioned(
                right: -6,
                top: -8,
                child: Transform.rotate(
                  angle: -8 * 3.1415926535 / 180,
                  child: _art(WiltingArt.discountTag, 28, 28),
                ),
              ),
              Positioned(
                left: -6,
                top: -6,
                child: _Badge(
                  key: const Key('clearance-badge'),
                  text: '${clearanceBasketCount(s)}',
                  color: wiltCoral,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The basket's bottom sheet: 64dp rows, old price struck in grey, new
/// price in coral.
class ClearanceSheet extends StatelessWidget {
  const ClearanceSheet({
    super.key,
    required this.session,
    required this.onClose,
  });

  final ShopSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final t = _t(s);
    final c = s.data.wilting.clearance;
    final basket = clearanceBasket(s);
    var reserved = false;
    for (final b in s.state.stock) {
      if (b.count > 0 &&
          b.freshnessLeft <= c.freshnessThreshold &&
          s.stockAvailable(b.flowerId) < s.stockCount(b.flowerId)) {
        reserved = true;
      }
    }
    return WiltSheet(
      key: const Key('clearance-sheet'),
      height: 640 * 0.5,
      onClose: onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    t.get('clearance', 'basketTitle'),
                    style: AppText.heading(size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Badge(
                text: t.get('clearance', 'tagDiscount', {
                  'phanTram': (c.discount * 100).round(),
                }),
                color: wiltCoral,
              ),
            ],
          ),
          Text(
            t.get('clearance', 'tagLastDay'),
            style: AppText.caption(size: 11),
          ),
          const SizedBox(height: 8),
          if (basket.isEmpty)
            Text(
              t.get('clearance', 'basketEmpty'),
              style: AppText.body(size: 13),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  for (final e in basket.entries)
                    SizedBox(
                      key: Key('clearance-row-${e.key}'),
                      height: 64,
                      child: Row(
                        children: [
                          ArtImage(Art.flower(e.key), size: 48),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${s.e.flower(e.key).nameVi} ×${e.value}',
                              style: AppText.body(size: 13, weight: 700),
                            ),
                          ),
                          Text(
                            vndLabel(s.e.flower(e.key).sellPrice),
                            style: AppText.caption(
                              size: 12,
                              color: AppColors.textDisabled,
                            ).copyWith(decoration: TextDecoration.lineThrough),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            vndLabel(clearancePrice(s, e.key)),
                            style: AppText.number(size: 14, color: wiltCoral),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (reserved)
            Text(
              t.get('clearance', 'reservedNote'),
              key: const Key('clearance-reserved'),
              style: AppText.caption(size: 11),
            ),
        ],
      ),
    );
  }
}

/// "Kệ hoa khô" on the right wall (spec §2): 96×72 once the rack is
/// bought; drying rack art while stems hang, the jar once stock is in.
class DriedShelf extends StatelessWidget {
  const DriedShelf({super.key, required this.session, required this.onTap});

  final ShopSession session;
  final VoidCallback onTap;

  static const size = Size(96, 72);

  @override
  Widget build(BuildContext context) {
    final s = session;
    final d = s.data.wilting.drying;
    final used = driedStorageUsed(s);
    final rack = s.state.drying;
    final showJar = driedStockCount(s) > 0;
    final next = rack.isEmpty
        ? null
        : rack.reduce((a, b) => a.daysLeft <= b.daysLeft ? a : b);
    return GestureDetector(
      key: const Key('dried-shelf'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: size.width,
        height: size.height + (next == null ? 0 : 18),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _art(
              showJar ? WiltingArt.driedJar : WiltingArt.dryingRack,
              size.width,
              size.height,
            ),
            Positioned(
              right: -6,
              top: -6,
              child: _Badge(
                key: const Key('dried-badge'),
                text: '$used/${d.storageCap}',
                color: used >= d.storageCap ? wiltCoral : AppColors.primaryBase,
              ),
            ),
            if (next != null)
              Positioned(
                left: 0,
                right: 0,
                top: size.height + 2,
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          key: const Key('dried-progress'),
                          value: (d.dryingDays - next.daysLeft) / d.dryingDays,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFE0E0E0),
                          color: AppColors.primaryBase,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${d.dryingDays - next.daysLeft}/${d.dryingDays} ngày',
                          style: AppText.caption(size: 11, weight: 800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The shelf's sheet: dried stock by name (block nameVi) and the rack.
class DriedShelfSheet extends StatelessWidget {
  const DriedShelfSheet({
    super.key,
    required this.session,
    required this.onClose,
  });

  final ShopSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final t = _t(s);
    final d = s.data.wilting.drying;
    final n = driedStockCount(s);
    String name(String id) => d.byId(id)?.name ?? id;
    return WiltSheet(
      key: const Key('dried-sheet'),
      height: 640 * 0.5,
      onClose: onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.get('dried', 'shelfTitle'),
                  style: AppText.heading(size: 18),
                ),
              ),
              // Decoration only (Hà Phương): not for sale.
              _art(WiltingArt.driedBouquetDecor, 40, 40),
            ],
          ),
          Text(
            n > 0
                ? t.get('dried', 'shelfStock', {'n': n})
                : t.get('dried', 'shelfEmpty'),
            key: const Key('dried-stock-line'),
            style: AppText.body(size: 13),
          ),
          Text(t.get('dried', 'neverWilt'), style: AppText.caption(size: 11)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final e in s.state.driedStock.entries)
                  if (e.value > 0)
                    SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name(e.key),
                              style: AppText.body(size: 13, weight: 700),
                            ),
                          ),
                          Text('×${e.value}', style: AppText.number(size: 14)),
                        ],
                      ),
                    ),
                for (final b in s.state.drying)
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${name(b.flowerId)} ×${b.stems}',
                            style: AppText.body(size: 13, weight: 700),
                          ),
                        ),
                        Text(
                          t.get('dried', 'drying', {'ngay': b.daysLeft}),
                          style: AppText.caption(size: 11),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Giàn phơi hoa" card at the end of the upgrades list (80 tall, like
/// the upgrade cards).
class DryingUnlockCard extends StatelessWidget {
  const DryingUnlockCard({
    super.key,
    required this.session,
    required this.onBuy,
  });

  final ShopSession session;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final t = _t(s);
    final d = s.data.wilting.drying;
    final Widget price;
    if (s.state.dryingUnlocked) {
      price = Center(
        child: Text('✓', style: AppText.heading(color: AppColors.primaryBase)),
      );
    } else if (s.state.day < d.unlockDay) {
      final hint = t.get('unlock', 'lockedHint', {'ngay': d.unlockDay});
      price = DisabledPrice(label: hint, hint: hint, small: true);
    } else {
      price = PriceButton(
        key: const Key('buy-drying'),
        label: formatK(d.unlockCost),
        onTap: onBuy,
      );
    }
    return SizedBox(
      height: 80,
      child: CardBox(
        radius: 16,
        borderWidth: 1,
        child: Stack(
          children: [
            Positioned(
              left: 12,
              top: 14,
              child: _art(WiltingArt.dryingRack, 52, 52),
            ),
            Positioned(
              left: 74,
              top: 5,
              width: 180,
              height: 22,
              child: Text(
                t.get('unlock', 'upgradeName'),
                style: AppText.heading(size: 15),
              ),
            ),
            Positioned(
              left: 74,
              top: 27,
              width: 176,
              child: Text(
                t.get('unlock', 'upgradeDesc'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                  size: 11,
                  weight: 700,
                ).copyWith(height: 1.2),
              ),
            ),
            Positioned(right: 12, top: 23, width: 66, height: 34, child: price),
          ],
        ),
      ),
    );
  }
}

/// "Mở Giàn phơi hoa" confirm popup.
class DryingUnlockPopup extends StatelessWidget {
  const DryingUnlockPopup({
    super.key,
    required this.session,
    required this.onClose,
  });

  final ShopSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final t = _t(s);
    final d = s.data.wilting.drying;
    return PopupFrame(
      key: const Key('drying-unlock-popup'),
      rect: const Rect.fromLTWH(32, 184, 296, 272),
      onOutsideTap: onClose,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _art(WiltingArt.dryingRack, 96, 72),
            const SizedBox(height: 8),
            Text(
              t.get('unlock', 'popupTitle'),
              style: AppText.heading(size: 18),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                t.get('unlock', 'popupBody', {'soNgay': d.dryingDays}),
                textAlign: TextAlign.center,
                style: AppText.body(size: 13),
              ),
            ),
            ChunkyButton(
              key: const Key('drying-unlock-go'),
              label: t.get('unlock', 'popupButton', {
                'tien': vndLabel(d.unlockCost),
              }),
              fontSize: 15,
              height: 48,
              onPressed: () {
                unlockDrying(s);
                onClose();
              },
            ),
          ],
        ),
      ),
    );
  }
}
