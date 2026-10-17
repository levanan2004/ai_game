/// Champion titles (An 17/10 19:46, Hà Phương 19:47, functions/titles.js):
/// the #1 of each board at a season's close takes that board's title from
/// its previous holder ("title transfers"); a player who wins again keeps it.
/// Each player's profile counts the seasons won ("×n").
///
///   titles/{titleId}            {holderUid, period, since, seasonEnd, ...}
///   public_profiles/{uid}       titleStats.{titleId} {timesWon, lastPeriod}
///                               (or {permanent: true, since, retro} for a
///                               customers-served milestone, functions/
///                               milestones.js), customers, pinnedTitle,
///                               bestRank.{charm|review}
///   milestone_state/{uid}       the owner's counter notes (note, noteDate)
///
/// All server-written. Names come from economy.json
/// (ratingBoard.championTitle.name, leaderboard.championTitle.name,
/// milestoneTitles.tiers[].name), else Nhất's text keys ([TitleText]).
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
  static String count(int n) => '$n danh hiệu'; // profile.titles.count
  static const seeAll = 'Xem tất cả'; // profile.titles.see_all
  static const empty =
      'Chưa có danh hiệu nào. Đứng hạng 1 bảng Đánh giá hoặc bảng Mị lực khi hết mùa để nhận danh hiệu.'; // profile.titles.empty
  static const emptyOther =
      'Tiệm này chưa có danh hiệu nào.'; // profile.titles.empty_other
  static const locked = 'Chưa đạt'; // profile.titles.badge.locked
  static const permanent = 'Vĩnh viễn'; // profile.titles.badge.permanent
  static const lockedHintRating =
      'Đứng hạng 1 bảng Đánh giá khi hết mùa để nhận danh hiệu này.'; // profile.titles.locked_hint.rating
  static const lockedHintCharm =
      'Đứng hạng 1 bảng Mị lực khi hết mùa để nhận danh hiệu này.'; // profile.titles.locked_hint.charm
  static String wearToast(String title) =>
      'Đã đeo "$title". Danh hiệu hiện cạnh tên bạn trên các bảng xếp hạng.'; // profile.titles.wear_toast
  static const customers1k = 'Người Bán Hoa Tận Tâm'; // title.customers_1k
  static const customers10k = 'Chủ Shop Được Yêu Mến'; // title.customers_10k
  static const customers100k = 'Chủ Shop Huyền Thoại'; // title.customers_100k
  static String customersDesc(String n) =>
      'Đã bán hoa cho $n khách'; // title.customers.desc
  static String customersProgress(String current, String target) =>
      'Bán cho $current/$target khách'; // title.customers.progress
  static String unlockedToast(String n, String title) =>
      'Chúc mừng! Tiệm đã bán hoa cho $n khách. Bạn nhận danh hiệu "$title".'; // title.customers.unlocked_toast
  static String customersLockedHint(String target) =>
      'Bán hoa cho $target khách để nhận danh hiệu này.'; // title.customers.locked_hint
  static String retroToast(String n, String title) =>
      'Tiệm của bạn đã phục vụ $n khách từ trước, nên nhận luôn danh hiệu "$title".'; // title.customers.retro_toast
  static const customersOnline =
      'Tính cả khách đặt hoa online.'; // title.customers.desc_online
  static const customersNotCounted =
      'Ngày chơi này quá ngắn nên khách hôm nay chưa được tính vào danh hiệu.'; // title.customers.not_counted
  static const customersDailyCap =
      'Hôm nay đã đủ số khách được tính cho danh hiệu. Mai bạn tiếp tục nhé.'; // title.customers.daily_cap
  static const rewardPreview =
      'Xem trước danh hiệu'; // leaderboard.reward.title_preview
  static String rewardTitleLine(String name) =>
      'Danh hiệu "$name"'; // leaderboard.reward.title_line
  static const rewardTitleNote =
      'Chỉ hạng 1 mỗi mùa'; // leaderboard.reward.title_note
}

/// The fixed title ids (functions/titles.js TITLE_IDS) and the milestone
/// tiers of economy.json milestoneTitles (functions/milestones.js).
abstract final class TitleIds {
  static const rating = 'de_nhat_goi_hoa';
  static const charm = 'mi_luc_nhat_troi';
  static const customers1k = 'title_khach_1k';
  static const customers10k = 'title_khach_10k';
  static const customers100k = 'title_khach_100k';
}

/// One customers-served milestone (milestoneTitles.tiers[]): permanent.
class MilestoneTier {
  const MilestoneTier({
    required this.id,
    required this.name,
    required this.threshold,
  });

  final String id;
  final String name;
  final int threshold;

  /// The tiers of [json] (the milestoneTitles block) by threshold.
  static List<MilestoneTier> listFrom(Object? json) {
    final tiers = json is Map ? json['tiers'] : null;
    final out = <MilestoneTier>[
      if (tiers is List)
        for (final t in tiers)
          if (t is Map &&
              t['id'] is String &&
              t['name'] is String &&
              t['threshold'] is num &&
              (t['threshold'] as num) >= 1)
            MilestoneTier(
              id: t['id'] as String,
              name: t['name'] as String,
              threshold: (t['threshold'] as num).toInt(),
            ),
    ]..sort((a, b) => a.threshold.compareTo(b.threshold));
    return out;
  }
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
  const ChampionTitles({this.review, this.charm, this.milestones = const []});

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
      milestones: MilestoneTier.listFrom(j['milestoneTitles']),
    );
  }

  final ChampionTitleConfig? review;
  final ChampionTitleConfig? charm;

  /// Customers-served milestones (permanent), by threshold.
  final List<MilestoneTier> milestones;

  MilestoneTier? milestone(String id) {
    for (final m in milestones) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// The cabinet's cells: both champion titles, then the milestones.
  List<String> get cabinet => [
    TitleIds.rating,
    TitleIds.charm,
    for (final m in milestones) m.id,
  ];

  ChampionTitleConfig? byId(String id) => switch (id) {
    TitleIds.rating => review,
    TitleIds.charm => charm,
    _ => null,
  };

  /// The display name of [id]: the config's, else Nhất's key, else ''.
  String nameOf(String id) =>
      byId(id)?.name ??
      milestone(id)?.name ??
      switch (id) {
        TitleIds.rating => TitleText.ratingChampion,
        TitleIds.charm => TitleText.charmChampion,
        TitleIds.customers1k => TitleText.customers1k,
        TitleIds.customers10k => TitleText.customers10k,
        TitleIds.customers100k => TitleText.customers100k,
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
    this.retro = false,
  });

  final int timesWon;
  final String lastPeriod;

  /// A permanent title (a customers-served milestone): held for good.
  final bool permanent;

  /// Reached from the starting count of old customers
  /// (title.customers.retro_toast rather than unlocked_toast).
  final bool retro;

  static TitleStat? fromMap(Object? m) {
    if (m is! Map) return null;
    final n = m['timesWon'];
    final p = m['lastPeriod'];
    return TitleStat(
      timesWon: n is num && n > 0 ? n.toInt() : 0,
      lastPeriod: p is String ? p : '',
      permanent: m['permanent'] == true,
      retro: m['retro'] == true,
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
    this.customers = 0,
    this.note = MilestoneNote.none,
  });

  static const empty = PlayerTitles();

  /// Customers counted on the server (public_profiles.customers).
  final int customers;

  /// Today's counter note on your own profile (milestone_state).
  final MilestoneNote note;

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
    Map<String, TitleHolder> holders, {
    MilestoneNote note = MilestoneNote.none,
  }) {
    final p = profile ?? const {};
    final c = p['customers'];
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
      customers: c is num && c > 0 ? c.toInt() : 0,
      note: note,
    );
  }

  /// The same titles with [id] pinned.
  PlayerTitles withPin(String id) => PlayerTitles(
    uid: uid,
    stats: stats,
    pinned: id,
    bestRank: bestRank,
    holders: holders,
    customers: customers,
    note: note,
  );

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

/// milestone_state's note of today (functions/milestones.js).
enum MilestoneNote {
  none,

  /// A game day too short: title.customers.not_counted.
  short,

  /// The real-day cap was reached: title.customers.daily_cap.
  cap;

  /// From milestone_state {note, noteDate}; only a note of [today] (VN date
  /// "yyyy-MM-dd") counts.
  static MilestoneNote fromState(Map<String, Object?>? d, String today) {
    if (d == null || d['noteDate'] != today) return none;
    return switch (d['note']) {
      'short' => short,
      'cap' => cap,
      _ => none,
    };
  }
}

/// Today's date in Vietnam as "yyyy-MM-dd" (milestones.js vnDate).
String vnDateKey(DateTime now) {
  final d = now.toUtc().add(const Duration(hours: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// A milestone just reached, for its toast (title.customers.*_toast).
class TitleUnlock {
  const TitleUnlock({required this.tier, required this.retro});
  final MilestoneTier tier;
  final bool retro;
}

/// Milestones [titles] holds that are not in [seen] (the device's record).
List<TitleUnlock> newUnlocks(
  ChampionTitles config,
  PlayerTitles titles,
  Set<String> seen,
) => [
  for (final m in config.milestones)
    if ((titles.stats[m.id]?.permanent ?? false) && !seen.contains(m.id))
      TitleUnlock(tier: m, retro: titles.stats[m.id]!.retro),
];
