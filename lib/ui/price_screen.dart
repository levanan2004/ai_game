import 'package:flutter/material.dart';

import '../logic/payment.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Giá bán: the walk-in price level. Online orders stay on the normal price.
class PriceScreen extends StatelessWidget {
  const PriceScreen({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final level = s.priceMultiplier;
    final customers = priceCustomerFactor(s.e, level);
    final patience = pricePatienceFactor(s.e, level);
    final locked = !s.canEditPrice;
    final atMin = level <= s.e.priceMultiplierMin + 1e-9;
    final atMax = level >= s.e.priceMultiplierMax - 1e-9;
    return OpaqueScreen(
      color: AppColors.bgBase,
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 10,
            child: BackButtonBox(
              key: const Key('price-back'),
              onTap: s.closePrices,
            ),
          ),
          Positioned(
            left: 56,
            right: 56,
            top: 10,
            height: 32,
            child: Center(
              child: Text(
                'Giá bán',
                style: AppText.title(size: 20, weight: 800),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _levelName(level),
                  textAlign: TextAlign.center,
                  style: AppText.caption(size: 13, weight: 800),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: ChunkyButton(
                        key: const Key('price-down'),
                        label: '−',
                        kind: ButtonKind.ghost,
                        height: 48,
                        fontSize: 22,
                        enabled: !locked && !atMin,
                        disabledHint: locked
                            ? 'Ca này đã tính khách theo giá lúc mở cửa'
                            : 'Đã là giá thấp nhất',
                        onPressed: () => s.setPriceMultiplier(
                          level - s.e.priceMultiplierStep,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        formatPriceLevel(level),
                        key: const Key('price-level'),
                        textAlign: TextAlign.center,
                        style: AppText.title(size: 32, weight: 800),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: ChunkyButton(
                        key: const Key('price-up'),
                        label: '+',
                        kind: ButtonKind.ghost,
                        height: 48,
                        fontSize: 22,
                        enabled: !locked && !atMax,
                        disabledHint: locked
                            ? 'Ca này đã tính khách theo giá lúc mở cửa'
                            : 'Đã là giá cao nhất',
                        onPressed: () => s.setPriceMultiplier(
                          level + s.e.priceMultiplierStep,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CardBox(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Line(
                        label: 'Mỗi bó tại tiệm',
                        value: level == 1
                            ? 'Giá gốc'
                            : '${_pct(level)} giá gốc',
                      ),
                      const SizedBox(height: 8),
                      _Line(
                        label: 'Khách ghé',
                        value: customers == 1
                            ? 'Như bình thường'
                            : 'Khoảng ${_pct(customers)}',
                      ),
                      const SizedBox(height: 8),
                      _Line(
                        label: 'Khách chờ',
                        value: patience == 1
                            ? 'Như bình thường'
                            : '${_pct(patience)} thời gian',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  locked
                      ? 'Ca này đã tính khách theo giá lúc mở cửa. Sang ngày sau mới đổi được.'
                      : 'Áp dụng từ lúc mở cửa. Đơn online không đổi theo giá này.',
                  textAlign: TextAlign.center,
                  style: AppText.caption(size: 12, weight: 700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: AppText.body(size: 14, weight: 700)),
        ),
        Text(value, style: AppText.body(size: 14, weight: 800)),
      ],
    );
  }
}

/// 1 → "1×", 1.2 → "1,2×".
String formatPriceLevel(double multiplier) {
  final tenths = (multiplier * 10).round();
  final whole = tenths ~/ 10;
  final frac = tenths % 10;
  if (frac == 0) return '$whole×';
  return '$whole,$frac×';
}

String _levelName(double multiplier) {
  if (multiplier < 1) return 'Rẻ hơn';
  if (multiplier > 1) return 'Đắt hơn';
  return 'Giá thường';
}

String _pct(double factor) {
  final n = (factor * 100).round();
  return '$n%';
}
