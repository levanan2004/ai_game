import 'package:flutter/foundation.dart';

import '../data/season_clock.dart';
import 'wallet.dart';

/// Season Pass, client side. The server owns every number: progress, XP,
/// premium and claims are written by functions/season_pass.js; the app reads
/// `season_pass/{uid}/seasons/{period}` and calls [SeasonPassService]. Tiers,
/// rewards, missions, themes and the premium price come from economy.json
/// `seasonPass` ([SeasonPassConfig]); without the block the pass is off.
@immutable
class SeasonPassConfig {
  const SeasonPassConfig({
    required this.tierXp,
    required this.premiumPrice,
    required this.cycleDays,
    this.tiers = const [],
    this.missions = const [],
    this.themes = const {},
    this.buyableUntilDay = 0,
    this.dailyMaxXp = 0,
    this.weeklyMaxXp = 0,
    this.firstSeasonStart,
  });

  /// XP of each tier, tier 1 first (`xp.perTier` / `tiers[].xp`).
  final List<int> tierXp;
  final int premiumPrice;
  final int cycleDays;

  /// `tiers[]`: what each tier gives on both tracks.
  final List<SeasonPassTier> tiers;

  /// `missions[]`, in the block's order.
  final List<SeasonPassMission> missions;

  /// `themes[]` by themeId.
  final Map<String, SeasonPassTheme> themes;

  /// `premium.buyableUntilDayOfSeason` (1-based day of the season).
  final int buyableUntilDay;

  /// `xp.dailyMaxXP`, `xp.weeklyMaxXP`.
  final int dailyMaxXp;
  final int weeklyMaxXp;

  /// `firstSeasonStart` (00:00 Vietnam, as UTC): no pass before it.
  final DateTime? firstSeasonStart;

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

  /// XP into the tier after the reached one and that tier's size; at the
  /// last tier, (size, size).
  (int, int) progressAt(int xp) {
    var need = 0;
    for (final t in tierXp) {
      if (xp < need + t) return (xp - need, t);
      need += t;
    }
    final last = tierXp.isEmpty ? 0 : tierXp.last;
    return (last, last);
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
    final parsed = <SeasonPassTier>[];
    for (final t in tiers) {
      final v = t is Map ? t['xp'] : null;
      if (v is! num || v <= 0) return null;
      xp.add(v.toInt());
      parsed.add(
        SeasonPassTier(
          tier: xp.length,
          xp: v.toInt(),
          free: SeasonPassReward.fromJson((t as Map)['free']),
          premium: SeasonPassReward.fromJson(t['premium']),
        ),
      );
    }
    final price = premium['price'];
    if (price is! num || price <= 0) return null;
    final x = sp['xp'] is Map ? sp['xp'] as Map : const {};
    final buyUntil = premium['buyableUntilDayOfSeason'];
    return SeasonPassConfig(
      tierXp: List.unmodifiable(xp),
      premiumPrice: price.toInt(),
      cycleDays: cycle.toInt(),
      tiers: List.unmodifiable(parsed),
      missions: List.unmodifiable([
        for (final m in sp['missions'] is List ? sp['missions'] as List : [])
          ?SeasonPassMission.fromJson(m),
      ]),
      themes: Map.unmodifiable({
        for (final t in sp['themes'] is List ? sp['themes'] as List : [])
          if (t is Map && t['themeId'] is String)
            t['themeId'] as String: SeasonPassTheme(
              id: t['themeId'] as String,
              nameKey: t['nameKey'] is String ? t['nameKey'] as String : '',
              flowers: List.unmodifiable(
                (t['themeFlowers'] is List ? t['themeFlowers'] as List : [])
                    .whereType<String>(),
              ),
            ),
      }),
      buyableUntilDay: buyUntil is num ? buyUntil.toInt() : cycle.toInt(),
      dailyMaxXp: x['dailyMaxXP'] is num ? (x['dailyMaxXP'] as num).toInt() : 0,
      weeklyMaxXp: x['weeklyMaxXP'] is num
          ? (x['weeklyMaxXP'] as num).toInt()
          : 0,
      firstSeasonStart: vnMidnight(sp['firstSeasonStart']),
    );
  }

  /// "2026-11-09" -> that day 00:00 in Vietnam (UTC+7), as UTC.
  static DateTime? vnMidnight(Object? ymd) {
    if (ymd is! String) return null;
    final d = DateTime.tryParse('${ymd}T00:00:00Z');
    return d?.subtract(const Duration(hours: 7));
  }
}

/// One track of one tier: `{"coins": 200000}`, `{"skin": "quay_sp_{theme}",
/// "skinTier": "dep"}`, `{"gachaTicket": 1, "petItem": "no_co_vai"}`...
/// Keys stay in the block's order, so labels and icons follow the block.
@immutable
class SeasonPassReward {
  const SeasonPassReward(this.parts);

  /// (key, value): value is an int amount or an id string.
  final List<(String, Object)> parts;

  bool get isEmpty => parts.isEmpty;

  /// Skins, avatar frames: they go to the wardrobe ("Đã vào Tủ đồ").
  bool get hasWardrobeItem =>
      parts.any((p) => p.$1 == 'skin' || p.$1 == 'khungAvatar');

  static SeasonPassReward fromJson(Object? j) => SeasonPassReward([
    if (j is Map)
      for (final e in j.entries)
        if (e.key is String && e.key != 'skinTier')
          if (e.value is num)
            (e.key as String, (e.value as num).toInt())
          else if (e.value is String)
            (e.key as String, e.value as String),
  ]);
}

@immutable
class SeasonPassTier {
  const SeasonPassTier({
    required this.tier,
    required this.xp,
    required this.free,
    required this.premium,
  });

  final int tier;
  final int xp;
  final SeasonPassReward free;
  final SeasonPassReward premium;

  SeasonPassReward track(SeasonPassTrack t) =>
      t == SeasonPassTrack.free ? free : premium;
}

enum SeasonPassMissionType { daily, weekly, season }

@immutable
class SeasonPassMission {
  const SeasonPassMission({
    required this.key,
    required this.type,
    required this.goal,
    required this.target,
    required this.xp,
    required this.titleKey,
  });

  final String key;
  final SeasonPassMissionType type;
  final String goal;
  final int target;
  final int xp;
  final String titleKey;

  static SeasonPassMission? fromJson(Object? j) {
    if (j is! Map) return null;
    final type = switch (j['type']) {
      'daily' => SeasonPassMissionType.daily,
      'weekly' => SeasonPassMissionType.weekly,
      'season' => SeasonPassMissionType.season,
      _ => null,
    };
    final key = j['missionKey'];
    final target = j['target'];
    final xp = j['xp'];
    if (type == null || key is! String || target is! num || xp is! num) {
      return null;
    }
    return SeasonPassMission(
      key: key,
      type: type,
      goal: j['goal'] is String ? j['goal'] as String : '',
      target: target.toInt(),
      xp: xp.toInt(),
      titleKey: j['titleKey'] is String ? j['titleKey'] as String : '',
    );
  }
}

@immutable
class SeasonPassTheme {
  const SeasonPassTheme({
    required this.id,
    required this.nameKey,
    required this.flowers,
  });

  final String id;
  final String nameKey;
  final List<String> flowers;
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
    this.done = const {},
    this.dailyDate = '',
    this.daily = const {},
    this.week = -1,
    this.weekly = const {},
    this.season = const {},
  });

  final String? period;
  final String? themeId;
  final int xp;
  final bool premium;

  /// `free_3`, `premium_1`... already claimed.
  final Set<String> claimed;

  /// Missions the server completed: `key@2026-11-09`, `key@w0`, `key`.
  final Set<String> done;

  /// Counters per goal: today's (Vietnam date [dailyDate]), this week's
  /// (0-based [week] of the season) and the season's.
  final String dailyDate;
  final Map<String, int> daily;
  final int week;
  final Map<String, int> weekly;
  final Map<String, int> season;

  bool isClaimed(int tier, SeasonPassTrack track) =>
      claimed.contains('${track.json}_$tier');

  static SeasonPassStatus fromJson(Map<String, Object?> j) {
    final raw = j['claimed'];
    final claimed = <String>{
      if (raw is Map) ...raw.keys.whereType<String>(),
      if (raw is List) ...raw.whereType<String>(),
    };
    final xp = j['xp'];
    Map<String, int> counts(Object? scope) {
      final c = scope is Map ? scope['c'] : null;
      return Map.unmodifiable({
        if (c is Map)
          for (final e in c.entries)
            if (e.key is String && e.value is num)
              e.key as String: (e.value as num).toInt(),
      });
    }

    final d = j['daily'];
    final w = j['weekly'];
    final done = j['done'];
    return SeasonPassStatus(
      period: j['period'] is String ? j['period'] as String : null,
      themeId: j['themeId'] is String ? j['themeId'] as String : null,
      xp: xp is num ? xp.toInt() : 0,
      premium: j['premium'] == true,
      claimed: Set.unmodifiable(claimed),
      done: Set.unmodifiable({
        if (done is Map) ...done.keys.whereType<String>(),
      }),
      dailyDate: d is Map && d['date'] is String ? d['date'] as String : '',
      daily: counts(d),
      week: w is Map && w['week'] is num ? (w['week'] as num).toInt() : -1,
      weekly: counts(w),
      season: counts(j['season']),
    );
  }

  /// A claim/purchase answer only carries xp, premium and claimed: keep the
  /// mission counters this doc already had.
  SeasonPassStatus withAnswer(SeasonPassStatus a) => SeasonPassStatus(
    period: a.period ?? period,
    themeId: a.themeId ?? themeId,
    xp: a.xp,
    premium: a.premium,
    claimed: a.claimed,
    done: done,
    dailyDate: dailyDate,
    daily: daily,
    week: week,
    weekly: weekly,
    season: season,
  );
}

/// Vietnam calendar date "2026-11-09" of [now].
String vnDate(DateTime now) => now
    .toUtc()
    .add(const Duration(hours: 7))
    .toIso8601String()
    .substring(0, 10);

/// Where the player stands on one mission, read from the server doc only.
@immutable
class SeasonPassMissionState {
  const SeasonPassMissionState(this.mission, this.current, this.done);

  final SeasonPassMission mission;

  /// The server's counter for this period, capped at the target.
  final int current;

  /// The server completed it (and gave its XP): nothing to press.
  final bool done;
}

/// One season as the screen shows it: config + season + the server doc.
@immutable
class SeasonPassView {
  const SeasonPassView({
    required this.config,
    required this.season,
    required this.themeId,
    required this.status,
    required this.now,
  });

  final SeasonPassConfig config;
  final Season season;
  final String themeId;
  final SeasonPassStatus status;
  final DateTime now;

  int get tier => config.tierAt(status.xp);
  bool get maxed => tier >= config.tierCount;
  bool get ended => !now.isBefore(season.end);

  /// 1-based day of the season (the server's buyableUntilDayOfSeason rule).
  int get dayOfSeason => now.difference(season.start).inDays + 1;

  bool get canBuy =>
      !ended && !status.premium && dayOfSeason <= config.buyableUntilDay;

  int get week => now.difference(season.start).inDays ~/ 7;

  bool reached(int t) => tier >= t;

  /// Reached, not yet claimed, and (premium) bought.
  bool claimable(int t, SeasonPassTrack track) {
    if (ended || !reached(t) || status.isClaimed(t, track)) return false;
    if (track == SeasonPassTrack.premium && !status.premium) return false;
    final tierDef = config.tiers.length >= t ? config.tiers[t - 1] : null;
    return tierDef != null && !tierDef.track(track).isEmpty;
  }

  /// Every (tier, track) waiting, lowest tier first, free before premium.
  List<(int, SeasonPassTrack)> get claimables => [
    for (var t = 1; t <= config.tierCount; t++)
      for (final track in SeasonPassTrack.values)
        if (claimable(t, track)) (t, track),
  ];

  /// The tier the track opens at: the first one waiting, else the next.
  int get focusTier {
    final c = claimables;
    if (c.isNotEmpty) return c.first.$1;
    return (tier + 1).clamp(1, config.tierCount);
  }

  SeasonPassMissionState mission(SeasonPassMission m) {
    final today = vnDate(now);
    final (scopeKey, counts) = switch (m.type) {
      SeasonPassMissionType.daily => (
        '${m.key}@$today',
        status.dailyDate == today ? status.daily : const <String, int>{},
      ),
      SeasonPassMissionType.weekly => (
        '${m.key}@w$week',
        status.week == week ? status.weekly : const <String, int>{},
      ),
      SeasonPassMissionType.season => (m.key, status.season),
    };
    final done = status.done.contains(scopeKey);
    final cur = done ? m.target : (counts[m.goal] ?? 0).clamp(0, m.target);
    return SeasonPassMissionState(m, cur, done);
  }

  /// XP the server gave today from daily missions (`dailyMaxXP` banner).
  int get dailyXp => [
    for (final m in config.missions)
      if (m.type == SeasonPassMissionType.daily && mission(m).done) m.xp,
  ].fold(0, (a, b) => a + b);

  bool get dailyCapped => config.dailyMaxXp > 0 && dailyXp >= config.dailyMaxXp;
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
/// `balance`, `too-late`, `flagged`.
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
