import 'package:flutter/foundation.dart';

import '../data/economy.dart';
import '../data/rating_board.dart';
import 'charm_rewards.dart';
import 'mailbox.dart';
import 'price_format.dart';
import 'rewards.dart';

/// Bảng Đánh giá periods ("rating-2", ...) are paid by
/// functions/rating_payout.js into `rating_board/{period}`; the admin page
/// shows and releases them like a Mị lực season.
bool isRatingPeriod(String period) => period.startsWith('rating-');

/// Pha lê, giọt hoa, xu of a rating reward line, only the non-zero ones
/// (functions/rating_payout.js ratingRewardItems).
RewardBundle ratingRewardBundle(RatingBoardReward line) => RewardBundle([
  if (line.phaLe > 0) RewardItem.phaLe(line.phaLe),
  if (line.giotHoa > 0) RewardItem.giotHoa(line.giotHoa),
  if (line.coins > 0) RewardItem.coins(line.coins),
]);

/// Nhất's season.reward.mail_title with {board_name} = season.board.review
/// and season.reward.review.mail_body with {reward_list}: the non-zero items,
/// then the title (season.reward.review.title_line, lower-case inside the
/// list as in her example). Same text as functions/rating_payout.js
/// ratingMailText.
({String title, String body}) ratingMailText({
  required int rank,
  required RatingBoardReward line,
}) {
  final parts = [
    if (line.phaLe > 0) '${coinFull(line.phaLe)} Pha lê',
    if (line.giotHoa > 0) '${coinFull(line.giotHoa)} giọt hoa',
    if (line.coins > 0) '${coinFull(line.coins)} xu',
    if (line.badge.isNotEmpty) 'danh hiệu "${line.badge}"',
  ];
  return (
    title: 'Thưởng mùa ${SeasonBoardName.review}: hạng $rank',
    body:
        'Chúc mừng bạn đạt hạng $rank bảng Đánh giá mùa này! '
        'Quà của bạn: ${listVi(parts)}.',
  );
}

/// The rating reward mail `bxh_{period}_{uid}` (same id rule as Mị lực).
GameMail ratingRewardMail({
  required String period,
  required int rank,
  required String uid,
  required RatingBoardReward line,
  required RewardBundle rewards,
}) {
  final text = ratingMailText(rank: rank, line: line);
  return GameMail(
    id: charmRewardMailId(period, uid),
    title: text.title,
    body: text.body,
    target: uid,
    rewards: rewards,
  );
}

/// What the automatic season payout (functions/payout.js) did with one row.
/// Written to `charm_board/{period}/review/{uid}`.
enum PayoutStatus {
  /// The reward mail exists.
  sent('sent'),

  /// Anomalous: no mail, waiting for the admin ("Duyệt thưởng").
  held('held'),

  /// Dropped from the board (no save, no pet, under 20): no reward.
  skipped('skipped'),

  /// The mail write failed; the next tick retries.
  failed('failed'),

  /// A held row the admin paid.
  released('released');

  const PayoutStatus(this.key);
  final String key;

  static PayoutStatus? fromKey(Object? raw) {
    for (final s in values) {
      if (s.key == raw) return s;
    }
    return null;
  }
}

/// Why a row was held (`flags`) or dropped (`reason`) by the payout.
String payoutFlagText(String key) => switch (key) {
  'mismatch' => 'Bảng ghi cao hơn Mị lực tính lại',
  // Only older review lines carry it: the 600 cap is gone (17/10/2026).
  'over_cap' => 'Mị lực trên 600',
  'new_account' => 'Tài khoản lập trong mùa',
  'no_save' => 'Không đọc được save',
  'no_pet' => 'Ô Mị lực không có thú',
  'under_min' => 'Dưới mức tối thiểu',
  _ => key,
};

@immutable
class PayoutLine {
  const PayoutLine({
    required this.uid,
    required this.status,
    this.displayName = '',
    this.rank = 0,
    this.stored = 0,
    this.recomputed = 0,
    this.flags = const [],
    this.reason,
    this.petId = '',
    this.stage = 0,
    this.mailId,
    this.items,
  });

  final String uid;
  final PayoutStatus status;
  final String displayName;

  /// 0 for a dropped row.
  final int rank;

  /// What the board said / what the save gives.
  final int stored;
  final int recomputed;

  /// Why a held row is held.
  final List<String> flags;

  /// Why a dropped row was dropped.
  final String? reason;
  final String petId;
  final int stage;
  final String? mailId;

  /// What the server picked for a held row (review line `items`, the pet
  /// item by functions/payout.js pickSeasonItem). "Duyệt thưởng" sends it.
  /// Null on lines written before the server stored it.
  final RewardBundle? items;

  /// The words shown next to the row.
  List<String> get why => [
    for (final f in flags) payoutFlagText(f),
    if (reason != null) payoutFlagText(reason!),
  ];

  PayoutLine copyWith({PayoutStatus? status}) => PayoutLine(
    uid: uid,
    status: status ?? this.status,
    displayName: displayName,
    rank: rank,
    stored: stored,
    recomputed: recomputed,
    flags: flags,
    reason: reason,
    petId: petId,
    stage: stage,
    mailId: mailId,
    items: items,
  );
}

/// `charm_board/{period}.payout`, the summary of the run, and the season end.
@immutable
class PayoutMeta {
  const PayoutMeta({
    this.status,
    this.endsAt,
    this.at,
    this.sent = 0,
    this.held = 0,
    this.skipped = 0,
    this.failed = 0,
  });

  /// `done`, `partial`, or null while the payout has not run.
  final String? status;
  final DateTime? endsAt;
  final DateTime? at;
  final int sent;
  final int held;
  final int skipped;
  final int failed;

  bool get ran => status == 'done' || status == 'partial';
}

/// Admin side of the automatic payout: what it did, the kill switch, and the
/// release of a held row.
abstract class CharmPayoutStore {
  Future<PayoutMeta> meta(String period);
  Future<List<PayoutLine>> lines(String period);

  /// `config/charmPayout.autoPayout`; true when the doc is missing.
  Future<bool> autoPayout();
  Future<void> setAutoPayout(bool on);

  /// Marks a held line paid by the admin.
  Future<void> markReleased(String period, String uid);

  /// `rating_board/{period}.champion`: the #1 of a rating season once paid.
  Future<void> markChampion(String period, String uid);

  /// After a held #1 of [period] is released, the server moves that board's
  /// champion title to it (callable titleRelease, functions/titles.js).
  /// False when the call failed (the reward is sent either way).
  Future<bool> releaseTitle(String period);
}

/// In-memory store for tests and previews.
class MemoryCharmPayoutStore implements CharmPayoutStore {
  MemoryCharmPayoutStore({
    this.metas = const {},
    Map<String, List<PayoutLine>>? lines,
    this.auto = true,
  }) : _lines = lines ?? {};

  final Map<String, PayoutMeta> metas;
  final Map<String, List<PayoutLine>> _lines;
  bool auto;
  final List<(String, String)> released = [];
  final Map<String, String> champions = {};

  /// Periods whose title was released, in order.
  final List<String> titleReleases = [];

  @override
  Future<bool> releaseTitle(String period) async {
    titleReleases.add(period);
    return true;
  }

  @override
  Future<PayoutMeta> meta(String period) async =>
      metas[period] ?? const PayoutMeta();

  @override
  Future<List<PayoutLine>> lines(String period) async => [...?_lines[period]];

  @override
  Future<bool> autoPayout() async => auto;

  @override
  Future<void> setAutoPayout(bool on) async => auto = on;

  @override
  Future<void> markChampion(String period, String uid) async =>
      champions[period] = uid;

  @override
  Future<void> markReleased(String period, String uid) async {
    released.add((period, uid));
    final list = _lines[period];
    if (list == null) return;
    _lines[period] = [
      for (final l in list)
        l.uid == uid ? l.copyWith(status: PayoutStatus.released) : l,
    ];
  }
}

/// The admin page's view of one season's payout: sent / skipped / held rows,
/// the kill switch, and releasing held rows one by one.
class CharmPayoutController extends ChangeNotifier {
  CharmPayoutController({
    required this.payout,
    required this.rewards,
    required this.economy,
    required this.period,
  });

  final CharmPayoutStore payout;
  final CharmRewardStore rewards;
  final Economy economy;
  String period;

  bool loading = false;
  bool failed = false;
  PayoutMeta meta = const PayoutMeta();
  List<PayoutLine> lines = const [];
  bool autoPayout = true;

  /// The switch is being written.
  bool savingSwitch = false;

  /// The uids being released right now (double taps are ignored).
  final Set<String> releasing = {};

  List<PayoutLine> get held => _of(PayoutStatus.held);
  List<PayoutLine> get sent => [
    ..._of(PayoutStatus.sent),
    ..._of(PayoutStatus.released),
  ];
  List<PayoutLine> get skipped => _of(PayoutStatus.skipped);
  List<PayoutLine> get failedLines => _of(PayoutStatus.failed);

  List<PayoutLine> _of(PayoutStatus s) => [
    for (final l in lines)
      if (l.status == s) l,
  ];

  Future<void> load() async {
    loading = true;
    failed = false;
    notifyListeners();
    try {
      meta = await payout.meta(period);
      lines = await payout.lines(period)
        ..sort((a, b) {
          if (a.rank == 0 || b.rank == 0) return b.rank.compareTo(a.rank);
          return a.rank.compareTo(b.rank);
        });
      autoPayout = await payout.autoPayout();
    } catch (_) {
      failed = true;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> setAutoPayout(bool on) async {
    if (savingSwitch) return;
    savingSwitch = true;
    notifyListeners();
    try {
      await payout.setAutoPayout(on);
      autoPayout = on;
    } catch (_) {
      // The switch snaps back: the write did not happen.
    }
    savingSwitch = false;
    notifyListeners();
  }

  /// "Duyệt thưởng" on one held row: writes that player's reward mail
  /// (create-only, so pressing twice cannot pay twice) with the items the
  /// server picked for the line (an older line without them: the same
  /// period + uid pick, ownership unknown), then marks the line released.
  /// False when it could not be done.
  Future<bool> release(PayoutLine line) async {
    if (line.status != PayoutStatus.held || line.rank < 1) return false;
    if (!releasing.add(line.uid)) return false;
    notifyListeners();
    var ok = false;
    try {
      ok = isRatingPeriod(period)
          ? await _releaseRating(line)
          : await _releaseCharm(line);
    } catch (_) {
      ok = false;
    }
    releasing.remove(line.uid);
    if (ok) {
      lines = [
        for (final l in lines)
          l.uid == line.uid ? l.copyWith(status: PayoutStatus.released) : l,
      ];
    }
    notifyListeners();
    return ok;
  }

  /// A held Mị lực line: the stored items (else the period + uid pick),
  /// Nhất's season letter, then released.
  Future<bool> _releaseCharm(PayoutLine line) async {
    final reward = economy.charmBoard.rewardFor(line.rank);
    if (reward == null) return false;
    final stored = line.items;
    final bundle = stored != null && stored.isNotEmpty
        ? stored
        : charmRewardBundle(reward, economy, period: period, uid: line.uid);
    if (bundle.isNotEmpty) {
      await rewards.grant(
        charmRewardMail(
          period: period,
          rank: line.rank,
          uid: line.uid,
          rewards: bundle,
          line: reward,
          economy: economy,
        ),
      );
    }
    await payout.markReleased(period, line.uid);
    await _releaseTitle(line, economy.titles.charm);
    return true;
  }

  /// A released #1 takes the board's champion title (server side). A failed
  /// call sets [titleReleaseFailed]: the admin page shows it with a retry
  /// ([retryTitleRelease]); the reward is sent and the line released either
  /// way.
  Future<void> _releaseTitle(
    PayoutLine line,
    ChampionTitleConfig? title,
  ) async {
    if (title == null || line.rank != title.rank) return;
    titleReleaseFailed = !await payout.releaseTitle(period);
  }

  /// Whether the last titleRelease call failed (the title did not move).
  bool titleReleaseFailed = false;

  /// Calls titleRelease again after a failure. True when it went through.
  Future<bool> retryTitleRelease() async {
    if (!titleReleaseFailed) return true;
    var ok = false;
    try {
      ok = await payout.releaseTitle(period);
    } catch (_) {
      ok = false;
    }
    titleReleaseFailed = !ok;
    notifyListeners();
    return ok;
  }

  /// A held rating line: the items the server stored (else the line of
  /// economy.json ratingBoard.rewards), Nhất's rating letter, then released;
  /// a #1 also becomes the season's champion and takes the title.
  Future<bool> _releaseRating(PayoutLine line) async {
    final reward = economy.ratingBoard.rewardFor(line.rank);
    if (reward == null) return false;
    final stored = line.items;
    final bundle = stored != null && stored.isNotEmpty
        ? stored
        : ratingRewardBundle(reward);
    if (bundle.isNotEmpty) {
      await rewards.grant(
        ratingRewardMail(
          period: period,
          rank: line.rank,
          uid: line.uid,
          line: reward,
          rewards: bundle,
        ),
      );
    }
    await payout.markReleased(period, line.uid);
    if (line.rank == 1) await payout.markChampion(period, line.uid);
    await _releaseTitle(line, economy.titles.review);
    return true;
  }
}
