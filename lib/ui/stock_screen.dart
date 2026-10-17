import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../logic/format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'paint.dart';

/// Kho hoa: stems on hand, plus the papers and ribbons the shop owns.
class StockScreen extends StatelessWidget {
  const StockScreen({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final flowers = s.unlockedFlowers;
    final wraps = [...s.e.papers, ...s.e.ribbons];
    return OpaqueScreen(
      color: AppColors.bgBase,
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 10,
            child: BackButtonBox(
              key: const Key('stock-back'),
              onTap: s.closeStock,
            ),
          ),
          Positioned(
            left: 56,
            right: 56,
            top: 10,
            height: 32,
            child: Center(
              child: Text(
                'Kho hoa',
                style: AppText.title(size: 20, weight: 800),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 52,
            bottom: 0,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              children: [
                for (final f in flowers) ...[
                  _FlowerRow(session: s, flower: f),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                Text('Giấy và nơ', style: AppText.heading(size: 16)),
                const SizedBox(height: 2),
                Text(
                  'Món mới mở lúc tiệm đóng cửa, trong Nâng cấp.',
                  style: AppText.caption(size: 12),
                ),
                const SizedBox(height: 8),
                for (final item in wraps) ...[
                  _WrapRow(session: s, item: item),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowerRow extends StatelessWidget {
  const _FlowerRow({required this.session, required this.flower});

  final ShopSession session;
  final FlowerDef flower;

  @override
  Widget build(BuildContext context) {
    final count = session.stockCount(flower.id);
    final left = _worstFreshness(session, flower.id);
    final fraction = count == 0 ? 0.0 : left / flower.freshnessDays;
    final line = count == 0 ? 'Hết hoa' : '$count cành · còn $left ngày';
    return CardBox(
      radius: 16,
      borderWidth: 1,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ArtImage(Art.flower(flower.id), size: 52),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flower.nameVi,
                  style: AppText.title(size: 15, weight: 800),
                ),
                Text(line, style: AppText.caption(size: 12, weight: 700)),
                const SizedBox(height: 4),
                ProgressBar(
                  width: 180,
                  height: 6,
                  fraction: fraction,
                  color: freshnessColor(fraction),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WrapRow extends StatelessWidget {
  const _WrapRow({required this.session, required this.item});

  final ShopSession session;
  final ItemDef item;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final owned = s.owned.contains(item.id);
    final picture = s.e.papers.any((p) => p.id == item.id)
        ? paperImage(item.id, size: 44)
        : ArtImage(Art.ribbon(item.id), size: 44);
    return GestureDetector(
      key: Key('stock-${item.id}'),
      onTap: owned
          ? null
          : () {
              if (!s.shopClosed) {
                s.showNotice('Mở khóa khi tiệm đóng cửa nhé');
                return;
              }
              s.openUpgrades(tab: 1);
            },
      child: Opacity(
        opacity: owned ? 1 : 0.55,
        child: CardBox(
          radius: 16,
          borderWidth: 1,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 52, height: 44, child: Center(child: picture)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nameVi,
                      style: AppText.title(size: 15, weight: 800),
                    ),
                    Text(
                      owned
                          ? 'Đang có'
                          : 'Chưa mở · ${formatK(item.unlockCost)}',
                      style: AppText.caption(size: 12, weight: 700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _worstFreshness(ShopSession s, String flowerId) {
  var worst = 0;
  var seen = false;
  for (final b in s.state.stock) {
    if (b.flowerId != flowerId || b.count <= 0) continue;
    if (!seen || b.freshnessLeft < worst) worst = b.freshnessLeft;
    seen = true;
  }
  return worst;
}
