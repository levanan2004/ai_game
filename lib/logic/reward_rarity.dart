/// How rare a reward item looks: picks the frame drawn behind its icon
/// (Phú's khung_thuong / khung_hiem / khung_su_thi / khung_huyen_thoai).
library;

import 'rewards.dart';

enum RewardRarity {
  thuong('khung_thuong', 'Thường'),
  hiem('khung_hiem', 'Hiếm'),
  suThi('khung_su_thi', 'Sử thi'),
  huyenThoai('khung_huyen_thoai', 'Huyền thoại');

  const RewardRarity(this.frame, this.label);

  /// File id under `assets/images/phuc_loi/`.
  final String frame;
  final String label;
}

/// Pha lê from this amount up counts as sử thi.
const phaLeEpicAmount = 500;

/// One rule for the whole game, so every gift popup agrees:
/// xu and bánh mật are thường; giọt hoa, cat seats/bowls and small Pha lê
/// are hiếm; big Pha lê and the mythical pots are sử thi; the cat itself is
/// huyền thoại.
RewardRarity rewardRarity(RewardItem item) => switch (item.kind) {
  RewardKind.coins || RewardKind.treat => RewardRarity.thuong,
  RewardKind.giotHoa || RewardKind.petSkin => RewardRarity.hiem,
  RewardKind.phaLe =>
    item.amount >= phaLeEpicAmount ? RewardRarity.suThi : RewardRarity.hiem,
  RewardKind.pot => RewardRarity.suThi,
  RewardKind.cat => RewardRarity.huyenThoai,
};
