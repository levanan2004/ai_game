import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../logic/format.dart';
import '../logic/pet.dart';
import '../logic/price_format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'game_toast.dart';
import 'reward_bundle_view.dart' show PhaLeIcon;
import 'ui_skin.dart';

/// Tiệm thú cưng (SPEC_shop_thu_cung.md): one two-column grid, xu pets
/// first then Pha lê pets, each by price. Food sits below the pets.
/// Opened with [ShopSession.openPetCatalog]; the back button closes it.
class PetCatalogPopup extends StatefulWidget {
  const PetCatalogPopup({super.key, required this.session});

  final ShopSession session;

  @override
  State<PetCatalogPopup> createState() => _PetCatalogPopupState();
}

class _PetCatalogPopupState extends State<PetCatalogPopup> {
  PetDef? _confirm;

  ShopSession get s => widget.session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => OpaqueScreen(
        color: AppColors.bgBase,
        child: Stack(
          key: const Key('pet-shop-popup'),
          children: [
            Positioned.fill(top: 106, child: _list()),
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
                key: const Key('pet-shop-close'),
                kind: SkinRound.back,
                width: 40,
                onTap: s.closePetCatalog,
              ),
            ),
            const Positioned(
              left: 70,
              right: 70,
              top: 54,
              child: Center(
                child: SkinRibbon(
                  title: 'Tiệm thú cưng',
                  width: 220,
                  height: 46,
                  fontSize: 18,
                ),
              ),
            ),
            if (_confirm != null)
              Positioned.fill(
                child: PetBuyPopup(
                  session: s,
                  pet: _confirm!,
                  onClose: () => setState(() => _confirm = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    final pets = s.petShopList;
    return CustomScrollView(
      key: const Key('pet-shop-list'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 254,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => PetCard(
                key: Key('pet-card-${pets[i].id}'),
                session: s,
                pet: pets[i],
                onBuy: () => setState(() => _confirm = pets[i]),
              ),
              childCount: pets.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Tác dụng của nhiều pet cộng dồn có giới hạn.',
              key: const Key('pet-shop-footer'),
              textAlign: TextAlign.center,
              style: AppText.caption(size: 12),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList.list(
            children: [
              Text('Thức ăn', style: AppText.heading(size: 16)),
              const SizedBox(height: 8),
              for (final treat in treatsForSale) _treatRow(treat),
            ],
          ),
        ),
      ],
    );
  }

  Widget _treatRow(PetTreat treat) {
    final have = treat.id == giftBiscuit ? s.state.biscuits : s.state.drops;
    final full = have >= maxGiftCount;
    final canPay = s.state.money >= treat.price;
    final canBuy = s.petShopOpen && !full && canPay;
    return SizedBox(
      height: 72,
      child: CardBox(
        radius: 16,
        borderWidth: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Image.asset(
                Art.pet(treat.asset),
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(treat.name, style: AppText.heading(size: 15)),
                    Text(
                      '${treat.blurb} · Đang có $have',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption(size: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 84,
                height: 34,
                child: ChunkyButton(
                  key: Key('pet-buy-${treat.id}'),
                  label: formatK(treat.price),
                  height: 34,
                  fontSize: 13,
                  kind: ButtonKind.secondary,
                  enabled: canBuy,
                  disabledHint: full
                      ? 'Đủ $maxGiftCount rồi'
                      : !s.petShopOpen
                      ? petShopClosedHint
                      : 'Chưa đủ xu',
                  onPressed: canBuy ? () => s.buyTreat(treat.id) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while the doors are open (purchases wait for closing time).
const petShopClosedHint = 'Mua khi tiệm đóng cửa nhé';

/// "1.200" for Pha lê prices and shortfalls.
String petGroupedCount(int n) => coinFull(n);

/// "300k" (xu) or "1.200" (Pha lê).
String petPriceText(PetDef pet) => priceLabel(pet.price, phaLe: pet.paysPhaLe);

/// Bubble on a grey price button: "Còn thiếu 150k xu", "Còn thiếu 1,2tr
/// xu", "Còn thiếu 150 Pha lê".
String petShortfallText(PetDef pet, int missing) =>
    shortfallText(phaLe: pet.paysPhaLe, missing: missing);

/// "Còn thiếu 1,2tr xu" / "Còn thiếu 50 Pha lê". Shared by the pet shop and
/// the pot shelf.
String shortfallText({required bool phaLe, required int missing}) =>
    'Còn thiếu ${priceUnit(missing, phaLe: phaLe)}';

/// The line under a grey price button.
String petShortLine(PetDef pet) =>
    pet.paysPhaLe ? 'Chưa đủ Pha lê' : 'Chưa đủ xu';

/// Ability parts joined with ", " that fit [maxLines] at [width]. Parts
/// that do not fit become " · +N" (spec §3, Kim long).
String fitAbilityLine(
  List<String> parts,
  TextStyle style,
  double width, {
  int maxLines = 2,
  TextScaler scaler = TextScaler.noScaling,
}) {
  bool fits(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      textScaler: scaler,
    )..layout(maxWidth: width);
    final over = painter.didExceedMaxLines;
    painter.dispose();
    return !over;
  }

  final whole = parts.join(', ');
  if (parts.length <= 1 || fits(whole)) return whole;
  var best = '${parts.first} · +${parts.length - 1}';
  for (var n = 2; n < parts.length; n++) {
    final text = '${parts.take(n).join(', ')} · +${parts.length - n}';
    if (!fits(text)) break;
    best = text;
  }
  return best;
}

enum PetCardState { canPayXu, canPayPhaLe, short, closed, owned }

PetCardState petCardState(ShopSession s, PetDef pet) {
  if (s.state.ownsPet(pet.id)) return PetCardState.owned;
  if (!s.petShopOpen) return PetCardState.closed;
  if (s.petShortfall(pet) > 0) return PetCardState.short;
  return pet.paysPhaLe ? PetCardState.canPayPhaLe : PetCardState.canPayXu;
}

/// One pet card, 254 tall (spec §3).
class PetCard extends StatelessWidget {
  const PetCard({
    super.key,
    required this.session,
    required this.pet,
    required this.onBuy,
  });

  final ShopSession session;
  final PetDef pet;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final state = petCardState(s, pet);
    final amber = pet.paysPhaLe;
    final owned = state == PetCardState.owned;
    final hint = switch (state) {
      PetCardState.short => petShortLine(pet),
      PetCardState.closed => petShopClosedHint,
      _ => '',
    };
    return CardBox(
      radius: 16,
      borderWidth: 1.5,
      borderColor: amber ? AppColors.accentBase : AppColors.surfaceBorder,
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, box) {
          final lineStyle = AppText.body(
            size: 12,
            weight: 700,
            color: AppColors.primaryPressed,
          ).copyWith(height: 16 / 12);
          final line = fitAbilityLine(
            petAbilityParts(pet),
            lineStyle,
            box.maxWidth,
            scaler: MediaQuery.textScalerOf(context),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PetPicture(
                pet: pet,
                height: 104,
                imageHeight: 92,
                chips: [
                  if (owned)
                    _chip(
                      'Đã nuôi',
                      key: Key('pet-owned-${pet.id}'),
                      color: AppColors.statusSuccess,
                      text: AppColors.textInverse,
                      size: 9.5,
                    ),
                ],
                bottomChips: [
                  // A tap on a chip opens the slot picker on that slot.
                  if (owned && s.state.petIncome == pet.id)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => s.openPetSlots(select: petSlotIncome),
                      child: _chip(
                        'Đang kiếm tiền',
                        key: Key('pet-income-${pet.id}'),
                        color: const Color(0xE6FFFFFF),
                        text: AppColors.primaryPressed,
                        size: 8.5,
                      ),
                    ),
                  if (owned && s.state.petCharm == pet.id)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => s.openPetSlots(select: petSlotCharm),
                      child: _chip(
                        'Đang thi Mị lực',
                        key: Key('pet-charm-${pet.id}'),
                        color: const Color(0xE6FFFFFF),
                        text: AppColors.primaryPressed,
                        size: 8.5,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 22,
                child: Text(
                  pet.nameVi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(size: 17),
                ),
              ),
              SizedBox(
                height: 32,
                child: Text(
                  line,
                  key: Key('pet-line-${pet.id}'),
                  maxLines: 2,
                  overflow: TextOverflow.clip,
                  style: lineStyle,
                ),
              ),
              const SizedBox(height: 1),
              SizedBox(
                height: 13,
                child: Text(
                  'Khi trưởng thành',
                  maxLines: 1,
                  style: AppText.caption(size: 10.5),
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: AppMotion.base,
                child: owned
                    ? SkinButton(
                        key: Key('pet-room-${pet.id}'),
                        label: 'Vào phòng',
                        kind: SkinButtonKind.secondary,
                        height: 36,
                        fontSize: 16,
                        onPressed: () => s.openPetRoom(pet.id),
                      )
                    : PetPriceButton(
                        key: Key('pet-buy-${pet.id}'),
                        pet: pet,
                        enabled:
                            state == PetCardState.canPayXu ||
                            state == PetCardState.canPayPhaLe,
                        height: 36,
                        onTap: onBuy,
                        onBlocked: (context) => showTapHint(
                          context,
                          state == PetCardState.closed
                              ? petShopClosedHint
                              : petShortfallText(pet, s.petShortfall(pet)),
                        ),
                      ),
              ),
              SizedBox(
                height: 13,
                child: Text(
                  hint,
                  key: Key('pet-hint-${pet.id}'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(size: 10.5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _chip(
  String label, {
  Key? key,
  required Color color,
  required Color text,
  required double size,
}) {
  return Container(
    key: key,
    height: 17,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8.5),
    ),
    child: Text(
      label,
      style: AppText.body(
        size: size,
        weight: 800,
        color: text,
      ).copyWith(height: 1),
    ),
  );
}

/// The pet's trưởng thành picture on its soft tile (green for xu, amber
/// for Pha lê). A missing file draws a soft placeholder and "HÌNH TẠM".
class PetPicture extends StatelessWidget {
  const PetPicture({
    super.key,
    required this.pet,
    required this.height,
    required this.imageHeight,
    this.chips = const [],
    this.bottomChips = const [],
  });

  final PetDef pet;
  final double height;
  final double imageHeight;
  final List<Widget> chips;
  final List<Widget> bottomChips;

  @override
  Widget build(BuildContext context) {
    final amber = pet.paysPhaLe;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: amber ? AppColors.accentSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(height > 110 ? 16 : 12),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            top: 2,
            child: Center(
              child: PetFrameImage(
                id: pet.id,
                stage: 2,
                size: imageHeight,
                missing: _Placeholder(pet: pet),
              ),
            ),
          ),
          if (chips.isNotEmpty)
            Positioned(left: 6, top: 6, child: Column(children: chips)),
          if (bottomChips.isNotEmpty)
            Positioned(
              left: 6,
              bottom: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < bottomChips.length; i++) ...[
                    if (i > 0) const SizedBox(height: 3),
                    bottomChips[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One pet, centered in a fixed square. Shop cards pass stage 2.
class PetFrameImage extends StatelessWidget {
  const PetFrameImage({
    super.key,
    required this.id,
    required this.stage,
    required this.size,
    this.pose = 'ngoi',
    this.missing,
  });

  final String id;
  final int stage;
  final double size;
  final String pose;
  final Widget? missing;

  @override
  Widget build(BuildContext context) {
    final edge = size * petFrameScale(id, stage);
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: SizedBox.square(
          dimension: edge,
          child: Image.asset(
            Art.pet(petArtId(id, stage, pose: pose)),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => missing ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.pet});

  final PetDef pet;

  @override
  Widget build(BuildContext context) {
    final color = pet.paysPhaLe
        ? const Color(0xFFEBCF86)
        : const Color(0xFFBFD8B8);
    return Stack(
      key: Key('pet-placeholder-${pet.id}'),
      alignment: Alignment.center,
      children: [
        CustomPaint(size: const Size(96, 92), painter: _BlobPainter(color)),
        Positioned(
          bottom: 14,
          child: Text(
            pet.nameVi,
            style: AppText.title(size: 14, weight: 800, color: Colors.white),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: _chip(
            'HÌNH TẠM',
            color: const Color(0xCCFFFFFF),
            text: AppColors.textSecondary,
            size: 8.5,
          ),
        ),
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width, h = size.height;
    canvas.drawOval(
      Rect.fromLTWH(w * 0.12, h * 0.45, w * 0.76, h * 0.55),
      paint,
    );
    canvas.drawCircle(Offset(w / 2, h * 0.36), h * 0.24, paint);
    final ear = Path()
      ..moveTo(w * 0.32, h * 0.26)
      ..lineTo(w * 0.36, h * 0.02)
      ..lineTo(w * 0.48, h * 0.18)
      ..close()
      ..moveTo(w * 0.68, h * 0.26)
      ..lineTo(w * 0.64, h * 0.02)
      ..lineTo(w * 0.52, h * 0.18)
      ..close();
    canvas.drawPath(ear, paint);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.color != color;
}

/// Price button of a pet: [CurrencyButton] with the pet's price.
class PetPriceButton extends StatelessWidget {
  const PetPriceButton({
    super.key,
    required this.pet,
    required this.enabled,
    required this.onTap,
    this.onBlocked,
    this.height = 36,
    this.label = '',
    this.fontSize = 16,
    this.full = false,
  });

  final PetDef pet;

  /// The whole number with its unit (a confirm dialog), not the card label.
  final bool full;
  final bool enabled;
  final VoidCallback onTap;
  final void Function(BuildContext context)? onBlocked;
  final double height;
  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) => CurrencyButton(
    phaLe: pet.paysPhaLe,
    priceText: full
        ? priceUnit(pet.price, phaLe: pet.paysPhaLe)
        : petPriceText(pet),
    enabled: enabled,
    onTap: onTap,
    onBlocked: onBlocked,
    height: height,
    label: label,
    fontSize: fontSize,
  );
}

/// Price button (pets spec §4, pots too): nut_chinh with a coin for xu, the
/// amber button with Pha lê, nut_tat with a faded icon when it cannot be
/// bought ([onBlocked] then shows why). [label] goes before the price
/// ("Đón về · ").
class CurrencyButton extends StatefulWidget {
  const CurrencyButton({
    super.key,
    required this.phaLe,
    required this.priceText,
    required this.enabled,
    required this.onTap,
    this.onBlocked,
    this.height = 36,
    this.label = '',
    this.fontSize = 16,
  });

  final bool phaLe;

  /// Text after the icon: the price, or "Mua 150.000 xu".
  final String priceText;
  final bool enabled;
  final VoidCallback onTap;
  final void Function(BuildContext context)? onBlocked;
  final double height;
  final String label;
  final double fontSize;

  @override
  State<CurrencyButton> createState() => _CurrencyButtonState();
}

class _CurrencyButtonState extends State<CurrencyButton> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    final amber = on && widget.phaLe;
    final color = !on
        ? const Color(0xFFF7F5EF)
        : amber
        ? AppColors.onSecondary
        : AppColors.onPrimary;
    final icon = widget.phaLe
        ? const PhaLeIcon(size: 20, hud: true)
        : const CoinIcon(size: 18);
    final content = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label.isNotEmpty)
            Text(
              widget.label,
              style: AppText.button(
                size: widget.fontSize,
                weight: 800,
                color: color,
              ),
            ),
          Opacity(opacity: on ? 1 : 0.55, child: icon),
          const SizedBox(width: 4),
          Text(
            widget.priceText,
            style: AppText.button(
              size: widget.fontSize,
              weight: 800,
              color: color,
            ),
          ),
        ],
      ),
    );
    final pressed = _down && on;
    final Widget face;
    if (amber) {
      face = PhaLeButtonFace(pressed: pressed, child: content);
    } else {
      final slice = !on
          ? UiSkin.disabled
          : pressed
          ? UiSkin.primaryPressed
          : UiSkin.primary;
      final scale = slice.scaleFor(widget.height);
      final pad = slice.padding / scale;
      final sink = pressed ? 4 / scale : 0.0;
      face = Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: SkinSliceImage(slice, scale: scale)),
          Padding(
            padding: pad.copyWith(
              left: 10,
              right: 10,
              top: pad.top + sink,
              bottom: pad.bottom - sink,
            ),
            child: Center(child: content),
          ),
        ],
      );
    }
    return Semantics(
      button: true,
      enabled: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: on ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          if (on) {
            widget.onTap();
          } else {
            widget.onBlocked?.call(context);
          }
        },
        child: SizedBox(height: widget.height, child: face),
      ),
    );
  }
}

/// The amber Pha lê button drawn in code (no skin yet): face 33 + shadow
/// 3, radius 12, `accentBase` with a 1.5 `statusWarning` border, shadow
/// #C98A2A and a soft shine. Pressed sinks the face and drops the shadow.
class PhaLeButtonFace extends StatelessWidget {
  const PhaLeButtonFace({super.key, required this.child, this.pressed = false});

  final Widget child;
  final bool pressed;

  static const shadow = Color(0xFFC98A2A);
  static const shine = Color(0xFFFFE7A3);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final depth = (box.maxHeight * 3 / 36).clamp(2.0, 4.0);
        return Stack(
          children: [
            if (!pressed)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                top: depth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: shadow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: pressed ? depth : 0,
              bottom: pressed ? 0 : depth,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accentBase,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.statusWarning,
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 6,
                      right: 6,
                      top: 3,
                      height: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: shine.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Center(child: child),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// "Đón {tên} về tiệm?" (spec §5). Tapping outside is "Để sau".
class PetBuyPopup extends StatelessWidget {
  const PetBuyPopup({
    super.key,
    required this.session,
    required this.pet,
    required this.onClose,
  });

  final ShopSession session;
  final PetDef pet;
  final VoidCallback onClose;

  void _buy(BuildContext context) {
    final s = session;
    final missing = s.petShortfall(pet);
    if (!s.petShopOpen || missing > 0) {
      showTapHint(
        context,
        !s.petShopOpen ? petShopClosedHint : petShortfallText(pet, missing),
      );
      onClose();
      return;
    }
    if (s.buyPet(pet.id)) {
      showGameToast(context, '${pet.nameVi} đã về tiệm rồi!');
    }
    onClose();
  }

  @override
  Widget build(BuildContext context) {
    final line = petAbilityLine(pet);
    final body = line.isEmpty
        ? 'Bé sẽ lớn dần khi được cho ăn bánh mật.'
        : '$line. Bé sẽ lớn dần khi được cho ăn bánh mật.';
    return GestureDetector(
      key: const Key('pet-confirm-dismiss'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        session.sounds.effect('popup_close');
        onClose();
      },
      child: ColoredBox(
        color: AppColors.bgOverlay,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: SizedBox(
              key: const Key('pet-confirm'),
              width: 320,
              child: SkinPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Đón ${pet.nameVi} về tiệm?',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AppText.title(size: 21, weight: 800),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: PetPicture(
                        pet: pet,
                        height: 124,
                        imageHeight: 108,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      body,
                      key: const Key('pet-confirm-body'),
                      textAlign: TextAlign.center,
                      style: AppText.body(
                        size: 14,
                        weight: 700,
                      ).copyWith(height: 20 / 14),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: SkinButton(
                              key: const Key('pet-confirm-later'),
                              label: 'Để sau',
                              kind: SkinButtonKind.secondary,
                              height: 44,
                              fontSize: 16,
                              onPressed: onClose,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Builder(
                              builder: (context) => PetPriceButton(
                                key: const Key('pet-confirm-yes'),
                                full: true,
                                pet: pet,
                                enabled: true,
                                height: 44,
                                fontSize: 14,
                                label: 'Đón về · ',
                                onTap: () => _buy(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
