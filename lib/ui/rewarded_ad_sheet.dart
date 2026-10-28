import 'package:flutter/material.dart';

import '../ads/rewarded_ads.dart';
import '../data/rewarded_ad_store.dart';
import '../logic/play_analytics.dart';
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
    final kind = s.rewardedAd;
    if (kind != null) PlayAnalytics.rewardedSheet(kind.name);
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
    PlayAnalytics.rewardedWatchTap(kind.name);
    final result = await rewardedAds.show(kind);
    if (!mounted) return;
    if (result == RewardedAdResult.earned) {
      PlayAnalytics.rewardedEarn(kind.name);
      final next = ledger.watched(kind);
      await _store.save(next);
      if (!mounted) return;
      s.grantRewards(rewardForAd(kind), source: RewardSource.rewardedAd);
      s.closeRewardedAd();
      s.showNotice(rewardedEarnNotice(kind), seconds: 3);
      return;
    }
    setState(() => _busy = false);
    PlayAnalytics.rewardedClose(
      kind.name,
      result == RewardedAdResult.dismissed ? 'dismissed' : 'unavailable',
    );
    s.showNotice(
      result == RewardedAdResult.dismissed
          ? rewardedAdDismissedNotice
          : rewardedAdUnavailableNotice,
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
    final capped = left == 0;
    const width = 300.0;
    const height = width * 656 / 443;
    return Stack(
      key: const Key('rewarded-ad-sheet'),
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _busy ? null : s.closeRewardedAd,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: AppColors.bgOverlay),
          ),
        ),
        Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    Art.ads('khung_popup_qua'),
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                Positioned(
                  left: width * 0.855,
                  top: height * 0.128,
                  width: width * 0.115,
                  height: width * 0.115,
                  child: GestureDetector(
                    key: const Key('rewarded-ad-dismiss'),
                    onTap: _busy ? null : s.closeRewardedAd,
                    behavior: HitTestBehavior.opaque,
                  ),
                ),
                Positioned(
                  left: width * 0.14,
                  right: width * 0.14,
                  top: height * 0.34,
                  bottom: height * 0.07,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: width * 0.72,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (xu)
                            const CoinIcon(size: 72)
                          else
                            const PhaLeIcon(size: 72),
                          const SizedBox(height: 10),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8EA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE7D7B0),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(
                                rewardedEarnNotice(kind),
                                textAlign: TextAlign.center,
                                style: AppText.body(
                                  size: 15,
                                  weight: 800,
                                  color: AppColors.primaryBase,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            left == null
                                ? 'Đang kiểm tra lượt xem...'
                                : capped
                                ? rewardedAdCappedNotice
                                : 'Còn $left/$rewardedAdDailyCap lượt hôm nay',
                            textAlign: TextAlign.center,
                            style: AppText.body(
                              size: 13,
                              weight: 700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            key: const Key('rewarded-ad-watch'),
                            onTap: ready ? _watch : null,
                            child: Opacity(
                              opacity: ready || capped ? 1 : 0.55,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.asset(
                                    Art.ads(
                                      capped
                                          ? 'nut_mai_xem_tiep'
                                          : 'nut_xem_quang_cao',
                                    ),
                                    width: width * 0.7,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.medium,
                                    errorBuilder: (_, _, _) => Text(
                                      capped ? 'Mai xem tiếp' : 'Xem quảng cáo',
                                    ),
                                  ),
                                  if (_busy)
                                    const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            key: const Key('rewarded-ad-close'),
                            onTap: _busy ? null : s.closeRewardedAd,
                            child: Image.asset(
                              Art.ads('nut_de_sau'),
                              width: width * 0.52,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, _, _) => const Text('Để sau'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
