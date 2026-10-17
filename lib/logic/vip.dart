import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/pot_rules.dart' show VipConfig, VipTier;
import 'shop_session.dart';
import 'wallet.dart' show VipStatus;

/// One Bảng vinh danh row (vip_hall/{uid}, functions/vip.js): the players at
/// VIP 10, by the day they reached it. Never an amount.
@immutable
class VipHallRow {
  const VipHallRow({
    required this.uid,
    required this.at,
    this.name = '',
    this.avatar = '',
    this.hidden = false,
  });

  final String uid;
  final DateTime at;
  final String name;
  final String avatar;

  /// "Ẩn tên khỏi Bảng vinh danh": shown as "Chủ tiệm ẩn danh", no avatar.
  final bool hidden;
}

/// Where VIP lives besides the wallet: the hall (read) and the owner's hall
/// switch (the vipHallHide callable).
abstract class VipSource {
  /// Up to [limit] rows after [after] (earliest first, then uid).
  Future<List<VipHallRow>> hallPage({VipHallRow? after, required int limit});

  /// How many rows the hall has.
  Future<int> hallCount();

  /// Sets "Ẩn tên khỏi Bảng vinh danh"; the server's new status. Throws
  /// when it did not happen.
  Future<VipStatus> setHallHidden(bool hidden);
}

/// In memory (tests, offline).
class MemoryVipSource implements VipSource {
  MemoryVipSource({List<VipHallRow>? hall}) : hall = hall ?? [];

  final List<VipHallRow> hall;
  bool fail = false;
  int reads = 0;
  bool hidden = false;
  VipStatus status = const VipStatus();

  List<VipHallRow> get _sorted => [...hall]
    ..sort((a, b) {
      final c = a.at.compareTo(b.at);
      return c != 0 ? c : a.uid.compareTo(b.uid);
    });

  @override
  Future<List<VipHallRow>> hallPage({
    VipHallRow? after,
    required int limit,
  }) async {
    if (fail) throw StateError('offline');
    reads++;
    final all = _sorted;
    final from = after == null
        ? 0
        : all.indexWhere((r) => r.uid == after.uid) + 1;
    return all.skip(from).take(limit).toList();
  }

  @override
  Future<int> hallCount() async {
    if (fail) throw StateError('offline');
    return hall.length;
  }

  @override
  Future<VipStatus> setHallHidden(bool hidden) async {
    if (fail) throw StateError('offline');
    this.hidden = hidden;
    status = VipStatus(
      level: status.level,
      vnd: status.vnd,
      max: status.max,
      nextVnd: status.nextVnd,
      hallHidden: hidden,
    );
    return status;
  }
}

/// What the VIP screen shows of a tier (spec 4.2 / Nhất 2c): perks that open
/// at that tier. Cosmetic only.
enum VipPerk {
  badge,
  nameColor,
  frame,
  pot,
  chatBubble,
  entryLine,
  petOutfit,
  title,
  hall,
}

/// VIP (spec 4): the owner's tier from the server wallet, the VIP screen
/// (Đặc quyền / Bảng vinh danh), Cài đặt VIP, the level-up popup. Gifts are
/// mails the server sends (claimed through walletClaimMail); nothing here
/// grants anything.
class VipController extends ChangeNotifier {
  VipController(this._s, {this.source});

  final ShopSession _s;
  final VipSource? source;

  /// Bảng vinh danh page size (spec 4.6).
  static const pageSize = 20;

  /// The hall tab and settings are offered from this tier (spec 4.2).
  static const hallLevel = 10;

  VipConfig get config => _s.e.vip;

  /// VIP is shown when economy.json has tiers.
  bool get offered => config.tiers.isNotEmpty;

  /// The server's answer for the signed-in player (null: guest, not read
  /// yet, or a server without VIP).
  VipStatus? get status => _s.signedIn ? _s.wallet?.vip : null;

  int get level => status?.level ?? 0;

  VipTier? tier(int level) {
    for (final t in config.tiers) {
      if (t.level == level) return t;
    }
    return null;
  }

  /// The tier after the current one (null at the top).
  VipTier? get next => tier(level + 1);

  /// 0..1 towards [next] from the current tier's threshold.
  double get progress {
    final n = next;
    final s = status;
    if (n == null) return 1;
    if (s == null) return 0;
    final from = tier(level)?.minVnd ?? 0;
    final span = n.minVnd - from;
    if (span <= 0) return 0;
    return ((s.vnd - from) / span).clamp(0.0, 1.0);
  }

  /// VND still to top up for [next].
  int get toNext {
    final n = next;
    if (n == null) return 0;
    return (n.minVnd - (status?.vnd ?? 0)).clamp(0, n.minVnd);
  }

  /// Perks the game has today. The VIP pots (3, 6), pet outfits (8, 10),
  /// chat bubble (5) and entry line (7) have no art / feature yet (spec 4.7
  /// 🟠), so they are not offered to players until they exist.
  static const livePerks = {
    VipPerk.badge,
    VipPerk.nameColor,
    VipPerk.frame,
    VipPerk.title,
    VipPerk.hall,
  };

  /// The perks that open at [level] (Nhất 2c, spec 4.2) that exist today,
  /// in that order.
  List<VipPerk> perksAt(int level) => [
    for (final p in allPerksAt(level))
      if (livePerks.contains(p)) p,
  ];

  /// Every perk of [level] in spec 4.2, existing or not.
  List<VipPerk> allPerksAt(int level) {
    final t = tier(level);
    if (t == null) return const [];
    final prev = tier(level - 1);
    final pots = [
      for (final e in config.pots.entries)
        if (e.value.level == level) e.key,
    ];
    return [
      VipPerk.badge,
      VipPerk.nameColor,
      if (t.frame.isNotEmpty && t.frame != prev?.frame) VipPerk.frame,
      if (pots.isNotEmpty) VipPerk.pot,
      if (level == 5) VipPerk.chatBubble,
      if (level == 7) VipPerk.entryLine,
      if (level == 8 || level == 10) VipPerk.petOutfit,
      if (level == 10) VipPerk.title,
      if (level == 10) VipPerk.hall,
    ];
  }

  /// The VIP pot ids of [level] (economy.json vip.vipPots).
  List<String> potsAt(int level) => [
    for (final e in config.pots.entries)
      if (e.value.level == level) e.key,
  ];

  // ---- the screen ---------------------------------------------------------

  bool open = false;

  /// 0 Đặc quyền, 1 Bảng vinh danh.
  int tab = 0;

  /// The carousel card shown (tier - 1).
  int card = 0;

  bool settingsOpen = false;

  void openScreen() {
    if (!offered) return;
    open = true;
    tab = 0;
    settingsOpen = false;
    final l = level;
    card = (l >= config.tiers.length ? l - 1 : l).clamp(
      0,
      config.tiers.length - 1,
    );
    notifyListeners();
    unawaited(_s.syncWallet());
  }

  void closeScreen() {
    if (!open) return;
    open = false;
    settingsOpen = false;
    notifyListeners();
  }

  void showTab(int t) {
    if (tab == t) return;
    tab = t;
    notifyListeners();
    if (t == 1 && hall == null && !hallLoading) unawaited(loadHall());
  }

  void showCard(int i) {
    if (i < 0 || i >= config.tiers.length || card == i) return;
    card = i;
    notifyListeners();
  }

  /// "Nạp Pha lê": the Pha lê shop (SePay on web/Android, Apple IAP on iOS:
  /// the shop picks), over which this screen closes.
  void topUp() {
    closeScreen();
    if (!_s.phaleShopOpen) _s.openPhaleShop();
  }

  // ---- Bảng vinh danh -----------------------------------------------------

  /// Rows of the page shown; null before the first read.
  List<VipHallRow>? hall;
  int hallTotal = 0;
  int hallPage = 0;
  bool hallLoading = false;
  bool hallFailed = false;

  /// The last row of each page read, to read the next one.
  final List<VipHallRow?> _pageStarts = [null];

  int get hallPages =>
      hallTotal <= 0 ? 1 : (hallTotal + pageSize - 1) ~/ pageSize;

  Future<void> loadHall({int page = 0}) async {
    final src = source;
    if (src == null || hallLoading) return;
    if (page < 0 || page >= _pageStarts.length) return;
    hallLoading = true;
    hallFailed = false;
    notifyListeners();
    try {
      final rows = await src.hallPage(
        after: _pageStarts[page],
        limit: pageSize,
      );
      if (page == 0) hallTotal = await src.hallCount();
      hall = rows;
      hallPage = page;
      // Their frames (player_avatars), for the avatar of each row.
      unawaited(
        _s.frames.prefetch([
          for (final r in rows)
            if (!r.hidden) r.uid,
        ]),
      );
      if (rows.length == pageSize && _pageStarts.length == page + 1) {
        _pageStarts.add(rows.last);
      }
    } catch (_) {
      hallFailed = true;
    }
    hallLoading = false;
    notifyListeners();
  }

  bool get hallHasNext =>
      hallPage + 1 < hallPages && _pageStarts.length > hallPage + 1;

  Future<void> nextHallPage() => loadHall(page: hallPage + 1);

  Future<void> prevHallPage() => loadHall(page: hallPage - 1);

  // ---- Cài đặt VIP --------------------------------------------------------

  bool hallBusy = false;

  bool get hallHidden => status?.hallHidden ?? false;

  void openSettings() {
    if (!open || !_s.signedIn) return;
    settingsOpen = true;
    notifyListeners();
  }

  void closeSettings() {
    if (!settingsOpen) return;
    settingsOpen = false;
    notifyListeners();
  }

  /// "Ẩn tên khỏi Bảng vinh danh". True when the server took it.
  Future<bool> setHallHidden(bool hidden) async {
    final src = source;
    if (src == null || hallBusy || !_s.signedIn) return false;
    hallBusy = true;
    notifyListeners();
    var ok = false;
    try {
      final got = await src.setHallHidden(hidden);
      _s.applyVipStatus(got);
      ok = true;
      // The hall rows change with it.
      hall = null;
      _pageStarts
        ..clear()
        ..add(null);
      if (tab == 1) unawaited(loadHall());
    } catch (_) {}
    hallBusy = false;
    notifyListeners();
    return ok;
  }

  // ---- level-up popup ------------------------------------------------------

  /// The tier just reached (popup), and the one before it.
  int? levelUp;
  int levelUpFrom = 0;

  String? _seenFor;
  int? _seen;

  /// Each wallet answer: a tier above the one this device last showed opens
  /// the popup (once per tier). A drop only lowers what was seen.
  Future<void> onStatus(VipStatus? v) async {
    final uid = _s.accountUid;
    if (v == null || uid == null || !_s.signedIn) return;
    if (_seenFor != uid) {
      _seenFor = uid;
      try {
        _seen = await _s.progressStore.loadVipSeen(uid) ?? 0;
      } catch (_) {
        _seen = 0;
      }
    }
    final seen = _seen ?? 0;
    if (v.level > seen) {
      levelUpFrom = levelUp == null ? seen : levelUpFrom;
      levelUp = v.level;
      notifyListeners();
    } else if (v.level < seen) {
      _seen = v.level;
      unawaited(_s.progressStore.saveVipSeen(uid, v.level));
    }
  }

  /// "Nhận": the gift is already in Hộp thư (the server sent it).
  void closeLevelUp() {
    final l = levelUp;
    final uid = _s.accountUid;
    if (l == null) return;
    levelUp = null;
    _seen = l;
    if (uid != null) unawaited(_s.progressStore.saveVipSeen(uid, l));
    notifyListeners();
  }

  /// The perks of the tiers just passed (levelUpFrom, levelUp].
  List<(int, VipPerk)> get levelUpPerks {
    final to = levelUp;
    if (to == null) return const [];
    return [
      for (var l = levelUpFrom + 1; l <= to; l++)
        for (final p in perksAt(l))
          if (!(l > levelUpFrom + 1 &&
              (p == VipPerk.badge || p == VipPerk.nameColor)))
            (l, p),
    ];
  }

  /// Gift cards of the tiers just passed.
  int get levelUpTickets {
    final to = levelUp;
    if (to == null) return 0;
    var n = 0;
    for (var l = levelUpFrom + 1; l <= to; l++) {
      n += tier(l)?.giftTickets ?? 0;
    }
    return n;
  }

  /// Signed out: forget.
  void reset() {
    open = false;
    settingsOpen = false;
    levelUp = null;
    _seenFor = null;
    _seen = null;
    hall = null;
    _pageStarts
      ..clear()
      ..add(null);
    notifyListeners();
  }
}
