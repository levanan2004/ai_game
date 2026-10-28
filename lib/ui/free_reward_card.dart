import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/play_analytics.dart';
import '../logic/rewarded_ad.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'reward_bundle_view.dart' show PhaLeIcon;

/// The two free rewards, opened from the Giỏ. Each button opens the watch
/// popup for that kind.
class FreeRewardPage extends StatelessWidget {
  const FreeRewardPage({
    super.key,
    required this.session,
    required this.onClose,
  });

  final ShopSession session;
  final VoidCallback onClose;

  static const width = 312.0;
  static const _artAspect = 176 / 531;

  @override
  Widget build(BuildContext context) {
    PlayAnalytics.rewardedEntrySeen(RewardedAdKind.xu.name, place: 'home');
    PlayAnalytics.rewardedEntrySeen(RewardedAdKind.phaLe.name, place: 'home');
    final height = width * _artAspect;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('free-reward-dismiss'),
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: AppColors.bgOverlay),
          ),
        ),
        Center(
          child: SizedBox(
            key: const Key('free-reward-page'),
            width: width,
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    Art.ads('the_noi_qua_mien_phi'),
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                _slot(
                  key: const Key('free-reward-xu'),
                  left: 0.073,
                  right: 0.49,
                  label: '+${formatK(rewardedXuAmount)}',
                  icon: const CoinIcon(size: 16),
                  onTap: () =>
                      session.openRewardedAd(RewardedAdKind.xu, place: 'home'),
                ),
                _slot(
                  key: const Key('free-reward-phale'),
                  left: 0.535,
                  right: 0.058,
                  label: '+$rewardedPhaLeAmount',
                  icon: const PhaLeIcon(size: 16),
                  onTap: () => session.openRewardedAd(
                    RewardedAdKind.phaLe,
                    place: 'home',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _slot({
    required Key key,
    required double left,
    required double right,
    required String label,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return Positioned(
      left: width * left,
      right: width * right,
      // Sit on the bright face of the pill. The measured green includes the
      // dark bottom rim, which pulled the label down.
      top: width * _artAspect * 0.42,
      bottom: width * _artAspect * 0.075,
      child: GestureDetector(
        key: key,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppText.caption(
                    size: 14,
                    weight: 800,
                    color: AppColors.textInverse,
                  ).copyWith(height: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shop toast for a rewarded-ad outcome. Null for every other notice.
Widget? rewardedShopNotice(String text) {
  final image = switch (text) {
    rewardedAdUnavailableNotice => Art.ads('thong_bao_chua_co'),
    rewardedAdCappedNotice => Art.ads('thong_bao_het_luot'),
    rewardedAdDismissedNotice => Art.ads('thong_bao_xem_chua_het'),
    _ => null,
  };
  if (image != null) {
    return Image.asset(
      image,
      key: const Key('shop-notice'),
      width: 240,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => Text(text, key: const Key('shop-notice')),
    );
  }
  final reward =
      text == rewardedEarnNotice(RewardedAdKind.xu) ||
      text == rewardedEarnNotice(RewardedAdKind.phaLe);
  if (!reward) return null;
  final xu = text.endsWith('xu');
  return SizedBox(
    key: const Key('shop-notice'),
    width: 300,
    height: 300 * 134 / 480,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Image.asset(
            Art.ads('thong_bao_nhan_qua'),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (xu) const CoinIcon(size: 22) else const PhaLeIcon(size: 22),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: AppText.caption(
                    size: 14,
                    weight: 800,
                    color: AppColors.primaryBase,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
