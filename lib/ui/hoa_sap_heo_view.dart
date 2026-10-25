import 'package:flutter/material.dart';

import '../data/wilting.dart';
import '../logic/price_format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'game_toast.dart';

// Hoa sắp héo views (Phú's spec_hoa_sap_heo.md, Nhất's strings).

/// Coral of the spec's badges and new prices.
const wiltCoral = Color(0xFFE26D5A);

WiltingText _t(ShopSession s) => s.data.wilting.text;

/// Bottom sheet frame: dim, [height] tall, top corners 20dp (spec §3).
class WiltSheet extends StatelessWidget {
  const WiltSheet({
    super.key,
    required this.height,
    required this.child,
    this.onClose,
  });

  final double height;
  final Widget child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: ColoredBox(
        color: AppColors.bgOverlay,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              height: height,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Chọn cành để phơi" at the summary (spec §3): 70% high, 4 columns,
/// 64dp cells on the 360dp frame.
class DryPickSheet extends StatefulWidget {
  const DryPickSheet({super.key, required this.session, required this.onClose});

  final ShopSession session;
  final VoidCallback onClose;

  static const cell = 64.0;

  @override
  State<DryPickSheet> createState() => _DryPickSheetState();
}

class _DryPickSheetState extends State<DryPickSheet> {
  final Map<String, int> _picks = {};

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final t = _t(s);
    final d = s.data.wilting.drying;
    final all = lastDayStems(s);
    final can = dryCandidates(s);
    var stems = 0;
    var dried = 0;
    for (final p in _picks.entries) {
      stems += p.value;
      dried += dryYield(s, p.key, p.value);
    }
    final used = driedStorageUsed(s);
    final room = d.storageCap - used;
    final over = dried > room;
    var canYield = 0;
    for (final c in can.entries) {
      canYield += dryYield(s, c.key, c.value);
    }
    return WiltSheet(
      key: const Key('dry-pick-sheet'),
      height: 640 * 0.7,
      onClose: widget.onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.get('dried', 'pickTitle'), style: AppText.heading(size: 18)),
          const SizedBox(height: 4),
          Text(t.get('dried', 'pickHint'), style: AppText.caption(size: 11)),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: (328 - 4 * DryPickSheet.cell) / 3,
              children: [
                for (final e in all.entries)
                  _PickCell(
                    key: Key('dry-cell-${e.key}'),
                    flowerId: e.key,
                    count: e.value,
                    selected: (_picks[e.key] ?? 0) > 0,
                    enabled: can.containsKey(e.key),
                    disabledHint: t.get('dried', 'pickNotDryable'),
                    onTap: () => setState(() {
                      if (_picks.remove(e.key) == null) {
                        _picks[e.key] = can[e.key]!;
                      }
                    }),
                  ),
              ],
            ),
          ),
          if (stems > 0) ...[
            Text(
              t.get('dried', 'pickCount', {
                'n': stems,
                'tien': vndLabel(stems * d.dryingCostPerStem),
              }),
              key: const Key('dry-pick-count'),
              style: AppText.body(size: 12, weight: 700),
            ),
            Text(
              t.get('dried', 'pickYield', {'n': dried}),
              key: const Key('dry-pick-yield'),
              style: AppText.caption(size: 11),
            ),
          ],
          if (room > 0 && room < canYield)
            Text(
              t.get('dried', 'storageNearlyFull', {'n': room}),
              key: const Key('dry-nearly-full'),
              style: AppText.caption(size: 11, color: wiltCoral),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: Row(
              children: [
                Text(
                  t.get('dried', 'storageCounter', {
                    'dang': used,
                    'toiDa': d.storageCap,
                  }),
                  key: const Key('dry-storage'),
                  style: AppText.body(size: 12, weight: 700),
                ),
                const Spacer(),
                SizedBox(
                  width: 92,
                  child: ChunkyButton(
                    key: const Key('dry-skip'),
                    label: t.get('dried', 'skipButton'),
                    kind: ButtonKind.ghost,
                    fontSize: 14,
                    height: 48,
                    onPressed: widget.onClose,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 112,
                  child: ChunkyButton(
                    key: const Key('dry-go'),
                    label: t.get('dried', 'dryButton'),
                    fontSize: 15,
                    height: 48,
                    enabled: stems > 0 && !over,
                    disabledHint: over
                        ? t.get('dried', 'storageFull', {'toiDa': d.storageCap})
                        : null,
                    onPressed: () {
                      if (sendToDry(s, Map.of(_picks))) widget.onClose();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickCell extends StatelessWidget {
  const _PickCell({
    super.key,
    required this.flowerId,
    required this.count,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.disabledHint,
  });

  final String disabledHint;
  final String flowerId;
  final int count;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cell = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: DryPickSheet.cell,
          height: DryPickSheet.cell,
          decoration: BoxDecoration(
            color: AppColors.surfaceSunken,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: selected
                ? Border.all(color: AppColors.primaryBase, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: ArtImage(Art.flower(flowerId), size: 40),
        ),
        Positioned(
          right: 4,
          bottom: 2,
          child: Text('$count', style: AppText.number(size: 12)),
        ),
        if (selected)
          const Positioned(
            right: -4,
            top: -4,
            child: Icon(
              Icons.check_circle,
              size: 18,
              color: AppColors.primaryBase,
            ),
          ),
      ],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : () => showGameToast(context, disabledHint),
      child: enabled ? cell : Opacity(opacity: 0.4, child: cell),
    );
  }
}
