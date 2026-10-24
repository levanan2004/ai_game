import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/sounds.dart';
import '../game/shop_game.dart';
import '../logic/charm_rewards.dart';
import '../logic/inbox.dart';
import '../logic/mailbox.dart';
import '../logic/notice_feed.dart';
import '../logic/notice_reply.dart';
import '../logic/photo_uploads.dart';
import '../logic/platform_flags.dart';
import '../logic/rewards.dart';
import '../logic/shop_session.dart';
import '../logic/welfare.dart';
import '../logic/welfare_slides.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'bouquet_table_screen.dart';
import 'corner_menu.dart';
import 'delete_account_dialog.dart';
import 'donors_screen.dart';
import 'event_popup.dart';
import 'gacha_entry.dart';
import 'gacha_screen.dart';
import 'garden_screen.dart';
import 'pet_item_shop.dart';
import 'phale_popups.dart';
import 'phale_shop_screen.dart';
import 'rewarded_ad_sheet.dart';
import 'pet_screen.dart';
import 'pet_shop_screen.dart';
import 'pot_book_screen.dart';
import 'pot_shop_screen.dart';
import 'phuc_loi_art.dart';
import 'frame_metrics.dart';
import 'mailbox_sheet.dart';
import 'main_shop_overlay.dart';
import 'market_screen.dart';
import 'notice_sheet.dart';
import 'open_url.dart';
import 'preorder_screen.dart';
import 'price_screen.dart';
import 'popups.dart';
import 'reviews_screen.dart';
import 'save_status.dart';
import 'sign_in_chooser.dart';
import 'seat_popup.dart';
import 'shop_name_popup.dart';
import 'stock_screen.dart';
import 'summary_screen.dart';
import 'terms_screen.dart';
import 'title_screen.dart';
import 'tutorial_overlay.dart';
import 'upgrades_screen.dart';
import 'welfare_sheet.dart';
import 'avatar_frame_sheet.dart';
import 'vip_screen.dart';
import 'world_chat_sheet.dart';

/// Fixed 360-wide logical frame.
///
/// A phone (width ≤ 480) scales that width to the window. A taller phone
/// grows the logical height to the same aspect, so the green header and the
/// footer meet the screen edges instead of leaving cream bands. A short
/// window keeps the 640 frame and letterboxes. Wider windows put a 390-wide
/// box in the middle, on [AppColors.backdropBase].
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
    final width = maxW.isFinite && maxW > 0 ? maxW : AppSize.frameWidth;
    final height = maxH.isFinite && maxH > 0 ? maxH : AppSize.frameHeight;
    final scale = width / AppSize.frameWidth;
    final fittedH = AppSize.frameHeight * scale;
    // Shorter than the 640 frame: the old letterbox, so the art is not squashed.
    if (scale <= 0 || fittedH >= height - 0.5) {
      return _phoneLetterbox(context, width, height);
    }
    final frameH = height / scale;
    final gapTop = (frameH - AppSize.frameHeight) / 2;
    final pad = MediaQuery.viewPaddingOf(context);
    final stageTopPx = gapTop * scale;
    return ColoredBox(
      color: AppColors.bgBase,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: AppSize.frameWidth,
            height: frameH,
            child: FrameMetrics(
              scale: scale,
              topInset: _topInset(context, scale, stageTopPx),
              bottomGap: 0,
              stageGapTop: gapTop,
              stageGapBottom: frameH - AppSize.frameHeight - gapTop,
              edgeTop: pad.top / scale,
              edgeBottom: pad.bottom / scale,
              child: ClipRect(child: child),
            ),
          ),
        ),
      ),
    );
  }

  /// 360×640 centered in the window. Used when the window is not taller than
  /// the design frame.
  Widget _phoneLetterbox(BuildContext context, double maxW, double maxH) {
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
  const GameRoot({
    super.key,
    required this.session,
    required this.game,
    this.notices,
    this.replies,
    this.mail,
    this.welfare,
    this.photos,
    this.openLink = openUrl,
  });

  final ShopSession session;
  final ShopGame game;
  final NoticeFeed? notices;
  final NoticeReplies? replies;

  /// Hộp thư. Null hides the button (offline builds and most tests).
  final MailboxFeed? mail;

  /// Phúc lợi (Điểm danh, Giftcode, Bạn biết?). Null hides the button.
  final WelfareFeed? welfare;

  /// Opens an external slide link in a new tab.
  final void Function(String url) openLink;

  /// Picture upload for the góp ý form.
  final PhotoUploads? photos;

  @override
  State<GameRoot> createState() => _GameRootState();
}

class _GameRootState extends State<GameRoot> {
  late final AppLifecycleListener _lifecycle;
  var _musicUnlocked = false;

  /// Hộp thư (Thư + Tin tức). The bell and the envelope both open it.
  late final Inbox? _inbox = widget.mail == null
      ? null
      : Inbox(mail: widget.mail!, news: widget.notices);

  @override
  void initState() {
    super.initState();
    // Hidden browser tab or app in background: pause (spec §1).
    _lifecycle = AppLifecycleListener(
      onHide: widget.session.autoPause,
      onInactive: widget.session.autoPause,
      // iOS: an App Store purchase left uncredited is sent again.
      onResume: widget.session.drainApplePurchases,
    );
    widget.session.addListener(_onSession);
    _bindMail();
    _applySystemBars();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    widget.session.sounds.dispose();
    _lifecycle.dispose();
    _inbox?.dispose();
    super.dispose();
  }

  void _onSession() {
    _applyAudio();
    _bindMail();
    _applySystemBars();
  }

  (Color, Color)? _bars;

  /// Status icons sit on the header color; the gesture bar sits on the footer.
  void _applySystemBars() {
    if (kIsWeb) return;
    final next = frameBands(widget.session);
    if (_bars == next) return;
    _bars = next;
    final (top, bottom) = next;
    final onDark = top.computeLuminance() < 0.45;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: bottom,
        systemNavigationBarContrastEnforced: false,
        statusBarIconBrightness: onDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: onDark ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness: bottom.computeLuminance() < 0.45
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

  /// The inbox and Phúc lợi follow the signed-in account (none for a guest).
  void _bindMail() {
    final uid = widget.session.accountUid;
    final mail = widget.mail;
    if (mail != null && mail.uid != uid) {
      Future.microtask(() => mail.bindUser(widget.session.accountUid));
    }
    final welfare = widget.welfare;
    if (welfare != null && welfare.uid != uid) {
      Future.microtask(() => welfare.bindUser(widget.session.accountUid));
    }
  }

  /// A "Bạn biết?" slide was tapped. Returns a message when nothing opened.
  String? _openSlide(WelfareSlide slide) {
    switch (slide.linkType) {
      case SlideLinkType.none:
        return null;
      case SlideLinkType.url:
        widget.openLink(slide.link);
        return null;
      case SlideLinkType.route:
        return _openRoute(slide.link);
    }
  }

  String? _openRoute(String route) {
    final session = widget.session;
    final welfare = widget.welfare;
    switch (route) {
      case 'login':
        welfare?.selectTab(WelfareTab.login);
        return null;
      case 'giftcode':
        if (!giftcodesOffered) return null;
        welfare?.selectTab(WelfareTab.giftcode);
        return null;
      case 'mailbox':
      case 'notices':
        final inbox = _inbox;
        if (inbox == null) return 'Chưa mở được Hộp thư.';
        welfare?.close();
        inbox.openAt(route == 'notices' ? InboxTab.news : InboxTab.mail);
        return null;
    }
    // Game screens need a loaded shop, not the title screen.
    final inShop =
        session.screen != Screen.title && session.screen != Screen.donors;
    if (!inShop && route != 'donors') return 'Vào tiệm rồi mở mục này nhé.';
    final before = session.screen;
    switch (route) {
      case 'reviews':
        session.openReviews();
      case 'stock':
        session.openStock();
      case 'prices':
        session.openPrices();
      case 'garden':
        session.openGarden();
      case 'pets':
        session.openPets();
      case 'petShop':
        session.openPetShop();
      case 'upgrades':
        session.openUpgrades();
      case 'donors':
        if (!supportersEnabled) return 'Mục này chưa có trong bản game này.';
        session.openDonors();
      default:
        return 'Mục này chưa có trong bản game này.';
    }
    if (session.screen == before) return 'Chưa mở được mục này lúc này.';
    welfare?.close();
    return null;
  }

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

  /// Hộp thư and Phúc lợi; the corner buttons hide while either is open.
  List<ChangeNotifier> get _sheets => [?widget.mail, ?widget.welfare];

  /// Tall phones: the market uses the whole window. Every other screen stays
  /// on the 640 stage so the shop scene and the Flame camera still match,
  /// with the header and footer colors painted into the bands around it.
  Widget _inFrame(BuildContext context, ShopSession session, Widget child) {
    final metrics = FrameMetrics.maybeOf(context);
    final gapTop = metrics?.stageGapTop ?? 0;
    final gapBottom = metrics?.stageGapBottom ?? 0;
    if (gapTop <= 0 && gapBottom <= 0) return child;
    final fill = session.screen == Screen.market;
    final bands = frameBands(session);
    return Stack(
      children: [
        if (!fill && gapTop > 0)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: gapTop,
            child: IgnorePointer(child: ColoredBox(color: bands.$1)),
          ),
        if (!fill && gapBottom > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: gapBottom,
            child: IgnorePointer(child: ColoredBox(color: bands.$2)),
          ),
        if (fill)
          Positioned.fill(child: child)
        else
          Positioned(
            left: 0,
            top: gapTop,
            width: AppSize.frameWidth,
            height: AppSize.frameHeight,
            child: child,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final inbox = _inbox;
    final welfare = widget.welfare;
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
              return _inFrame(
                context,
                session,
                Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: IgnorePointer(
                          ignoring: screen != Screen.shop,
                          child: GameWidget<ShopGame>(game: widget.game),
                        ),
                      ),
                    ),
                    if (screen == Screen.shop)
                      Positioned.fill(
                        child: MainShopOverlay(
                          session: session,
                          sheets: _sheets,
                          sheetOpen: () => CornerButtonGate.anyOpen(_sheets),
                        ),
                      ),
                    if (screen == Screen.table)
                      Positioned.fill(
                        child: BouquetTableScreen(session: session),
                      ),
                    if (screen == Screen.reviews)
                      Positioned.fill(child: ReviewsScreen(session: session)),
                    if (screen == Screen.stock)
                      Positioned.fill(child: StockScreen(session: session)),
                    if (screen == Screen.market)
                      Positioned.fill(child: MarketScreen(session: session)),
                    if (screen == Screen.preorders)
                      Positioned.fill(child: PreorderScreen(session: session)),
                    if (screen == Screen.summary)
                      Positioned.fill(child: SummaryScreen(session: session)),
                    if (screen == Screen.upgrades)
                      Positioned.fill(child: UpgradesScreen(session: session)),
                    if (screen == Screen.prices)
                      Positioned.fill(child: PriceScreen(session: session)),
                    if (screen == Screen.garden)
                      Positioned.fill(child: GardenScreen(session: session)),
                    if (screen == Screen.pets)
                      Positioned.fill(child: PetScreen(session: session)),
                    if (screen == Screen.petShop)
                      Positioned.fill(child: PetShopScreen(session: session)),
                    if (session.petItemShopOpen &&
                        (screen == Screen.pets || screen == Screen.petShop))
                      Positioned.fill(
                        child: PetItemShopScreen(session: session),
                      ),
                    if (screen == Screen.potShop)
                      Positioned.fill(child: PotShopScreen(session: session)),
                    if (screen == Screen.potBook)
                      Positioned.fill(child: PotBookScreen(session: session)),
                    if (screen == Screen.title)
                      Positioned.fill(child: TitleScreen(session: session)),
                    if (screen == Screen.donors)
                      Positioned.fill(child: DonorsScreen(session: session)),
                    // SPEC_ban_luu.md (B): whose save is in play, right under
                    // the main shop's TopBar (56 tall plus the top inset).
                    if (screen == Screen.shop)
                      Positioned(
                        left: 0,
                        right: 0,
                        top:
                            56 + (FrameMetrics.maybeOf(context)?.topInset ?? 0),
                        child: SaveStatusRow(session: session),
                      ),
                    // Basket menu beside the gear: Hộp thư and Phúc lợi.
                    if (_showNoticeButton(session))
                      Positioned.fill(
                        child: CornerButtonGate(
                          sheets: _sheets,
                          child: CornerMenu(
                            left: screen == Screen.title
                                ? 12
                                : CornerMenu.shopHudLeft,
                            top: screen == Screen.title
                                ? 4
                                : 4 +
                                      (FrameMetrics.maybeOf(
                                            context,
                                          )?.topInset ??
                                          0),
                            listenable: Listenable.merge([?inbox, ?welfare]),
                            entries: menuEntries(
                              inbox: inbox,
                              welfare: welfare,
                              session: session,
                            ),
                          ),
                        ),
                      ),
                    if (session.tutorialActive &&
                        screen != Screen.title &&
                        screen != Screen.donors)
                      Positioned.fill(child: TutorialOverlay(session: session)),
                    if (screen != Screen.donors &&
                        (screen != Screen.title || session.pauseMenuOpen))
                      Positioned.fill(child: PopupLayer(session: session)),
                    // Tin thế giới, over the shop and its popups (Cài đặt opens
                    // Người đã chặn from here), spec 5.3.
                    if (session.chat.offered)
                      Positioned.fill(
                        child: ListenableBuilder(
                          listenable: session.chat,
                          builder: (context, _) => session.chat.open
                              ? WorldChatSheet(session: session)
                              : const SizedBox.shrink(),
                        ),
                      ),
                    // Khung avatar (F1), over the chat and Cài đặt that open it.
                    if (session.frames.offered)
                      Positioned.fill(
                        child: ListenableBuilder(
                          listenable: session.frames,
                          builder: (context, _) => session.frames.pickerOpen
                              ? AvatarFrameSheet(session: session)
                              : const SizedBox.shrink(),
                        ),
                      ),
                    if (session.tutorialViewStep > 0)
                      Positioned.fill(child: TutorialViewer(session: session)),
                    if (session.namePrompt != null)
                      Positioned.fill(child: ShopNamePopup(session: session)),
                    if (session.termsLaterOpen)
                      Positioned.fill(child: TermsLaterPopup(session: session)),
                    if (session.deleteAccountOpen)
                      Positioned.fill(
                        child: DeleteAccountDialog(session: session),
                      ),
                    if (session.deleteDone)
                      Positioned.fill(
                        child: DeleteDoneDialog(session: session),
                      ),
                    if (inbox != null)
                      Positioned.fill(
                        child: MailboxSheet(
                          inbox: inbox,
                          news: widget.notices == null
                              ? null
                              : NewsTab(
                                  feed: widget.notices!,
                                  onOpenLink: widget.openLink,
                                  replies: widget.replies,
                                  signedIn: session.signedIn,
                                  uid: session.accountUid ?? '',
                                  email: session.accountEmail ?? '',
                                  playerName: session.accountName ?? '',
                                  shopName: session.state.shopName ?? '',
                                  onSignIn: session.signIn,
                                  photos: widget.photos,
                                ),
                          signedIn: session.signedIn,
                          canClaim: () =>
                              session.canWriteAccount &&
                              session.accountUid == widget.mail!.uid,
                          grant: (mail) => session.grantRewards(
                            mail.rewards,
                            source: RewardSource.mailbox,
                            rank: charmMailRank(mail),
                          ),
                          onSignIn: session.signIn,
                        ),
                      ),
                    if (widget.welfare != null)
                      Positioned.fill(
                        child: WelfareSheet(
                          feed: widget.welfare!,
                          signedIn: session.signedIn,
                          canClaim: () =>
                              session.canWriteAccount &&
                              session.accountUid == widget.welfare!.uid,
                          grantLogin: (bundle) => session.grantRewards(
                            bundle,
                            source: RewardSource.loginReward,
                          ),
                          grantCode: (bundle) => session.grantRewards(
                            bundle,
                            source: RewardSource.giftcode,
                          ),
                          onSlide: _openSlide,
                          onSignIn: session.signIn,
                        ),
                      ),
                    if (session.eventOffer != null)
                      Positioned.fill(child: EventPopup(session: session)),
                    if (session.strayCatOffer)
                      Positioned.fill(child: StrayCatPopup(session: session)),
                    if (session.seatLost)
                      Positioned.fill(child: SeatLostPopup(session: session)),
                    // Vòng quay tuần (task 8), under the Pha lê shop so a
                    // top-up from inside it lands on top; the one-time intro
                    // over the shop.
                    if (session.gacha.offered)
                      Positioned.fill(
                        child: ListenableBuilder(
                          listenable: session.gacha,
                          builder: (context, _) => Stack(
                            children: [
                              if (session.gacha.open)
                                Positioned.fill(
                                  child: GachaScreen(session: session),
                                ),
                              if (!session.gacha.open &&
                                  session.gacha.introDue &&
                                  session.eventOffer == null)
                                Positioned.fill(
                                  child: GachaIntroPopup(gacha: session.gacha),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (session.phaleShopOpen)
                      Positioned.fill(child: PhaleShopHost(session: session)),
                    if (session.phaleShort != null || session.xuShort != null)
                      Positioned.fill(
                        child: MoneyShortOverlays(session: session),
                      ),
                    // Màn VIP (spec 4.4), over the Pha lê shop, the chat and
                    // the profile cards that open it; the level-up popup on top.
                    if (session.vip.offered)
                      Positioned.fill(
                        child: ListenableBuilder(
                          listenable: session.vip,
                          builder: (context, _) => Stack(
                            children: [
                              if (session.vip.open)
                                Positioned.fill(
                                  child: VipScreen(session: session),
                                ),
                              if (session.vip.levelUp != null)
                                Positioned.fill(
                                  child: VipLevelUpPopup(session: session),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (session.rewardedAd != null)
                      Positioned.fill(child: RewardedAdSheet(session: session)),
                    if (session.petItemGift != null &&
                        session.lastDelivery == null)
                      Positioned.fill(
                        child: PetItemGiftPopup(session: session),
                      ),
                    if (session.termsMode != null)
                      Positioned.fill(
                        child: TermsScreen(
                          key: ValueKey(session.termsMode),
                          session: session,
                        ),
                      ),
                    if (session.signInChooserOpen)
                      Positioned.fill(child: SignInChooser(session: session)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Colors that continue the screen into the bands above and below the
/// 640 stage, so a tall phone does not show cream strips.
(Color, Color) frameBands(ShopSession s) {
  if (s.termsMode != null) {
    return (AppColors.bgBase, AppColors.bgBase);
  }
  if (s.phaleShopOpen || s.charmBoardOpen || s.petSlotsOpen) {
    return (AppColors.headerTop, AppColors.bgBase);
  }
  return switch (s.screen) {
    Screen.shop => (AppColors.headerTop, AppColors.navBg),
    Screen.market => (AppColors.headerTop, AppColors.surfaceCard),
    Screen.title || Screen.summary => (AppColors.bgShop, AppColors.bgShop),
    Screen.table => (AppColors.headerTop, AppColors.bgShop),
    Screen.preorders ||
    Screen.upgrades ||
    Screen.pets ||
    Screen.petShop ||
    Screen.potShop ||
    Screen.potBook => (AppColors.headerTop, AppColors.bgBase),
    Screen.reviews ||
    Screen.stock ||
    Screen.donors ||
    Screen.prices ||
    Screen.garden => (AppColors.bgBase, AppColors.bgBase),
  };
}

bool _showNoticeButton(ShopSession session) {
  if (session.tutorialActive) return false;
  return session.screen == Screen.title ||
      session.screen == Screen.shop ||
      session.screen == Screen.table;
}

/// Hides the corner menu while the Hộp thư or Phúc lợi sheet is open, so it
/// never pokes through the popup's frame or ribbon.
class CornerButtonGate extends StatelessWidget {
  const CornerButtonGate({
    super.key,
    required this.sheets,
    required this.child,
  });

  final List<ChangeNotifier> sheets;
  final Widget child;

  static bool _open(Object feed) => switch (feed) {
    MailboxFeed f => f.open,
    WelfareFeed f => f.open,
    _ => false,
  };

  /// The Hộp thư or Phúc lợi sheet is open (the chat ticker hides too).
  static bool anyOpen(List<ChangeNotifier> sheets) => sheets.any(_open);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(sheets),
      builder: (context, _) =>
          anyOpen(sheets) ? const SizedBox.shrink() : child,
    );
  }
}

/// The corner menu's tray: Hộp thư, Phúc lợi, Cài đặt. Tin thế giới is on
/// the bottom nav. Three entries → 168 dp.
List<CornerMenuEntry> menuEntries({
  Inbox? inbox,
  WelfareFeed? welfare,
  ShopSession? session,
}) => [
  if (inbox != null)
    CornerMenuEntry(
      id: 'mailbox',
      label: 'Hộp thư',
      unread: () => inbox.unread,
      onTap: () {
        welfare?.close();
        inbox.openAt(InboxTab.mail);
      },
      icon: (_) => MailEnvelope(
        open: inbox.unread == 0,
        width: 30,
        fallback: const Icon(
          Icons.mail_rounded,
          size: 22,
          color: AppColors.primaryBase,
        ),
      ),
    ),
  if (welfare != null)
    CornerMenuEntry(
      id: 'welfare',
      label: 'Phúc lợi',
      unread: () => welfare.canClaimToday ? 1 : 0,
      onTap: () {
        inbox?.close();
        if (!welfare.open) welfare.toggle();
      },
      icon: (_) => Image.asset(
        Art.phucLoi('phuc_loi_icon'),
        width: 32,
        height: 32,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => const Icon(
          Icons.card_giftcard_rounded,
          size: 22,
          color: AppColors.primaryBase,
        ),
      ),
    ),
  if (session != null)
    CornerMenuEntry(
      id: 'settings',
      label: 'Cài đặt',
      unread: () => 0,
      onTap: () {
        inbox?.close();
        welfare?.close();
        session.togglePause();
      },
      icon: (_) => Image.asset(
        Art.nav('cai_dat'),
        width: 22,
        height: 22,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => const Icon(
          Icons.settings_rounded,
          size: 22,
          color: AppColors.primaryBase,
        ),
      ),
    ),
];
