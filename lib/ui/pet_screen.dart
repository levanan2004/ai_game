import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/skins.dart';
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
///
/// The room picture covers the whole screen, behind the top bar; the
/// screen fits one phone without scrolling.

/// A pet slot box (head / neck / accessory) and the Trang trí button.
const double petSlotSize = 56;

/// The sticky bar with Bế, Cho ăn, Chọn vào ô.
const double petActionBarHeight = 64;

/// The food bowl next to the cushion.
const double petBowlSize = 48;

/// The cushion takes this part of the screen width.
const double petSeatWidthFactor = 0.6;

/// Pet picture height (was 170 at most; ~20% bigger).
const double petMaxHeight = 204;

/// Green of the Cho ăn button and the food popup's Mua button.
const Color petFeedGreen = Color(0xFF3F7F52);

/// Wooden frame of the slots and the Trang trí button.
const Color _woodDark = Color(0xFF7A4A24);
const Color _woodLight = Color(0xFFC08A55);
const Color _woodFill = Color(0xFFF6E7C8);

class PetScreen extends StatefulWidget {
  const PetScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen>
    with SingleTickerProviderStateMixin {
  String? _pose;
  Timer? _poseTimer;
  late final AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  ShopSession get s => widget.session;

  @override
  void dispose() {
    _poseTimer?.cancel();
    _bounce.dispose();
    super.dispose();
  }

  void _showPose(String pose) {
    _poseTimer?.cancel();
    setState(() => _pose = pose);
    _bounce.forward(from: 0);
    _poseTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _pose = null);
    });
  }

  String _idlePose() {
    if (_pose != null) return _pose!;
    return s.petHungry ? 'doi' : 'ngoi';
  }

  /// The pet for its stage and the pose now. A baby or teen pose picture that
  /// cannot be loaded falls back to the shared (grown) one.
  Widget _petPicture(OwnedPet pet) {
    final pose = _idlePose();
    final fallback = petArtFallbackId(pet.id, pet.stage, pose: pose);
    return Image.asset(
      Art.pet(petArtId(pet.id, pet.stage, pose: pose)),
      fit: BoxFit.contain,
      errorBuilder: fallback == null
          ? null
          : (context, error, stack) =>
                Image.asset(Art.pet(fallback), fit: BoxFit.contain),
    );
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
          Positioned.fill(
            child: Image.asset(
              s.skinAsset('nenPhong'),
              key: const Key('pet-room-bg'),
              fit: BoxFit.cover,
              alignment: const Alignment(0, 0.35),
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Image.asset(
                Art.pet('phong'),
                fit: BoxFit.cover,
                alignment: const Alignment(0, 0.35),
              ),
            ),
          ),
          Positioned.fill(top: 100, child: pet == null ? _noPet() : _body(pet)),
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
    // The most a pet and its items can bring (`charm.partMax`); owned pots
    // add their own part on top.
    final petMax = s.e.charmRules.petMax + s.e.charmRules.petItemsMax;
    final atMax = petMax > 0 && total >= petMax;
    final belowMin = inCharmSlot && total < s.board.config.minCharm;
    final worn = pet.worn.isNotEmpty;
    // One screen, no scroll: the scene takes what the cards and the bar
    // leave.
    return Column(
      children: [
        _nameRow(pet),
        Expanded(
          child: _room(
            pet,
            atMax: atMax,
            worn: worn,
            inIncome: inIncomeSlot,
            inCharm: inCharmSlot,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            children: [
              _charmCard(
                base: base,
                multiplier: multiplier,
                items: items,
                total: total,
                atMax: atMax,
                belowMin: belowMin,
              ),
              const SizedBox(height: 8),
              _growth(pet),
            ],
          ),
        ),
        _actionBar(pet),
      ],
    );
  }

  /// Text over the room picture keeps a soft white glow to stay readable.
  static const _glow = [Shadow(color: Colors.white, blurRadius: 6)];

  Widget _nameRow(OwnedPet pet) {
    final many = s.state.pets.length > 1;
    Widget arrow(String key, IconData icon, int dir) => SizedBox(
      width: 44,
      height: 32,
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
                  width: 28,
                  height: 28,
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
      height: 32,
      child: Row(
        children: [
          arrow('pet-prev', Icons.chevron_left, -1),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    s.petName(pet.id),
                    key: const Key('pet-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(
                      size: 20,
                      weight: 800,
                    ).copyWith(shadows: _glow),
                  ),
                ),
                const SizedBox(width: 6),
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= pet.stage
                          ? AppColors.primaryBase
                          : Colors.white,
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
                    color: AppColors.textPrimary,
                  ).copyWith(shadows: _glow),
                ),
              ],
            ),
          ),
          arrow('pet-next', Icons.chevron_right, 1),
        ],
      ),
    );
  }

  Widget _badge(String text, {required bool income, required Key key}) {
    return Container(
      key: key,
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

  /// The scene over the room picture: the slots at the side edges, the
  /// cushion with the pet, the bowl and toy, and the slot labels under the
  /// cushion. Its size depends only on the screen, so a pet, an empty slot or
  /// a full one never moves the cards or the bar below. A swipe sideways is
  /// the same as the arrows.
  Widget _room(
    OwnedPet pet, {
    required bool atMax,
    required bool worn,
    required bool inIncome,
    required bool inCharm,
  }) {
    final state = s.state;
    final seat = _worn(state.petSeat, state.petSeats, seatDefaultSkin);
    final ready = s.petReadyToGrow;
    final giot = state.drops + state.stones;
    final need = stonesToGrow(pet.stage);
    return GestureDetector(
      key: const Key('pet-room'),
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 250) return;
        _pose = null;
        s.stepRoomPet(v < 0 ? 1 : -1);
      },
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          const labelsH = 24.0;
          // Cushion pictures are 180x120; pet feet sit at 70% of its height.
          final seatW = w * petSeatWidthFactor;
          final seatH = seatW * 120 / 180;
          final seatBottom = h - labelsH - 2;
          final seatTop = seatBottom - seatH;
          final feet = seatTop + 0.7 * seatH;
          final ph = math.max(0.0, math.min(petMaxHeight, feet - 4));
          final pw = 124 * ph / 140;
          final petTop = feet - ph;
          final seatLeft = (w - seatW) / 2;
          return Stack(
            children: [
              Positioned(
                left: seatLeft,
                top: seatTop,
                width: seatW,
                height: seatH,
                child: GestureDetector(
                  key: const Key('pet-seat'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => s.openSkinPicker(skinSeat),
                  child: Image.asset(
                    s.skinAsset('choNgoi'),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Image.asset(
                      Art.pet(petSkinById(seat)?.asset ?? seat),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Toy at the front-left corner, mirrored from the bowl.
              Positioned(
                right: seatLeft + seatW + 2,
                top: seatBottom - petBowlSize,
                width: petBowlSize,
                height: petBowlSize,
                child: Image.asset(
                  s.skinAsset('doChoi'),
                  key: const Key('pet-toy'),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              Positioned(
                left: seatLeft + seatW + 2,
                top: seatBottom - petBowlSize,
                width: petBowlSize,
                height: petBowlSize,
                child: _bowl(pet),
              ),
              if (!_hasMeal(pet))
                Positioned(
                  left: seatLeft + seatW + 2 + petBowlSize - 18,
                  top: seatBottom - petBowlSize - 26,
                  child: IgnorePointer(
                    child: Container(
                      key: const Key('pet-bubble'),
                      width: 30,
                      height: 30,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.textPrimary),
                      ),
                      child: Image.asset(Art.pet(giftBiscuit)),
                    ),
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
                  child: AnimatedBuilder(
                    animation: _bounce,
                    builder: (context, child) {
                      // A happy hop on every pose (the pets that lack a
                      // picture for one keep their stage picture and hop).
                      final t = _bounce.value;
                      final hop = _pose == null ? 0.0 : math.sin(math.pi * t);
                      return Transform.translate(
                        offset: Offset(0, -10 * hop),
                        child: Transform.scale(
                          scale: 1 + 0.04 * hop,
                          alignment: Alignment.bottomCenter,
                          child: child,
                        ),
                      );
                    },
                    child: _petPicture(pet),
                  ),
                ),
              ),
              if (_hearts(pet))
                Positioned(
                  left: (w - pw) / 2,
                  top: petTop - 6,
                  width: pw,
                  height: ph * 0.5,
                  child: IgnorePointer(
                    child: _Hearts(key: const Key('pet-hearts'), t: _bounce),
                  ),
                ),
              Positioned(left: 8, top: 4, child: _slot(pet, 'head', atMax)),
              Positioned(
                left: 8,
                top: 4 + petSlotSize + 24,
                child: _slot(pet, 'accessory', atMax),
              ),
              Positioned(right: 8, top: 4, child: _slot(pet, 'neck', atMax)),
              Positioned(
                right: 8,
                top: 4 + petSlotSize + 24,
                child: _decorateButton(s),
              ),
              // Ô Thu nhập / Ô Mị lực in one row just under the cushion.
              Positioned(
                left: 8,
                right: 8,
                top: seatBottom + 2,
                height: labelsH - 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (inIncome)
                        _badge(
                          'Ô Thu nhập',
                          income: true,
                          key: const Key('pet-badge-income'),
                        ),
                      if (inIncome && inCharm) const SizedBox(width: 6),
                      if (inCharm)
                        _badge(
                          'Ô Mị lực',
                          income: false,
                          key: const Key('pet-badge-charm'),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: seatTop + seatH * 0.72,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ready)
                      SizedBox(
                        width: 230,
                        child: ChunkyButton(
                          key: const Key('pet-break'),
                          label: 'Đột phá · $giot/$need giọt hoa',
                          height: 36,
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
                      )
                    else if (!worn)
                      _hintChip(PetDo.emptyHint, const Key('pet-empty-hint')),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Enough bánh mật for one meal of [pet].
  bool _hasMeal(OwnedPet pet) => s.state.biscuits >= biscuitsToEat(pet.stage);

  /// The bowl of the room skin. With food it shows a biscuit in it; empty, a
  /// small food bubble (the hungry hint) floats above it. A tap is Cho ăn.
  Widget _bowl(OwnedPet pet) {
    final bowl = _worn(s.state.petBowl, s.state.petBowls, bowlDefaultSkin);
    return GestureDetector(
      key: const Key('pet-bowl'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _feed(pet),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              s.skinAsset('batAn'),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Image.asset(
                Art.pet(petSkinById(bowl)?.asset ?? bowl),
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (_hasMeal(pet))
            Align(
              alignment: const Alignment(0, -0.3),
              child: Image.asset(
                Art.pet(giftBiscuit),
                key: const Key('pet-bowl-food'),
                width: 22,
                height: 22,
              ),
            ),
        ],
      ),
    );
  }

  /// Cho ăn, from the button or the bowl.
  void _feed(OwnedPet pet) {
    if (!_hasMeal(pet)) return;
    final pose = s.feedPet();
    if (pose != null) _showPose(pose);
  }

  Widget _hintChip(String text, Key key) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      text,
      key: key,
      style: AppText.caption(
        size: 12,
        weight: 800,
        color: AppColors.textSecondary,
      ),
    ),
  );

  /// Hearts over the pet while it is stroked, and for a pose the pet has no
  /// picture for (growing, breakthrough): the stage picture hops with hearts.
  bool _hearts(OwnedPet pet) =>
      _pose != null &&
      (_pose == 'vuot' || !petHasPoseArt(pet.id, _pose!, stage: pet.stage));

  /// A 56dp box with a wooden frame drawn in code.
  Widget _woodBox({required Widget child, bool glow = false}) => Container(
    width: petSlotSize,
    height: petSlotSize,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: _woodDark,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        if (glow)
          BoxShadow(
            color: AppColors.accentBase.withValues(alpha: 0.6),
            blurRadius: 10,
          )
        else
          const BoxShadow(
            color: Color(0x33000000),
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
      ],
    ),
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _woodFill,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _woodLight, width: 1.5),
      ),
      child: child,
    ),
  );

  /// Trang trí phòng: same wooden box as the slots, under Cổ.
  Widget _decorateButton(ShopSession s) {
    return GestureDetector(
      key: const Key('pet-open-decorate'),
      behavior: HitTestBehavior.opaque,
      onTap: () => s.openDecorate(skinGroupRoom),
      child: Column(
        children: [
          _woodBox(child: const Icon(Icons.brush, size: 26, color: _woodDark)),
          const SizedBox(height: 2),
          _slotLabel(
            Text(
              s.skins.ui('skin.edit.pet'),
              maxLines: 1,
              style: AppText.caption(size: 11, weight: 800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotLabel(Widget child) => Container(
    height: 18,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: child,
  );

  /// One slot: the item (or the slot name) in a wooden box, its Mị lực bonus
  /// ("+N") or "Trống" under it.
  Widget _slot(OwnedPet pet, String slot, bool atMax) {
    final id = pet.worn[slot];
    final item = id == null ? null : s.e.petItem(id);
    final charm = item == null ? 0 : s.e.petItemRules.charmOfTier(item.tier);
    return GestureDetector(
      key: Key('pet-slot-$slot'),
      behavior: HitTestBehavior.opaque,
      onTap: () => s.openPetItemPicker(slot),
      child: Column(
        children: [
          _woodBox(
            glow: atMax,
            child: item == null
                ? Text(
                    PetDo.slotName(slot),
                    textAlign: TextAlign.center,
                    style: AppText.caption(
                      size: 11,
                      weight: 800,
                      color: _woodDark,
                    ),
                  )
                : PetItemIcon(
                    itemId: item.id,
                    slot: slot,
                    tier: item.tier,
                    size: 40,
                  ),
          ),
          const SizedBox(height: 2),
          _slotLabel(
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
        PetDo.charmMax(s.e.charmRules.petMax + s.e.charmRules.petItemsMax),
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
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 64,
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

  /// Progress, bánh mật and mood (the buttons are in the bar below).
  Widget _growth(OwnedPet pet) {
    final state = s.state;
    final ready = s.petReadyToGrow;
    final name = s.petName(pet.id);
    final need = stonesToGrow(pet.stage);
    final line = ready
        ? 'Đủ 100%. Cần $need giọt hoa để đột phá.'
        : pet.stage >= 2
        ? PetDo.adult(name)
        : PetDo.progress(pet.progress);
    return _card(
      Column(
        key: const Key('pet-growth-card'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 22,
            child: Row(
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
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: pet.stage >= 2 ? 1 : pet.progress / 100,
              backgroundColor: AppColors.surfaceBorder,
              color: ready ? AppColors.secondaryBase : AppColors.primaryBase,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                key: const Key('pet-mood'),
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
        ],
      ),
    );
  }

  /// The sticky bar: Bế, Cho ăn (green, in the middle), Chọn vào ô. Each
  /// button has its icon above its label.
  Widget _actionBar(OwnedPet pet) {
    final meal = biscuitsToEat(pet.stage);
    Widget button({
      required Key key,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool green = false,
    }) {
      final fg = green ? Colors.white : AppColors.primaryPressed;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: GestureDetector(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: green ? petFeedGreen : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: green
                    ? null
                    : Border.all(color: AppColors.surfaceBorderStrong),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: fg),
                  Text(
                    label,
                    maxLines: 1,
                    style: AppText.caption(size: 12, weight: 800, color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: const Key('pet-action-bar'),
      height: petActionBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Row(
        children: [
          button(
            key: const Key('pet-hold'),
            icon: Icons.volunteer_activism,
            label: PetDo.hold,
            onTap: () => _showPose('be'),
          ),
          button(
            key: const Key('pet-feed'),
            icon: Icons.restaurant,
            // One meal's cost; the owned count is on the card above.
            label: PetDo.feed(meal),
            green: true,
            onTap: () => _feed(pet),
          ),
          button(
            key: const Key('pet-open-slots'),
            icon: Icons.grid_view_rounded,
            label: PetDo.pick,
            onTap: s.openPetSlots,
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
    return CardBox(padding: const EdgeInsets.all(12), child: child);
  }
}

/// Three small hearts that float up and fade while [t] runs.
class _Hearts extends StatelessWidget {
  const _Hearts({super.key, required this.t});

  final Animation<double> t;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        Widget heart(double dx, double delay, double size) {
          final p = ((v - delay) / (1 - delay)).clamp(0.0, 1.0);
          return Align(
            alignment: Alignment(dx, 1 - 2 * p),
            child: Opacity(
              opacity: (1 - p) * (p == 0 ? 0 : 1),
              child: Icon(
                Icons.favorite,
                size: size,
                color: const Color(0xFFE5677B),
              ),
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(child: heart(-0.6, 0, 16)),
            Positioned.fill(child: heart(0.1, 0.15, 20)),
            Positioned.fill(child: heart(0.7, 0.3, 14)),
          ],
        );
      },
    );
  }
}
