import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../game/shop_game.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'bouquet_table_screen.dart';
import 'donors_screen.dart';
import 'frame_metrics.dart';
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

/// Fixed 360×640 logical frame.
///
/// Width ≤ 480 fills the window (letterboxed on [AppColors.bgBase]). Wider
/// windows put a 390-wide box in the middle, on [AppColors.backdropBase].
class GameFrame extends StatelessWidget {
  const GameFrame({super.key, required this.child});

  final Widget child;

  static const _desktopWidth = 390.0;
  static const _desktopMaxHeight = 844.0;
  static const _desktopMargin = 32.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        if (!maxW.isFinite || !maxH.isFinite || maxW <= 480) {
          return _phone(context, maxW, maxH);
        }
        return _desktop(context, maxH);
      },
    );
  }

  Widget _phone(BuildContext context, double maxW, double maxH) {
    final scale = _fitScale(maxW, maxH);
    final frameTop = (maxH - AppSize.frameHeight * scale) / 2;
    return ColoredBox(
      color: AppColors.bgBase,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: AppSize.frameWidth,
            height: AppSize.frameHeight,
            child: FrameMetrics(
              scale: scale,
              topInset: _topInset(context, scale, frameTop),
              bottomGap: 0,
              child: ClipRect(child: child),
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktop(BuildContext context, double maxH) {
    final aspect = AppSize.frameHeight / AppSize.frameWidth;
    var boxW = _desktopWidth;
    var boxH = boxW * aspect;
    if (boxH > _desktopMaxHeight) {
      boxH = _desktopMaxHeight;
      boxW = boxH / aspect;
    }
    final availH = math.max(0.0, maxH - _desktopMargin * 2);
    if (boxH > availH && boxH > 0) {
      final s = availH / boxH;
      boxW *= s;
      boxH *= s;
    }
    final scale = boxW / AppSize.frameWidth;
    final frameTop = (maxH - boxH) / 2;
    return ColoredBox(
      color: AppColors.backdropBase,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _BlurredShopBackdrop(),
          Center(
            child: Container(
              width: boxW,
              height: boxH,
              decoration: BoxDecoration(
                color: AppColors.bgBase,
                borderRadius: BorderRadius.circular(AppRadius.lg + 4),
                // design_tokens shadow.popup (#2E3A2C33 is RRGGBBAA).
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.popupShadow,
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg + 4),
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: AppSize.frameWidth,
                    height: AppSize.frameHeight,
                    child: FrameMetrics(
                      scale: scale,
                      topInset: _topInset(context, scale, frameTop),
                      bottomGap: frameTop,
                      child: ClipRect(child: child),
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

  double _fitScale(double maxW, double maxH) {
    if (!maxW.isFinite || !maxH.isFinite || maxW <= 0 || maxH <= 0) return 1;
    return math.min(maxW / AppSize.frameWidth, maxH / AppSize.frameHeight);
  }

  /// Safe-area pixels that actually cover the frame, in logical pixels.
  double _topInset(BuildContext context, double scale, double frameTop) {
    if (scale <= 0) return 0;
    final overlap = math.max(0.0, MediaQuery.paddingOf(context).top - frameTop);
    return overlap / scale;
  }
}

/// `shop_bg.png` blurred behind the desktop box (about 18px, 35% opacity).
class _BlurredShopBackdrop extends StatelessWidget {
  const _BlurredShopBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.35,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: 18,
            sigmaY: 18,
            tileMode: TileMode.clamp,
          ),
          child: SizedBox.expand(
            child: Image.asset(
              Art.scene('shop_bg'),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
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
    widget.session.sounds.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  void _onSession() => _applyAudio();

  /// Browsers block autoplay until the first gesture.
  void _unlockMusic() {
    if (_musicUnlocked) return;
    _musicUnlocked = true;
    widget.session.sounds.unlock();
    _applyAudio();
  }

  void _applyAudio() {
    final session = widget.session;
    final sounds = session.sounds;
    sounds.musicOn = session.state.musicOn;
    sounds.effectsOn = session.state.sfxOn;
    if (!_musicUnlocked) return;
    sounds.playMusic(session.musicTrack);
    sounds.setAmbience(session.playShopAmbience);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _unlockMusic(),
      child: SoundScope(
        sounds: session.sounds,
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
                    Positioned.fill(
                      child: BouquetTableScreen(session: session),
                    ),
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
      ),
    );
  }
}
