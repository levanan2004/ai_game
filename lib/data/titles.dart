/// Champion titles (An 17/10 19:46, Hà Phương 19:47, functions/titles.js):
/// the #1 of each board at a season's close takes that board's title from
/// its previous holder ("title transfers"); a player who wins again keeps it.
/// Each player's profile counts the seasons won ("×n").
///
///   titles/{titleId}            {holderUid, period, since, seasonEnd, ...}
///   public_profiles/{uid}       titleStats.{titleId} {timesWon, lastPeriod}
///                               (or {permanent: true} for a permanent title,
///                               e.g. the coming customers-served milestones),
///                               pinnedTitle, bestRank.{charm|review}
///
/// All server-written. Names come from economy.json
/// (ratingBoard.championTitle.name, leaderboard.championTitle.name), else
/// Nhất's text keys ([TitleText]).
library;

import 'season_clock.dart';

/// Nhất, chu_ho_so_chien_tich.md (verbatim).
abstract final class TitleText {
  static const ratingChampion = 'Đệ Nhất Gói Hoa'; // title.rating_champion
  static const charmChampion = 'Mị Lực Nhất Trời'; // title.charm_champion
  static String ratingDesc(int month, int year) =>
      'Hạng 1 bảng Đánh giá · mùa $month/$year'; // title.rating_champion.desc
  static String charmDesc(int month, int year) =>
      'Hạng 1 bảng Mị lực · mùa $month/$year'; // title.charm_champion.desc
  static String timesWon(int n) => 'Đã từng giữ $n mùa'; // title.times_won
  static String timesBadge(int n) => '×$n'; // title.times_badge
  static const sectionTitles = 'Danh hiệu'; // profile.section.titles
  static const wearing = 'Đang đeo'; // profile.titles.badge.wearing
  static const held = 'Đang giữ'; // profile.titles.badge.held
  static const lost = 'Đã từng giữ'; // profile.titles.badge.lost
  static const wear = 'Đeo danh hiệu này'; // profile.titles.wear
  static const unwear = 'Tháo danh hiệu'; // profile.titles.unwear
  static const wearLocked =
      'Chỉ người đang giữ danh hiệu mới đeo được.'; // profile.titles.wear_locked
  static String rewardTitleLine(String name) =>
      'Danh hiệu "$name"'; // leaderboard.reward.title_line
  static const rewardTitleNote =
      'Chỉ hạng 1 mỗi mùa'; // leaderboard.reward.title_note
}

/// The fixed title ids (functions/titles.js TITLE_IDS).
abstract final class TitleIds {
  static const rating = 'de_nhat_goi_hoa';
  static const charm = 'mi_luc_nhat_troi';
}

enum TitleBoard { review, charm }

/// One board's `championTitle` block: who gets it (rank) and its name.
class ChampionTitleConfig {
  const ChampionTitleConfig({
    required this.id,
    required this.board,
    required this.name,
    this.rank = 1,
  });

  final String id;
  final TitleBoard board;
  final String name;
  final int rank;

  bool coversRange(int from, int to) => rank >= from && rank <= to;

  /// [json] is the block; null without a usable name (no title then).
  static ChampionTitleConfig? fromJson(Object? json, TitleBoard board) {
    if (json is! Map) return null;
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final rank = json['rank'];
    return ChampionTitleConfig(
      id: board == TitleBoard.review ? TitleIds.rating : TitleIds.charm,
      board: board,
      name: name,
      rank: rank is num && rank >= 1 ? rank.toInt() : 1,
    );
  }
}

/// Both boards' titles from economy.json.
class ChampionTitles {
  const ChampionTitles({this.review, this.charm});

  factory ChampionTitles.fromEconomy(Map<String, dynamic> j) {
    Object? block(String k) =>
        j[k] is Map ? (j[k] as Map)['championTitle'] : null;
    return ChampionTitles(
      review: ChampionTitleConfig.fromJson(
        block('ratingBoard'),
        TitleBoard.review,
      ),
      charm: ChampionTitleConfig.fromJson(
        block('leaderboard'),
        TitleBoard.charm,
      ),
    );
  }

  final ChampionTitleConfig? review;
  final ChampionTitleConfig? charm;

  ChampionTitleConfig? byId(String id) => switch (id) {
    TitleIds.rating => review,
    TitleIds.charm => charm,
    _ => null,
  };

  /// The display name of [id]: the config's, else Nhất's key, else ''.
  String nameOf(String id) =>
      byId(id)?.name ??
      switch (id) {
        TitleIds.rating => TitleText.ratingChampion,
        TitleIds.charm => TitleText.charmChampion,
        _ => '',
      };
}

/// titles/{titleId}: who holds it now and for which season.
class TitleHolder {
  const TitleHolder({
    required this.titleId,
    required this.holderUid,
    this.period = '',
    this.seasonEnd,
  });

  final String titleId;
  final String holderUid;
  final String period;
  final DateTime? seasonEnd;

  /// [time] turns a Firestore Timestamp (or DateTime) into a DateTime.
  static TitleHolder? fromMap(
    String id,
    Map<String, Object?> d, {
    DateTime? Function(Object?)? time,
  }) {
    final uid = d['holderUid'];
    if (uid is! String || uid.isEmpty) return null;
    final p = d['period'];
    final end = d['seasonEnd'];
    return TitleHolder(
      titleId: id,
      holderUid: uid,
      period: p is String ? p : '',
      seasonEnd: end is DateTime ? end : time?.call(end),
    );
  }
}

/// public_profiles/{uid}.titleStats.{titleId}.
class TitleStat {
  const TitleStat({
    this.timesWon = 0,
    this.lastPeriod = '',
    this.permanent = false,
  });

  final int timesWon;
  final String lastPeriod;

  /// A permanent title (milestones, not counted yet): held for good.
  final bool permanent;

  static TitleStat? fromMap(Object? m) {
    if (m is! Map) return null;
    final n = m['timesWon'];
    final p = m['lastPeriod'];
    return TitleStat(
      timesWon: n is num && n > 0 ? n.toInt() : 0,
      lastPeriod: p is String ? p : '',
      permanent: m['permanent'] == true,
    );
  }
}

/// public_profiles/{uid}.bestRank.{board}.
class BestRank {
  const BestRank({required this.rank, this.period = ''});
  final int rank;
  final String period;
}

/// One player's titles as the profile card shows them.
class PlayerTitles {
  const PlayerTitles({
    this.uid = '',
    this.stats = const {},
    this.pinned = '',
    this.bestRank = const {},
    this.holders = const {},
  });

  static const empty = PlayerTitles();

  final String uid;
  final Map<String, TitleStat> stats;

  /// pinnedTitle as stored; see [wearing].
  final String pinned;
  final Map<TitleBoard, BestRank> bestRank;

  /// titleId -> titles/{titleId} (every title, whoever holds it).
  final Map<String, TitleHolder> holders;

  /// From public_profiles/{uid} and the titles/ docs.
  factory PlayerTitles.fromMaps(
    String uid,
    Map<String, Object?>? profile,
    Map<String, TitleHolder> holders,
  ) {
    final p = profile ?? const {};
    final rawStats = p['titleStats'];
    final rawBest = p['bestRank'];
    final pin = p['pinnedTitle'];
    BestRank? best(Object? m) {
      if (m is! Map || m['rank'] is! num || (m['rank'] as num) < 1) return null;
      final per = m['period'];
      return BestRank(
        rank: (m['rank'] as num).toInt(),
        period: per is String ? per : '',
      );
    }

    return PlayerTitles(
      uid: uid,
      stats: {
        if (rawStats is Map)
          for (final e in rawStats.entries)
            if (e.key is String && TitleStat.fromMap(e.value) != null)
              e.key as String: TitleStat.fromMap(e.value)!,
      },
      pinned: pin is String ? pin : '',
      bestRank: {
        if (rawBest is Map) ...{
          TitleBoard.charm: ?best(rawBest['charm']),
          TitleBoard.review: ?best(rawBest['review']),
        },
      },
      holders: holders,
    );
  }

  /// Whether this player holds [id] now (the only state that can be worn).
  bool holds(String id) =>
      (stats[id]?.permanent ?? false) ||
      (uid.isNotEmpty && holders[id]?.holderUid == uid);

  int timesWon(String id) => stats[id]?.timesWon ?? 0;

  /// The title worn next to the name: the pin, only while held.
  String get wearing => pinned.isNotEmpty && holds(pinned) ? pinned : '';

  /// Titles to list on the card: held now or held before, the worn one
  /// first, then held, then the rest; champion titles in board order.
  List<String> get listed {
    final ids = <String>{
      for (final e in stats.entries)
        if (e.value.timesWon > 0 || e.value.permanent) e.key,
      for (final h in holders.values)
        if (h.holderUid == uid && uid.isNotEmpty) h.titleId,
    }.toList();
    int order(String id) => id == wearing ? 0 : (holds(id) ? 1 : 2);
    const board = [TitleIds.rating, TitleIds.charm];
    int pos(String id) => board.contains(id) ? board.indexOf(id) : board.length;
    ids.sort((a, b) {
      final c = order(a).compareTo(order(b));
      return c != 0 ? c : pos(a).compareTo(pos(b));
    });
    return ids;
  }
}

/// {month, year} of a season's last day in Vietnam ([end] is the next
/// Monday 00:00 VN), for title.*.desc ("mùa {month}/{year}").
({int month, int year}) titleSeasonMonth(DateTime end) {
  final d = end
      .toUtc()
      .subtract(const Duration(milliseconds: 1))
      .add(const Duration(hours: 7));
  return (month: d.month, year: d.year);
}

/// The detail line of [id] for [titles]: the season held now, else the last
/// season won (its end from [clock]). '' when no season is known.
String titleDetail(String id, PlayerTitles titles, SeasonClock? clock) {
  DateTime? end;
  final h = titles.holders[id];
  if (h != null && h.holderUid == titles.uid) end = h.seasonEnd;
  end ??= seasonEndOf(clock, titles.stats[id]?.lastPeriod ?? '');
  if (end == null) return '';
  final m = titleSeasonMonth(end);
  return switch (id) {
    TitleIds.rating => TitleText.ratingDesc(m.month, m.year),
    TitleIds.charm => TitleText.charmDesc(m.month, m.year),
    _ => '',
  };
}
