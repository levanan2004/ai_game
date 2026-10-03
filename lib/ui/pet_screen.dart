import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/pet.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'pet_shop_screen.dart';

/// The cat's room. The cushion, bowl, and cat are separate pictures so a
/// later skin can replace one of them.
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
    final state = s.state;
    final seat = _worn(state.petSeat, state.petSeats, giftSeat);
    final bowl = _worn(state.petBowl, state.petBowls, giftBowl);
    return OpaqueScreen(
      color: AppColors.bgBase,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              Art.pet('phong'),
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
          if (bowl != null)
            Positioned(
              left: 16,
              top: 400,
              width: 72,
              height: 50,
              child: GestureDetector(
                key: const Key('pet-bowl'),
                onTap: () => s.openSkinPicker(skinBowl),
                child: Image.asset(Art.pet(bowl), fit: BoxFit.contain),
              ),
            ),
          if (seat != null)
            Positioned(
              left: 96,
              top: 350,
              width: 180,
              height: 120,
              child: GestureDetector(
                key: const Key('pet-seat'),
                onTap: () => s.openSkinPicker(skinSeat),
                child: Image.asset(Art.pet(seat), fit: BoxFit.contain),
              ),
            ),
          if (state.hasCat)
            Positioned(
              left: 122,
              top: 275,
              width: 124,
              height: 140,
              child: GestureDetector(
                key: const Key('pet-cat'),
                onTap: () => _showPose('vuot'),
                child: Image.asset(
                  Art.pet(petSprite(state.petStage, _idlePose())),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          Positioned(
            left: 12,
            top: 10,
            child: BackButtonBox(
              key: const Key('pet-back'),
              onTap: s.closePets,
            ),
          ),
          Positioned(
            left: 56,
            right: 16,
            top: 8,
            height: 36,
            child: Center(
              child: _chip(
                state.hasCat ? petStageName(state.petStage) : 'Thú cưng',
              ),
            ),
          ),
          Positioned(left: 12, right: 12, bottom: 12, child: _actions()),
          if (s.petCatalogOpen)
            Positioned.fill(child: PetCatalogPopup(session: s)),
          if (s.skinPicker != null)
            Positioned.fill(child: PetSkinPopup(session: s)),
        ],
      ),
    );
  }

  Widget _actions() {
    final state = s.state;
    if (!state.hasCat) {
      return _card(
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
      );
    }
    final ready = s.petReadyToGrow;
    final giot = state.drops + state.stones;
    final need = stonesToGrow(state.petStage);
    final line = ready
        ? 'Đủ 100%. Cần $need giọt hoa để đột phá.'
        : state.petStage >= 2
        ? 'Mèo đã trưởng thành.'
        : 'Tiến trình ${state.petProgress}%';
    return _card(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ready)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ArtImage(Art.pet(giftDrop), size: 28),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    line,
                    key: const Key('pet-progress'),
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 13, weight: 800),
                  ),
                ),
              ],
            )
          else
            Text(
              line,
              key: const Key('pet-progress'),
              textAlign: TextAlign.center,
              style: AppText.body(size: 13, weight: 800),
            ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: state.petStage >= 2 ? 1 : state.petProgress / 100,
              backgroundColor: AppColors.surfaceBorder,
              color: ready ? AppColors.secondaryBase : AppColors.primaryBase,
            ),
          ),
          const SizedBox(height: 4),
          // What the player owns; the button shows what one meal costs.
          Row(
            children: [
              if (s.petHungry)
                Text(
                  'Mèo đang đói',
                  style: AppText.caption(size: 11, weight: 800),
                ),
              const Spacer(),
              Text(
                'Bánh mật: ${state.biscuits}',
                key: const Key('pet-biscuits'),
                style: AppText.caption(size: 11, weight: 800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChunkyButton(
                  key: const Key('pet-hold'),
                  label: 'Bế',
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
                  // One meal's cost; the owned count is above the button.
                  label: 'Cho ăn (-${biscuitsToEat(state.petStage)})',
                  height: 40,
                  fontSize: 14,
                  enabled: state.biscuits >= biscuitsToEat(state.petStage),
                  disabledHint: 'Cần ${biscuitsToEat(state.petStage)} bánh mật',
                  onPressed: state.biscuits >= biscuitsToEat(state.petStage)
                      ? () {
                          final pose = s.feedPet();
                          if (pose != null) _showPose(pose);
                        }
                      : null,
                ),
              ),
            ],
          ),
          if (ready) ...[
            const SizedBox(height: 8),
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
    );
  }

  Widget _card(Widget child) {
    return CardBox(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: child,
    );
  }

  Widget _chip(String text) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.headerChip,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(text, style: AppText.caption(size: 13, weight: 800)),
      ),
    );
  }
}
