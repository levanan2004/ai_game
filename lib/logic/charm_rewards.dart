import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/charm_board.dart';
import '../data/economy.dart';
import '../data/pet_items.dart';
import '../save/game_state.dart';
import 'mailbox.dart';
import 'pet.dart';
import 'pot_bonus.dart';
import 'price_format.dart';
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

/// Rarity names as players see them (bxh.rar.*, same as Bxh.tierName and
/// functions/payout.js TIER_NAMES).
String seasonTierName(String tierKey) => switch (tierKey) {
  'hiem' => 'Hiếm',
  'suThi' => 'Sử thi',
  'huyenThoai' => 'Huyền thoại',
  _ => 'Thường',
};

/// ["a"] -> "a"; ["a", "b"] -> "a và b"; ["a", "b", "c"] -> "a, b và c".
String listVi(List<String> parts) {
  if (parts.length <= 1) return parts.join();
  return '${parts.sublist(0, parts.length - 1).join(', ')} và ${parts.last}';
}

/// "{fallback_amount}": "80 Pha lê" or "1.000.000 xu".
String seasonAmountText(RewardItem item) => item.kind == RewardKind.phaLe
    ? '${coinFull(item.amount)} Pha lê'
    : '${coinFull(item.amount)} xu';

/// What a player who owns the whole rarity gets instead (same dice as the
/// server, [charmRewardPick] with every item owned). Null: no items/price.
RewardItem? seasonFallback(
  Economy e,
  String tierKey, {
  required String period,
  required String uid,
}) {
  final tier = PetItemTier.fromKey(tierKey);
  if (tier == null) return null;
  final all = {
    for (final item in e.petItems)
      if (item.tier == tier) item.id,
  };
  final pick = charmRewardPick(
    e,
    tierKey,
    period: period,
    uid: uid,
    owned: all,
  );
  return pick == null || pick.kind == RewardKind.petItem ? null : pick;
}

/// Nhất's admin.season.reward_row; a rank without Pha lê or giọt hoa drops
/// that phrase.
String seasonAdminRewardRow(CharmBoardReward line) => [
  if (line.phaLe > 0) '${coinFull(line.phaLe)} Pha lê',
  if (line.giotHoa > 0) '${coinFull(line.giotHoa)} giọt hoa',
  if (PetItemTier.fromKey(line.itemTier) != null)
    '1 đồ pet ${seasonTierName(line.itemTier)} ngẫu nhiên (chưa có)',
].join(' · ');

/// Title and body of a season reward letter: Nhất's season.reward.mail_title,
/// mail_body and mail_body_fallback, verbatim, with a missing Pha lê or giọt
/// hoa phrase dropped. [rewards] is [charmRewardBundle] of [line] (its Pha lê
/// and giọt hoa, then the pick). Same text as functions/payout.js
/// seasonMailText.
({String title, String body}) seasonMailText({
  required int rank,
  required CharmBoardReward line,
  required RewardBundle rewards,
  required Economy e,
}) {
  final own = [
    if (line.phaLe > 0) '${coinFull(line.phaLe)} Pha lê',
    if (line.giotHoa > 0) '${coinFull(line.giotHoa)} giọt hoa',
  ];
  final rest = rewards.items.skip(own.length).toList();
  final pick = rest.isEmpty ? null : rest.first;
  // The #1 also lists its title (leaderboard.championTitle), last, worded
  // like the rating letter (season.reward.review.title_line, lower-case).
  final t = e.titles.charm;
  final titleGift = t != null && rank == t.rank
      ? 'danh hiệu "${t.name}"'
      : null;
  final head =
      'Chúc mừng bạn đạt hạng $rank bảng ${SeasonBoardName.charm} mùa này!';
  final title = 'Thưởng mùa ${SeasonBoardName.charm}: hạng $rank';
  if (pick != null && pick.kind != RewardKind.petItem) {
    final more = [...own, ?titleGift];
    final extra = more.isEmpty ? '' : ', kèm ${listVi(more)}';
    return (
      title: title,
      body:
          '$head Bạn đã có đủ đồ pet ${seasonTierName(line.itemTier)}, '
          'nên nhận ${seasonAmountText(pick)} thay thế$extra.',
    );
  }
  final name = pick == null
      ? null
      : (e.petItem(pick.id ?? '')?.nameVi ?? pick.id ?? '');
  final gifts = [...own, ?name, ?titleGift];
  return (
    title: title,
    body: gifts.isEmpty ? head : '$head Quà của bạn: ${listVi(gifts)}.',
  );
}

/// Mị lực of a saved game, recomputed from the save itself with the live
/// economy. 0 with an empty charm slot. Three parts, each kept under its
/// `charm.partMax` (no overall cap):
///   * the charm-slot pet: base x stage multiplier,
///   * the items that pet wears,
///   * every owned pot type once ([ownedPotsCharm]).
/// The game's own score and functions/charm.js use the same arithmetic.
int recomputeCharm(GameState state, Economy e) {
  final id = state.petCharm;
  if (id == null) return 0;
  final owned = state.ownedPet(id);
  final def = e.pet(id);
  if (owned == null || def == null) return 0;
  return petAndItemsCharm(e, def, owned) + ownedPotsCharm(e, state);
}

/// The pet part plus the item part of [owned]'s Mị lực, each clamped.
int petAndItemsCharm(Economy e, PetDef def, OwnedPet owned) {
  final pet = petCharmScore(
    def,
    owned.stage,
    multipliers: e.charmStageMultiplier,
  );
  final items = wornItemsCharm(owned.worn, e.petItemRules, e.petItem);
  return clampCharmPart(pet, e.charmRules.petMax) +
      clampCharmPart(items, e.charmRules.petItemsMax);
}

/// FNV-1a (32 bit) of `period:uid`: the season's dice for one player, the
/// same number as functions/payout.js `seasonPickHash` (shared fixture
/// test/fixtures/charm_rewards_fixture.json `picks`). A rerun, the server's
/// payout and the admin's release all pick the same item.
int seasonPickHash(String period, String uid) {
  var h = 0x811c9dc5;
  for (final c in '$period:$uid'.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// The one pet item of [tier] for [uid] in [period] (`leaderboard.
/// petItemPick`, functions/payout.js `pickSeasonItem`):
///   * "randomNotOwned": one of the tier's items not in [owned]; owning them
///     all pays the shop price of the item at `hash % tierSize`, in that
///     item's currency (Pha lê or xu);
///   * otherwise any item of the tier.
/// Null when the tier has no items.
RewardItem? charmRewardPick(
  Economy e,
  String tierKey, {
  required String period,
  required String uid,
  Set<String> owned = const {},
}) {
  final tier = PetItemTier.fromKey(tierKey);
  if (tier == null) return null;
  final pool = [
    for (final item in e.petItems)
      if (item.tier == tier) item,
  ];
  if (pool.isEmpty) return null;
  final h = seasonPickHash(period, uid);
  if (!e.charmBoard.picksNotOwned) {
    return RewardItem.petItem(pool[h % pool.length].id);
  }
  final left = [
    for (final item in pool)
      if (!owned.contains(item.id)) item,
  ];
  if (left.isNotEmpty) return RewardItem.petItem(left[h % left.length].id);
  final item = pool[h % pool.length];
  if (item.price <= 0) return null;
  return item.paysPhaLe
      ? RewardItem.phaLe(item.price)
      : RewardItem.coins(item.price);
}

/// What one reward line pays: Pha lê and Giọt hoa as listed, then exactly
/// one pet item of the line's tier ([charmRewardPick]).
RewardBundle charmRewardBundle(
  CharmBoardReward line,
  Economy e, {
  required String period,
  required String uid,
  Set<String> owned = const {},
}) {
  final pick = charmRewardPick(
    e,
    line.itemTier,
    period: period,
    uid: uid,
    owned: owned,
  );
  return RewardBundle([
    if (line.phaLe > 0) RewardItem.phaLe(line.phaLe),
    if (line.giotHoa > 0) RewardItem.giotHoa(line.giotHoa),
    ?pick,
  ]);
}

/// The letter that carries a player's season reward.
GameMail charmRewardMail({
  required String period,
  required int rank,
  required String uid,
  required RewardBundle rewards,
  required CharmBoardReward line,
  required Economy economy,
}) {
  final text = seasonMailText(
    rank: rank,
    line: line,
    rewards: rewards,
    e: economy,
  );
  return GameMail(
    id: charmRewardMailId(period, uid),
    title: text.title,
    body: text.body,
    target: uid,
    rewards: rewards,
  );
}

/// One line of the review: the stored board row next to what the player's
/// saved game says today.
@immutable
class CharmReviewRow {
  const CharmReviewRow({required this.row, this.save, this.recomputed});

  final CharmBoardRow row;

  /// The player's saved game, null when it could not be read.
  final GameState? save;

  /// Mị lực recomputed from [save], null when there is no readable save.
  final int? recomputed;

  int get rank => row.rank;
  CharmBoardEntry get entry => row.entry;

  /// The stored charm and the recomputed one differ (or there was no save to
  /// check): the admin should look before paying.
  bool get needsLook => recomputed == null || recomputed != entry.charm;

  /// The payout would HOLD this row for the admin: the board claims more
  /// than the save backs. A board value at or below the recomputed one is
  /// not held: the recomputed value is what gets paid. (There is no overall
  /// cap any more; each part is clamped in [recomputeCharm].)
  bool get willHold => recomputed != null && entry.charm > recomputed!;

  String? get savedPetId => save?.petCharm;
  int? get savedStage {
    final id = savedPetId;
    return id == null ? null : save?.ownedPet(id)?.stage;
  }

  Map<String, String> get savedWorn {
    final id = savedPetId;
    return id == null ? const {} : (save?.ownedPet(id)?.worn ?? const {});
  }
}

/// Admin side of the season reward: saves of the ranked players and the one
/// create-only write (the release of a held row).
abstract class CharmRewardStore {
  /// Saved games of [uids]; a player without a readable save is left out.
  Future<Map<String, GameState>> saves(List<String> uids);

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

/// The preview of one period on /quan-tri (Xếp hạng Mị lực) before the payout
/// has run: loads the board and checks each row against the saved game.
class CharmReviewController extends ChangeNotifier {
  CharmReviewController({
    required this.board,
    required this.store,
    required this.economy,
    required this.period,
  });

  final CharmBoardSource board;
  final CharmRewardStore store;
  final Economy economy;

  /// The period under review (editable in the panel).
  String period;

  ReviewLoad load = ReviewLoad.idle;
  List<CharmReviewRow> rows = const [];

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

  /// Where the season stands at [now] (the live period only).
  SeasonPhase seasonPhase(DateTime now) =>
      seasonPhaseAt(config.endOf(period), now);

  Future<void> loadBoard() async {
    if (!isValidPeriodKey(period)) {
      load = ReviewLoad.error;
      notifyListeners();
      return;
    }
    load = ReviewLoad.loading;
    notifyListeners();
    try {
      final top = await board.top(period: period, limit: config.limit);
      final uids = [for (final r in top) r.entry.uid];
      final saves = await store.saves(uids);
      rows = [
        for (final r in top)
          CharmReviewRow(
            row: r,
            save: saves[r.entry.uid],
            recomputed: saves[r.entry.uid] == null
                ? null
                : recomputeCharm(saves[r.entry.uid]!, economy),
          ),
      ];
      load = ReviewLoad.ready;
    } catch (_) {
      load = ReviewLoad.error;
    }
    notifyListeners();
  }
}

/// The rank a season-reward letter names ("Bạn đứng hạng 7 ..."), or null for
/// any other letter. The reward popup of an item says "Hạng 7 · mùa vừa rồi".
int? charmMailRank(GameMail mail) {
  if (!mail.id.startsWith('bxh_')) return null;
  final m = RegExp(r'hạng (\d+)').firstMatch(mail.body);
  return m == null ? null : int.tryParse(m.group(1)!);
}
