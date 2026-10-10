import 'package:flutter/material.dart';

import '../data/pet_items.dart';
import '../logic/pet_item_room.dart';
import '../logic/price_format.dart';
import '../logic/rewards.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'game_toast.dart';
import 'pet_item_art.dart';
import 'pet_item_picker.dart';
import 'pet_shop_grid.dart' show CurrencyButton;
import 'petdo_text.dart';
import 'reward_bundle_view.dart' show PhaLeIcon;
import 'ui_skin.dart';

/// "Tiệm đồ pet" (P3): three tabs (Cổ, Đầu, Phụ kiện), one row per item,
/// cheapest tier first. Copies are unlimited, so a price button is live
/// whenever the player can pay, owned or not; the badge `xN` shows how many
/// they have. A bought copy goes to the store room and is never worn by
/// itself.
class PetItemShopScreen extends StatelessWidget {
  const PetItemShopScreen({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final s = session;
        final tab = s.petItemShopTab;
        final items = s.petItemsOfSlot(tab);
        return OpaqueScreen(
          color: AppColors.bgBase,
          child: Stack(
            key: const Key('item-shop'),
            children: [
              Positioned.fill(
                top: 108,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Row(
                        children: [
                          for (final slot in s.e.petItemRules.slots) ...[
                            if (slot != s.e.petItemRules.slots.first)
                              const SizedBox(width: 8),
                            Expanded(
                              child: SkinTab(
                                key: Key('item-shop-tab-$slot'),
                                label: PetDo.slotName(slot),
                                selected: slot == tab,
                                height: 40,
                                onTap: () => s.selectPetItemShopTab(slot),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      PetDo.shopHint,
                      key: const Key('item-shop-hint'),
                      style: AppText.caption(
                        size: 12,
                        weight: 800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView(
                        key: const Key('item-shop-list'),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          for (final item in items) ...[
                            _ItemRow(session: s, item: item),
                            const SizedBox(height: 10),
                          ],
                          const _OtherWays(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: TopBar(
                  session: s,
                  showRating: false,
                  showDay: false,
                  showPhaLe: true,
                ),
              ),
              Positioned(
                left: 16,
                top: 54,
                child: SkinRoundButton(
                  key: const Key('item-shop-back'),
                  kind: SkinRound.back,
                  width: 40,
                  onTap: s.closePetItemShop,
                ),
              ),
              const Positioned(
                left: 70,
                right: 70,
                top: 54,
                child: Center(
                  child: SkinRibbon(
                    title: PetDo.shopTitle,
                    width: 220,
                    height: 46,
                    fontSize: 18,
                  ),
                ),
              ),
              if (s.petItemBuyId != null)
                Positioned.fill(child: PetItemBuyPopup(session: s)),
            ],
          ),
        );
      },
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.session, required this.item});

  final ShopSession session;
  final PetItemDef item;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final p = PetItemPalette.of(item.tier);
    final owned = s.petItemOwned(item.id);
    final missing = s.petItemShortfall(item);
    final open = s.petShopOpen;
    final short = missing > 0;
    return Container(
      key: Key('item-row-${item.id}'),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.frame, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PetItemIcon(
                itemId: item.id,
                slot: item.slot,
                tier: item.tier,
                size: 48,
                count: owned,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nameVi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title(size: 16, weight: 800),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        PetItemTierChip(tier: item.tier),
                        const SizedBox(width: 6),
                        CharmBonus(
                          charm: s.e.petItemRules.charmOfTier(item.tier),
                          size: 12,
                          color: p.glyph,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 98,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 36,
                      child: ItemBuyButton(
                        key: Key('item-shop-buy-${item.id}'),
                        session: s,
                        item: item,
                        height: 36,
                        fontSize: 15,
                      ),
                    ),
                    if (open && short)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.paysPhaLe ? PetDo.shortPl : PetDo.shortXu,
                          key: Key('item-short-${item.id}'),
                          style: AppText.caption(
                            size: 11,
                            weight: 700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(
              size: 12,
              weight: 700,
              color: AppColors.textSecondary,
            ).copyWith(height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _OtherWays extends StatelessWidget {
  const _OtherWays();

  @override
  Widget build(BuildContext context) {
    return CardBox(
      key: const Key('item-shop-other'),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PetDo.otherTitle,
            style: AppText.title(
              size: 14,
              weight: 800,
              color: AppColors.primaryPressed,
            ),
          ),
          const SizedBox(height: 4),
          Text(PetDo.otherSub, style: AppText.body(size: 12, weight: 700)),
        ],
      ),
    );
  }
}

/// "Mua {món}?" (P3b xu, P3c Pha lê). The button shows the whole number.
class PetItemBuyPopup extends StatelessWidget {
  const PetItemBuyPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final s = session;
        final id = s.petItemBuyId;
        final item = id == null ? null : s.e.petItem(id);
        if (item == null) return const SizedBox.shrink();
        final have = s.petItemOwned(item.id);
        return PetItemConfirmShell(
          dismissKey: const Key('item-buy-dismiss'),
          panelKey: const Key('item-buy'),
          onClose: s.closePetItemBuy,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                PetDo.buyTitle(item.nameVi),
                key: const Key('item-buy-title'),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppText.title(size: 20, weight: 800),
              ),
              const SizedBox(height: 10),
              PetItemArtBox(item: item, count: have, height: 100),
              const SizedBox(height: 8),
              Center(child: PetItemTierChip(tier: item.tier)),
              const SizedBox(height: 6),
              Text(
                item.description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                  size: 13,
                  weight: 700,
                ).copyWith(height: 1.25),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    PetDo.buySlotLine(
                      s.e.petItemRules.charmOfTier(item.tier),
                      item.slot,
                    ),
                    key: const Key('item-buy-slotline'),
                    style: AppText.caption(
                      size: 12,
                      weight: 800,
                      color: AppColors.primaryPressed,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                have > 0 ? PetDo.buyHave(have) : PetDo.buyNone,
                key: const Key('item-buy-have'),
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
                        key: const Key('item-buy-later'),
                        label: PetDo.buyCancel,
                        kind: SkinButtonKind.secondary,
                        height: 44,
                        fontSize: 16,
                        onPressed: s.closePetItemBuy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Builder(
                        builder: (context) => CurrencyButton(
                          key: const Key('item-buy-yes'),
                          phaLe: item.paysPhaLe,
                          // The whole number, never abbreviated (P3b).
                          priceText: PetDo.buyConfirm(
                            priceUnit(item.price, phaLe: item.paysPhaLe),
                          ),
                          enabled: true,
                          height: 44,
                          fontSize: 14,
                          onTap: () {
                            final missing = s.petItemShortfall(item);
                            if (!s.petShopOpen || missing > 0) {
                              s.closePetItemBuy();
                              showTapHint(
                                context,
                                !s.petShopOpen
                                    ? PetDo.shopClosed
                                    : PetDo.shortTip(
                                        missing,
                                        phaLe: item.paysPhaLe,
                                      ),
                              );
                              return;
                            }
                            s.confirmPetItemBuy();
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

/// P4a, P4b, P4c: a received item. It is in the store room already; the
/// popup says so and, for a copy the player already had, offers to sell the
/// spare at once (no second confirm, then a toast).
class PetItemGiftPopup extends StatelessWidget {
  const PetItemGiftPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final s = session;
        final gift = s.petItemGift;
        final item = gift == null ? null : s.e.petItem(gift.itemId);
        if (gift == null) return const SizedBox.shrink();
        if (item == null) {
          // An item the file no longer knows: nothing to show.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => s.closePetItemGift(),
          );
          return const SizedBox.shrink();
        }
        final counts = s.petItemCounts(item.id);
        final dup = counts.owned >= 2;
        final value = s.petItemSellPrice(item.id);
        final rank = gift.kind == PetItemGiftKind.rank;
        final sub = rank
            ? (gift.rank == null
                  ? PetDo.getRankSubNoRank
                  : PetDo.getRankSub(gift.rank!))
            : PetDo.getMysterySub;
        return PetItemConfirmShell(
          dismissKey: const Key('item-gift-dismiss'),
          panelKey: const Key('item-gift'),
          onClose: s.closePetItemGift,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                rank ? PetDo.getRank : PetDo.getMystery,
                key: const Key('item-gift-title'),
                textAlign: TextAlign.center,
                style: AppText.title(size: 20, weight: 800),
              ),
              Text(
                sub,
                key: const Key('item-gift-sub'),
                textAlign: TextAlign.center,
                style: AppText.caption(
                  size: 12,
                  weight: 800,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              PetItemArtBox(item: item, count: counts.owned, height: 110),
              const SizedBox(height: 6),
              Text(
                item.nameVi,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppText.title(size: 18, weight: 800),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PetItemTierChip(tier: item.tier),
                  const SizedBox(width: 8),
                  CharmBonus(
                    charm: s.e.petItemRules.charmOfTier(item.tier),
                    size: 13,
                    color: PetItemPalette.of(item.tier).glyph,
                  ),
                  if (!dup) ...[
                    const SizedBox(width: 8),
                    Container(
                      key: const Key('item-gift-new'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        PetDo.getNew,
                        style: AppText.caption(
                          size: 11,
                          weight: 800,
                          color: AppColors.primaryPressed,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                  size: 12,
                  weight: 700,
                  color: AppColors.textSecondary,
                ).copyWith(height: 1.25),
              ),
              if (gift.extras.isNotEmpty) ...[
                const SizedBox(height: 6),
                _Extras(items: gift.extras),
              ],
              const SizedBox(height: 8),
              if (dup)
                Container(
                  key: const Key('item-gift-dup'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentBase),
                  ),
                  child: Column(
                    children: [
                      Text(
                        PetDo.getDup(counts.owned),
                        style: AppText.body(size: 13, weight: 800),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          item.paysPhaLe
                              ? const PhaLeIcon(size: 20, hud: true)
                              : const CoinIcon(size: 20),
                          const SizedBox(width: 4),
                          Text(
                            priceUnit(value, phaLe: item.paysPhaLe),
                            key: const Key('item-gift-dup-value'),
                            style: AppText.number(size: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Text(
                  PetDo.getHint,
                  key: const Key('item-gift-hint'),
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
                    Expanded(
                      child: SkinButton(
                        key: const Key('item-gift-later'),
                        label: dup ? PetDo.getKeep : PetDo.getLater,
                        kind: SkinButtonKind.secondary,
                        height: 44,
                        fontSize: 16,
                        onPressed: s.closePetItemGift,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: dup
                          ? Builder(
                              builder: (context) => SkinButton(
                                key: const Key('item-gift-sell'),
                                label: PetDo.sellSpare,
                                height: 44,
                                fontSize: 15,
                                onPressed: () {
                                  if (!s.petShopOpen) {
                                    showTapHint(context, PetDo.sellClosed);
                                    return;
                                  }
                                  final res = s.sellPetItemGiftSpare();
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
                            )
                          : SkinButton(
                              key: const Key('item-gift-go'),
                              label: PetDo.getGo,
                              height: 44,
                              fontSize: 15,
                              onPressed: s.petItemGiftToRoom,
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

/// The rest of a reward line ("Pha lê +120", "Giọt hoa +10") shown beside the
/// item, as in the board's reward popup.
class _Extras extends StatelessWidget {
  const _Extras({required this.items});

  final List<RewardItem> items;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    for (final i in items) {
      switch (i.kind) {
        case RewardKind.phaLe:
          parts.add('${coinFull(i.amount)} Pha lê');
        case RewardKind.giotHoa:
          parts.add('${coinFull(i.amount)} Giọt hoa');
        case RewardKind.coins:
          parts.add('${coinFull(i.amount)} xu');
        default:
          break;
      }
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      key: const Key('item-gift-extras'),
      textAlign: TextAlign.center,
      style: AppText.caption(
        size: 12,
        weight: 800,
        color: AppColors.primaryPressed,
      ),
    );
  }
}
