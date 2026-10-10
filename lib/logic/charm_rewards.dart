import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/charm_board.dart';
import '../data/economy.dart';
import '../data/pet_items.dart';
import '../save/game_state.dart';
import 'mailbox.dart';
import 'pet.dart';
import 'rewards.dart';

/// Season rewards of the Mị lực board (Duyệt thưởng).
///
/// When a season is over an admin looks at the board (top 10 first), then
/// presses "Duyệt thưởng". That writes ONE mail per ranked player into the
/// existing gift mailbox (`mails/{id}`): the reward is a normal
/// [RewardBundle], so claiming it goes through the same
/// `MailboxFeed.claim` + `ShopSession.grantRewards` path as every other
/// mail (once per account, never doubled).
///
/// One grant per player per period comes from the mail id:
/// [charmRewardMailId] = `bxh_{period}_{uid}`. The rules let an admin create
/// such a mail but never edit it, and the player's claimed mark is keyed by
/// the same id, so approving twice, or re-sending after a delete, cannot pay
/// twice.

/// Prefix of every leaderboard reward mail. firestore.rules checks it.
const charmRewardMailPrefix = 'bxh_';

/// `bxh_{period}_{uid}`.
String charmRewardMailId(String period, String uid) =>
    '$charmRewardMailPrefix${period}_$uid';

const charmRewardMailTitle = 'Thưởng xếp hạng Mị lực';

/// Mị lực of a saved game, recomputed from the save itself with the live
/// economy (pet base x stage multiplier + worn items). 0 with an empty slot.
/// The same arithmetic as the game's own score, capped like the board.
int recomputeCharm(GameState state, Economy e) {
  final id = state.petCharm;
  if (id == null) return 0;
  final owned = state.ownedPet(id);
  final def = e.pet(id);
  if (owned == null || def == null) return 0;
  final score = petCharmScore(
    def,
    owned.stage,
    multipliers: e.charmStageMultiplier,
    itemCharm: wornItemsCharm(owned.worn, e.petItemRules, e.petItem),
  );
  return score.clamp(0, charmBoardMaxCharm);
}

/// What one reward line pays: Pha lê and Giọt hoa as listed, and one pet
/// item of the line's tier, picked at random inside the tier (the same item
/// may come up for many players; nothing is converted when a player already
/// owns it, resale is the normal 30%).
RewardBundle charmRewardBundle(
  CharmBoardReward line,
  Economy e,
  Random random,
) {
  final tier = PetItemTier.fromKey(line.itemTier);
  final pool = tier == null
      ? const <PetItemDef>[]
      : [
          for (final item in e.petItems)
            if (item.tier == tier) item,
        ];
  return RewardBundle([
    if (line.phaLe > 0) RewardItem.phaLe(line.phaLe),
    if (line.giotHoa > 0) RewardItem.giotHoa(line.giotHoa),
    if (pool.isNotEmpty)
      RewardItem.petItem(pool[random.nextInt(pool.length)].id),
  ]);
}

/// The letter that carries a player's season reward.
GameMail charmRewardMail({
  required String period,
  required int rank,
  required String uid,
  required RewardBundle rewards,
}) => GameMail(
  id: charmRewardMailId(period, uid),
  title: charmRewardMailTitle,
  body:
      'Bạn đứng hạng $rank ở bảng xếp hạng Mị lực mùa $period. '
      'Quà thưởng đã được duyệt, nhận ngay nhé!',
  target: uid,
  rewards: rewards,
);

/// One line of the review: the stored board row next to what the player's
/// saved game says today.
@immutable
class CharmReviewRow {
  const CharmReviewRow({
    required this.row,
    this.save,
    this.recomputed,
    this.granted = false,
  });

  final CharmBoardRow row;

  /// The player's saved game, null when it could not be read.
  final GameState? save;

  /// Mị lực recomputed from [save], null when there is no readable save.
  final int? recomputed;

  /// A reward mail for this player and period already exists.
  final bool granted;

  int get rank => row.rank;
  CharmBoardEntry get entry => row.entry;

  /// The stored charm and the recomputed one differ (or there was no save to
  /// check): the admin should look before paying.
  bool get needsLook => recomputed == null || recomputed != entry.charm;

  /// The payout would HOLD this row for the admin: the board claims more
  /// than the save backs, or more than the cap. A board value at or below the
  /// recomputed one is not held: the recomputed value is what gets paid.
  bool get willHold =>
      recomputed != null &&
      (entry.charm > recomputed! || entry.charm > charmBoardMaxCharm);

  String? get savedPetId => save?.petCharm;
  int? get savedStage {
    final id = savedPetId;
    return id == null ? null : save?.ownedPet(id)?.stage;
  }

  Map<String, String> get savedWorn {
    final id = savedPetId;
    return id == null ? const {} : (save?.ownedPet(id)?.worn ?? const {});
  }

  CharmReviewRow withGranted() => CharmReviewRow(
    row: row,
    save: save,
    recomputed: recomputed,
    granted: true,
  );
}

/// Admin side of the season reward: saves of the ranked players, the rewards
/// already written, and the one create-only write.
abstract class CharmRewardStore {
  /// Saved games of [uids]; a player without a readable save is left out.
  Future<Map<String, GameState>> saves(List<String> uids);

  /// The uids of [uids] that already have a reward mail for [period].
  Future<Set<String>> granted(String period, List<String> uids);

  /// Writes [mail] only if no mail with that id exists. True when this call
  /// created it, false when it was already there (never overwritten).
  Future<bool> grant(GameMail mail);
}

/// In-memory store for tests and previews, with the same create-only rule.
class MemoryCharmRewardStore implements CharmRewardStore {
  MemoryCharmRewardStore({Map<String, GameState>? saves})
    : _saves = saves ?? {};

  final Map<String, GameState> _saves;
  final Map<String, GameMail> mails = {};

  /// Set to make [grant] fail for these uids.
  final Set<String> failFor = {};

  @override
  Future<Map<String, GameState>> saves(List<String> uids) async => {
    for (final uid in uids)
      if (_saves[uid] != null) uid: _saves[uid]!,
  };

  @override
  Future<Set<String>> granted(String period, List<String> uids) async => {
    for (final uid in uids)
      if (mails.containsKey(charmRewardMailId(period, uid))) uid,
  };

  @override
  Future<bool> grant(GameMail mail) async {
    if (failFor.contains(mail.target)) throw StateError('write failed');
    if (mails.containsKey(mail.id)) return false;
    mails[mail.id] = mail;
    return true;
  }
}

/// Reads a `users/{uid}.progress` map into a [GameState] (null if broken).
GameState? decodeProgress(Object? progress) {
  if (progress is! Map) return null;
  try {
    return GameState.decode(jsonEncode(progress));
  } catch (_) {
    return null;
  }
}

enum ReviewLoad { idle, loading, ready, error }

/// Where a season is at [now] given its end (the charm_board/{period}.endsAt,
/// or the config's end for the live period); unknown without an end.
SeasonPhase seasonPhaseAt(DateTime? end, DateTime now) {
  if (end == null) return SeasonPhase.unknown;
  if (now.isBefore(end)) return SeasonPhase.running;
  if (now.isBefore(end.add(charmBoardWriteGrace))) return SeasonPhase.grace;
  return SeasonPhase.ended;
}

/// Where the live season is when the admin looks at it.
enum SeasonPhase {
  /// No end time known (an old period, or no season start in the config).
  unknown,

  /// Before the end: the board still moves.
  running,

  /// Past the end but inside the write grace: a late write can still land.
  grace,

  /// Past the grace: the board is frozen.
  ended,
}

/// What "Duyệt thưởng" did.
@immutable
class CharmApproval {
  const CharmApproval({this.created = 0, this.already = 0, this.failed = 0});

  /// Mails written now.
  final int created;

  /// Players who already had their reward (an earlier approval).
  final int already;

  /// Writes that failed; pressing the button again retries only these.
  final int failed;
}

/// The admin review of one period (`/quan-tri`, Xếp hạng Mị lực): load the board,
/// check each row against the saved game, skip anyone suspicious, approve.
class CharmReviewController extends ChangeNotifier {
  CharmReviewController({
    required this.board,
    required this.store,
    required this.economy,
    required this.period,
    Random? random,
  }) : _random = random ?? Random();

  final CharmBoardSource board;
  final CharmRewardStore store;
  final Economy economy;
  final Random _random;

  /// The period under review (editable in the panel).
  String period;

  ReviewLoad load = ReviewLoad.idle;
  List<CharmReviewRow> rows = const [];

  /// Players the admin took out of this approval. A row whose recomputed Mị
  /// lực is under the minimum (or whose save cannot be read, or has no pet)
  /// starts ticked here; the admin can untick it.
  final Set<String> skipped = {};

  String? _loadedPeriod;
  Set<String> _seenUids = {};

  bool approving = false;
  CharmApproval? lastApproval;

  CharmBoardConfig get config => economy.charmBoard;

  /// The first 10, shown big.
  List<CharmReviewRow> get top => rows.take(10).toList();
  List<CharmReviewRow> get rest => rows.skip(10).toList();

  /// The recomputed Mị lực is under the minimum to rank, the save could not
  /// be read, or the Mị lực slot has no pet: no reward unless the admin says so.
  bool underMin(CharmReviewRow r) =>
      r.recomputed == null || r.recomputed! < config.minCharm;

  /// Rows flagged by [underMin] (counted in the summary).
  List<CharmReviewRow> get flagged => [
    for (final r in rows)
      if (underMin(r)) r,
  ];

  /// How many flagged rows are still ticked "Bỏ qua" now.
  int get flaggedSkipped =>
      flagged.where((r) => skipped.contains(r.entry.uid)).length;

  /// Where the season stands at [now] (the live period only).
  SeasonPhase seasonPhase(DateTime now) =>
      seasonPhaseAt(period == config.periodKey ? config.seasonEnd : null, now);

  bool paysRank(CharmReviewRow r) => config.rewardFor(r.rank) != null;

  /// Rows an approval would write now.
  List<CharmReviewRow> get payable => [
    for (final r in rows)
      if (paysRank(r) && !r.granted && !skipped.contains(r.entry.uid)) r,
  ];

  int get alreadyPaid => rows.where((r) => r.granted).length;

  Future<void> loadBoard() async {
    if (!isValidPeriodKey(period)) {
      load = ReviewLoad.error;
      notifyListeners();
      return;
    }
    load = ReviewLoad.loading;
    lastApproval = null;
    notifyListeners();
    try {
      final top = await board.top(period: period, limit: config.limit);
      final uids = [for (final r in top) r.entry.uid];
      final saves = await store.saves(uids);
      final paid = await store.granted(period, uids);
      rows = [
        for (final r in top)
          CharmReviewRow(
            row: r,
            save: saves[r.entry.uid],
            recomputed: saves[r.entry.uid] == null
                ? null
                : recomputeCharm(saves[r.entry.uid]!, economy),
            granted: paid.contains(r.entry.uid),
          ),
      ];
      // The same period reloaded keeps the admin's ticks; a new period starts
      // from the flagged rows only. A row that was not on the board before
      // and is flagged now is ticked; one the admin unticked stays unticked.
      final sameBoard = _loadedPeriod == period;
      final before = sameBoard ? Set<String>.from(_seenUids) : <String>{};
      if (!sameBoard) skipped.clear();
      skipped.removeWhere((uid) => !uids.contains(uid));
      for (final r in rows) {
        if (underMin(r) && !before.contains(r.entry.uid)) {
          skipped.add(r.entry.uid);
        }
      }
      _seenUids = uids.toSet();
      _loadedPeriod = period;
      load = ReviewLoad.ready;
    } catch (_) {
      load = ReviewLoad.error;
    }
    notifyListeners();
  }

  void toggleSkip(String uid) {
    if (!skipped.add(uid)) skipped.remove(uid);
    notifyListeners();
  }

  /// Writes one reward mail for every payable row (the rows on screen are
  /// what the admin reviewed). Safe to press twice: a player who already has
  /// the mail is counted as `already` and nothing is written for them.
  Future<CharmApproval> approve() async {
    if (approving || load != ReviewLoad.ready) {
      return const CharmApproval();
    }
    approving = true;
    notifyListeners();
    var created = 0;
    var already = 0;
    var failed = 0;
    final done = <String>{};
    for (final r in payable) {
      final line = config.rewardFor(r.rank)!;
      final bundle = charmRewardBundle(line, economy, _random);
      if (bundle.isEmpty) continue;
      final mail = charmRewardMail(
        period: period,
        rank: r.rank,
        uid: r.entry.uid,
        rewards: bundle,
      );
      try {
        if (await store.grant(mail)) {
          created++;
        } else {
          already++;
        }
        done.add(r.entry.uid);
      } catch (_) {
        failed++;
      }
    }
    rows = [
      for (final r in rows) done.contains(r.entry.uid) ? r.withGranted() : r,
    ];
    approving = false;
    lastApproval = CharmApproval(
      created: created,
      already: already,
      failed: failed,
    );
    notifyListeners();
    return lastApproval!;
  }
}

/// The rank a season-reward letter names ("Bạn đứng hạng 7 ..."), or null for
/// any other letter. The reward popup of an item says "Hạng 7 · mùa vừa rồi".
int? charmMailRank(GameMail mail) {
  if (!mail.id.startsWith('bxh_')) return null;
  final m = RegExp(r'hạng (\d+)').firstMatch(mail.body);
  return m == null ? null : int.tryParse(m.group(1)!);
}
