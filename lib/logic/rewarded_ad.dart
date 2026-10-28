import '../data/pha_le_rules.dart';
import 'price_format.dart';
import 'rewards.dart';

/// Which rewarded ad the player asked to watch.
enum RewardedAdKind { xu, phaLe }

/// Xu granted when the xu ad is watched all the way through.
const rewardedXuAmount = 200000;

/// Pha lê granted when the Pha lê ad is watched all the way through
/// (economy.json `phaLeFree.adReward`).
int get rewardedPhaLeAmount => PhaLeRules.current.adReward;

/// Each kind can be watched this many times per local calendar day
/// (economy.json `phaLeFree.adMaxPerDay`).
int get rewardedAdDailyCap => PhaLeRules.current.adMaxPerDay;

/// What showing an ad did. Only [earned] may add xu or Pha lê.
enum RewardedAdResult { earned, dismissed, unavailable }

/// How many ads of each kind were watched on [day] (`yyyy-mm-dd`, local).
class RewardedAdLedger {
  const RewardedAdLedger({required this.day, this.xu = 0, this.phaLe = 0});

  final String day;
  final int xu;
  final int phaLe;

  int count(RewardedAdKind kind) => switch (kind) {
    RewardedAdKind.xu => xu,
    RewardedAdKind.phaLe => phaLe,
  };

  int remaining(RewardedAdKind kind) {
    final left = rewardedAdDailyCap - count(kind);
    return left < 0 ? 0 : left;
  }

  bool canWatch(RewardedAdKind kind) => remaining(kind) > 0;

  RewardedAdLedger watched(RewardedAdKind kind) => switch (kind) {
    RewardedAdKind.xu => RewardedAdLedger(day: day, xu: xu + 1, phaLe: phaLe),
    RewardedAdKind.phaLe => RewardedAdLedger(
      day: day,
      xu: xu,
      phaLe: phaLe + 1,
    ),
  };

  static String dayKey(DateTime local) {
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// [stored] from yesterday (or empty) becomes a fresh ledger for [now].
  static RewardedAdLedger forDay(RewardedAdLedger? stored, DateTime now) {
    final day = dayKey(now);
    if (stored == null || stored.day != day) return RewardedAdLedger(day: day);
    return stored;
  }
}

RewardBundle rewardForAd(RewardedAdKind kind) => switch (kind) {
  RewardedAdKind.xu => RewardBundle.coins(rewardedXuAmount),
  RewardedAdKind.phaLe => RewardBundle.phaLe(rewardedPhaLeAmount),
};

/// Toast after the ad is watched all the way through.
String rewardedEarnNotice(RewardedAdKind kind) => switch (kind) {
  RewardedAdKind.xu => 'Nhận ${coinFull(rewardedXuAmount)} xu',
  RewardedAdKind.phaLe => 'Nhận $rewardedPhaLeAmount Pha lê',
};

const rewardedAdDismissedNotice = 'Xem hết quảng cáo mới nhận thưởng nhé.';
const rewardedAdUnavailableNotice = 'Chưa có quảng cáo. Thử lại sau nhé.';
const rewardedAdCappedNotice = 'Hết lượt hôm nay. Mai xem tiếp nhé.';
