import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/pet.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';

/// The pet shop room. Pets are not placed on the shelves: a button on the
/// counter opens a scrolling catalog, the same cupboard as the pot shop,
/// so twenty or thirty pets still fit.
class PetShopScreen extends StatelessWidget {
  const PetShopScreen({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        return OpaqueScreen(
          color: AppColors.bgBase,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/scenes/tiem_thu_cung.jpg',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              Positioned(
                left: 12,
                top: 10,
                child: BackButtonBox(
                  key: const Key('pet-shop-back'),
                  onTap: s.closePetShop,
                ),
              ),
              Positioned(
                left: 96,
                top: 430,
                width: 168,
                height: 48,
                child: ChunkyButton(
                  key: const Key('pet-shop-open'),
                  label: 'Mua thú',
                  height: 44,
                  fontSize: 16,
                  onPressed: s.openPetCatalog,
                ),
              ),
              if (s.petCatalogOpen)
                Positioned.fill(child: PetCatalogPopup(session: s)),
            ],
          ),
        );
      },
    );
  }
}

class PetCatalogPopup extends StatefulWidget {
  const PetCatalogPopup({super.key, required this.session});

  final ShopSession session;

  @override
  State<PetCatalogPopup> createState() => _PetCatalogPopupState();
}

class _PetCatalogPopupState extends State<PetCatalogPopup> {
  int _tab = 0;

  ShopSession get session => widget.session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        return GestureDetector(
          key: const Key('pet-shop-dismiss'),
          behavior: HitTestBehavior.opaque,
          onTap: session.closePetCatalog,
          child: ColoredBox(
            color: AppColors.bgOverlay,
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: SizedBox(
                  key: const Key('pet-shop-popup'),
                  width: 336,
                  height: 520,
                  child: CardBox(
                    radius: 20,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(),
                        const SizedBox(height: 8),
                        _tabs(),
                        const SizedBox(height: 10),
                        Expanded(child: _tab == 0 ? _pets() : _treats()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Text('Tiệm thú cưng', style: AppText.heading(size: 18)),
        ),
        GestureDetector(
          key: const Key('pet-shop-close'),
          onTap: session.closePetCatalog,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryPressed, width: 1.5),
            ),
            child: Text(
              '×',
              style: AppText.heading(size: 18, color: AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabs() {
    const labels = ['Thú cưng', 'Thức ăn'];
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.surfaceBorder,
          width: AppBorder.thin,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                key: Key('pet-shop-tab-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (i == _tab) return;
                  session.sounds.effect('ui_tab');
                  setState(() => _tab = i);
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: i == _tab ? AppColors.primaryBase : null,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      labels[i],
                      style: AppText.button(
                        size: 13,
                        weight: 800,
                        color: i == _tab
                            ? AppColors.onPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pets() {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: petsForSale.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final pet = petsForSale[i];
        final owned = pet.id == giftCat && session.state.hasCat;
        return _OfferCard(
          id: pet.id,
          name: pet.name,
          blurb: pet.blurb,
          status: owned ? 'Đang ở phòng' : 'Chưa có',
          asset: pet.asset,
          price: pet.price,
          owned: owned,
          canBuy:
              session.petShopOpen && !owned && session.state.money >= pet.price,
          hint: _buyHint(
            closed: session.petShopOpen,
            canPay: session.state.money >= pet.price,
          ),
          onBuy: () => session.buyPet(pet.id),
        );
      },
    );
  }

  Widget _treats() {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: treatsForSale.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final treat = treatsForSale[i];
        final have = treat.id == giftBiscuit
            ? session.state.biscuits
            : session.state.drops;
        final full = have >= maxGiftCount;
        final canPay = session.state.money >= treat.price;
        return _OfferCard(
          id: treat.id,
          name: treat.name,
          blurb: treat.blurb,
          status: 'Đang có $have',
          asset: treat.asset,
          price: treat.price,
          owned: false,
          canBuy: session.petShopOpen && !full && canPay,
          hint: full
              ? 'Đủ $maxGiftCount rồi'
              : _buyHint(closed: session.petShopOpen, canPay: canPay),
          onBuy: () => session.buyTreat(treat.id),
        );
      },
    );
  }

  String _buyHint({required bool closed, required bool canPay}) {
    if (!closed) return 'Mua khi tiệm đóng cửa nhé';
    if (!canPay) return 'Chưa đủ tiền';
    return 'Chưa mua được';
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.id,
    required this.name,
    required this.blurb,
    required this.status,
    required this.asset,
    required this.price,
    required this.owned,
    required this.canBuy,
    required this.hint,
    required this.onBuy,
  });

  final String id;
  final String name;
  final String blurb;
  final String status;
  final String asset;
  final int price;
  final bool owned;
  final bool canBuy;
  final String hint;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: CardBox(
        radius: 16,
        borderWidth: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Image.asset(
                Art.pet(asset),
                width: 52,
                height: 52,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heading(size: 15),
                    ),
                    Text(
                      blurb,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 11, weight: 700),
                    ),
                    Text(status, style: AppText.caption(size: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 72,
                height: 32,
                child: owned
                    ? Center(
                        child: Text(
                          'Đã có',
                          style: AppText.body(
                            size: 13,
                            weight: 800,
                            color: AppColors.statusSuccess,
                          ),
                        ),
                      )
                    : ChunkyButton(
                        key: Key('pet-buy-$id'),
                        label: formatK(price),
                        height: 32,
                        fontSize: 12,
                        kind: ButtonKind.secondary,
                        enabled: canBuy,
                        disabledHint: hint,
                        onPressed: canBuy ? onBuy : null,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cupboard frame at its 682×1024 ratio, same card as the pot shop.
class _Frame extends StatelessWidget {
  const _Frame({
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
      key: const Key('pet-shop-popup'),
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
              key: const Key('pet-shop-close'),
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

/// Cupboard for the cushion or the bowl. Later paid skins are more cells.
class PetSkinPopup extends StatefulWidget {
  const PetSkinPopup({super.key, required this.session});

  final ShopSession session;

  @override
  State<PetSkinPopup> createState() => _PetSkinPopupState();
}

class _PetSkinPopupState extends State<PetSkinPopup> {
  String? _detailId;

  ShopSession get session => widget.session;

  @override
  Widget build(BuildContext context) {
    final kind = session.skinPicker;
    if (kind == null) return const SizedBox.shrink();
    final frame = _detailId == null
        ? Art.ui('kho_khung')
        : Art.ui('chi_tiet_khung');
    final skin = _detailId == null ? null : petSkinById(_detailId!);
    return GestureDetector(
      key: const Key('pet-skin-dismiss'),
      behavior: HitTestBehavior.opaque,
      onTap: session.closeSkinPicker,
      child: ColoredBox(
        color: AppColors.bgOverlay,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: _Frame(
              asset: frame,
              onClose: session.closeSkinPicker,
              child: skin == null ? _grid(kind) : _detail(skin),
            ),
          ),
        ),
      ),
    );
  }

  Widget _grid(String kind) {
    final skins = skinsOf(kind);
    final title = kind == skinSeat ? 'Chỗ ngồi' : 'Bát';
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        return Padding(
          padding: EdgeInsets.fromLTRB(w * 0.17, h * 0.08, w * 0.17, h * 0.10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppText.heading(size: 16)),
              Text('Chọn một mẫu', style: AppText.caption(size: 11)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final skin in skins)
                      GestureDetector(
                        key: Key('pet-skin-cell-${skin.id}'),
                        onTap: () => setState(() => _detailId = skin.id),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Image.asset(
                                Art.pet(skin.asset),
                                width: 56,
                                height: 56,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  skin.name,
                                  style: AppText.heading(size: 14),
                                ),
                              ),
                              Text(
                                session.skinEquipped(skin)
                                    ? 'Đang dùng'
                                    : skin.price <= 0
                                    ? 'Có sẵn'
                                    : formatK(skin.price),
                                style: AppText.caption(size: 11, weight: 800),
                              ),
                            ],
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

  Widget _detail(PetSkin skin) {
    final owned = session.skinOwned(skin);
    final equipped = session.skinEquipped(skin);
    final closed = session.petShopOpen;
    final canPay = session.state.money >= skin.price;
    final canBuy = !owned && closed && canPay;
    final label = equipped
        ? 'Đang dùng'
        : owned
        ? 'Dùng'
        : 'Mua ${formatK(skin.price)}';
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
              height: 32,
              child: Row(
                children: [
                  BackButtonBox(onTap: () => setState(() => _detailId = null)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      skin.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heading(size: 16),
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
                child: Image.asset(
                  Art.pet(skin.asset),
                  height: w * 0.34,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              left: w * 0.16,
              right: w * 0.16,
              top: h * 0.58,
              bottom: h * 0.09,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    skin.price <= 0 ? 'Có sẵn trong phòng' : skin.name,
                    style: AppText.body(size: 13, weight: 700),
                  ),
                  const Spacer(),
                  ChunkyButton(
                    key: Key('pet-skin-use-${skin.id}'),
                    label: label,
                    height: 40,
                    fontSize: 15,
                    enabled: !equipped && (owned || canBuy),
                    disabledHint: equipped
                        ? 'Đang dùng mẫu này'
                        : !closed
                        ? 'Mua khi tiệm đóng cửa nhé'
                        : 'Chưa đủ tiền',
                    onPressed: equipped
                        ? null
                        : owned
                        ? () => session.usePetSkin(skin.id)
                        : canBuy
                        ? () => session.buyPetSkin(skin.id)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
