import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../audio/bgm.dart';
import '../game/shop_game.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'bouquet_table_screen.dart';
import 'donors_screen.dart';
import 'main_shop_overlay.dart';
import 'market_screen.dart';
import 'preorder_screen.dart';
import 'popups.dart';
import 'reviews_screen.dart';
import 'shop_name_popup.dart';
import 'summary_screen.dart';
import 'title_screen.dart';
import 'tutorial_overlay.dart';
import 'upgrades_screen.dart';

/// Fixed 360×640 logical frame, scaled uniformly and letterboxed.
class GameFrame extends StatelessWidget {
  const GameFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgBase,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: AppSize.frameWidth,
            height: AppSize.frameHeight,
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}

/// Flame canvas (always mounted so the clock keeps running) plus the
/// Flutter screen for [ShopSession.screen] on top, then the tutorial
/// spotlight and popups.
class GameRoot extends StatefulWidget {
  const GameRoot({super.key, required this.session, required this.game});

  final ShopSession session;
  final ShopGame game;

  @override
  State<GameRoot> createState() => _GameRootState();
}

class _GameRootState extends State<GameRoot> {
  late final AppLifecycleListener _lifecycle;
  final _bgm = Bgm();
  bool? _musicApplied;
  var _musicUnlocked = false;

  @override
  void initState() {
    super.initState();
    // Hidden browser tab or app in background: pause (spec §1).
    _lifecycle = AppLifecycleListener(
      onHide: widget.session.autoPause,
      onInactive: widget.session.autoPause,
    );
    widget.session.addListener(_onSession);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _bgm.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  void _onSession() {
    final on = widget.session.state.musicOn;
    if (on == _musicApplied) return;
    _musicApplied = on;
    if (_musicUnlocked) _bgm.sync(on);
  }

  /// Browsers block autoplay until the first gesture.
  void _unlockMusic() {
    if (_musicUnlocked) return;
    _musicUnlocked = true;
    _bgm.unlock();
    _musicApplied = widget.session.state.musicOn;
    _bgm.sync(_musicApplied!);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _unlockMusic(),
      child: GameFrame(
        child: ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            final screen = session.screen;
            return Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: screen != Screen.shop,
                    child: GameWidget<ShopGame>(game: widget.game),
                  ),
                ),
                if (screen == Screen.shop)
                  Positioned.fill(child: MainShopOverlay(session: session)),
                if (screen == Screen.table)
                  Positioned.fill(child: BouquetTableScreen(session: session)),
                if (screen == Screen.reviews)
                  Positioned.fill(child: ReviewsScreen(session: session)),
                if (screen == Screen.market)
                  Positioned.fill(child: MarketScreen(session: session)),
                if (screen == Screen.preorders)
                  Positioned.fill(child: PreorderScreen(session: session)),
                if (screen == Screen.summary)
                  Positioned.fill(child: SummaryScreen(session: session)),
                if (screen == Screen.upgrades)
                  Positioned.fill(child: UpgradesScreen(session: session)),
                if (screen == Screen.title)
                  Positioned.fill(child: TitleScreen(session: session)),
                if (screen == Screen.donors)
                  Positioned.fill(child: DonorsScreen(session: session)),
                if (session.tutorialActive &&
                    screen != Screen.title &&
                    screen != Screen.donors)
                  Positioned.fill(child: TutorialOverlay(session: session)),
                if (screen != Screen.donors &&
                    (screen != Screen.title || session.pauseMenuOpen))
                  Positioned.fill(child: PopupLayer(session: session)),
                if (session.tutorialViewStep > 0)
                  Positioned.fill(child: TutorialViewer(session: session)),
                if (session.namePrompt != null)
                  Positioned.fill(child: ShopNamePopup(session: session)),
              ],
            );
          },
        ),
      ),
    );
  }
}
