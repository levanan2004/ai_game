import 'package:shared_preferences/shared_preferences.dart';

import 'ad_launch.dart';

/// First time this iOS install opened the app, in epoch milliseconds.
const iosFirstOpenKey = 'ios_ads_first_open_ms';

/// Remembers [now] the first time it is called, then returns that instant.
Future<DateTime> rememberIosFirstOpen(DateTime now) async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getInt(iosFirstOpenKey);
  final firstMs = stored ?? now.millisecondsSinceEpoch;
  if (stored == null) await prefs.setInt(iosFirstOpenKey, firstMs);
  return DateTime.fromMillisecondsSinceEpoch(firstMs);
}

/// No AdMob request yet: this iOS install is still inside [iosAdQuietPeriod].
Future<bool> iosAdRequestsBlocked(DateTime now) async {
  final first = await rememberIosFirstOpen(now);
  return iosAdsQuiet(first, now);
}
