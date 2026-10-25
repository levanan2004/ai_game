import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/economy.dart';
import 'mailbox.dart';
import 'rewards.dart';
import 'shop_session.dart';
import 'wallet.dart';

/// One spin as the server drew it (functions/gacha.js draw): the reward
/// items, the week's pot ([featured]) or its xu when already owned ([dup]),
/// and whether the pity counter forced it ([pity]).
@immutable
class SpinResult {
  const SpinResult({
    required this.items,
    this.featured = false,
    this.dup = false,
    this.pity = false,
  });

  final RewardBundle items;
  final bool featured;
  final bool dup;
  final bool pity;

  static SpinResult? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return SpinResult(
      items: RewardBundle.fromJson(raw['items']),
      featured: raw['featured'] == true,
      dup: raw['dup'] == true,
      pity: raw['pity'] == true,
    );
  }

  static List<SpinResult> listFrom(Object? raw) => [
    if (raw is List)
      for (final r in raw) ?SpinResult.fromJson(r),
  ];
}

/// One `wallets/{uid}/ledger` spin row (Lịch sử quay): when, which pot, the
/// results in order.
@immutable
class SpinRecord {
  const SpinRecord({
    required this.at,
    required this.potId,
    required this.results,
  });

  final DateTime at;
  final String potId;
  final List<SpinResult> results;
}

/// Where the owner's spin history is read (the server ledger).
abstract class GachaHistorySource {
  /// Newest first, at most [limit] spin rows.
  Future<List<SpinRecord>> recent(String uid, {int limit = 30});
}

class MemoryGachaHistory implements GachaHistorySource {
  MemoryGachaHistory([List<SpinRecord>? rows]) : rows = rows ?? [];

  final List<SpinRecord> rows;
  bool fail = false;

  @override
  Future<List<SpinRecord>> recent(String uid, {int limit = 30}) async {
    if (fail) throw StateError('offline');
    final out = [...rows]..sort((a, b) => b.at.compareTo(a.at));
    return out.take(limit).toList();
  }
}

/// The spin's rewards arrive as one Hộp thư mail (`gacha_{uid}_{seq}`).
/// The wheel claims it from its result popup ("Nhận" / "Nhận hết") through
/// the mailbox, and reads spin mails still unclaimed (`spin.pending`).
abstract class GachaMailbox {
  Future<MailClaimResult> claim(String mailId);

  /// Unclaimed spin mails, newest first.
  Future<List<String>> pendingSpinMails();
}

/// [GachaMailbox] on the Hộp thư feed: refreshes it (the spin mail was
/// just written) and claims like the mailbox does, with its grant.
class FeedGachaMailbox implements GachaMailbox {
  FeedGachaMailbox(this.feed, {required this.allowed, required this.grant});

  final MailboxFeed feed;
  final bool Function() allowed;
  final RewardBundle Function(GameMail mail) grant;

  @override
  Future<MailClaimResult> claim(String mailId) async {
    if (!feed.mails.any((m) => m.id == mailId)) await feed.refresh();
    return feed.claim(mailId, allowed: allowed(), grant: grant);
  }

  @override
  Future<List<String>> pendingSpinMails() async {
    await feed.refresh();
    return [
      for (final m in feed.mails)
        if (m.id.startsWith('gacha_') && !feed.stateOf(m.id).claimed) m.id,
    ];
  }
}

/// A one-time message the wheel screen turns into Nhất's text
/// (GachaText): toasts after a buy or spin, the reset notice, the pity
/// reminder. [a]/[b] are its numbers, [code] a server refusal.
enum GachaNoteKind {
  spinFail,
  buyFail,
  buySuccess,
  xuDailyOut,
  xuOverLimit,
  notEnoughXu,
  resetNotice,
  reminder,
}

@immutable
class GachaNote {
  const GachaNote(
    this.kind, {
    this.a = 0,
    this.b = 0,
    this.code = '',
    this.left,
  });

  final GachaNoteKind kind;
  final int a;
  final int b;
  final String code;

  /// [GachaNoteKind.reminder]: time until the counter resets.
  final Duration? left;
}

/// What the wheel screen shows over itself.
enum GachaPopup {
  none,
  result,
  short,
  buy,
  plConfirm,
  odds,
  history,
  cards,
  notice,

  /// "Thiếu {n} Pha lê": a Pha lê buy short of [GachaController.plShortNeed].
  plShort,
}

/// Vòng quay tuần (spec 1, Nhất 1a–1j, task 8): the week's Sơn Hải pot from
/// the server wallet, Thẻ gacha per pot, the pity counter, buying cards and
/// spinning. Every buy and spin goes through the wallet callables
/// (gachaBuyCards, gachaSpin); nothing is drawn or counted here.
class GachaController extends ChangeNotifier {
  GachaController(this._s, {this.history});

  final ShopSession _s;
  final GachaHistorySource? history;

  /// Bound by main to the Hộp thư (null offline and in most tests).
  GachaMailbox? mailbox;

  GachaConfig get config => _s.e.gacha;

  /// The wheel exists in economy.json.
  bool get offered => config.offered;

  DateTime get _now => _s.clockNow();

  WalletView? get _w => _s.signedIn ? _s.wallet : null;

  // ---- the week ------------------------------------------------------------

  /// This week's pot: the server's answer, else the same math on the client.
  String? get potId => _w?.potOfWeek ?? config.potOfWeekAt(_now);
  String? get nextPotId =>
      _w?.nextPotOfWeek ??
      (() {
        final at = config.nextChangeAt(_now);
        return at == null ? null : config.potOfWeekAt(at);
      })();

  int get weekIndex {
    final w = _w;
    if (w != null && w.weekIndex >= 0) return w.weekIndex;
    return config.weekIndexAt(_now);
  }

  /// 0h Monday (VN) when the pot changes.
  DateTime? get weekEnd => _w?.weekEnd ?? config.nextChangeAt(_now);

  Duration get timeLeft {
    final end = weekEnd;
    if (end == null) return Duration.zero;
    final d = end.difference(_now);
    return d.isNegative ? Duration.zero : d;
  }

  /// The last day of the week: the countdown turns orange,
  /// `spin.pity.reset_soon` shows.
  bool get lastDay => weekEnd != null && timeLeft <= const Duration(days: 1);

  PotDef? pot(String? id) => id == null ? null : _s.e.potOrNull(id);

  String potName(String? id) => pot(id)?.nameVi ?? '';

  /// Phú's art folder of [id] (`gacha.assetIdByPot`).
  String? assetOf(String? id) => id == null ? null : config.assetIdByPot[id];

  /// The xu a duplicate week pot pays (`ifOwned.coins`).
  int get dupCoins {
    for (final e in config.table) {
      if (e.item == 'potOfWeek') return e.ifOwnedCoins;
    }
    return 0;
  }

  /// The player owns this week's pot (save or Kho chậu).
  bool get ownsPot {
    final id = potId;
    return id != null && (_s.state.potCounts[id] ?? 0) > 0;
  }

  // ---- cards ---------------------------------------------------------------

  int cardsOf(String id) => _w?.cardsOf(id) ?? 0;
  int get cards => potId == null ? 0 : cardsOf(potId!);

  /// Card types owned, this week's first, then by when they come back.
  List<MapEntry<String, int>> get inventory {
    final w = _w;
    if (w == null) return const [];
    final cur = potId;
    final list = [
      for (final e in w.cards.entries)
        if (e.value > 0) e,
    ];
    if (cur != null && !list.any((e) => e.key == cur)) {
      list.add(MapEntry(cur, 0));
    }
    DateTime back(String id) => id == cur
        ? DateTime(0)
        : (config.nextWeekOf(id, _now) ?? DateTime(9999));
    list.sort((a, b) => back(a.key).compareTo(back(b.key)));
    return list;
  }

  /// When [id] comes back to the wheel (start of that week).
  DateTime? returnOf(String id) => config.nextWeekOf(id, _now);

  int get cardPhaLe => _w?.cardPhaLe ?? config.ticketPhaLe;
  int get cardCoins => _w?.cardCoins ?? config.ticketCoinsOnDay(_s.state.day);
  int get xuDailyMax => _w?.xuCardsDailyMax ?? config.maxCoinTicketsPerDay;

  /// Xu cards still buyable today (null = no cap).
  int? get xuLeftToday {
    final w = _w;
    if (w == null) return xuDailyMax > 0 ? xuDailyMax : null;
    return w.xuCardsLeftToday;
  }

  // ---- pity ----------------------------------------------------------------

  int get pityAt => (_w?.pityAt ?? 0) > 0 ? _w!.pityAt : config.pityAt;

  /// This week's spins of this week's pot since the last hit.
  int get pityCount => potId == null ? 0 : (_w?.pity[potId!]?.n ?? 0);

  /// Spins left until the pot is sure.
  int get pityLeft => (pityAt - pityCount).clamp(0, pityAt);

  // ---- entry: red dot, intro -----------------------------------------------

  /// The red dot on the Vòng quay icon: a card of this week's pot unused, or
  /// the new week not opened yet.
  bool get dot =>
      offered &&
      _s.signedIn &&
      potId != null &&
      (cards > 0 || _s.state.gachaSeenWeek != weekIndex);

  /// The one-time intro popup ("Mới: Vòng quay tuần").
  bool get introDue =>
      offered &&
      potId != null &&
      !_s.state.gachaIntroShown &&
      _s.screen == Screen.shop &&
      !_s.tutorialActive;

  /// The icon glows/blinks twice after the intro is closed with "Đóng".
  int glowSeq = 0;

  /// Closes the intro for good; [open] opens the wheel ("Xem ngay").
  void closeIntro({required bool open}) {
    _s.editSave((st) => st.gachaIntroShown = true);
    if (open) {
      openScreen();
    } else {
      glowSeq++;
    }
    notifyListeners();
  }

  // ---- screen --------------------------------------------------------------

  bool open = false;
  GachaPopup popup = GachaPopup.none;

  /// One-time message for [GachaPopup.notice] (reset notice, reminder).
  GachaNote? notice;
  final List<GachaNote> _notices = [];

  /// Unclaimed spin mails found on opening (`spin.pending`).
  List<String> pending = const [];

  void openScreen() {
    if (!offered) return;
    open = true;
    popup = GachaPopup.none;
    _notices.clear();
    final week = weekIndex;
    if (week >= 0 && _s.signedIn) {
      final reset = _resetNotice(week);
      if (reset != null) _notices.add(reset);
      final remind = _reminder(week);
      if (remind != null) _notices.add(remind);
      if (_s.state.gachaSeenWeek != week) {
        _s.editSave((st) => st.gachaSeenWeek = week);
      }
    }
    _nextNotice();
    notifyListeners();
    unawaited(_s.syncWallet());
    unawaited(_loadPending());
  }

  void closeScreen() {
    if (spinning) return;
    open = false;
    popup = GachaPopup.none;
    results = const [];
    notifyListeners();
  }

  /// `spin.pity.reset_notice`: once, on the first open of a week, when the
  /// counter of last week's pot was reset from more than 0.
  GachaNote? _resetNotice(int week) {
    if (_s.state.gachaResetNoticeWeek == week) return null;
    final w = _w;
    if (w == null) return null;
    final was = w.pity.values.any(
      (p) => p.resetFrom > 0 && p.lastWeek != null && p.lastWeek == week - 1,
    );
    if (!was) return null;
    _s.editSave((st) => st.gachaResetNoticeWeek = week);
    return const GachaNote(GachaNoteKind.resetNotice);
  }

  /// `spin.pity.reminder`: once, in the last
  /// `pityReminderDaysBeforeReset` days, when this week's count reached
  /// `pityReminderAt`.
  GachaNote? _reminder(int week) {
    final at = config.pityReminderAt;
    final days = config.pityReminderDaysBeforeReset;
    if (at <= 0 || days <= 0 || _s.state.gachaReminderWeek == week) return null;
    if (pityCount < at || weekEnd == null) return null;
    if (timeLeft > Duration(days: days)) return null;
    _s.editSave((st) => st.gachaReminderWeek = week);
    return GachaNote(
      GachaNoteKind.reminder,
      a: pityCount,
      b: pityAt,
      left: timeLeft,
    );
  }

  void _nextNotice() {
    if (_notices.isEmpty) {
      notice = null;
      if (popup == GachaPopup.notice) popup = GachaPopup.none;
      return;
    }
    notice = _notices.removeAt(0);
    popup = GachaPopup.notice;
  }

  void closeNotice() {
    _nextNotice();
    notifyListeners();
  }

  Future<void> _loadPending() async {
    final box = mailbox;
    if (box == null || !_s.signedIn) return;
    try {
      pending = await box.pendingSpinMails();
    } catch (_) {
      pending = const [];
    }
    notifyListeners();
  }

  void showPopup(GachaPopup p) {
    if (spinning) return;
    popup = p;
    if (p == GachaPopup.history) unawaited(loadHistory());
    notifyListeners();
  }

  void closePopup() {
    popup = GachaPopup.none;
    notifyListeners();
  }

  // ---- spinning ------------------------------------------------------------

  bool spinning = false;

  /// Count of the spin being asked for / shown.
  int spinCount = 1;

  /// The last spin's results and its mail.
  List<SpinResult> results = const [];
  String? resultMail;
  bool claimed = false;
  bool claiming = false;

  /// A toast the screen shows once (and clears).
  GachaNote? toast;

  /// Cards missing for [spinCount] ([GachaPopup.short]).
  int get missing => (spinCount - cards).clamp(0, spinCount);

  /// Quay 1 / Quay 10. Missing cards open "Thiếu {N} thẻ" instead. Returns
  /// the results when the server spun.
  Future<List<SpinResult>?> spin(int count) async {
    if (spinning || !_s.signedIn || potId == null) return null;
    spinCount = count;
    if (cards < count) {
      popup = GachaPopup.short;
      notifyListeners();
      return null;
    }
    spinning = true;
    popup = GachaPopup.none;
    notifyListeners();
    try {
      final raw = await _s.spinGacha(count: count);
      results = SpinResult.listFrom(raw['results']);
      resultMail = raw['mailId'] is String ? raw['mailId'] as String : null;
      claimed = false;
      return results;
    } on WalletException catch (e) {
      toast = GachaNote(GachaNoteKind.spinFail, code: e.code);
      return null;
    } catch (_) {
      toast = const GachaNote(GachaNoteKind.spinFail, code: 'server');
      return null;
    } finally {
      spinning = false;
      notifyListeners();
    }
  }

  /// The wheel finished turning (or was skipped): show the results.
  void showResults() {
    if (results.isEmpty) return;
    popup = GachaPopup.result;
    notifyListeners();
  }

  /// "Nhận" / "Nhận hết": claims the spin mail through Hộp thư.
  Future<bool> claimResults() async {
    final id = resultMail;
    final box = mailbox;
    if (claimed) return true;
    if (id == null || box == null || claiming) {
      popup = GachaPopup.none;
      notifyListeners();
      return false;
    }
    claiming = true;
    notifyListeners();
    var ok = false;
    try {
      final r = await box.claim(id);
      ok = r == MailClaimResult.claimed || r == MailClaimResult.already;
    } catch (_) {}
    claiming = false;
    claimed = ok;
    if (ok) {
      pending = [
        for (final p in pending)
          if (p != id) p,
      ];
      popup = GachaPopup.none;
    }
    notifyListeners();
    return ok;
  }

  /// Claims the spin mails left from earlier (`spin.pending`).
  Future<void> claimPending() async {
    final box = mailbox;
    if (box == null) return;
    for (final id in [...pending]) {
      try {
        final r = await box.claim(id);
        if (r == MailClaimResult.claimed || r == MailClaimResult.already) {
          pending = [
            for (final p in pending)
              if (p != id) p,
          ];
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  // ---- buying ----------------------------------------------------------------

  bool buying = false;

  /// Pha lê missing for the last refused Pha lê buy ([GachaPopup.plShort]).
  int plShortNeed = 0;

  /// How many cards the buy sheet / short popup is for.
  int buyCount = 1;

  void openBuy(int count) {
    buyCount = count;
    popup = GachaPopup.buy;
    notifyListeners();
  }

  /// "Mua bằng Pha lê" asks first ([GachaPopup.plConfirm]).
  void askPhaLe(int count) {
    buyCount = count;
    popup = GachaPopup.plConfirm;
    notifyListeners();
  }

  /// Buys [count] cards; after a short popup, spins right away
  /// (`ticket.short.after_buy`). Returns true when bought.
  Future<bool> buy(
    int count, {
    required bool withPhaLe,
    bool thenSpin = false,
  }) async {
    if (buying) return false;
    if (!withPhaLe) {
      final left = xuLeftToday;
      if (left != null && left < count) {
        toast = left <= 0
            ? GachaNote(GachaNoteKind.xuDailyOut, a: xuDailyMax)
            : GachaNote(GachaNoteKind.xuOverLimit, a: left);
        notifyListeners();
        return false;
      }
      if (_s.state.money < cardCoins * count) {
        toast = const GachaNote(GachaNoteKind.notEnoughXu);
        notifyListeners();
        return false;
      }
    } else if (_s.state.phaLe < cardPhaLe * count) {
      plShortNeed = cardPhaLe * count - _s.state.phaLe;
      popup = GachaPopup.plShort;
      notifyListeners();
      return false;
    }
    buying = true;
    notifyListeners();
    var ok = false;
    try {
      await _s.buyGachaCards(count: count, withPhaLe: withPhaLe);
      ok = true;
      toast = GachaNote(GachaNoteKind.buySuccess, a: count, b: cards);
    } on WalletException catch (e) {
      toast = GachaNote(GachaNoteKind.buyFail, code: e.code);
    } catch (_) {
      toast = const GachaNote(GachaNoteKind.buyFail, code: 'server');
    }
    buying = false;
    popup = GachaPopup.none;
    notifyListeners();
    if (ok && thenSpin) {
      final r = await spin(spinCount);
      if (r != null) showResults();
    }
    return ok;
  }

  /// The toast was shown.
  void clearToast() => toast = null;

  // ---- history ---------------------------------------------------------------

  List<SpinRecord>? historyRows;
  bool historyFailed = false;

  Future<void> loadHistory() async {
    final src = history;
    final uid = _s.accountUid;
    historyFailed = false;
    if (src == null || uid == null) {
      historyRows = const [];
      notifyListeners();
      return;
    }
    historyRows = null;
    notifyListeners();
    try {
      historyRows = await src.recent(uid);
    } catch (_) {
      historyRows = const [];
      historyFailed = true;
    }
    notifyListeners();
  }
}
