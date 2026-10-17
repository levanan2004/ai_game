import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../save/game_state.dart';
import '../logic/format.dart';
import '../logic/garden.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';

/// Grass slots on [Art.scene] `vuon_nha_bg` (768×2048), source pixels.
/// Index runs left to right, then the next row. Four beds use the first row.
class _YardLayout {
  static const srcW = 768.0;
  static const srcH = 2048.0;
  static const viewW = 360.0;
  static const viewH = viewW * srcH / srcW;

  static const _cols = <(double, double)>[
    (62, 134),
    (233, 133),
    (403, 131),
    (581, 133),
  ];
  static const _rows = <(double, double)>[
    (618, 119),
    (770, 119),
    (924, 126),
    (1088, 132),
    (1260, 141),
  ];

  static Rect plotBox(int index) {
    final col = _cols[index % 4];
    final row = _rows[index ~/ 4];
    final cx = (col.$1 + col.$2 / 2) * viewW / srcW;
    final cy = (row.$1 + row.$2 / 2) * viewH / srcH;
    return Rect.fromCenter(center: Offset(cx, cy), width: 76, height: 76);
  }
}

/// Desktop web only drags a scroll view with a mouse when the pointer kind
/// is listed. Touch and trackpads already drag.
class _YardScrollBehavior extends MaterialScrollBehavior {
  const _YardScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.mouse,
  };
}

/// Vườn nhà: a scrolling yard. Till, plant, and water on real time.
class GardenScreen extends StatefulWidget {
  const GardenScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen> {
  int _selected = 0;
  bool _shop = false;

  ShopSession get s => widget.session;

  @override
  Widget build(BuildContext context) {
    final plots = s.state.plots;
    return OpaqueScreen(
      color: AppColors.bgBase,
      child: Stack(
        children: [
          Positioned.fill(
            child: ScrollConfiguration(
              behavior: const _YardScrollBehavior(),
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 148),
                  child: SizedBox(
                    width: _YardLayout.viewW,
                    height: _YardLayout.viewH,
                    child: Stack(
                      children: [
                        Image.asset(
                          Art.scene('vuon_nha_bg'),
                          width: _YardLayout.viewW,
                          height: _YardLayout.viewH,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.medium,
                        ),
                        for (var i = 0; i < plots.length && i < 20; i++)
                          _placedPlot(i),
                        if (plots.length < s.e.gardenMaxPlots) _nextPlot(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 10,
            child: BackButtonBox(
              key: const Key('garden-back'),
              onTap: s.closeGarden,
            ),
          ),
          Positioned(
            left: 56,
            right: 108,
            top: 8,
            height: 36,
            child: Center(child: _titleChip(_shop ? 'Mua hạt' : 'Vườn nhà')),
          ),
          Positioned(
            right: 12,
            top: 8,
            child: ChunkyButton(
              key: const Key('garden-shop'),
              label: _shop ? 'Luống' : 'Mua hạt',
              kind: ButtonKind.ghost,
              height: 36,
              fontSize: 13,
              onPressed: () => setState(() => _shop = !_shop),
            ),
          ),
          if (_shop)
            Positioned(
              left: 0,
              right: 0,
              top: 52,
              bottom: 0,
              child: ColoredBox(
                color: AppColors.bgBase,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: _SeedShop(session: s),
                ),
              ),
            )
          else
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _PlotActions(
                session: s,
                index: _selected,
                onBuy: () => setState(() => _shop = true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _titleChip(String label) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.headerChip,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(label, style: AppText.title(size: 18, weight: 800)),
      ),
    );
  }

  Widget _placedPlot(int index) {
    final box = _YardLayout.plotBox(index);
    return Positioned(
      left: box.left,
      top: box.top,
      width: box.width,
      height: box.height,
      child: _PlotButton(
        session: s,
        index: index,
        selected: _selected == index,
        onTap: () => setState(() => _selected = index),
      ),
    );
  }

  Widget _nextPlot() {
    final index = s.state.plots.length;
    final box = _YardLayout.plotBox(index);
    final selected = _selected == index;
    return Positioned(
      left: box.left,
      top: box.top,
      width: box.width,
      height: box.height,
      child: GestureDetector(
        key: const Key('garden-next-plot'),
        onTap: () {
          if (!s.plotShopUnlocked) {
            showTapHint(context, 'Mở vào ngày ${s.e.gardenPlotBuyDay}');
            return;
          }
          setState(() => _selected = index);
        },
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x553F7F52),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? AppColors.primaryPressed
                  : const Color(0xAA3F7F52),
              width: AppBorder.thick,
            ),
          ),
          child: Center(
            child: Text(
              '+',
              style: AppText.title(
                size: 28,
                weight: 800,
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlotButton extends StatelessWidget {
  const _PlotButton({
    required this.session,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final ShopSession session;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final view = session.gardenView(index);
    return GestureDetector(
      key: Key('garden-plot-$index'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected
                ? AppColors.primaryPressed
                : const Color(0x00000000),
            width: AppBorder.thick,
          ),
        ),
        child: Image.asset(
          Art.garden(gardenArtId(view)),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _PlotActions extends StatelessWidget {
  const _PlotActions({
    required this.session,
    required this.index,
    required this.onBuy,
  });

  final ShopSession session;
  final int index;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    if (index == session.state.plots.length) {
      return _BuyPlotCard(session: session);
    }
    if (index < 0 || index >= session.state.plots.length) {
      return const SizedBox.shrink();
    }
    final s = session;
    final view = s.gardenView(index);
    final flower = view.flowerId == null ? null : s.e.flower(view.flowerId!);
    final seed = view.flowerId == null ? null : s.e.gardenSeed(view.flowerId!);
    final name = flower?.nameVi;
    final wait = view.remaining == null
        ? null
        : formatGardenWait(view.remaining!);
    final (
      String line,
      String? action,
      VoidCallback? onAction,
    ) = switch (view.phase) {
      GardenPhase.locked =>
        session.shovelCount > 0
            ? (
                'Đất còn khô. Xới tốn 1 xẻng.',
                'Xới đất',
                () {
                  session.tillPlot(index);
                },
              )
            : ('Đất còn khô. Cần 1 xẻng.', 'Mua xẻng', onBuy),
      GardenPhase.empty => ('Luống trống.', null, null),
      GardenPhase.sprout || GardenPhase.leaf => (
        view.thirsty
            ? '$name đang khát. Còn $wait trước khi héo.'
            : '$name đang lớn. Tưới sau $wait.',
        view.thirsty ? 'Tưới' : null,
        view.thirsty
            ? () {
                s.waterPlot(index);
              }
            : null,
      ),
      GardenPhase.bloom => (
        '$name đã nở. Thu hoạch ${seed?.yieldStems ?? 0} cành.',
        'Thu hoạch',
        () {
          s.harvestPlot(index);
        },
      ),
      GardenPhase.wilted => (
        '$name héo rồi. Nhổ để trồng luống khác.',
        'Nhổ',
        () {
          s.clearPlot(index);
        },
      ),
    };
    final ownedSeeds = [
      for (final f in s.e.flowers)
        if ((s.e.gardenSeed(f.id)) != null && s.seedCount(f.id) > 0) f,
    ];
    return CardBox(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tưới đúng giờ. Trễ một lượt thì cây héo.',
            style: AppText.caption(size: 12, weight: 700),
          ),
          const SizedBox(height: 4),
          Text(line, style: AppText.body(size: 14, weight: 700)),
          const SizedBox(height: 8),
          if (view.phase == GardenPhase.empty) ...[
            if (ownedSeeds.isEmpty)
              ChunkyButton(
                key: const Key('garden-need-seed'),
                label: 'Mua hạt',
                height: 44,
                onPressed: onBuy,
              )
            else
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: ownedSeeds.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = ownedSeeds[i];
                    return ChunkyButton(
                      key: Key('garden-plant-${f.id}'),
                      label: '${f.nameVi} ×${s.seedCount(f.id)}',
                      height: 44,
                      fontSize: 14,
                      onPressed: () => s.plantPlot(index, f.id),
                    );
                  },
                ),
              ),
          ] else if (action != null)
            ChunkyButton(
              key: const Key('garden-action'),
              label: action,
              height: 44,
              onPressed: onAction,
            ),
        ],
      ),
    );
  }
}

class _BuyPlotCard extends StatelessWidget {
  const _BuyPlotCard({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final price = session.e.gardenPlotPrice(session.state.plots.length);
    final afford = session.state.money >= price;
    return CardBox(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mua thêm một luống đất khô.',
            style: AppText.body(size: 14, weight: 700),
          ),
          const SizedBox(height: 8),
          ChunkyButton(
            key: const Key('garden-buy-plot'),
            label: formatK(price),
            height: 44,
            enabled: afford,
            disabledHint: 'Không đủ tiền',
            onPressed: () {
              session.buyPlot();
            },
          ),
        ],
      ),
    );
  }
}

class _SeedShop extends StatelessWidget {
  const _SeedShop({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final rows = [
      for (final f in s.e.flowers)
        if (s.owned.contains(f.id) && s.e.gardenSeed(f.id) != null)
          (f, s.e.gardenSeed(f.id)!),
    ];
    return ListView.separated(
      itemCount: rows.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i == 0) return _ShovelRow(session: s);
        final (FlowerDef flower, GardenSeedDef seed) = rows[i - 1];
        final afford = s.state.money >= seed.price;
        final morning =
            s.state.phase == DayPhase.market ||
            s.state.phase == DayPhase.preparing;
        return SizedBox(
          height: 72,
          child: CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                ArtImage(Art.garden('hat_${flower.id}'), size: 52),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(flower.nameVi, style: AppText.heading(size: 15)),
                      Text(
                        '${seed.stepMinutes} phút mỗi lượt · ${seed.yieldStems} cành · có ${s.seedCount(flower.id)}',
                        style: AppText.caption(size: 11, weight: 700),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 88,
                  child: ChunkyButton(
                    key: Key('garden-buy-${flower.id}'),
                    label: formatK(seed.price),
                    height: 40,
                    fontSize: 14,
                    enabled: afford && morning,
                    disabledHint: morning
                        ? 'Không đủ tiền'
                        : 'Mua hạt lúc sáng hoặc lúc chuẩn bị cửa',
                    onPressed: () => s.buySeed(flower.id),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShovelRow extends StatelessWidget {
  const _ShovelRow({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final price = s.e.shovelPrice;
    final afford = s.state.money >= price;
    final morning =
        s.state.phase == DayPhase.market || s.state.phase == DayPhase.preparing;
    return SizedBox(
      height: 72,
      child: CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Xẻng', style: AppText.heading(size: 15)),
                  Text(
                    'Tươi một luống khô · có ${s.shovelCount}',
                    style: AppText.caption(size: 11, weight: 700),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 88,
              child: ChunkyButton(
                key: const Key('garden-buy-shovel'),
                label: formatK(price),
                height: 40,
                fontSize: 14,
                enabled: afford && morning,
                disabledHint: morning
                    ? 'Không đủ tiền'
                    : 'Mua xẻng lúc sáng hoặc lúc chuẩn bị cửa',
                onPressed: () {
                  s.buyShovel();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
