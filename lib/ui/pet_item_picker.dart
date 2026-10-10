import 'package:flutter/material.dart';

import '../data/pet_items.dart';
import '../logic/pet.dart';
import '../logic/pet_item_room.dart';
import '../logic/price_format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'game_toast.dart';
import 'pet_item_art.dart';
import 'pet_shop_grid.dart' show CurrencyButton;
import 'reward_bundle_view.dart' show PhaLeIcon;
import 'petdo_text.dart';
import 'ui_skin.dart';

/// The Mị lực mark used next to a bonus ("+5").
class CharmMark extends StatelessWidget {
  const CharmMark({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    Art.bxh('mi_luc'),
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}

/// "+5" with the Mị lực mark.
class CharmBonus extends StatelessWidget {
  const CharmBonus({
    super.key,
    required this.charm,
    this.size = 12,
    this.color,
  });

  final int charm;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CharmMark(size: size + 2),
      const SizedBox(width: 2),
      Text(
        '+$charm',
        style: AppText.caption(
          size: size,
          weight: 800,
          color: color ?? AppColors.textSecondary,
        ),
      ),
    ],
  );
}

/// "Chọn đồ cho ô {ô}" (P2, P5c, P5d): a bottom sheet over the room with the
/// four items of one slot and the detail of the chosen one.
class PetItemPicker extends StatelessWidget {
  const PetItemPicker({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final s = session;
        final slot = s.petItemPickSlot;
        final pet = s.roomPet;
        if (slot == null || pet == null) return const SizedBox.shrink();
        final items = s.petItemsOfSlot(slot);
        final charm = s.petCharmOf(pet.id);
        final detailId = s.petItemPickDetail;
        final detail = detailId == null ? null : s.e.petItem(detailId);
        final nothingOwned = items.every((i) => s.petItemOwned(i.id) == 0);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const Key('item-pick-dismiss'),
                behavior: HitTestBehavior.opaque,
                onTap: s.closePetItemPicker,
                child: const ColoredBox(color: AppColors.bgOverlay),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 500,
              child: DecoratedBox(
                key: const Key('item-pick'),
                decoration: const BoxDecoration(
                  color: AppColors.bgBase,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: AppColors.popupShadow, blurRadius: 12),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBorderStrong,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  PetDo.pickTitle(slot),
                                  key: const Key('item-pick-title'),
                                  style: AppText.title(size: 19, weight: 800),
                                ),
                                Text(
                                  PetDo.pickSub(
                                    s.petName(pet.id),
                                    petStageName(pet.stage),
                                    charm,
                                  ),
                                  key: const Key('item-pick-sub'),
                                  style: AppText.caption(
                                    size: 12,
                                    weight: 700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SkinRoundButton(
                            key: const Key('item-pick-close'),
                            kind: SkinRound.close,
                            width: 36,
                            onTap: s.closePetItemPicker,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (var r = 0; r < items.length; r += 2) ...[
                        if (r > 0) const SizedBox(height: 8),
                        Row(
                          children: [
                            for (var c = r; c < r + 2; c++) ...[
                              if (c > r) const SizedBox(width: 8),
                              Expanded(
                                child: c < items.length
                                    ? _PickCard(
                                        session: s,
                                        petId: pet.id,
                                        item: items[c],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Expanded(
                        child: detail != null
                            ? _Detail(session: s, petId: pet.id, item: detail)
                            : _EmptyBlock(
                                session: s,
                                slot: slot,
                                show: nothingOwned,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// P5c: nothing owned for this slot.
class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({
    required this.session,
    required this.slot,
    required this.show,
  });

  final ShopSession session;
  final String slot;
  final bool show;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      key: const Key('item-pick-empty'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            PetDo.emptyTitle(slot),
            textAlign: TextAlign.center,
            style: AppText.title(size: 16, weight: 800),
          ),
          const SizedBox(height: 4),
          Text(
            PetDo.emptySub,
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 13,
              weight: 700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 180,
            child: SkinButton(
              key: const Key('item-pick-empty-cta'),
              label: PetDo.emptyCta,
              height: 40,
              fontSize: 15,
              onPressed: () => session.openPetItemShop(slot: slot),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({
    required this.session,
    required this.petId,
    required this.item,
  });

  final ShopSession session;
  final String petId;
  final PetItemDef item;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final state = s.petItemCardState(petId, item);
    final counts = s.petItemCounts(item.id);
    final selected = s.petItemPickDetail == item.id;
    final worn = state == PetItemCardState.worn;
    final owned = counts.owned > 0;
    final borderColor = worn
        ? AppColors.primaryBase
        : selected
        ? AppColors.accentBase
        : AppColors.surfaceBorder;
    return GestureDetector(
      key: Key('item-card-${item.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => s.selectPetItemDetail(item.id),
      child: Container(
        height: 108,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: owned ? AppColors.surfaceCard : AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: worn || selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PetItemIcon(
                    itemId: item.id,
                    slot: item.slot,
                    tier: item.tier,
                    size: 40,
                    count: counts.owned,
                    locked: !owned,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nameVi,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            size: 12,
                            weight: 800,
                            color: owned
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ).copyWith(height: 1.1),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              PetItemTierChip(tier: item.tier, fontSize: 10),
                              const SizedBox(width: 4),
                              CharmBonus(
                                charm: s.e.petItemRules.charmOfTier(item.tier),
                                size: 11,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30, child: _action(context, s, state)),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, ShopSession s, PetItemCardState state) {
    switch (state) {
      case PetItemCardState.worn:
        return Container(
          key: Key('item-worn-${item.id}'),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primaryBase),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_rounded,
                size: 16,
                color: AppColors.primaryPressed,
              ),
              const SizedBox(width: 4),
              Text(
                PetDo.worn,
                style: AppText.button(
                  size: 13,
                  weight: 800,
                  color: AppColors.primaryPressed,
                ),
              ),
            ],
          ),
        );
      case PetItemCardState.inStock:
        return SkinButton(
          key: Key('item-wear-${item.id}'),
          label: PetDo.wear,
          height: 30,
          fontSize: 14,
          onPressed: () => s.wearPetItemOnRoomPet(item.id),
        );
      case PetItemCardState.elsewhere:
        return Container(
          key: Key('item-else-${item.id}'),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceSunken,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.surfaceBorderStrong),
          ),
          child: Text(
            PetDo.at(s.petItemWornBy(item.id, except: petId) ?? ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption(size: 12, weight: 800),
          ),
        );
      case PetItemCardState.canPay:
      case PetItemCardState.short:
        return ItemBuyButton(
          key: Key('item-buy-${item.id}'),
          session: s,
          item: item,
          height: 30,
          fontSize: 14,
        );
    }
  }
}

/// The price button of an item not owned (picker card, detail block).
/// A tap on a grey one says what is missing; while the shop serves it says
/// to come back when it is closed.
class ItemBuyButton extends StatelessWidget {
  const ItemBuyButton({
    super.key,
    required this.session,
    required this.item,
    this.height = 36,
    this.fontSize = 15,
    this.label = '',
    this.full = false,
  });

  final ShopSession session;
  final PetItemDef item;
  final double height;
  final double fontSize;
  final String label;

  /// The whole number with its unit ("Mua 20.000.000 xu"), for a confirm.
  final bool full;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final missing = s.petItemShortfall(item);
    final open = s.petShopOpen;
    final can = missing == 0 && open;
    return CurrencyButton(
      phaLe: item.paysPhaLe,
      priceText: priceLabel(item.price, phaLe: item.paysPhaLe),
      enabled: can,
      height: height,
      fontSize: fontSize,
      label: label,
      onTap: () => s.openPetItemBuy(item.id),
      onBlocked: (context) => showTapHint(
        context,
        !open
            ? PetDo.shopClosed
            : PetDo.shortTip(missing, phaLe: item.paysPhaLe),
      ),
    );
  }
}

/// Name, description, counts, preview of the Mị lực and the buttons.
class _Detail extends StatelessWidget {
  const _Detail({
    required this.session,
    required this.petId,
    required this.item,
  });

  final ShopSession session;
  final String petId;
  final PetItemDef item;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final counts = s.petItemCounts(item.id);
    final state = s.petItemCardState(petId, item);
    final owned = counts.owned > 0;
    final wornHere = state == PetItemCardState.worn;
    final now = s.petCharmOf(petId);
    final after = owned
        ? s.petCharmWith(
            petId,
            slot: item.slot,
            itemId: wornHere ? null : item.id,
          )
        : now;
    final delta = after - now;
    return Container(
      key: Key('item-detail-${item.id}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  item.nameVi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(size: 16, weight: 800),
                ),
              ),
              const SizedBox(width: 6),
              PetItemTierChip(tier: item.tier),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(
              size: 12,
              weight: 700,
              color: AppColors.textSecondary,
            ).copyWith(height: 1.2),
          ),
          const Spacer(),
          if (owned) ...[
            Text(
              PetDo.count(counts.owned, counts.worn, counts.spare),
              key: const Key('item-detail-count'),
              style: AppText.caption(
                size: 12,
                weight: 800,
                color: AppColors.primaryPressed,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: _CompareChip(
                label: wornHere ? PetDo.compareOff : PetDo.compare,
                now: now,
                after: after,
                delta: delta,
              ),
            ),
            const SizedBox(height: 6),
          ],
          _buttons(context, s, state, counts),
        ],
      ),
    );
  }

  Widget _buttons(
    BuildContext context,
    ShopSession s,
    PetItemCardState state,
    PetItemCounts counts,
  ) {
    if (counts.owned == 0) {
      return SizedBox(
        height: 38,
        child: ItemBuyButton(
          key: Key('item-detail-buy-${item.id}'),
          session: s,
          item: item,
          height: 38,
        ),
      );
    }
    final sellable = counts.spare > 0;
    final value = s.petItemSellPrice(item.id);
    final wornHere = state == PetItemCardState.worn;
    final Widget second;
    if (wornHere) {
      second = SkinButton(
        key: const Key('item-unwear'),
        label: PetDo.unwear,
        kind: SkinButtonKind.secondary,
        height: 38,
        fontSize: 15,
        onPressed: () => s.unwearRoomPetSlot(item.slot),
      );
    } else if (state == PetItemCardState.inStock) {
      second = SkinButton(
        key: const Key('item-wear'),
        label: PetDo.wear,
        height: 38,
        fontSize: 15,
        onPressed: () => s.wearPetItemOnRoomPet(item.id),
      );
    } else {
      second = SkinButton(
        key: const Key('item-wear'),
        label: PetDo.wear,
        height: 38,
        fontSize: 15,
        enabled: false,
        onPressed: null,
        disabledHint: PetDo.at(s.petItemWornBy(item.id, except: petId) ?? ''),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: CurrencyButton(
                  key: const Key('item-sell'),
                  phaLe: item.paysPhaLe,
                  secondary: true,
                  label: '${PetDo.sellBtn} ',
                  priceText: '+${coinFull(value)}',
                  enabled: sellable,
                  height: 38,
                  fontSize: 15,
                  onTap: () {
                    if (!s.petShopOpen) {
                      showTapHint(context, PetDo.sellClosed);
                    } else {
                      s.openPetItemSell(item.id);
                    }
                  },
                  onBlocked: (context) =>
                      showTapHint(context, PetDo.sellUnwearHint),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(height: 38, child: second)),
          ],
        ),
        if (!sellable)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              PetDo.sellUnwearHint,
              key: const Key('item-unwear-hint'),
              style: AppText.caption(
                size: 11,
                weight: 800,
                color: AppColors.secondaryPressed,
              ),
            ),
          ),
      ],
    );
  }
}

/// "Mị lực pet: 60 → 70 (+10)".
class _CompareChip extends StatelessWidget {
  const _CompareChip({
    required this.label,
    required this.now,
    required this.after,
    required this.delta,
  });

  final String label;
  final int now;
  final int after;
  final int delta;

  @override
  Widget build(BuildContext context) {
    final up = delta >= 0;
    return Container(
      key: const Key('item-compare'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.caption(size: 12, weight: 700)),
          const SizedBox(width: 6),
          Text('$now', style: AppText.number(size: 14)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_right_alt, size: 16),
          ),
          Text('$after', style: AppText.number(size: 14)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: up ? AppColors.primaryBase : AppColors.secondaryPressed,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              up ? '+$delta' : '−${-delta}',
              style: AppText.caption(
                size: 11,
                weight: 800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A popup shell in the style of the pet confirm: dim, tap outside = Để sau.
class PetItemConfirmShell extends StatelessWidget {
  const PetItemConfirmShell({
    super.key,
    required this.dismissKey,
    required this.panelKey,
    required this.onClose,
    required this.child,
  });

  final Key dismissKey;
  final Key panelKey;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: dismissKey,
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: ColoredBox(
        color: AppColors.bgOverlay,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: SizedBox(
              key: panelKey,
              width: 320,
              child: SkinPanel(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// The art box of a popup: the item big on a soft tier-coloured ground.
class PetItemArtBox extends StatelessWidget {
  const PetItemArtBox({
    super.key,
    required this.item,
    this.count = 0,
    this.height = 110,
  });

  final PetItemDef item;
  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = PetItemPalette.of(item.tier);
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.chipFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: PetItemIcon(
        itemId: item.id,
        slot: item.slot,
        tier: item.tier,
        size: height * 0.62,
        count: count,
      ),
    );
  }
}

/// "Bán {món}?" (P2c): always asked, even for a cheap item.
class PetItemSellPopup extends StatelessWidget {
  const PetItemSellPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final s = session;
        final id = s.petItemSellId;
        final item = id == null ? null : s.e.petItem(id);
        if (item == null) return const SizedBox.shrink();
        final counts = s.petItemCounts(item.id);
        final value = s.petItemSellPrice(item.id);
        final note = counts.owned - 1 > 0
            ? PetDo.sellNote(counts.owned - 1)
            : PetDo.sellNoteLast;
        return PetItemConfirmShell(
          dismissKey: const Key('item-sell-dismiss'),
          panelKey: const Key('item-sell'),
          onClose: s.closePetItemSell,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                PetDo.sellTitle(item.nameVi),
                key: const Key('item-sell-title'),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppText.title(size: 20, weight: 800),
              ),
              const SizedBox(height: 10),
              PetItemArtBox(item: item, count: counts.owned),
              const SizedBox(height: 8),
              Center(child: PetItemTierChip(tier: item.tier)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentBase),
                ),
                child: Row(
                  children: [
                    Text(
                      PetDo.sellReceive,
                      style: AppText.body(size: 14, weight: 800),
                    ),
                    const Spacer(),
                    _MoneyIcon(phaLe: item.paysPhaLe),
                    const SizedBox(width: 4),
                    Text(
                      key: const Key('item-sell-receive'),
                      priceUnit(value, phaLe: item.paysPhaLe),
                      style: AppText.number(size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                note,
                key: const Key('item-sell-note'),
                textAlign: TextAlign.center,
                style: AppText.caption(
                  size: 12,
                  weight: 700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: SkinButton(
                        key: const Key('item-sell-later'),
                        label: PetDo.sellCancel,
                        kind: SkinButtonKind.secondary,
                        height: 44,
                        fontSize: 16,
                        onPressed: s.closePetItemSell,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Builder(
                        builder: (context) => CurrencyButton(
                          key: const Key('item-sell-yes'),
                          phaLe: item.paysPhaLe,
                          priceText: PetDo.sellConfirm(coinFull(value)),
                          enabled: true,
                          height: 44,
                          fontSize: 14,
                          onTap: () {
                            if (!s.petShopOpen) {
                              s.closePetItemSell();
                              showTapHint(context, PetDo.sellClosed);
                              return;
                            }
                            final res = s.confirmPetItemSell();
                            if (res == PetItemTrade.sold) {
                              showGameToast(
                                context,
                                PetDo.sellDone(
                                  item.nameVi,
                                  priceUnit(value, phaLe: item.paysPhaLe),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MoneyIcon extends StatelessWidget {
  const _MoneyIcon({required this.phaLe});

  final bool phaLe;

  @override
  Widget build(BuildContext context) =>
      phaLe ? const PhaLeIcon(size: 20, hud: true) : const CoinIcon(size: 20);
}
