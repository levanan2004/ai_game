import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

/// Game events for Google Analytics. Quiet when Firebase never started
/// (tests, offline). Never sends a name, email, photo, or typed shop name.
abstract final class PlayAnalytics {
  static FirebaseAnalytics? get _ga =>
      Firebase.apps.isEmpty ? null : FirebaseAnalytics.instance;

  /// Someone opened the game in the browser.
  static Future<void> visit() async {
    final ga = _ga;
    if (ga == null) return;
    try {
      await ga.logAppOpen();
      await ga.logEvent(name: 'visit');
    } catch (_) {}
  }

  static Future<void> login() => _log('login', {'method': 'google'});

  static Future<void> dayOpen(int day) => _log('day_open', {'day': day});

  static Future<void> dayEnd({
    required int revenue,
    required int bouquets,
    required int left,
    required int wilted,
    required double stars,
  }) => _log('day_end', {
    'revenue': revenue,
    'bouquets': bouquets,
    'left': left,
    'wilted': wilted,
    'stars': stars,
  });

  static Future<void> upgrade(String id) =>
      _log('upgrade_buy', {'item_id': id});

  static Future<void> adReward() => _log('ad_reward');

  /// Rewarded-video funnel. [adReward] is the ad-free upgrade, not this.
  /// Impression in AdMob is [rewardedShow] (the ad appeared), not [rewardedEarn].
  static final rewardedEntrySeenKinds = <String>{};

  /// True the first time [kind] is noted. Later calls are false.
  static bool noteRewardedEntrySeen(String kind) =>
      rewardedEntrySeenKinds.add(kind);

  /// [place] is where the button sat: `topbar`, `home`, `summary`, `short`, `shop`.
  static void rewardedEntrySeen(String kind, {String place = 'entry'}) {
    if (!noteRewardedEntrySeen('$place:$kind')) return;
    _log('rw_entry_seen', {'kind': kind, 'place': place});
  }

  static void rewardedEntryTap(String kind, {String place = 'entry'}) =>
      _log('rw_entry_tap', {'kind': kind, 'place': place});

  static void rewardedSheet(String kind) => _log('rw_sheet', {'kind': kind});

  static void rewardedWatchTap(String kind) =>
      _log('rw_watch_tap', {'kind': kind});

  static void rewardedLoad(String kind, {required bool ok}) =>
      _log('rw_load', {'kind': kind, 'ok': ok ? 1 : 0});

  static void rewardedShow(String kind) => _log('rw_show', {'kind': kind});

  static void rewardedEarn(String kind) => _log('rw_earn', {'kind': kind});

  static void rewardedClose(String kind, String outcome) =>
      _log('rw_close', {'kind': kind, 'outcome': outcome});

  static Future<void> tutorialDone({required bool skipped}) =>
      _log('tutorial_complete', {'skipped': skipped ? 1 : 0});

  /// Sổ tay khách quen (spec_so_tay_khach_quen.md §9).
  static Future<void> notebookOpen() => _log('notebook_open');

  static Future<void> regularCardOpen(String id) =>
      _log('regular_card_open', {'id': id});

  static Future<void> letterOpen(String id, int step) =>
      _log('letter_open', {'id': id, 'step': step});

  static Future<void> inviteAgain(String id, int step) =>
      _log('invite_again', {'id': id, 'step': step});

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    final ga = _ga;
    if (ga == null) return;
    try {
      await ga.logEvent(name: name, parameters: params);
    } catch (_) {}
  }
}
