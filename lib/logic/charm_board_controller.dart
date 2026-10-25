import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/charm_board.dart';
import '../data/pet_items.dart';
import '../save/progress_store.dart';
import 'charm_rewards.dart';
import 'mailbox.dart';
import 'profile_report.dart';
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

/// The chip on the "Xếp hạng Mị lực" row of the map
/// (SPEC_gia_ban_va_bxh_ban_do.md section 3, seven chips plus two quiet ones).
enum BoardMapChip {
  /// Row shows the title only (no data and no way to get it).
  hidden,

  /// Grey empty chip while the first read is on its way.
  loading,

  /// Not signed in: "Đăng nhập" with a lock.
  guest,

  /// The season is over and the reward is not in the mailbox yet.
  closing,

  /// On the board: "Hạng {n}" (colour by shield band) and the Mị lực.
  ranked,

  /// The reward mail is here and not claimed: as [ranked] plus a red dot.
  rewardReady,

  /// Over the minimum but not in the 100 rows read: "100+".
  outside,

  /// No pet in the Mị lực slot, or under the minimum, or not published yet.
  unranked,
}

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

  /// The rarity whose prize list ("Đồ pet {rarity} có thể nhận") is open on
  /// the rewards screen, null when closed.
  String? poolTier;

  /// The row whose profile sheet is open.
  CharmBoardRow? profile;

  CharmBoardEntry? _published;
  DateTime? _publishTried;
  bool _cleaned = false;
  String? _uid;
  String? _publishPeriod;
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

  /// The reward mail of this player for the season that just ended (the
  /// payout writes it a few minutes after the Sunday 23:59 close). Null
  /// before that, or with no reward.
  GameMail? get rewardMail {
    final uid = _s.accountUid;
    final feed = _mail;
    final prev = _closing ?? config.clock?.previous(_now());
    if (uid == null || feed == null || feed.uid != uid || prev == null) {
      return null;
    }
    final id = charmRewardMailId(prev.period, uid);
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
      avatar: _s.publishedAvatar,
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

  // -- the map row ---------------------------------------------------------

  /// Which chip the map row wears. Priority (spec): guest, reward waiting,
  /// closing, rank, outside, unranked. Reads what is already here; the map
  /// asks for one cached read when it opens ([refresh]).
  BoardMapChip get mapChip {
    if (!_s.signedIn) return BoardMapChip.guest;
    if (claim == BoardClaim.ready) return BoardMapChip.rewardReady;
    final state = me;
    if (state == BoardMe.noPet || state == BoardMe.underMin) {
      return BoardMapChip.unranked;
    }
    if (rows.isEmpty && load != BoardLoad.ready) {
      if (load == BoardLoad.error || source == null) return BoardMapChip.hidden;
      return BoardMapChip.loading;
    }
    return switch (state) {
      BoardMe.ranked =>
        claim == BoardClaim.pending
            ? BoardMapChip.closing
            : BoardMapChip.ranked,
      BoardMe.outside => BoardMapChip.outside,
      _ => BoardMapChip.unranked,
    };
  }

  /// The rank the map chip shows: the latest read, or the rank written in the
  /// reward mail when the board has not been read yet.
  int? get mapRank {
    final r = myRank;
    if (r != null) return r;
    final mail = rewardMail;
    return mail == null ? null : charmMailRank(mail);
  }

  // -- season clock ----------------------------------------------------------

  bool get hasSeasonClock => config.clock != null;

  /// For `lockMinutesAfterClose` (economy.json ratingBoard.season, both
  /// boards) after a season's Sunday 23:59 close the board still shows that
  /// season, frozen ("Đang chốt bảng"), while the payout (5-minute grace,
  /// then every 10 minutes) writes the reward mails. Then the next season's
  /// board, which started at Monday 00:00, is shown.
  Season? get _closing => config.clock?.closing(_now(), config.lockAfterClose);

  /// The season the board shows (shared clock, season_clock.dart): the one
  /// in its closing lock, else the one running. Null without a clock.
  Season? get season => _closing ?? config.seasonAt(_now());

  /// The controller's clock (tests pass a fixed one).
  DateTime get now => _now();

  /// The board key now: season-1, then season-2 from Monday 09/11 (shown
  /// after the closing window), ... with no change to economy.json.
  String get period => season?.period ?? config.periodKey;

  /// Inside the closing window of the season that just ended.
  bool get seasonEnded => _closing != null;

  Duration get seasonLeft {
    final end = season?.end;
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

  /// The reward button: [BoardClaim.pending] ("Đang chốt bảng") in the
  /// closing window until the reward mail exists, [BoardClaim.ready]
  /// ("Nhận thưởng") once the last season's mail is here (also later, in the
  /// next season), [BoardClaim.done] ("Đã nhận") after it is claimed, else
  /// [BoardClaim.notEnded] (a row the payout HELD for the admin has no mail
  /// until it is released).
  BoardClaim get claim {
    final mail = rewardMail;
    if (mail == null) {
      return seasonEnded ? BoardClaim.pending : BoardClaim.notEnded;
    }
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

  String? _rowsPeriod;

  bool get _fresh =>
      fetchedAt != null && _now().difference(fetchedAt!) < config.refreshEvery;

  /// Opens the screen: reads the board (a read less than 15 minutes old is
  /// reused) and publishes the player's row if its 15 minutes are up.
  Future<void> open() async {
    rewardsOpen = false;
    poolTier = null;
    profile = null;
    notifyListeners();
    await refresh();
    await publishIfDue();
    await _lookForReward();
  }

  /// After a season closed the reward mail may have arrived since the
  /// mailbox was last read.
  Future<void> _lookForReward() async {
    if (config.clock?.previous(_now()) != null) await _mail?.refresh();
  }

  /// Reads the top rows. [force] is pull-to-refresh: it skips the 15-minute
  /// cache but not the 30-second gap (a retry after an error skips both).
  Future<void> refresh({bool force = false}) async {
    final src = source;
    if (src == null || !_s.signedIn || load == BoardLoad.loading) return;
    final now = _now();
    // A new season is a new board: the old rows are not reused.
    final key = period;
    if (_rowsPeriod != key) {
      _rowsPeriod = key;
      rows = const [];
      fetchedAt = null;
      if (load == BoardLoad.ready) load = BoardLoad.idle;
    }
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
      rows = await src.top(period: key, limit: config.limit);
      fetchedAt = _now();
      load = BoardLoad.ready;
      // Khung avatar of the rows (server-written player_avatars, cached).
      unawaited(_s.frames.prefetch([for (final r in rows) r.entry.uid]));
    } catch (_) {
      // Rows from an earlier read stay on screen; only an empty board errors.
      load = rows.isEmpty ? BoardLoad.error : BoardLoad.ready;
    }
    notifyListeners();
  }

  void openRewards() {
    rewardsOpen = true;
    poolTier = null;
    profile = null;
    notifyListeners();
    unawaited(_lookForReward());
  }

  void closeRewards() {
    rewardsOpen = false;
    poolTier = null;
    notifyListeners();
  }

  void openPool(String tierKey) {
    if (!rewardsOpen) return;
    poolTier = tierKey;
    notifyListeners();
  }

  void closePool() {
    if (poolTier == null) return;
    poolTier = null;
    notifyListeners();
  }

  void openProfile(CharmBoardRow row) {
    // A hidden player's profile does not open: the list offers "Bỏ ẩn".
    if (isHidden(row.entry.uid)) return openHiddenList();
    profile = row;
    reportOpen = false;
    notifyListeners();
  }

  void closeProfile() {
    if (profile == null) return;
    profile = null;
    reportOpen = false;
    notifyListeners();
  }

  // -- reporting a profile (Apple 1.2) ----------------------------------------

  /// The reason form over the profile sheet.
  bool reportOpen = false;

  /// Players this session already reported (the rules refuse a second one).
  final Set<String> _reported = {};

  /// A report opened from another board's profile card (Bảng Đánh giá).
  ReportTarget? _reportFor;

  /// Who the report form is about: the card opened from Bảng Đánh giá, else
  /// the open Mị lực profile.
  ReportTarget? get reportTarget {
    final other = _reportFor;
    if (other != null) return other;
    final row = profile;
    if (row == null) return null;
    return ReportTarget(
      uid: row.entry.uid,
      name: row.entry.displayName,
      source: reportSourceCharmBoard,
    );
  }

  /// "Báo cáo" shows on another signed-in player's row, never on your own.
  bool get canReport {
    final uid = _s.accountUid;
    final t = reportTarget;
    return uid != null && t != null && t.uid.isNotEmpty && t.uid != uid;
  }

  void openReport() {
    if (!canReport) return;
    reportOpen = true;
    notifyListeners();
  }

  /// "Báo cáo" on a profile card opened from Bảng Đánh giá: the same form
  /// (report.dialog.*), with that board as the source.
  void openReportFor(String uid, String name, {required String source}) {
    _reportFor = ReportTarget(uid: uid, name: name, source: source);
    if (!canReport) {
      _reportFor = null;
      return;
    }
    reportOpen = true;
    notifyListeners();
  }

  void closeReport() {
    if (!reportOpen && _reportFor == null) return;
    reportOpen = false;
    _reportFor = null;
    notifyListeners();
  }

  // -- hidden players ("Ẩn người chơi này"; per account, account_prefs.dart) --

  ProgressStore? _hiddenStore;

  /// Players hidden by this account (on the device when signed out):
  /// uid -> shop name when hidden (for the
  /// "Người chơi đã ẩn" list). Their rows keep their rank with the name and
  /// avatar masked; tapping one opens that list instead of the profile.
  Map<String, String> hidden = const {};

  /// The "Người chơi đã ẩn" list over the board.
  bool hiddenListOpen = false;

  /// Reads the hidden list from [store] (main.dart; tests pass a memory one).
  /// A signed-in account with a server gets its own list from
  /// [ShopSession.prefs] instead.
  Future<void> useHiddenPlayers(ProgressStore store) async {
    _hiddenStore = store;
    if (_s.prefs.ownsLists) return;
    try {
      hidden = await store.loadHiddenPlayers();
    } catch (_) {
      hidden = const {};
    }
    notifyListeners();
  }

  /// Never true for the player's own row.
  bool isHidden(String uid) => uid != _s.accountUid && hidden.containsKey(uid);

  /// Hides the open profile's player (report form, after the confirm) and
  /// closes the sheet. Returns the name for the toast, or null when nothing
  /// was hidden (own row, guest).
  Future<String?> hideProfile() async {
    final t = reportTarget;
    if (!canReport || t == null) return null;
    final name = t.name;
    hidden = {...hidden, t.uid: name};
    if (_reportFor != null) _s.ratingBoard.closeSheets();
    _reportFor = null;
    profile = null;
    reportOpen = false;
    notifyListeners();
    await _saveHidden();
    return name;
  }

  /// Tin thế giới "Chặn": the same list, by uid and name. False for the
  /// player's own uid (and when signed out there is no own uid to compare,
  /// so an empty uid is refused too).
  Future<bool> hidePlayer(String uid, String name) async {
    if (uid.isEmpty || uid == _s.accountUid) return false;
    hidden = {...hidden, uid: name};
    notifyListeners();
    await _saveHidden();
    return true;
  }

  void openHiddenList() {
    hiddenListOpen = true;
    profile = null;
    reportOpen = false;
    notifyListeners();
  }

  void closeHiddenList() {
    if (!hiddenListOpen) return;
    hiddenListOpen = false;
    notifyListeners();
  }

  /// "Bỏ ẩn" in the list: shows the player again.
  Future<void> unhide(String uid) async {
    if (!hidden.containsKey(uid)) return;
    hidden = {...hidden}..remove(uid);
    notifyListeners();
    await _saveHidden();
  }

  /// The account's list (account_prefs.dart), or the device's.
  void applyHidden(Map<String, String> players) {
    hidden = Map.unmodifiable(players);
    notifyListeners();
  }

  Future<void> _saveHidden() async {
    if (await _s.prefs.save()) return;
    try {
      await _hiddenStore?.saveHiddenPlayers(hidden);
    } catch (_) {}
  }

  /// Sends the report of the open profile. The form closes unless it failed.
  Future<ReportSend> sendReport(ReportReason reason, String note) async {
    final uid = _s.accountUid;
    final t = reportTarget;
    final sink = _s.reports;
    if (!canReport || uid == null || t == null || sink == null) {
      return ReportSend.failed;
    }
    final target = t.uid;
    var out = ReportSend.already;
    if (!_reported.contains(target)) {
      final text = note.trim();
      out = await sink.send(
        ProfileReport(
          reporterUid: uid,
          targetUid: target,
          targetName: t.name,
          reason: reason,
          source: t.source,
          note: text.length > reportNoteMax
              ? text.substring(0, reportNoteMax)
              : text,
        ),
      );
    }
    if (out != ReportSend.failed) {
      _reported.add(target);
      reportOpen = false;
      _reportFor = null;
    }
    notifyListeners();
    return out;
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
    final key = period;
    if (_uid != uid || _publishPeriod != key) {
      _uid = uid;
      _publishPeriod = key;
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
          await src.remove(period: key, uid: uid);
          _published = null;
          _cleaned = true;
        } catch (_) {}
      }
      return;
    }
    if (_published != null && _published!.sameContent(entry)) return;
    _publishTried = now;
    try {
      await src.publish(period: key, entry: entry);
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
