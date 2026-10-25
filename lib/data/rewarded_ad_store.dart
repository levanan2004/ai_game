import 'package:shared_preferences/shared_preferences.dart';

import '../logic/rewarded_ad.dart';

/// Local count of rewarded ads watched today. Not part of the cloud save:
/// the xu and Pha lê themselves are written by [ShopSession.grantRewards].
class RewardedAdStore {
  static const _key = 'rewarded-ad-day';

  Future<RewardedAdLedger> load(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    return RewardedAdLedger.forDay(_parse(prefs.getString(_key)), now);
  }

  Future<void> save(RewardedAdLedger ledger) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, '${ledger.day}|${ledger.xu}|${ledger.phaLe}');
  }

  static RewardedAdLedger? _parse(String? raw) {
    if (raw == null) return null;
    final p = raw.split('|');
    if (p.length != 3) return null;
    final xu = int.tryParse(p[1]);
    final phaLe = int.tryParse(p[2]);
    if (xu == null || phaLe == null) return null;
    return RewardedAdLedger(day: p[0], xu: xu, phaLe: phaLe);
  }
}
