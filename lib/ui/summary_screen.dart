import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';

/// Tổng kết cuối ngày (spec_cho_va_tong_ket.md §2).
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen>
    with SingleTickerProviderStateMixin {
  // 5 sections, 80 ms apart, each sliding in over `slow`.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 80 * 4 + AppMotion.slow.inMilliseconds),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _section(int i, Widget child) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, c) {
        final total = _c.duration!.inMilliseconds;
        final t = ((_c.value * total - i * 80) / AppMotion.slow.inMilliseconds)
            .clamp(0.0, 1.0);
        final v = Curves.easeOutCubic.transform(t);
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: c),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final e = s.e;
    final m = s.state.metrics;
    final profit = m.profit;
    final rank = s.rank;
    final nextRank = e.shopRanks.where((r) => r.rank == rank.rank + 1);
    final rating = s.rating.average;
    final delta =
        double.parse(rating.toStringAsFixed(1)) -
        double.parse(m.ratingAtStart.toStringAsFixed(1));
    final hired = s.shippersHired;
    final upkeep = m.fixedCosts - e.fixedCostsTotal - m.shipperWages;
    final onlineLabel = m.tripsOutAtClose > 0
        ? 'Tiền đơn online (gồm ${m.tripsOutAtClose} đơn giao sau giờ đóng cửa)'
        : 'Tiền đơn online';
    final rows = <(String, int)>[
      ('Tiền hoa', m.flowerIncome),
      ('Tiền boa', m.tipIncome),
      if (hired > 0) (onlineLabel, m.onlineIncome),
      ('Thưởng mục tiêu', m.goalRewards),
      ('Nhập hoa buổi sáng', -m.marketSpend),
      // TODO(Phú): paper/ribbon per-use cost has no line in the spec.
      if (m.wrapSupplies > 0) ('Giấy gói và nơ', -m.wrapSupplies),
      ('Tiền thuê và điện nước', -e.fixedCostsTotal),
      if (upkeep > 0) ('Phí duy trì nâng cấp', -upkeep),
      if (hired > 0) ('Lương shipper', -m.shipperWages),
    ];
    final rowGap = rows.length <= 5 ? 22.0 : (104 / rows.length);
    final wilted = m.wiltedByFlower.entries
        .where((w) => w.value > 0)
        .map((w) => '${w.value} cành ${e.flower(w.key).nameVi.toLowerCase()}')
        .toList();

    return OpaqueScreen(
      color: AppColors.bgShop,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 16,
            child: Text(
              'Tổng kết Ngày ${s.state.day}',
              textAlign: TextAlign.center,
              style: AppText.title(size: 22, weight: 800),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 46,
            child: Text(
              '${rank.nameVi} · ${e.openHour}:00 đến ${e.closeHour}:00',
              textAlign: TextAlign.center,
              style: AppText.caption(size: 11),
            ),
          ),
          Positioned(
            left: 12,
            top: 72,
            width: 336,
            height: 86,
            child: _section(
              0,
              CardBox(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Text('Lãi hôm nay', style: AppText.caption(weight: 800)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CoinIcon(size: 24),
                        const SizedBox(width: 6),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: profit.toDouble()),
                          duration: AppMotion.celebrate,
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => Text(
                            formatSignedK(v.round()),
                            key: const Key('summary-profit'),
                            style: AppText.display(
                              size: 30,
                              color: profit >= 0
                                  ? AppColors.statusSuccess
                                  : AppColors.statusDanger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Tiền mặt: ${formatK(s.state.money)}',
                      style: AppText.caption(size: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final (i, (label, value, color)) in [
            ('Bó đã bán', m.bouquetsSold, AppColors.primaryBase),
            ('Khách bỏ về', m.customersLeft, AppColors.statusWarning),
            ('Cành bị héo', m.stemsWilted, AppColors.freshnessWilting),
          ].indexed)
            Positioned(
              left: 12 + i * 116.0,
              top: 170,
              width: 104,
              height: 64,
              child: _section(
                1,
                CardBox(
                  shadow: false,
                  radius: 16,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$value',
                        style: AppText.number(size: 22, color: color),
                      ),
                      const SizedBox(height: 6),
                      Text(label, style: AppText.caption(size: 11)),
                    ],
                  ),
                ),
              ),
            ),
          if (hired > 0)
            Positioned(
              left: 12,
              top: 236,
              width: 336,
              height: 16,
              child: _section(
                1,
                Text.rich(
                  TextSpan(
                    style: AppText.caption(size: 11),
                    children: [
                      const TextSpan(text: 'Đơn online: '),
                      TextSpan(text: '${m.onlineDelivered} đúng giờ'),
                      const TextSpan(text: ' · '),
                      TextSpan(
                        text: '${m.onlineLate} trễ',
                        style: TextStyle(
                          color: m.onlineLate > 0
                              ? AppColors.statusDanger
                              : AppColors.textSecondary,
                        ),
                      ),
                      const TextSpan(text: ' · '),
                      TextSpan(
                        text: '${m.onlineMissed} bị lỡ',
                        style: TextStyle(
                          color: m.onlineMissed > 0
                              ? AppColors.statusDanger
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  key: const Key('summary-online'),
                ),
              ),
            ),
          Positioned(
            left: 12,
            top: hired > 0 ? 254 : 246,
            width: 336,
            height: 168,
            child: _section(
              2,
              CardBox(
                shadow: false,
                child: Stack(
                  children: [
                    Positioned(
                      left: 12,
                      top: 6,
                      child: Text(
                        'Thu chi',
                        style: AppText.title(size: 15, weight: 800),
                      ),
                    ),
                    for (var i = 0; i < rows.length; i++)
                      Positioned(
                        left: 12,
                        right: 12,
                        top: 42 - 9 + i * rowGap,
                        child: _moneyRow(rows[i].$1, rows[i].$2),
                      ),
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 144,
                      child: Container(
                        height: 1,
                        color: AppColors.surfaceBorder,
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 148,
                      child: Row(
                        children: [
                          Text(
                            'Cộng',
                            style: AppText.body(size: 12, weight: 800),
                          ),
                          const Spacer(),
                          Text(
                            formatSignedK(profit),
                            style: AppText.number(
                              size: 14,
                              color: profit >= 0
                                  ? AppColors.statusSuccess
                                  : AppColors.statusDanger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 426,
            width: 164,
            height: 78,
            child: _section(
              3,
              CardBox(
                shadow: false,
                radius: 16,
                child: Stack(
                  children: [
                    Positioned(
                      left: 12,
                      top: 8,
                      child: Text(
                        'Đánh giá',
                        style: AppText.caption(size: 11, weight: 800),
                      ),
                    ),
                    const Positioned(
                      left: 12,
                      top: 34,
                      child: StarIcon(radius: 10),
                    ),
                    Positioned(
                      left: 36,
                      top: 32,
                      child: Text(
                        formatRating(rating),
                        style: AppText.number(size: 20),
                      ),
                    ),
                    if (delta.abs() >= 0.05)
                      Positioned(
                        right: 10,
                        top: 34,
                        child: Container(
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: delta > 0
                                ? AppColors.secondarySoft
                                : AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${delta > 0 ? 'tăng' : 'giảm'} ${formatRating(delta.abs())}',
                            style: AppText.caption(
                              size: 10,
                              weight: 800,
                              color: delta > 0
                                  ? AppColors.statusSuccess
                                  : AppColors.primaryPressed,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 12,
                      top: 58,
                      child: Text(
                        '${m.newReviews} nhận xét mới',
                        style: AppText.caption(size: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 184,
            top: 426,
            width: 164,
            height: 78,
            child: _section(
              3,
              CardBox(
                shadow: false,
                radius: 16,
                child: Stack(
                  children: [
                    Positioned(
                      left: 12,
                      top: 8,
                      child: Text(
                        'Hạng tiệm',
                        style: AppText.caption(size: 11, weight: 800),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 8,
                      top: 26,
                      child: Text(
                        rank.nameVi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(size: 14, weight: 800),
                      ),
                    ),
                    if (nextRank.isEmpty)
                      Positioned(
                        left: 12,
                        top: 56,
                        child: Text(
                          'Hạng cao nhất',
                          style: AppText.caption(size: 10),
                        ),
                      )
                    else ...[
                      Positioned(
                        left: 12,
                        top: 50,
                        child: ProgressBar(
                          width: 140,
                          height: 8,
                          fraction:
                              (s.state.lifetimeBouquetsSold -
                                  rank.minBouquetsSold) /
                              (nextRank.first.minBouquetsSold -
                                  rank.minBouquetsSold),
                          color: AppColors.primaryBase,
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 60,
                        child: Text(
                          'Còn ${nextRank.first.minBouquetsSold - s.state.lifetimeBouquetsSold} bó để lên hạng',
                          style: AppText.caption(size: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 508,
            width: 336,
            height: 28,
            child: _section(
              4,
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    if (wilted.isNotEmpty) ...[
                      const FlowerIcon(flowerId: 'daisy', radius: 8),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        wilted.isEmpty
                            ? (s.state.day == 1
                                  // End of day 1 tip (spec_popup_va_mo_dau.md §6).
                                  ? 'Có tiền rồi thì ghé Nâng cấp để tiệm xịn hơn nhé.'
                                  : 'Không có cành nào bị héo, giỏi lắm!')
                            : 'Bỏ đi ${wilted.join(', ')} đã héo',
                        key: const Key('summary-strip'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(
                          size: 11,
                          weight: 800,
                          color: wilted.isEmpty
                              ? AppColors.statusSuccess
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 540,
            width: 336,
            height: 52,
            child: _DonateEntry(onTap: s.openDonors),
          ),
          Positioned(
            left: 12,
            top: 592,
            width: 160,
            height: 48,
            child: ChunkyButton(
              label: 'Xem nhận xét',
              kind: ButtonKind.ghost,
              fontSize: 15,
              onPressed: () => s.openReviews(todayOnly: true),
            ),
          ),
          Positioned(
            left: 184,
            top: 592,
            width: 164,
            height: 48,
            child: ChunkyButton(
              key: const Key('next-day'),
              label: 'Sang ngày mới',
              fontSize: 16,
              onPressed: s.startNextDay,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, int v) => Row(
    children: [
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.body(
            size: 12,
            weight: 700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      const Spacer(),
      Text(
        formatSignedK(v),
        style: AppText.number(
          size: 13,
          color: v < 0 ? AppColors.statusDanger : AppColors.statusSuccess,
        ),
      ),
    ],
  );
}

/// spec_dai_thien_nhan.md §1: 52px card above "Sang ngày mới".
class _DonateEntry extends StatelessWidget {
  const _DonateEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('summary-donate'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.surfaceBorder,
            width: AppBorder.thin,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            ArtImage(Art.nav('sen'), size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Game miễn phí, ủng hộ tùy tâm',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(
                  size: 11,
                  weight: 800,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlineButton(
              key: const Key('summary-donate-button'),
              label: 'Ủng hộ',
              width: 76,
              height: 28,
              fontSize: 13,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
