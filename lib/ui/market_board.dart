import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../logic/format.dart';
import '../logic/market_board.dart';
import '../logic/market_prices.dart';
import '../logic/regulars_view.dart' show holidayIcon;
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart' show FlowerIcon;
import 'gio_cao_diem_text.dart';
import 'popups.dart' show shortFlowerName;
import 'so_tay_screen.dart' show SoTayArt;

/// Colours of the market price board (Phú's spec 25/10).
abstract final class MarketBoardColors {
  static const up = Color(0xFFE26D5A);
  static const down = Color(0xFF3F7F52);
  static const same = Color(0xFF9E9A90);
  static const holiday = Color(0xFFF2B544);
  static const cream = Color(0xFFFFF8E7);
}

String _holidayName(HolidayDef h) => GioCaoDiemText.holidayName(h.id, h.nameVi);

/// Market card, 56 tall: the day and the holiday on the left, "Xem giá hôm
/// nay" on the right. On a holiday: gold border and the holiday picture.
class MarketCard extends StatelessWidget {
  const MarketCard({super.key, required this.session, required this.onOpen});

  final ShopSession session;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final day = s.state.day;
    final today = s.holidayToday;
    final named = marketCardHoliday(s.e, day);
    final icon = today == null ? null : holidayIcon(today.id);
    return GestureDetector(
      key: const Key('market-card'),
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: MarketBoardColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: today != null
                ? MarketBoardColors.holiday
                : AppColors.primaryBase,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Image.asset(
                SoTayArt.le(icon),
                key: const Key('market-card-holiday-icon'),
                width: 36,
                height: 36,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(width: 36),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    GioCaoDiemText.day(day),
                    style: AppText.title(size: 15, weight: 800),
                  ),
                  if (named != null)
                    Text(
                      _holidayName(named),
                      key: const Key('market-card-holiday'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption(
                        size: 11,
                        weight: 800,
                        color: AppColors.primaryPressed,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              height: 32,
              constraints: const BoxConstraints(maxWidth: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryBase,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  GioCaoDiemText.openSheet,
                  style: AppText.caption(
                    size: 12,
                    weight: 800,
                    color: Colors.white,
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

/// Price arrow on a market tile, 12 dp: ▲ red up, ▼ green down, a grey
/// dash for the same price; nothing on day 1.
class PriceArrow extends StatelessWidget {
  const PriceArrow({super.key, required this.change});

  final PriceChange? change;

  @override
  Widget build(BuildContext context) {
    final c = change;
    if (c == null) return const SizedBox.shrink();
    if (c.trend == PriceTrend.same) {
      return Container(
        key: const Key('price-same'),
        width: 12,
        height: 12,
        alignment: Alignment.center,
        child: Container(width: 8, height: 2, color: MarketBoardColors.same),
      );
    }
    final up = c.trend == PriceTrend.up;
    return CustomPaint(
      key: Key(up ? 'price-up' : 'price-down'),
      size: const Size(12, 12),
      painter: _Triangle(
        up: up,
        color: up ? MarketBoardColors.up : MarketBoardColors.down,
      ),
    );
  }
}

class _Triangle extends CustomPainter {
  const _Triangle({required this.up, required this.color});

  final bool up;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = up
        ? (Path()
            ..moveTo(w / 2, h * 0.15)
            ..lineTo(w * 0.95, h * 0.85)
            ..lineTo(w * 0.05, h * 0.85))
        : (Path()
            ..moveTo(w * 0.05, h * 0.15)
            ..lineTo(w * 0.95, h * 0.15)
            ..lineTo(w / 2, h * 0.85));
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Triangle old) => old.up != up || old.color != color;
}

/// Bảng giá chợ hôm nay: a bottom sheet over 60% of the market. Holiday
/// banner on top, then Loại hoa / Giá / So với hôm qua, holiday-priced
/// flowers first with the "Lễ" tag, the hint line at the bottom.
class MarketBoardSheet extends StatelessWidget {
  const MarketBoardSheet({
    super.key,
    required this.session,
    required this.onClose,
  });

  final ShopSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final flowers = marketBoardFlowers(s);
    final banner = marketBannerOf(s.e, s.state.day);
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('market-sheet-scrim'),
              onTap: onClose,
              child: const ColoredBox(color: AppColors.bgOverlay),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: box.maxHeight * 0.6,
            child: Container(
              key: const Key('market-sheet'),
              decoration: const BoxDecoration(
                color: AppColors.bgBase,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          GioCaoDiemText.marketTitle,
                          style: AppText.title(size: 17, weight: 800),
                        ),
                      ),
                      GestureDetector(
                        key: const Key('market-sheet-close'),
                        onTap: onClose,
                        behavior: HitTestBehavior.opaque,
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(Icons.close_rounded, size: 22),
                        ),
                      ),
                    ],
                  ),
                  if (banner != null) ...[
                    _Banner(session: s, banner: banner),
                    const SizedBox(height: 8),
                  ],
                  const _HeaderRow(),
                  const Divider(height: 8, color: AppColors.surfaceBorder),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (final f in flowers)
                          _BoardRow(session: s, flower: f),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    GioCaoDiemText.hint,
                    key: const Key('market-sheet-hint'),
                    style: AppText.caption(size: 11),
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

class _Banner extends StatelessWidget {
  const _Banner({required this.session, required this.banner});

  final ShopSession session;
  final MarketBanner banner;

  @override
  Widget build(BuildContext context) {
    final e = session.e;
    final h = banner.holiday;
    final name = _holidayName(h);
    final names = [
      for (final id in h.featuredFlowers) shortFlowerName(e.flower(id).nameVi),
    ];
    final (title, sub) = switch (banner.kind) {
      MarketBannerKind.soon => (
        GioCaoDiemText.banner(name, GioCaoDiemText.flowerList(names)),
        null,
      ),
      MarketBannerKind.holiday => (
        GioCaoDiemText.holidayPrice(name),
        GioCaoDiemText.holidaySub,
      ),
      MarketBannerKind.after => (GioCaoDiemText.after(name), null),
    };
    return Container(
      key: Key('market-sheet-banner-${banner.kind.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: banner.kind == MarketBannerKind.after
            ? AppColors.surfaceSunken
            : MarketBoardColors.holiday.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: banner.kind == MarketBannerKind.after
              ? AppColors.surfaceBorder
              : MarketBoardColors.holiday,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppText.caption(
              size: 12,
              weight: 800,
              color: AppColors.textPrimary,
            ),
          ),
          if (sub != null) Text(sub, style: AppText.caption(size: 11)),
        ],
      ),
    );
  }
}

const _priceW = 70.0;
const _changeW = 100.0;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = AppText.caption(size: 11, weight: 800);
    return Row(
      children: [
        Expanded(child: Text(GioCaoDiemText.colFlower, style: style)),
        SizedBox(
          width: _priceW,
          child: Text(
            GioCaoDiemText.colPrice,
            textAlign: TextAlign.right,
            style: style,
          ),
        ),
        SizedBox(
          width: _changeW,
          child: Text(
            GioCaoDiemText.colChange,
            textAlign: TextAlign.right,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.session, required this.flower});

  final ShopSession session;
  final FlowerDef flower;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final f = flower;
    final change = s.priceChange(f);
    final tagged = holidayPriced(s.e, f, s.state.day);
    final (text, color) = switch (change?.trend) {
      null => (GioCaoDiemText.firstDay, MarketBoardColors.same),
      PriceTrend.up => (
        GioCaoDiemText.up(change!.percent),
        MarketBoardColors.up,
      ),
      PriceTrend.down => (
        GioCaoDiemText.down(change!.percent),
        MarketBoardColors.down,
      ),
      PriceTrend.same => (GioCaoDiemText.same, MarketBoardColors.same),
    };
    return SizedBox(
      key: Key('market-sheet-row-${f.id}'),
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: ArtImage(
              Art.flower(f.id),
              size: 32,
              fallback: FlowerIcon(flowerId: f.id, radius: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    f.nameVi,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 13, weight: 700),
                  ),
                ),
                if (tagged) ...[
                  const SizedBox(width: 6),
                  Container(
                    key: Key('market-sheet-tag-${f.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: MarketBoardColors.holiday,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      GioCaoDiemText.holidayTag,
                      style: AppText.caption(
                        size: 10,
                        weight: 800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: _priceW,
            child: Text(
              '${formatK(s.bundlePrice(f))}/bó',
              textAlign: TextAlign.right,
              style: AppText.number(size: 13),
            ),
          ),
          SizedBox(
            width: _changeW,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (change != null) ...[
                  PriceArrow(change: change),
                  const SizedBox(width: 3),
                ],
                Flexible(
                  child: Text(
                    text,
                    key: Key('market-sheet-change-${f.id}'),
                    maxLines: 1,
                    style: AppText.caption(size: 11, weight: 800, color: color),
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
