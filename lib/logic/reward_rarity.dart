/// How rare a reward item looks: picks the frame drawn behind its icon
/// (Phú's khung_thuong / khung_hiem / khung_su_thi / khung_huyen_thoai).
library;

import '../data/rarity_rules.dart';
import 'rewards.dart';

export '../data/rarity_rules.dart';

/// One rule for the whole game, so every gift popup agrees. The tiers come
/// from economy.json `rewardRarity` ([RarityRules.current]); pass [rules]
/// to use another table.
RewardRarity rewardRarity(RewardItem item, [RarityRules? rules]) =>
    (rules ?? RarityRules.current).of(item.kind.json, item.amount);
