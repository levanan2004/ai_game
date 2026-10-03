import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/account_gateway.dart';
import 'data/firebase_account.dart';
import 'data/game_data.dart';
import 'data/notice_board.dart';
import 'data/notice_replies.dart';
import 'data/player_directory.dart';
import 'data/supporter_admin.dart';
import 'data/supporter_source.dart';
import 'firebase_options.dart';
import 'game/shop_game.dart';
import 'logic/game_notice.dart';
import 'logic/notice_feed.dart';
import 'logic/notice_reply.dart';
import 'logic/play_analytics.dart';
import 'logic/shop_session.dart';
import 'logic/site_route.dart';
import 'logic/site_route_stub.dart'
    if (dart.library.js_interop) 'logic/site_route_web.dart';
import 'logic/tab_id_stub.dart'
    if (dart.library.js_interop) 'logic/tab_id_web.dart';
import 'save/progress_store.dart';
import 'theme/tokens.dart';
import 'ui/admin_page.dart';
import 'ui/game_root.dart';

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
  // A missing network or a failed Firebase init must not stop offline play.
  if (kIsWeb) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
      await PlayAnalytics.visit();
    } catch (_) {}
  }
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
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = widget.data ?? await GameData.load();
      final store = widget.store ?? await ProgressStore.persistent();
      final saved = await store.load();
      final terms = await store.loadTerms();
      final online = Firebase.apps.isNotEmpty;
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
      final account = online ? FirebaseAccount() : const OfflineAccount();
      await account.useTabLogin();
      final session = ShopSession(
        data: data,
        store: store,
        saved: saved,
        supporters: online ? const FirestoreSupporterSource() : null,
        supporterAdmin: online ? FirestoreSupporterAdmin() : null,
        playerDirectory: online ? FirestorePlayerDirectory() : null,
        account: account,
        terms: terms,
        tabId: currentTabId(),
      )..showTitle();
      // A slow or failed pull must not block the first frame.
      session.resumeAccount();
      if (!mounted) {
        notices.dispose();
        return;
      }
      notices.start();
      setState(() {
        _session = session;
        _game = ShopGame(session);
        _notices = notices;
        _replies = replies;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _notices?.dispose();
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
              ),
      ),
    );
  }
}
