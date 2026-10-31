import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/season_clock.dart';
import 'season_pass.dart';
import 'wallet.dart';

/// Where the Season Pass reads from (Firestore in the app, fakes in tests).
abstract class SeasonPassSource {
  /// `config/seasonPass.themeByPeriod`: a season without a theme has no pass.
  Future<Map<String, String>> themeByPeriod();

  /// `season_pass/{uid}/seasons/{period}`; null before the server wrote it.
  Future<Map<String, Object?>?> seasonDoc(String uid, String period);
}

enum SeasonPassPhase { loading, closed, ready, error }

/// What a buy press ended in.
enum SeasonPassBuy { bought, notEnough, failed, pending }

/// The pass screen's state. Every number on it is the server's: the season
/// doc and the callables' answers; nothing is counted or unlocked locally,
/// and an action only changes the screen once the server answered.
class SeasonPassController extends ChangeNotifier {
  SeasonPassController({
    required this.config,
    required this.clock,
    required this.source,
    required this.uid,
    required this.api,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SeasonPassConfig? config;
  final SeasonClock? clock;
  final SeasonPassSource? source;
  final String? Function() uid;
  final WalletApi? Function() api;
  final DateTime Function() _now;

  SeasonPassPhase phase = SeasonPassPhase.loading;
  SeasonPassView? view;

  /// The next start of a themed season (empty state), when known.
  DateTime? opensAt;

  /// `track_tier` keys waiting for the server; [buying] for the purchase.
  final pending = <String>{};
  bool buying = false;

  /// One-shot toast for the screen: `sp_pending` / `sp_claim_failed`.
  String? toastKey;

  /// The last answer of a claim with its rewards, for the result dialog.
  List<(int, SeasonPassTrack)> lastClaimed = const [];

  int _loads = 0;

  /// The button on the shop bar shows only during a season with a theme.
  bool get entryVisible =>
      phase == SeasonPassPhase.ready && view != null && !view!.ended;

  /// Tiers waiting (the red dot). Missions are given by the server on their
  /// own, so they never wait for a press.
  int get claimableCount => view?.claimables.length ?? 0;

  static String key(int tier, SeasonPassTrack t) => '${t.json}_$tier';

  Future<void> load() async {
    final cfg = config;
    final c = clock;
    final src = source;
    final id = uid();
    final load = ++_loads;
    if (cfg == null || c == null || src == null || id == null) {
      phase = SeasonPassPhase.closed;
      opensAt = null;
      notifyListeners();
      return;
    }
    if (view == null) {
      phase = SeasonPassPhase.loading;
      notifyListeners();
    }
    try {
      final now = _now();
      final themes = await src.themeByPeriod();
      final first = cfg.firstSeasonStart;
      final season = c.at(now);
      final started =
          (first == null || !now.isBefore(first)) &&
          !now.isBefore(season.start);
      final themeId = themes[season.period];
      if (!started || themeId == null || !cfg.themes.containsKey(themeId)) {
        if (load != _loads) return;
        view = null;
        opensAt = _nextOpen(cfg, c, themes, now);
        phase = SeasonPassPhase.closed;
        notifyListeners();
        return;
      }
      final doc = await src.seasonDoc(id, season.period);
      if (load != _loads) return;
      view = SeasonPassView(
        config: cfg,
        season: season,
        themeId: themeId,
        status: SeasonPassStatus.fromJson({
          ...?doc,
          'period': season.period,
          'themeId': themeId,
        }),
        now: now,
      );
      pending.clear();
      phase = SeasonPassPhase.ready;
    } catch (_) {
      if (load != _loads) return;
      // No cached numbers shown as if they were live (spec §6).
      view = null;
      phase = SeasonPassPhase.error;
    }
    notifyListeners();
  }

  DateTime? _nextOpen(
    SeasonPassConfig cfg,
    SeasonClock c,
    Map<String, String> themes,
    DateTime now,
  ) {
    var s = c.at(now);
    final first = cfg.firstSeasonStart;
    for (var i = 0; i < 14; i++) {
      final opens = first != null && s.start.isBefore(first) ? first : s.start;
      final theme = themes[s.period];
      if (opens.isAfter(now) &&
          theme != null &&
          cfg.themes.containsKey(theme)) {
        return opens;
      }
      s = c.season(s.number + 1);
    }
    return null;
  }

  void _answer(SeasonPassStatus pass) {
    final v = view;
    if (v == null) return;
    view = SeasonPassView(
      config: v.config,
      season: v.season,
      themeId: v.themeId,
      status: v.status.withAnswer(pass),
      now: _now(),
    );
  }

  /// One tier's track. True when the server gave it.
  Future<bool> claim(int tier, SeasonPassTrack track) async {
    final ok = await _claimMany([(tier, track)]);
    return ok.isNotEmpty;
  }

  /// "Nhận tất cả": the server has no batch call, so each tier is its own
  /// claim, in order; it stops at the first refusal.
  Future<List<(int, SeasonPassTrack)>> claimAll() =>
      _claimMany(view?.claimables ?? const []);

  Future<List<(int, SeasonPassTrack)>> _claimMany(
    List<(int, SeasonPassTrack)> items,
  ) async {
    final a = api();
    final v = view;
    final done = <(int, SeasonPassTrack)>[];
    if (a == null || v == null || items.isEmpty) return done;
    final todo = [
      for (final i in items)
        if (v.claimable(i.$1, i.$2) && !pending.contains(key(i.$1, i.$2))) i,
    ];
    if (todo.isEmpty) return done;
    pending.addAll([for (final i in todo) key(i.$1, i.$2)]);
    notifyListeners();
    for (final i in todo) {
      try {
        final r = await SeasonPassService(a).claim(i.$1, i.$2);
        _answer(r.pass);
        pending.remove(key(i.$1, i.$2));
        done.add(i);
      } on WalletException catch (e) {
        if (e.code == 'network') {
          toastKey = 'sp_pending';
          notifyListeners();
          unawaited(_retryLoad());
          return done;
        }
        toastKey = 'sp_claim_failed';
        pending.clear();
        await load();
        lastClaimed = done;
        return done;
      } catch (_) {
        toastKey = 'sp_claim_failed';
        pending.clear();
        await load();
        lastClaimed = done;
        return done;
      }
      notifyListeners();
    }
    pending.clear();
    lastClaimed = done;
    notifyListeners();
    return done;
  }

  /// Buy the premium track with Pha lê ([phaLe] = the server's balance).
  /// Callers check [phaLe] first and show the "not enough" dialog instead.
  Future<SeasonPassBuy> buy() async {
    final a = api();
    if (a == null || view == null || buying) return SeasonPassBuy.failed;
    buying = true;
    notifyListeners();
    try {
      final r = await SeasonPassService(a).buyPremium();
      _answer(r.pass);
      return SeasonPassBuy.bought;
    } on WalletException catch (e) {
      if (e.code == 'balance') return SeasonPassBuy.notEnough;
      if (e.code == 'network') {
        toastKey = 'sp_pending';
        unawaited(_retryLoad());
        return SeasonPassBuy.pending;
      }
      toastKey = 'sp_claim_failed';
      unawaited(load());
      return SeasonPassBuy.failed;
    } catch (_) {
      toastKey = 'sp_claim_failed';
      unawaited(load());
      return SeasonPassBuy.failed;
    } finally {
      buying = false;
      notifyListeners();
    }
  }

  /// After a lost answer: read the server doc again (it holds the truth).
  Future<void> _retryLoad() async {
    await Future<void>.delayed(const Duration(seconds: 5));
    await load();
  }

  /// The screen's minute tick: the countdown and the season's end move
  /// with the clock, nothing else.
  void tick() {
    final v = view;
    if (v == null) return;
    view = SeasonPassView(
      config: v.config,
      season: v.season,
      themeId: v.themeId,
      status: v.status,
      now: _now(),
    );
    notifyListeners();
  }

  String? takeToast() {
    final t = toastKey;
    toastKey = null;
    return t;
  }
}
