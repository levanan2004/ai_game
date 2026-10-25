import 'dart:convert';

import 'package:flutter/services.dart';

import '../logic/login_rewards.dart';
import '../logic/word_filter.dart';
import 'pha_le_rules.dart';
import 'skins.dart';
import 'cosmetics.dart';
import 'economy.dart';
import 'texts.dart';

/// Everything the game reads from `assets/data/` at startup.
class GameData {
  const GameData({
    required this.economy,
    required this.reviews,
    required this.orders,
    required this.cosmetics,
    this.words,
    this.skinCatalog,
  });

  static const economyAsset = 'assets/data/economy.json';
  static const reviewsAsset = 'assets/data/reviews.json';
  static const ordersAsset = 'assets/data/orders.json';
  static const cosmeticsAsset = 'assets/data/cosmetics.json';
  static const skinTextAsset = 'assets/data/ten_skin.json';
  static const avatarIndexAsset = 'assets/images/customers/index.json';

  final Economy economy;
  final ReviewTexts reviews;
  final OrderTexts orders;
  final CosmeticCatalog cosmetics;

  /// Nhất's word list ([WordFilter.asset]); null lets every name through.
  final WordFilter? words;

  WordFilter get wordFilter => words ?? WordFilter.empty;

  /// Skin trang trí: prices from economy.json, names from ten_skin.json.
  final SkinCatalog? skinCatalog;

  SkinCatalog get skins => skinCatalog ?? SkinCatalog.empty;

  factory GameData.fromJsonStrings({
    required String economy,
    required String reviews,
    required String orders,
    required String cosmetics,
    String? avatarIndex,
    String? tuCam,
    String? skinText,
  }) {
    var orderTexts = OrderTexts.fromJson(
      jsonDecode(orders) as Map<String, dynamic>,
    );
    if (avatarIndex != null) {
      orderTexts = orderTexts.withAvatars(parseAvatarIndex(avatarIndex));
    }
    final eco = Economy.fromJson(jsonDecode(economy) as Map<String, dynamic>);
    // Numbers code reads without a GameData at hand (ad sheet, exchange
    // math, Điểm danh fallback table) come from this file too.
    PhaLeRules.current = eco.phaLeRules;
    LoginRewardConfig.economyDefault = LoginRewardConfig.fromEconomy(
      eco.loginRewardsJson,
    );
    return GameData(
      economy: eco,
      reviews: ReviewTexts.fromJson(
        jsonDecode(reviews) as Map<String, dynamic>,
      ),
      orders: orderTexts,
      cosmetics: CosmeticCatalog.fromJson(
        jsonDecode(cosmetics) as Map<String, dynamic>,
      ),
      words: tuCam == null ? null : WordFilter.parse(tuCam),
      skinCatalog: SkinCatalog.fromStrings(eco.skinsJson, skinText),
    );
  }

  /// customers/index.json: list of {name, avatarId, ...} -> name to avatarId.
  static Map<String, String> parseAvatarIndex(String json) => {
    for (final e in jsonDecode(json) as List)
      (e as Map<String, dynamic>)['name'] as String: e['avatarId'] as String,
  };

  static Future<GameData> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    return GameData.fromJsonStrings(
      economy: await b.loadString(economyAsset),
      reviews: await b.loadString(reviewsAsset),
      orders: await b.loadString(ordersAsset),
      cosmetics: await b.loadString(cosmeticsAsset),
      avatarIndex: await b.loadString(avatarIndexAsset),
      tuCam: await b.loadString(WordFilter.asset),
      skinText: await b.loadString(skinTextAsset),
    );
  }
}
