import 'package:flutter/material.dart';

import '../logic/pet.dart';
import '../logic/rewards.dart';
import '../logic/xu_grant.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'gift_admin_panel.dart';
import 'reward_bundle_view.dart';

/// The Quà tặng gift cards (pots, Pha lê, Giọt hoa, …) plus a Xu field,
/// editing one [RewardBundle]. Only one picker may be on screen at a time
/// (the cards are keyed `gift-card-<id>`); give it a new key to reload
/// [bundle].
class RewardPicker extends StatefulWidget {
  const RewardPicker({
    super.key,
    required this.bundle,
    required this.onChanged,
    this.xuKey = const Key('reward-picker-xu'),
  });

  final RewardBundle bundle;
  final ValueChanged<RewardBundle> onChanged;
  final Key xuKey;

  @override
  State<RewardPicker> createState() => _RewardPickerState();
}

class _RewardPickerState extends State<RewardPicker> {
  late final Map<String, int> _counts = {...widget.bundle.toGiftItems()};
  late final TextEditingController _xu = TextEditingController(
    text: (_counts[giftXu] ?? 0) > 0 ? '${_counts[giftXu]}' : '',
  );

  @override
  void dispose() {
    _xu.dispose();
    super.dispose();
  }

  RewardBundle get _bundle =>
      RewardBundle.fromGiftItems(sanitizeGiftItems(_counts));

  void _changed() => widget.onChanged(_bundle);

  void _toggle(GiftKind kind) {
    setState(() {
      if (_counts.containsKey(kind.id)) {
        _counts.remove(kind.id);
      } else {
        _counts[kind.id] = 1;
      }
    });
    _changed();
  }

  void _setCount(GiftKind kind, int? count) {
    setState(() {
      if (count == null || count <= 0) {
        _counts.remove(kind.id);
      } else {
        _counts[kind.id] = count > kind.cap ? kind.cap : count;
      }
    });
    _changed();
  }

  void _setXu(String raw) {
    final n = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
    setState(() {
      if (n == null || n <= 0) {
        _counts.remove(giftXu);
      } else {
        _counts[giftXu] = n > maxGrantMoney ? maxGrantMoney : n;
      }
    });
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in giftCatalog)
              if (kind.art != GiftArt.coin)
                GiftPickCard(
                  kind: kind,
                  count: _counts[kind.id] ?? 0,
                  owned: null,
                  onTap: () => _toggle(kind),
                  onCount: (count) => _setCount(kind, count),
                ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: widget.xuKey,
          controller: _xu,
          keyboardType: TextInputType.number,
          onChanged: _setXu,
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Xu kèm theo, ví dụ 50000',
            prefixIcon: Padding(
              padding: EdgeInsets.all(10),
              child: CoinIcon(size: 22),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (bundle.isEmpty)
          Text('Chưa chọn quà.', style: AppText.caption())
        else
          RewardBundleView(
            key: const Key('reward-picker-preview'),
            bundle: bundle,
            iconSize: 24,
          ),
      ],
    );
  }
}
