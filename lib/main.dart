import 'package:flutter/material.dart';

import 'data/game_data.dart';
import 'game/shop_game.dart';
import 'logic/shop_session.dart';
import 'save/progress_store.dart';
import 'theme/tokens.dart';
import 'ui/game_root.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShopApp());
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
      final session = ShopSession(data: data, store: store, saved: saved);
      if (!mounted) return;
      setState(() {
        _session = session;
        _game = ShopGame(session);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return MaterialApp(
      title: 'Tiệm Hoa',
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
            : GameRoot(session: session, game: _game!),
      ),
    );
  }
}
