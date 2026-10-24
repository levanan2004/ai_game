import 'dart:async';

import 'data/wallet_client.dart';
import 'data/firestore_charm_board.dart';
import 'data/firestore_rating_board.dart';
import 'data/firestore_profile_reports.dart';
import 'data/firestore_account_prefs.dart';
import 'data/firestore_avatar_frames.dart';
import 'data/firestore_gacha_history.dart';
import 'data/firestore_vip.dart';
import 'data/firestore_world_chat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'ads/launch_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/account_gateway.dart';
import 'data/firebase_account.dart';
import 'data/firebase_photo_uploads.dart';
import 'data/mailbox_store.dart';
import 'data/game_data.dart';
import 'data/notice_board.dart';
import 'data/notice_replies.dart';
import 'data/rarity_rules.dart';
import 'data/sepay_phale_gateway.dart';
import 'data/player_directory.dart';
import 'data/pot_rules.dart' show GachaConfig;
import 'data/supporter_admin.dart';
import 'data/supporter_source.dart';
import 'data/welfare_store.dart';
import 'firebase_options.dart';
import 'game/shop_game.dart';
import 'iap/apple_phale_client.dart';
import 'iap/phale_iap.dart';
import 'logic/platform_flags.dart';
import 'logic/game_notice.dart';
import 'logic/gacha.dart';
import 'logic/rewards.dart' show RewardSource;
import 'logic/mailbox.dart';
import 'logic/notice_feed.dart';
import 'logic/notice_reply.dart';
import 'logic/phale_claim.dart';
import 'logic/photo_uploads.dart';
import 'logic/play_analytics.dart';
import 'logic/shop_session.dart';
import 'logic/site_route.dart';
import 'logic/site_route_stub.dart'
    if (dart.library.js_interop) 'logic/site_route_web.dart';
import 'logic/tab_id_stub.dart'
    if (dart.library.js_interop) 'logic/tab_id_web.dart';
import 'logic/welfare.dart';
import 'save/game_state.dart';
import 'save/progress_store.dart';
import 'theme/tokens.dart';
import 'ui/admin_page.dart';
import 'ui/game_root.dart';

/// Where the Pha lê top-up functions live (2nd gen, see functions/README.md).
const _phaleBaseUrl =
    'https://asia-southeast1-tiem-hoa-som-mai.cloudfunctions.net';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản trị · Tiệm Hoa Sớm Mai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: AppFonts.body,
        scaffoldBackgroundColor: AppColors.bgBase,
      ),
      home: const AdminPage(),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The game is a 360x640 portrait frame (see GameFrame).
  if (!kIsWeb) {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } catch (_) {}
  }
  // A missing network or a failed Firebase init must not stop offline play.
  // Web uses the hand-written options. Android and iOS read their native
  // config file (google-services.json / GoogleService-Info.plist) unless
  // DefaultFirebaseOptions has real values; with neither, init throws and the
  // game starts as an offline guest.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await PlayAnalytics.visit();
  } catch (_) {}
  runApp(
    currentSiteArea() == SiteArea.admin ? const AdminApp() : const ShopApp(),
  );
}

class ShopApp extends StatefulWidget {
  const ShopApp({super.key, this.data, this.store});

  /// Test hooks. When null, assets and browser storage are loaded.
  final GameData? data;
  final ProgressStore? store;

  @override
  State<ShopApp> createState() => _ShopAppState();
}

class _ShopAppState extends State<ShopApp> {
  ShopSession? _session;
  ShopGame? _game;
  NoticeFeed? _notices;
  NoticeReplies? _replies;
  MailboxFeed? _mail;
  WelfareFeed? _welfare;
  PhotoUploads? _photos;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // Widget tests use a TestWidgets binding. The tracking dialog and the
    // ads SDK stay out of those tests.
    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (!binding.contains('Test')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(launchMobileAds());
      });
    }
  }

  Future<void> _load() async {
    try {
      final data = widget.data ?? await GameData.load();
      RarityRules.current = data.economy.rewardRarity;
      GachaConfig.current = data.economy.gacha;
      final store = widget.store ?? await ProgressStore.persistent();
      final online = Firebase.apps.isNotEmpty;
      // Only signed-in play is saved. A reload opens the account this
      // browser used last, from its own copy, while the login is restored.
      // The old guest slot is not read. Without Firebase there is no
      // account to open, so play is an unsaved guest game this time.
      final lastAccount = online ? await store.loadLastAccount() : null;
      GameState? saved;
      if (lastAccount != null) {
        store.useAccount(lastAccount.uid);
        saved = await store.load();
      }
      final terms = await store.loadTerms();
      final guestBannerDismissed = await store.loadGuestBannerDismissed();
      NoticeSeen seen;
      if (widget.store != null) {
        seen = NoticeSeen.memory();
      } else {
        try {
          seen = await NoticeSeen.persistent();
        } catch (_) {
          seen = NoticeSeen.memory();
        }
      }
      final replies = online ? FirestoreNoticeReplies() : null;
      final notices = NoticeFeed(
        board: online ? FirestoreNoticeBoard() : const EmptyNoticeBoard(),
        seen: seen,
      );
      final mail = MailboxFeed(service: online ? FirestoreMailbox() : null);
      final welfare = WelfareFeed(service: online ? FirestoreWelfare() : null);
      final photos = online ? FirebasePhotoUploads() : null;
      final account = online ? FirebaseAccount() : const OfflineAccount();
      await account.useLastingLogin();
      final session = ShopSession(
        data: data,
        store: store,
        saved: saved,
        supporters: online ? const FirestoreSupporterSource() : null,
        supporterAdmin: online ? FirestoreSupporterAdmin() : null,
        playerDirectory: online ? FirestorePlayerDirectory() : null,
        charmBoard: online ? FirestoreCharmBoard() : null,
        ratingBoardSource: online ? FirestoreRatingBoard() : null,
        reports: online ? FirestoreProfileReports() : null,
        worldChatSource: online ? FirestoreWorldChat() : null,
        avatarFrameSource: online ? FirestoreAvatarFrames() : null,
        vipSource: online ? FirestoreVip() : null,
        gachaHistory: online ? FirestoreGachaHistory() : null,
        accountPrefsSource: online ? FirestoreAccountPrefs() : null,
        account: account,
        terms: terms,
        guestBannerDismissed: guestBannerDismissed,
        tabId: currentTabId(),
        lastAccount: lastAccount,
      )..showTitle();
      if (online) {
        // Server wallet (functions/wallet.js): Pha lê spends, Thẻ gacha,
        // pity. Set before the account resumes so sign-in reads it first.
        session.walletApi = WalletClient(idToken: session.account.idToken);
        mail.walletClaim = session.walletClaimMail;
        // Vòng quay tuần claims its spin mail from the result popup.
        session.gacha.mailbox = FeedGachaMailbox(
          mail,
          allowed: () =>
              session.canWriteAccount && session.accountUid == mail.uid,
          grant: (m) =>
              session.grantRewards(m.rewards, source: RewardSource.mailbox),
        );
      }
      // A slow or failed pull must not block the first frame.
      session.resumeAccount();
      if (!mounted) {
        notices.dispose();
        mail.dispose();
        welfare.dispose();
        return;
      }
      notices.attachAccount(session);
      unawaited(session.board.useHiddenPlayers(store));
      unawaited(session.chat.useStore(store));
      notices.start();
      // Top-up: the real gateway (used only when phaLeShop.open) and the claim
      // of the credit mail the server writes when the money arrives.
      if (online) {
        session.phaleLiveGateway = SepayPhaleGateway(
          baseUrl: _phaleBaseUrl,
          idToken: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
        );
        session.phaleClaim = (order) => claimPhaleMail(session, mail, order);
      }
      if (phaLeUsesAppleIap && online) {
        final iap = PhaleIap();
        session.phaleIap = iap;
        session.applePhaleClient = ApplePhaleClient();
        // Unfinished purchases StoreKit hands back at launch are credited
        // as they arrive (once signed in; sign-in drains again).
        iap.unclaimed.listen((_) => session.drainApplePurchases());
        unawaited(iap.start());
        unawaited(session.drainApplePurchases());
      }
      // Publishes the player's Mị lực row every 15 minutes while the game is open.
      session.board.start();
      // An approved season reward arrives as a mail; the board claims it there.
      session.board.attachMailbox(mail);
      setState(() {
        _session = session;
        _game = ShopGame(session);
        _notices = notices;
        _replies = replies;
        _mail = mail;
        _welfare = welfare;
        _photos = photos;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _notices?.dispose();
    _mail?.dispose();
    _welfare?.dispose();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return MaterialApp(
      title: 'Tiệm Hoa Sớm Mai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: AppFonts.body,
        scaffoldBackgroundColor: AppColors.bgBase,
      ),
      home: Material(
        color: AppColors.bgBase,
        child: session == null
            ? Center(
                child: Text(
                  _error == null ? '' : 'Lỗi dữ liệu: $_error',
                  style: AppText.caption(),
                ),
              )
            : GameRoot(
                session: session,
                game: _game!,
                notices: _notices,
                replies: _replies,
                mail: _mail,
                welfare: _welfare,
                photos: _photos,
              ),
      ),
    );
  }
}
