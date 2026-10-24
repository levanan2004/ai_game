import '../data/economy.dart';
import '../save/game_state.dart';
import 'pet.dart';

/// Stats of the pots on the shelf: the bar and the display shelf
/// (`potStatsRules.shelfSlots`, 11). A pot in the cupboard adds nothing.
/// Values of every pot on the shelf add up (`potStatsRules.stack`); with
/// `sameTypeCountsOnce` a pot type counts once however many copies stand
/// there. The numbers are `pots[].stats` in economy.json.
class PotShelfStats {
  const PotShelfStats(this.values);

  static const none = PotShelfStats({});

  /// [PotStat] key -> summed value (0..1 fractions).
  final Map<String, double> values;

  double operator [](String key) => values[key] ?? 0;

  double get incomeBonus => this[PotStat.incomeBonus];
  double get tipBonus => this[PotStat.tipBonus];
  double get onlineOrderBonus => this[PotStat.onlineOrderBonus];
  double get theftRecoverBonus => this[PotStat.theftRecoverBonus];
  double get mouseCatch => this[PotStat.mouseCatch];
  double get patienceBonus => this[PotStat.patienceBonus];
  double get wiltSaveChance => this[PotStat.wiltSaveChance];
  double get marketDiscount => this[PotStat.marketDiscount];
  double get wrapSpeedBonus => this[PotStat.wrapSpeedBonus];
  double get mysteryChance => this[PotStat.mysteryChance];
}

PotShelfStats potShelfStats(Economy e, GameState state) {
  final sum = <String, double>{};
  final ids = [...state.barPots, ...state.displayPots];
  for (final id in e.potStatsRules.sameTypeCountsOnce ? ids.toSet() : ids) {
    final pot = e.potOrNull(id);
    if (pot == null) continue;
    for (final s in pot.stats.entries) {
      sum[s.key] = (sum[s.key] ?? 0) + s.value;
    }
  }
  return sum.isEmpty ? PotShelfStats.none : PotShelfStats(sum);
}

/// Mị lực one pot type adds while owned: its own `charm`, or for a Sơn Hải
/// pot without one `charm.sonHaiCharmPerType`.
int potTypeCharm(Economy e, PotDef pot) {
  if (pot.charm > 0) return pot.charm;
  return pot.set == 'sonHai' ? e.charmRules.sonHaiCharmPerType : 0;
}

/// The pot part of Mị lực: each owned pot TYPE once (several copies of one
/// type still count once), shelf or cupboard alike, kept under
/// `charm.partMax.sonHaiPots`.
int ownedPotsCharm(Economy e, GameState state) {
  var sum = 0;
  for (final entry in state.potCounts.entries) {
    if (entry.value <= 0) continue;
    final pot = e.potOrNull(entry.key);
    if (pot == null) continue;
    sum += potTypeCharm(e, pot);
  }
  return clampCharmPart(sum, e.charmRules.potsMax);
}

/// A Mị lực part kept inside 0..[max]; a [max] of 0 means not set.
int clampCharmPart(int v, int max) {
  if (v < 0) return 0;
  if (max > 0 && v > max) return max;
  return v;
}

/// Lines of a pot card (Nhất, chu_chi_tiet_chau.md 1b): the Mị lực line
/// for a pot with charm, then one line per stat. Empty for a plain pot.
List<String> potStatLines(Economy e, PotDef pot) {
  final charm = potTypeCharm(e, pot);
  return [
    if (charm > 0) 'Mị lực +$charm (tính khi sở hữu)', // pot.detail.charm
    ...potStatOnlyLines(pot),
  ];
}

/// One line per shelf stat of [pot] (`pot.stat.*`), fractions shown as
/// percent ("1,5%"). Empty for a pot without stats.
List<String> potStatOnlyLines(PotDef pot) {
  final lines = <String>[];
  for (final key in PotStat.all) {
    final v = pot.stats[key];
    if (v == null || v <= 0) continue;
    final p = '${petPercent(v)}%';
    lines.add(switch (key) {
      PotStat.mysteryChance => 'Khách thần bí +$p', // pot.stat.mystery_chance
      PotStat.incomeBonus => 'Thu nhập +$p', // pot.stat.income
      PotStat.onlineOrderBonus =>
        'Tiền đơn giao online +$p', // pot.stat.online_order
      PotStat.theftRecoverBonus =>
        'Lấy lại tiền khi bị trộm +$p', // pot.stat.theft_recover
      PotStat.tipBonus => 'Tiền tip +$p', // pot.stat.tip
      PotStat.mouseCatch => 'Bắt chuột +$p', // pot.stat.mouse_catch
      PotStat.patienceBonus => 'Khách chờ lâu hơn +$p', // pot.stat.patience
      PotStat.wiltSaveChance =>
        'Giữ tươi thêm: $p mỗi ngày', // pot.stat.wilt_save
      PotStat.marketDiscount =>
        'Giá hoa ở chợ rẻ hơn $p', // pot.stat.market_discount
      PotStat.wrapSpeedBonus => 'Gói hoa nhanh hơn $p', // pot.stat.wrap_faster
      _ => '',
    });
  }
  return [
    for (final l in lines)
      if (l.isNotEmpty) l,
  ];
}
