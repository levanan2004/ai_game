import 'package:flutter/material.dart';

import '../data/share_text.dart' show ShareKind;
import '../data/skins.dart';
import '../logic/pet.dart' show petArtFallbackId, petArtId;
import '../logic/pot_slots.dart';
import '../logic/price_format.dart';
import '../logic/shop_session.dart';
import '../save/game_state.dart'
    show barPotSlots, defaultPotId, displayPotSlots;
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'game_toast.dart';
import 'pet_shop_grid.dart' show CurrencyButton;
import 'share_sheet.dart';
import 'ui_skin.dart';

/// Preview height cap (Phú): at most 38% of the screen, so 1.5 rows of
/// cards still show under it.
const double decoratePreviewMaxShare = 0.38;

/// The preview sits 44px under the main screen's top (its header).
const _previewShift = Offset(0, -44);

/// Tiệm Trang Trí (spec_skin_trang_tri.md §5–6): buy and pick on one
/// screen. Tapping a card only previews it; "Lưu" wears the owned picks,
/// or turns into "Mua {n} món" while unowned ones are previewed.
/// Opened with [SkinShopSession.openDecorate].
class DecorateScreen extends StatefulWidget {
  const DecorateScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<DecorateScreen> createState() => _DecorateScreenState();
}

class _DecorateScreenState extends State<DecorateScreen> {
  bool _sharing = false;
  late final String group = s.decorateGroup ?? skinGroupShop;
  late final List<String> slots = group == skinGroupShop
      ? skinShopSlots
      : skinRoomSlots;
  late String tab = slots.first;
  late Map<String, String> picks = s.skinWornSet(group);
  bool ownedOnly = false;
  bool buying = false;
  bool discard = false;
  bool busy = false;

  ShopSession get s => widget.session;
  SkinCatalog get cat => s.skins;

  bool get _changedPicks {
    final worn = s.skinWornSet(group);
    return picks.entries.any((e) => worn[e.key] != e.value);
  }

  /// Previewed skins that can still be bought (not owned, not event).
  List<SkinDef> get _toBuy => [
    for (final id in picks.values)
      if (cat.byId(id) case final d?)
        if (!s.skinHas(d.id) && !d.isEvent && !d.isDefault) d,
  ];

  /// An unowned event skin is previewed: Lưu puts the worn one back, free.
  bool get _eventPreview => picks.values.any((id) {
    final d = cat.byId(id);
    return d != null && d.isEvent && !s.skinHas(d.id);
  });

  void _back() {
    if (_changedPicks) {
      setState(() => discard = true);
    } else {
      s.closeDecorate();
    }
  }

  void _save() {
    if (!s.skinGroupEditable(group)) {
      showGameToast(context, cat.ui('skin.closedOnly'));
      return;
    }
    if (_toBuy.isNotEmpty) {
      setState(() => buying = true);
      return;
    }
    s.wearSkins(picks);
    setState(() => picks = s.skinWornSet(group));
  }

  Future<void> _buyAll() async {
    if (busy) return;
    setState(() => busy = true);
    for (final d in _toBuy) {
      if (!await s.buySkin(d.id)) break;
    }
    if (!mounted) return;
    s.wearSkins(picks);
    setState(() {
      busy = false;
      buying = false;
      // Bought ones are worn; an event preview goes back (Hà Phương).
      picks = s.skinWornSet(group);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final list = [
          for (final d in cat.ofSlot(tab))
            if (!ownedOnly || s.skinHas(d.id)) d,
        ];
        final toBuy = _toBuy;
        final eventNote = _eventPreview;
        final screenH = MediaQuery.sizeOf(context).height;
        final previewH = (screenH * decoratePreviewMaxShare).clamp(0.0, 268.0);
        final tabsTop = 98 + previewH + 4;
        return OpaqueScreen(
          color: AppColors.bgBase,
          child: Stack(
            key: const Key('decorate'),
            children: [
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
                left: 8,
                top: 58,
                child: SkinRoundButton(
                  key: const Key('decorate-back'),
                  kind: SkinRound.back,
                  width: 34,
                  onTap: _back,
                ),
              ),
              Positioned(
                left: 60,
                right: 92,
                top: 58,
                child: Center(
                  child: SkinRibbon(
                    title: cat.ui(
                      group == skinGroupShop
                          ? 'skin.edit.shop'
                          : 'skin.edit.pet',
                    ),
                    width: 200,
                    height: 36,
                    fontSize: 16,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 60,
                width: 80,
                child: SkinTab(
                  key: const Key('decorate-owned'),
                  label: cat.ui('skin.filterOwned'),
                  selected: ownedOnly,
                  height: 32,
                  fontSize: 12,
                  onTap: () => setState(() => ownedOnly = !ownedOnly),
                ),
              ),
              Positioned(
                left: 0,
                top: 98,
                width: 360,
                height: previewH,
                // Drawn at 360×268 and scaled down to the cap.
                child: FittedBox(
                  child: SizedBox(
                    width: 360,
                    height: 268,
                    child: _Preview(
                      session: s,
                      group: group,
                      picks: picks,
                      focus: tab,
                    ),
                  ),
                ),
              ),
              // Khoe tiệm hoa (chia_se.json button.share_shop): the shop
              // as it is worn, bottom-left of the preview.
              if (group == skinGroupShop)
                Positioned(
                  left: 8,
                  top: 98 + previewH - 8 - 30,
                  child: OutlineButton(
                    key: const Key('share-shop'),
                    label: s.data.share.ui('button.share_shop'),
                    icon: Icons.share,
                    onTap: () => setState(() => _sharing = true),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                top: tabsTop,
                height: 36,
                child: Row(
                  children: [
                    for (final slot in slots)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: SkinTab(
                            key: Key('decorate-tab-$slot'),
                            label: cat.ui('slot.$slot'),
                            selected: slot == tab,
                            height: 36,
                            fontSize: 12,
                            onTap: () => setState(() => tab = slot),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: tabsTop + 40,
                bottom: eventNote ? 84 : 64,
                child: GridView.builder(
                  key: const Key('decorate-grid'),
                  padding: const EdgeInsets.only(bottom: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 120,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _SkinCard(
                    key: Key('decorate-card-${list[i].id}'),
                    session: s,
                    skin: list[i],
                    previewing: picks[tab] == list[i].id,
                    onPreview: () =>
                        setState(() => picks = {...picks, tab: list[i].id}),
                  ),
                ),
              ),
              if (eventNote)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 62,
                  height: 20,
                  child: Center(
                    child: Text(
                      cat.ui('skin.event.preview_only'),
                      key: const Key('decorate-event-note'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(
                        size: 12,
                        weight: 700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                height: 44,
                child: Row(
                  children: [
                    Expanded(
                      child: SkinButton(
                        key: const Key('decorate-undo'),
                        label: cat.ui('skin.undo'),
                        kind: SkinButtonKind.secondary,
                        height: 44,
                        fontSize: 16,
                        enabled: _changedPicks,
                        onPressed: () =>
                            setState(() => picks = s.skinWornSet(group)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SkinButton(
                        key: const Key('decorate-save'),
                        label: toBuy.isEmpty
                            ? cat.ui('skin.save')
                            : cat.ui('skin.buyN', {'n': toBuy.length}),
                        height: 44,
                        fontSize: 16,
                        enabled: _changedPicks,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ),
              if (buying)
                Positioned.fill(
                  child: _BuyPopup(
                    session: s,
                    items: toBuy,
                    busy: busy,
                    onBuy: _buyAll,
                    onClose: () => setState(() => buying = false),
                  ),
                ),
              if (discard)
                Positioned.fill(
                  child: _Ask(
                    keyName: 'decorate-discard',
                    title: cat.ui('skin.discard'),
                    yes: cat.ui('skin.discard.yes'),
                    no: cat.ui('skin.discard.no'),
                    onYes: s.closeDecorate,
                    onNo: () => setState(() => discard = false),
                  ),
                ),
              if (_sharing)
                Positioned.fill(
                  child: ShareSheet(
                    session: s,
                    kind: ShareKind.shop,
                    onClose: () => setState(() => _sharing = false),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Signboard skins: 552×84, end caps ~36% of the width keep their shape.
SkinSlice signSlice(String id) =>
    SkinSlice(id, w: 552, h: 84, left: 199, right: 199, dir: 'skin/tiem');

/// The live scene with the previewed skins: the shop area y44–312 at 1:1,
/// or the pet room. The tab's slot gets a dashed gold outline.
/// The shop as it is now (worn skins, bar pots, shop name) at 360×268, for
/// the share image (spec_khung_chia_se §5 B).
class ShopScenePreview extends StatelessWidget {
  const ShopScenePreview({super.key, required this.session});

  final ShopSession session;

  static const size = Size(360, 268);

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: size,
    child: _Preview(
      session: session,
      group: skinGroupShop,
      picks: session.skinWornSet(skinGroupShop),
      focus: '',
      plain: true,
    ),
  );
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.session,
    required this.group,
    required this.picks,
    required this.focus,
    this.plain = false,
  });

  final ShopSession session;
  final String group;
  final Map<String, String> picks;
  final String focus;

  /// For the share image: no "Cả bộ" chip.
  final bool plain;

  String _asset(String slot) =>
      session.skins.byId(picks[slot] ?? '')?.asset ?? '';

  Widget _img(String slot, {BoxFit fit = BoxFit.contain, Alignment? align}) =>
      Image.asset(
        _asset(slot),
        fit: fit,
        alignment: align ?? Alignment.center,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) {
    final shop = group == skinGroupShop;
    final rects = shop ? _shopRects() : _roomRects();
    final focusRects = rects[focus] ?? const <Rect>[];
    final cat = session.skins;
    final themes = {for (final id in picks.values) cat.byId(id)?.theme};
    final theme = themes.length == 1 ? themes.first : null;
    return ClipRect(
      key: const Key('decorate-preview'),
      child: Stack(
        children: [
          Positioned.fill(
            child: _img(
              shop ? 'nenManHinh' : 'nenPhong',
              fit: BoxFit.cover,
              align: shop ? Alignment.bottomCenter : const Alignment(0, 0.35),
            ),
          ),
          if (shop) ...[
            Positioned.fromRect(
              rect: const Rect.fromLTWH(12, 88, 336, 20),
              child: Image.asset(
                Art.scene('ke_hoa'),
                fit: BoxFit.fill,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            Positioned.fromRect(
              rect: displayShelfPlank.shift(_previewShift),
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minHeight: 60 * plankArtScale,
                  maxHeight: 60 * plankArtScale,
                  child: Transform.translate(
                    offset: const Offset(0, -plankFaceSrcTop * plankArtScale),
                    child: Image.asset(
                      Art.scene('ke_hoa'),
                      fit: BoxFit.fill,
                      width: displayShelfPlank.width,
                      height: 60 * plankArtScale,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            // The pots as ShopScene draws them: all 5 bar slots (the free
            // bucket or the pot), then the stand's non-free pots.
            for (var i = 0; i < barPotSlots; i++)
              _pot(
                Key('decorate-pot-$i'),
                session.state.barPots[i],
                barPotRect(i).shift(_previewShift),
                bucket: Rect.fromLTWH(
                  barSlotX(i) + 2,
                  110,
                  40,
                  32,
                ).shift(_previewShift),
              ),
            for (var i = 0; i < displayPotSlots; i++)
              if (session.state.displayPots[i] != defaultPotId)
                _pot(
                  Key('decorate-stand-pot-$i'),
                  session.state.displayPots[i],
                  displayPotRects[i].shift(_previewShift),
                ),
            Positioned.fromRect(
              rect: rects['bienHieu']!.first,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (picks['bienHieu'] != null)
                    SkinSliceImage(signSlice(picks['bienHieu']!), scale: 3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          session.state.shopName ?? '',
                          key: const Key('decorate-shop-name'),
                          maxLines: 1,
                          style: AppText.make(
                            AppFonts.display,
                            14,
                            800,
                            color: AppColors.primaryPressed,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fromRect(
              rect: rects['quay']!.first,
              child: _img('quay', fit: BoxFit.fill),
            ),
          ] else ...[
            for (final slot in const ['batAn', 'doChoi', 'choNgoi'])
              Positioned.fromRect(rect: rects[slot]!.first, child: _img(slot)),
            if (session.roomPet case final pet?)
              Positioned.fromRect(
                rect: _petRect(rects['choNgoi']!.first),
                child: Image.asset(
                  Art.pet(petArtId(pet.id, pet.stage)),
                  key: const Key('decorate-pet'),
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (_, _, _) {
                    final f = petArtFallbackId(pet.id, pet.stage);
                    return f == null
                        ? const SizedBox.shrink()
                        : Image.asset(Art.pet(f), fit: BoxFit.contain);
                  },
                ),
              ),
          ],
          for (final r in focusRects)
            Positioned.fromRect(
              rect: r.deflate(1),
              child: const IgnorePointer(
                child: CustomPaint(painter: _DashPainter()),
              ),
            ),
          if (!plain && theme != null && theme != skinDefaultTheme)
            Positioned(
              right: 8,
              bottom: 8,
              child: Pill(
                key: const Key('decorate-set'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      cat.ui('skin.set', {'chuDe': cat.ui('theme.$theme')}),
                      style: AppText.body(size: 12, weight: 800),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The pet as in the room (124×140 next to a 180-wide cushion), feet at
  /// 70% of the cushion picture height.
  static Rect _petRect(Rect seat) {
    final w = seat.width * 124 / 180;
    final h = w * 140 / 124;
    return Rect.fromLTWH(
      seat.center.dx - w / 2,
      seat.top + seat.height * 0.7 - h,
      w,
      h,
    );
  }

  /// Pot [id] in [slot] like ShopScene: the free bucket at [bucket] (bar
  /// only), any other pot grown by its potScale around the bottom centre.
  Widget _pot(Key key, String id, Rect slot, {Rect? bucket}) {
    final free = id == defaultPotId;
    if (free && bucket == null) return const SizedBox.shrink();
    var k = 1.0;
    for (final p in session.e.pots) {
      if (p.id == id) {
        k = p.unlimited ? 1.0 : p.potScale;
        break;
      }
    }
    final w = slot.width * k, h = slot.height * k;
    return Positioned.fromRect(
      rect: free
          ? bucket!
          : Rect.fromLTWH(slot.center.dx - w / 2, slot.bottom - h, w, h),
      child: Image.asset(
        free ? Art.scene('xo_hoa') : Art.pot(id),
        key: key,
        fit: free ? BoxFit.fill : BoxFit.contain,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }

  /// Same places as ShopScene, moved up by the 44px header.
  static Map<String, List<Rect>> _shopRects() => {
    'nenManHinh': const [Rect.fromLTWH(0, 0, 360, 268)],
    'bienHieu': const [Rect.fromLTWH(88, 16, 184, 28)],
    'quay': const [Rect.fromLTWH(0, 232, 360, 24)],
  };

  /// The pet room at 0.5: cushion in the middle, bowl left, toy right.
  static Map<String, List<Rect>> _roomRects() => {
    'nenPhong': const [Rect.fromLTWH(0, 0, 360, 268)],
    'choNgoi': const [Rect.fromLTWH(135, 168, 90, 60)],
    'batAn': const [Rect.fromLTWH(64, 217, 36, 25)],
    'doChoi': const [Rect.fromLTWH(260, 206, 36, 36)],
  };
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5C451)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..addRect(Offset.zero & size);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

/// Tier chip colours (spec §2).
(Color, Color, Color) _tierColors(SkinDef d) => switch (d.tier) {
  'dep' => (
    const Color(0xFFDCEBFF),
    const Color(0xFF2F5FA8),
    const Color(0xFF9CC0EE),
  ),
  'hiem' => (
    const Color(0xFFF5C451),
    const Color(0xFF5A3B0A),
    const Color(0xFFF5C451),
  ),
  'suKien' => (const Color(0xFFC46BB8), Colors.white, const Color(0xFFC46BB8)),
  'thuong' => (
    const Color(0xFFE6F2E8),
    AppColors.primaryBase,
    const Color(0xFFCFE3D3),
  ),
  _ => (
    const Color(0xFFEEEEEE),
    const Color(0xFF666666),
    const Color(0xFFCFE3D3),
  ),
};

/// One skin card (spec §3): tier chip, picture, name and the action.
class _SkinCard extends StatelessWidget {
  const _SkinCard({
    super.key,
    required this.session,
    required this.skin,
    required this.previewing,
    required this.onPreview,
  });

  final ShopSession session;
  final SkinDef skin;
  final bool previewing;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final cat = s.skins;
    final d = skin;
    final owned = s.skinHas(d.id);
    final inUse = s.skinWorn(d.slot) == d.id;
    final (chip, chipText, edge) = _tierColors(d);
    final price = s.skinPrice(d);
    final missing = s.skinShortfall(d);
    final Widget action;
    if (inUse) {
      action = Opacity(
        opacity: 0.5,
        child: Text(
          cat.ui('skin.inUse'),
          style: AppText.body(size: 11, weight: 800),
        ),
      );
    } else if (owned) {
      action = SkinButton(
        key: Key('decorate-use-${d.id}'),
        label: cat.ui('skin.use'),
        kind: SkinButtonKind.secondary,
        height: 26,
        fontSize: 12,
        onPressed: onPreview,
      );
    } else if (d.isEvent) {
      action = Text(
        cat.ui('skin.event'),
        maxLines: 1,
        style: AppText.body(
          size: 10,
          weight: 800,
          color: const Color(0xFFC46BB8),
        ),
      );
    } else {
      action = CurrencyButton(
        key: Key('decorate-price-${d.id}'),
        phaLe: price.phaLe,
        priceText: coinLabel(price.amount),
        enabled: missing == 0,
        height: 26,
        fontSize: 12,
        onTap: onPreview,
        onBlocked: (context) => showGameToast(
          context,
          cat.ui('skin.missing', {
            'n': coinFull(missing),
            'donVi': price.phaLe ? 'Pha lê' : 'xu',
          }),
        ),
      );
    }
    return GestureDetector(
      onTap: onPreview,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inUse ? AppColors.primaryBase : edge,
            width: inUse ? 3 : (d.tier == 'thuong' ? 1.5 : 2),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 20, 6, 4),
                child: Column(
                  children: [
                    SizedBox(
                      width: 88,
                      height: 44,
                      child: Opacity(
                        opacity: d.isEvent && !owned ? 0.6 : 1,
                        child: Image.asset(
                          d.asset,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 11, weight: 700),
                    ),
                    const Spacer(),
                    SizedBox(height: 26, child: Center(child: action)),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chip,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  d.isDefault
                      ? cat.ui('skin.default')
                      : cat.ui('tier.${d.tier}'),
                  style: AppText.title(size: 10, weight: 800, color: chipText),
                ),
              ),
            ),
            if (!owned)
              const Positioned(
                right: 4,
                top: 4,
                child: Icon(Icons.lock, size: 16, color: Color(0xFF8A7A5A)),
              ),
            if (inUse)
              const Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.check_circle,
                  size: 16,
                  color: AppColors.primaryBase,
                ),
              ),
            if (previewing)
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _DashPainter()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Mua {n} món": each previewed item with its price, then one total line
/// per currency (xu and Pha lê apart).
class _BuyPopup extends StatelessWidget {
  const _BuyPopup({
    required this.session,
    required this.items,
    required this.busy,
    required this.onBuy,
    required this.onClose,
  });

  final ShopSession session;
  final List<SkinDef> items;
  final bool busy;
  final VoidCallback onBuy, onClose;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final cat = s.skins;
    var xu = 0, phaLe = 0;
    for (final d in items) {
      final p = s.skinPrice(d);
      if (p.phaLe) {
        phaLe += p.amount;
      } else {
        xu += p.amount;
      }
    }
    final enough = s.state.money >= xu && s.state.phaLe >= phaLe;
    final style = AppText.body(size: 13, weight: 800);
    return _Ask(
      keyName: 'decorate-buy',
      title: cat.ui('skin.buyN', {'n': items.length}),
      yes: cat.ui('skin.confirm.yes'),
      no: cat.ui('skin.confirm.no'),
      yesEnabled: enough && !busy,
      onYes: onBuy,
      onNo: onClose,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final d in items)
            Row(
              children: [
                Expanded(child: Text(d.name, maxLines: 1, style: style)),
                Text(
                  priceUnit(s.skinPrice(d).amount, phaLe: s.skinPrice(d).phaLe),
                  style: style,
                ),
              ],
            ),
          const Divider(),
          if (xu > 0)
            Text(
              priceUnit(xu),
              key: const Key('decorate-buy-xu'),
              textAlign: TextAlign.end,
              style: style,
            ),
          if (phaLe > 0)
            Text(
              priceUnit(phaLe, phaLe: true),
              key: const Key('decorate-buy-phale'),
              textAlign: TextAlign.end,
              style: style,
            ),
          const SizedBox(height: 6),
          Text(
            cat.ui('skin.cosmetic'),
            textAlign: TextAlign.center,
            style: AppText.body(size: 11, weight: 700),
          ),
        ],
      ),
    );
  }
}

class _Ask extends StatelessWidget {
  const _Ask({
    required this.keyName,
    required this.title,
    required this.yes,
    required this.no,
    required this.onYes,
    required this.onNo,
    this.body,
    this.yesEnabled = true,
  });

  final String keyName, title, yes, no;
  final VoidCallback onYes, onNo;
  final Widget? body;
  final bool yesEnabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onNo,
      child: ColoredBox(
        color: AppColors.bgOverlay,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: SizedBox(
              key: Key(keyName),
              width: 320,
              child: SkinPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppText.title(size: 20, weight: 800),
                    ),
                    if (body != null) ...[const SizedBox(height: 10), body!],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SkinButton(
                            key: Key('$keyName-no'),
                            label: no,
                            kind: SkinButtonKind.secondary,
                            height: 44,
                            fontSize: 16,
                            onPressed: onNo,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SkinButton(
                            key: Key('$keyName-yes'),
                            label: yes,
                            height: 44,
                            fontSize: 16,
                            enabled: yesEnabled,
                            onPressed: onYes,
                          ),
                        ),
                      ],
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
