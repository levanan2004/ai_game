import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../logic/price_format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'pet_shop_grid.dart' show petGroupedCount, shortfallText;
import 'ui_skin.dart';

/// Painted cupboard frame (`kho_khung`) and item card (`chi_tiet_khung`).
/// Shelf rows repeat `kho_ke` so the list can grow past nine pots.
class PotPopup extends StatefulWidget {
  const PotPopup({super.key, required this.session});

  final ShopSession session;

  @override
  State<PotPopup> createState() => _PotPopupState();
}

class _PotPopupState extends State<PotPopup> {
  String? _detailId;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final frame = _detailId == null
        ? Art.ui('kho_khung')
        : Art.ui('chi_tiet_khung');
    return GestureDetector(
      key: const Key('pot-dismiss'),
      behavior: HitTestBehavior.opaque,
      onTap: s.closePotPicker,
      child: ColoredBox(
        color: AppColors.bgOverlay,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: _ArtFrame(
              asset: frame,
              onClose: s.closePotPicker,
              child: _detailId == null ? _grid(s) : _detail(s, _detailId!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _grid(ShopSession s) {
    final current = s.e.pot(
      s.potInSlot(bar: s.potPickerBar == true, index: s.potPickerIndex),
    );
    final pots = [
      for (final p in s.e.pots)
        if (s.potListed(p)) p,
    ];
    final rows = (pots.length + 2) ~/ 3;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        return Padding(
          padding: EdgeInsets.fromLTRB(w * 0.17, h * 0.08, w * 0.17, h * 0.10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Kho chậu', style: AppText.heading(size: 16)),
                  ),
                  SizedBox(
                    width: 96,
                    child: SkinButton(
                      key: const Key('pot-to-shop'),
                      label: 'Tiệm Chậu Hoa',
                      height: 30,
                      fontSize: 12,
                      onPressed: s.openPotShop,
                    ),
                  ),
                ],
              ),
              Text(
                'Chỗ này đang để ${_name(s, current)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(size: 11),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: rows,
                  itemBuilder: (context, row) {
                    final start = row * 3;
                    return _ShelfRow(
                      pots: [
                        for (var i = 0; i < 3; i++)
                          start + i < pots.length ? pots[start + i] : null,
                      ],
                      currentId: current.id,
                      session: s,
                      onOpen: (id) => setState(() => _detailId = id),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detail(ShopSession s, String id) {
    final pot = s.e.pot(id);
    final bar = s.potPickerBar == true;
    final index = s.potPickerIndex;
    final here = s.potInSlot(bar: bar, index: index) == id;
    final owned = s.potOwned(id);
    final left = _left(s, pot);
    final lore = s.data.cosmetics.find(id);
    final canPlace = s.canPlacePot(id, bar: bar, index: index);
    final have = pot.paysPhaLe ? s.state.phaLe : s.state.money;
    // One copy of each pot: a pot already owned has no buy button.
    final buyable = pot.purchasable && !s.potHas(id);
    final canBuy = buyable && have >= pot.cost;
    final missing = pot.cost - have;
    final name = lore?.nameVi ?? pot.nameVi;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        return Stack(
          children: [
            Positioned(
              left: w * 0.16,
              right: w * 0.16,
              top: h * 0.09,
              height: 40,
              child: Row(
                children: [
                  BackButtonBox(onTap: () => setState(() => _detailId = null)),
                  const SizedBox(width: 6),
                  Expanded(
                    // Long names ("Chậu Kỳ Lân Sơn Hải") wrap to two lines.
                    child: Text(
                      name,
                      key: const Key('pot-detail-name'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heading(size: 16).copyWith(height: 1.1),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: h * 0.18,
              child: Center(
                child: ArtImage(
                  pot.unlimited ? Art.scene('xo_hoa') : Art.pot(pot.id),
                  // New sets are drawn smaller in the canvas: potScale evens them.
                  size: w * 0.34 * (pot.unlimited ? 1.0 : pot.potScale),
                  fallback: ArtImage(Art.scene('xo_hoa'), size: w * 0.34),
                ),
              ),
            ),
            Positioned(
              left: w * 0.16,
              right: w * 0.16,
              top: h * 0.56,
              bottom: h * 0.09,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    pot.unlimited ? 'Có sẵn' : 'Đang có $owned',
                    style: AppText.title(size: 14, weight: 800),
                  ),
                  if (left != null)
                    Text(
                      'Còn đặt được $left',
                      style: AppText.caption(size: 12),
                    ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        lore?.description ?? 'Chưa có lời giới thiệu.',
                        style: AppText.body(size: 13),
                      ),
                    ),
                  ),
                  if (here)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Đang để chỗ này',
                        style: AppText.caption(
                          size: 12,
                          weight: 800,
                          color: AppColors.primaryPressed,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      if (!here && canPlace)
                        Expanded(
                          child: _Mini(
                            key: Key('place-$id'),
                            label: 'Đặt vào chỗ này',
                            onTap: () {
                              s.placePot(id);
                              s.closePotPicker();
                            },
                          ),
                        ),
                      if (!here && canPlace && buyable)
                        const SizedBox(width: 8),
                      if (buyable)
                        Expanded(
                          child: _Mini(
                            key: Key('buy-$id'),
                            label: pot.paysPhaLe
                                ? 'Mua ${petGroupedCount(pot.phaLePrice)} Pha lê'
                                : 'Mua ${coinLabel(pot.price)}',
                            filled: false,
                            amber: pot.paysPhaLe,
                            onTap: canBuy ? () => s.buyPot(id) : null,
                            blockedHint: shortfallText(
                              phaLe: pot.paysPhaLe,
                              missing: missing,
                            ),
                            onBlocked: pot.paysPhaLe
                                ? () => s.askPhaleShort(pot.nameVi, pot.cost)
                                : null,
                          ),
                        ),
                    ],
                  ),
                  if (buyable && !canBuy)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        pot.paysPhaLe ? 'Chưa đủ Pha lê' : 'Chưa đủ xu',
                        key: Key('buy-short-$id'),
                        textAlign: TextAlign.right,
                        style: AppText.caption(size: 10),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _name(ShopSession s, PotDef pot) =>
      s.data.cosmetics.find(pot.id)?.nameVi ?? pot.nameVi;

  /// Copies not yet sitting on a slot. Null when the pot is unlimited.
  int? _left(ShopSession s, PotDef pot) {
    if (pot.unlimited) return null;
    final n = s.potOwned(pot.id) - s.potPlaced(pot.id);
    return n < 0 ? 0 : n;
  }
}

/// One painted plank with up to three pots. The picture keeps its 1024×152
/// ratio; pots stand on the mats and the row scrolls inside the frame.
class _ShelfRow extends StatelessWidget {
  const _ShelfRow({
    required this.pots,
    required this.currentId,
    required this.session,
    required this.onOpen,
  });

  final List<PotDef?> pots;
  final String currentId;
  final ShopSession session;
  final ValueChanged<String> onOpen;

  static const _centers = [0.218, 0.498, 0.783];

  static double _scale(PotDef p) => p.unlimited ? 1.0 : p.potScale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final shelfH = width * 152 / 1024;
        final potSize = width * 0.175 * 1.45;
        // Mat bottom sits 63.8% down the plank picture.
        final feet = shelfH * (1 - 0.638);
        // A pot drawn at potScale > 1 grows upward from its feet, so the row
        // is as tall as its largest pot or the top would be clipped.
        final tallest = [
          for (final p in pots)
            if (p != null) potSize * (p.unlimited ? 1.0 : p.potScale),
        ].fold<double>(potSize, (a, b) => a > b ? a : b);
        final rowH = tallest - feet + shelfH + 8;
        return SizedBox(
          height: rowH,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: shelfH,
                child: Image.asset(
                  Art.ui('kho_ke'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              for (var i = 0; i < pots.length; i++)
                if (pots[i] != null)
                  Positioned(
                    left: width * _centers[i] - potSize * _scale(pots[i]!) / 2,
                    // Keep the pot's foot (5.3% above the canvas bottom) on
                    // the same spot whatever the scale.
                    bottom:
                        feet -
                        potSize * 0.027 -
                        potSize * _scale(pots[i]!) * 0.053,
                    width: potSize * _scale(pots[i]!),
                    height: potSize * _scale(pots[i]!),
                    child: _PotOnMat(
                      pot: pots[i]!,
                      session: session,
                      here: pots[i]!.id == currentId,
                      onOpen: () => onOpen(pots[i]!.id),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _PotOnMat extends StatelessWidget {
  const _PotOnMat({
    required this.pot,
    required this.session,
    required this.here,
    required this.onOpen,
  });

  final PotDef pot;
  final ShopSession session;
  final bool here;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final owned = pot.unlimited ? null : session.potOwned(pot.id);
    final locked = owned == 0;
    Widget art = FittedBox(
      child: ArtImage(
        pot.unlimited ? Art.scene('xo_hoa') : Art.pot(pot.id),
        size: 64,
        fallback: ArtImage(Art.scene('xo_hoa'), size: 64),
      ),
    );
    if (locked) {
      art = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0xB3000000),
          BlendMode.srcATop,
        ),
        child: art,
      );
    }
    return GestureDetector(
      key: Key('pot-cell-${pot.id}'),
      onTap: onOpen,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: here
                    ? Border.all(color: AppColors.primaryBase, width: 2)
                    : null,
              ),
              child: art,
            ),
          ),
          if (owned != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.bgBase,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.surfaceBorderStrong),
                ),
                child: Text(
                  'x$owned',
                  style: AppText.caption(
                    size: 10,
                    weight: 800,
                    color: locked
                        ? AppColors.textDisabled
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Frame art at its own 682×1024 ratio, so an iPad scales the whole card
/// and does not stretch the border.
class _ArtFrame extends StatelessWidget {
  const _ArtFrame({
    required this.asset,
    required this.child,
    required this.onClose,
  });

  final String asset;
  final Widget child;
  final VoidCallback onClose;

  static const width = 336.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 1024 / 682,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              asset,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Positioned.fill(child: child),
          Positioned(
            top: 8,
            right: 10,
            child: GestureDetector(
              key: const Key('pot-close'),
              onTap: onClose,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryPressed,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '×',
                  style: AppText.heading(
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = true,
    this.amber = false,
    this.blockedHint,
    this.onBlocked,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  /// Pha lê button: amber like the pet shop's.
  final bool amber;

  /// Bubble shown when the button is tapped while disabled.
  final String? blockedHint;

  /// Replaces the bubble when set (the Pha lê top-up popup).
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap:
          onTap ??
          onBlocked ??
          (blockedHint == null
              ? null
              : () => showTapHint(context, blockedHint!)),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: !enabled
              ? AppColors.surfaceBorder
              : amber
              ? AppColors.accentBase
              : filled
              ? AppColors.primaryBase
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: !enabled
                ? AppColors.surfaceBorder
                : amber
                ? AppColors.statusWarning
                : AppColors.primaryBase,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption(
            size: 11,
            weight: 800,
            color: !enabled
                ? AppColors.textDisabled
                : amber
                ? AppColors.onSecondary
                : filled
                ? AppColors.textInverse
                : AppColors.primaryPressed,
          ),
        ),
      ),
    );
  }
}
