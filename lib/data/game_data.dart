import 'dart:convert';

import 'package:flutter/services.dart';

import 'economy.dart';
import 'texts.dart';

/// Everything the game reads from `assets/data/` at startup.
class GameData {
  const GameData({
    required this.economy,
    required this.reviews,
    required this.orders,
  });

  static const economyAsset = 'assets/data/economy.json';
  static const reviewsAsset = 'assets/data/reviews.json';
  static const ordersAsset = 'assets/data/orders.json';
  static const avatarIndexAsset = 'assets/images/customers/index.json';

  final Economy economy;
  final ReviewTexts reviews;
  final OrderTexts orders;

  factory GameData.fromJsonStrings({
    required String economy,
    required String reviews,
    required String orders,
    String? avatarIndex,
  }) {
    var orderTexts = OrderTexts.fromJson(
      jsonDecode(orders) as Map<String, dynamic>,
    );
    if (avatarIndex != null) {
      orderTexts = orderTexts.withAvatars(parseAvatarIndex(avatarIndex));
    }
    return GameData(
      economy: Economy.fromJson(jsonDecode(economy) as Map<String, dynamic>),
      reviews: ReviewTexts.fromJson(
        jsonDecode(reviews) as Map<String, dynamic>,
      ),
      orders: orderTexts,
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
      avatarIndex: await b.loadString(avatarIndexAsset),
    );
  }
}
