import 'package:flutter/foundation.dart';

/// The server wallet (functions/wallet.js, `wallets/{uid}`): the Pha lê
/// balance every spend is checked against, Thẻ gacha per Sơn Hải pot and the
/// per-pot pity counters. Only Cloud Functions write it (firestore.rules);
/// the app calls them through [WalletApi] and shows what comes back. The
/// save's `phaLe` is a copy of [WalletView.phaLe] for display.
@immutable
class WalletView {
  const WalletView({
    required this.phaLe,
    this.cards = const {},
    this.potOfWeek,
    this.nextPotOfWeek,
    this.weekEnd,
    this.weekStart,
    this.weekIndex = -1,
    this.daysLeft = 0,
    this.pity = const {},
    this.pityAt = 0,
    this.xuCardsBoughtToday = 0,
    this.xuCardsDailyMax = 0,
    this.xuCardsLeftToday,
    this.cardPhaLe = 0,
    this.cardCoins,
    this.credited = 0,
    this.vip,
  });

  final int phaLe;

  /// Sơn Hải pot id -> cards owned (never expire).
  final Map<String, int> cards;

  /// The pot on the wheel this week (server clock), null when none.
  final String? potOfWeek;
  final String? nextPotOfWeek;

  /// 0h Monday (Việt Nam) when the pot changes.
  final DateTime? weekEnd;
  final DateTime? weekStart;

  /// Rotation week (0 = the first pot), -1 before the start.
  final int weekIndex;
  final int daysLeft;

  /// Pot id -> this week's counter. Counters reset each week
  /// (`gacha.pityCarryOver` false); [PityCount.resetFrom] keeps the old one.
  final Map<String, PityCount> pity;
  final int pityAt;

  /// Cards bought with xu today (VN real day) and the daily cap
  /// (0 = unlimited; then [xuCardsLeftToday] is null).
  final int xuCardsBoughtToday;
  final int xuCardsDailyMax;
  final int? xuCardsLeftToday;

  /// Price of one card. [cardCoins] only when the call sent the game day.
  final int cardPhaLe;
  final int? cardCoins;

  /// Pha lê this call credited (mail claim / earn), else 0.
  final int credited;

  /// This player's VIP (functions/vip.js); null from a server without VIP.
  final VipStatus? vip;

  int cardsOf(String potId) => cards[potId] ?? 0;

  /// The same view with [v] as its VIP.
  WalletView withVip(VipStatus v) => WalletView(
    phaLe: phaLe,
    cards: cards,
    potOfWeek: potOfWeek,
    nextPotOfWeek: nextPotOfWeek,
    weekEnd: weekEnd,
    weekStart: weekStart,
    weekIndex: weekIndex,
    daysLeft: daysLeft,
    pity: pity,
    pityAt: pityAt,
    xuCardsBoughtToday: xuCardsBoughtToday,
    xuCardsDailyMax: xuCardsDailyMax,
    xuCardsLeftToday: xuCardsLeftToday,
    cardPhaLe: cardPhaLe,
    cardCoins: cardCoins,
    credited: credited,
    vip: v,
  );

  /// Cards of this week's pot.
  int get cardsThisWeek => potOfWeek == null ? 0 : cardsOf(potOfWeek!);

  static int _n(Object? v) => v is num ? v.toInt() : 0;

  static WalletView fromJson(Map raw) {
    final week = raw['week'] is Map ? raw['week'] as Map : const {};
    final xu = raw['xuCardsToday'] is Map ? raw['xuCardsToday'] as Map : {};
    final price = raw['price'] is Map ? raw['price'] as Map : const {};
    final credited = raw['credited'] is Map ? raw['credited'] as Map : const {};
    final cards = raw['cards'] is Map ? raw['cards'] as Map : const {};
    final pity = raw['pity'] is Map ? raw['pity'] as Map : const {};
    final end = week['weekEnd'];
    final start = week['weekStart'];
    return WalletView(
      phaLe: _n(raw['phaLe']),
      cards: {
        for (final e in cards.entries)
          if (e.key is String && _n(e.value) > 0) e.key as String: _n(e.value),
      },
      potOfWeek: week['potId'] is String ? week['potId'] as String : null,
      nextPotOfWeek: week['nextPotId'] is String
          ? week['nextPotId'] as String
          : null,
      weekEnd: end is num
          ? DateTime.fromMillisecondsSinceEpoch(end.toInt(), isUtc: true)
          : null,
      weekStart: start is num
          ? DateTime.fromMillisecondsSinceEpoch(start.toInt(), isUtc: true)
          : null,
      weekIndex: week['index'] is num ? (week['index'] as num).toInt() : -1,
      daysLeft: _n(week['daysLeft']),
      pity: {
        for (final e in pity.entries)
          if (e.key is String && e.value is Map)
            e.key as String: PityCount(
              n: _n((e.value as Map)['n']),
              resetFrom: _n((e.value as Map)['resetFrom']),
              lastWeek: (e.value as Map)['lastWeek'] is num
                  ? ((e.value as Map)['lastWeek'] as num).toInt()
                  : null,
            ),
      },
      pityAt: _n(raw['pityAt']),
      xuCardsBoughtToday: _n(xu['bought']),
      xuCardsDailyMax: _n(xu['max']),
      xuCardsLeftToday: xu['left'] is num ? (xu['left'] as num).toInt() : null,
      cardPhaLe: _n(price['phaLe']),
      cardCoins: price['coins'] is num ? (price['coins'] as num).toInt() : null,
      credited: _n(credited['phaLe']),
      vip: raw['vip'] is Map ? VipStatus.fromJson(raw['vip'] as Map) : null,
    );
  }
}

/// The owner's VIP as the server computed it (functions/vip.js vipView):
/// tier, total VND topped up (refunds taken off; shown only to the owner),
/// highest tier reached, the next threshold, the hall and badge switches.
@immutable
class VipStatus {
  const VipStatus({
    this.level = 0,
    this.vnd = 0,
    this.max = 0,
    this.nextVnd,
    this.hallHidden = false,
    this.badgeHidden = false,
    this.pots,
  });

  final int level;
  final int vnd;
  final int max;

  /// VND total of the next tier; null at the top.
  final int? nextVnd;
  final bool hallHidden;

  /// "Ẩn huy hiệu VIP": others see no tier (the server writes the public
  /// tier as 0 and the hall row anonymous). Tier and perks unchanged.
  final bool badgeHidden;

  /// VIP pot ids the server says this tier owns (functions/vip.js
  /// ownedVipPots); null from a server older than the VIP pots.
  final List<String>? pots;

  static VipStatus fromJson(Map raw) => VipStatus(
    level: WalletView._n(raw['level']).clamp(0, 10),
    vnd: WalletView._n(raw['vnd']),
    max: WalletView._n(raw['max']),
    nextVnd: raw['nextVnd'] is num ? (raw['nextVnd'] as num).toInt() : null,
    hallHidden: raw['hallHidden'] == true,
    badgeHidden: raw['badgeHidden'] == true,
    pots: raw['pots'] is List
        ? (raw['pots'] as List).whereType<String>().toList()
        : null,
  );
}

/// One pot's pity counter this week. [resetFrom] > 0: the weekly reset just
/// turned that old count into 0 (for a one-time notice; task 8).
@immutable
class PityCount {
  const PityCount({required this.n, this.resetFrom = 0, this.lastWeek});

  final int n;
  final int resetFrom;

  /// The week [resetFrom] was counted in (null when nothing was reset).
  final int? lastWeek;
}

/// A refused wallet call. [code] is the server's reason: `balance`,
/// `limit` (xu cards of the day), `no-cards`, `not-current`, `not-started`,
/// `already`, `not-earned`, `not-for-sale`, `expired`, `not-yours`, `bad`;
/// `network` / `server` when nothing usable came back.
class WalletException implements Exception {
  const WalletException(this.code);

  final String code;

  @override
  String toString() => 'WalletException($code)';
}

/// The wallet callables (functions/index.js): walletSync, walletClaimMail,
/// walletEarn, phaleBuy, phaleExchange, gachaBuyCards, gachaSpin. Returns
/// the raw result map (it always carries the wallet view); throws
/// [WalletException].
abstract class WalletApi {
  Future<Map<String, Object?>> call(String name, Map<String, Object?> data);
}
