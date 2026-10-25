import 'package:flutter/material.dart';

import '../ads/rewarded_ads.dart';
import '../data/rewarded_ad_store.dart';
import '../logic/price_format.dart';
import '../logic/rewarded_ad.dart';
import '../logic/rewards.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'reward_bundle_view.dart' show PhaLeIcon;

/// Popup for one rewarded ad: xu from the top-bar plus, Pha lê from the shop.
class RewardedAdSheet extends StatefulWidget {
  const RewardedAdSheet({super.key, required this.session});

  final ShopSession session;

  @override
  State<RewardedAdSheet> createState() => _RewardedAdSheetState();
}

class _RewardedAdSheetState extends State<RewardedAdSheet> {
  final _store = RewardedAdStore();
  RewardedAdLedger? _ledger;
  var _busy = false;

  ShopSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ledger = await _store.load(DateTime.now());
    if (!mounted) return;
    setState(() => _ledger = ledger);
  }

  Future<void> _watch() async {
    final kind = s.rewardedAd;
    final ledger = _ledger;
    if (kind == null || ledger == null || _busy || !ledger.canWatch(kind)) {
      return;
    }
    setState(() => _busy = true);
    final result = await rewardedAds.show(kind);
    if (!mounted) return;
    if (result == RewardedAdResult.earned) {
      final next = ledger.watched(kind);
      await _store.save(next);
      if (!mounted) return;
      s.grantRewards(rewardForAd(kind), source: RewardSource.rewardedAd);
      s.closeRewardedAd();
      s.showNotice(
        kind == RewardedAdKind.xu
            ? 'Nhận ${coinFull(rewardedXuAmount)} xu'
            : 'Nhận $rewardedPhaLeAmount Pha lê',
        seconds: 3,
      );
      return;
    }
    setState(() => _busy = false);
    s.showNotice(
      result == RewardedAdResult.dismissed
          ? 'Xem hết quảng cáo mới nhận thưởng nhé.'
          : 'Chưa có quảng cáo. Thử lại sau nhé.',
      seconds: 3,
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = s.rewardedAd ?? RewardedAdKind.xu;
    final ledger = _ledger;
    final left = ledger?.remaining(kind);
    final ready = ledger != null && ledger.canWatch(kind) && !_busy;
    final xu = kind == RewardedAdKind.xu;
    return Stack(
      key: const Key('rewarded-ad-sheet'),
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _busy ? null : s.closeRewardedAd,
            child: const ColoredBox(color: AppColors.bgOverlay),
          ),
        ),
        Center(
          child: SizedBox(
            width: 320,
            child: CardBox(
              radius: AppRadius.lg,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    Art.ads(xu ? 'quang_cao_xu' : 'quang_cao_pha_le'),
                    height: 168,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Xem quảng cáo',
                    style: AppText.title(size: 20, weight: 800),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (xu)
                        const CoinIcon(size: 22)
                      else
                        const PhaLeIcon(size: 22),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          xu
                              ? 'Nhận ${coinFull(rewardedXuAmount)} xu'
                              : 'Nhận $rewardedPhaLeAmount Pha lê',
                          style: AppText.body(size: 15, weight: 800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    left == null
                        ? 'Đang kiểm tra lượt xem...'
                        : left == 0
                        ? 'Hết lượt hôm nay. Mai xem tiếp nhé.'
                        : 'Còn $left/$rewardedAdDailyCap lượt hôm nay',
                    style: AppText.body(
                      size: 13,
                      weight: 700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('rewarded-ad-watch'),
                      onPressed: ready ? _watch : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBase,
                        disabledBackgroundColor: AppColors.surfaceSunken,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                          child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  Art.ads('nut_xem'),
                                  width: 22,
                                  height: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  left == 0 ? 'Mai xem tiếp' : 'Xem quảng cáo',
                                  style: AppText.button(
                                    size: 16,
                                    color: ready
                                        ? Colors.white
                                        : AppColors.textDisabled,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  TextButton(
                    key: const Key('rewarded-ad-close'),
                    onPressed: _busy ? null : s.closeRewardedAd,
                    child: Text(
                      'Để sau',
                      style: AppText.button(
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
