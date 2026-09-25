import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/shop_game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShopApp());
}

class ShopApp extends StatefulWidget {
  const ShopApp({super.key, this.game});

  /// When null, a [ShopGame] that loads browser storage is created.
  final ShopGame? game;

  @override
  State<ShopApp> createState() => _ShopAppState();
}

class _ShopAppState extends State<ShopApp> {
  late final ShopGame _game = widget.game ?? ShopGame();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ai_game',
      home: GameWidget(game: _game),
    );
  }
}
