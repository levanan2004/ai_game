import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../logic/pot_bonus.dart';
import '../logic/price_format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'game_toast.dart';
import 'pot_text.dart';
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
    final canPlace = owned > 0 && s.canPlacePot(id, bar: bar, index: index);
    final have = pot.paysPhaLe ? s.state.phaLe : s.state.money;
    // Any number of copies: a pot already owned keeps its buy button.
    final buyable = pot.purchasable;
    final canBuy = buyable && have >= pot.cost;
    final missing = pot.cost - have;
    final name = lore?.nameVi ?? pot.nameVi;
    final vipLevel = s.isVipPot(id) ? s.vip.potLevel(id) : 0;
    final charm = potTypeCharm(s.e, pot);
    final stats = potStatOnlyLines(pot);
    final onShelf = s.potPlaced(id) > 0;
    final group = PotText.group(pot.set);
    // Status (Nhất 1c): only about the shelf stats; a pot without stats
    // (VIP, Hoàng đạo) shows "Chậu trang trí" and no status.
    final String? status;
    final String? statusSub;
    if (!pot.unlimited && owned <= 0) {
      status = PotText.statusNotOwned;
      statusSub = null;
    } else if (stats.isEmpty) {
      status = null;
      statusSub = null;
    } else if (onShelf) {
      status = PotText.statusActive;
      statusSub = null;
    } else {
      status = PotText.statusInStorage;
      statusSub = PotText.statusShelfOnly;
    }
    final source = vipLevel > 0
        ? PotText.sourceVip(vipLevel)
        : pot.set == 'sonHai'
        ? PotText.sourceSonHai
        : null;
    final caption = AppText.caption(size: 11.5);
    final strong = AppText.caption(
      size: 12,
      weight: 800,
      color: AppColors.primaryPressed,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        return Stack(
          children: [
            Positioned(
              left: w * 0.16,
              right: w * 0.16,
              top: h * 0.085,
              height: 44,
              child: Row(
                children: [
                  BackButtonBox(onTap: () => setState(() => _detailId = null)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PotText.detailTitle,
                          key: const Key('pot-detail-title'),
                          style: AppText.caption(size: 10.5),
                        ),
                        // Long names shrink to one line.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            name,
                            key: const Key('pot-detail-name'),
                            maxLines: 1,
                            style: AppText.heading(
                              size: 15,
                            ).copyWith(height: 1.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    key: const Key('pot-detail-close'),
                    onTap: s.closePotPicker,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        PotText.btnClose,
                        style: AppText.caption(size: 12, weight: 800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: h * 0.165,
              child: Center(
                child: ArtImage(
                  pot.unlimited ? Art.scene('xo_hoa') : Art.pot(pot.id),
                  // New sets are drawn smaller in the canvas: potScale evens them.
                  size: w * 0.26 * (pot.unlimited ? 1.0 : pot.potScale),
                  fallback: ArtImage(Art.scene('xo_hoa'), size: w * 0.26),
                ),
              ),
            ),
            Positioned(
              left: w * 0.16,
              right: w * 0.16,
              top: h * 0.43,
              bottom: h * 0.09,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pot.unlimited ? 'Có sẵn' : 'Đang có $owned',
                          style: AppText.title(size: 14, weight: 800),
                        ),
                      ),
                      if (group != null)
                        Container(
                          key: Key('pot-detail-group-$id'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Text(
                            group,
                            style: AppText.caption(size: 11, weight: 800),
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      key: Key('pot-detail-body-$id'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (charm > 0) ...[
                            Text(
                              PotText.charm(charm),
                              key: Key('pot-detail-charm-$id'),
                              style: strong,
                            ),
                            Text(PotText.charmRule, style: caption),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            PotText.statsTitle,
                            style: AppText.caption(size: 11.5, weight: 800),
                          ),
                          if (stats.isEmpty)
                            Text(
                              PotText.statNone,
                              key: Key('pot-detail-none-$id'),
                              style: caption,
                            )
                          else
                            for (final (i, line) in stats.indexed)
                              Text(
                                line,
                                key: Key('pot-bonus-$id-$i'),
                                style: strong,
                              ),
                          if (status != null)
                            Text(
                              status,
                              key: Key('pot-detail-status-$id'),
                              style: status == PotText.statusActive
                                  ? strong
                                  : AppText.caption(size: 11.5, weight: 800),
                            ),
                          if (statusSub != null)
                            Text(statusSub, style: caption),
                          if (source != null)
                            Text(
                              source,
                              key: Key('pot-detail-source-$id'),
                              style: caption,
                            ),
                          if (pot.set == 'sonHai' && owned > 0)
                            Text(PotText.sourceSonHaiOwned, style: caption),
                          if (left != null && owned > 0)
                            Text('Còn đặt được $left', style: caption),
                          const SizedBox(height: 6),
                          Text(
                            PotText.descs[id] ??
                                lore?.description ??
                                'Chưa có lời giới thiệu.',
                            key: Key('pot-detail-desc-$id'),
                            style: AppText.body(
                              size: 12.5,
                            ).copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (here && !pot.unlimited)
                        Expanded(
                          child: _Mini(
                            key: Key('store-$id'),
                            label: PotText.btnStore,
                            filled: false,
                            onTap: () {
                              final ok = s.storePot();
                              showGameToast(
                                context,
                                ok
                                    ? PotText.storedToast(name)
                                    : PotText.moveFailToast,
                                error: !ok,
                              );
                            },
                          ),
                        )
                      else if (!here && canPlace)
                        Expanded(
                          child: _Mini(
                            key: Key('place-$id'),
                            label: PotText.btnPlace,
                            onTap: () {
                              final ok = s.placePot(id);
                              showGameToast(
                                context,
                                ok
                                    ? PotText.placedToast(name)
                                    : PotText.moveFailToast,
                                error: !ok,
                              );
                              if (ok) s.closePotPicker();
                            },
                          ),
                        ),
                      if (!pot.unlimited) ...[
                        const SizedBox(width: 6),
                        Text(
                          PotText.shelfCount(s.shelfUsed, s.shelfSlots),
                          key: const Key('pot-detail-shelf-count'),
                          style: AppText.caption(size: 11, weight: 800),
                        ),
                      ],
                      if (buyable || (source == null && !pot.unlimited)) ...[
                        const SizedBox(width: 6),
                        if (!buyable)
                          Expanded(
                            child: _Mini(
                              key: Key('buy-$id'),
                              label: pot.howVi ?? 'Chưa bán',
                              filled: false,
                              onTap: null,
                            ),
                          )
                        else
                          Expanded(
                            child: _Mini(
                              key: Key('buy-$id'),
                              label: owned > 0
                                  ? PotText.more(
                                      pot.paysPhaLe
                                          ? '${petGroupedCount(pot.phaLePrice)} Pha lê'
                                          : coinLabel(pot.price),
                                    )
                                  : pot.paysPhaLe
                                  ? 'Mua ${petGroupedCount(pot.phaLePrice)} Pha lê'
                                  : 'Mua ${coinLabel(pot.price)}',
                              filled: false,
                              amber: pot.paysPhaLe,
                              onTap: canBuy ? () => s.buyPotPaid(id) : null,
                              blockedHint: shortfallText(
                                phaLe: pot.paysPhaLe,
                                missing: missing,
                              ),
                              onBlocked: pot.paysPhaLe
                                  ? () => s.askPhaleShort(pot.nameVi, pot.cost)
                                  : () => s.askXuShort(pot.nameVi, pot.cost),
                            ),
                          ),
                      ],
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
                  PotText.count(owned),
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
