import 'dart:async';

import 'package:flutter/material.dart';

import '../data/charm_board.dart' show charmBoardMaxCharm;
import '../logic/pet.dart';
import '../logic/shop_session.dart';
import '../save/game_state.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'charm_board_screen.dart';
import 'common.dart';
import 'pet_item_art.dart';
import 'pet_item_picker.dart';
import 'pet_shop_screen.dart';
import 'pet_slots_screen.dart';
import 'petdo_text.dart';
import 'ui_skin.dart';

/// "Phòng pet" (SPEC_phong_pet_vat_pham P1): the room of [ShopSession.roomPet]
/// with its three item slots, the Mị lực formula, the care card and the
/// buttons. The cushion, bowl and pet are separate pictures so a later skin
/// can replace one of them. Only the cat has poses; other pets show their
/// stage picture. Orange notes in the mock (items drawn on the pet body,
/// moving items between pets) are not part of this screen.
class PetScreen extends StatefulWidget {
  const PetScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  String? _pose;
  Timer? _poseTimer;

  ShopSession get s => widget.session;

  @override
  void dispose() {
    _poseTimer?.cancel();
    super.dispose();
  }

  void _showPose(String pose) {
    _poseTimer?.cancel();
    setState(() => _pose = pose);
    _poseTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _pose = null);
    });
  }

  String _idlePose() {
    if (_pose != null) return _pose!;
    return s.petHungry ? 'doi' : 'ngoi';
  }

  /// The equipped skin, or the free one that comes with the room.
  String _worn(String? equipped, List<String> owned, String free) {
    if (equipped != null && owned.contains(equipped)) return equipped;
    return free;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: s, builder: (context, _) => _scene());
  }

  Widget _scene() {
    final pet = s.roomPet;
    return OpaqueScreen(
      color: AppColors.bgBase,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 108,
            bottom: 0,
            child: pet == null ? _noPet() : _body(pet),
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
              key: const Key('pet-back'),
              kind: SkinRound.back,
              width: 40,
              onTap: s.closePets,
            ),
          ),
          const Positioned(
            left: 70,
            right: 70,
            top: 54,
            child: Center(
              child: SkinRibbon(
                title: PetDo.roomTitle,
                width: 190,
                height: 46,
                fontSize: 18,
              ),
            ),
          ),
          if (pet != null)
            Positioned(
              right: 12,
              top: 58,
              child: SizedBox(
                width: 84,
                child: SkinButton(
                  key: const Key('pet-open-items'),
                  label: PetDo.roomShop,
                  kind: SkinButtonKind.secondary,
                  height: 38,
                  fontSize: 13,
                  onPressed: () => s.openPetItemShop(),
                ),
              ),
            ),
          if (s.petSlotsOpen)
            Positioned.fill(child: PetSlotsScreen(session: s)),
          if (s.charmBoardOpen)
            Positioned.fill(child: CharmBoardScreen(session: s)),
          if (s.petCatalogOpen)
            Positioned.fill(child: PetCatalogPopup(session: s)),
          if (s.skinPicker != null)
            Positioned.fill(child: PetSkinPopup(session: s)),
          if (s.petItemPickSlot != null)
            Positioned.fill(child: PetItemPicker(session: s)),
          if (s.petItemSellId != null)
            Positioned.fill(child: PetItemSellPopup(session: s)),
        ],
      ),
    );
  }

  Widget _noPet() {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 40, 12, 12),
        child: _card(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mua mèo ở Tiệm thú cưng, hoặc đợi mèo lạc cuối ngày 5.',
                key: const Key('pet-empty'),
                textAlign: TextAlign.center,
                style: AppText.body(size: 13, weight: 700),
              ),
              const SizedBox(height: 8),
              ChunkyButton(
                key: const Key('pet-open-shop'),
                label: 'Tiệm thú cưng',
                height: 40,
                fontSize: 14,
                onPressed: s.openPetCatalog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(OwnedPet pet) {
    final def = s.e.pet(pet.id)!;
    final total = s.petCharmOf(pet.id);
    final items = s.petItemCharm(pet.id);
    final multiplier = s.e.charmStageMultiplier[pet.stage.clamp(0, 2)];
    final base = def.charmBase;
    final inCharmSlot = s.state.petCharm == pet.id;
    final inIncomeSlot = s.state.petIncome == pet.id;
    final atMax = total >= charmBoardMaxCharm;
    final belowMin = inCharmSlot && total < s.board.config.minCharm;
    final worn = pet.worn.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          _nameRow(pet),
          if (inIncomeSlot || inCharmSlot)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [
                  if (inIncomeSlot) _badge('Đang ở ô Thu nhập', income: true),
                  if (inCharmSlot) _badge('Đang ở ô Mị lực', income: false),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Expanded(
            child: _room(
              pet,
              atMax: atMax,
              hint: worn ? PetDo.tapHint : PetDo.emptyHint,
            ),
          ),
          const SizedBox(height: 6),
          _charmCard(
            base: base,
            multiplier: multiplier,
            items: items,
            total: total,
            atMax: atMax,
            belowMin: belowMin,
          ),
          const SizedBox(height: 6),
          _care(pet),
        ],
      ),
    );
  }

  Widget _nameRow(OwnedPet pet) {
    final many = s.state.pets.length > 1;
    Widget arrow(String key, IconData icon, int dir) => SizedBox(
      width: 44,
      height: 44,
      child: many
          ? GestureDetector(
              key: Key(key),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _pose = null;
                s.stepRoomPet(dir);
              },
              child: Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primaryBase),
                ),
              ),
            )
          : null,
    );
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          arrow('pet-prev', Icons.chevron_left, -1),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  s.petName(pet.id),
                  key: const Key('pet-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(size: 22, weight: 800),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= pet.stage
                              ? AppColors.primaryBase
                              : Colors.transparent,
                          border: Border.all(color: AppColors.primaryBase),
                        ),
                      ),
                    const SizedBox(width: 3),
                    Text(
                      petStageName(pet.stage),
                      key: const Key('pet-stage'),
                      style: AppText.caption(
                        size: 12,
                        weight: 800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          arrow('pet-next', Icons.chevron_right, 1),
        ],
      ),
    );
  }

  Widget _badge(String text, {required bool income}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.primaryBase),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          income ? const CoinIcon(size: 14) : const CharmHeart(size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppText.caption(
              size: 12,
              weight: 800,
              color: AppColors.primaryPressed,
            ),
          ),
        ],
      ),
    );
  }

  /// The frame with the pet, the cushion, the bowl and the three slots.
  Widget _room(OwnedPet pet, {required bool atMax, required String hint}) {
    final state = s.state;
    final seat = _worn(state.petSeat, state.petSeats, giftSeat);
    final bowl = _worn(state.petBowl, state.petBowls, giftBowl);
    return DecoratedBox(
      key: const Key('pet-room'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: atMax ? AppColors.accentBase : AppColors.surfaceBorderStrong,
          width: 3,
        ),
        boxShadow: atMax
            ? [
                BoxShadow(
                  color: AppColors.accentBase.withValues(alpha: 0.55),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth, h = box.maxHeight;
            final ph = (h * 0.52).clamp(80.0, 150.0);
            final k = ph / 140;
            final pw = 124 * k;
            final petTop = h * 0.2;
            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    Art.pet('phong'),
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, 0.35),
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                Positioned(
                  left: 64,
                  bottom: 26,
                  width: 72 * k,
                  height: 50 * k,
                  child: GestureDetector(
                    key: const Key('pet-bowl'),
                    onTap: () => s.openSkinPicker(skinBowl),
                    child: Image.asset(Art.pet(bowl), fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  left: (w - 180 * k) / 2,
                  top: petTop + 75 * k,
                  width: 180 * k,
                  height: 120 * k,
                  child: GestureDetector(
                    key: const Key('pet-seat'),
                    onTap: () => s.openSkinPicker(skinSeat),
                    child: Image.asset(Art.pet(seat), fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  left: (w - pw) / 2,
                  top: petTop,
                  width: pw,
                  height: ph,
                  child: GestureDetector(
                    key: const Key('pet-cat'),
                    onTap: () {
                      if (petHasPoses(pet.id)) _showPose('vuot');
                    },
                    child: Image.asset(
                      Art.pet(petArtId(pet.id, pet.stage, pose: _idlePose())),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                if (s.petHungry)
                  Positioned(
                    left: (w + pw) / 2 - 6,
                    top: petTop - 4,
                    child: Container(
                      key: const Key('pet-bubble'),
                      width: 38,
                      height: 38,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.textPrimary),
                      ),
                      child: Image.asset(Art.pet(giftBiscuit)),
                    ),
                  ),
                Positioned(left: 8, top: 8, child: _slot(pet, 'head', atMax)),
                Positioned(
                  left: 8,
                  top: 8 + 84,
                  child: _slot(pet, 'accessory', atMax),
                ),
                Positioned(right: 8, top: 8, child: _slot(pet, 'neck', atMax)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 6,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        hint,
                        key: const Key('pet-hint'),
                        style: AppText.caption(
                          size: 12,
                          weight: 800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// One slot: label, the item (or a dashed frame), "+N" or "Trống".
  Widget _slot(OwnedPet pet, String slot, bool atMax) {
    final id = pet.worn[slot];
    final item = id == null ? null : s.e.petItem(id);
    final charm = item == null ? 0 : s.e.petItemRules.charmOfTier(item.tier);
    Widget chip(Widget child) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: child,
    );
    return GestureDetector(
      key: Key('pet-slot-$slot'),
      behavior: HitTestBehavior.opaque,
      onTap: () => s.openPetItemPicker(slot),
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        decoration: atMax
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentBase.withValues(alpha: 0.6),
                    blurRadius: 10,
                  ),
                ],
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip(
              Text(
                PetDo.slotName(slot),
                style: AppText.caption(size: 11, weight: 800),
              ),
            ),
            const SizedBox(height: 3),
            if (item == null)
              PetItemEmptyFrame(slot: slot, size: 40)
            else
              PetItemIcon(slot: slot, tier: item.tier, size: 40),
            const SizedBox(height: 3),
            chip(
              item == null
                  ? Text(
                      PetDo.slotEmpty,
                      style: AppText.caption(
                        size: 11,
                        weight: 700,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : CharmBonus(
                      charm: charm,
                      size: 11,
                      color: PetItemPalette.of(item.tier).glyph,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// `Gốc × Hệ số + Đồ = Tổng`.
  Widget _charmCard({
    required int base,
    required double multiplier,
    required int items,
    required int total,
    required bool atMax,
    required bool belowMin,
  }) {
    Widget box(String label, String value, {bool strong = false, Key? key}) {
      return Expanded(
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: strong ? AppColors.primaryBase : AppColors.surfaceSunken,
            borderRadius: BorderRadius.circular(10),
            border: strong ? null : Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppText.caption(
                  size: 10,
                  weight: 800,
                  color: strong ? Colors.white : AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                key: key,
                style: AppText.number(
                  size: 17,
                  color: strong ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget op(String t) => SizedBox(
      width: 14,
      child: Center(
        child: Text(t, style: AppText.number(size: 15, weight: 800)),
      ),
    );
    final mult = multiplier == multiplier.roundToDouble()
        ? '${multiplier.round()}'
        : '$multiplier'.replaceAll('.', ',');
    Widget? side;
    if (atMax) {
      side = _sideChip(
        PetDo.charmMax(charmBoardMaxCharm),
        fill: AppColors.accentSoft,
        line: AppColors.accentBase,
        key: const Key('pet-charm-max'),
      );
    } else if (belowMin) {
      side = _sideChip(
        PetDo.charmMin(s.board.config.minCharm),
        fill: AppColors.secondarySoft,
        line: AppColors.secondaryBase,
        key: const Key('pet-charm-min'),
      );
    }
    return CardBox(
      key: const Key('pet-charm-card'),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: SizedBox(
        height: 72,
        child: Column(
          children: [
            Row(
              children: [
                const CharmMark(size: 16),
                const SizedBox(width: 4),
                Text(
                  PetDo.charmTitle,
                  style: AppText.title(size: 14, weight: 800),
                ),
                const Spacer(),
                side ??
                    Text(
                      PetDo.charmItems(items),
                      key: const Key('pet-charm-items'),
                      style: AppText.caption(
                        size: 12,
                        weight: 800,
                        color: AppColors.textSecondary,
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                box(PetDo.charmBase, '$base', key: const Key('pet-charm-base')),
                op('×'),
                box(PetDo.charmMult, mult, key: const Key('pet-charm-mult')),
                op('+'),
                box(
                  PetDo.charmItemsCol,
                  '$items',
                  key: const Key('pet-charm-items-col'),
                ),
                op('='),
                box(
                  PetDo.charmTotal,
                  '$total',
                  strong: true,
                  key: const Key('pet-charm-total'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideChip(
    String text, {
    required Color fill,
    required Color line,
    required Key key,
  }) {
    return Flexible(
      child: Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: line),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: AppText.caption(
              size: 11,
              weight: 800,
              color: AppColors.onSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// Progress and the three buttons (Bế, Cho ăn, Chọn vào ô).
  Widget _care(OwnedPet pet) {
    final state = s.state;
    final ready = s.petReadyToGrow;
    final giot = state.drops + state.stones;
    final name = s.petName(pet.id);
    final need = stonesToGrow(pet.stage);
    final meal = biscuitsToEat(pet.stage);
    final line = ready
        ? 'Đủ 100%. Cần $need giọt hoa để đột phá.'
        : pet.stage >= 2
        ? PetDo.adult(name)
        : PetDo.progress(pet.progress);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _card(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (ready) ...[
                    ArtImage(Art.pet(giftDrop), size: 22),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      line,
                      key: const Key('pet-progress'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 13, weight: 800),
                    ),
                  ),
                  ArtImage(Art.pet(giftBiscuit), size: 20),
                  const SizedBox(width: 4),
                  Text(
                    PetDo.biscuit(state.biscuits),
                    key: const Key('pet-biscuits'),
                    style: AppText.caption(size: 12, weight: 800),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: pet.stage >= 2 ? 1 : pet.progress / 100,
                  backgroundColor: AppColors.surfaceBorder,
                  color: ready
                      ? AppColors.secondaryBase
                      : AppColors.primaryBase,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Container(
                    key: const Key('pet-mood'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    decoration: BoxDecoration(
                      color: s.petHungry
                          ? AppColors.secondarySoft
                          : AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: s.petHungry
                            ? AppColors.secondaryBase
                            : AppColors.primaryBase,
                      ),
                    ),
                    child: Text(
                      s.petHungry ? PetDo.hungry(name) : PetDo.full(name),
                      style: AppText.caption(size: 11, weight: 800),
                    ),
                  ),
                ),
              ),
              if (ready) ...[
                const SizedBox(height: 6),
                ChunkyButton(
                  key: const Key('pet-break'),
                  label: 'Đột phá · $giot/$need giọt hoa',
                  height: 40,
                  fontSize: 14,
                  enabled: giot >= need,
                  disabledHint: 'Cần $need giọt hoa',
                  onPressed: giot >= need
                      ? () {
                          final pose = s.breakthroughPet();
                          if (pose != null) _showPose(pose);
                        }
                      : null,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: ChunkyButton(
                  key: const Key('pet-hold'),
                  label: PetDo.hold,
                  kind: ButtonKind.ghost,
                  height: 40,
                  fontSize: 14,
                  onPressed: () => _showPose('be'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChunkyButton(
                  key: const Key('pet-feed'),
                  // One meal's cost; the owned count is on the card above.
                  label: PetDo.feed(meal),
                  height: 40,
                  fontSize: 14,
                  enabled: state.biscuits >= meal,
                  disabledHint: 'Cần $meal bánh mật',
                  onPressed: state.biscuits >= meal
                      ? () {
                          final pose = s.feedPet();
                          if (pose != null) _showPose(pose);
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChunkyButton(
                  key: const Key('pet-open-slots'),
                  label: PetDo.pick,
                  kind: ButtonKind.ghost,
                  height: 40,
                  fontSize: 14,
                  onPressed: s.openPetSlots,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(Widget child) {
    return CardBox(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: child,
    );
  }
}
