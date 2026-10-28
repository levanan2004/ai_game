import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../data/skins.dart';
import '../logic/goals.dart';
import '../logic/pot_slots.dart' show displayShelfPlank;
import '../logic/shop_session.dart';
import '../logic/shop_shelf.dart';
import '../save/game_state.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'charm_board_screen.dart';
import 'common.dart';
import 'frame_metrics.dart';
import 'free_reward_card.dart';
import 'gacha_entry.dart';
import 'hoa_sap_heo_view.dart';
import 'delivery_widgets.dart';
import 'map_popup.dart';
import 'pet_shop_screen.dart';
import 'pet_slots_screen.dart';
import 'pot_place_mode.dart';
import 'pot_popup.dart';
import 'pot_shop_hint.dart';
import 'shop_shelf_layer.dart';
import 'so_tay_screen.dart' show NotebookButton, mapNotebookRow;
import 'tutorial_overlay.dart';
import 'world_chat_text.dart';
import 'world_chat_ticker.dart';

/// Right icon column (Phú): 8 dp under the ticker; the icon circle 12 dp
/// from the right edge (the 60 dp icon cell has 6 dp either side of its
/// 48 dp circle); icons 12 dp apart.
const rightColumnGap = 8.0;
const rightColumnRight = 12.0 - (GachaEntryIcon.width - 48) / 2;

/// Hoa sắp héo spots (Phú).
const driedShelfRight = rightColumnRight + GachaEntryIcon.width + 8;
const clearanceBasketTop = 232.0 - 8 - 56;

/// Vòng quay icon (Phu 26/10, round 6): off the pot shelf, just under the
/// stand pots' 6 dp plank, 2 dp below it (round 7; frame y 256..304,
/// 8 dp above the Muc tieu card at 312).
final double gachaBelowShelfTop =
    ShelfGeometry.sceneOffset + displayShelfPlank.top + 8;

/// Bottom-right of the scene (An 26/10, fix 10): Vong quay stands on the
/// counter ledge, in the clock and pet row; Trang tri 8 dp above it,
/// centred on the wheel's vertical axis. Trang tri art 40 dp (56 less 30%,
/// An 26/10) in a 48 dp tap target.
const double cornerButtonSize = 48;
const double brushArtSize = 40;
const double brushTop =
    gachaCornerTop - 8 - (cornerButtonSize + brushArtSize) / 2;
const double gachaCornerTop = ShelfGeometry.ledgeTop - GachaEntryIcon.height;
// The wheel circle's centre is 28 dp in from its cell's right edge; the
// brush's 48 dp box is centred there too, so both share one axis.
const double cornerButtonRight = rightColumnRight + 28 - cornerButtonSize / 2;

/// Same-Day card under the top bar (spec_giao_hang v0.2 §4), before the
/// Tin thế giới push.
const sameDayTop = 60.0;
const sameDayHeight = 76.0;

/// Sổ tay button top: (12,56), or 8dp under the Same-Day card while one
/// is offered (Phú).
/// So tay button: 44 dp, 8 dp from the left edge and 8 dp under the top
/// bar (Phu).
const double notebookButtonLeft = 8;

/// Ticker left edge while the So tay button shows: its right (52) + 8.
const double notebookTickerLeft = 60;

/// Shop sign board on the scene (ShopScene._drawShopSign): y 60, 28 high,
/// at most 184 wide and centred, so its right edge is at most x 272.
const double shopSignBottom = 60 + 28;
const double shopSignMaxRight = (360 + 184) / 2;

/// Top of the Tin the gioi ticker: its own strip 4 dp under the shop sign.
double worldChatTickerTop(ShopSession s, BuildContext context) {
  final guest = !s.signedIn && s.showGuestBanner ? 48.0 : 0.0;
  return shopSignBottom +
      (FrameMetrics.maybeOf(context)?.topInset ?? 0) +
      guest +
      4;
}

double notebookButtonTop(ShopSession s) {
  if (s.incomingSameDay == null) return 56;
  final push = WorldChatTicker.on(s) ? WorldChatTicker.push : 0.0;
  return sameDayTop + push + sameDayHeight + 8;
}

/// Widgets drawn over the Flame shop scene (spec_tiem_chinh.md): top bar,
/// daily goals card, main button + hint, bottom navigation.
class MainShopOverlay extends StatefulWidget {
  const MainShopOverlay({
    super.key,
    required this.session,
    this.sheets = const [],
    this.sheetOpen,
  });

  final ShopSession session;

  /// Hộp thư / Phúc lợi (game_root): the chat ticker hides while one is open.
  final List<Listenable> sheets;
  final bool Function()? sheetOpen;

  @override
  State<MainShopOverlay> createState() => _MainShopOverlayState();
}

class _MainShopOverlayState extends State<MainShopOverlay> {
  bool _goalsOpen = false;
  bool _confirmEnd = false;
  bool _mapOpen = false;

  /// The one-time Tiệm Chậu Hoa hint box is on screen.
  bool _potHintOpen = false;
  bool _basketOpen = false;
  bool _shelfOpen = false;

  ShopSession get session => widget.session;

  /// Under the bar (56 + the top inset) and the guest strip when it shows.
  void _closeMap() {
    session.sounds.effect('popup_close');
    setState(() => _mapOpen = false);
  }

  /// Top of the right icon column: under the ticker while it shows.
  double _rightColumnTop(BuildContext context) => WorldChatTicker.on(session)
      ? _tickerTop(context) + WorldChatTicker.height + rightColumnGap
      : _tickerTop(context) - shopSignBottom + 56;

  /// 8dp off the Vòng quay icon; when the guest banner or the chat ticker
  /// pushes it down onto the basket, 8dp left of the basket instead (Phú),
  /// sliding there and back in 200 ms easeOut.
  double _shelfRight(BuildContext context) {
    final bottom =
        _rightColumnTop(context) +
        DriedShelf.size.height +
        (session.state.drying.isEmpty ? 0 : DriedShelf.labelHeight);
    if (ClearanceBasket.visible(session) && bottom > clearanceBasketTop) {
      return 8 + ClearanceBasket.size.width + 8;
    }
    return driedShelfRight;
  }

  double _tickerTop(BuildContext context) =>
      worldChatTickerTop(session, context);

  /// What sits under the bar (left 12, 336 wide) moves down
  /// [WorldChatTicker.push] while the ticker takes the room.
  Widget _underTicker({
    required double top,
    double? height,
    required Widget child,
  }) {
    final s = session;
    return ListenableBuilder(
      listenable: s.chat,
      builder: (context, child) {
        final push = WorldChatTicker.on(s) ? WorldChatTicker.push : 0.0;
        return Positioned(
          left: 12,
          width: 336,
          top: top + push,
          height: height,
          child: child!,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    final placing = s.placeModeActive;
    if (!_potHintOpen && s.potHintBoxDue) {
      // Shown once: the flag goes on as soon as the box appears.
      _potHintOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        s.markPotHintShown();
      });
    }
    final strip = s.hasOnlineStrip;
    final teaser = s.showShipperTeaser;
    final goalsTop = ShelfGeometry.goalsCardTop(strip);
    final goalsOpen = strip && _goalsOpen;
    final goalsHeight = !strip ? 92.0 : (goalsOpen ? 92.0 : 40.0);
    var buttonTop = _shelfEmptyOpen ? 450.0 : 420.0;
    var bannerTop = 408.0;
    if (strip || teaser) {
      var cursor = goalsTop + goalsHeight + 8;
      if (teaser) {
        cursor += 56 + 8;
      }
      if (_shelfEmptyOpen) {
        bannerTop = cursor;
        buttonTop = cursor + 42;
      } else {
        buttonTop = cursor;
      }
    }
    // Tall phones (An 26/10): the stage grows by [extra] under the 640
    // frame; the cards stay right under the scene and the bottom nav goes
    // to the screen bottom, so the extra room is above the nav only.
    final extra = FrameMetrics.maybeOf(context)?.stageGapBottom ?? 0.0;
    // Tin the gioi ticker (An 26/10): under the scene, above the goals
    // card, clear of the shop sign and the bucket row; 2 dp above and below.
    // Its room is kept while the strip is hidden, like the strip itself.
    final ticker = s.chat.offered && !placing;
    // 2 dp gaps: with the shipper teaser the Mo cua button still ends
    // above the bottom nav on a 640 screen.
    final tickerTop = goalsTop + 2;
    final shift = ticker ? WorldChatTicker.height + 4 : 0.0;
    final hintTop = buttonTop + 60;
    final showHint = hintTop + shift < 548 && !_shelfEmptyOpen;
    final brush =
        !placing && !s.tutorialActive && s.state.phase != DayPhase.open;
    final gachaColumn = s.gacha.offered && !placing && !s.tutorialActive;
    return SizedBox(
      width: 360,
      height: 640 + extra,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: TopBar(
              session: s,
              showPause: false,
              noticeSlot: true,
              showDay: false,
              showPhaLe: true,
              onStarTap: s.openReviews,
            ),
          ),
          if (s.eventStatus != null)
            _underTicker(
              top: 52,
              child: Text(
                s.eventStatus!,
                key: const Key('event-status'),
                textAlign: TextAlign.center,
                style: AppText.caption(size: 12, weight: 800),
              ),
            ),
          Positioned.fill(child: ShopShelfLayer(session: s)),
          // Hoa sắp héo (Phú): shelf 8dp left of the Vòng quay icon,
          // basket bottom 8dp above the shipper dock (top 232).
          if (dryingActive(s))
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              right: _shelfRight(context),
              top: _rightColumnTop(context),
              child: DriedShelf(
                session: s,
                onTap: () => setState(() => _shelfOpen = true),
              ),
            ),
          if (ClearanceBasket.visible(s))
            Positioned(
              right: 8,
              top: clearanceBasketTop,
              child: ClearanceBasket(
                session: s,
                onTap: () => setState(() => _basketOpen = true),
              ),
            ),
          if (s.shipperRuns.isNotEmpty) ...[
            Positioned.fill(child: ShipperTravel(session: s)),
            Positioned(
              right: _dockRight,
              top: 232,
              child: ShipperDock(session: s),
            ),
          ],
          if (strip)
            Positioned(
              left: 0,
              top: 300,
              width: 360,
              height: 64,
              child: OnlineOrderStrip(session: s),
            ),
          if (!placing)
            Positioned(
              left: 12,
              top: goalsTop + shift,
              width: 336,
              height: goalsHeight,
              child: GoalsCard(
                session: s,
                collapsed: strip && !_goalsOpen,
                onExpand: () => setState(() => _goalsOpen = true),
              ),
            ),
          if (teaser && !placing)
            Positioned(
              left: 12,
              top: goalsTop + goalsHeight + 8 + shift,
              width: 336,
              height: 56,
              child: ShipperTeaser(session: s),
            ),
          if (_shelfEmptyOpen && !placing)
            Positioned(
              left: 12,
              top: bannerTop + shift,
              width: 336,
              height: 34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    'Hết hoa rồi, mai nhớ nhập thêm nhé',
                    key: const Key('empty-shelf-banner'),
                    style: AppText.caption(
                      size: 11,
                      weight: 800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          if (!placing)
            Positioned(
              left: 12,
              top: buttonTop + shift,
              width: 336,
              height: 56,
              child: _mainButton(),
            ),
          if (showHint && !placing)
            Positioned(
              left: 12,
              right: 12,
              top: hintTop + shift,
              child: _hintLine(),
            ),
          if (!placing)
            Positioned(
              left: 0,
              top: 560 + extra,
              width: 360,
              height: 80,
              child: ListenableBuilder(
                listenable: s.chat,
                builder: (context, _) => BottomNav(
                  session: s,
                  mapOpen: _mapOpen,
                  onMap: () {
                    s.sounds.effect('popup_open');
                    setState(() => _mapOpen = true);
                  },
                ),
              ),
            ),
          if (placing)
            Positioned.fill(
              child: PlaceModeLayer(session: s, bannerTop: goalsTop),
            ),
          _underTicker(
            top: sameDayTop,
            height: sameDayHeight,
            child: SameDaySlot(session: s),
          ),
          // Sổ tay khách quen (spec §1b), under the top bar once open.
          // Pushed under the Same-Day card while it shows (Phú).
          // Tin thế giới ticker (Phú), right under the xu/Pha lê bar.
          if (s.chat.offered && !placing)
            Positioned(
              left: WorldChatTicker.margin,
              right: WorldChatTicker.margin,
              top: tickerTop,
              height: WorldChatTicker.height,
              child: WorldChatTicker(
                session: s,
                sheets: widget.sheets,
                sheetOpen: widget.sheetOpen,
                popupOpen: _confirmEnd || _mapOpen || _potHintOpen,
              ),
            ),
          // Right icon column (Phú): 8 dp under the Tin thế giới ticker,
          // 12 dp from the right edge; more icons stack downward 12 dp
          // apart. Hộp thư / Phúc lợi / Tin thế giới / Cài đặt in the basket.
          if (gachaColumn)
            ListenableBuilder(
              listenable: s.chat,
              builder: (context, child) => Positioned(
                right: s.state.gachaIconHidden ? 8 : rightColumnRight,
                top: gachaCornerTop,
                child: child!,
              ),
              child: Column(
                key: const Key('right-icon-column'),
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (s.state.gachaIconHidden)
                    GachaShowButton(onShow: () => s.setGachaIconHidden(false))
                  else
                    // No hide chip on the shop (An 26/10); the red dot is
                    // the real "card / new week" badge, on its corner.
                    GachaEntryIcon(gacha: s.gacha),
                ],
              ),
            ),
          // Trang tri: 56 dp, bottom-right, 8 dp above the Vong quay cell.
          if (brush)
            Positioned(
              right: cornerButtonRight,
              top: brushTop,
              child: _BrushButton(onTap: () => s.openDecorate(skinGroupShop)),
            ),
          // Reopen the closed ticker: right of the shop sign, centred on it.
          if (!placing)
            ListenableBuilder(
              listenable: s.chat,
              builder: (context, _) => WorldChatReopenButton.on(s)
                  ? Positioned(
                      left: shopSignMaxRight + 4,
                      top: 60 + 14 - WorldChatReopenButton.hit / 2,
                      child: WorldChatReopenButton(session: s),
                    )
                  : const SizedBox.shrink(),
            ),
          // The notebook button stays above the scene's other widgets
          // (ticker, icon columns); popups still cover it (Phu).
          if (s.notebookUnlocked && !placing)
            ListenableBuilder(
              listenable: s.chat,
              builder: (context, child) => AnimatedPositioned(
                key: const Key('notebook-button-slot'),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                left: notebookButtonLeft,
                top: notebookButtonTop(s),
                child: child!,
              ),
              child: NotebookButton(session: s),
            ),
          if (_basketOpen)
            Positioned.fill(
              child: ClearanceSheet(
                session: s,
                onClose: () => setState(() => _basketOpen = false),
              ),
            ),
          if (_shelfOpen)
            Positioned.fill(
              child: DriedShelfSheet(
                session: s,
                onClose: () => setState(() => _shelfOpen = false),
              ),
            ),
          if (_confirmEnd) _endDayDialog(),
          if (_mapOpen)
            MapPopup(
              session: s,
              onClose: _closeMap,
              extraRows: [
                mapNotebookRow(context, s, _closeMap),
                mapDecorateRow(context, s, _closeMap),
              ],
            ),
          if (s.potPickerOpen) Positioned.fill(child: PotPopup(session: s)),
          if (_potHintOpen && !placing)
            Positioned.fill(
              child: PotShopHintBox(
                session: s,
                onClose: () => setState(() => _potHintOpen = false),
              ),
            ),
          if (s.petSlotsOpen)
            Positioned.fill(child: PetSlotsScreen(session: s)),
          if (s.charmBoardOpen)
            Positioned.fill(child: CharmBoardScreen(session: s)),
          if (s.petCatalogOpen)
            Positioned.fill(child: PetCatalogPopup(session: s)),
          if (s.shopNotice != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 88,
              child: IgnorePointer(
                child: Center(
                  child:
                      rewardedShopNotice(s.shopNotice!) ??
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Text(
                            s.shopNotice!,
                            key: const Key('shop-notice'),
                            textAlign: TextAlign.center,
                            style: AppText.caption(
                              size: 12,
                              weight: 800,
                              color: AppColors.textInverse,
                            ),
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

  /// The shipper dock stands on the ledge's right end, where the pet sits;
  /// with a pet along it moves left to end 4 px before the pet.
  double get _dockRight {
    final pet = shelfPet(session.state);
    if (pet == null) return 8;
    return ShelfGeometry.sceneRight - ShelfGeometry.petRect(pet).left - 4;
  }

  bool get _shelfEmptyOpen =>
      session.state.phase == DayPhase.open && session.shelfEmpty;

  Widget _mainButton() {
    final s = session;
    switch (s.state.phase) {
      case DayPhase.preparing:
        return KeyedSubtree(
          key: TutorialTargets.openButton,
          child: ChunkyButton(
            key: const Key('main-button'),
            label: 'Mở cửa',
            height: 52,
            fontSize: 18,
            onPressed: s.openShop,
          ),
        );
      case DayPhase.open:
        if (s.shelfEmpty) {
          final blocked = s.mustPlayUntilClose;
          return ChunkyButton(
            key: const Key('close-early'),
            label: 'Kết thúc ngày',
            kind: ButtonKind.ghost,
            height: 52,
            fontSize: 18,
            enabled: !blocked,
            disabledHint: blocked ? ShopSession.playUntilCloseHint : null,
            onPressed: blocked ? null : _askToEndDay,
          );
        }
        final c = s.nextForPlayer;
        if (c == null) {
          return const ChunkyButton(
            key: Key('main-button'),
            label: 'Đang chờ khách...',
            kind: ButtonKind.ghost,
            height: 52,
            fontSize: 18,
            enabled: false,
            onPressed: null,
            disabledHint: 'Chưa có khách, đợi chút nhé',
          );
        }
        return ChunkyButton(
          key: const Key('main-button'),
          label: 'Bó hoa cho ${c.name}',
          height: 52,
          fontSize: 18,
          onPressed: s.openTable,
        );
      case DayPhase.market:
      case DayPhase.summary:
        return const SizedBox.shrink();
    }
  }

  Widget _hintLine() {
    final s = session;
    if (s.state.phase == DayPhase.preparing) {
      final low = s.unlockedFlowers.any((f) => s.stockCount(f.id) == 0);
      if (low) {
        return GestureDetector(
          key: const Key('go-market'),
          behavior: HitTestBehavior.opaque,
          onTap: s.backToMarket,
          child: Text(
            'Ghé chợ hoa ›',
            textAlign: TextAlign.center,
            style: AppText.caption(
              size: 11,
              weight: 800,
              color: AppColors.primaryPressed,
            ),
          ),
        );
      }
    }
    final hint = s.state.phase == DayPhase.open && s.nextForPlayer != null
        ? 'Chạm khách đầu hàng hoặc bấm nút để bó'
        : '';
    final canEnd = s.state.phase == DayPhase.open && s.tutorialStep == 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hint.isNotEmpty)
          Flexible(
            child: Text(
              hint,
              key: const Key('shop-hint'),
              textAlign: TextAlign.center,
              style: AppText.caption(size: 11, weight: 700),
            ),
          ),
        if (canEnd) ...[
          if (hint.isNotEmpty) const SizedBox(width: 8),
          GestureDetector(
            key: const Key('end-day'),
            behavior: HitTestBehavior.opaque,
            onTap: _askToEndDay,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'Kết thúc ngày',
                style: AppText.caption(
                  size: 11,
                  weight: 800,
                  color: AppColors.primaryPressed,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _askToEndDay() {
    final s = session;
    if (s.mustPlayUntilClose) {
      showTapHint(context, ShopSession.playUntilCloseHint);
      return;
    }
    s.sounds.effect('popup_open');
    setState(() => _confirmEnd = true);
  }

  Widget _endDayDialog() {
    final s = session;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          s.sounds.effect('popup_close');
          setState(() => _confirmEnd = false);
        },
        child: ColoredBox(
          color: AppColors.bgOverlay,
          child: Stack(
            children: [
              Positioned(
                left: 32,
                top: 220,
                width: 296,
                height: 196,
                child: GestureDetector(
                  onTap: () {},
                  child: CardBox(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    child: Column(
                      children: [
                        Text(
                          'Đóng cửa và sang tổng kết? Khách đang chờ sẽ về, không bị trừ sao. Sáng mai mới mua được hoa.',
                          key: const Key('end-day-confirm'),
                          textAlign: TextAlign.center,
                          style: AppText.body(size: 14, weight: 800),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ChunkyButton(
                                  key: const Key('end-day-no'),
                                  label: 'Ở lại',
                                  kind: ButtonKind.ghost,
                                  fontSize: 15,
                                  onPressed: () {
                                    s.sounds.effect('popup_close');
                                    setState(() => _confirmEnd = false);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ChunkyButton(
                                  key: const Key('end-day-yes'),
                                  label: 'Kết thúc',
                                  fontSize: 15,
                                  onPressed: () {
                                    setState(() => _confirmEnd = false);
                                    s.closeEarly();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Mục tiêu hôm nay" card.
class GoalsCard extends StatelessWidget {
  const GoalsCard({
    super.key,
    required this.session,
    this.collapsed = false,
    this.onExpand,
  });

  final ShopSession session;
  final bool collapsed;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final m = session.state.metrics;
    final goals = session.state.goals.take(3).toList();
    final done = goals.where((g) => g.isDone(m)).length;
    if (collapsed) {
      return GestureDetector(
        key: const Key('goals-collapsed'),
        onTap: onExpand,
        child: CardBox(
          radius: 16,
          borderWidth: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mục tiêu $done/${goals.length} ›',
                style: AppText.title(size: 15, weight: 800),
              ),
            ),
          ),
        ),
      );
    }
    return CardBox(
      radius: 16,
      borderWidth: 1,
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 6,
            child: Text(
              'Mục tiêu hôm nay',
              style: AppText.title(size: 15, weight: 800),
            ),
          ),
          for (var i = 0; i < goals.length; i++)
            Positioned(
              left: 12,
              right: 12,
              top: 38 - 9 + i * 18.0,
              height: 18,
              child: _GoalRow(goal: goals[i], metrics: m),
            ),
        ],
      ),
    );
  }
}

/// One goal line. A reached goal is a green dot with a white check stroke.
/// Limit goals ("không quá", "không để quá") keep that check while they hold,
/// and switch to × once they are broken.
class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, required this.metrics});

  final DailyGoal goal;
  final DayMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final done = goal.isDone(metrics);
    final exceeded = goal.isExceeded(metrics);
    final limit = goal.isLimit;
    final achieved = done && !exceeded;
    final titleColor = exceeded
        ? AppColors.statusDanger
        : (!limit && done)
        ? AppColors.textSecondary
        : AppColors.textPrimary;
    final progressColor = exceeded
        ? AppColors.statusDanger
        : AppColors.textSecondary;
    final fill = achieved ? AppColors.statusSuccess : AppColors.surfaceCard;
    final border = exceeded
        ? AppColors.statusDanger
        : achieved
        ? AppColors.statusSuccess
        : AppColors.surfaceBorderStrong;
    return Row(
      children: [
        AnimatedContainer(
          duration: AppMotion.base,
          curve: Curves.easeOutBack,
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: border, width: AppBorder.thin),
          ),
          child: achieved || exceeded
              ? CustomPaint(
                  painter: _LimitMarkPainter(
                    exceeded: exceeded,
                    color: achieved
                        ? AppColors.textInverse
                        : AppColors.statusDanger,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            goal.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(size: 12, weight: 700, color: titleColor),
          ),
        ),
        Text(
          goal.progressLabel(metrics),
          style: AppText.number(size: 12, color: progressColor),
        ),
      ],
    );
  }
}

class _LimitMarkPainter extends CustomPainter {
  const _LimitMarkPainter({required this.exceeded, required this.color});

  final bool exceeded;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (exceeded) {
      canvas.drawLine(
        Offset(size.width * 0.28, size.height * 0.28),
        Offset(size.width * 0.72, size.height * 0.72),
        p,
      );
      canvas.drawLine(
        Offset(size.width * 0.72, size.height * 0.28),
        Offset(size.width * 0.28, size.height * 0.72),
        p,
      );
    } else {
      final path = Path()
        ..moveTo(size.width * 0.22, size.height * 0.52)
        ..lineTo(size.width * 0.42, size.height * 0.72)
        ..lineTo(size.width * 0.78, size.height * 0.30);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_LimitMarkPainter old) =>
      old.exceeded != exceeded || old.color != color;
}

/// Bottom navigation: Kho hoa, Nâng cấp, Đánh giá, Sổ sách/Bản đồ, Tin thế
/// giới. Chậu hoa is on Bản đồ. Five tabs of 72 dp. "Giá bán" is
/// no longer a tab: it is a button on the counter ledge next to the clock
/// (`PricesLedgeButton`, SPEC_gia_ban_va_bxh_ban_do.md PA2).
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.session,
    required this.onMap,
    this.mapOpen = false,
  });

  final ShopSession session;
  final VoidCallback onMap;
  final bool mapOpen;

  /// 360 / 5 tabs.
  static const tabWidth = 72.0;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final preparing = s.state.phase == DayPhase.preparing;
    // Dim only a tab that cannot be used right now. Tapping it explains why.
    final upgradeBlocked = s.state.phase == DayPhase.open
        ? 'Nâng cấp khi tiệm đóng cửa nhé'
        : null;
    const soon = 'Mục này sắp có nhé';
    // Five tabs, 72 dp each. Tab 4 is Tin thế giới (Chậu hoa is on Bản đồ).
    final chatOffered = s.chat.offered;
    final items = <(String, Color, VoidCallback?, String?, String?, Screen?)>[
      (
        'Kho hoa',
        AppColors.secondaryBase,
        s.openStock,
        'kho_hoa',
        null,
        Screen.stock,
      ),
      (
        'Nâng cấp',
        AppColors.primaryBase,
        s.openUpgradesFromNav,
        'nang_cap',
        upgradeBlocked,
        Screen.upgrades,
      ),
      (
        'Đánh giá',
        AppColors.currencyStar,
        s.openReviews,
        'danh_gia',
        null,
        Screen.reviews,
      ),
      preparing
          ? ('Bản đồ', AppColors.statusInfo, onMap, 'ban_do', null, null)
          : ('Sổ sách', AppColors.statusInfo, null, 'so_sach', soon, null),
      chatOffered
          ? (
              ChatText.title,
              AppColors.primaryBase,
              s.chat.openChat,
              'tin_the_gioi',
              null,
              null,
            )
          : (
              ChatText.title,
              AppColors.primaryBase,
              null,
              'tin_the_gioi',
              'Tin thế giới cần mạng nhé',
              null,
            ),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.navBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Stack(
        children: [
          for (var i = 0; i < items.length; i++)
            Positioned(
              left: i * BottomNav.tabWidth,
              top: 0,
              width: BottomNav.tabWidth,
              height: 80,
              child: _NavButton(
                key: Key('nav-$i'),
                label: items[i].$1,
                color: items[i].$2,
                icon: items[i].$4,
                selected:
                    (i == 4 && chatOffered && s.chat.open) ||
                    (items[i].$6 != null && items[i].$6 == s.screen) ||
                    (mapOpen && preparing && i == 3),
                onTap: items[i].$3,
                disabledHint: items[i].$5,
              ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
    required this.disabledHint,
    required this.selected,
    this.badge = false,
  });

  final String label;
  final Color color;

  /// A red dot at the icon's top right (no number).
  final bool badge;

  /// File name in assets/images/nav, or null for the placeholder.
  final String? icon;
  final VoidCallback? onTap;

  /// Set when the tab cannot be used right now: the tab is dimmed and a tap
  /// explains why instead of opening it.
  final String? disabledHint;
  final bool selected;

  bool get dimmed => disabledHint != null;

  @override
  Widget build(BuildContext context) {
    // Old drawn placeholder: coloured dot in a small tile.
    final placeholder = Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgBase,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: AppColors.surfaceBorder,
            width: AppBorder.thin,
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
    final labelColor = dimmed
        ? AppColors.textDisabled
        : selected
        ? AppColors.navActiveLabel
        : AppColors.navLabel;
    return GestureDetector(
      onTap: disabledHint != null
          ? () => showTapHint(context, disabledHint!)
          : onTap == null
          ? null
          : () {
              SoundScope.maybeOf(context)?.effect('ui_tab');
              onTap!();
            },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          if (selected)
            Positioned(
              left: 8,
              top: 16,
              width: 56,
              height: 32,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.navActivePill,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          // Full-colour icon unless the tab really cannot be used.
          Positioned(
            left: 22,
            top: 18,
            width: 28,
            height: 28,
            child: icon == null
                ? placeholder
                : ArtImage(
                    Art.nav(icon!),
                    size: 28,
                    opacity: dimmed ? 0.45 : 1,
                    fallback: placeholder,
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 52,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: AppText.make(
                  AppFonts.display,
                  11.5,
                  selected ? 800 : 600,
                  height: 1.1,
                  color: labelColor,
                ),
              ),
            ),
          ),
          if (badge)
            Positioned(
              left: 44,
              top: 8,
              width: 16,
              height: 16,
              child: ArtImage(
                Art.menu('cham_do'),
                key: const Key('nav-red-dot'),
                size: 16,
                fallback: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.statusDanger,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The round 40×40 cọ sơn button that opens Tiệm Trang Trí.
class _BrushButton extends StatefulWidget {
  const _BrushButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_BrushButton> createState() => _BrushButtonState();
}

/// Phu's art: `ui/nut_co_ve`, `ui/nut_co_ve_nhan` while pressed.
class _BrushButtonState extends State<_BrushButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('main-decorate'),
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: SizedBox.square(
        dimension: cornerButtonSize,
        child: Center(
          child: Image.asset(
            Art.ui(_down ? 'nut_co_ve_nhan' : 'nut_co_ve'),
            key: Key(_down ? 'main-decorate-down' : 'main-decorate-up'),
            width: brushArtSize,
            height: brushArtSize,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
