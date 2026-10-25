import 'dart:convert';

/// Hoa sắp héo (Hà Phương's hoa_sap_heo_block.json): end-of-day clearance
/// basket and dried flowers. Every number comes from the block.
class WiltingRules {
  const WiltingRules({required this.clearance, required this.drying});

  static const asset = 'assets/data/hoa_sap_heo_block.json';

  static const empty = WiltingRules(
    clearance: ClearanceRules.off,
    drying: DryingRules.off,
  );

  final ClearanceRules clearance;
  final DryingRules drying;

  /// Null (an older build's data) leaves the feature out.
  static WiltingRules parse(String? json) {
    if (json == null) return empty;
    final b = jsonDecode(json) as Map<String, dynamic>;
    return WiltingRules(
      clearance: ClearanceRules.fromJson(_map(b, 'clearanceSale')),
      drying: DryingRules.fromJson(_map(b, 'driedFlowers')),
    );
  }
}

Map<String, dynamic> _map(Map? o, String k) =>
    ((o?[k] as Map?) ?? const {}).cast<String, dynamic>();
int _i(Map m, String k) => (m[k] as num?)?.toInt() ?? 0;
double _d(Map m, String k) => (m[k] as num?)?.toDouble() ?? 0;

/// `clearanceSale`: the "Rổ hoa giảm giá" from [startHour] to closing.
class ClearanceRules {
  const ClearanceRules({
    required this.enabled,
    required this.freshnessThreshold,
    required this.startHour,
    required this.discountPercent,
    required this.minDiscountPercentGuard,
    required this.buyersPerDay,
    required this.stemsPerBuyer,
    required this.maxStemsSoldPerDay,
    required this.reservedStemsExcluded,
    required this.summaryLabel,
  });

  static const off = ClearanceRules(
    enabled: false,
    freshnessThreshold: 0,
    startHour: 0,
    discountPercent: 0,
    minDiscountPercentGuard: 0,
    buyersPerDay: 0,
    stemsPerBuyer: 0,
    maxStemsSoldPerDay: 0,
    reservedStemsExcluded: true,
    summaryLabel: '',
  );

  factory ClearanceRules.fromJson(Map<String, dynamic> j) {
    if (j.isEmpty) return off;
    final demand = _map(j, 'demand');
    return ClearanceRules(
      enabled: j['enabled'] == true,
      freshnessThreshold: _i(j, 'freshnessThreshold'),
      startHour: _i(j, 'startHour'),
      discountPercent: _d(j, 'discountPercent'),
      minDiscountPercentGuard: _d(j, 'minDiscountPercentGuard'),
      buyersPerDay: _d(demand, 'buyersPerDay'),
      stemsPerBuyer: _i(demand, 'stemsPerBuyer'),
      maxStemsSoldPerDay: _i(demand, 'maxStemsSoldPerDay'),
      reservedStemsExcluded: j['reservedStemsExcluded'] != false,
      summaryLabel: (j['summaryLabelVi'] as String?) ?? '',
    );
  }

  final bool enabled;
  final int freshnessThreshold;
  final int startHour;
  final double discountPercent;
  final double minDiscountPercentGuard;
  final double buyersPerDay;
  final int stemsPerBuyer;
  final int maxStemsSoldPerDay;
  final bool reservedStemsExcluded;
  final String summaryLabel;

  /// [discountPercent], never below the guard.
  double get discount => discountPercent < minDiscountPercentGuard
      ? minDiscountPercentGuard
      : discountPercent;

  /// roundTo1000down(sellPrice × (1 − discount)).
  int priceFor(int sellPrice) =>
      (sellPrice * (1 - discount) / 1000).floor() * 1000;
}

/// One `driedFlowers.flowers` entry.
class DriedFlowerDef {
  const DriedFlowerDef({
    required this.id,
    required this.name,
    required this.conversionRatio,
    required this.driedSellPrice,
  });

  final String id;
  final String name;
  final double conversionRatio;
  final int driedSellPrice;
}

/// `driedFlowers`: Giàn phơi hoa and the "Kệ hoa khô" (single stems only).
class DryingRules {
  const DryingRules({
    required this.enabled,
    required this.unlockDay,
    required this.unlockCost,
    required this.inputFreshnessMax,
    required this.dryingDays,
    required this.dryingCostPerStem,
    required this.storageCap,
    required this.flowers,
    required this.shelfBuyersPerDay,
    required this.shelfStemsPerBuyer,
    required this.holidayBuyersMultiplier,
    required this.summaryLabel,
  });

  static const off = DryingRules(
    enabled: false,
    unlockDay: 0,
    unlockCost: 0,
    inputFreshnessMax: 0,
    dryingDays: 0,
    dryingCostPerStem: 0,
    storageCap: 0,
    flowers: [],
    shelfBuyersPerDay: 0,
    shelfStemsPerBuyer: 0,
    holidayBuyersMultiplier: 1,
    summaryLabel: '',
  );

  factory DryingRules.fromJson(Map<String, dynamic> j) {
    if (j.isEmpty) return off;
    final unlock = _map(j, 'unlock');
    final shelf = _map(j, 'shelfSales');
    return DryingRules(
      enabled: j['enabled'] == true,
      unlockDay: _i(unlock, 'day'),
      unlockCost: _i(unlock, 'unlockCost'),
      inputFreshnessMax: _i(j, 'inputFreshnessMax'),
      dryingDays: _i(j, 'dryingDays'),
      dryingCostPerStem: _i(j, 'dryingCostPerStem'),
      storageCap: _i(j, 'storageCap'),
      flowers: [
        for (final f
            in ((j['flowers'] as List?) ?? const [])
                .cast<Map<String, dynamic>>())
          DriedFlowerDef(
            id: f['id'] as String,
            name: (f['nameVi'] as String?) ?? '',
            conversionRatio: _d(f, 'conversionRatio'),
            driedSellPrice: _i(f, 'driedSellPrice'),
          ),
      ],
      shelfBuyersPerDay: _d(shelf, 'buyersPerDay'),
      shelfStemsPerBuyer: _i(shelf, 'stemsPerBuyer'),
      holidayBuyersMultiplier:
          (shelf['holidayBuyersMultiplier'] as num?)?.toDouble() ?? 1,
      summaryLabel: (j['summaryLabelVi'] as String?) ?? '',
    );
  }

  final bool enabled;
  final int unlockDay;
  final int unlockCost;
  final int inputFreshnessMax;
  final int dryingDays;
  final int dryingCostPerStem;
  final int storageCap;

  /// The block's list is the source of truth for what can be dried.
  final List<DriedFlowerDef> flowers;
  final double shelfBuyersPerDay;
  final int shelfStemsPerBuyer;
  final double holidayBuyersMultiplier;
  final String summaryLabel;

  DriedFlowerDef? byId(String id) {
    for (final f in flowers) {
      if (f.id == id) return f;
    }
    return null;
  }

  bool canDry(String flowerId) => byId(flowerId) != null;
}
