/// How rare a reward looks, and the amount tiers that decide it.
///
/// The numbers live in `assets/data/economy.json` under `rewardRarity`
/// (Hà Phương edits them there). [RarityRules.defaults] is the same table,
/// used when that key is missing.
library;

enum RewardRarity {
  thuong('khung_thuong', 'Thường'),
  hiem('khung_hiem', 'Hiếm'),
  suThi('khung_su_thi', 'Sử thi'),
  huyenThoai('khung_huyen_thoai', 'Huyền thoại');

  const RewardRarity(this.frame, this.label);

  /// File id under `assets/images/phuc_loi/`.
  final String frame;
  final String label;

  static RewardRarity? fromJson(Object? raw) {
    for (final r in values) {
      if (r.name == raw) return r;
    }
    return null;
  }
}

/// From [from] (inclusive) up, the item is [rarity].
class RarityTier {
  const RarityTier(this.from, this.rarity);

  final int from;
  final RewardRarity rarity;
}

/// One reward kind: [base] below every tier, then the highest tier reached.
class RarityRule {
  const RarityRule(this.base, [this.tiers = const []]);

  final RewardRarity base;

  /// Sorted by [RarityTier.from], lowest first.
  final List<RarityTier> tiers;

  RewardRarity at(int amount) {
    var r = base;
    for (final t in tiers) {
      if (amount >= t.from) r = t.rarity;
    }
    return r;
  }
}

/// The whole table, keyed by reward kind json name (`coins`, `giotHoa`, ...).
class RarityRules {
  const RarityRules(this.byKind);

  final Map<String, RarityRule> byKind;

  /// Code defaults, matching economy.json:
  /// xu < 300k thường, >= 300k hiếm; giọt hoa < 20 hiếm, >= 20 sử thi;
  /// Pha lê < 500 hiếm, >= 500 sử thi; bánh mật thường; cat seats/bowls
  /// hiếm; thần thú pots sử thi; the cat huyền thoại.
  static const defaults = RarityRules({
    'coins': RarityRule(RewardRarity.thuong, [
      RarityTier(300000, RewardRarity.hiem),
    ]),
    'giotHoa': RarityRule(RewardRarity.hiem, [
      RarityTier(20, RewardRarity.suThi),
    ]),
    'phaLe': RarityRule(RewardRarity.hiem, [
      RarityTier(500, RewardRarity.suThi),
    ]),
    'treat': RarityRule(RewardRarity.thuong),
    'petSkin': RarityRule(RewardRarity.hiem),
    'pot': RarityRule(RewardRarity.suThi),
    'cat': RarityRule(RewardRarity.huyenThoai),
  });

  /// The table the UI reads. The app sets it from economy.json on load.
  static RarityRules current = defaults;

  /// Parses `economy.json` -> `rewardRarity`. A missing key (or a missing
  /// kind) keeps the code default; a misspelt kind or rarity throws.
  factory RarityRules.fromJson(Object? json) {
    if (json == null) return defaults;
    if (json is! Map) {
      throw const FormatException('economy.json: "rewardRarity" must be a map');
    }
    final out = Map<String, RarityRule>.of(defaults.byKind);
    for (final e in json.entries) {
      final kind = e.key as String;
      if (kind.startsWith('_')) continue;
      final fallback = defaults.byKind[kind];
      if (fallback == null) {
        throw FormatException('economy.json: unknown "rewardRarity.$kind"');
      }
      final v = e.value as Map;
      RewardRarity rarity(Object? raw, String path) =>
          RewardRarity.fromJson(raw) ??
          (throw FormatException(
            'economy.json: "rewardRarity.$kind.$path" must be one of '
            '${RewardRarity.values.map((r) => r.name).join(', ')}',
          ));
      final base = v.containsKey('base')
          ? rarity(v['base'], 'base')
          : fallback.base;
      final tiers = v.containsKey('tiers')
          ? [
              for (final t in (v['tiers'] as List).cast<Map>())
                RarityTier(
                  (t['from'] as num).toInt(),
                  rarity(t['rarity'], 'tiers.rarity'),
                ),
            ]
          : [...fallback.tiers];
      tiers.sort((a, b) => a.from.compareTo(b.from));
      out[kind] = RarityRule(base, List.unmodifiable(tiers));
    }
    return RarityRules(Map.unmodifiable(out));
  }

  RewardRarity of(String kind, int amount) =>
      (byKind[kind] ?? const RarityRule(RewardRarity.thuong)).at(amount);
}
