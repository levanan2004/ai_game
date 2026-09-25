import '../data/economy.dart';
import 'format.dart';

/// Effects of the upgrades the player owns (economy.json `upgrades`).
/// Each level's effect values are totals that replace the previous level's.
class UpgradeEffects {
  const UpgradeEffects(this.e, this.levels, {this.adsActive = false});

  final Economy e;
  final Map<String, int> levels;
  final bool adsActive;

  UpgradeLevel? current(String id) {
    final lv = levels[id] ?? 0;
    if (lv <= 0) return null;
    final u = e.upgrades.where((u) => u.id == id);
    if (u.isEmpty) return null;
    final defs = u.first.levels;
    return defs[(lv > defs.length ? defs.length : lv) - 1];
  }

  Object? effect(String id, String key) => current(id)?.effect[key];

  num _num(String id, String key, num fallback) {
    final v = effect(id, key);
    return v is num ? v : fallback;
  }

  double get customerMultiplier {
    var m = _num('display', 'customerMultiplier', 1).toDouble();
    if (adsActive) {
      final ads = e.upgrades.where((u) => u.id == 'ads');
      if (ads.isNotEmpty) {
        final v = ads.first.levels.first.effect['customerMultiplier'];
        if (v is num) m *= v;
      }
    }
    return m;
  }

  double get patienceMultiplier =>
      _num('bench', 'patienceMultiplier', 1).toDouble();
  int get counterSlots =>
      _num('counter', 'counterSlots', e.counterSlots).toInt();
  int get maxQueue => _num('counter', 'maxQueue', e.maxQueue).toInt();
  int get freshnessBonusDays =>
      _num('cold_storage', 'freshnessBonusDays', 0).toInt();
  double get greenZoneBonus =>
      _num('wrapping_table', 'greenZoneBonus', 0).toDouble();
  double get wrapTimeReduction =>
      _num('wrapping_table', 'wrapTimeReduction', 0).toDouble();
  bool get autoPaperRibbon => effect('staff', 'autoPaperRibbon') == true;
  double? get autoServeSeconds {
    final v = effect('staff', 'autoServeSeconds');
    return v is num ? v.toDouble() : null;
  }

  int get autoServeMaxStems =>
      _num('staff', 'autoServeMaxStems', e.maxStems).toInt();
  String get autoServeTier {
    final v = effect('staff', 'autoServeTier');
    return v is String ? v : 'okay';
  }

  /// Sum of `dailyUpkeep` and `dailyWage` of the owned levels.
  int get dailyCosts {
    var sum = 0;
    for (final u in e.upgrades) {
      final c = current(u.id);
      if (c == null || u.consumable) continue;
      sum += c.dailyUpkeep + c.dailyWage;
    }
    return sum;
  }
}

/// Why an upgrade button is disabled (null = can buy).
enum UpgradeBlock {
  maxed,
  comingSoon,
  shopOpen,
  negativeMoney,
  requires,
  adsRunning,
  poor,
}

/// Effect keys the game loop does not implement yet. An upgrade whose
/// effects are all in here can't be bought (it would cost money and upkeep
/// for nothing). TODO(Khoa): online orders have no UI spec yet.
const unimplementedEffectKeys = {'ordersPerDay', 'deliveryFee'};

bool isComingSoon(UpgradeLevel level) {
  final keys = [
    for (final k in level.effect.keys)
      if (!k.startsWith('_') && k != 'requires') k,
  ];
  return keys.isNotEmpty && keys.every(unimplementedEffectKeys.contains);
}

class UpgradeStatus {
  const UpgradeStatus({
    required this.next,
    required this.block,
    this.requiresId,
    this.requiresLevel = 0,
  });

  final UpgradeLevel? next;
  final UpgradeBlock? block;
  final String? requiresId;
  final int requiresLevel;

  bool get canBuy => block == null;
}

UpgradeStatus upgradeStatus(
  Economy e, {
  required String id,
  required Map<String, int> levels,
  required int money,
  required bool shopClosed,
  required int adsDaysLeft,
}) {
  final u = e.upgrade(id);
  final lv = levels[id] ?? 0;
  if (u.consumable) {
    final next = u.levels.first;
    if (adsDaysLeft > 0) {
      return UpgradeStatus(next: next, block: UpgradeBlock.adsRunning);
    }
    return UpgradeStatus(
      next: next,
      block: _moneyBlock(money, next.cost, shopClosed),
    );
  }
  if (lv >= u.maxLevel) {
    return const UpgradeStatus(next: null, block: UpgradeBlock.maxed);
  }
  final next = u.levels[lv];
  if (isComingSoon(next)) {
    return UpgradeStatus(next: next, block: UpgradeBlock.comingSoon);
  }
  for (final r in next.requires.entries) {
    if ((levels[r.key] ?? 0) < r.value) {
      return UpgradeStatus(
        next: next,
        block: UpgradeBlock.requires,
        requiresId: r.key,
        requiresLevel: r.value,
      );
    }
  }
  return UpgradeStatus(
    next: next,
    block: _moneyBlock(money, next.cost, shopClosed),
  );
}

UpgradeBlock? _moneyBlock(int money, int cost, bool shopClosed) {
  if (!shopClosed) return UpgradeBlock.shopOpen;
  if (money < 0) return UpgradeBlock.negativeMoney;
  if (money < cost) return UpgradeBlock.poor;
  return null;
}

String _pct(num fraction) => '${(fraction * 100).round()}';

/// Effect keys that have a sentence in spec_nang_cap.md, or are folded into
/// another key's sentence (`maxQueue`, `autoServeMaxStems`, `deliveryFee`)
/// or deliberately silent (`autoServeTier`).
const knownEffectKeys = {
  'freshnessBonusDays',
  'wrapTimeReduction',
  'greenZoneBonus',
  'customerMultiplier',
  'patienceMultiplier',
  'counterSlots',
  'maxQueue',
  'autoPaperRibbon',
  'stemTimeReduction',
  'autoServeSeconds',
  'autoServeMaxStems',
  'autoServeTier',
  'ordersPerDay',
  'deliveryFee',
};

/// Keys of [effect] the composer cannot turn into words (no template yet).
/// `requires` and `_*` keys are ignored on purpose and not listed.
List<String> skippedEffectKeys(Map<String, Object> effect) => [
  for (final k in effect.keys)
    if (!k.startsWith('_') && k != 'requires' && !knownEffectKeys.contains(k))
      k,
];

/// Effect sentence parts from the spec_nang_cap.md templates, in the order
/// the keys appear. `requires`, `_*` keys and unknown keys are skipped (no
/// crash, no raw key shown); `deliveryFee` goes right after `ordersPerDay`.
List<String> describeEffectParts(Map<String, Object> effect) {
  final parts = <String>[];
  String? fee() {
    final f = effect['deliveryFee'];
    return f is num ? 'thu phí giao ${formatK(f.round())} mỗi đơn' : null;
  }

  for (final entry in effect.entries) {
    final k = entry.key;
    final v = entry.value;
    if (k.startsWith('_') || k == 'requires') continue;
    switch (k) {
      case 'freshnessBonusDays' when v is num:
        parts.add('hoa tươi thêm $v ngày');
      case 'wrapTimeReduction' when v is num:
        parts.add('gói nhanh hơn ${_pct(v)}%');
      case 'greenZoneBonus':
        parts.add('vùng xanh rộng hơn');
      case 'customerMultiplier' when v is num:
        parts.add('thêm ${_pct(v - 1)}% khách');
      case 'patienceMultiplier' when v is num:
        parts.add('khách chờ lâu hơn ${_pct(v - 1)}%');
      case 'counterSlots' when v is num:
        final q = effect['maxQueue'];
        parts.add(
          q is num ? '$v chỗ ở quầy, hàng chờ $q người' : '$v chỗ ở quầy',
        );
      case 'maxQueue' when v is num && effect['counterSlots'] is! num:
        parts.add('hàng chờ $v người');
      case 'autoPaperRibbon' when v == true:
        parts.add('tự chọn giấy và nơ');
      case 'stemTimeReduction':
        parts.add('nhặt hoa nhanh hơn');
      case 'autoServeSeconds' when v is num:
        final m = effect['autoServeMaxStems'];
        parts.add(
          m is num
              ? 'nhân viên tự bó đơn tối đa $m cành, mỗi đơn $v giây'
              : 'nhân viên tự bó đơn, mỗi đơn $v giây',
        );
      case 'ordersPerDay' when v is num:
        parts.add('$v đơn online mỗi ngày');
        final f = fee();
        if (f != null) parts.add(f);
      case 'deliveryFee' when effect['ordersPerDay'] is! num:
        final f = fee();
        if (f != null) parts.add(f);
      default:
        // Folded keys (maxQueue, autoServeMaxStems, deliveryFee), the silent
        // autoServeTier, and keys without a template are skipped.
        break;
    }
  }
  return parts;
}

String describeEffect(Map<String, Object> effect) =>
    describeEffectParts(effect).join(', ');

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "phí 5k/ngày" for a level with upkeep or wage, else null.
String? upkeepLabel(UpgradeLevel? l) {
  if (l == null) return null;
  final c = l.dailyUpkeep + l.dailyWage;
  return c > 0 ? 'phí ${formatK(c)}/ngày' : null;
}
