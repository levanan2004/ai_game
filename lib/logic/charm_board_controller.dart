import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/charm_board.dart';
import '../data/pet_items.dart';
import 'charm_rewards.dart';
import 'mailbox.dart';
import 'rewards.dart';
import 'shop_session.dart';

/// What the board itself is doing.
enum BoardLoad { idle, loading, ready, error }

/// Where the player stands (the "Hạng của bạn" card, SPEC section 5).
enum BoardMe {
  /// Not signed in.
  guest,

  /// The Mị lực slot is empty.
  noPet,

  /// A pet is in the slot but its Mị lực is under the minimum.
  underMin,

  /// On the board with a rank.
  ranked,

  /// Over the minimum, not in the rows read (rank 100+).
  outside,

  /// Over the minimum and the board has room, but the row is not published
  /// yet (the score goes up every 15 minutes).
  pending,
}

/// The reward button (SPEC section 6).
enum BoardClaim { notEnded, pending, ready, done }

/// "Kéo xuống để làm mới" may not hit the server more often than this.
const charmBoardFetchGap = Duration(seconds: 30);

/// The board of one season for one player: reads the top rows (cached for
/// `leaderboard.refreshMinutes`), publishes the player's own row at most that
/// often, and says where the player stands. The screen is
/// lib/ui/charm_board_screen.dart. Without a [source] (offline, tests) it
/// does nothing and the screen shows the error state.
class CharmBoardController extends ChangeNotifier {
  CharmBoardController(
    this._s, {
    required this.source,
    required DateTime Function() now,
  }) : _now = now;

  final ShopSession _s;
  final CharmBoardSource? source;
  final DateTime Function() _now;

  CharmBoardConfig get config => _s.e.charmBoard;

  BoardLoad load = BoardLoad.idle;
  List<CharmBoardRow> rows = const [];
  DateTime? fetchedAt;
  DateTime? _fetchTried;

  /// The reward table instead of the board.
  bool rewardsOpen = false;

  /// The row whose profile sheet is open.
  CharmBoardRow? profile;

  CharmBoardEntry? _published;
  DateTime? _publishTried;
  bool _cleaned = false;
  String? _uid;
  Timer? _timer;

  /// Starts the once-a-minute check that publishes when the 15 minutes are
  /// up. Only the real game starts it; tests call [publishIfDue] themselves.
  void start() {
    _timer ??= Timer.periodic(
      const Duration(minutes: 1),
      (_) => publishIfDue(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mail?.removeListener(notifyListeners);
    super.dispose();
  }

  // -- the season reward (gift mailbox) ----------------------------------------

  MailboxFeed? _mail;

  /// Connects the gift mailbox: an approved season reward arrives there as
  /// the mail `bxh_{period}_{uid}` and is claimed through the same path as
  /// every other mail.
  void attachMailbox(MailboxFeed feed) {
    _mail?.removeListener(notifyListeners);
    _mail = feed;
    feed.addListener(notifyListeners);
  }

  /// The reward mail of this player for the live period, once an admin has
  /// approved the season. Null before that.
  GameMail? get rewardMail {
    final uid = _s.accountUid;
    final feed = _mail;
    if (uid == null || feed == null || feed.uid != uid) return null;
    final id = charmRewardMailId(config.periodKey, uid);
    for (final mail in feed.mails) {
      if (mail.id == id) return mail;
    }
    return null;
  }

  // -- the player's own row ------------------------------------------------

  /// The row the player would publish now, or null with no pet in the slot.
  CharmBoardEntry? get mine {
    final uid = _s.accountUid;
    final id = _s.state.petCharm;
    if (uid == null || id == null) return null;
    final owned = _s.state.ownedPet(id);
    if (owned == null) return null;
    return CharmBoardEntry.forPlayer(
      uid: uid,
      displayName: _s.state.shopName ?? '',
      avatar: _s.state.ownerAvatar,
      charm: _s.charmScore,
      petId: id,
      stage: owned.stage,
      worn: owned.worn,
    );
  }

  /// Local Mị lực, live (the card uses it, not the board's older number).
  int get myCharm => _s.charmScore;

  /// Rank from the latest fetch, or null when the player is not in the rows.
  int? get myRank {
    final uid = _s.accountUid;
    if (uid == null) return null;
    for (final row in rows) {
      if (row.entry.uid == uid) return row.rank;
    }
    return null;
  }

  BoardMe get me {
    if (!_s.signedIn) return BoardMe.guest;
    if (_s.state.petCharm == null || mine == null) return BoardMe.noPet;
    if (myCharm < config.minCharm) return BoardMe.underMin;
    if (myRank != null) return BoardMe.ranked;
    return rows.length >= config.limit ? BoardMe.outside : BoardMe.pending;
  }

  /// "Cần thêm {n} Mị lực để vào top 100": one more than the last row
  /// (a tie goes to whoever got there first, so equal is not enough).
  int get outsideNeed {
    if (rows.isEmpty) return 0;
    final need = rows.last.entry.charm - myCharm + 1;
    return need < 1 ? 1 : need;
  }

  // -- season clock ----------------------------------------------------------

  bool get hasSeasonClock => config.seasonEnd != null;

  bool get seasonEnded {
    final end = config.seasonEnd;
    return end != null && !_now().isBefore(end);
  }

  Duration get seasonLeft {
    final end = config.seasonEnd;
    if (end == null) return Duration.zero;
    final left = end.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  /// "12 ngày 5 giờ", "5 giờ 20 phút" or "20 phút".
  String get seasonLeftText {
    final left = seasonLeft;
    final d = left.inDays;
    final h = left.inHours % 24;
    final m = left.inMinutes % 60;
    if (d > 0) return '$d ngày $h giờ';
    if (h > 0) return '$h giờ $m phút';
    return '${m < 1 ? 1 : m} phút';
  }

  /// The reward button. Nothing is paid before the admin has looked at the
  /// top ranks, so an ended season waits at [BoardClaim.pending] until the
  /// reward mail arrives, then [BoardClaim.ready] until it is claimed.
  BoardClaim get claim {
    if (!seasonEnded) return BoardClaim.notEnded;
    final mail = rewardMail;
    if (mail == null) return BoardClaim.pending;
    return _mail!.stateOf(mail.id).claimed ? BoardClaim.done : BoardClaim.ready;
  }

  /// A claim is running (double taps are ignored).
  bool get claiming {
    final mail = rewardMail;
    return mail != null && _mail!.claiming(mail.id);
  }

  /// Mị lực one item of tier [tierKey] adds (0 for a tier with no item).
  int itemCharm(String tierKey) {
    final tier = PetItemTier.fromKey(tierKey);
    return tier == null ? 0 : _s.e.petItemRules.charmOfTier(tier);
  }

  /// "Nhận thưởng": claims the reward mail through the gift mailbox (once per
  /// account) and adds the bundle with `grantRewards(source: mailbox)`.
  Future<MailClaimResult> claimReward() async {
    final feed = _mail;
    final mail = rewardMail;
    if (feed == null || mail == null) return MailClaimResult.refused;
    final result = await feed.claim(
      mail.id,
      allowed: _s.canWriteAccount && _s.accountUid == feed.uid,
      grant: (m) => _s.grantRewards(
        m.rewards,
        source: RewardSource.mailbox,
        rank: charmMailRank(m),
      ),
    );
    notifyListeners();
    return result;
  }

  // -- reading ---------------------------------------------------------------

  bool get _fresh =>
      fetchedAt != null && _now().difference(fetchedAt!) < config.refreshEvery;

  /// Opens the screen: reads the board (a read less than 15 minutes old is
  /// reused) and publishes the player's row if its 15 minutes are up.
  Future<void> open() async {
    rewardsOpen = false;
    profile = null;
    notifyListeners();
    await refresh();
    await publishIfDue();
    await _lookForReward();
  }

  /// Once the season is over the reward mail may have arrived since the
  /// mailbox was last read.
  Future<void> _lookForReward() async {
    if (seasonEnded) await _mail?.refresh();
  }

  /// Reads the top rows. [force] is pull-to-refresh: it skips the 15-minute
  /// cache but not the 30-second gap (a retry after an error skips both).
  Future<void> refresh({bool force = false}) async {
    final src = source;
    if (src == null || !_s.signedIn || load == BoardLoad.loading) return;
    final now = _now();
    if (!force && _fresh && load == BoardLoad.ready) return;
    if (force &&
        load != BoardLoad.error &&
        _fetchTried != null &&
        now.difference(_fetchTried!) < charmBoardFetchGap) {
      return;
    }
    _fetchTried = now;
    load = BoardLoad.loading;
    notifyListeners();
    try {
      rows = await src.top(period: config.periodKey, limit: config.limit);
      fetchedAt = _now();
      load = BoardLoad.ready;
    } catch (_) {
      // Rows from an earlier read stay on screen; only an empty board errors.
      load = rows.isEmpty ? BoardLoad.error : BoardLoad.ready;
    }
    notifyListeners();
  }

  void openRewards() {
    rewardsOpen = true;
    profile = null;
    notifyListeners();
    unawaited(_lookForReward());
  }

  void closeRewards() {
    rewardsOpen = false;
    notifyListeners();
  }

  void openProfile(CharmBoardRow row) {
    profile = row;
    notifyListeners();
  }

  void closeProfile() {
    if (profile == null) return;
    profile = null;
    notifyListeners();
  }

  // -- writing ---------------------------------------------------------------

  /// Publishes the player's row: signed in, a pet in the Mị lực slot, Mị lực
  /// at least the minimum, the season not over, nothing sooner than
  /// `refreshMinutes` after the last try, and only when the row changed
  /// (rules refuse a second write inside 30 seconds anyway). Below the
  /// minimum an older row is taken off once.
  Future<void> publishIfDue({bool force = false}) async {
    final src = source;
    if (src == null || !_s.canWriteAccount) return;
    final uid = _s.accountUid!;
    if (_uid != uid) {
      _uid = uid;
      _published = null;
      _publishTried = null;
      _cleaned = false;
    }
    if (seasonEnded) return;
    final now = _now();
    if (!force &&
        _publishTried != null &&
        now.difference(_publishTried!) < config.refreshEvery) {
      return;
    }
    final entry = mine;
    if (entry == null || entry.charm < config.minCharm) {
      if (_published != null || !_cleaned) {
        _publishTried = now;
        try {
          await src.remove(period: config.periodKey, uid: uid);
          _published = null;
          _cleaned = true;
        } catch (_) {}
      }
      return;
    }
    if (_published != null && _published!.sameContent(entry)) return;
    _publishTried = now;
    try {
      await src.publish(period: config.periodKey, entry: entry);
      _published = entry;
      _cleaned = true;
    } catch (_) {
      // Try again in a minute, not in 15.
      _publishTried = now.subtract(
        config.refreshEvery - const Duration(minutes: 1),
      );
    }
  }
}
