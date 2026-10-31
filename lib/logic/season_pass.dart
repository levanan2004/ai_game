import 'package:flutter/foundation.dart';

import 'wallet.dart';

/// Season Pass, client side (no UI yet). The server owns every number:
/// progress, XP, premium and claims are written by functions/season_pass.js;
/// the app reads `season_pass/{uid}/seasons/{period}` and calls
/// [SeasonPassService]. Tier sizes and the premium price come from
/// economy.json `seasonPass` ([SeasonPassConfig]); without the block the pass
/// is simply off.
@immutable
class SeasonPassConfig {
  const SeasonPassConfig({
    required this.tierXp,
    required this.premiumPrice,
    required this.cycleDays,
  });

  /// XP of each tier, tier 1 first (`xp.perTier` / `tiers[].xp`).
  final List<int> tierXp;
  final int premiumPrice;
  final int cycleDays;

  int get tierCount => tierXp.length;

  /// The tier reached at [xp] (0 = none yet).
  int tierAt(int xp) {
    var need = 0;
    var reached = 0;
    for (var i = 0; i < tierXp.length; i++) {
      need += tierXp[i];
      if (xp < need) break;
      reached = i + 1;
    }
    return reached;
  }

  /// Null when economy.json has no (or a broken) `seasonPass` block.
  static SeasonPassConfig? fromEconomy(Object? economy) {
    final sp = economy is Map ? economy['seasonPass'] : null;
    if (sp is! Map) return null;
    final tiers = sp['tiers'];
    final premium = sp['premium'];
    final cycle = sp['cycleDays'];
    if (tiers is! List || tiers.isEmpty || premium is! Map || cycle is! num) {
      return null;
    }
    final xp = <int>[];
    for (final t in tiers) {
      final v = t is Map ? t['xp'] : null;
      if (v is! num || v <= 0) return null;
      xp.add(v.toInt());
    }
    final price = premium['price'];
    if (price is! num || price <= 0) return null;
    return SeasonPassConfig(
      tierXp: List.unmodifiable(xp),
      premiumPrice: price.toInt(),
      cycleDays: cycle.toInt(),
    );
  }
}

enum SeasonPassTrack {
  free('free'),
  premium('premium');

  const SeasonPassTrack(this.json);
  final String json;
}

/// The player's pass for one season: the server doc
/// `season_pass/{uid}/seasons/{period}` or a callable's result.
@immutable
class SeasonPassStatus {
  const SeasonPassStatus({
    required this.period,
    required this.themeId,
    required this.xp,
    required this.premium,
    required this.claimed,
  });

  final String? period;
  final String? themeId;
  final int xp;
  final bool premium;

  /// `free_3`, `premium_1`... already claimed.
  final Set<String> claimed;

  bool isClaimed(int tier, SeasonPassTrack track) =>
      claimed.contains('${track.json}_$tier');

  static SeasonPassStatus fromJson(Map<String, Object?> j) {
    final raw = j['claimed'];
    final claimed = <String>{
      if (raw is Map) ...raw.keys.whereType<String>(),
      if (raw is List) ...raw.whereType<String>(),
    };
    final xp = j['xp'];
    return SeasonPassStatus(
      period: j['period'] is String ? j['period'] as String : null,
      themeId: j['themeId'] is String ? j['themeId'] as String : null,
      xp: xp is num ? xp.toInt() : 0,
      premium: j['premium'] == true,
      claimed: Set.unmodifiable(claimed),
    );
  }
}

/// What a claim or a purchase came back with.
@immutable
class SeasonPassResult {
  const SeasonPassResult({
    required this.status,
    required this.pass,
    this.mailId,
    this.phaLe,
  });

  /// `claimed` / `bought` / `already`.
  final String status;
  final SeasonPassStatus pass;

  /// The mail holding the tier's items (claim it with walletClaimMail, like
  /// any reward mail). Null when the tier only had skins.
  final String? mailId;

  /// The wallet's Pha lê after a purchase.
  final int? phaLe;

  static SeasonPassResult fromJson(Map<String, Object?> j) => SeasonPassResult(
    status: j['status'] is String ? j['status'] as String : '',
    pass: SeasonPassStatus.fromJson(j),
    mailId: j['mailId'] is String ? j['mailId'] as String : null,
    phaLe: j['phaLe'] is num ? (j['phaLe'] as num).toInt() : null,
  );
}

/// The Season Pass callables (functions/index.js seasonPassClaim,
/// seasonPassBuyPremium) over the same [WalletApi] transport. Refusals come
/// back as [WalletException]: `closed`, `bad`, `not-reached`, `no-premium`,
/// `balance`, `too-late`.
class SeasonPassService {
  SeasonPassService(this.api);

  final WalletApi api;

  Future<SeasonPassResult> claim(int tier, SeasonPassTrack track) async =>
      SeasonPassResult.fromJson(
        await api.call('seasonPassClaim', {'tier': tier, 'track': track.json}),
      );

  Future<SeasonPassResult> buyPremium() async =>
      SeasonPassResult.fromJson(await api.call('seasonPassBuyPremium', {}));
}
