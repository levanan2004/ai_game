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

  static Future<void> tutorialDone({required bool skipped}) =>
      _log('tutorial_complete', {'skipped': skipped ? 1 : 0});

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    final ga = _ga;
    if (ga == null) return;
    try {
      await ga.logEvent(name: name, parameters: params);
    } catch (_) {}
  }
}
