import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../logic/pet.dart';
import '../logic/shop_session.dart';
import '../save/game_state.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'game_toast.dart';
import 'pet_shop_grid.dart';
import 'ui_skin.dart';

/// Whether the charm slot also shows the Mị lực number after the stage
/// name. The spec only names the stage and leaves the number as an open
/// question for Hà Phương, so it is one switch.
const showCharmNumber = true;

/// Màn "Ô thú cưng" (SPEC_chon_thu_o.md): two slots, Thu nhập and Mị lực,
/// pinned in a mint tray; the pets the player owns scroll below. Opened with
/// [ShopSession.openPetSlots]. Every change is saved at once.
class PetSlotsScreen extends StatefulWidget {
  const PetSlotsScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<PetSlotsScreen> createState() => _PetSlotsScreenState();
}

class _PetSlotsScreenState extends State<PetSlotsScreen> {
  /// Bumped when a tap hits the pet already in the selected slot.
  final _shake = <String, int>{};

  ShopSession get s => widget.session;

  void _tapPet(BuildContext tileContext, PetDef pet) {
    final res = s.placePetInSlot(pet.id);
    switch (res.result) {
      case PetSlotResult.placed:
        showGameToast(
          context,
          '${s.petName(pet.id)} đã vào ô ${petSlotName(res.slot!)}',
        );
      case PetSlotResult.already:
        setState(() => _shake[pet.id] = (_shake[pet.id] ?? 0) + 1);
      case PetSlotResult.pickSlot:
        showTapHint(tileContext, 'Chạm vào một ô trước nhé.');
      case PetSlotResult.notOwned:
        break;
    }
  }

  String get _hint {
    final owned = s.state.pets.isNotEmpty;
    if (!owned) return 'Nuôi thú ở Tiệm thú cưng rồi quay lại đây nhé.';
    final sel = s.petSlotSelected;
    if (sel == null) return 'Chạm vào một ô để đổi thú.';
    return s.petInSlot(sel) == null
        ? 'Chạm vào thú để đặt vào ô đang chọn.'
        : 'Chạm vào thú khác để thay, hoặc bấm × để tháo.';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final owned = [
          for (final pet in s.petShopList)
            if (s.state.ownsPet(pet.id)) pet,
        ];
        return OpaqueScreen(
          color: AppColors.bgBase,
          child: Stack(
            key: const Key('pet-slots'),
            children: [
              Positioned.fill(
                top: 106,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        height: 204,
                        child: SkinTray(
                          child: Row(
                            children: [
                              for (final slot in petSlotIds) ...[
                                if (slot != petSlotIds.first)
                                  const SizedBox(width: 8),
                                Expanded(
                                  child: PetSlotCell(
                                    key: Key('slot-$slot'),
                                    session: s,
                                    slot: slot,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _hint,
                      key: const Key('slot-hint'),
                      textAlign: TextAlign.center,
                      style: AppText.caption(
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Thú đã nuôi (${owned.length})',
                          key: const Key('slot-owned-title'),
                          style: AppText.title(
                            size: 16,
                            color: const Color(0xFF4A3B2A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: _grid(owned)),
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
                  key: const Key('slot-close'),
                  kind: SkinRound.back,
                  width: 40,
                  onTap: s.closePetSlots,
                ),
              ),
              const Positioned(
                left: 70,
                right: 70,
                top: 54,
                child: Center(
                  child: SkinRibbon(
                    title: 'Ô thú cưng',
                    width: 220,
                    height: 46,
                    fontSize: 18,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 40,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.bgBase.withValues(alpha: 0),
                          AppColors.bgBase,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _grid(List<PetDef> owned) {
    return LayoutBuilder(
      builder: (context, box) {
        final tile = (box.maxWidth - 52) / 3;
        final image = tile >= 108 ? 88.0 : 80.0;
        return GridView.builder(
          key: const Key('slot-list'),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 150,
          ),
          itemCount: owned.length + 1,
          itemBuilder: (context, i) {
            if (i == owned.length) {
              return _ShopTile(onTap: s.openPetCatalog);
            }
            final pet = owned[i];
            return Builder(
              builder: (tileContext) => _PetTile(
                key: Key('slot-pet-${pet.id}'),
                session: s,
                pet: pet,
                image: image,
                shake: _shake[pet.id] ?? 0,
                onTap: () => _tapPet(tileContext, pet),
              ),
            );
          },
        );
      },
    );
  }
}

/// Heart drawn in code until the real Mị lực icon exists.
class CharmHeart extends StatelessWidget {
  const CharmHeart({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.favorite,
    size: size,
    color: const Color(0xFFE8738A),
    semanticLabel: 'Mị lực',
  );
}

Widget _slotIcon(String slot, double size) =>
    slot == petSlotCharm ? CharmHeart(size: size) : CoinIcon(size: size);

/// One column of the tray: label, 96 frame, name, line.
class PetSlotCell extends StatefulWidget {
  const PetSlotCell({super.key, required this.session, required this.slot});

  final ShopSession session;
  final String slot;

  @override
  State<PetSlotCell> createState() => _PetSlotCellState();
}

class _PetSlotCellState extends State<PetSlotCell>
    with TickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  ShopSession get s => widget.session;

  bool get _selected => s.petSlotSelected == widget.slot;

  @override
  void initState() {
    super.initState();
    if (_selected) _glow.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PetSlotCell old) {
    super.didUpdateWidget(old);
  }

  @override
  void dispose() {
    _glow.dispose();
    _bounce.dispose();
    super.dispose();
  }

  String? _lastPet;
  var _hasBuilt = false;

  /// Starts or stops the breathing glow and the arrival bounce once the
  /// frame is built (controllers must not notify during build).
  void _syncAfterFrame(bool selected, bool arrived) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (selected && !_glow.isAnimating) {
        _glow.repeat(reverse: true);
      } else if (!selected && _glow.isAnimating) {
        _glow.stop();
      }
      if (arrived) _bounce.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final id = s.petInSlot(slot);
    final def = id == null ? null : s.e.pet(id);
    final owned = id == null ? null : s.state.ownedPet(id);
    final filled = def != null && owned != null;
    final selected = _selected;
    final arrived = _hasBuilt && id != null && id != _lastPet;
    if (selected != _glow.isAnimating || arrived) {
      _syncAfterFrame(selected, arrived);
    }
    _hasBuilt = true;
    _lastPet = id;
    final amber = filled && def.paysPhaLe;
    final line = !filled
        ? '—'
        : slot == petSlotCharm
        ? (showCharmNumber
              ? '${petStageName(owned.stage)} · ${s.petCharmOf(id!)}'
              : petStageName(owned.stage))
        : petSlotIncomeLine(def, owned.stage);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => s.selectPetSlot(slot),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 22,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _slotIcon(slot, 16),
                const SizedBox(width: 6),
                Text(
                  petSlotName(slot),
                  style: AppText.title(
                    size: 14,
                    color: AppColors.primaryPressed,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_glow, _bounce]),
                    builder: (context, child) {
                      final glow = selected
                          ? 0.45 +
                                0.30 * Curves.easeInOut.transform(_glow.value)
                          : 0.0;
                      final t = _bounce.value;
                      // 0.9 -> 1.05 -> 1
                      final scale = _bounce.isAnimating
                          ? (t < 0.5
                                ? 0.9 + 0.15 * (t / 0.5)
                                : 1.05 - 0.05 * ((t - 0.5) / 0.5))
                          : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          key: Key('slot-frame-$slot'),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: AppColors.accentBase.withValues(
                                        alpha: glow,
                                      ),
                                      blurRadius: 5,
                                      spreadRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: filled
                        ? _filledFrame(def, owned, amber, selected)
                        : _emptyFrame(selected),
                  ),
                ),
                if (filled)
                  Positioned(
                    right: -7,
                    top: -7,
                    child: GestureDetector(
                      key: Key('slot-clear-$slot'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => s.clearPetSlot(slot),
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A3B2A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.white,
                          semanticLabel: 'Tháo',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            filled ? s.petName(def.id) : 'Trống',
            key: Key('slot-name-$slot'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.title(
              size: 15,
              color: filled ? const Color(0xFF4A3B2A) : AppColors.textSecondary,
            ),
          ),
          Text(
            line,
            key: Key('slot-line-$slot'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 11,
              weight: 700,
              color: filled && slot == petSlotIncome
                  ? AppColors.primaryPressed
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyFrame(bool selected) {
    final color = selected
        ? AppColors.primaryBase
        : AppColors.surfaceBorderStrong;
    return CustomPaint(
      painter: DashedRRectPainter(color: color, strokeWidth: 1.8, radius: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 28, color: color),
            Text(
              'Chọn thú',
              style: AppText.body(size: 11, weight: 800, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filledFrame(PetDef def, OwnedPet owned, bool amber, bool selected) {
    return Container(
      decoration: BoxDecoration(
        color: amber ? AppColors.accentSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? AppColors.accentBase
              : amber
              ? AppColors.accentBase
              : AppColors.surfaceBorder,
          width: selected ? 3 : 1.5,
        ),
      ),
      child: Center(
        child: PetFrameImage(id: def.id, stage: owned.stage, size: 90),
      ),
    );
  }
}

/// One owned pet in the list: picture at its stage, name, stage name, and a
/// badge for each slot it sits in.
class _PetTile extends StatefulWidget {
  const _PetTile({
    super.key,
    required this.session,
    required this.pet,
    required this.image,
    required this.shake,
    required this.onTap,
  });

  final ShopSession session;
  final PetDef pet;
  final double image;
  final int shake;
  final VoidCallback onTap;

  @override
  State<_PetTile> createState() => _PetTileState();
}

class _PetTileState extends State<_PetTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  var _down = false;

  @override
  void didUpdateWidget(_PetTile old) {
    super.didUpdateWidget(old);
    if (old.shake != widget.shake) _shakeAnim.forward(from: 0);
  }

  @override
  void dispose() {
    _shakeAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final pet = widget.pet;
    final owned = s.state.ownedPet(pet.id)!;
    final amber = pet.paysPhaLe;
    final income = s.state.petIncome == pet.id;
    final charm = s.state.petCharm == pet.id;
    final inSlot = income || charm;
    final badges = [if (income) petSlotIncome, if (charm) petSlotCharm];
    final tint = amber ? AppColors.accentSoft : AppColors.primarySoft;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _shakeAnim,
        builder: (context, child) {
          final dx =
              math.sin(_shakeAnim.value * math.pi * 4) *
              4 *
              (1 - _shakeAnim.value);
          return Transform.translate(
            offset: Offset(dx, _down ? 3 : 0),
            child: child,
          );
        },
        child: Stack(
          children: [
            CardBox(
              radius: 14,
              borderWidth: inSlot ? 2 : 1.5,
              borderColor: inSlot
                  ? AppColors.primaryBase
                  : amber
                  ? AppColors.accentBase
                  : AppColors.surfaceBorder,
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  Container(
                    width: widget.image,
                    height: widget.image,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: PetFrameImage(
                        id: pet.id,
                        stage: owned.stage,
                        size: widget.image - 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      s.petName(pet.id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title(
                        size: 14,
                        color: const Color(0xFF4A3B2A),
                      ),
                    ),
                  ),
                  Text(
                    petStageName(owned.stage),
                    style: AppText.body(
                      size: 10.5,
                      weight: 700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < badges.length; i++)
              Positioned(
                // Top right corner of the picture, 24 apart.
                top: 2,
                right: 2 + (badges.length - 1 - i) * 24.0 + 4,
                child: Container(
                  key: Key('slot-badge-${badges[i]}-${pet.id}'),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryBase,
                      width: 1.5,
                    ),
                  ),
                  child: _slotIcon(badges[i], 13),
                ),
              ),
            if (_down)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primaryBase.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The last cell: opens the pet shop.
class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('slot-to-shop'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        painter: DashedRRectPainter(
          color: AppColors.surfaceBorderStrong,
          strokeWidth: 1.5,
          radius: 14,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 24, color: AppColors.primaryBase),
              const SizedBox(height: 4),
              Text(
                'Tiệm thú cưng',
                textAlign: TextAlign.center,
                style: AppText.title(size: 13, color: AppColors.primaryPressed),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded-rectangle outline.
class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    this.dash = 6,
    this.gap = 4,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset,
            size.width - strokeWidth,
            size.height - strokeWidth,
          ),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius;
}
