import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../game/shop_game.dart';
import '../logic/charm_rewards.dart';
import '../logic/inbox.dart';
import '../logic/mailbox.dart';
import '../logic/notice_feed.dart';
import '../logic/notice_reply.dart';
import '../logic/photo_uploads.dart';
import '../logic/rewards.dart';
import '../logic/shop_session.dart';
import '../logic/welfare.dart';
import '../logic/welfare_slides.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'bouquet_table_screen.dart';
import 'corner_menu.dart';
import 'donors_screen.dart';
import 'event_popup.dart';
import 'garden_screen.dart';
import 'pet_item_shop.dart';
import 'phale_popups.dart';
import 'phale_shop_screen.dart';
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
import 'seat_popup.dart';
import 'shop_name_popup.dart';
import 'stock_screen.dart';
import 'summary_screen.dart';
import 'terms_screen.dart';
import 'title_screen.dart';
import 'tutorial_overlay.dart';
import 'upgrades_screen.dart';
import 'welfare_sheet.dart';

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
    );
    widget.session.addListener(_onSession);
    _bindMail();
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
                    Positioned.fill(child: PetItemShopScreen(session: session)),
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
                      top: 56 + (FrameMetrics.maybeOf(context)?.topInset ?? 0),
                      child: SaveStatusRow(session: session),
                    ),
                  // Basket menu beside the gear: Hộp thư and Phúc lợi.
                  if ((inbox != null || welfare != null) &&
                      _showNoticeButton(session))
                    Positioned.fill(
                      child: CornerButtonGate(
                        sheets: _sheets,
                        child: CornerMenu(
                          left: screen == Screen.title ? 12 : 272,
                          top: screen == Screen.title
                              ? 4
                              : 4 +
                                    (FrameMetrics.maybeOf(context)?.topInset ??
                                        0),
                          listenable: Listenable.merge([?inbox, ?welfare]),
                          entries: menuEntries(inbox: inbox, welfare: welfare),
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
                  if (session.tutorialViewStep > 0)
                    Positioned.fill(child: TutorialViewer(session: session)),
                  if (session.namePrompt != null)
                    Positioned.fill(child: ShopNamePopup(session: session)),
                  if (session.termsLaterOpen)
                    Positioned.fill(child: TermsLaterPopup(session: session)),
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
                  if (session.phaleShopOpen)
                    Positioned.fill(child: PhaleShopHost(session: session)),
                  if (session.phaleShort != null)
                    Positioned.fill(child: PhaleShortPopup(session: session)),
                  if (session.petItemGift != null &&
                      session.lastDelivery == null)
                    Positioned.fill(child: PetItemGiftPopup(session: session)),
                  if (session.termsMode != null)
                    Positioned.fill(
                      child: TermsScreen(
                        key: ValueKey(session.termsMode),
                        session: session,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(sheets),
      builder: (context, _) =>
          sheets.any(_open) ? const SizedBox.shrink() : child,
    );
  }
}

/// The corner menu's tray, top to bottom. A third entry (Xếp hạng) only
/// needs one more [CornerMenuEntry] here; the tray grows to 168 dp.
List<CornerMenuEntry> menuEntries({Inbox? inbox, WelfareFeed? welfare}) => [
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
];
